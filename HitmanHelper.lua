script_name('HitmanHelper')
script_author("Webb")
script_version("14.06.2023")
script_version_number(1)

local main_color, main_color_hex = 0xB8B6B6FF, "{B8B6B6}"
local prefix, updating_prefix, error_prefix = "{B8B6B6}[HitMan]{FFFAFA} ", "{FF0000}[UPDATING]{FFFAFA} ",
    "{FF0000}[ERROR] "

function try(f, catch_f)
    local status, exception = pcall(f)
    if not status then
        catch_f(exception)
    end
end

try(function()
    ev = require 'samp.events'
    imgui = require 'imgui'
    imgui.ToggleButton = require('imgui_addons').ToggleButton
    inicfg = require 'inicfg'
    dlstatus = require'moonloader'.download_status
    encoding = require 'encoding'
    encoding.default = 'CP1251'
    u8 = encoding.UTF8
end, function(e)
    sampAddChatMessage(prefix .. error_prefix .. "An error occurred while loading libraries", 0xFF0000)
    sampAddChatMessage(prefix .. error_prefix .. "For more information, view the console (~)", 0xFF0000)
    print(error_prefix .. e)
    thisScript():unload()
end)

local hit_ini, server

local config = {
    settings = {
        aim = true,
        player = true,
        radar = true,
        cooldown = true
    }
}

if hit_ini == nil then -- загружаем конфиг
    hit_ini = inicfg.load(config, HitmanHelper)
    inicfg.save(hit_ini, HitmanHelper)
end

local script = {
    loaded = false,
    unload = false,
    update = false,
    checkedUpdates = false,
    author = "Cody_Webb",
    telegram = {
        nick = "@ibm287",
        url = "https://t.me/ibm287"
    },
    request = {
        complete = true,
        free = true
    }
}

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then
        return
    end
    while not isSampAvailable() do
        wait(0)
    end
    
    while sampGetCurrentServerName() == "SA-MP" do
        wait(0)
    end
    server = sampGetCurrentServerName():gsub('|', '')
    server = (server:find('02') and 'Two' or (server:find('Revo') and 'Revolution' or
                 (server:find('Legacy') and 'Legacy' or (server:find('Classic') and 'Classic' or nil))))
    if server == nil then
        script.sendMessage('Данный сервер не поддерживается, выгружаюсь...')
        script.unload = true
        thisScript():unload()
    end

    imgui.ApplyCustomStyle()
    local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
    local path = getFolderPath(0x14)
    fonts.arial28 = imgui.GetIO().Fonts:AddFontFromFileTTF(path .. '\\arial.ttf', toScreenX(28 / 3), nil, glyph_ranges)

    togglebools = {
        aim = hit_ini.settings.aim and imgui.ImBool(true) or imgui.ImBool(false),
        player = hit_ini.settings.player and imgui.ImBool(true) or imgui.ImBool(false),
        radar = hit_ini.settings.radar and imgui.ImBool(true) or imgui.ImBool(false),
        cooldown = hit_ini.settings.cooldown and imgui.ImBool(true) or imgui.ImBool(false)
    }

    sampRegisterChatCommand("hitman", function()
        imgui.main.v = not imgui.main.v
    end)

    script.loaded = true

    while sampGetGamestate() ~= 3 do
        wait(0)
    end
    while sampGetPlayerScore(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) <= 0 and not sampIsLocalPlayerSpawned() do
        wait(0)
    end

    script.checkUpdates()

    while not script.checkedUpdates do
        wait(0)
    end

    script.sendMessage("Успешно запущен. Открыть меню - " .. main_color_hex .. "/hitman")

    imgui.Process = true

    while true do
        wait(0)
        imgui.ShowCursor = false
        if imgui.main.v then
            imgui.LockPlayer = true
        end
    end
end

function script.checkUpdates() -- проверка обновлений
    lua_thread.create(function()
        local response = request("https://raw.githubusercontent.com/WebbLua/HitmanHelper/main/version.json")
        local data = decodeJson(response)
        if data == nil then
            script.sendMessage("Не удалось получить информацию про обновления")
            script.unload = true
            thisScript():unload()
            return
        end
        script.url = data.url
        if data.author then
            script.author = data.author
        end
        if data.telegram then
            script.telegram = data.telegram
        end
        if data.version > thisScript()['version_num'] then
            script.sendMessage(updating_prefix .. "Обнаружена новая версия скрипта от " ..
                                   data.date .. ", начинаю обновление...")
            script.updateScript()
            return true
        end
        script.checkedUpdates = true
    end)
end

function request(url) -- запрос по URL
    while not script.request.free do
        wait(0)
    end
    script.request.free = false
    local path = os.tmpname()
    while true do
        script.request.complete = false
        download_id = downloadUrlToFile(url, path, download_handler)
        while not script.request.complete do
            wait(0)
        end
        local file = io.open(path, "r")
        if file ~= nil then
            local text = file:read("*a")
            io.close(file)
            os.remove(path)
            script.request.free = true
            return text
        end
        os.remove(path)
    end
    return ""
end

function download_handler(id, status, p1, p2)
    if stop_downloading then
        stop_downloading = false
        download_id = nil
        return false -- прервать загрузку
    end

    if status == dlstatus.STATUS_ENDDOWNLOADDATA then
        script.request.complete = true
    end
end

function script.updateScript()
    script.update = true
    downloadUrlToFile(script.url, thisScript().path, function(_, status, _, _)
        if status == 6 then
            script.sendMessage(updating_prefix .. "Скрипт был обновлён!")
            if script.find("ML-AutoReboot") == nil then
                thisScript():reload()
            end
        end
    end)
end

function script.sendMessage(t)
    sampAddChatMessage(prefix .. u8:decode(t), main_color)
end

function onScriptTerminate(s, bool)
    if s == thisScript() and not bool then
        imgui.Process = false
        if not script.update then
            if not script.unload then
                script.sendMessage(error_prefix ..
                                       "Скрипт крашнулся: отправьте файл moonloader\\moonloader.log разработчику в tg: " ..
                                       script.telegram.nick)
            else
                script.sendMessage("Скрипт был выгружен")
            end
        else
            script.sendMessage(updating_prefix .. "Перезагружаюсь...")
        end
    end
end
