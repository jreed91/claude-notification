cask "agentbar" do
  version "1.11.0"
  sha256 "bf7f665da5f8786765604348b56d3f298bae9b332bac4f8dd45439cf2fbd3d5c"

  url "https://github.com/jreed91/agentbar/releases/download/v#{version}/AgentBar-#{version}.zip"
  name "AgentBar"
  desc "Menu bar companion for Claude Code and GitHub Copilot CLI"
  homepage "https://github.com/jreed91/agentbar"

  # The app's LSMinimumSystemVersion is 14.0 — Sonoma or newer, not Sonoma only.
  depends_on macos: ">= :sonoma"

  app "AgentBar.app"

  zap trash: [
    "~/Library/Application Support/AgentBar",
    "~/Library/Preferences/com.jreed91.AgentBar.plist",
    "~/.copilot/hooks/agentbar.json",
  ]
end
