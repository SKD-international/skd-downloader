cask "skd-downloader" do
  version "0.9.0-beta.2"
  sha256 "0463d52f217ff2b32d865725d6bc631e137791b9f69e508509dba17e849e2f22"

  url "https://github.com/SKD-international/skd-downloader/releases/download/v#{version}/SKD.Downloader.Native-#{version}-mac.zip"
  name "SKD Downloader"
  desc "Downloader GUI and MediaHuman alternative"
  homepage "https://github.com/SKD-international/skd-downloader"

  depends_on macos: ">= :sonoma"
  depends_on formula: "yt-dlp"
  depends_on formula: "ffmpeg"

  app "SKD Downloader.app"

  zap trash: [
    "~/Library/Application Support/skd-downloader",
    "~/Library/Application Support/skd-downloader-native",
    "~/Library/Logs/skd-downloader",
    "~/Library/Preferences/com.skd.downloader.native.plist",
    "~/Library/Preferences/com.skd.downloader.plist",
  ]
end
