local duel = require("utils.duel")
local player = require("utils.players")
local ui = {};

-- Custom function to show the ui, to keep things clean with the error handling.
---@param pid number
---@param keyboard boolean
---@param cursor boolean
---@param keepInput boolean
function ui.show(pid, keyboard, cursor, keepInput)
  local shown, showReason = ShowPlayerWebFrame(pid, "frontend");
  if not shown then
    SendClientMessage(pid, COLOR_RED, "(ui.show): " .. tostring(showReason))
    return true
  end

  local focused, focusReason = SetPlayerWebFocus(pid, "frontend", keyboard, cursor, keepInput)
  if not focused then
    SendClientMessage(pid, COLOR_RED, "(ui.show): " .. tostring(focusReason))
    return false
  end
  return true
end

---A function to hide the ui.
---@param pid number
function ui.hide(pid) return HidePlayerWebFrame(pid, "frontend") end

function OnPlayerWebReady(pid, frame)
  if frame == "frontend" then
    local requestingUI = player.getRequestingUI(pid)
    if requestingUI ~= "" then
      SendClientEvent(pid, "panel.frontend", { router = requestingUI })
      player.setRequestingUI(pid, ui.UI_LIST.NO_UI)
    end
  end

end

function OnClientEvent(pid, name, payload, source)
  if source == "frontend" then
    if name == "panel.frontend.duel.fetch" then
      local x, y, z = GetPlayerPos(pid);
      local nearbyPlayers = {}
      for _, nearbyPid in ipairs(GetPlayersInRange(x, y, z, 20, GetPlayerVirtualWorld(pid))) do
        if nearbyPid ~= pid then
          local nearbyPlayer = player.get(nearbyPid)
          if nearbyPlayer then
            nearbyPlayers[#nearbyPlayers + 1] = {
              pid = nearbyPid,
              name = nearbyPlayer.name,
              elo = nearbyPlayer.playerDuels.elo,
            }
          end
        end
      end
      local playerData = player.get(pid)

      SendClientEvent(pid, "panel.frontend.duel.fetch.sendresponse", {
        nearbyPlayers = nearbyPlayers,
        player = {name = playerData.name, elo = playerData.playerDuels.elo},
      })
    end
    if name == ui.EMITS_NAMES.sendInvite then
        local settings, decodeReason = JsonDecode(payload or "")
        if decodeReason or settings == nil then
          SendClientMessage(pid, COLOR_RED, "Could not read duel settings.")
          return
        end

        local duelSettings, reason = duel.validateSettings(settings)
        if not duelSettings then
          SendClientMessage(pid, COLOR_RED, "(OnClientEvent, validate duel settings): " ..reason)
          return
        end

        local x, y, z = GetPlayerPos(pid);
          for _, nearbyPid in ipairs(GetPlayersInRange(x, y, z, 20, GetPlayerVirtualWorld(pid))) do
            if duelSettings.selectedPlayer.pid == nearbyPid and not nil then
              duel.add(pid, duelSettings.selectedPlayer.pid, duelSettings.numberOfRounds, duelSettings.time, duelSettings.useOwnWeapons, duelSettings.isRanked, duelSettings.weaponId, duelSettings.shieldId)
              ui.hide(pid);

              SendClientMessage(pid, COLOR_YELLOW, "You have invited " .. GetPlayerName(duelSettings.selectedPlayer.pid) .. "to duel.")

              player.setRequestingUI(duelSettings.selectedPlayer.pid, ui.UI_LIST.invite)
              ui.show(duelSettings.selectedPlayer.pid, true, true, true);
              break
            end
          end
    end

    if name == ui.EMITS_NAMES.fetchInvite then
      local duelData = duel.isPlayerInDuel(pid);

      if duelData ~= false then
        local opponentPid = duelData.playerOne == pid and duelData.playerTwo or duelData.playerOne
        local opponentData = player.get(opponentPid)
        if not opponentData then
          return
        end

        SendClientEvent(pid, ui.EMITS_NAMES.sendInviteReponse, {
          opponent = {
            name = opponentData.name,
            elo = opponentData.playerDuels.elo,
          },
          settings = duelData.settings,
        })
      end
    end

    if name == ui.EMITS_NAMES.declineInvite then
      local duelInfo = duel.findByPlayer(pid)

      if duelInfo == nil then
        SendClientMessage(pid, COLOR_YELLOW, "You don't have any pending duels.")
        return;
      end

      SendClientMessage(pid, COLOR_YELLOW, "You have denied ".. GetPlayerName(duelInfo.playerOne) .. "'s invite to duel.");
      SendClientMessage(duelInfo.playerOne, COLOR_YELLOW, "".. GetPlayerName(duelInfo.playerTwo) .. " declined your invite to duel");

      ui.hide(pid);
      duel.remove(duelInfo)
    end

    if name == ui.EMITS_NAMES.acceptInvite then
      local duelInfo = duel.findByPlayer(pid);
      if duelInfo == nil then
        SendClientMessage(pid, COLOR_YELLOW, "You don't have any pending duels.")
        return;
      end

            SendClientMessage(duelInfo.playerTwo, COLOR_YELLOW, "You have accepted ".. GetPlayerName(duelInfo.playerOne) .. "'s invite to duel.");
      SendClientMessage(duelInfo.playerOne, COLOR_YELLOW, "".. GetPlayerName(duelInfo.playerTwo) .. " accepted your invite to duel");

      ui.hide(duelInfo.playerTwo)
      duel.initiate(duelInfo)
    end
  end
end

ui.UI_LIST = {
  NO_UI = "",
  duelSettings = "duelsettings",
  invite = "duelinvite"
}

ui.EMITS_NAMES = {
  sendInvite = "panel.frontend.duel.sendinvite",
  fetchInvite = "panel.frontend.invite.fetch",
  sendInviteReponse = "panel.frontend.invite.fetch.sendresponse",
  acceptInvite = "panel.frontend.invite.accept",
  declineInvite = "panel.frontend.invite.decline"
}

return ui;