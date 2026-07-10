cask "agentbar" do
  version "1.2.1"
  sha256 "50c68374fdf66ea54dfdd85f0a3ad783c0748f54e287f8858693aa3f3807aa5b"

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
