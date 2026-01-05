<p align="center">
  <img src="https://i.postimg.cc/9FxZhRf3/1024-mac.webp" alt="Droppy Icon" width="128">
</p>

<h1 align="center">Droppy</h1>

<p align="center">
  <strong>The ultimate productivity tool for macOS.</strong><br>
  <em>Notch Shelf • Floating Basket • Clipboard Manager</em><br>
  <br>
  Designed with ❤️ and pixel-perfect polish. Now featuring rich Interactive URL Previews in our Clipboard.
</p>

<p align="center">
    <img src="https://img.shields.io/github/v/release/iordv/Droppy?style=flat-square&color=007AFF" alt="Latest Release">
    <img src="https://img.shields.io/badge/platform-macOS_14+-lightgrey?style=flat-square" alt="Platform">
    <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License">
</p>

<p align="center">
  <a href="#installation">Installation</a> •
  <a href="#key-features">Features</a> •
  <a href="#usage">Usage</a> •
  <a href="#whats-new">Changelog</a>
</p>

---

## What is Droppy?

Droppy reimagines productivity on macOS by combining three essential tools into one seamless experience:

1.  **Notch Shelf**: A sleek holding zone hidden in your webcam notch.
2.  **Floating Basket**: Summon a drop zone anywhere with a quick mouse jiggle.
3.  **Clipboard Manager**: A powerful history tool with OCR, favorites, and instant search.

It's the perfect bridge between your apps, spaces, and workflow.

---

## ✨ Key Features

| Feature | Description |
|:--------|:------------|
| **🗂️ Notch Shelf** | Drag files to the Notch — they vanish into a sleek shelf, ready when you need them. |
| **🧺 Floating Basket** | **"Jiggle" your mouse** while dragging to summon a basket instantly at your cursor. |
| **📋 Clipboard Manager** | A powerful clipboard history with full **keyboard navigation**, **search**, **favorites**, and **OCR text extraction**. |
| **📦 Move To...** | Move files directly to saved folders (like your NAS) from the shelf. Non-blocking & fast. |
| **📉 Smart Compression** | Right-click to compress images, PDFs, and videos. Includes **Target Size** and **Size Guard** 🛡️. |
| **⚡️ Fast Actions** | Convert images, extract text (OCR), zip, rename — all directly in the shelf. |
| **🖥️ Multi-Monitor** | Works on external displays. Auto-hides during fullscreen games and videos. |

---

## 🕹️ Usage

### 1. Stash Files 📥
- **Notch Shelf**: Drag any file to the black area around your webcam. It snaps in.
- **Floating Basket**: While dragging, **shake your mouse left-right**. A basket appears instantly.

### 2. Quick Actions 🪄
Right-click any item to:
- **Move To...** — Send to saved favorites or NAS folders
- **Compress** — Auto or specify a target size
- **Convert** — e.g., HEIC → JPEG
- **Extract Text** — OCR to copy text from images
- **Share** or **Reveal in Finder**

### 3. Drop Files 📤
Drag files out of the shelf and drop into any app — email, Discord, Photoshop, Finder.  
**Poof** — the file moves and vanishes from the shelf.

### 4. Clipboard Manager 📋
| Action | How |
|:-------|:----|
| **Open** | `Cmd + Shift + Space` (customizable) |
| **Navigate** | Arrow keys to browse entries |
| **Paste** | `Enter` to paste instantly |
| **Search** | `Cmd + F` or click the search icon |
| **Favorite** | Click ⭐ — favorites float to the top |

### 📥 Smarter Links
- **Rich Interactive Previews**: Every URL now shows a detailed snippet with page titles, descriptions, and favicons.
- **Click to Open**: Click any link preview to jump straight to your browser. The clipboard closes automatically for a seamless workflow.
- **Direct Image Previews**: Links directly to images (`.png`, `.jpg`, `.avif`, etc.) display the actual image directly in your history.
- **Smart Detection**: Accurate plain-text link detection (even without `http://`) via `NSDataDetector`.

> **Works everywhere** — even in password fields and Terminal, thanks to low-level hotkey support.

---

## 🎨 Visual Tour

### The Notch Shelf
*Perfect for MacBook users. Utilizes the empty space around your webcam.*
<p align="center">
  <img src="https://i.postimg.cc/63TpswW4/image.png" alt="Notch Shelf Preview" width="100%">
</p>

### The Floating Basket
*Summoned anywhere with a quick jiggle. The perfect temporary holding zone.*
<p align="center">
  <img src="https://i.postimg.cc/50488cNj/image.png" alt="Floating Basket Preview" width="100%">
</p>

### The Clipboard Manager
*Your history, beautifully organized. Search, Edit, and Drag & Drop.*

<p align="center">
  <img src="https://i.postimg.cc/rpdpn8sH/image.png" alt="Multi-select, Favorite, and Paste" width="100%">
</p>

<p align="center">
  <img src="https://i.postimg.cc/63npKYdc/image.png" alt="Rename, Copy, and Delete" width="100%">
</p>

---

## 🛠️ Power User Tips

### 📉 Smart Compression
- **Auto**: Uses HEVC for videos (1080p) and balanced settings for images
- **Target Size**: Need under 2MB? Right-click → Compress → **Target Size...**
- **Size Guard**: If compression would make the file larger, Droppy keeps the original and shows a Green Shield 🛡️

### 📝 Drag-and-Drop OCR
1. Drag an image into Droppy
2. Hold **Shift** while dragging it out
3. Drop into a text editor — **it's text!**

---

## 📥 Installation

### Homebrew (Recommended)
```bash
brew install --cask iordv/tap/droppy
```

### Manual Download
1. Download [**Droppy.dmg**](https://github.com/iordv/Droppy/releases/latest)
2. Drag to Applications
3. **Right-click → Open** on first launch

> **Quarantine Issue?** If macOS says the app is damaged:
> ```bash
> xattr -d com.apple.quarantine /Applications/Droppy.app
> ```

---

## 🆕 What's New
<!-- CHANGELOG_START -->
## Droppy 4.0 — The HUD Update 🎛️

This is a HUGE update! Droppy now replaces the ugly macOS system HUDs with beautiful, animated overlays embedded right in your notch.

### ✨ New Features

**🎵 Media Player HUD**
- Full media controls directly in the notch
- Album art with smooth crossfade transitions between songs
- Interactive seek slider with tactile feedback
- Play/pause, skip forward/back controls
- Tap album art to open the source app (Safari, Spotify, etc.)
- Silky smooth collapse-expand animations

**🔊 Volume HUD**
- Beautiful volume indicator replaces the system HUD
- Animated icon that morphs between mute/low/high states
- Smooth liquid glass styling
- Percentage display with live updates

**🔆 Brightness HUD**
- Elegant brightness control overlay
- Dynamic sun icon animation
- Matches the volume HUD design language

### 🎨 Design
- All HUDs use the signature Liquid Glass aesthetic
- Crazy smooth spring animations throughout
- Perfectly synchronized transitions
- Icon-centric design that feels native to macOS

### 🔧 Improvements
- Fixed Homebrew quarantine issue — no more security dialogs on updates
- Optimized animation performance
- Better memory management for media metadata
<!-- CHANGELOG_END -->

---

## ❤️ Support
If you enjoy using Droppy, consider buying me a coffee to support development!

<p align="center">
  <a href="https://buymeacoffee.com/droppy">
    <img src="https://i.postimg.cc/yxRYWNqL/0x0.png" alt="Buy Me A Coffee" width="128">
  </a>
</p>

---

## License
MIT License. Free and Open Source forever.

Made with ❤️ by [Jordy Spruit](https://github.com/iordv)
