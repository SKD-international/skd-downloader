cask "skd-downloader" do
  version "0.9.0-beta.7"
  sha256 "baa4e1839206cdeeb165019df0fbccb9bcd10204743a32fa950a883fdcf682b6"

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
