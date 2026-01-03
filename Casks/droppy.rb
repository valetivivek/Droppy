cask "droppy" do
  version "2.0.2"
  sha256 "fc2e58eebff817af13a970418e6c682457b1bac2142cfff53a69f9353c1c9db2"

  url "https://raw.githubusercontent.com/iordv/Droppy/main/Droppy-2.0.2.dmg"
  name "Droppy"
  desc "Drag and drop file shelf for macOS"
  homepage "https://github.com/iordv/Droppy"

  app "Droppy.app"

  zap trash: [
    "~/Library/Application Support/Droppy",
    "~/Library/Preferences/iordv.Droppy.plist",
  ]
end
