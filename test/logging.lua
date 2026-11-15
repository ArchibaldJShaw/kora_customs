-- Behavioural check: client/main.lua's migrated debug command reports through Kora.logging
-- (and not print). Loads the real client file under a permissive stub environment.
local function vector(x, y, z) return { x = x, y = y, z = z } end
vector3 = vector
Config = nil
dofile('shared/config.lua')
dofile('shared/catalog.lua')
dofile('shared/camera.lua')
dofile('shared/horn.lua')
Config.debug = true

local logged, commands = {}, {}
local function spy(level)
    return function(event, message, fields)
        logged[#logged + 1] = { level = level, event = event, message = message, fields = fields }
        return true
    end
end

-- Any unknown global/field is a callable no-op that returns itself.
local proxy
proxy = setmetatable({}, {
    __index = function() return proxy end,
    __call = function() return proxy end,
})
local function permissive(seed)
    return setmetatable(seed or {}, { __index = function() return proxy end })
end

Kora = permissive({
    logging = { trace = spy('trace'), debug = spy('debug'), info = spy('info'), warn = spy('warn'),
        error = spy('error'), fatal = spy('fatal'), isEnabled = function() return true end },
    lang = function(key) return key end,
})
for _, name in ipairs({ 'CreateThread', 'Wait', 'RegisterKeyMapping', 'AddEventHandler', 'RegisterNetEvent',
    'RegisterNUICallback', 'SetTimeout' }) do
    _G[name] = function() end
end
_G.RegisterCommand = function(name, handler) commands[name] = handler end
_G.exports = setmetatable({}, { __call = function() end, __index = function() return proxy end })
_G.PlayerPedId = function() return 1 end
_G.GetVehiclePedIsIn = function() return 0 end
_G.GetCurrentResourceName = function() return 'kora_customs' end
setmetatable(_G, { __index = function() return proxy end })

local printed = false
local realPrint = print
_G.print = function() printed = true end
local ok, err = pcall(dofile, 'client/main.lua')
_G.print = realPrint
assert(ok, 'client/main.lua loads under the stub environment: ' .. tostring(err))
assert(commands.getVehprop, 'getVehprop debug command registered')

commands.getVehprop()
assert(#logged == 1, 'one logger call for a missing vehicle, got ' .. #logged)
assert(logged[1].level == 'debug' and logged[1].event == 'debug.no_vehicle', 'debug level with a stable event name')
assert(printed == false, 'no raw print')
print('kora_customs logging: ok')
