---@class DuelSettings
---@field time number
---@field useOwnWeapons boolean
---@field weaponId? string the selected weapon's game table name
---@field shieldId? string the selected shield's game table name
---@field isRanked boolean
---@field numberOfRounds number

---@class Duel
---@field playerOne number
---@field playerTwo? number
---@field status string
---@field currentRound number
---@field playerOneRoundsWon number
---@field playerTwoRoundsWon number
---@field settings DuelSettings

---@class PlayerUI
---@field requestingUI string

---@class PlayerDuels
---@field elo number
---@field lost number
---@field won number

---@class Player
---@field pid number
---@field name string
---@field playerUI PlayerUI
---@field playerDuels PlayerDuels

---@class Data
---@field duels Duel[]
---@field players Player[]

---@type Data
local data = {
  duels = {},
  players = {},
}

return data