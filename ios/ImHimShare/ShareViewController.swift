//
//  ShareViewController.swift
//  ImHimShare
//
//  WingAI-style Share Extension. The user taps Share on a screenshot,
//  picks ImHim, and a panel slides up from the bottom containing OUR
//  UI — not the main app. Inside that panel:
//
//    Header  — ImHim wordmark + close X
//    Image   — the screenshot, rounded card, dimmed slightly
//              + a red scan line travelling top → bottom → top
//    Status  — SCANNING NN%   thin red progress bar
//    Chips   — three reply options, tap to copy to clipboard
//
//  When the user taps a chip, the text lands on the clipboard, a brief
//  "COPIED" pill confirms, the panel auto-dismisses and they paste
//  straight into whatever chat they were composing. No app launch.
//

import UIKit
import UniformTypeIdentifiers

@objc(ShareViewController)
class ShareViewController: UIViewController {

    // MARK: - State

    private enum State {
        case extracting           // pulling the image out of extensionContext
        case scanning(Data)       // we have bytes, calling /rizz/reply
        case replies(Data, [RizzReplyItem])
        case error(String)
    }

    private var state: State = .extracting { didSet { render() } }
    private let client = RizzClient()

    // Two animation controllers — scan line + percentage. Spun up in
    // viewDidLoad and torn down in deinit.
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

    // Persistent views the scanning state animates — image card + scan
    // line + percentage label + bar. Kept around across renders so the
    // CADisplayLink can mutate them without rebuilding the tree on
    // every frame.
    private let imageCard: UIImageView = {
        let iv = UIImageView()
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 18
        iv.contentMode = .scaleAspectFill
        iv.backgroundColor = Theme.surface2
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    private let scanLine = _ScanLineView()
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
            rootStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])

        rootStack.addArrangedSubview(headerRow)
        rootStack.addArrangedSubview(bodyContainer)

        extractImage()
    }

    deinit {
        scanCtl?.invalidate()
        pctCtl?.invalidate()
    }

    // MARK: - Extraction

    private func extractImage() {
        guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            state = .error("No screenshot in the share.")
            return
        }
        for item in inputItems {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadItem(
                        forTypeIdentifier: UTType.image.identifier,
                        options: nil
                    ) { [weak self] item, _ in
                        DispatchQueue.main.async {
                            self?.handleLoaded(item)
                        }
                    }
                    return
                }
            }
        }
        state = .error("Couldn't find an image to scan.")
    }

    private func handleLoaded(_ item: NSSecureCoding?) {
        var data: Data?
        if let url = item as? URL {
            data = try? Data(contentsOf: url)
        } else if let image = item as? UIImage {
            data = image.jpegData(compressionQuality: 0.92)
        } else if let raw = item as? Data {
            data = raw
        }
        guard let data = data else {
            state = .error("That image couldn't be read.")
            return
        }
        state = .scanning(data)
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
        // 1.4s up + 1.4s down = 2.8s cycle. Eased ping-pong via abs(sin).
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
        // Eases 0 → 96 over 14s, then idles. Replies arriving stops
        // the link entirely — the user sees the chips appear, which
        // IS the 100%.
        let elapsed = min(CACurrentMediaTime() - pctStart, 14)
        let progress = pow(1 - (1 - elapsed / 14), 3) // easeOutCubic
        let pct = Int((progress * 96).rounded())
        pctLabel.attributedText = NSAttributedString(
            string: "\(pct)%",
            attributes: [
                .font: italic(size: 42, weight: .heavy),
                .foregroundColor: Theme.textPrimary,
            ]
        )
        let m = NSMutableAttributedString(attributedString: pctLabel.attributedText!)
        m.addAttribute(.foregroundColor, value: Theme.red, range: NSRange(location: m.length - 1, length: 1))
        pctLabel.attributedText = m
        pctBar.setProgress(Float(pct) / 100, animated: false)
    }

    // MARK: - Render

    private func render() {
        bodyContainer.subviews.forEach { $0.removeFromSuperview() }
        let inner: UIView
        switch state {
        case .extracting:           inner = makeExtractingView()
        case .scanning(let data):   inner = makeScanningView(data)
        case .replies(let d, let r): inner = makeRepliesView(d, r)
        case .error(let m):         inner = makeErrorView(m)
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

    private func makeExtractingView() -> UIView {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = Theme.red
        spinner.startAnimating()
        let label = UILabel()
        label.text = "Reading screenshot…"
        label.textColor = Theme.textSecondary
        label.font = Theme.body(size: 13)
        label.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        return stack
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
        // Bro v195: "make it half screen while scanning" — pin the
        // card to roughly 40% of the share-extension's own height.
        // The extension is already a half-screen modal, so 0.40 of
        // its height lands the image at about a quarter of the
        // device screen, leaving the percentage + bar a clean
        // breathing block beneath it.
        let halfScreen = imageCard.heightAnchor.constraint(
            equalTo: view.heightAnchor, multiplier: 0.40)
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
        // Dim overlay so the scan reads cleanly over any photo.
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

        // SCANNING + percentage + progress bar.
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
            UIView.spacer(8),
            scanningLbl,
            UIView.spacer(2),
            pctLabel,
            UIView.spacer(8),
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
            string: "TAP A REPLY TO COPY",
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
            UIView.spacer(10),
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
        card.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = msg
        title.font = Theme.body(size: 13, weight: .semibold)
        title.textColor = Theme.textPrimary
        title.textAlignment = .center
        title.numberOfLines = 0
        title.translatesAutoresizingMaskIntoConstraints = false

        let close = UIButton(type: .system)
        close.setTitle("CLOSE", for: .normal)
        close.titleLabel?.font = Theme.label(size: 11)
        close.tintColor = Theme.textSecondary
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [title, close])
        stack.axis = .vertical
        stack.spacing = 12
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

    // MARK: - Actions

    @objc private func chipTapped(_ sender: UIControl) {
        guard let text = sender.accessibilityValue else { return }
        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showCopiedToast()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.closeTapped()
        }
    }

    @objc private func closeTapped() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func showCopiedToast() {
        let toast = UILabel()
        toast.attributedText = NSAttributedString(
            string: "COPIED · PASTE INTO YOUR CHAT",
            attributes: [
                .kern: 2.4,
                .foregroundColor: UIColor.white,
                .font: Theme.label(size: 11),
            ]
        )
        toast.backgroundColor = Theme.red
        toast.textAlignment = .center
        toast.layer.cornerRadius = 99
        toast.layer.masksToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),
            toast.heightAnchor.constraint(equalToConstant: 36),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
        ])
        toast.alpha = 0
        toast.transform = CGAffineTransform(translationX: 0, y: 12)
        UIView.animate(withDuration: 0.28) {
            toast.alpha = 1
            toast.transform = .identity
        }
    }

    // MARK: - Type helpers

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
}

// ── Scan line ────────────────────────────────────────────────────────
private final class _ScanLineView: UIView {
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
        // White core line in the middle.
        ctx.setFillColor(UIColor.white.cgColor)
        let core = CGRect(x: 0, y: rect.midY - 1, width: rect.width, height: 2)
        ctx.fill(core)
    }
}

private extension UIView {
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
