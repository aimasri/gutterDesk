#!/usr/bin/env python3
"""
generate_plymouth_assets.py - Generates boot splash visual assets for gutterDesk Plymouth theme.
"""

import os
import math
import subprocess
from PIL import Image, ImageDraw

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
THEME_DIR = os.path.join(REPO_ROOT, "themes", "plymouth", "gutterdesk")
os.makedirs(THEME_DIR, exist_ok=True)

# -------------------------------------------------------------
# 1. Generate logo.svg and render logo.png (Centered Emblem + Wordmark)
# -------------------------------------------------------------
LOGO_SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 440 320" width="440" height="320">
  <defs>
    <!-- Brand Color Gradients -->
    <linearGradient id="g1" x1="0%" y1="0%" x2="0%" y2="100%"><stop offset="0%" stop-color="#38e2fc"/><stop offset="100%" stop-color="#06b6d4"/></linearGradient>
    <linearGradient id="g2" x1="0%" y1="0%" x2="0%" y2="100%"><stop offset="0%" stop-color="#7dd3fc"/><stop offset="100%" stop-color="#38bdf8"/></linearGradient>
    <linearGradient id="g3" x1="0%" y1="0%" x2="0%" y2="100%"><stop offset="0%" stop-color="#818cf8"/><stop offset="100%" stop-color="#6366f1"/></linearGradient>
    <linearGradient id="g4" x1="0%" y1="0%" x2="0%" y2="100%"><stop offset="0%" stop-color="#c084fc"/><stop offset="100%" stop-color="#a855f7"/></linearGradient>
    <linearGradient id="g5" x1="0%" y1="0%" x2="0%" y2="100%"><stop offset="0%" stop-color="#f472b6"/><stop offset="100%" stop-color="#ec4899"/></linearGradient>
    <linearGradient id="g6" x1="0%" y1="0%" x2="0%" y2="100%"><stop offset="0%" stop-color="#fb7185"/><stop offset="100%" stop-color="#f43f5e"/></linearGradient>
    <linearGradient id="g7" x1="0%" y1="0%" x2="0%" y2="100%"><stop offset="0%" stop-color="#fdba74"/><stop offset="100%" stop-color="#fb923c"/></linearGradient>
    <linearGradient id="g8" x1="0%" y1="0%" x2="0%" y2="100%"><stop offset="0%" stop-color="#fde047"/><stop offset="100%" stop-color="#eab308"/></linearGradient>
    <linearGradient id="g9" x1="0%" y1="0%" x2="0%" y2="100%"><stop offset="0%" stop-color="#34d399"/><stop offset="100%" stop-color="#10b981"/></linearGradient>
    <linearGradient id="g10" x1="0%" y1="0%" x2="0%" y2="100%"><stop offset="0%" stop-color="#67e8f9"/><stop offset="100%" stop-color="#00f2fe"/></linearGradient>

    <!-- Wordmark Desk Gradient -->
    <linearGradient id="deskGrad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#38bdf8"/>
      <stop offset="45%" stop-color="#a855f7"/>
      <stop offset="100%" stop-color="#ec4899"/>
    </linearGradient>

    <!-- Edge Spine Gradient -->
    <linearGradient id="spineGrad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#38bdf8"/>
      <stop offset="100%" stop-color="#ec4899"/>
    </linearGradient>

    <!-- Master Stem Gradient -->
    <linearGradient id="stemGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#38bdf8"/>
      <stop offset="100%" stop-color="#6366f1"/>
    </linearGradient>
  </defs>

  <!-- ================= ICON EMBLEM (Centered on X=220) ================= -->
  <!-- Original bounds: x: 36..220 (width 184). Center is at 36 + 92 = 128. -->
  <!-- To center at 220, translate by 220 - 128 = 92 -->
  <g transform="translate(92, 16)">
    <!-- Master Left Column (Stem of 'D') -->
    <rect x="36" y="36" width="72" height="142" rx="10" fill="url(#stemGrad)"/>
    <rect x="36" y="36" width="72" height="18" rx="10" fill="#000000" opacity="0.22"/>
    <circle cx="45" cy="45" r="2.2" fill="#ffffff" opacity="0.8"/>
    <circle cx="52" cy="45" r="2.2" fill="#ffffff" opacity="0.8"/>
    <circle cx="59" cy="45" r="2.2" fill="#ffffff" opacity="0.8"/>
    <!-- Line numbers & code preview -->
    <line x1="56" y1="58" x2="56" y2="168" stroke="#ffffff" stroke-opacity="0.25" stroke-width="1.2"/>
    <rect x="62" y="62" width="36" height="3.5" rx="1.75" fill="#ffffff" opacity="0.9"/>
    <rect x="62" y="71" width="24" height="3.5" rx="1.75" fill="#38e2fc" opacity="0.95"/>
    <rect x="68" y="80" width="32" height="3" rx="1.5" fill="#ffffff" opacity="0.5"/>
    <rect x="68" y="88" width="22" height="3" rx="1.5" fill="#ffffff" opacity="0.5"/>
    <rect x="62" y="97" width="38" height="3.5" rx="1.75" fill="#ffffff" opacity="0.9"/>
    <rect x="68" y="106" width="28" height="3" rx="1.5" fill="#38e2fc" opacity="0.85"/>
    <rect x="68" y="114" width="34" height="3" rx="1.5" fill="#ffffff" opacity="0.5"/>
    <rect x="62" y="123" width="20" height="3.5" rx="1.75" fill="#ffffff" opacity="0.7"/>
    <rect x="62" y="134" width="38" height="14" rx="4" fill="#000000" opacity="0.22"/>
    <rect x="66" y="139" width="16" height="4" rx="2" fill="#38e2fc"/>
    <rect x="62" y="154" width="30" height="3" rx="1.5" fill="#ffffff" opacity="0.45"/>
    <rect x="62" y="162" width="22" height="3" rx="1.5" fill="#ffffff" opacity="0.45"/>

    <!-- Right Upper Tile (Upper Shoulder of 'D') -->
    <path d="M 116 46 A 10 10 0 0 1 126 36 L 194 36 A 26 26 0 0 1 220 62 L 220 93 A 10 10 0 0 1 210 103 L 126 103 A 10 10 0 0 1 116 93 Z"
          fill="url(#g5)"/>
    <rect x="124" y="44" width="46" height="8" rx="4" fill="#ffffff" opacity="0.3"/>
    <circle cx="180" cy="48" r="2.2" fill="#ffffff" opacity="0.75"/>
    <circle cx="187" cy="48" r="2.2" fill="#ffffff" opacity="0.75"/>
    <circle cx="194" cy="48" r="2.2" fill="#ffffff" opacity="0.75"/>
    <rect x="124" y="58" width="40" height="36" rx="5" fill="#ffffff" opacity="0.22"/>
    <rect x="170" y="58" width="40" height="16" rx="4" fill="#ffffff" opacity="0.3"/>
    <rect x="170" y="78" width="40" height="16" rx="4" fill="#ffffff" opacity="0.3"/>

    <!-- Right Lower Tile (Lower Shoulder of 'D') -->
    <path d="M 116 121 A 10 10 0 0 1 126 111 L 210 111 A 10 10 0 0 1 220 121 L 220 152 A 26 26 0 0 1 194 178 L 126 178 A 10 10 0 0 1 116 168 Z"
          fill="url(#g7)"/>
    <rect x="124" y="119" width="40" height="22" rx="5" fill="#ffffff" opacity="0.24"/>
    <rect x="129" y="127" width="20" height="5" rx="2.5" fill="#ffffff" opacity="0.95"/>
    <rect x="170" y="119" width="40" height="22" rx="5" fill="#ffffff" opacity="0.24"/>
    <rect x="175" y="127" width="24" height="5" rx="2.5" fill="#ffffff" opacity="0.95"/>
    <rect x="124" y="147" width="86" height="20" rx="5" fill="#ffffff" opacity="0.2"/>
    <rect x="129" y="155" width="56" height="4" rx="2" fill="#ffffff" opacity="0.9"/>

    <!-- Bottom Foundation Panel (Status Deck) -->
    <rect x="36" y="188" width="184" height="22" rx="7" fill="#141624" stroke="url(#spineGrad)" stroke-width="1.6" stroke-opacity="0.8"/>
    <rect x="42" y="193" width="15" height="12" rx="3.5" fill="url(#g1)"/>
    <rect x="47.5" y="197" width="4" height="4" rx="1" fill="#0b0c12"/>
    <rect x="60" y="193" width="12" height="12" rx="3" fill="#ffffff" opacity="0.18"/>
    <rect x="75" y="193" width="12" height="12" rx="3" fill="#ffffff" opacity="0.18"/>
    <rect x="90" y="193" width="12" height="12" rx="3" fill="#ffffff" opacity="0.18"/>
    <line x1="108" y1="194" x2="108" y2="204" stroke="#ffffff" stroke-opacity="0.2" stroke-width="1"/>
    <g transform="translate(116, 196)">
      <rect x="0"  y="0" width="5" height="6" rx="2" fill="url(#g1)"/>
      <rect x="8"  y="0" width="5" height="6" rx="2" fill="url(#g2)"/>
      <rect x="16" y="0" width="6" height="6" rx="2" fill="url(#g3)"/>
      <rect x="25" y="0" width="5" height="6" rx="2" fill="url(#g4)"/>
      <rect x="33" y="0" width="5" height="6" rx="2" fill="url(#g5)"/>
      <rect x="41" y="0" width="6" height="6" rx="2" fill="url(#g6)"/>
      <rect x="50" y="0" width="5" height="6" rx="2" fill="url(#g7)"/>
      <rect x="58" y="0" width="6" height="6" rx="2" fill="url(#g8)"/>
      <rect x="67" y="0" width="5" height="6" rx="2" fill="url(#g9)"/>
      <rect x="75" y="0" width="5" height="6" rx="2" fill="url(#g10)"/>
    </g>
  </g>

  <!-- ================= TYPOGRAPHY ================= -->
  <text x="220" y="272" text-anchor="middle"
        font-family="'Inter', 'Liberation Sans', 'DejaVu Sans', sans-serif"
        font-size="46" font-weight="400" letter-spacing="-1px">
    <tspan fill="#F8FAFC" font-weight="400">gutter</tspan><tspan fill="url(#deskGrad)" font-weight="800">Desk</tspan>
  </text>

  <text x="220" y="302" text-anchor="middle"
        font-family="'Inter', 'Liberation Sans', 'DejaVu Sans', sans-serif"
        font-size="12" font-weight="600" letter-spacing="3.5px" fill="#94A3B8">
    TACTILE WORKSPACE DISTRO
  </text>
</svg>"""

logo_svg_path = os.path.join(THEME_DIR, "logo.svg")
with open(logo_svg_path, "w") as f:
    f.write(LOGO_SVG)

logo_png_path = os.path.join(THEME_DIR, "logo.png")
print("Rendering logo.png via inkscape...")
subprocess.run([
    "inkscape",
    "--export-filename=" + logo_png_path,
    "--export-area-page",
    logo_svg_path
], check=True)

# -------------------------------------------------------------
# 2. Generate 30 Animated Neon Spinner Frames (64x64 RGBA)
# -------------------------------------------------------------
print("Generating 30 spinner animation frames...")
SPINNER_SIZE = 64
RADIUS = 23
THICKNESS = 4.0
CENTER = (SPINNER_SIZE / 2.0, SPINNER_SIZE / 2.0)

# Brand spinner colors from Sky Blue to Indigo to Neon Pink
def interpolate_color(t):
    # t is in [0, 1]
    # Colors: 0.0 -> #38bdf8 (Sky), 0.5 -> #818cf8 (Indigo), 1.0 -> #ec4899 (Pink)
    c1 = (56, 189, 248)   # Sky
    c2 = (129, 140, 248)  # Indigo
    c3 = (236, 72, 153)   # Pink
    if t < 0.5:
        sub_t = t * 2.0
        r = int(c1[0] + (c2[0] - c1[0]) * sub_t)
        g = int(c1[1] + (c2[1] - c1[1]) * sub_t)
        b = int(c1[2] + (c2[2] - c1[2]) * sub_t)
    else:
        sub_t = (t - 0.5) * 2.0
        r = int(c2[0] + (c3[0] - c2[0]) * sub_t)
        g = int(c2[1] + (c3[1] - c2[1]) * sub_t)
        b = int(c2[2] + (c3[2] - c2[2]) * sub_t)
    return (r, g, b)

TOTAL_FRAMES = 30
ARC_SPAN = 260.0  # degrees of the visible arc

for frame_idx in range(TOTAL_FRAMES):
    scale = 4
    hi_size = SPINNER_SIZE * scale
    hi_center = (CENTER[0] * scale, CENTER[1] * scale)
    hi_radius = RADIUS * scale
    hi_thick = THICKNESS * scale

    img = Image.new("RGBA", (hi_size, hi_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    base_angle = (frame_idx / TOTAL_FRAMES) * 360.0

    steps = 120
    for s in range(steps):
        t = s / float(steps)  # 0 at tail, 1 at head
        angle_deg = base_angle + (t * ARC_SPAN)
        angle_rad = math.radians(angle_deg)

        alpha = int(255 * (t ** 1.8))
        rgb = interpolate_color(t)
        color = (rgb[0], rgb[1], rgb[2], alpha)

        x = hi_center[0] + hi_radius * math.cos(angle_rad)
        y = hi_center[1] + hi_radius * math.sin(angle_rad)

        dot_radius = hi_thick / 2.0 * (0.6 + 0.4 * t)
        draw.ellipse([x - dot_radius, y - dot_radius, x + dot_radius, y + dot_radius], fill=color)

    final_img = img.resize((SPINNER_SIZE, SPINNER_SIZE), Image.Resampling.LANCZOS)
    filename = f"spinner-{frame_idx:02d}.png"
    final_img.save(os.path.join(THEME_DIR, filename))

# -------------------------------------------------------------
# 3. Generate Dialog & Password Prompt Assets
# -------------------------------------------------------------
print("Generating password & dialog assets...")

# Bullet for password masking: 16x16 glowing cyan dot
bullet_scale = 4
bullet_img = Image.new("RGBA", (16 * bullet_scale, 16 * bullet_scale), (0, 0, 0, 0))
bullet_draw = ImageDraw.Draw(bullet_img)
bullet_center = (8 * bullet_scale, 8 * bullet_scale)
bullet_draw.ellipse([
    bullet_center[0] - 6 * bullet_scale, bullet_center[1] - 6 * bullet_scale,
    bullet_center[0] + 6 * bullet_scale, bullet_center[1] + 6 * bullet_scale
], fill=(6, 182, 212, 60))
bullet_draw.ellipse([
    bullet_center[0] - 3.5 * bullet_scale, bullet_center[1] - 3.5 * bullet_scale,
    bullet_center[0] + 3.5 * bullet_scale, bullet_center[1] + 3.5 * bullet_scale
], fill=(56, 189, 248, 255))
final_bullet = bullet_img.resize((16, 16), Image.Resampling.LANCZOS)
final_bullet.save(os.path.join(THEME_DIR, "bullet.png"))

# Entry box: 280x38 rounded rect
entry_scale = 4
entry_w, entry_h = 280 * entry_scale, 38 * entry_scale
entry_img = Image.new("RGBA", (entry_w, entry_h), (0, 0, 0, 0))
entry_draw = ImageDraw.Draw(entry_img)
entry_draw.rounded_rectangle(
    [2 * entry_scale, 2 * entry_scale, entry_w - 2 * entry_scale, entry_h - 2 * entry_scale],
    radius=6 * entry_scale,
    fill=(12, 16, 21, 230),
    outline=(42, 50, 69, 255),
    width=int(1.5 * entry_scale)
)
final_entry = entry_img.resize((280, 38), Image.Resampling.LANCZOS)
final_entry.save(os.path.join(THEME_DIR, "entry.png"))

# Lock icon: 24x24 cyan padlock
lock_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">
  <path d="M12 2 C9.24 2 7 4.24 7 7 L7 10 L6 10 C4.9 10 4 10.9 4 12 L4 20 C4 21.1 4.9 22 6 22 L18 22 C19.1 22 20 21.1 20 20 L20 12 C20 10.9 19.1 10 18 10 L17 10 L17 7 C17 4.24 14.76 2 12 2 Z M12 4 C13.66 4 15 5.34 15 7 L15 10 L9 10 L9 7 C9 5.34 10.34 4 12 4 Z M12 14 C13.1 14 14 14.9 14 16 C14 16.74 13.6 17.38 13 17.72 L13 19 C13 19.55 12.55 20 12 20 C11.45 20 11 19.55 11 19 L11 17.72 C10.4 17.38 10 16.74 10 16 C10 14.9 10.9 14 12 14 Z" fill="#38bdf8"/>
</svg>"""
lock_svg_path = os.path.join(THEME_DIR, "lock.svg")
with open(lock_svg_path, "w") as f:
    f.write(lock_svg)
subprocess.run([
    "inkscape",
    "--export-filename=" + os.path.join(THEME_DIR, "lock.png"),
    lock_svg_path
], check=True)

# Dialog box: 320x150
box_scale = 2
box_w, box_h = 320 * box_scale, 150 * box_scale
box_img = Image.new("RGBA", (box_w, box_h), (0, 0, 0, 0))
box_draw = ImageDraw.Draw(box_img)
box_draw.rounded_rectangle(
    [2 * box_scale, 2 * box_scale, box_w - 2 * box_scale, box_h - 2 * box_scale],
    radius=8 * box_scale,
    fill=(8, 12, 14, 240),
    outline=(30, 36, 48, 255),
    width=int(1.5 * box_scale)
)
final_box = box_img.resize((320, 150), Image.Resampling.LANCZOS)
final_box.save(os.path.join(THEME_DIR, "box.png"))

print(f"✓ Successfully generated all Plymouth assets in {THEME_DIR}")
