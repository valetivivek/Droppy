## 🚀 Droppy v11.1.0

Sorry from Jordy (the developer) for moving Droppy to paid. To make that transition fair, v11.1.0 starts with a full **3-day trial** so you can test everything first.

## ⭐ Biggest updates
- Added a full **3-day Droppy trial**. Try everything free for 3 days, then purchase only if you want to keep it.
- Added stronger licensing enforcement and fixes:
  - Fixed a licensing bug.
  - Closed a seat-limit loophole by applying the same seat-limit check during stored-license verification (not only on new activation).
- Added an **all-new stacked file preview system** across Droppy:
  - New stacked previews in Shelf and Basket.
  - Updated Basket switcher with stacked files and better responsiveness.
  - Task bar now auto-selects when opening the notch.
- Added broad animation/feel upgrades:
  - Improved opening/closing animations for Shelf, Media HUD, and more.
  - Improved animation fluidity across Droppy.
  - Stabilized/optimized animations when adding many files to Shelf, including a subtle batch-add animation.

## ✨ Core UX and behavior improvements
- Added notch width controls: make it narrower or wider, with smooth animation and haptics.
- Added per-display auto-expand controls: configure main Mac and external displays separately.
- When **High Alert** is on, hover expansion is disabled (click required), so hover can reliably show remaining High Alert time.
- Updated Finder extension setup flow to be clearer and more visible.
- Replaced the duplicate “Settings” header label with the current section title (for example, “Quickshare”).
- Extension divider/line behavior cleanup:
  - Extension lines now continue fully to the container border.
  - Separator now renders as a neutral vertical line instead of a chevron.
  - When separator is off, hidden delimiter control collapses to zero width.
- Cleaned up multiple extension windows.
- Removed forced auto-rename after folder creation (no misleading immediate-cancel flow).
- Added missing **Show in Finder** action to shelf item context actions.
- Fixed shelf auto-collapse behavior so it uses geometric hover + expanded-content hover (not stale notch-hover state).
- Added local + global ESC monitors so Escape works regardless of key-window focus.
- Fixed menu bar click-through with expanded shelf by allowing top-strip pass-through outside the notch trigger area.

## 📤 Quickshare and sharing
- Quickshare now uses a more defensive upload pipeline (including directory handling and guaranteed state cleanup), fixing failed uploads.
- Added Quickshare option to require confirmation before uploading.
- Quickshare now accepts links.
- Fixed sharing files via mail in Outlook (now opens a prefilled mail with the file attached).

## 📸 Capture, OCR, and media pipeline fixes
- Fixed Element Capture flow; area capture, full-screen capture, and OCR capture now work reliably.
- Region/OCR overlay now forces a crosshair cursor while active, giving a clear selection-mode indicator.
- Improved OCR reliability and result routing to the same display where capture was taken.
- Added explicit feedback when OCR detects no text.
- Fixed screenshot editing so it now saves the correct image.
- Fixed AI background removal visibility/output issues.
- Fixed long voice-transcription overlay behavior:
  - No longer auto-hides after 60s during long jobs.
  - Added persistent processing status + elapsed time in manager and overlay UI.

## 🎛️ Display, HUD, and device integration
- Implemented #191: hardware DDC/CI external-display volume control with fallback to existing system-volume path.
- Implemented Lunar compatibility fix in `BrightnessManager` so Droppy can surface HUD updates from polled brightness deltas while keeping normal polling quiet to avoid auto-brightness noise.
- Fixed #194: stabilized built-in display brightness step math so float residue can’t cause a phantom extra 0 step.
- Fixed #198: targeted notch-centering fix for external-primary-display setups.
- Fixed external HUD reveal race where percentage text appeared before notch expansion.
- Fixed lock-screen HUD jumping position after docking/undocking.
- Improved lock/unlock lock-screen HUD animations for smoother transitions.

## 📷 Notchface and Reminders upgrades
- Notchface now uses smarter camera discovery (external/USB cameras first, then fallback).
- Added manual camera picker in Notchface extension window.
- Fixed Reminders extension calendar-permission flow.
- Added the all-new calendar view in Droppy.
- Fixed ToDo permission retry focus-steal path so background Reminders/Calendar sync retries no longer pull focus while typing in other apps.

## 🧠 Stability and quality fixes
- Fixed a critical long-run memory leak in Menu Bar Manager.
- Fixed Menu Bar Manager settings sheet sizing on small displays by constraining height to visible screen bounds.
- Fixed drag-out-of-shelf behavior that could incorrectly trigger basket/switcher prompts.
- Improved basket quick-action reliability.
- Fixed basket/shelf file shortcut behavior (Cmd+A, click-outside deselect, Shift-select).
- Favorited/flagged clipboard entries now always appear correctly.
- Tag manager in Clipboard now adapts to the active color scheme correctly.
- Fixed mini-player reappearance caused by noisy media updates resetting `mediaHUDFadedOut`.
- Implemented #196 in `MusicManager.swift`: debounced track-change path now preserves duration/elapsed values correctly.
- Locked down automatic/background window presentation paths so they wait until Droppy is active/frontmost (while keeping intentional user-triggered activations working).
- Fixed Notify Me overlay interaction blocking so it no longer blocks a large area of the screen.
- Added scrolling file names on Shelf items so long names are visible on hover.
