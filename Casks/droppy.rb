cask "droppy" do
  version "2.0.4"
  sha256 "fe2bbaa7645ea05db84885e29c4e07bb38869b738e876c7bb46aa0665de6c645"

  url "https://raw.githubusercontent.com/iordv/Droppy/main/Droppy-2.0.4.dmg"
  name "Droppy"
  desc "Drag and drop file shelf for macOS"
  homepage "https://github.com/iordv/Droppy"

  app "Droppy.app"

  zap trash: [
    "~/Library/Application Support/Droppy",
    "~/Library/Preferences/iordv.Droppy.plist",
  ]
end
