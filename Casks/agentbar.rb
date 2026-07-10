cask "agentbar" do
  version "1.3.0"
  sha256 "3ae27f9de8152feff9f4fe3d34ee5ce64d062475fa97abdee6b4df02df21d6a9"

  url "https://github.com/jreed91/claude-notification/releases/download/v#{version}/AgentBar-#{version}.zip"
  name "AgentBar"
  desc "Menu bar companion for Claude Code — answer agent prompts from the macOS menu bar"
  homepage "https://github.com/jreed91/claude-notification"

  depends_on macos: :sonoma

  app "AgentBar.app"

  zap trash: [
    "~/Library/Application Support/AgentBar",
    "~/Library/Preferences/com.jreed91.AgentBar.plist",
  ]
end
