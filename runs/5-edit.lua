-- Poor simulation of text editing

local width = g_width
local height = g_height
local random = math.random

local function payload()
    local buf = g_buf
    local function put(s)
        buf:put(s)
    end
    local function putf(patt, ...)
        buf:putf(patt, ...)
    end
    local function randstr(cap)
        while cap > 0 do
            put('\27[38;2')
            local r = random(0, 255)
            local g = random(0, 255)
            local b = random(0, 255)
            local n = random(math.min(5, cap), math.min(10, cap))
            putf(';%d;%d;%dm', r, g, b)
            for _ = 1, n do
                put(string.char(random(33, 96)))
            end
            cap = cap -n
            put('\27[39;49m')
        end
    end
    for _ = 1, 10 do
        put('\27[?25l')
        put('\27[H')
        local max_ws = 20
        for _ = 1, height do
            local ws = random(0, math.min(max_ws, width))
            randstr(width - ws)
            put('\27[0m')
            put(string.rep(' ', ws))
            put'\r\27[B'
        end
        put('\r\27[?25h')
        for row = 1, height do
            for _ = 1, 100 do
                put('\27[?25l')
                local pos = math.random(1, width - max_ws)
                putf('\27[%d;%dH', row, pos)
                randstr(math.min(20, width - pos))
                put('\27[?25h')
            end
        end
    end
    return buf
end

return {
    label = 'edit',
    is_alt = true,
    payload = payload
}
