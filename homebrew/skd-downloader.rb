cask "skd-downloader" do
  version "0.9.0-beta.1"
  sha256 :no_check

  url "https://github.com/Bonchaloo/skd-downloader/releases/download/v#{version}/SKD.Downloader-#{version}.dmg"
  name "SKD Downloader"
  desc "Premium yt-dlp GUI — free MediaHuman alternative"
  homepage "https://github.com/Bonchaloo/skd-downloader"

  depends_on formula: "yt-dlp"

  app "SKD Downloader.app"

  zap trash: [
    "~/Library/Application Support/skd-downloader",
    "~/Library/Preferences/com.skd.downloader.plist",
    "~/Library/Logs/skd-downloader",
  ]
end
