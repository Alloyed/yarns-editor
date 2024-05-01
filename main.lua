local rtmidi = require 'luartmidi'
local imgui = require "imgui"
local controlInfo = require 'controls'

--local info = controlInfo.yarns -- TODO: loom
local info = controlInfo.loom -- TODO: loom

local clearColor = { 0.2, 0.2, 0.2 }

local out = rtmidi.RtMidiOut()

local rc = {state={}, channelNumbers={rc=16, [1]=1, [2]=2, [3]=3, [4]=4}, layout=info.layouts[1], dirty={}}

local function findById(controls, id)
    for cc, control in pairs(controls) do
        if control.id == id then
            return cc, control
        end
    end
end

function rc:send(tag, id, value)
    print("sending", tag, id, value)
    local channel, cc
    if tag == 'rc' then
        channel = self.channelNumbers.rc
        cc = findById(info.rc, id)
    else
        cc = findById(info.partcc, id)
        if cc then
            channel = self.channelNumbers[tag]
        else -- rc only
            channel = self.channelNumbers.rc
            cc = findById(info.partrc, id) + info.partOffsets[tag] - 1
        end
    end
    print("cc", channel, cc, value)
    --out:channel(channel - 1):controlchange(cc, value)
end

function rc:get(tag, id)
    if not self.state[tag] then
        self.state[tag] = {}
    end
    if not self.state[tag][id] then
        self.state[tag][id] = 0
    end
    return self.state[tag][id]
end

function rc:set(tag, id, value)
    self.state[tag][id] = value
    self.dirty[tag.."|"..id] = {tag, id}
    self:applyChanges()
end

function rc:markAllDirty()
    -- TODO
    for tag, tagState in pairs(self.state) do
        for id, _ in pairs(tagState) do
            self.dirty[tag.."|"..id] = {tag, id}
        end
    end
end

function rc:applyChanges()
    -- TODO: queue to avoid spamminess
    for _, change in pairs(self.dirty) do
        local tag, id = unpack(change)
        self:send(tag, id, self:get(tag, id))
    end
    self.dirty = {}
end

local gui = {
}

function gui:draw()
    imgui.SetNextWindowPos(50, 50, "ImGuiCond_FirstUseEver")
    imgui.Begin("Another Window", true, {});
    do
        if imgui.BeginCombo("device", self.portName or "<select device>") then
            for i=1, out:getportcount() do
                local name = out:getportname()
                if imgui.Selectable(name) then
                    self.portName = name
                    out:openport(i)
                end
            end
            imgui.EndCombo()
        end

        if out:isportopen() then
            rc.channelNumbers.rc, changed = imgui.InputInt("RC Channel", rc.channelNumbers.rc)
            if changed then
                rc:markAllDirty()
                rc:applyChanges()
            end

            if imgui.Button("Full Sync") then
                rc:markAllDirty()
                rc:applyChanges()
            end

            if imgui.BeginTabBar("Tabs") then
                if imgui.BeginTabItem("Global") then
                    if imgui.BeginCombo("Layout", rc.layout.abbreviation) then
                        for _, layout in ipairs(info.layouts) do
                            if imgui.Selectable(layout.abbreviation) then
                                rc.layout = layout
                                rc:markAllDirty()
                                rc:applyChanges()
                            end
                        end
                        imgui.EndCombo()
                    end
                    for cc = 0, 127 do
                        local control = info.rc[cc]
                        if control and not control.custom then
                            local value, changed = imgui.SliderInt(control.id, rc:get('rc', control.id), 0, 127)
                            if changed then
                                rc:set('rc', control.id, value)
                            end
                        end
                    end
                    imgui.EndTabItem()
                end
                for partIndex=1, rc.layout.parts do
                    if imgui.BeginTabItem("Part "..partIndex) then
                        for cc = 0, 127 do
                            local control = info.partcc[cc]
                            if control and not control.custom then
                                local value, changed = imgui.SliderInt(control.id, rc:get(partIndex, control.id), 0, 127)
                                if changed then
                                    rc:set(partIndex, control.id, value)
                                end
                            end
                        end
                        imgui.EndTabItem()
                    end
                end
                imgui.EndTabBar()
            end
        end
    end
    imgui.End();
end

--
-- LOVE callbacks
--
function love.load(arg)
end

function love.update(dt)
    imgui.NewFrame()
end

function love.draw()
    gui:draw()

    love.graphics.clear(clearColor[1], clearColor[2], clearColor[3])
    imgui.Render();
end

function love.quit()
    imgui.ShutDown();
end

--
-- User inputs
--
function love.textinput(t)
    imgui.TextInput(t)
    if not imgui.GetWantCaptureKeyboard() then
        -- Pass event to the game
    end
end

function love.keypressed(key)
    imgui.KeyPressed(key)
    if not imgui.GetWantCaptureKeyboard() then
        -- Pass event to the game
    end
end

function love.keyreleased(key)
    imgui.KeyReleased(key)
    if not imgui.GetWantCaptureKeyboard() then
        -- Pass event to the game
    end
end

function love.mousemoved(x, y)
    imgui.MouseMoved(x, y)
    if not imgui.GetWantCaptureMouse() then
        -- Pass event to the game
    end
end

function love.mousepressed(x, y, button)
    imgui.MousePressed(button)
    if not imgui.GetWantCaptureMouse() then
        -- Pass event to the game
    end
end

function love.mousereleased(x, y, button)
    imgui.MouseReleased(button)
    if not imgui.GetWantCaptureMouse() then
        -- Pass event to the game
    end
end

function love.wheelmoved(x, y)
    imgui.WheelMoved(y)
    if not imgui.GetWantCaptureMouse() then
        -- Pass event to the game
    end
end
