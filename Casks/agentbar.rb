cask "agentbar" do
  version "1.2.0"
  sha256 "acab27c9f393bbc94795575089bb9e3db825aa888f158b12474084e0ba414fe1"

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
