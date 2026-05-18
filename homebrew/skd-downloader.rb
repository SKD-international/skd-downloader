cask "skd-downloader" do
  version "0.9.0-beta.7"
  sha256 "1b938e86d96a6984d370a22ff5e4d558bb59204e722709c3b897fd1311e87729"

  url "https://github.com/SKD-international/skd-downloader/releases/download/v#{version}/SKD.Downloader.Native-#{version}-mac.zip"
  name "SKD Downloader"
  desc "Native yt-dlp video and audio downloader"
  homepage "https://github.com/SKD-international/skd-downloader"

  depends_on macos: ">= :sonoma"
  depends_on formula: "yt-dlp"
  depends_on formula: "ffmpeg"

  app "SKD Downloader.app"

  caveats do
    <<~EOS
      yt-dlp, ffmpeg, and ffprobe are installed by Homebrew and used from PATH.
      App data is stored under ~/Library/Application Support/skd-downloader-native.
    EOS
  end

  zap trash: [
    "~/Library/Application Support/skd-downloader",
    "~/Library/Application Support/skd-downloader-native",
    "~/Library/Logs/skd-downloader",
    "~/Library/Preferences/com.skd.downloader.native.plist",
    "~/Library/Preferences/com.skd.downloader.plist",
  ]
end
