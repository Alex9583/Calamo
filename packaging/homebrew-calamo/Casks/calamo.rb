# Canonical source of the tap Alex9583/homebrew-calamo — copy this tree
# over on each release (docs/release.md). A third-party tap because the
# official homebrew-cask rejects non-notarized apps.
cask "calamo" do
  version "1.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000" # from the GitHub Release notes

  url "https://github.com/Alex9583/Calamo/releases/download/v#{version}/Calamo-#{version}.dmg"
  name "Calamo"
  desc "Local-only multilingual voice dictation: hold a key, speak, release"
  homepage "https://github.com/Alex9583/Calamo"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma
  depends_on arch: :arm64

  app "Calamo.app"

  zap trash: [
    "~/Library/Application Support/com.calamo.Calamo",
    "~/Library/Preferences/com.calamo.Calamo.plist",
  ]

  caveats <<~EOS
    Calamo is signed with a stable self-signed certificate, not notarized
    by Apple, and Homebrew quarantines what it downloads. First launch:

      1. Open Calamo — macOS says it cannot verify it. Click "Done".
      2. System Settings → Privacy & Security → click "Open Anyway".

    macOS asks again after every upgrade. Advanced alternative — drop the
    quarantine flag instead (brew's --no-quarantine does the same at
    install time, but is deprecated since Homebrew 5):

      xattr -dr com.apple.quarantine "/Applications/Calamo.app"

    Speech recognition by NVIDIA Parakeet models (CC BY 4.0),
    cleanup by Qwen3.5-2B (Apache-2.0) — downloaded on first launch.
  EOS
end
