---@class DuelSettings
---@field time number
---@field useOwnWeapons boolean
---@field weaponId? number
---@field shieldId? number
---@field isRanked boolean
---@field numberOfRounds number

---@class Duel
---@field playerOne number
---@field playerTwo number
---@field status string
---@field currentRound number
---@field playerOneRoundsWon number
---@field playerTwoRoundsWon number
---@field settings DuelSettings

---@class Duels
---@field duels table<number, Duel>

---@type Duels
local data = {
  duels = {}
}


return data;