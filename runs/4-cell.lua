-- converted from
-- https://github.com/alacritty/vtebench/tree/master/benchmarks/dense_cells

local columns = g_width
local lines = g_height

local str = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

return {
    label = 'cell',
    is_alt = true,
    payload = function()
        local buf = g_buf
        local offset = 0
        for ch in string.gmatch(str, utf8.charpattern) do
            buf:put('\27[H')
            for ln = 1, lines do
                for col = 1, columns do
                    index = ln + col + offset
                    fg = index % 156 + 100
                    bg = 255 - index % 156 + 100
                    buf:putf('\27[38;5;%d;48;5;%d;1;3;4m%s', fg, bg, ch)
                end
            end
            offset = offset + 1
        end
        return buf
    end
}
