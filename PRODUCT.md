## Design Context

### Users
SKD Downloader is for desktop users who download, inspect, convert, and re-run media jobs with yt-dlp but do not want to live in Terminal. They work in batches, compare formats, check engine health, and need clear queue state while downloads run in the background.

### Brand Personality
Fast, precise, and workmanlike. The app should feel like a serious native macOS utility: compact, responsive, legible, and confident without looking like a toy dashboard or a pasted web app.

### Aesthetic Direction
Use a dense native macOS control-deck direction with Linear-style layout discipline, Raycast-style dark utility mood, and restrained SKD mint/cyan/amber accent energy. Dark mode is the default because the app is used during focused desktop sessions with long-running queue activity; light themes stay precise and low-glare.

### Design Principles
- Operational clarity wins over decoration: queue state, engine health, selected format, and next action must be obvious.
- Use accents only for status and action hierarchy, not for generic decoration.
- Keep controls compact and native: the app should scan like a pro utility, not a marketing page.
- Prefer structured bands, tool surfaces, and dense rows over oversized cards.
- Monospaced text is reserved for paths, versions, URLs, and diagnostics.
