✨ New Features
- Added clipboard video playback - MP4, MOV, and other video files now play inline with full controls
- Added rich document previews for Word, Excel, PowerPoint, and PDF files in clipboard with multi-page support
- Added pinch-to-zoom for document previews (zoom 1x-5x with centered scaling)
- Added double-tap to toggle zoom and pan when zoomed in
- Added zoom controls overlay with zoom in/out buttons and percentage indicator
- Added subtle horizontal scrolling for long file names in shelf and basket views

🔧 Improvements  
- Optimized Dynamic Island padding (reduced from 30pt to 20pt for tighter, more elegant appearance)
- Increased Dynamic Island corner radius to 50pt for more pill-like, rounded aesthetic
- Fixed shelf grid horizontal padding (20pt for Dynamic Island, 30pt for notch modes)
- Fixed double clipping artifact on Dynamic Island expanded view
- Unified transparency logic for floating buttons across all display modes
- Improved consistency between Dynamic Island and external notch display modes

🐛 Bug Fixes
- Fixed volume/brightness HUD clipping at 100% on external notch style
- Fixed icon clipping on external notch style with proper padding
- Fixed battery/capslock/DND HUD widths for external displays
- Fixed all HUD views to properly respect external display style preference
- Fixed external display notch padding using correct Dynamic Island height

---

## Installation

<img src="https://raw.githubusercontent.com/iordv/Droppy/main/docs/assets/macos-disk-icon.png" height="24"> **Recommended: Direct Download** (signed & notarized)

Download `Droppy-10.0.1.dmg` below, open it, and drag Droppy to Applications. That's it!

> ✅ **Signed & Notarized by Apple** — No quarantine warnings, no terminal commands needed.

<img src="https://brew.sh/assets/img/homebrew.svg" height="24"> **Alternative: Install via Homebrew**
```bash
brew install --cask iordv/tap/droppy
```
