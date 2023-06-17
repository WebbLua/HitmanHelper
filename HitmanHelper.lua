script_name('HitmanHelper')
script_author("Webb")
script_version("17.06.2023")
script_version_number(2)

local main_color, main_color_hex = 0xB8B6B6, "{B8B6B6}"
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
    inicfg = require 'inicfg'
    vkeys = require 'vkeys'
    dlstatus = require'moonloader'.download_status
    ffi = require 'ffi'
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
        cooldown = true,
        when = 0,
        min = 15,
        posX = 0,
        posY = 0
    }
}

if hit_ini == nil then -- загружаем конфиг
    hit_ini = inicfg.load(config, HitmanHelper)
    inicfg.save(hit_ini, HitmanHelper)
end

local script = {
    v = {num, date},
    loaded = false,
    unload = false,
    update = false,
    checkedUpdates = false,
    telegram = {
        nick = "@ibm287",
        url = "https://t.me/ibm287"
    },
    request = {
        complete = true,
        free = true
    },
    label = {}
}

local font
local current = {
    nick = nil,
    id = nil
}
local style = imgui.GetStyle()
local colors = style.Colors
local clr = imgui.Col
local ImVec4 = imgui.ImVec4
imgui.main = imgui.ImBool(false)

local msg = {
    new = {
        text = u8:decode "^ Гробовщик%: Твоя цель %- (.*)%, передаю всю известную информацию о нём%.%.%.$",
        color = 1790050303
    },
    ideal = {
        text = u8:decode "^ Задание выполнено безупречно%. Награда%: %d+ вирт$",
        color = 1790050303
    },
    witness = {
        text = u8:decode "^ Задание выполнено при свидетелях%. Награда%: %d+ вирт$",
        color = 1790050303
    },
    fail = {
        text = u8:decode "^ Задание провалено%, опыт киллера понижен %{FFFFFF%}%(%( %/killSkill %)%)$",
        color = -10270721
    },
    lost = {
        text = u8:decode "^ Цель потеряна%, задание отменено без потери опыта$",
        color = -1347440641
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
    server = (server:find('02') and 'Two' or (
        server:find('Revo') and 'Revolution' or (
            server:find('Legacy') and 'Legacy' or (
                server:find('Classic') and 'Classic' or 
                nil
            )
        )
    )
)
    if server == nil then
        script.sendMessage('Данный сервер не поддерживается, выгружаюсь...')
        script.unload = true
        thisScript():unload()
    end

    imgui.ApplyCustomStyle()
    font = imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\arial.ttf', toScreenX(20 / 3), nil,
        imgui.GetIO().Fonts:GetGlyphRangesCyrillic())

    sampRegisterChatCommand("hitman", function()
        imgui.main.v = not imgui.main.v
    end)
    sampRegisterChatCommand("setaim", function(id)
        if id == nil or id == "" then
            current.nick = nil
            current.id = nil
            script.sendMessage("Последняя цель для поиска была сброшена")
            return
        end
        local nick = sampGetPlayerNickname(id)
        if nick == nil then
            script.sendMessage("Цель оффлайн")
            return
        end
        current.nick = nick
        current.id = tonumber(id)
        script.sendMessage("Определена новая цель для поиска: " .. current.nick .. "[" ..
                               current.id .. "]")
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

    local rFont = renderCreateFont("Arial", 10, 4)
    while true do
        wait(0)
        imgui.ShowCursor = false
        if imgui.main.v then
            imgui.LockPlayer = true
        end

        if hit_ini.settings.player then
            if current.id ~= nil then
                local result, handle = sampGetCharHandleBySampPlayerId(current.id)
                if result then
                    if doesCharExist(handle) and isCharOnScreen(handle) then
                        local x, y, z = getBodyPartCoordinates(3, handle)
                        local sx, sy = convert3DCoordsToScreen(x, y, z)
                        local mx, my, mz = getCharCoordinates(PLAYER_PED)
                        local msx, msy = convert3DCoordsToScreen(mx, my, mz)
                        local d = getDistanceBetweenCoords3d(mx, my, mz, x, y, z)
                        local distance = string.format("%.1f", d)
                        local clist = sampGetPlayerColor(id)
                        local a, r, g, b = explode_argb(clist)
                        local color = join_argb(230.0, r, g, b)
                        local camMode = readMemory(0xB6F1A8, 1, false)
                        local collision = processLineOfSight(mx, my, mz, x, y, z, true, false, false, false, true, true,
                            true, true)
                        if (camMode == 53 or camMode == 55 or camMode == 7 or camMode == 8) and not collision and
                            not isKeyDown(vkeys.VK_LSHIFT) then
                            targetAtCoords(x, y, (isCharInAnyCar(handle) and z + 0.3 or z))
                        end
                        local dcolor = getCurrentCharWeapon(PLAYER_PED) == 34 and
                                           (d <= 100 and "{0af775}" or "{8b0000}TOO FAR ") or ""
                        renderFontDrawText(rFont,
                            current.nick .. "[" .. current.id .. "] " .. dcolor .. "distance: " .. distance ..
                                (collision and " {8b0000}COLLISION" or ""), sx, sy, color)
                        renderDrawLine(msx, msy, sx, sy, 1.5, color)
                        local t = {3, 4, 5, 51, 52, 41, 42, 31, 32, 33, 21, 22, 23, 2}
                        for v = 1, #t do
                            pos1X, pos1Y, pos1Z = getBodyPartCoordinates(t[v], handle)
                            pos2X, pos2Y, pos2Z = getBodyPartCoordinates(t[v] + 1, handle)
                            pos1, pos2 = convert3DCoordsToScreen(pos1X, pos1Y, pos1Z)
                            pos3, pos4 = convert3DCoordsToScreen(pos2X, pos2Y, pos2Z)
                            renderDrawLine(pos1, pos2, pos3, pos4, 1, color)
                        end
                        for v = 4, 5 do
                            pos2X, pos2Y, pos2Z = getBodyPartCoordinates(v * 10 + 1, handle)
                            pos3, pos4 = convert3DCoordsToScreen(pos2X, pos2Y, pos2Z)
                            renderDrawLine(pos1, pos2, pos3, pos4, 1, color)
                        end
                        local t = {53, 43, 24, 34, 6}
                        for v = 1, #t do
                            posX, posY, posZ = getBodyPartCoordinates(t[v], handle)
                            pos1, pos2 = convert3DCoordsToScreen(posX, posY, posZ)
                        end
                    end
                end
            end
        end

        textLabelOverPlayerNickname()
        
    end
end

function sampGetPlayerIdByNickname(nick)
    local _, myid = sampGetPlayerIdByCharHandle(playerPed)
    if tostring(nick) == sampGetPlayerNickname(myid) then
        return myid
    end
    for i = 0, 1000 do
        if sampIsPlayerConnected(i) and sampGetPlayerNickname(i) == tostring(nick) then
            return i
        end
    end
end

function explode_argb(argb)
    local a = bit.band(bit.rshift(argb, 24), 0xFF)
    local r = bit.band(bit.rshift(argb, 16), 0xFF)
    local g = bit.band(bit.rshift(argb, 8), 0xFF)
    local b = bit.band(argb, 0xFF)
    return a, r, g, b
end

function join_argb(a, r, g, b)
    local argb = b -- b
    argb = bit.bor(argb, bit.lshift(g, 8)) -- g
    argb = bit.bor(argb, bit.lshift(r, 16)) -- r
    argb = bit.bor(argb, bit.lshift(a, 24)) -- a
    return argb
end

local getBonePosition = ffi.cast("int (__thiscall*)(void*, float*, int, bool)", 0x5E4280)
function getBodyPartCoordinates(id, handle)
    local pedptr = getCharPointer(handle)
    local vec = ffi.new("float[3]")
    getBonePosition(ffi.cast("void*", pedptr), vec, id, true)
    return vec[0], vec[1], vec[2]
end

function targetAtCoords(x, y, z)
    local cx, cy, cz = getActiveCameraCoordinates()

    local vect = {
        fX = cx - x,
        fY = cy - y,
        fZ = cz - z
    }

    local screenAspectRatio = representIntAsFloat(readMemory(0xC3EFA4, 4, false))
    local crosshairOffset = {representIntAsFloat(readMemory(0xB6EC10, 4, false)),
                             representIntAsFloat(readMemory(0xB6EC14, 4, false))}

    -- weird shit
    local mult = math.tan(getCameraFov() * 0.5 * 0.017453292)
    fz = 3.14159265 - math.atan2(1.0, mult * ((0.5 - crosshairOffset[1]) * (2 / screenAspectRatio)))
    fx = 3.14159265 - math.atan2(1.0, mult * 2 * (crosshairOffset[2] - 0.5))

    local camMode = readMemory(0xB6F1A8, 1, false)

    if not (camMode == 53 or camMode == 55) then -- sniper rifle etc.
        fx = 3.14159265 / 2
        fz = 3.14159265 / 2
    end

    local ax = math.atan2(vect.fY, -vect.fX) - 3.14159265 / 2
    local az = math.atan2(math.sqrt(vect.fX * vect.fX + vect.fY * vect.fY), vect.fZ)

    setCameraPositionUnfixed(az - fz, fx - ax)
end

function imgui.ApplyCustomStyle()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    local ImVec2 = imgui.ImVec2

    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.FramePadding = ImVec2(4.0, 2.0)
    style.ItemSpacing = ImVec2(8.0, 2.0)
    style.WindowRounding = 1.0
    style.FrameRounding = 1.0
    style.ScrollbarRounding = 1.0
    style.GrabRounding = 1.0

    colors[clr.Text] = ImVec4(1.00, 1.00, 1.00, 0.95)
    colors[clr.TextDisabled] = ImVec4(0.50, 0.50, 0.50, 1.00)
    colors[clr.WindowBg] = ImVec4(0.13, 0.12, 0.12, 1.00)
    colors[clr.ChildWindowBg] = ImVec4(0.13, 0.12, 0.12, 1.00)
    colors[clr.PopupBg] = ImVec4(0.05, 0.05, 0.05, 0.94)
    colors[clr.Border] = ImVec4(0.53, 0.53, 0.53, 0.46)
    colors[clr.BorderShadow] = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[clr.FrameBg] = ImVec4(0.00, 0.00, 0.00, 0.85)
    colors[clr.FrameBgHovered] = ImVec4(0.22, 0.22, 0.22, 0.40)
    colors[clr.FrameBgActive] = ImVec4(0.16, 0.16, 0.16, 0.53)
    colors[clr.TitleBg] = ImVec4(0.00, 0.00, 0.00, 1.00)
    colors[clr.TitleBgActive] = ImVec4(0.00, 0.00, 0.00, 1.00)
    colors[clr.TitleBgCollapsed] = ImVec4(0.00, 0.00, 0.00, 0.51)
    colors[clr.MenuBarBg] = ImVec4(0.12, 0.12, 0.12, 1.00)
    colors[clr.ScrollbarBg] = ImVec4(0.02, 0.02, 0.02, 0.53)
    colors[clr.ScrollbarGrab] = ImVec4(0.31, 0.31, 0.31, 1.00)
    colors[clr.ScrollbarGrabHovered] = ImVec4(0.41, 0.41, 0.41, 1.00)
    colors[clr.ScrollbarGrabActive] = ImVec4(0.48, 0.48, 0.48, 1.00)
    colors[clr.ComboBg] = ImVec4(0.24, 0.24, 0.24, 0.99)
    colors[clr.CheckMark] = ImVec4(0.79, 0.79, 0.79, 1.00)
    colors[clr.SliderGrab] = ImVec4(0.48, 0.47, 0.47, 0.91)
    colors[clr.SliderGrabActive] = ImVec4(0.56, 0.55, 0.55, 0.62)
    colors[clr.Button] = ImVec4(0.50, 0.50, 0.50, 0.63)
    colors[clr.ButtonHovered] = ImVec4(0.67, 0.67, 0.68, 0.63)
    colors[clr.ButtonActive] = ImVec4(0.26, 0.26, 0.26, 0.63)
    colors[clr.Header] = ImVec4(0.54, 0.54, 0.54, 0.58)
    colors[clr.HeaderHovered] = ImVec4(0.64, 0.65, 0.65, 0.80)
    colors[clr.HeaderActive] = ImVec4(0.25, 0.25, 0.25, 0.80)
    colors[clr.Separator] = ImVec4(0.58, 0.58, 0.58, 0.50)
    colors[clr.SeparatorHovered] = ImVec4(0.81, 0.81, 0.81, 0.64)
    colors[clr.SeparatorActive] = ImVec4(0.81, 0.81, 0.81, 0.64)
    colors[clr.ResizeGrip] = ImVec4(0.87, 0.87, 0.87, 0.53)
    colors[clr.ResizeGripHovered] = ImVec4(0.87, 0.87, 0.87, 0.74)
    colors[clr.ResizeGripActive] = ImVec4(0.87, 0.87, 0.87, 0.74)
    colors[clr.CloseButton] = ImVec4(0.45, 0.45, 0.45, 0.50)
    colors[clr.CloseButtonHovered] = ImVec4(0.70, 0.70, 0.90, 0.60)
    colors[clr.CloseButtonActive] = ImVec4(0.70, 0.70, 0.70, 1.00)
    colors[clr.PlotLines] = ImVec4(0.68, 0.68, 0.68, 1.00)
    colors[clr.PlotLinesHovered] = ImVec4(0.68, 0.68, 0.68, 1.00)
    colors[clr.PlotHistogram] = ImVec4(0.90, 0.77, 0.33, 1.00)
    colors[clr.PlotHistogramHovered] = ImVec4(0.87, 0.55, 0.08, 1.00)
    colors[clr.TextSelectedBg] = ImVec4(0.47, 0.60, 0.76, 0.47)
    colors[clr.ModalWindowDarkening] = ImVec4(0.88, 0.88, 0.88, 0.35)
end

function imgui.OnDrawFrame()
    if imgui.main.v and script.checkedUpdates then -- меню скрипта
        imgui.SwitchContext()
        colors[clr.WindowBg] = ImVec4(0.06, 0.06, 0.06, 0.94)
        imgui.PushFont(font)
        imgui.ShowCursor = true
        local sw, sh = getScreenResolution()
        imgui.SetNextWindowSize(vec(200, 53), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, vec(0.5 / 3, 0.25))
        imgui.Begin(thisScript().name .. ' v' .. script.v.num .. ' от ' .. script.v.date, imgui.main,
            imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar)
        imgui.BeginChild("main", vec(195, 38), true)
        if imgui.Checkbox("Aim по скину на жертву вашего текущего задания",
            imgui.ImBool(hit_ini.settings.aim)) then
            hit_ini.settings.aim = not hit_ini.settings.aim
            inicfg.save(hit_ini, HitmanHelper)
        end
        if imgui.IsItemHovered() then
            imgui.BeginTooltip()
            imgui.TextUnformatted(
                "При наводке на вашу жертву, перекрестье оптического прицела Sniper Rifle будет на её скине\nЧто-бы сдвинуть прицел - зажмите кнопку SHIFT")
            imgui.EndTooltip()
        end
        if imgui.Checkbox(
            "Рендер ника и скелета жертвы на экране (аналог WallHack)",
            imgui.ImBool(hit_ini.settings.player)) then
            hit_ini.settings.player = not hit_ini.settings.player
            inicfg.save(hit_ini, HitmanHelper)
        end
        if imgui.IsItemHovered() then
            imgui.BeginTooltip()
            imgui.TextUnformatted(
                "На экране будет отображён ник и скелет жертвы в случае если она в зоне вашей прорисовки\nТакже цель можно выбрать вручную с помощью команды /setaim [id]")
            imgui.EndTooltip()
        end
        if imgui.Checkbox("Отображать на экране CoolDown до следующего задания",
            imgui.ImBool(hit_ini.settings.cooldown)) then
            hit_ini.settings.cooldown = not hit_ini.settings.cooldown
            inicfg.save(hit_ini, HitmanHelper)
        end
        if imgui.IsItemHovered() then
            imgui.BeginTooltip()
            imgui.TextUnformatted(
                "В формате MM:SS будет отображаться CoolDown до следующего задания")
            imgui.EndTooltip()
        end
        imgui.EndChild()
        imgui.End()
        imgui.PopFont()
    end

    imgui.SwitchContext()
    colors[clr.WindowBg] = ImVec4(0, 0, 0, 0)

    if hit_ini.settings.cooldown then -- показывать КД до след задания
        imgui.SetNextWindowPos(vec(hit_ini.settings.posX, hit_ini.settings.posY), imgui.Cond.FirstUseEver)
        imgui.Begin('cooldown', _,
            imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize +
                imgui.WindowFlags.AlwaysAutoResize)
        imgui.PushFont(fonts)
        if (os.time() - hit_ini.settings.when) < (hit_ini.settings.min * 60) then
            sec = (hit_ini.settings.min * 60) - (os.time() - hit_ini.settings.when)
            local mins = math.floor(sec / 60)
            if math.fmod(sec, 60) >= 10 then
                secs = math.fmod(sec, 60)
            end
            if math.fmod(sec, 60) < 10 then
                secs = "0" .. math.fmod(sec, 60) .. ""
            end
            imgui.TextColoredRGB("{FF0000}До следующего заказа: " .. mins .. ":" .. secs .. "")
        else
            imgui.TextColoredRGB("{00FF00}Можно убивать!")
        end
        imgui.PopFont()
        local newPos = imgui.GetWindowPos()
        local savePosX, savePosY = convertWindowScreenCoordsToGameScreenCoords(newPos.x, newPos.y)
        if (math.ceil(savePosX) ~= math.ceil(hit_ini.settings.posX) or math.ceil(savePosY) ~=
            math.ceil(hit_ini.settings.posY)) and imgui.IsRootWindowOrAnyChildFocused() and imgui.IsMouseDragging(0) and
            imgui.IsRootWindowOrAnyChildHovered() then
            hit_ini.settings.posX = math.ceil(savePosX)
            hit_ini.settings.posY = math.ceil(savePosY)
            inicfg.save(hit_ini, settings)
        end
        imgui.End()
    end
end

function imgui.TextColoredRGB(text)
    local style = imgui.GetStyle()
    local colors = style.Colors
    local ImVec4 = imgui.ImVec4

    local explode_argb = function(argb)
        local a = bit.band(bit.rshift(argb, 24), 0xFF)
        local r = bit.band(bit.rshift(argb, 16), 0xFF)
        local g = bit.band(bit.rshift(argb, 8), 0xFF)
        local b = bit.band(argb, 0xFF)
        return a, r, g, b
    end

    local getcolor = function(color)
        if color:sub(1, 6):upper() == 'SSSSSS' then
            local r, g, b = colors[1].x, colors[1].y, colors[1].z
            local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
            return ImVec4(r, g, b, a / 255)
        end

        local color = type(color) == 'string' and tonumber(color, 16) or color
        if type(color) ~= 'number' then
            return
        end
        local r, g, b, a = explode_argb(color)
        return imgui.ImColor(r, g, b, a):GetVec4()
    end

    local render_text = function(text_)
        for w in text_:gmatch('[^\r\n]+') do
            local text, colors_, m = {}, {}, 1
            w = w:gsub('{(......)}', '{%1FF}')
            while w:find('{........}') do
                local n, k = w:find('{........}')
                local color = getcolor(w:sub(n + 1, k - 1))
                if color then
                    text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
                    colors_[#colors_ + 1] = color
                    m = n
                end

                w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
            end

            if text[0] then
                for i = 0, #text do
                    imgui.TextColored(colors_[i] or colors[1], text[i])
                    if imgui.IsItemClicked() then
                        if SelectedRow == A_Index then
                            ChoosenRow = SelectedRow
                        else
                            SelectedRow = A_Index
                        end
                    end
                    imgui.SameLine(nil, 0)
                end

                imgui.NewLine()
            else
                imgui.Text(w)
                if imgui.IsItemClicked() then
                    if SelectedRow == A_Index then
                        ChoosenRow = SelectedRow
                    else
                        SelectedRow = A_Index
                    end
                end
            end
        end
    end
    render_text(text)
end

function toScreenY(gY)
    local x, y = convertGameScreenCoordsToWindowScreenCoords(0, gY)
    return y
end

function toScreenX(gX)
    local x, y = convertGameScreenCoordsToWindowScreenCoords(gX, 0)
    return x
end

function toScreen(gX, gY)
    local s = {}
    s.x, s.y = convertGameScreenCoordsToWindowScreenCoords(gX, gY)
    return s
end

function vec(gX, gY)
    local x, y = convertGameScreenCoordsToWindowScreenCoords(gX, gY)
    return imgui.ImVec2(x, y)
end

function ev.onServerMessage(color, text)
    if color == msg.new.color then -- новое задание
        local nick = text:match(msg.new.text)
        if nick ~= nil then
            local id = sampGetPlayerIdByNickname(nick)
            if id ~= nil then
                current.nick = nick
                current.id = tonumber(id)
                script.sendMessage("Определена новая цель для поиска: " .. current.nick ..
                                       "[" .. current.id .. "]")
            end
        end
    end
    if color == msg.ideal.color and text:match(msg.ideal.text) then -- безупречное выполнение
        current.nick = nil
        current.id = nil
        script.sendMessage("Последняя цель для поиска была сброшена")
        hit_ini.settings.min = 15
        hit_ini.settings.when = os.time()
        inicfg.save(hit_ini, settings)
    end
    if color == msg.witness.color and text:match(msg.witness.text) then -- при свидетелях
        current.nick = nil
        current.id = nil
        script.sendMessage("Последняя цель для поиска была сброшена")
        hit_ini.settings.min = 20
        hit_ini.settings.when = os.time()
        inicfg.save(hit_ini, settings)
    end
    if color == msg.fail.color and text:match(msg.fail.text) then -- провал
        current.nick = nil
        current.id = nil
        script.sendMessage("Последняя цель для поиска была сброшена")
        hit_ini.settings.min = 5
        hit_ini.settings.when = os.time()
        inicfg.save(hit_ini, settings)
    end
    if color == msg.lost.color and text:match(msg.lost.text) then -- цель потеряна
        current.nick = nil
        current.id = nil
        script.sendMessage("Последняя цель для поиска была сброшена")
        hit_ini.settings.when = 0
        inicfg.save(hit_ini, settings)
    end
end

textlabel = {}
function textLabelOverPlayerNickname()
    for i = 0, 1000 do
        if textlabel[i] ~= nil then
            sampDestroy3dText(textlabel[i])
            textlabel[i] = nil
        end
    end
    for i = 0, 1000 do
        if sampIsPlayerConnected(i) and sampGetPlayerScore(i) ~= 0 then
            local nick = sampGetPlayerNickname(i)
            if script.label[server][nick] ~= nil then
                if textlabel[i] == nil then
                    textlabel[i] = sampCreate3dText(u8:decode(script.label[server][nick].text),
                        tonumber(script.label[server][nick].color), 0.0, 0.0, 0.8, 15.0, false, i, -1)
                end
            end
        else
            if textlabel[i] ~= nil then
                sampDestroy3dText(textlabel[i])
                textlabel[i] = nil
            end
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
        script.v.num = data.version
        script.v.date = data.date
        script.url = data.url
        script.label = decodeJson(request(data.label))
        if data.telegram then
            script.telegram = data.telegram
        end
        if script.v.num > thisScript()['version_num'] then
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