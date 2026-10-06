-- Serialize: turns a game table into a string for addon messages and back.
-- Plain values only (tables, strings, numbers, booleans). Keys starting with
-- "_" are local-only and never sent.
local ADDON, ns = ...

local S = {}
ns.Serialize = S

local function Escape(s)
    return (s:gsub("[%%~{}|\n]", function(c) return string.format("%%%02X", c:byte()) end))
end

local function Unescape(s)
    return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function Encode(v, out)
    local t = type(v)
    if t == "table" then
        out[#out + 1] = "{"
        for k, x in pairs(v) do
            if not (type(k) == "string" and k:sub(1, 1) == "_") and type(x) ~= "function" then
                Encode(k, out)
                Encode(x, out)
            end
        end
        out[#out + 1] = "}"
    elseif t == "string" then
        out[#out + 1] = "s" .. Escape(v) .. "~"
    elseif t == "number" then
        out[#out + 1] = "n" .. tostring(v) .. "~"
    elseif t == "boolean" then
        out[#out + 1] = v and "T" or "F"
    end
end

function S.Encode(v)
    local out = {}
    Encode(v, out)
    return table.concat(out)
end

-- Returns value, next position; errors on malformed input.
local function Decode(str, pos)
    local c = str:sub(pos, pos)
    if c == "{" then
        local t = {}
        pos = pos + 1
        while str:sub(pos, pos) ~= "}" do
            if pos > #str then error("unterminated table") end
            local k, v
            k, pos = Decode(str, pos)
            v, pos = Decode(str, pos)
            t[k] = v
        end
        return t, pos + 1
    elseif c == "s" or c == "n" then
        local stop = str:find("~", pos + 1, true)
        if not stop then error("unterminated value") end
        local raw = str:sub(pos + 1, stop - 1)
        if c == "s" then return Unescape(raw), stop + 1 end
        return tonumber(raw), stop + 1
    elseif c == "T" then
        return true, pos + 1
    elseif c == "F" then
        return false, pos + 1
    end
    error("bad token at " .. pos)
end

-- Never throws: a broken message from another player just returns nil.
function S.Decode(str)
    local ok, v = pcall(Decode, str or "", 1)
    if ok then return v end
end
