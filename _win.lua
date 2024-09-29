local ffi = require("ffi")
local C = ffi.C

ffi.cdef[[

typedef short SHORT;
typedef unsigned short      WORD;
typedef unsigned long       DWORD;
typedef unsigned int        UINT;
typedef DWORD               *LPDWORD;
typedef int                 BOOL;
typedef void *HANDLE;

typedef struct _COORD {
    SHORT X;
    SHORT Y;
} COORD, *PCOORD;

typedef struct _SMALL_RECT {
    SHORT Left;
    SHORT Top;
    SHORT Right;
    SHORT Bottom;
} SMALL_RECT, *PSMALL_RECT;

typedef struct _CONSOLE_SCREEN_BUFFER_INFO {
    COORD dwSize;
    COORD dwCursorPosition;
    WORD  wAttributes;
    SMALL_RECT srWindow;
    COORD dwMaximumWindowSize;
} CONSOLE_SCREEN_BUFFER_INFO, *PCONSOLE_SCREEN_BUFFER_INFO;

BOOL
__stdcall
GetConsoleScreenBufferInfo(
    HANDLE hConsoleOutput,
    PCONSOLE_SCREEN_BUFFER_INFO lpConsoleScreenBufferInfo
    );

HANDLE
__stdcall
GetStdHandle(
    DWORD nStdHandle
    );

UINT
__stdcall
GetConsoleOutputCP(
    );
BOOL
__stdcall
SetConsoleOutputCP(
    UINT wCodePageID
    );

BOOL
__stdcall
GetConsoleMode(
    HANDLE hConsoleHandle,
    LPDWORD lpMode
    );

BOOL
__stdcall
SetConsoleMode(
    HANDLE hConsoleHandle,
    DWORD dwMode
    );
    
BOOL
__stdcall
WriteFile(
    HANDLE hFile,
    const void* lpBuffer,
    DWORD nNumberOfBytesToWrite,
    LPDWORD lpNumberOfBytesWritten,
    void* lpOverlapped
    );
    
]]


local width = 120
local height = 60
local old_cp = ffi.new('UINT[1]')
local old_mode = ffi.new('DWORD[1]')
local stdout

local function initialize()
    local csbi = ffi.new('CONSOLE_SCREEN_BUFFER_INFO')
    stdout = C.GetStdHandle(-11)
    if C.GetConsoleScreenBufferInfo(stdout, csbi) ~= 0 then
        width = csbi.srWindow.Right - csbi.srWindow.Left + 1
        height = csbi.srWindow.Bottom - csbi.srWindow.Top + 1
    end
    old_cp[0] = C.GetConsoleOutputCP()
    C.SetConsoleOutputCP(65001) -- CP_UTF8
    C.GetConsoleMode(stdout, old_mode)
    -- ENABLE_PROCESSED_OUTPUT | ENABLE_WRAP_AT_EOL_OUTPUT | ENABLE_VIRTUAL_TERMINAL_PROCESSING
    C.SetConsoleMode(stdout, 7)
end

local function uninitialize()
    C.SetConsoleMode(stdout, old_mode[0])
    C.SetConsoleOutputCP(old_cp[0])
end

local function window_size()
    return width, height
end

local function write(buf)
    local ptr, remain = buf:ref()
    local written = ffi.new('DWORD[1]')
    while remain ~= 0 do
        local to_write = math.min(remain, g_chunk_size)
        C.WriteFile(stdout, ptr, to_write, written, nil)
        remain = remain - written[0]
        ptr = ptr + written[0]
    end
end

return initialize, uninitialize, window_size, write
