local ffi = require("ffi")
local C = ffi.C

ffi.cdef[[
    struct winsize {
        unsigned short ws_row;
        unsigned short ws_col;
        unsigned short ws_xpixel;
        unsigned short ws_ypixel;
    };

    int ioctl(int fd, unsigned long op, ...);
    ssize_t write(int fildes, const void *buf, size_t nbyte);
]]

local function initialize()
end

local function uninitialize()
end

local function window_size()
    local ws = ffi.new('struct winsize')
    C.ioctl(0, 21523, ws) -- STDIN_FILENO, TIOCGWINSZ
    return ws.ws_col, ws.ws_row
end

local function write(buf)
    local ptr, remain = buf:ref()
    while remain ~= 0 do
        local to_write = math.min(remain, g_chunk_size)
        local written = tonumber(C.write(1, ptr, to_write)) -- STDOUT_FILENO
        remain = remain - written
        ptr = ptr + written
    end
end

return initialize, uninitialize, window_size, write

