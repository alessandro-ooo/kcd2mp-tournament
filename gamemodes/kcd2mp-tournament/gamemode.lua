local duel = require("utils.duel")
local player = require("utils.players")
dofile("gamemodes/kcd2mp-tournament/commands.lua")

function OnGameModeInit()
  Log("Tournament gamemode")
end

function OnPlayerConnect(pid)
  player.add(pid)
  SendClientMessage(pid, COLOR_SERVER, "Welcome to the KCD2MP Tournament gamemode!")
  SendClientMessage(pid, COLOR_SERVER, "Type /duel <player_id|player_name> to challenge someone to a duel.")
  SendClientMessage(pid, COLOR_SERVER, "Accept or decline duel requests in the duel invite window.")
end

function OnPlayerDeath(pid, attacker)
  local duelInfo = duel.findByPlayer(pid)

  if not duelInfo or duelInfo.status ~= "fighting" then
    return
  end

  local roundWinner
  local roundLoser
  if pid == duelInfo.playerOne then
    roundLoser = duelInfo.playerOne
    roundWinner = duelInfo.playerTwo
  else
    roundLoser = duelInfo.playerTwo
    roundWinner = duelInfo.playerOne
  end

  if attacker ~= roundWinner then
    Log(string.format(
      "Duel round forfeit: victim=%d attacker=%d; opponent=%d takes the round",
      pid,
      attacker,
      roundWinner
    ))
  end

  if roundWinner == duelInfo.playerOne then
    duelInfo.playerOneRoundsWon = duelInfo.playerOneRoundsWon + 1
  else
    duelInfo.playerTwoRoundsWon = duelInfo.playerTwoRoundsWon + 1
  end
  duelInfo.currentRound = duelInfo.currentRound + 1

  SendClientMessage(roundLoser, COLOR_RED, string.format(
    "You lost round %d. Score: %d-%d.",
    duelInfo.currentRound,
    duelInfo.playerOneRoundsWon,
    duelInfo.playerTwoRoundsWon
  ))
  SendClientMessage(roundWinner, COLOR_GREEN, string.format(
    "You won round %d. Score: %d-%d.",
    duelInfo.currentRound,
    duelInfo.playerOneRoundsWon,
    duelInfo.playerTwoRoundsWon
  ))

  if duelInfo.currentRound < duelInfo.settings.numberOfRounds then
    return
  end

  duel.changeStatus(duelInfo, "finished")
  if duelInfo.playerOneRoundsWon > duelInfo.playerTwoRoundsWon then
    SendClientMessage(duelInfo.playerOne, COLOR_GREEN, "You won the duel!")
    SendClientMessage(duelInfo.playerTwo, COLOR_RED, GetPlayerName(duelInfo.playerOne) .. " won the duel.")
  elseif duelInfo.playerTwoRoundsWon > duelInfo.playerOneRoundsWon then
    SendClientMessage(duelInfo.playerTwo, COLOR_GREEN, "You won the duel!")
    SendClientMessage(duelInfo.playerOne, COLOR_RED, GetPlayerName(duelInfo.playerTwo) .. " won the duel.")
  else
    SendClientMessage(duelInfo.playerOne, COLOR_SERVER, "The duel ended in a tie.")
    SendClientMessage(duelInfo.playerTwo, COLOR_SERVER, "The duel ended in a tie.")
  end

  duel.remove(duelInfo)
end