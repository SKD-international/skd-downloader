# SKD Downloader

# Large Print Mac Guide

This guide is for the native Mac app installed with Homebrew.

It is written for easy reading.

Use your browser zoom if the text is still too small:

```text
Command + Plus
```

Press it more than once to make this page bigger.

## What This App Does

SKD Downloader saves videos and audio from links.

You can use it for sites like YouTube, Vimeo, TikTok, Reddit, Instagram, and many others.

Most people only need three steps:

1. Copy a video link.
2. Paste it into SKD Downloader.
3. Click download.

## Install It

Open the Terminal app on the Mac.

Paste this full command.

Then press Return.

```bash
if ! command -v brew >/dev/null 2>&1; then /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; fi; eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"; brew tap Bonchaloo/tap; brew install --cask skd-downloader
```

Wait until Terminal finishes.

This may take a few minutes.

## Open It

1. Open the Applications folder.
2. Find **SKD Downloader**.
3. Double-click it.

If macOS asks whether to open it, choose **Open**.

The app is signed and notarized by Apple.

## Make The Mac Easier To See

If the app or Mac text is too small:

1. Click the Apple menu in the top left.
2. Open **System Settings**.
3. Open **Displays**.
4. Choose a larger text option.

You can also make the SKD Downloader window bigger by dragging a corner of the window.

## Download A Video

1. Open Safari, Chrome, or another browser.
2. Go to the video page.
3. Copy the page link from the address bar.
4. Open **SKD Downloader**.
5. Click **Paste Links**.
6. Choose **Video**.
7. Leave **Format** on **MP4**.
8. Leave **Quality** on **Highest**.
9. Click **Add to Queue**.
10. Click **Start Queue**.

The download progress appears in the queue.

## Download Audio Only

Use this when you want music, a podcast, or spoken audio.

1. Copy the video link.
2. Open **SKD Downloader**.
3. Click **Paste Links**.
4. Choose **Audio**.
5. Leave the audio format on **M4A**.
6. Click **Add to Queue**.
7. Click **Start Queue**.

## Where The Files Go

By default, files go here:

```text
Downloads/SKD Downloader
```

To open the folder from the app:

1. Click **Open Folder**.
2. Your downloaded files should be there.

## Play A Downloaded Video

1. Open **SKD Downloader**.
2. Look at the left side of the app.
3. Click **Library**.
4. Click a saved video.
5. Click **Open**.

You can also open the file from the Downloads folder.

## Stop A Download

If you started the wrong download:

1. Click the download in the queue.
2. Click **Stop**.

You can start another download after that.

## If Something Fails

Try these steps first:

1. Make sure the internet is working.
2. Close SKD Downloader.
3. Open SKD Downloader again.
4. Try the link again.

If the app says the engine needs attention:

1. Click **Refresh Engine**.
2. Wait a moment.
3. Try the download again.

## Update The App Later

Open Terminal.

Paste this command.

Then press Return.

```bash
brew update && brew upgrade --cask skd-downloader
```

## Remove The App

Open Terminal.

Paste this command.

Then press Return.

```bash
brew uninstall --cask skd-downloader
```

## Simple Reminders

Use **Video** for a normal video file.

Use **Audio** for music or spoken audio.

Use **MP4** for video unless you have a reason to choose something else.

Use **M4A** for audio unless you have a reason to choose something else.

Use **Open Folder** when you cannot find the saved file.
