cask "skd-downloader" do
  version "0.9.0-beta.7"
  sha256 "1b938e86d96a6984d370a22ff5e4d558bb59204e722709c3b897fd1311e87729"

  github_token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN") do
    raise "HOMEBREW_GITHUB_API_TOKEN is required to install this private beta cask"
  end

  url "https://api.github.com/repos/SKD-international/skd-downloader/releases/assets/409951915?version=#{version}",
      header: [
        "Accept: application/octet-stream",
        "Authorization: Bearer #{github_token}",
      ]
  name "SKD Downloader"
  desc "Downloader GUI and MediaHuman alternative"
  homepage "https://github.com/SKD-international/skd-downloader"

  depends_on macos: ">= :sonoma"
  depends_on formula: "yt-dlp"
  depends_on formula: "ffmpeg"

  app "SKD Downloader.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/SKD Downloader.app"]
  end

  zap trash: [
    "~/Library/Application Support/skd-downloader",
    "~/Library/Application Support/skd-downloader-native",
    "~/Library/Logs/skd-downloader",
    "~/Library/Preferences/com.skd.downloader.native.plist",
    "~/Library/Preferences/com.skd.downloader.plist",
  ]
end
