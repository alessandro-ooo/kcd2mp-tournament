-- Example: a chat of your own, drawn by a web page.
--
-- ui/ui.toml gives the chat to the frame "chat" for every player ([components.chat]), and ui/chat/ draws it: the page hears the
-- chat's lines, its channels and the commands it may suggest, and sends what the player types - the chat@1 contract of the web
-- interface SDK ("Drawing a component"). Nothing more is needed on the server: every line reaches the page by itself.
--
-- What this mode adds is only there to show the page's parts: a channel (a tab in the chat), a command (suggested as the player
-- types "/") and a line in pieces of different colours. Run it with [gamemode] script = "sdk/web/examples/replace-chat/replace-chat.lua",
-- or copy this folder into gamemodes/ and point the script there.

SetGameModeText("chat example")

function OnGameModeInit()
  RegisterChatChannel("trade", { label = "Trade", color = 0xE0C060FF })

  RegisterCommand("roll", function(pid, args)
    local sides = tonumber(args) or 6
    if sides < 2 or sides > 1000 then
      SendChatMessage(pid, "Usage: /roll [sides], 2 to 1000.")
      return
    end
    SendChatMessageToAll({
      spans = {
        { text = GetPlayerName(pid), color = COLOR_GOLD, bold = true },
        { text = " rolls a d" .. sides .. ": " },
        { text = tostring(math.random(1, sides)), bold = true },
      },
    })
  end, { help = "Roll a die for everyone to see", params = "[sides]" })
end

function OnPlayerSpawn(pid)
  SendChatMessage(pid, {
    spans = {
      { text = "Welcome, ", color = COLOR_WHITE },
      { text = GetPlayerName(pid), color = COLOR_GOLD, bold = true },
      { text = ". This chat is a web page - press Enter to talk, Tab to switch to the Trade channel, and try /roll.", italic = true },
    },
  })
end
