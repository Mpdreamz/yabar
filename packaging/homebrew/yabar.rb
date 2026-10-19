# TEMPLATE: the Homebrew cask, as scripts/bump-tap.sh writes it to mpdreamz/homebrew-tap on every release, with the
# version and the zip's sha256 filled in. Change it here, not in the tap. (bump-tap.sh replaces this header.)
cask "yabar" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "https://github.com/mpdreamz/yabar/releases/download/v#{version}/Yabar-arm64.zip"
  name "Yabar"
  desc "Menu bar spaces and window stack indicators for yabai"
  homepage "https://github.com/mpdreamz/yabar"

  livecheck do
    url :url
    strategy :github_latest
  end

  # Yabar updates itself (Sparkle); brew upgrade leaves it to that (brew upgrade --greedy still upgrades it).
  auto_updates true

  depends_on arch: :arm64
  depends_on macos: :sequoia

  app "Yabar.app"

  uninstall quit: "io.github.mpdreamz.yabar"

  zap trash: [
    "~/Library/Application Support/Yabar",
    "~/Library/Caches/io.github.mpdreamz.yabar",
    "~/Library/HTTPStorages/io.github.mpdreamz.yabar",
    "~/Library/Preferences/io.github.mpdreamz.yabar.plist",
  ]
end
