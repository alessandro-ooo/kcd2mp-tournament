local player = require("utils.players")
local duel = require("utils.duel")
dofile("gamemodes/kcd2mp-tournament/commands.lua")

function OnGameModeInit()
  Log("Tournament gamemode")
end

function OnPlayerConnect(pid)
  player.add(pid)
  SendClientMessage(pid, COLOR_SERVER, "Welcome to the KCD2MP Tournament gamemode!")
  SendClientMessage(pid, COLOR_SERVER, "Type /duel challenge someone to a duel.")
  SendClientMessage(pid, COLOR_SERVER, "Accept or decline duel requests in the duel invite window.")
end

function OnPlayerSpawn(pid)
  local duelInfo = duel.findByPlayer(pid);

  if not duelInfo then
    return
  end

  duel.beginRound(duelInfo)
end

function OnPlayerDeath(pid, attacker)
  local duelInfo = duel.findByPlayer(pid)

  if not duelInfo then
    return
  end  
  
  duel.processRound(duelInfo, attacker, pid)
end