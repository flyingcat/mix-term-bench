-- converted from
-- https://github.com/alacritty/vtebench/tree/master/benchmarks/cursor_motion

local columns = g_width
local lines = g_height

local str = {
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
    "類指興唱秋授通動朝商教経推比検決ソツエけうせゆはひドトムメヨ민은행위시의법률에의하여범죄를구성하지아니하",
}

local function run(width)
    local buf = g_buf

    if width == 2 and columns % 2 == 1 then columns = columns - 1 end

    for ch in string.gmatch(str[width], utf8.charpattern) do
        local column_start = 1
        local column_end = columns - width + 1
        local line_start = 1
        local line_end = lines

        while true do
            local column = column_start
            local line = line_start

            local function out()
                buf:put(string.format('\27[%d;%dH%s', line, column, ch))
            end

            while column < column_end do
                out()
                column = column + width
            end

            while line < line_end do
                out()
                line = line + 1
            end

            while column > column_start do
                out()
                column = column - width
            end

            while line > line_start do
                out()
                line = line - 1
            end

            column_start = column_start + width
            line_start = line_start + 1
            column_end = column_end - width
            line_end = line_end - 1


            if column_start > column_end or line_start > line_end then
                break
            end
        end
    end

    return buf
end

return {
    {
        label = 'cursor-a',
        payload = function() return run(1) end
    },
    {
        label = 'cursor-u',
        payload = function() return run(2) end
    },
}