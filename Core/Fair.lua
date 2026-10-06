-- Fair: a sealed secret and a shuffle every addon can repeat.
--
-- Card games can't deal from public /rolls alone: anyone could work out
-- everyone's cards. So the host's addon picks a secret and first shows only
-- its SHA-256 fingerprint (the "seal"). Then a player cuts the deck with a
-- real /roll. The deck is shuffled from secret + cut, so the host could not
-- pick a good deck in advance (the cut wasn't known) or swap the secret
-- afterwards (the seal would not match). After the hand the secret is shown
-- and every addon checks the whole deal.
local ADDON, ns = ...

local F = {}
ns.Fair = F

local band, bor, bxor, bnot, rshift, lshift = bit.band, bit.bor, bit.bxor, bit.bnot, bit.rshift, bit.lshift
local MOD = 4294967296

local K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function U(x) return x % MOD end
local function Rot(x, n) return U(bor(rshift(x, n), lshift(x, 32 - n))) end

-- SHA-256 of a string, as 8 numbers.
local function Digest(msg)
    local len = #msg
    local bits = len * 8
    msg = msg .. "\128" .. string.rep("\0", (55 - len) % 64)
        .. string.char(0, 0, 0, 0,
            math.floor(bits / 16777216) % 256, math.floor(bits / 65536) % 256,
            math.floor(bits / 256) % 256, bits % 256)

    local h = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }
    local w = {}
    for chunk = 1, #msg, 64 do
        for i = 1, 16 do
            local b1, b2, b3, b4 = msg:byte(chunk + (i - 1) * 4, chunk + (i - 1) * 4 + 3)
            w[i] = ((b1 * 256 + b2) * 256 + b3) * 256 + b4
        end
        for i = 17, 64 do
            local x, y = w[i - 15], w[i - 2]
            local s0 = U(bxor(Rot(x, 7), Rot(x, 18), rshift(x, 3)))
            local s1 = U(bxor(Rot(y, 17), Rot(y, 19), rshift(y, 10)))
            w[i] = U(w[i - 16] + s0 + w[i - 7] + s1)
        end
        local a, b, c, d, e, f, g, hh = h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8]
        for i = 1, 64 do
            local S1 = U(bxor(Rot(e, 6), Rot(e, 11), Rot(e, 25)))
            local ch = U(bxor(band(e, f), band(U(bnot(e)), g)))
            local t1 = U(hh + S1 + ch + K[i] + w[i])
            local S0 = U(bxor(Rot(a, 2), Rot(a, 13), Rot(a, 22)))
            local maj = U(bxor(band(a, b), band(a, c), band(b, c)))
            local t2 = U(S0 + maj)
            hh, g, f, e, d, c, b, a = g, f, e, U(d + t1), c, b, a, U(t1 + t2)
        end
        h[1], h[2], h[3], h[4] = U(h[1] + a), U(h[2] + b), U(h[3] + c), U(h[4] + d)
        h[5], h[6], h[7], h[8] = U(h[5] + e), U(h[6] + f), U(h[7] + g), U(h[8] + hh)
    end
    return h
end

function F.Hash(msg)
    local h = Digest(msg)
    local out = {}
    for i = 1, 8 do out[i] = string.format("%08x", h[i]) end
    return table.concat(out)
end

-- A fresh secret for one hand.
function F.NewSecret()
    local parts = { tostring(time and time() or 0), tostring(GetTime and GetTime() or 0) }
    for i = 1, 6 do parts[#parts + 1] = tostring(math.random(0, 2147483646)) end
    return F.Hash(table.concat(parts, ":")):sub(1, 32)
end

-- Random numbers from secret + cut: SHA-256 of "<secret>:<cut>:<block>".
local function Stream(secret, cut)
    local block, words, pos = 0, nil, 9
    return function()
        if pos > 8 then
            block = block + 1
            words = Digest(secret .. ":" .. tostring(cut) .. ":" .. block)
            pos = 1
        end
        pos = pos + 1
        return words[pos - 1]
    end
end

-- The shuffled deck (cards 1-52) for this secret and cut.
function F.Deck(secret, cut)
    local next = Stream(secret, cut)
    local deck = {}
    for i = 1, 52 do deck[i] = i end
    for i = 52, 2, -1 do
        local j = next() % i + 1
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

-- n numbers in 1..size from secret + cut (for games that are not cards).
function F.Draw(secret, cut, n, size)
    local next = Stream(secret, cut)
    local out = {}
    for i = 1, n do out[i] = next() % size + 1 end
    return out
end
