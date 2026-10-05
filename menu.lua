local composer = require("composer")
local scene = composer.newScene()

local json = require("json")
local soundManager = require("soundManager")

local buttonsData = {}
local sceneGroup = nil

-- ГРАНИЦЫ ЭКРАНА
local left = display.safeScreenOriginX
local top = display.safeScreenOriginY
local right = left + display.actualContentWidth
local bottom = top + display.actualContentHeight

local centerX = display.contentCenterX
local centerY = display.contentCenterY
local W = display.actualContentWidth
local H = display.actualContentHeight

-- CREATE
function scene:create(event)
    sceneGroup = self.view

    local bg = display.newRect(sceneGroup, centerX, centerY, W, H)
    bg:setFillColor(0.1, 0.1, 0.2)
    bg:toBack()

    local title = display.newText({
        parent = sceneGroup,
        text = "ВЫБОР УРОВНЯ",
        x = centerX,
        y = top + 50,
        font = native.systemFontBold,
        fontSize = 28
    })
    title:setFillColor(0.9, 0.9, 0.7)


    local buttonWidth = 160
    local buttonHeight = 45
    local spacing = 12

    local totalHeight = (buttonHeight * 4) + (spacing * 3)
    local startY = centerY - totalHeight / 2 + 40

    for i = 1, 4 do
        local y = startY + (i - 1) * (buttonHeight + spacing)

        local button = display.newRoundedRect(sceneGroup, centerX, y, buttonWidth, buttonHeight, 10)
        button:setStrokeColor(0.5, 0.5, 0.6)
        button.strokeWidth = 2
        button:setFillColor(0.25, 0.35, 0.25)  

        local label = display.newText({
            parent = sceneGroup,
            text = "УРОВЕНЬ " .. i,
            x = centerX,
            y = y,
            font = native.systemFontBold,
            fontSize = 18
        })
        label:setFillColor(0.9, 0.9, 0.8)
        label:setStrokeColor(0, 0, 0)
        label.strokeWidth = 1
        
        local listener = function() 
            soundManager.playSound("jump")
            composer.gotoScene("level" .. i, { effect = "fade", time = 200 })
        end
        button:addEventListener("tap", listener)
        
        buttonsData[i] = {
            button = button,
            label = label,
            hasListener = true,
            listener = listener
        }
    end

    -- КНОПКА "НАЗАД"
    local backBtn = display.newRoundedRect(sceneGroup, left + 50, top + 30, 80, 35, 8)
    backBtn:setFillColor(0.35, 0.25, 0.35)
    backBtn:setStrokeColor(0.5, 0.5, 0.6)
    backBtn.strokeWidth = 2
    
    local backText = display.newText({
        parent = sceneGroup,
        text = "← НАЗАД",
        x = left + 50,
        y = top + 30,
        font = native.systemFontBold,
        fontSize = 16
    })
    backText:setFillColor(0.9, 0.8, 0.9)
    backText:setStrokeColor(0, 0, 0)
    backText.strokeWidth = 1
    
    backBtn:addEventListener("tap", function()
        soundManager.playSound("jump")
        composer.gotoScene("start", { effect = "fade", time = 200 })
    end)
end

-- очистка
function scene:destroy(event)
    buttonsData = {}
    sceneGroup = nil
end

scene:addEventListener("create", scene)
scene:addEventListener("destroy", scene)

return scene