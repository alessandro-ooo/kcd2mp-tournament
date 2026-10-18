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

---@param pid number
---@param uiName string
function ui.hide(pid, uiName) return HidePlayerWebFrame(pid, uiName) end

function OnPlayerWebReady(pid, frame)
  SendClientMessage(pid, COLOR_RED, "Current frame " ..frame)
  if frame == "frontend" then
    SendClientMessage(pid, COLOR_RED, "Inside IF frontend")
    local requestingUI = player.getRequestingUI(pid)
    SendClientMessage(pid, COLOR_RED, "Current requesting ui" ..requestingUI)
    if requestingUI ~= "" then
      SendClientEvent(pid, "panel.frontend", { router = requestingUI })
      player.setRequestingUI(pid, ui.UI_LIST.NO_UI)
    end
  end

end

-- TODO: Route player based on the requestedUI with web and client events.
function OnClientEvent(pid, name, payload, source)
  if source == "frontend" then
    if name == "panel.frontend.duel.fetch" then
      SendClientMessage(pid, COLOR_RED, "fetching duel")
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
        SendClientMessage(pid, COLOR_RED, "sendinvite")
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

        -- TODO: Player not being found for some reason
          for _, nearbyPid in ipairs(GetPlayersInRange(x, y, z, 20, GetPlayerVirtualWorld(pid))) do
            if duelSettings.selectedPlayer == nearbyPid and not nil then
              duel.add(pid, duelSettings.selectedPlayer, duelSettings.settings.numberOfRounds, duelSettings.settings.numberOfRounds, duelSettings.settings.useOwnWeapons, duelSettings.settings.isRanked, duelSettings.settings.weaponId, duelSettings.settings.shieldId)
              SendClientMessage(pid, COLOR_RED, "pid" ..duelSettings.selectedPlayer)
              player.setRequestingUI(duelSettings.selectedPlayer, ui.EMITS_NAMES.showInvite)
              ui.show(duelSettings.selectedPlayer, true, true, true);
              break
            end
          end
    end

    if name == ui.EMITS_NAMES.fetchInvite then
      local duelData = duel.isPlayerInDuel(pid);

      if duelData ~= false then
      SendClientEvent(pid, ui.EMITS_NAMES.sendInviteReponse, {
        duelData
      })
      end
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
  sendInviteReponse = "panel.frontend.invite.sendresponse"
}

return ui;