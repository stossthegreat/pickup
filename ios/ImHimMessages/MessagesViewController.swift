//
//  MessagesViewController.swift
//  ImHimMessages
//
//  The iMessage app — what shows up in iMessage's "+" drawer
//  alongside Photos, Apple Pay, etc. WingAI ships exactly this kind
//  of extension. End-to-end flow:
//
//   1. User opens Messages, taps "+" next to the compose box.
//   2. The app drawer slides up. ImHim icon is one of the apps.
//   3. Tap ImHim. Our extension takes over the bottom half of the
//      screen with our UI:
//
//        Header  ImHim wordmark + close X
//        Status  "Waiting for screenshot…" (pulsing red pill)
//        Action  "OR PICK FROM PHOTOS" outline pill
//
//   4. While that's on screen, our PHPhotoLibrary poll watches for
//      a brand-new screenshot. The moment one lands (or the user
//      picks one via the picker), the UI flips to:
//
//        Image (half-screen) with the red scan line travelling
//        SCANNING  NN%  thin red progress bar
//
//   5. Backend returns replies. UI flips to three reply chips.
//      Tap a chip → activeConversation.insertText(...) drops it
//      into iMessage's compose box. User taps Send.
//
//  No app switch, no copy/paste.
//

import Messages
import UIKit
import Photos
import PhotosUI
import UniformTypeIdentifiers

@objc(MessagesViewController)
class MessagesViewController: MSMessagesAppViewController, PHPickerViewControllerDelegate {

    // MARK: - State

    private enum State {
        case waiting               // looking for a screenshot
        case scanning(Data)        // call to /rizz/reply in flight
        case replies(Data, [RizzReplyItem])
        case error(String)
    }
    private var state: State = .waiting { didSet { render() } }
    private let client = RizzClient()
    private var pollTimer: Timer?
    private var lastConsumedAssetID: String?

    // Animation drivers — only spin up while scanning.
    private var scanCtl: CADisplayLink?
    private var pctCtl:  CADisplayLink?
    private var scanStart: CFTimeInterval = 0
    private var pctStart:  CFTimeInterval = 0

    // MARK: - Views

    private lazy var rootStack: UIStackView = {
        let v = UIStackView()
        v.axis = .vertical
        v.alignment = .fill
        v.spacing = 12
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var headerRow: UIStackView = {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        let wordmark = UILabel()
        wordmark.attributedText = makeWordmark(size: 22)

        let dot = UIView()
        dot.backgroundColor = Theme.red
        dot.layer.cornerRadius = 3
        dot.widthAnchor.constraint(equalToConstant: 6).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 6).isActive = true

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeBtn.tintColor = Theme.textSecondary
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeBtn.widthAnchor.constraint(equalToConstant: 36).isActive = true
        closeBtn.heightAnchor.constraint(equalToConstant: 30).isActive = true

        row.addArrangedSubview(wordmark)
        row.addArrangedSubview(dot)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(closeBtn)
        return row
    }()

    private let bodyContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // Persistent scanning views.
    private let imageCard: UIImageView = {
        let iv = UIImageView()
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 18
        iv.contentMode = .scaleAspectFill
        iv.backgroundColor = Theme.surface2
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    private let scanLine = _ScanLineViewIM()
    private var scanLineCenterY: NSLayoutConstraint?

    private let pctLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let pctBar: UIProgressView = {
        let p = UIProgressView(progressViewStyle: .bar)
        p.progressTintColor = Theme.red
        p.trackTintColor = Theme.surface3
        p.layer.cornerRadius = 1.5
        p.clipsToBounds = true
        p.translatesAutoresizingMaskIntoConstraints = false
        p.heightAnchor.constraint(equalToConstant: 3).isActive = true
        return p
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.base

        view.addSubview(rootStack)
        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            rootStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
        ])
        rootStack.addArrangedSubview(headerRow)
        rootStack.addArrangedSubview(bodyContainer)

        render()
        startPolling()
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        startPolling()
        render()
    }

    override func didResignActive(with conversation: MSConversation) {
        super.didResignActive(with: conversation)
        stopPolling()
        stopAnimations()
    }

    deinit {
        scanCtl?.invalidate()
        pctCtl?.invalidate()
        pollTimer?.invalidate()
    }

    // MARK: - Photo polling

    private func startPolling() {
        stopPolling()
        tryConsumeScreenshot()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.tryConsumeScreenshot()
        }
    }
    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func tryConsumeScreenshot() {
        if case .waiting = state {} else { return }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in }
            return
        }
        guard status == .authorized || status == .limited else { return }

        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        opts.fetchLimit = 1
        let result = PHAsset.fetchAssets(with: .image, options: opts)
        guard let asset = result.firstObject,
              let created = asset.creationDate
        else { return }
        // 120s freshness window — long enough for the user to take a
        // screenshot, switch back to iMessage, tap + → ImHim.
        if Date().timeIntervalSince(created) > 120 { return }
        if asset.localIdentifier == lastConsumedAssetID { return }

        let req = PHImageRequestOptions()
        req.isNetworkAccessAllowed = true
        req.deliveryMode = .highQualityFormat
        req.resizeMode = .none
        req.isSynchronous = false
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: req) { [weak self] data, _, _, _ in
            DispatchQueue.main.async {
                guard let self = self, let data = data else { return }
                self.lastConsumedAssetID = asset.localIdentifier
                self.send(data)
            }
        }
    }

    // MARK: - Manual picker

    @objc private func pickFromPhotos() {
        // Expanded presentation gives us the screen real estate we need
        // to present a PHPickerViewController on top.
        if presentationStyle != .expanded {
            requestPresentationStyle(.expanded)
        }
        var cfg = PHPickerConfiguration(photoLibrary: .shared())
        cfg.filter = .images
        cfg.selectionLimit = 1
        let picker = PHPickerViewController(configuration: cfg)
        picker.delegate = self
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.present(picker, animated: true)
        }
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        else { return }
        provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                var data: Data?
                if let url = item as? URL { data = try? Data(contentsOf: url) }
                else if let image = item as? UIImage { data = image.jpegData(compressionQuality: 0.92) }
                else if let raw = item as? Data { data = raw }
                if let data = data { self.send(data) }
            }
        }
    }

    // MARK: - Send → /rizz/reply

    private func send(_ data: Data) {
        state = .scanning(data)
        stopPolling()
        startAnimations()
        client.fetchReplies(screenshot: data) { [weak self] result in
            guard let self = self else { return }
            self.stopAnimations()
            switch result {
            case .success(let replies):
                if replies.isEmpty {
                    self.state = .error("No replies — try a clearer screenshot.")
                } else {
                    self.state = .replies(data, replies)
                }
            case .failure(let err):
                self.state = .error(err.userMessage)
            }
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        scanStart = CACurrentMediaTime()
        pctStart  = CACurrentMediaTime()
        scanCtl?.invalidate()
        scanCtl = CADisplayLink(target: self, selector: #selector(scanTick))
        scanCtl?.add(to: .main, forMode: .common)
        pctCtl?.invalidate()
        pctCtl = CADisplayLink(target: self, selector: #selector(pctTick))
        pctCtl?.add(to: .main, forMode: .common)
    }
    private func stopAnimations() {
        scanCtl?.invalidate(); scanCtl = nil
        pctCtl?.invalidate(); pctCtl = nil
    }
    @objc private func scanTick() {
        let elapsed = CACurrentMediaTime() - scanStart
        let cycle = 2.8
        let t = (elapsed.truncatingRemainder(dividingBy: cycle)) / cycle
        let pingPong = abs(sin(.pi * t))
        let h = imageCard.bounds.height
        if h <= 0 { return }
        let y = -(h / 2 - 13) + (h - 26) * pingPong
        scanLineCenterY?.constant = y
    }
    @objc private func pctTick() {
        let elapsed = min(CACurrentMediaTime() - pctStart, 14)
        let progress = pow(1 - (1 - elapsed / 14), 3)
        let pct = Int((progress * 96).rounded())
        let attr = NSMutableAttributedString(
            string: "\(pct)%",
            attributes: [
                .font: italic(size: 42, weight: .heavy),
                .foregroundColor: Theme.textPrimary,
            ]
        )
        attr.addAttribute(.foregroundColor, value: Theme.red, range: NSRange(location: attr.length - 1, length: 1))
        pctLabel.attributedText = attr
        pctBar.setProgress(Float(pct) / 100, animated: false)
    }

    // MARK: - Render

    private func render() {
        bodyContainer.subviews.forEach { $0.removeFromSuperview() }
        let inner: UIView
        switch state {
        case .waiting:               inner = makeWaitingView()
        case .scanning(let data):    inner = makeScanningView(data)
        case .replies(let d, let r): inner = makeRepliesView(d, r)
        case .error(let m):          inner = makeErrorView(m)
        }
        inner.translatesAutoresizingMaskIntoConstraints = false
        bodyContainer.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: bodyContainer.topAnchor),
            inner.bottomAnchor.constraint(equalTo: bodyContainer.bottomAnchor),
            inner.leadingAnchor.constraint(equalTo: bodyContainer.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: bodyContainer.trailingAnchor),
        ])
    }

    // MARK: - Builders

    private func makeWaitingView() -> UIView {
        let card = UIView()
        card.backgroundColor = Theme.surface1
        card.layer.cornerRadius = 20
        card.layer.borderWidth = 0.8
        card.layer.borderColor = Theme.divider.cgColor

        let title = UILabel()
        title.text = "Drop a screenshot."
        title.font = italic(size: 24, weight: .heavy)
        title.textColor = Theme.textPrimary
        title.textAlignment = .center

        let sub = UILabel()
        sub.text = "Take a screenshot of the chat — we'll read it and write three replies you can tap straight in."
        sub.font = Theme.body(size: 13)
        sub.textColor = Theme.textSecondary
        sub.textAlignment = .center
        sub.numberOfLines = 0

        let pulse = makeRedPill(text: "WAITING FOR SCREENSHOT")
        animatePulse(pulse)

        let manual = makeOutlinePill(text: "OR PICK FROM PHOTOS")
        let tap = UITapGestureRecognizer(target: self, action: #selector(pickFromPhotos))
        manual.addGestureRecognizer(tap)

        let stack = UIStackView(arrangedSubviews: [title, sub, pulse, manual])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
        ])
        return card
    }

    private func makeScanningView(_ data: Data) -> UIView {
        imageCard.image = UIImage(data: data)
        scanLine.translatesAutoresizingMaskIntoConstraints = false

        let cardWrap = UIView()
        cardWrap.translatesAutoresizingMaskIntoConstraints = false
        cardWrap.addSubview(imageCard)
        cardWrap.addSubview(scanLine)
        let centerY = scanLine.centerYAnchor.constraint(equalTo: imageCard.centerYAnchor, constant: 0)
        scanLineCenterY = centerY
        let halfScreen = imageCard.heightAnchor.constraint(
            equalTo: view.heightAnchor, multiplier: 0.50)
        halfScreen.priority = .required
        NSLayoutConstraint.activate([
            imageCard.topAnchor.constraint(equalTo: cardWrap.topAnchor),
            imageCard.bottomAnchor.constraint(equalTo: cardWrap.bottomAnchor),
            imageCard.centerXAnchor.constraint(equalTo: cardWrap.centerXAnchor),
            imageCard.widthAnchor.constraint(lessThanOrEqualTo: cardWrap.widthAnchor),
            halfScreen,
            scanLine.leadingAnchor.constraint(equalTo: imageCard.leadingAnchor),
            scanLine.trailingAnchor.constraint(equalTo: imageCard.trailingAnchor),
            scanLine.heightAnchor.constraint(equalToConstant: 26),
            centerY,
        ])
        let dim = UIView()
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.20)
        dim.isUserInteractionEnabled = false
        dim.translatesAutoresizingMaskIntoConstraints = false
        imageCard.addSubview(dim)
        NSLayoutConstraint.activate([
            dim.topAnchor.constraint(equalTo: imageCard.topAnchor),
            dim.bottomAnchor.constraint(equalTo: imageCard.bottomAnchor),
            dim.leadingAnchor.constraint(equalTo: imageCard.leadingAnchor),
            dim.trailingAnchor.constraint(equalTo: imageCard.trailingAnchor),
        ])

        let scanningLbl = UILabel()
        scanningLbl.attributedText = NSAttributedString(
            string: "SCANNING",
            attributes: [
                .kern: 3.6,
                .foregroundColor: Theme.red,
                .font: Theme.label(size: 11),
            ]
        )
        scanningLbl.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [
            cardWrap,
            UIViewIM.spacer(8),
            scanningLbl,
            UIViewIM.spacer(2),
            pctLabel,
            UIViewIM.spacer(8),
            pctBar,
        ])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 0
        return stack
    }

    private func makeRepliesView(_ data: Data, _ replies: [RizzReplyItem]) -> UIView {
        let imageThumb = UIImageView(image: UIImage(data: data))
        imageThumb.clipsToBounds = true
        imageThumb.layer.cornerRadius = 12
        imageThumb.contentMode = .scaleAspectFill
        imageThumb.translatesAutoresizingMaskIntoConstraints = false
        imageThumb.heightAnchor.constraint(equalToConstant: 56).isActive = true
        imageThumb.widthAnchor.constraint(equalToConstant: 56).isActive = true

        let caption = UILabel()
        caption.attributedText = NSAttributedString(
            string: "TAP A REPLY TO INSERT",
            attributes: [
                .kern: 3.0,
                .foregroundColor: Theme.textTertiary,
                .font: Theme.label(size: 10.5),
            ]
        )
        caption.numberOfLines = 0

        let captionRow = UIStackView(arrangedSubviews: [imageThumb, caption])
        captionRow.axis = .horizontal
        captionRow.alignment = .center
        captionRow.spacing = 12

        let chipStack = UIStackView()
        chipStack.axis = .vertical
        chipStack.spacing = 8
        for r in replies {
            chipStack.addArrangedSubview(makeReplyChip(r))
        }

        let stack = UIStackView(arrangedSubviews: [
            captionRow,
            UIViewIM.spacer(10),
            chipStack,
        ])
        stack.axis = .vertical
        stack.alignment = .fill
        return stack
    }

    private func makeReplyChip(_ r: RizzReplyItem) -> UIView {
        let chip = UIControl()
        chip.backgroundColor = Theme.surface1
        chip.layer.cornerRadius = 14
        chip.layer.borderColor = Theme.divider.cgColor
        chip.layer.borderWidth = 0.8
        chip.translatesAutoresizingMaskIntoConstraints = false

        let tag = UILabel()
        tag.attributedText = NSAttributedString(
            string: r.tag,
            attributes: [
                .kern: 2.4,
                .foregroundColor: Theme.red,
                .font: Theme.label(size: 9.5),
            ]
        )

        let body = UILabel()
        body.text = r.text
        body.font = Theme.body(size: 14)
        body.textColor = Theme.textPrimary
        body.numberOfLines = 3

        let stack = UIStackView(arrangedSubviews: [tag, body])
        stack.axis = .vertical
        stack.spacing = 3
        stack.alignment = .leading
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false

        chip.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: chip.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: chip.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: chip.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: chip.trailingAnchor, constant: -14),
        ])
        chip.accessibilityValue = r.text
        chip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        return chip
    }

    private func makeErrorView(_ msg: String) -> UIView {
        let card = UIView()
        card.backgroundColor = Theme.surface1
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 0.8
        card.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.45).cgColor

        let title = UILabel()
        title.text = msg
        title.font = Theme.body(size: 13, weight: .semibold)
        title.textColor = Theme.textPrimary
        title.textAlignment = .center
        title.numberOfLines = 0

        let retry = makeOutlinePill(text: "TRY AGAIN")
        let tap = UITapGestureRecognizer(target: self, action: #selector(retryWaiting))
        retry.addGestureRecognizer(tap)

        let stack = UIStackView(arrangedSubviews: [title, retry])
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
        ])
        return card
    }

    private func makeRedPill(text: String) -> UIView {
        let pill = UILabel()
        pill.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .kern: 3.2,
                .foregroundColor: Theme.red,
                .font: Theme.label(size: 11),
            ]
        )
        pill.textAlignment = .center
        pill.backgroundColor = Theme.redDim
        pill.layer.cornerRadius = 99
        pill.layer.masksToBounds = true
        pill.layer.borderWidth = 0.9
        pill.layer.borderColor = Theme.red.withAlphaComponent(0.65).cgColor

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(pill)
        pill.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pill.topAnchor.constraint(equalTo: container.topAnchor),
            pill.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            pill.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            pill.heightAnchor.constraint(equalToConstant: 32),
            pill.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])
        return container
    }

    private func makeOutlinePill(text: String) -> UIView {
        let pill = UILabel()
        pill.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .kern: 3.0,
                .foregroundColor: Theme.textSecondary,
                .font: Theme.label(size: 10.5),
            ]
        )
        pill.textAlignment = .center
        pill.layer.cornerRadius = 99
        pill.layer.masksToBounds = true
        pill.layer.borderWidth = 0.8
        pill.layer.borderColor = Theme.textTertiary.cgColor
        pill.isUserInteractionEnabled = true

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(pill)
        pill.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pill.topAnchor.constraint(equalTo: container.topAnchor),
            pill.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            pill.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            pill.heightAnchor.constraint(equalToConstant: 30),
            pill.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])
        container.isUserInteractionEnabled = true
        return container
    }

    private func animatePulse(_ v: UIView) {
        UIView.animate(
            withDuration: 1.2,
            delay: 0,
            options: [.repeat, .autoreverse, .curveEaseInOut, .allowUserInteraction],
            animations: { v.alpha = 0.55 }
        )
    }

    private func makeWordmark(size: CGFloat) -> NSAttributedString {
        let attr = NSMutableAttributedString()
        attr.append(NSAttributedString(
            string: "Im",
            attributes: [
                .font: Theme.wordmark(size: size),
                .foregroundColor: Theme.textPrimary,
                .kern: -0.5,
            ]
        ))
        attr.append(NSAttributedString(
            string: "Him",
            attributes: [
                .font: Theme.wordmark(size: size),
                .foregroundColor: Theme.red,
                .kern: -0.5,
            ]
        ))
        return attr
    }

    private func italic(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let d = base.fontDescriptor.withSymbolicTraits([.traitItalic]) {
            return UIFont(descriptor: d, size: size)
        }
        return base
    }

    // MARK: - Actions

    @objc private func chipTapped(_ sender: UIControl) {
        guard let text = sender.accessibilityValue else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // THE INSERT — drops the reply straight into iMessage's compose box.
        activeConversation?.insertText(text, completionHandler: nil)
        // Collapse back to compact mode so user sees the chat again.
        requestPresentationStyle(.compact)
    }

    @objc private func closeTapped() {
        requestPresentationStyle(.compact)
    }

    @objc private func retryWaiting() {
        lastConsumedAssetID = nil
        state = .waiting
        startPolling()
    }
}

// ── Scan line / spacer helpers ─────────────────────────────────────
final class _ScanLineViewIM: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let glow = CGGradient(
            colorsSpace: nil,
            colors: [
                Theme.red.withAlphaComponent(0.0).cgColor,
                Theme.red.withAlphaComponent(0.55).cgColor,
                Theme.red.withAlphaComponent(0.0).cgColor,
            ] as CFArray,
            locations: [0.0, 0.5, 1.0]
        )!
        ctx.drawLinearGradient(
            glow,
            start: CGPoint(x: rect.midX, y: 0),
            end:   CGPoint(x: rect.midX, y: rect.height),
            options: []
        )
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: rect.midY - 1, width: rect.width, height: 2))
    }
}

enum UIViewIM {
    static func spacer(_ h: CGFloat) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: h).isActive = true
        return v
    }
}

private extension RizzError {
    var userMessage: String {
        switch self {
        case .network(let m):  return "Network · \(m.prefix(48))"
        case .decode(let m):   return "Server · \(m.prefix(48))"
        }
    }
}

// ═════════════════════════════════════════════════════════════════════
//  Inlined Theme + RizzClient — same trick the Share Extension uses.
//  One source file, one entry in the installer's SOURCE_FILES list.
// ═════════════════════════════════════════════════════════════════════

enum Theme {
    static let base         = UIColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1.00)
    static let surface1     = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1.00)
    static let surface2     = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.00)
    static let surface3     = UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.00)
    static let divider      = UIColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 1.00)
    static let textPrimary  = UIColor.white
    static let textSecondary = UIColor(white: 1.00, alpha: 0.82)
    static let textTertiary = UIColor(white: 1.00, alpha: 0.58)
    static let red          = UIColor(red: 0.90, green: 0.22, blue: 0.27, alpha: 1.00)
    static let redDim       = UIColor(red: 0.90, green: 0.22, blue: 0.27, alpha: 0.18)
    static let accent       = UIColor(red: 0.55, green: 0.58, blue: 0.96, alpha: 1.00)

    static func wordmark(size: CGFloat) -> UIFont {
        let descriptor = UIFont.systemFont(ofSize: size, weight: .heavy)
            .fontDescriptor.withSymbolicTraits([.traitItalic])
        if let descriptor = descriptor {
            return UIFont(descriptor: descriptor, size: size)
        }
        return UIFont.systemFont(ofSize: size, weight: .heavy)
    }
    static func label(size: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .black)
    }
    static func body(size: CGFloat, weight: UIFont.Weight = .medium) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: weight)
    }
}

struct RizzReplyItem {
    let text: String
    let tag:  String
}

enum RizzError: Error {
    case network(String)
    case decode(String)
}

final class RizzClient {
    private let host = URL(string: "https://mirrorly-production.up.railway.app")!
    var preferredVibe: String { "playful" }

    func fetchReplies(
        screenshot: Data,
        completion: @escaping (Result<[RizzReplyItem], RizzError>) -> Void
    ) {
        let payloadImage = compress(screenshot) ?? screenshot
        let b64 = payloadImage.base64EncodedString()
        let body: [String: Any] = [
            "vibe":        preferredVibe,
            "ctx":         "imessage",
            "scenario":    "",
            "imageBase64": b64,
        ]
        var req = URLRequest(url: host.appendingPathComponent("rizz/reply"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 45
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.network("encode: \(error)")))
            return
        }
        URLSession.shared.dataTask(with: req) { data, _, err in
            if let err = err {
                DispatchQueue.main.async { completion(.failure(.network(err.localizedDescription))) }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(.network("no data"))) }
                return
            }
            do {
                guard
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let replies = json["replies"] as? [[String: Any]]
                else {
                    let bodyStr = String(data: data, encoding: .utf8)?.prefix(120) ?? ""
                    DispatchQueue.main.async { completion(.failure(.decode("shape: \(bodyStr)"))) }
                    return
                }
                let mapped: [RizzReplyItem] = replies.compactMap {
                    guard let text = ($0["text"] as? String ?? $0["line"] as? String)?
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                          !text.isEmpty
                    else { return nil }
                    let tag = ($0["tag"] as? String ?? "RIZZ").uppercased()
                    return RizzReplyItem(text: text, tag: tag)
                }
                DispatchQueue.main.async { completion(.success(Array(mapped.prefix(3)))) }
            } catch {
                DispatchQueue.main.async { completion(.failure(.decode(error.localizedDescription))) }
            }
        }.resume()
    }

    private func compress(_ data: Data) -> Data? {
        guard let img = UIImage(data: data) else { return nil }
        let maxEdge: CGFloat = 1600
        let w = img.size.width, h = img.size.height
        let scale = min(1.0, maxEdge / max(w, h))
        let target = CGSize(width: w * scale, height: h * scale)
        UIGraphicsBeginImageContextWithOptions(target, true, 1.0)
        img.draw(in: CGRect(origin: .zero, size: target))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized?.jpegData(compressionQuality: 0.78)
    }
}
