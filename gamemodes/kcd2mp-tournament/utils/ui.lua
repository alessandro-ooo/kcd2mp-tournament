local duel = require("utils.duel")
local ui = {};

-- Custom function to show the ui, to keep things clean with the error handling.

---@param pid number
---@param uiName string
---@param keyboard boolean
---@param cursor boolean
---@param keepInput boolean

function ui.show(pid, uiName, keyboard, cursor, keepInput)
  local shown, showReason = ShowPlayerWebFrame(pid, uiName);

  if not shown then
    SendClientMessage(pid, COLOR_RED, "(ui.shown): " .. tostring(showReason))
    return true
  end

  local focused, focusReason = SetPlayerWebFocus(pid, uiName, keyboard, cursor, keepInput)
  if not focused then
    SendClientMessage(pid, COLOR_RED, "(ui.shown): " .. tostring(focusReason))
    return false
  end
  return true
end

---@param pid number
---@param uiName string
function ui.hide(pid, uiName) return HidePlayerWebFrame(pid, uiName) end

function OnPlayerWebReady(pid, frame)

  if frame == ui.UI_LIST.duelSettings then
    local isPlayerInDuel = duel.isPlayerInDuel(pid)
    if isPlayerInDuel == false then
      local data = duel.getData(pid);
      local eventTo = string.format("panel.%s", frame)

      local sent, sendReason = SendClientEvent(pid, eventTo, data)
      if not sent then
        SendClientMessage(pid, COLOR_RED, "(ui.shown): " .. tostring(sendReason))
        return false
      end
    end
  end
end

function OnClientEvent(pid, name, payload, source)
  if source == ui.UI_LIST.duelSettings then
    if name == ui.EMITS_NAMES.duelSettings_SendInvite then
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
          if duelSettings.selectedPlayer == nearbyPid and not nil then
            duel.add(pid, duelSettings.selectedPlayer, duelSettings.settings.numberOfRounds, duelSettings.settings.numberOfRounds, duelSettings.settings.useOwnWeapons, duelSettings.settings.isRanked, duelSettings.settings.weaponId, duelSettings.settings.shieldId)
            -- TODO: SHOOW INvITE
            break
          end
        end
    end
  end
end

ui.UI_LIST = {
  duelSettings = "duelsettings"
}

ui.EMITS_NAMES = {
  duelSettings_SendInvite = "panel.duelsettings.sendInvite"
}

return ui;