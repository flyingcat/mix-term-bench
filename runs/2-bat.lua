return {
    {
        label = 'bat-a',
        payload = function()
            local file = io.open('./assets/jquery.js.bin', 'rb')
            local ct = file:read('a')
            file:close()
            return ct
        end
    },
    {
        label = 'bat-u',
        payload = function()
            local file = io.open('./assets/moon.html.bin', 'rb')
            local ct = file:read('a')
            file:close()
            return ct
        end
    },
}
