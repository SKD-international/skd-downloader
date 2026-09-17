cask "skd-downloader" do
  version "0.9.0-beta.9"
  sha256 "bd438fcec4bbe29146e42b6d022eb4999e9ab1a190b582b5f321e066c0aa7976"

  on_arm do
    depends_on formula: "ffmpeg"
  end

  url "https://github.com/SKD-international/skd-downloader/releases/download/v#{version}/SKD.Downloader.Native-#{version}-mac.zip"
  name "SKD Downloader"
  desc "Native yt-dlp video and audio downloader"
  homepage "https://github.com/SKD-international/skd-downloader"

  depends_on macos: :sonoma

  app "SKD Downloader.app"

  zap trash: [
    "~/Library/Application Support/skd-downloader",
    "~/Library/Application Support/skd-downloader-native",
    "~/Library/Logs/skd-downloader",
    "~/Library/Preferences/com.skd.downloader.native.plist",
    "~/Library/Preferences/com.skd.downloader.plist",
  ]

  caveats do
    <<~EOS
      The app installs and updates yt-dlp and Deno itself from their official
      GitHub releases (SHA-256 verified) into
      ~/Library/Application Support/skd-downloader-native/tools/bin.

      ffmpeg is still needed for merging and audio extraction. On Apple Silicon
      it is installed with this cask. On Intel Macs Homebrew no longer ships
      ffmpeg bottles, so install it separately (`brew install ffmpeg` builds from
      source) or keep an existing ffmpeg in /usr/local/bin.
    EOS
  end
end
