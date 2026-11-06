cask "vois-studio" do
  version "2.6.2"
  sha256 "27d994698a15e786861797990f9d094dae7181e146c310199da3d37361dfb9a5"

  url "https://cdn.vois.so/releases/production/v#{version}/Vois_#{version}_aarch64.dmg"
  name "Vois Studio"
  desc "Voice studio for voiceovers, podcasts and audiobooks"
  homepage "https://vois.so/"

  livecheck do
    url "https://cdn.vois.so/releases/production/latest.json"
    strategy :json do |json|
      json["version"]
    end
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :monterey

  app "Vois.app"

  zap trash: [
    "~/Library/Application Support/com.praneybehl.vois",
    "~/Library/Application Support/so.vois.app",
    "~/Library/Caches/com.praneybehl.vois",
    "~/Library/Caches/so.vois.app",
    "~/Library/HTTPStorages/so.vois.app",
    "~/Library/Logs/com.praneybehl.vois",
    "~/Library/Logs/so.vois.app",
    "~/Library/Preferences/com.praneybehl.vois.plist",
    "~/Library/Preferences/so.vois.app.plist",
    "~/Library/Saved Application State/so.vois.app.savedState",
    "~/Library/WebKit/com.praneybehl.vois",
    "~/Library/WebKit/so.vois.app",
  ]
end
