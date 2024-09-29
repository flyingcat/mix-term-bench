local opt = dofile('./_opt.lua')
if opt.show_help then
    print('help: TODO')
    return
end

local buffer = require("string.buffer")
local ffi = require("ffi")
local C = ffi.C

math.randomseed(14159, 26535)
utf8 = { charpattern = '[%z1-\xF7\xC2-\xFD][\x80-\xBF]*' }

g_chunk_size = 1024 * 1024 * 128
g_buf = buffer.new(1024 * 1024 * 8)

local measure
do
    if jit.os == 'Windows' then
        ffi.cdef [[
            int __stdcall QueryPerformanceFrequency(int64_t* lpFrequency);
            int __stdcall QueryPerformanceCounter(int64_t* lpFrequency);
        ]]
        local ints = ffi.new('int64_t[3]')
        local frequency = ints + 0
        C.QueryPerformanceFrequency(frequency)
        measure = function(f)
            local beg_time = ints + 1
            C.QueryPerformanceCounter(beg_time)
            f()
            local end_time = ints + 2
            C.QueryPerformanceCounter(end_time)
            return tonumber((end_time[0] - beg_time[0]) * 1000000 / frequency[0]) / 1000000
        end
    else
        ffi.cdef[[
            struct timespec {
                long tv_sec;
                long tv_nsec;
            };
            int clock_gettime(int32_t clk_id, struct timespec *tp);
        ]]

        --[[
        CLOCK_REALTIME              0
        CLOCK_MONOTONIC             1
        CLOCK_PROCESS_CPUTIME_ID    2
        CLOCK_THREAD_CPUTIME_ID     3
        CLOCK_MONOTONIC_RAW         4
        CLOCK_REALTIME_COARSE       5
        CLOCK_MONOTONIC_COARSE      6
        CLOCK_BOOTTIME              7
        ]]

        local function diff(start, e)
            local temp = ffi.new('struct timespec')
            if (e.tv_nsec-start.tv_nsec)<0 then
                temp.tv_sec = e.tv_sec-start.tv_sec-1;
                temp.tv_nsec = 1000000000+e.tv_nsec-start.tv_nsec;
            else
                temp.tv_sec = e.tv_sec-start.tv_sec;
                temp.tv_nsec = e.tv_nsec-start.tv_nsec;
            end
            return tonumber(temp.tv_sec) + tonumber(temp.tv_nsec) / 1000000000;
        end

        local t1 = ffi.new('struct timespec')
        local t2 = ffi.new('struct timespec')
        measure = function(f)
            C.clock_gettime(1, t1)
            f()
            C.clock_gettime(1, t2)
            return diff(t1, t2)
        end
    end
end

local sleep
if ffi.os == "Windows" then
    ffi.cdef[[
        void Sleep(int ms);
    ]]
    function sleep(s)
        C.Sleep(s*1000)
    end
else
    ffi.cdef[[
        int poll(struct pollfd *fds, unsigned long nfds, int timeout);
    ]]
    function sleep(s)
        C.poll(nil, 0, s*1000)
    end
end

local function filename_info(path)
    local m = string.match(path, '[\\/]([^\\/]+)$')
    if m then path = m end
    local m1 = string.match(path, '.*%.lua$')
    local m2 = string.match(path, '.*%.alt%.lua$')
    return path, m1 ~= nil, m2 ~= nil
end

local runs = {}
do
    if #opt.files ~= 0 then
        for _, f in ipairs(opt.files) do
            local basename, is_lua, is_alt = filename_info(f)
            local t = {
                label = basename,
                is_alt = is_alt,
                payload = function()
                    if is_lua then
                        return dofile(f)
                    else
                        local file = io.open(f, 'rb')
                        local ct = file:read('a')
                        file:close()
                        return ct
                    end
                end
            }
            table.insert(runs, { tasks = t })
        end
    else
        local cmd
        if jit.os == 'Windows' then
            cmd = 'dir .\\runs\\*.lua /b /a-d'
        else
            cmd = 'ls ./runs/*.lua | xargs -n 1 basename'
        end
        local pfile = io.popen(cmd)
        for fname in pfile:lines() do
            local t = {
                path = './runs/'..fname,
                -- name = fname:sub(1, -5):gsub('^%d%-', ''),
            }
            table.insert(runs, t)
        end
        pfile:close()
    end
end

local function interfaces()
    if opt.dyn then
        ffi.cdef [[
            void vt_initialize(int x, int y, int z);
            void vt_uninitialize();
            void vt_window_size(int* w, int* h);
            void vt_write(const void* buf, uint32_t nbyte);
        ]]
        local dynlib = ffi.load(opt.dyn)
        return  function() dynlib.vt_initialize(opt.dx, opt.dy, opt.dz) end,
                function() dynlib.vt_uninitialize() end,
                function()
                    local ws = ffi.new('int[2]')
                    dynlib.vt_window_size(ws, ws + 1)
                    print(string.format('dynlib mode with size %dx%d', ws[0], ws[1]))
                    return ws[0], ws[1]
                end,
                function(buf)
                    local ptr, n = buf:ref()
                    dynlib.vt_write(ptr, n)
                end
    end
    if jit.os == 'Windows' then
        return dofile('./_win.lua')
    else
        return dofile('./_nix.lua')
    end
end

local initialize, uninitialize, window_size, write = interfaces()

initialize()

g_width, g_height = window_size()

local function rep_n(len)
    if opt.rep_n then
        return opt.rep_n
    end
    return math.ceil(opt.rep_bytes / len)
end

local function filter(s)
    if #opt.include ~= 0 then
        for _, v in ipairs(opt.include) do
            local m = string.match(s, v)
            if m then return true end
        end
        return false
    else
        for _, v in ipairs(opt.exclude) do
            local m = string.match(s, v)
            if m then return false end
        end
        return true
    end
end

local function write_string(s)
    write(buffer:new():set(s))
end

local results = {}
for _, run in ipairs(runs) do
    local tasks = run.tasks
    if not tasks then
        tasks = dofile(run.path)
    end
    if #tasks == 0 then tasks = { tasks } end
    for _, item in ipairs(tasks) do
        if not filter(item.label) then
            goto continue
        end
        g_buf:reset()
        if opt.dyn then
            local tip = 'running '..item.label..' ...'
            io.write('\r\27[K'..tip)
        end
        if item.is_alt then
            write_string('\27[?1049h')
        end
        local payload = item.payload
        if type(payload) == 'function' then payload = payload() end
        if type(payload) == 'string' then
            local buf = buffer.new()
            buf:set(payload)
            payload = buf
        elseif type(payload) == 'table' then
            for _, v in ipairs(payload) do
                g_buf:put(v)
                g_buf:put('\r\n')
            end
            payload = g_buf
        end
        local n = rep_n(#payload)
        local time = measure(function()
            for _ = 1, n do
                write(payload)
            end
        end)
        if item.is_alt then
            write_string('\27[?1049l')
        end
        if not opt.dyn then
            sleep(0.2)
        end
        table.insert(results, { label = item.label, time = time, bytes = #payload * n })
        ::continue::
    end
end

uninitialize()

if opt.dyn then
    io.write('\r\27[K\r')
else
    io.write('\27c')
    print(string.format('terminal size %dx%d', g_width, g_height))
end

local function f_pad_left(f, n, ...)
    local str = string.format(f, ...)
    return string.rep(' ', n - #str)..str
end
local function f_pad_right(f, n, ...)
    local str = string.format(f, ...)
    return str..string.rep(' ', n - #str)
end

local cmp_dict = {}
do
    if opt.cmp_path then
        local f, err = io.open(opt.cmp_path, 'rb')
        if err then
            print('Failed to open path: '..opt.cmp_path)
        else
            for line in f:lines() do
                local key, val = string.match(line, '^<(.+)><(%d+%.?%d*)>$')
                if key then
                    cmp_dict[key] = tonumber(val)
                end
            end
        end
    end
end

for _, item in ipairs(results) do
    local label = item.label .. string.rep(' ', 20 - #item.label)
    local length = f_pad_left('%.03f', 10, item.bytes / 1024 / 1024)
    local time = f_pad_right('%.03f', 10, item.time)
    item.mpers = item.bytes / 1024 / 1024 / item.time
    local mpers = f_pad_left('%.03f', 10, item.mpers)
    local cmp = ''
    if opt.cmp_path and cmp_dict[item.label] then
        local val = (item.mpers / cmp_dict[item.label] - 1) * 100;
        cmp = string.format('%+.02f%%', val)
        if (val > 0 and val < 1) or (val < 0 and val > -1) then
            cmp = '\27[38;2;180;180;180m'..cmp..'\27[39;49m'
        end
    end
    print(string.format('%s    %s / %s    %s MB/s %s', label, length, time, mpers, cmp))
end

if opt.data_path then
    local f, err = io.open(opt.data_path, 'wb')
    if err then
        print('Failed to open path: '..opt.data_path)
    else
        for _, item in ipairs(results) do
            f:write(string.format('<%s><%f>\n', item.label, item.mpers))
        end
        print('\nresult saved to: '..opt.data_path)
    end
end
