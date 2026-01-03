cask "droppy" do
  version "2.1.1"
  sha256 "bf3f74b0593c46c98fe97504d633aa6c7622fa89eb3a8eee8ae627eafaa841d0"

  url "https://raw.githubusercontent.com/iordv/Droppy/main/Droppy-2.1.1.dmg"
  name "Droppy"
  desc "Drag and drop file shelf for macOS"
  homepage "https://github.com/iordv/Droppy"

  app "Droppy.app"

  zap trash: [
    "~/Library/Application Support/Droppy",
    "~/Library/Preferences/iordv.Droppy.plist",
  ]
end
