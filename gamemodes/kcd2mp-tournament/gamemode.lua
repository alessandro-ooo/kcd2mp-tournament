local duel = require("utils.duel")
dofile("gamemodes/kcd2mp-tournament/commands.lua")


function OnGameModeInit()
  Log("Tournament gamemode")
end

function OnPlayerConnect(pid)
  SendClientMessage(pid, COLOR_SERVER, "Welcome to the KCD2MP Tournament gamemode!")
  SendClientMessage(pid, COLOR_SERVER, "Type /duel <player_id|player_name> to challenge someone to a duel.")
  SendClientMessage(pid, COLOR_SERVER, "Type /accept to accept a duel request or /decline to decline.")
end

function OnClientEvent(pid, name, payload, source)
  if source ~= "duelsettings" or name ~= "panel.duelsettings.start" or payload ~= "start" then
    return
  end

  local duelInfo = duel.findByPlayer(pid)
  if duelInfo and duelInfo.status == "accepted" and duelInfo.playerOne == pid then
    duel.changeStatus(duelInfo, "fighting")
    SendClientMessage(duelInfo.playerOne, COLOR_SERVER, "Your duel is starting.")
    SendClientMessage(duelInfo.playerTwo, COLOR_SERVER, GetPlayerName(duelInfo.playerOne) .. " has started the duel.")
    HidePlayerWebFrame(pid, "duelsettings")
  else
    SendClientMessage(pid, COLOR_RED, "You have no accepted duel to start.")
  end
end