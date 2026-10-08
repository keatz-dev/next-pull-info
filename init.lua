local _, NPI = ...
_G["MDT_NPI"] = NPI

-- Missing translations fall back to the English key.
NPI.L = setmetatable({}, { __index = function(_, key) return key end })
