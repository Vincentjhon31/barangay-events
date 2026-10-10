# eBongabong Calendar — 90s Promo Storyboard

**Canvas:** 1920×1080 (16:9) · **Frame budget:** 90.0s · **Safe margin:** 96px all sides
**Type:** Display *Archivo* 700–800, tracking −0.02em · UI/body *IBM Plex Sans* 400–500
**Palette (from `lib/liquid_glass_components.dart`):** field `#05070C` → `#0A0D14` → `#06080D`,
cards `#121826`, orbs blue `#2B7FFF` / green `#1F9D65` / amber `#FFA726`, radii 28/22px,
borders `rgba(255,255,255,0.08–0.14)`, shadows `rgba(0,0,0,0.25–0.35)`
**Event chip colors (from `lib/event_colors.dart`):** peacock `#2B8FD6`, basil `#2FA36B`,
tomato `#E85D50`, tangerine `#F0932B`, grape `#9B59B6`, blueberry `#5B6ACF`

On-screen type minimums at 1080p: display 96px, subhead 44px, caption 28px — sized to stay
legible on a phone-sized preview of a 16:9 video.

---

## Shot list

| # | In–Out | Beat | On-screen text | Visual / asset | Motion |
|---|---|---|---|---|---|
| 1 | 0:00–0:04 | 1 | — | Dark field, three glass fragments adrift: a chat bubble, a feed post, a taped paper notice | Slow parallax drift; orbs breathe behind. No cuts. |
| 2 | 0:04–0:10 | 1 | **The news gets lost.** | Same fragments scatter outward and dim | Fragments push off-frame on ease-out; type rises 24px into place, 480ms |
| 3 | 0:10–0:16 | 2 | **eBongabong Calendar** <br><small>Community events, at a glance.</small> | Real app icon (`../store/ecalendar-icon.png`) over the glass title panel | Icon and panel bloom in, then a specular sweep crosses the glass |
| 4 | 0:16–0:22 | 2 | **Everything, in front of you.** | **Real capture** — `shots/calendar-month.png` in a phone frame | Frame scales 0.96→1 with blur ramp |
| 5 | 0:22–0:28 | 3 | **Labelled, every time.** <br><small>Month, week, list or day</small> | **Real capture** — `shots/event-list.png`, whose visible *Public* chips land under this beat's narration | Cross-slide in from the right, 480ms |
| 6 | 0:28–0:33 | 3 | **Public · Group · Personal** | Three glass chips fan out from the phone — peacock, basil, grape | Chips arc out on 40ms stagger, each settling with a 4px overshoot |
| 7 | 0:33–0:39 | 3 | **You choose who sees it.** | **Real capture** — `shots/add-event.png`, the Add Event form: Public/Group/Personal selector, colour labels, Attachments row | Frame scales 0.96→1 with blur ramp |
| 8 | 0:39–0:44 | 4 | **Share a code. They are in.** | **Real capture** — `shots/join-group.png`, the *Join with a code* screen incl. its private-group approval note | Frame scales 0.96→1 with blur ramp |
| 9 | 0:44–0:50 | 4 | **Admins keep it in order.** | **Real capture, cropped** — `shots/group-members-detail.png`, shown as a zoomed UI detail card rather than a phone screen | Card blooms in |
| 10 | 0:50–0:56 | 5 | **Official. With the paperwork.** | **Real capture** — `shots/event-detail.png` (time, location, posted-by, and the calendar-plus hand-off in its header) | Cross-slide in from the right, 480ms |
| 11 | 0:56–1:04 | 6 | **One tap to your own calendar** | Event card duplicates; the copy flies to a Google Calendar glyph | Duplicate arcs across frame, 560ms, trailing a soft blue streak |
| 12 | 1:04–1:13 | 7 | **Everyone knows. Right away.** | `shots/notification.png` banner drops in, then ripples out to five phone silhouettes | Banner drops with overshoot; concentric rings expand outward, 80ms stagger per phone |
| 13 | 1:13–1:21 | 8 | **Citizen · LGU staff · Administrator** | Three role cards deal in and stack | Cards deal in from below on 120ms stagger, each with a 2° rotation settling to 0° |
| 14 | 1:21–1:30 | 9 | **eBongabong Calendar** <br>**Connect. Coordinate. Celebrate.** <br><small>Municipality of Bongabong · Oriental Mindoro</small> | End card on the deep field, orbs full bloom | Wordmark settles at 1:22; the three words arrive one per second at 1:24, 1:25, 1:26; hold to 1:30 |

---

## Rules this storyboard holds to

- **No fake phone chrome.** No drawn iOS/Android status bar, no fake keyboard — the real
  screenshots carry whatever the device actually rendered.
- **No emoji, no dingbats.** All iconography is stroke-based inline SVG on a 24px grid,
  1.75px stroke, rounded caps, one family throughout.
- **One move per beat.** Each shot has a single orchestrated motion, not competing
  micro-animations. Easing is `cubic-bezier(0.22, 1, 0.36, 1)` for entrances, 320–560ms.
- **Glass is layered, not flat.** Every shot keeps three depth planes — orb field behind,
  glass panel mid, chip/type foreground — with parallax between them.
- **Real content only.** Event names in any mock or overlay content are real barangay
  activities: Barangay Assembly, Feeding Program, Basketball League Finals, Clean-Up Drive,
  Immunization Day, Fiesta Kickoff. No lorem ipsum, no invented statistics.
- **Grayscale check.** The reel must still read with color removed — hierarchy comes from
  scale and contrast, not hue alone.

## Asset dependency — what is real and what is not

Captured from the running app (release build on a Medium_Phone emulator, 1080×2400, status bar in
demo mode for a clean 9:30 clock):

| Shot | File | Screen |
|---|---|---|
| 4 | `shots/calendar-month.png` | Month view with live public events and the *Upcoming* card |
| 5 | `shots/event-list.png` | List view — real events, each with its *Public* chip |
| 10 | `shots/event-detail.png` | Event Details sheet for a real public event |

| 7 | `shots/add-event.png` | Add Event form — visibility selector, colour labels, Attachments |
| 8 | `shots/join-group.png` | *Join with a code* screen |
| 9 | `shots/group-members-detail.png` | Members list, cropped from the group admin page |

Every screen in the reel is now a real capture. The CSS recreations are still in the file behind
each image as an `onerror` fallback, so a missing or renamed PNG degrades to a recreation built
from the app's own constants rather than breaking the shot.

Also captured, not used in the reel: `shots/welcome.png` (guest / login screen) and
`shots/day-timeline.png` (Day view — left out because a single nine-hour event fills it with one
flat block, which reads poorly on video).

### Two deliberate redactions

Both were caught while reviewing the captures, and both would have shipped otherwise:

1. **A real mobile number.** The Add Event form pre-fills *Contact number* from the signed-in
   profile. It was cleared on the unsaved draft before capture, so the shot shows the
   placeholder `e.g. 0912 345 6789` instead.
2. **Group join codes.** The group admin page prints the 6-character invite code in plain view,
   and anyone who reads it off the video can join that group. The full-page capture is therefore
   *not* used — shot 9 uses a crop of the members list only. For the same reason the Groups
   overview screen (which lists every group's code) is not in the reel at all.

If either group's code has already been shown anywhere, rotate it.
