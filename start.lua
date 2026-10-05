
local composer = require("composer")
local scene = composer.newScene()

local soundManager = require("soundManager")

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
    local sceneGroup = self.view

    -- ФОН
    local bg = display.newRect(sceneGroup, centerX, centerY, W, H)
    bg:setFillColor(0.1, 0.1, 0.2)
    bg:toBack()

    -- ЗАГОЛОВОК
    local title = display.newText({
        parent = sceneGroup,
        text = "RUNNER GAME",
        x = centerX,
        y = top + 70,
        font = native.systemFontBold,
        fontSize = 48
    })
    title:setFillColor(0.9, 0.9, 0.7)


    -- КНОПКА "НАЧАТЬ" 
    local startBtn = display.newRoundedRect(sceneGroup, centerX, centerY - 30, 220, 55, 12)
    startBtn:setFillColor(0.25, 0.35, 0.25)
    startBtn:setStrokeColor(0.5, 0.5, 0.6)
    startBtn.strokeWidth = 2
    
    local startText = display.newText({
        parent = sceneGroup,
        text = "НАЧАТЬ",
        x = centerX,
        y = centerY - 30,
        font = native.systemFontBold,
        fontSize = 24
    })
    startText:setFillColor(0.9, 0.9, 0.8)
    startText:setStrokeColor(0, 0, 0)
    startText.strokeWidth = 1

    -- КНОПКА "ВЫБОР УРОВНЯ"
    local levelSelectBtn = display.newRoundedRect(sceneGroup, centerX, centerY + 35, 220, 55, 12)
    levelSelectBtn:setFillColor(0.35, 0.25, 0.35)
    levelSelectBtn:setStrokeColor(0.5, 0.5, 0.6)
    levelSelectBtn.strokeWidth = 2
    
    local levelSelectText = display.newText({
        parent = sceneGroup,
        text = "ВЫБОР УРОВНЯ",
        x = centerX,
        y = centerY + 35,
        font = native.systemFontBold,
        fontSize = 24
    })
    levelSelectText:setFillColor(0.9, 0.8, 0.9)
    levelSelectText:setStrokeColor(0, 0, 0)
    levelSelectText.strokeWidth = 1

    -- КНОПКА "ВЫХОД"
    local exitBtn = display.newRoundedRect(sceneGroup, centerX, centerY + 100, 180, 45, 10)
    exitBtn:setFillColor(0.35, 0.2, 0.2)
    exitBtn:setStrokeColor(0.5, 0.5, 0.6)
    exitBtn.strokeWidth = 2
    
    local exitText = display.newText({
        parent = sceneGroup,
        text = "ВЫХОД",
        x = centerX,
        y = centerY + 100,
        font = native.systemFontBold,
        fontSize = 20
    })
    exitText:setFillColor(0.9, 0.8, 0.8)
    exitText:setStrokeColor(0, 0, 0)
    exitText.strokeWidth = 1

    -- ОБРАБОТЧИКИ КНОПОК
    startBtn:addEventListener("tap", function()
        soundManager.playSound("jump")
        composer.gotoScene("level1", { effect = "fade", time = 200 })
    end)

    levelSelectBtn:addEventListener("tap", function()
        soundManager.playSound("jump")
        composer.gotoScene("menu", { effect = "fade", time = 200 })
    end)

    exitBtn:addEventListener("tap", function()
        os.exit()
    end)
end

-- запускаем музыку
function scene:show(event)
    if event.phase == "did" then
        soundManager.playBackground()
    end
end

-- HIDE
function scene:hide(event)
    if event.phase == "will" then
        -- ничего не делаем
    end
end

-- DESTROY
function scene:destroy(event)
    -- очистка
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene