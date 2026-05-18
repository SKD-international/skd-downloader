# Security Policy

## Supported Versions

Security fixes target the current `main` branch and the latest public release.

## Reporting A Vulnerability

Do not open a public issue for exploitable vulnerabilities, credential leaks,
or download-chain abuse reports.

Use GitHub's private vulnerability reporting for this repository when it is
enabled. If it is not available, contact a maintainer out of band and include:

- affected version or commit
- operating system version
- reproduction steps
- expected and actual behavior
- whether the issue requires a malicious URL, local file, or network position

## Download Safety Scope

SKD Downloader shells out to `yt-dlp`, `ffmpeg`, and `ffprobe`. Reports that
involve unsafe command construction, path traversal, unexpected file writes,
or execution of untrusted local binaries are in scope.

Reports about third-party extractor behavior should also be reported upstream
to the relevant project when the vulnerable behavior is outside this app.
