local duel = require("utils.duel")
local pendingDuelSettingsRoute = {}

function OnPlayerCommandText(pid, cmd, args)
  cmd = cmd:lower()
  if cmd == "duel" then
    local target, reason = sscanf(args, "u") or sscanf(args, "s")
    if target == false then
      SendClientMessage(pid, COLOR_RED, "usage: /duel <player_id|player_name> - " .. reason)
      return true
    end

    if duel.isPlayerInDuel(pid) then
      SendClientMessage(pid, COLOR_RED, "You are already in a duel.")
      return true
    end

    if duel.isPlayerInDuel(target) then
      SendClientMessage(pid, COLOR_RED, "The target player is already in a duel.")
      return true
    end
    SendClientMessage(pid, COLOR_SERVER, "Duel request sent to " .. target)
    SendClientMessage(target, COLOR_SERVER, "Duel request from " .. GetPlayerName(pid) .. ". Type /acceptduel to accept or /declineduel to decline.")
    
    duel.add(pid, target);
    return true
  end

  if cmd == "acceptduel" then
    local duelData = duel.findByPlayer(pid)
    if duelData and duelData.status == "pending" then
      duel.changeStatus(duelData, "accepted")
      SendClientMessage(duelData.playerOne, COLOR_SERVER, GetPlayerName(pid) .. " has accepted your duel request.")
      SendClientMessage(duelData.playerTwo, COLOR_SERVER, "You have accepted the duel request from " .. GetPlayerName(duelData.playerOne) .. ". Waiting for player one to start the duel.")

      local shown, showReason = ShowPlayerWebFrame(duelData.playerOne, "duelsettings")

      if not shown then
        SendClientMessage(duelData.playerOne, COLOR_RED, "Could not show interface: " .. tostring(showReason))
        return true
      end

      local focused, focusReason = SetPlayerWebFocus(duelData.playerOne, "duelsettings", true, true, true)
      if not focused then
        SendClientMessage(duelData.playerOne, COLOR_RED, "Interface opened, but mouse focus failed: " .. tostring(focusReason))
      end

      if IsPlayerWebFrameReady(duelData.playerOne, "duelsettings") then
        pendingDuelSettingsRoute[duelData.playerOne] = nil
        local sent, sendReason = SendClientEvent(duelData.playerOne, "panel.duelsettings", { "main" })
        if not sent then
          SendClientMessage(duelData.playerOne, COLOR_RED, "Could not open duel settings page: " .. tostring(sendReason))
        end
      else
        pendingDuelSettingsRoute[duelData.playerOne] = true
      end
    end
  end

  if cmd == "declineduel" then
    local duelData = duel.findByPlayer(pid)
    if duelData and duelData.status == "pending" then
      duel.remove(duelData)
      SendClientMessage(duelData.playerOne, COLOR_SERVER, GetPlayerName(pid) .. " has declined your duel request.")
      SendClientMessage(duelData.playerTwo, COLOR_SERVER, "You have declined the duel request from " .. GetPlayerName(duelData.playerOne) .. ".")
    else
      SendClientMessage(pid, COLOR_RED, "You have no pending duel requests.")
    end
  end

  if cmd == "getduelstatus" then
    local duelData = duel.findByPlayer(pid)
    if duelData then
      SendClientMessage(
        pid,
        COLOR_SERVER,
        "(DEBUG) Current duel: " .. GetPlayerName(duelData.playerOne)
          .. " vs " .. GetPlayerName(duelData.playerTwo)
          .. " (" .. duelData.status .. ")"
      )
    else
      SendClientMessage(pid, COLOR_RED, "You are not currently in a duel.")
    end
  end

  if cmd == "reload" then
    ReloadGameMode();
  end

  if cmd == "test" then
    local shown, showReason = ShowPlayerWebFrame(pid, "duelsettings")
    if not shown then
      SendClientMessage(pid, COLOR_RED, "Could not show interface: " .. tostring(showReason))
      return true
    end

    local focused, focusReason = SetPlayerWebFocus(pid, "duelsettings", true, true, true)
    if not focused then
      SendClientMessage(pid, COLOR_RED, "Interface opened, but mouse focus failed: " .. tostring(focusReason))
    end
    return true
  end

  return true
end

function OnPlayerWebReady(pid, frame)
  if frame == "duelsettings" and pendingDuelSettingsRoute[pid] then
    pendingDuelSettingsRoute[pid] = nil
    local sent, sendReason = SendClientEvent(pid, "panel.duelsettings", { "main" })
    if not sent then
      SendClientMessage(pid, COLOR_RED, "Could not open duel settings page: " .. tostring(sendReason))
    end
  end
end

function OnPlayerDisconnect(pid)
  pendingDuelSettingsRoute[pid] = nil
end