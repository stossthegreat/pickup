# App Store — App Review Information

Answers the Guideline 2.1 "Information Needed" request. **Paste the block below
into App Store Connect → App Review Information → Notes**, attach the screen
recording, and fill in the real devices in item 2.

---

## ⬇️ PASTE THIS INTO THE NOTES FIELD ⬇️

```
Thank you for reviewing ImHim. Responses below correspond to items 1–7.

1. SCREEN RECORDING
Attached. Captured on a physical iPhone 12 running the latest iOS. It begins by
launching the app, goes through onboarding, then walks the core flow: the
Practice tab (opening an AI character and texting her), a live voice roleplay
(which shows the microphone permission prompt), the Texts tab (picking a
conversation screenshot via the iOS system photo picker and getting reply
suggestions), and the Missions/Progress tabs. It also shows the subscription
paywall appearing when a paid feature is tapped.

2. DEVICES / OS TESTED
- iPhone 12 (physical device), running the latest iOS.

3. PURPOSE & TARGET AUDIENCE
ImHim is a social-confidence practice app for adults (17+). It helps people who
freeze up in dating and social situations build confidence by practising
conversations with fictional AI characters — over text and live voice — and
following a 60-day plan with feedback across five conversation skills. The
problem it solves: people avoid approaching, overthink their texts, and never
actually practise. ImHim is a private, low-stakes place to rehearse. All
characters are AI-generated; the app does not connect users to real people.

The app's model is practise-then-apply: users first rehearse with the AI
characters, then optionally try the same skills in real life. ImHim never
connects users to real people and never instructs anything unsafe, illegal, or
manipulative. The real-world prompts are optional confidence challenges (e.g.
"make eye contact and smile," "start one conversation") that the user marks done
themselves — there is no in-app action beyond a checkmark. This mirrors
established exposure-based confidence and social-anxiety apps.

4. ACCESSING THE MAIN FEATURES
There is no account, login, or registration — the app opens straight into the
main tabs, which are free to browse. The paid features are a weekly
auto-renewable subscription (product ID: imhim_pro_weekly). To test:
- Sign into a Sandbox Apple ID (Settings > App Store > Sandbox Account).
- Tap any character in the Practice tab, or any mission in the Missions tab —
  the paywall appears. It shows the subscription title, length, price, and links
  to the Terms of Use and Privacy Policy. The paywall is dismissible; browsing
  the app is free.
- Purchase the weekly subscription (free in Sandbox) — the app unlocks. You can
  then text a character or start a live voice roleplay.
Because there is no account, there is no login/deletion flow; users can still
request data deletion at https://stossthegreat.github.io/pickup/delete.html

5. EXTERNAL SERVICES
- OpenAI — generates the AI text and live voice roleplay replies.
- Apple StoreKit + RevenueCat — the auto-renewable subscription and receipt
  validation.
- Google ML Kit (on-device) — extracts text from a user-selected screenshot in
  the Texts feature; the image never leaves the device.
- Google Firebase — anonymous usage analytics only (no PII, no ad IDs).
No user accounts and no third-party advertising networks.

6. REGIONAL DIFFERENCES
None. The app functions consistently across all regions. All content is in
English.

7. REGULATED INDUSTRY / THIRD-PARTY MATERIAL
Not applicable. ImHim is an entertainment and self-improvement app. All AI
characters are fictional and AI-generated — no real people, likenesses, brands,
or protected third-party material are used. AI responses come from the OpenAI
API.

PERMISSIONS
- Microphone — used during live voice roleplay so the user can speak and hear a
  spoken reply. Audio is sent to OpenAI to generate the reply, then discarded.
- Photos — the Texts feature uses the iOS system photo picker to read one
  screenshot the user chooses. No photo-library permission is requested (the
  picker returns only the selected image); text is extracted on-device (Google
  ML Kit) and only that text is sent. The camera is used only if the user
  chooses the "take a photo" option.

Contact: info@m2mb.co.uk
```

## ⬆️ END OF PASTE BLOCK ⬆️

---

### Recording checklist (for you)
- The **only guaranteed permission prompt is the Microphone** one — capture it
  during the voice roleplay. There is **no** photo-library prompt (the system
  photo picker doesn't need one). The Camera prompt appears only if you demo the
  "take a photo" option in Texts — optional.
- Show the paywall appearing on a paid tap, and that browsing is otherwise free.

### Before you upload the submission binary (internal — do NOT paste)
- `kBypassPaywall = false` and `kPaywallDemoUnlock = false` (real paywall).
- `PurchaseConfig.enabled = true`, iOS key set, `proEntitlementId = 'pro'`.
- Confirm on a Sandbox device that the paywall shows a **real price** (not "—"),
  which proves `imhim_pro_weekly` is fetchable and there's no error 23.
