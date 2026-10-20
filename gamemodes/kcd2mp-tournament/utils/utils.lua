local utils = {}

function utils.isIntegerInRange(value, min, max)
  return type(value) == "number"
    and value % 1 == 0
    and value >= min
    and value <= max
end

return utils;