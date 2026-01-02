cask "droppy" do
  version "1.2.7"
  sha256 "ee43d71338215fd417651ac4eb96b53fbcb32cc2483f738f6b27ceafb11801b7"

  url "https://raw.githubusercontent.com/iordv/Droppy/main/Droppy.dmg"
  name "Droppy"
  desc "Drag and drop file shelf for macOS"
  homepage "https://github.com/iordv/Droppy"

  app "Droppy.app"

  zap trash: [
    "~/Library/Application Support/Droppy",
    "~/Library/Preferences/iordv.Droppy.plist",
  ]
end
