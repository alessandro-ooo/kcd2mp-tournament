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
  Log(string.format(
    "Web event: player=%s name=%s source=%s payload=%s",
    tostring(pid),
    tostring(name),
    tostring(source),
    tostring(payload)
  ))

  local settings, decodeReason = JsonDecode(payload or "")
  if type(settings) ~= "table" then
    SendClientMessage(pid, COLOR_RED, "Could not read duel settings: " .. tostring(decodeReason or "invalid payload"))
    return
  end

  if type(settings.time) ~= "number" or settings.time % 1 ~= 0 or settings.time < 1 or settings.time > 3600
    or type(settings.numberOfRounds) ~= "number" or settings.numberOfRounds % 1 ~= 0
    or settings.numberOfRounds < 1 or settings.numberOfRounds > 3
    or type(settings.useOwnWeapons) ~= "boolean" or type(settings.isRanked) ~= "boolean"
    or (settings.weaponId ~= nil and (type(settings.weaponId) ~= "number" or settings.weaponId % 1 ~= 0 or settings.weaponId < 1))
    or (settings.shieldId ~= nil and (type(settings.shieldId) ~= "number" or settings.shieldId % 1 ~= 0 or settings.shieldId < 1)) then
    SendClientMessage(pid, COLOR_RED, "Duel settings are invalid.")
    return
  end

  local duelInfo = duel.findByPlayer(pid)
  if not duelInfo or duelInfo.status ~= "accepted" or duelInfo.playerOne ~= pid then
    SendClientMessage(pid, COLOR_RED, "You have no accepted duel to start.")
    return
  end

  duelInfo.settings = {
    time = settings.time,
    useOwnWeapons = settings.useOwnWeapons,
    weaponId = settings.weaponId,
    shieldId = settings.shieldId,
    isRanked = settings.isRanked,
    numberOfRounds = settings.numberOfRounds,
  }
  duel.changeStatus(duelInfo, "fighting")
  SendClientMessage(pid, COLOR_SERVER, string.format(
    "Duel settings received: %d seconds, %d round(s), own weapons %s, ranked %s.",
    settings.time,
    settings.numberOfRounds,
    settings.useOwnWeapons and "on" or "off",
    settings.isRanked and "on" or "off"
  ))
  SendClientMessage(duelInfo.playerTwo, COLOR_SERVER, GetPlayerName(pid) .. " has started the duel.")
  HidePlayerWebFrame(pid, "duelsettings")
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