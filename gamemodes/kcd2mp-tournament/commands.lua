local duel = require("utils.duel")
local player = require("utils.players")
local ui = require("utils.ui")

function OnPlayerCommandText(pid, cmd, args)
  cmd = cmd:lower()
  if cmd == "duel" then
    if duel.isPlayerInDuel(pid) then
      SendClientMessage(pid, COLOR_RED, "You are already in a duel.")
      return true
    end

    player.setRequestingUI(pid, ui.UI_LIST.duelSettings)
    local success = ui.show(pid, true, true, true)

    if success == false then return false end
    return true
  end

  return true
end

function OnPlayerDisconnect(pid)
  local duelInfo = duel.findByPlayer(pid)
  if duelInfo then
    local opponent = duelInfo.playerOne == pid and duelInfo.playerTwo or duelInfo.playerOne
    duel.remove(duelInfo)
    if opponent and opponent ~= pid and GetPlayerName(opponent) then
      HidePlayerWebFrame(opponent, "duelsettings")
      SendClientMessage(opponent, COLOR_RED, "The duel was cancelled because the other player disconnected.")
    end
  end
end