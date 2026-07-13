cask "agentbar" do
  version "1.10.0"
  sha256 "a37e2ae94f865f474ea91e246320849b8edcbc786be10cd660e882bce16ff8dd"

  url "https://github.com/jreed91/claude-notification/releases/download/v#{version}/AgentBar-#{version}.zip"
  name "AgentBar"
  desc "Menu bar companion for Claude Code and GitHub Copilot CLI"
  homepage "https://github.com/jreed91/claude-notification"

  depends_on macos: :sonoma

  app "AgentBar.app"

  zap trash: [
    "~/Library/Application Support/AgentBar",
    "~/Library/Preferences/com.jreed91.AgentBar.plist",
    "~/.copilot/hooks/agentbar.json",
  ]
end
