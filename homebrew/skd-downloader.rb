cask "skd-downloader" do
  version "0.9.0-beta.3"
  sha256 "af966c31aef8fecb0c2c6a8d3217b515514d0dac79597cda07179b79d6c21f34"

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
