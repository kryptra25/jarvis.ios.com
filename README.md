# JARVIS for iPhone

An iOS port of your Android JarvisMobile app. Same persona, same dark UI, same
canned commands, same TTS sentence-queueing logic — but the AI brain now runs
**entirely on the phone** instead of talking to Ollama on your PC, so the app
works with Wi-Fi and cellular both switched off.

## What's different from the Android version, and why

| Android app | This iOS app | Why |
|---|---|---|
| Talks to Ollama on your PC over Tailscale | Runs a small AI model (Qwen2.5-0.5B, GGUF/llama.cpp) bundled inside the app itself | You asked for fully offline — no PC needs to be on, no network needed, ever |
| Background wake-word listening (foreground service) | Tap-to-talk only | iOS suspends background apps; there's no equivalent to Android's always-on foreground mic service, even when sideloaded. This was confirmed as the preferred tradeoff. |
| Launches any installed app by name | Can open built-in apps (Maps, Mail, Messages, Camera, Calendar, Music, Photos, Safari, Notes, Clock, Settings) via URL scheme | iOS sandboxes apps from each other — there's no API to list or launch arbitrary third-party apps by name |
| Settings: Ollama host/port/model | Settings: profile + which model file is bundled | No server to point at anymore |
| Weather via wttr.in (free, no key) | Same | This is the one feature that genuinely needs internet — there's no offline source of live weather |
| $0 cost, sideloaded | $0 cost, sideloaded via Sideloadly | No $99/year Apple Developer Program needed either way |

Everything else — the persona ("JARVIS, created by Kryptra"), the canned
commands (name/time/date/who-made-you), stop/sleep/shutdown phrases, the
sentence-by-sentence TTS queueing so responses never get cut off, the Face
ID/Touch ID gate, the dark blue color scheme — is ported as directly as
possible from your `MainActivity.kt`.

## The three things you need, and why

1. **Xcode** (free, Mac only) — compiles the Swift code into an app.
2. **Sideloadly** (free, Mac or Windows) — installs the compiled app onto
   your iPhone using your regular, free Apple ID. No $99/year developer
   account required.
3. A way to get step 1 done even if you don't own a Mac — see Option B below.

Apple ID code-signing certificates (free or paid) expire after **7 days** on
a free account, so Sideloadly will ask you to reconnect your phone and
re-install roughly once a week. This is a limitation of free Apple IDs, not
of this app or of Sideloadly.

---

## Option A — You have a Mac

This is the simplest path, and you don't strictly need Sideloadly at all:

```bash
brew install xcodegen
cd JarvisIOS
bash scripts/download_model.sh      # downloads the ~400MB on-device model
xcodegen generate                   # creates Jarvis.xcodeproj
open Jarvis.xcodeproj
```

In Xcode: plug in your iPhone, select it as the run destination, go to the
**Signing & Capabilities** tab of the Jarvis target, sign in with your free
Apple ID under Xcode → Settings → Accounts if you haven't already, pick your
personal team, and hit Run (▶). Xcode installs it directly — that's it.

If you'd rather produce a `.ipa` to install via Sideloadly instead (e.g. to
install on a phone that isn't plugged into that Mac), use Product → Archive,
then **Distribute App → Ad Hoc** (or Development), which signs it with your
free Apple ID and exports an `.ipa` you can hand to Sideloadly.

## Option B — You don't have a Mac (free cloud build)

This repo includes `.github/workflows/build-ipa.yml`, which builds an
**unsigned** `.ipa` for free using GitHub's hosted Mac runners. No Apple
account, certificates, or secrets are needed for this step — Sideloadly does
the actual signing afterward, locally, on your computer.

1. Push this folder to a new GitHub repository (public repos get free
   unlimited Actions minutes; private repos get a free monthly quota that's
   easily enough for occasional builds).
2. Go to the **Actions** tab → "Build unsigned IPA" → **Run workflow**.
3. Wait for it to finish (llama.cpp takes a few minutes to compile the first
   time), then download the `Jarvis-unsigned-ipa` artifact.
4. Unzip it — you now have `Jarvis-unsigned.ipa`.
5. Install [Sideloadly](https://sideloadly.io) on whatever computer you do
   have (Windows or Mac). On Windows you'll also need iTunes installed (just
   for the Apple device drivers, you don't need to use it).
6. Plug your iPhone in, drag `Jarvis-unsigned.ipa` into Sideloadly, enter
   your free Apple ID when prompted, and click Start. Sideloadly signs and
   installs it.
7. On the iPhone: Settings → General → VPN & Device Management → trust your
   Apple ID's developer profile (first install only).

Repeat step 6 roughly weekly when the signature expires (Sideloadly will
just reuse the same `.ipa` file — no rebuild needed unless you change the
code).

## Option C — Borrow a Mac just once

If you can get five minutes on literally any Mac (a friend's, a library,
work), Option A's `xcodegen generate && open Jarvis.xcodeproj` → Archive →
Export Unsigned/Ad Hoc gets you the same `.ipa` as Option B, and you never
need that Mac again — Sideloadly installs/reinstalls from your own PC after
that.

---

## Changing the on-device model

The default is Qwen2.5-0.5B-Instruct (Q4_K_M, ~400MB) — the same model
family as the Android app's default. It's fast and genuinely free, but it's
a small model, so don't expect GPT-4-level reasoning; it's well-suited to
short, conversational replies, which is exactly what the system prompt asks
for.

To use a bigger, smarter model instead (tradeoff: bigger download, slower
replies, needs a newer iPhone):

1. Edit `MODEL_URL` and the destination filename in `scripts/download_model.sh`.
2. Update `LocalLLMService.modelFileName` in
   `Sources/Services/LocalLLMService.swift` to match.
3. Re-run the download script (or re-run the GitHub Actions workflow) and
   rebuild.

Good options from bartowski's GGUF quantizations on Hugging Face:
`Qwen2.5-1.5B-Instruct-Q4_K_M.gguf` (~1.0GB, noticeably smarter) or
`Llama-3.2-3B-Instruct-Q4_K_M.gguf` (~2.0GB, best quality, wants a fairly
recent iPhone).

## Known limitations

- **No background wake word.** Tap the mic button instead — this was the
  tradeoff chosen over an unreliable background-audio hack.
- **"Open X" only works for built-in Apple apps**, not arbitrary third-party
  apps, due to iOS sandboxing.
- **Weather needs internet.** Everything else doesn't.
- **First app launch loads the model into memory**, which takes a couple of
  seconds — there's a status banner if it fails to load (it shouldn't, since
  it's bundled, but rebuilding without running the download script first is
  the most likely cause if you see it).
- **iOS 18.0+ required** (set by the on-device LLM library's minimum
  platform) — fine for any iPhone XS or newer that's been updated.

## Project structure

```
JarvisIOS/
  project.yml                     XcodeGen spec (generates the .xcodeproj)
  scripts/download_model.sh       Fetches the bundled GGUF model
  .github/workflows/build-ipa.yml Free cloud build → unsigned .ipa
  Sources/
    Models/                       Plain data types (profile, status, messages)
    State/JarvisViewModel.swift   Central brain — ports MainActivity.kt's logic
    Services/                     Speech, TTS, on-device LLM, weather, commands
    Views/                        SwiftUI screens
  Resources/
    Models/                       Where the .gguf model file lands
    Assets.xcassets/              App icon + accent color
```

If you change the package name/version that `LocalLLMService.swift` talks to
(`ShenghaiWang/SwiftLlama`), that's the one file to revisit — everything else
in the app calls into `LocalLLMService`, never into SwiftLlama directly.
