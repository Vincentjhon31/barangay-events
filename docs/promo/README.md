# Promo package — eBongabong Calendar

A ~90-second, 16:9 narrated motion graphic promoting the app. Built without any AI video
service: the motion is real CSS animation over real app screenshots, recorded off screen.

| File | What it is |
|---|---|
| `reel.mp4` | **The video.** 1920×1080, 30fps, 90.00s, H.264. |
| `reel.webm` | Same render, VP8/WebM. Not in git (36 MB duplicate); `render.mjs` regenerates it. |
| `reel.html` | The source the video is rendered from — a self-contained animated page. |
| `render.mjs` | Renders `reel.html` to video frame by frame (see below). |
| `narration.md` | The voiceover — timed per beat, plus a continuous read for a single take. |
| `storyboard.md` | The 14-shot breakdown: timecodes, on-screen text, assets, motion notes. |
| `shots/` | Real screenshots captured from the app, consumed by `reel.html`. |

The older `../promo-script-and-flow.md` is the original source material this was built from and is
left untouched.

## Watch it

Open `reel.html` in Chrome. It starts immediately and runs for exactly 90 seconds.

- **R** restarts the animation from 0:00
- **D** toggles a timecode readout for checking against `storyboard.md` (hidden by default, so
  it never appears in a recording unless you turn it on)
- `reel.html?t=53` freezes the reel at 53 seconds — handy for inspecting one shot without
  waiting for it to come round

The page is authored at exactly 1920×1080 and scales itself to fit whatever window it is in, so
it looks correct at any size but records cleanly at 1080p.

## Re-render the video

`render.mjs` renders the reel offline, frame by frame — it is **not** a screen recording. It
drives Chrome over the DevTools protocol, seeks the CSS animations to an exact timestamp per
frame, screenshots that frame, and pipes it straight into ffmpeg. Nothing depends on window
focus, frame drops, or the machine being idle, and the output is exactly 90.00s at a true 30fps.

```sh
export FFMPEG_BIN="$(python -c 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())')"
node docs/promo/render.mjs docs/promo/reel.mp4      # H.264 / MP4
node docs/promo/render.mjs docs/promo/reel.webm     # VP8 / WebM
```

The output extension picks the codec: `.mp4` → libx264 (preset slow, CRF 19, `+faststart`),
anything else → VP8. `FPS` and `DURATION` env vars override the defaults (30 / 90); a short
`FPS=10 DURATION=2` run is a quick smoke test. Expect roughly 4–5 minutes for the full 90s,
paced by screenshot throughput rather than encoding.

**ffmpeg note.** A full ffmpeg is required for MP4. This machine has one via
`pip install imageio-ffmpeg` (user-level, no admin) — that is what `FFMPEG_BIN` points at above.
Without `FFMPEG_BIN` the script falls back to Playwright's bundled ffmpeg, which is a stripped
build that can only produce **VP8/WebM** — it has no H.264 encoder and no MP4 muxer. That build
also cannot probe a piped stream, which is why the input codec is named explicitly (`-c:v mjpeg`).

## Adding the voiceover

The picture has no audio track. Record `narration.md` separately, then lay it over the video in
any editor (Clipchamp ships with Windows and is enough for this). The beat timecodes in
`narration.md` and `storyboard.md` are identical, so the audio lines up without guesswork.

## If a screenshot is missing

Every screen in `reel.html` has two layers: the real capture from `shots/`, and behind it a CSS
recreation built from the app's own constants (`lib/liquid_glass_components.dart` for the glass,
gradients and radii; `lib/event_colors.dart` for the event chip colors). If a capture is absent
the `onerror` guard drops the image and the recreation shows through — so the reel always plays,
it just loses some fidelity on that shot.

To add or replace a capture, drop a PNG into `shots/` under the filename `storyboard.md` lists
for that shot. No other change is needed.

## Regenerating the captures

Every screen in the reel is a real capture from the running app. `storyboard.md` under *Asset
dependency* lists which file each shot expects — and flags the two things that were redacted
before capture (a pre-filled personal mobile number, and the group invite codes).

The public calendar needs no login — the welcome screen offers **Continue as Guest**. The
new-event form, join-code screen and group member list need a signed-in account. With the app
installed on a booted emulator:

```sh
# clean status bar first (no emulator clock or debug icons in shot)
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0930
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false

adb exec-out screencap -p > docs/promo/shots/calendar-month.png
```

Build and install with `flutter build apk --release --target-platform android-x64` then
`adb install -r build/app/outputs/flutter-apk/app-release.apk`. Use a **release** build — a debug
build paints a DEBUG ribbon across the corner of every screenshot.

**Before capturing any signed-in screen, check the frame for two things:** the *Contact number*
field on the Add Event form pre-fills from your profile, and the group admin page prints the
group's invite code in plain view. Neither belongs in a video.
