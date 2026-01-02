cask "droppy" do
  version "1.2.3"
  sha256 "c611779a69496bfefb29344163911c6255b94f2ccbdd3d9217ec1c7bab1a1ca1"

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
