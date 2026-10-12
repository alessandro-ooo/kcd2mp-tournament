-- Example: KCD:MP's own chat and scoreboard, moved and restyled by a theme - no page of your own.
--
-- ui/ui.toml draws the chat and the scoreboard with KCD:MP's web versions (drawer "default"), puts the chat in the top-right
-- corner, opens the scoreboard with Tab, and styles both with ui/theme.css and a few colour variables. It also writes two chat
-- templates: a line the mode sends with template = "ooc" or "notice" is laid out by them.
--
-- Run it with [gamemode] script = "sdk/web/examples/theme/theme.lua", or copy this folder into gamemodes/.

SetGameModeText("theme example")

function OnGameModeInit()
  RegisterCommand("ooc", function(pid, args)
    if args == "" then
      SendChatMessage(pid, "Usage: /ooc <text>")
      return
    end
    -- the web chat lays the line out with the theme's "ooc" template; the game's own chat shows "Henry: text"
    SendChatMessageToAll({ template = "ooc", params = { GetPlayerName(pid), args } })
  end, { help = "Say something out of character", params = "<text>" })
end

function OnPlayerSpawn(pid)
  SendChatMessage(pid, {
    template = "notice",
    params = { "Welcome! This chat is KCD:MP's own, styled by the server's theme. Try /ooc, and Tab for the scoreboard." },
  })
end
