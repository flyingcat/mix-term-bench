local opt = {
    show_help = false,
    dyn = nil,
    dx = -1,
    dy = -1,
    dz = -1,
    include = {},
    exclude = {},
    files = {},
    rep_n = nil,
    rep_bytes = 1024 * 1024 * 128,
    data_path = nil,
    cmp_path = nil,
}

local n = #arg
local i = 1
local function next()
    if i > n then
        local s = arg[i - 1]
        error('Error: value for '..s..' expected')
    end
    local v =  arg[i]
    i = i + 1
    return v
end
local function parse_rep(str)
    local m
    local function match(patt)
        m = string.match(str, patt)
        return m
    end
    if match('^%d+$') then
        opt.rep_n = tonumber(m)
    elseif match('^(%d+)[mM][bB]?$') then
        opt.rep_bytes = tonumber(m) * 1024 * 1024
    elseif match('^(%d+.%d+)[mM][bB]?$') then
        opt.rep_bytes = math.floor(tonumber(m) * 1024 * 1024)
    elseif match('^(%d+)[gG][bB]?$') then
        opt.rep_bytes = tonumber(m) * 1024 * 1024 * 1024
    elseif match('^(%d+.%d+)[gG][bB]?$') then
        opt.rep_bytes = math.floor(tonumber(m) * 1024 * 1024 * 1024)
    else
        error('invalid value for "-r"')
    end
end
local function parse_filter(str)
    local i, s, n = 1, 1, #str
    local t = opt.include
    if string.sub(str, 1, 1) == '~' then
        t = opt.exclude
        i = 2
        s = 2
    end
    local sep = string.byte(',')
    local function put()
        -- local patt = string.gsub(string.sub(str, s, i - 1), '[*?]', '.%0')
        local patt = string.gsub(string.sub(str, s, i - 1), '[$()%.%[%]+-^]', '%%%0')
        patt = string.gsub(patt, '[*?]', '.%0')
        patt = '^'..patt..'$'
        table.insert(t, patt)
    end
    while i <= n do
        local ch = string.byte(str, i)
        if ch == sep then
            if s < i then
                put()
            end
            s = i + 1
        end
        i = i + 1
    end
    if s < i then
        put()
    end
end
while i <= n do
    local v = next()
    if v == '-h' or v == '--help' then
        opt.show_help = true
    elseif v == '-f' then
        parse_filter(next())
    elseif v == '-d' then
        opt.dyn = next()
    elseif v == '-dx' then
        opt.dx = tonumber(next())
    elseif v == '-dy' then
        opt.dy = tonumber(next())
    elseif v == '-dz' then
        opt.dz = tonumber(next())
    elseif v == '-r' then
        parse_rep(next())
    elseif v == '--data' then
        opt.data_path = next()
    elseif v == '--cmp' then
        opt.cmp_path = next()
    else
        if string.sub(v, 1, 1) == '-' then
            error('unknown option "'..v..'"')
        end
        table.insert(opt.files, v)
    end
end

-- for k, v in pairs(opt) do
--     print(k, v)
-- end
-- print('--files--')
-- for _, v in ipairs(opt.files) do
--     print(v)
-- end
-- print('--include--')
-- for _, v in ipairs(opt.include) do
--     print(v)
-- end
-- print('--exclude--')
-- for _, v in ipairs(opt.exclude) do
--     print(v)
-- end

return opt
