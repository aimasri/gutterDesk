<div align="center">
  <img src="assets/logo/gutterdesk_logo.png" alt="gutterDesk Logo" width="480">
  <p><strong>The Tactile, Edge-Driven Productivity Suite &amp; Desktop Linux Distro</strong></p>
  <p>Built on Debian 13 (Trixie) · Openbox · Tint2 · GNU Stow · Modular Checkbox Engine</p>
</div>

---

## Overview

**gutterDesk** is a reproducible, minimalist Linux distribution designed for focused, keyboard-driven productivity. It serves as the operating system foundation for the **gutter** productivity suite, integrating **gutterDeck** (accordion app compositor dock) and **gutterTab** (edge-docked note & prompt drawer) directly into the X11 desktop environment.

### Core Highlights
* **Universal Base Core:** Boots to an ultra-lightweight environment consuming <400MB idle RAM.
* **Midnight Forest Theme:** Custom muted forest-dark palette with translucent Tint2 panels and Openbox window framing.
* **Modular Checkbox Deployment:** A single post-install interactive wizard (`./install.sh`) lets you enable Creative, Media, Web, or Trading stacks on demand.
* **Dual-Monitor Smart Wallpapers:** Automatically detects portrait and landscape display heads (`auto-wallpaper.sh`) and assigns orientation-matched wallpapers per monitor.
* **Zero Configuration Drift:** Every dotfile is managed declaratively through GNU Stow.

---

## Quickstart

### 1. Bootstrap Universal Base OS
On a fresh minimal Debian 13 installation:

```bash
git clone https://github.com/aimasri/gutterDesk.git ~/projects/gutterDesk
cd ~/projects/gutterDesk
./bootstrap.sh
```

### 2. Enable Functional Modules
Select and provision optional modules:

```bash
./install.sh
```

---

## The gutter Productivity Family

| Component | Role | Description |
| :--- | :--- | :--- |
| **[gutterDesk](https://github.com/aimasri/gutterDesk)** | Desktop Operating System | Minimalist, reproducible Debian 13 distribution with Openbox + Tint2. |
| **[gutterDeck](https://github.com/aimasri/gutterDeck)** | Desktop Compositor Dock | 10-channel edge accordion dock for instant application launching. |
| **[gutterTab](https://github.com/aimasri/gutterTab)** | Edge Note &amp; Prompt Daemon | Edge-docked note drawer with prompt templates and directory bookmarks. |

---

## Repository Structure

```
gutterDesk/
├── bootstrap.sh                 # Universal Base OS bootstrap script
├── install.sh                   # Interactive modular checkbox installer
├── gutterdesk_spec.md           # Architecture and technical specification
├── installation_roadmap.md      # Step-by-step deployment guide
├── assets/                      # Vector and raster logo and icon assets
├── wallpapers/                  # Dynamic landscape and portrait wallpapers
├── packages/                    # Declarative package lists (base, creative, web, etc.)
├── dotfiles/                    # GNU Stow dotfile hierarchies (openbox, tint2, pcmanfm)
└── modules/                     # Standalone module provisioning scripts
```

---

## License
MIT License. Open for modification and community deployment.
