# SKD Downloader Native Design System

## 1. Visual Theme & Atmosphere

SKD Downloader should feel like a fast native macOS utility, not a toy dashboard and not a browser app pasted into a desktop shell. The structure is operational and precise, with enough brand energy to make the app recognizable from a glance.

Default direction:
- Linear-style layout discipline for spacing, grouping, and queue management
- Raycast-style dark utility mood for elevated surfaces and contrast
- SKD accent energy for primary action, progress, and status moments

The app also supports alternate themes for users who want a colder dark utility look or a softer workspace feel.

## 2. Theme Presets

### SKD Midnight
- Near-black blue-green canvas
- Mint primary accent
- Cyan secondary accent
- Amber warning accent
- Use as the default theme

### Raycast Pulse
- Obsidian utility surfaces
- Bright blue interactive accent
- Coral-red punctuation color
- Keep accents restrained and status-driven

### Linear Light
- Cool off-white workspace
- Hairline borders and minimal shadow
- Indigo primary accent
- Best for precise queue and metadata workflows

### Notion Warm
- Soft paper background
- Gentle blue action color
- Warmer neutrals and quieter contrast
- Best for a calmer, more approachable workspace feel

## 3. Typography Rules

- Use the macOS system sans-serif for all standard interface text
- Use heavier weights only for screen titles, section labels, and queue emphasis
- Use monospaced text only for paths, URLs, binary versions, and status diagnostics
- Avoid decorative typefaces

## 4. Layout Principles

- Prefer split-view structure and dense, scannable queue rows
- Use 12, 16, 20, and 24 point spacing steps
- Keep sidebars native and flat
- Put expressive surfaces in the detail area, not the source list

## 5. Component Stylings

- Hero panels can be more expressive than the rest of the app
- Queue and history rows should stay compact and legible
- Cards should use system material plus a theme tint overlay, not opaque fake glass
- Primary buttons may be more prominent, but secondary controls should stay quiet
- Status badges should be color-coded and concise

## 6. Do

- Keep the app feeling native to macOS
- Let status colors carry meaning
- Use theme accents for progress, selection, and primary action
- Preserve operational clarity before style

## 7. Don’t

- Don’t turn the sidebar into a gallery of cards
- Don’t tint every icon just because color is available
- Don’t hide queue state behind oversized decorative surfaces
- Don’t let the warm themes reduce contrast on metadata and file paths
