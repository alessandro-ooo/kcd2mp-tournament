local data = require("data");
dofile("gamemodes/kcd2mp-tournament/commands.lua")


function OnGameModeInit()
  Log("Tournament gamemode")
end

function OnPlayerConnect(pid)
  SendClientMessage(pid, COLOR_SERVER, "Welcome to the KCD2MP Tournament gamemode!")
  SendClientMessage(pid, COLOR_SERVER, "Type /duel <player_id|player_name> to challenge someone to a duel.")
  SendClientMessage(pid, COLOR_SERVER, "Type /accept to accept a duel request or /decline to decline.")
end

