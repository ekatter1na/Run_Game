local composer = require("composer")
local scene = composer.newScene()
local physics = require("physics")

local json = require("json")
local soundManager = require("soundManager")

local player
local ground, ceiling
local obstacles = {}
local fallingSpikes = {}
local finish
local goodStars = {}
local badStars = {}
local score = 0
local scoreText = nil

local isDead = false
local isDucking = false
local isStopped = false
local transitioning = false
local levelCompleted = false
local winScreenGroup = nil
local gameLoop = nil
local collisionHandler = nil
local deathTimer = nil

-- ОГРАНИЧЕНИЕ ПРЫЖКОВ
local jumpsLeft = 2

-- АНИМАЦИОННЫЕ ПЕРЕМЕННЫЕ
local runFrames = {}
local jumpFrames = {}
local crouchFrames = {}
local idleFrames = {}
local currentAnimation = nil
local animationTimer = nil
local currentFrameIndex = 1

local lastSpikeFallTime = 0

local left = display.screenOriginX
local top = display.screenOriginY
local right = left + display.viewableContentWidth
local bottom = top + display.viewableContentHeight

local W = display.viewableContentWidth
local H = display.viewableContentHeight
local CX = display.contentCenterX
local CY = display.contentCenterY

local SPEED = 6

-- Прогресс
local progress = { unlockedLevel = 3 }

local function loadProgress()
    local path = system.pathForFile("save.json", system.DocumentsDirectory)
    local file = io.open(path, "r")
    if file then
        local contents = file:read("*a")
        local data = json.decode(contents)
        if data then progress = data end
        file:close()
    end
end

local function saveProgress()
    local path = system.pathForFile("save.json", system.DocumentsDirectory)
    local file = io.open(path, "w")
    if file then
        file:write(json.encode(progress))
        file:close()
    end
end

local function fileExists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- ЗАГРУЗКА И ОТОБРАЖЕНИЕ КАДРОВ АНИМАЦИИ
local function hideAllFrames()
    for i = 1, #runFrames do
        if runFrames[i] then runFrames[i].isVisible = false end
    end
    for i = 1, #jumpFrames do
        if jumpFrames[i] then jumpFrames[i].isVisible = false end
    end
    for i = 1, #crouchFrames do
        if crouchFrames[i] then crouchFrames[i].isVisible = false end
    end
    for i = 1, #idleFrames do
        if idleFrames[i] then idleFrames[i].isVisible = false end
    end
end

local function showCurrentFrame()
    hideAllFrames()
    
    if currentAnimation == "run" then
        if runFrames[currentFrameIndex] then
            runFrames[currentFrameIndex].isVisible = true
            runFrames[currentFrameIndex].x = player.x
            runFrames[currentFrameIndex].y = player.y
        end
    elseif currentAnimation == "jump" then
        if jumpFrames[currentFrameIndex] then
            jumpFrames[currentFrameIndex].isVisible = true
            jumpFrames[currentFrameIndex].x = player.x
            jumpFrames[currentFrameIndex].y = player.y
        end
    elseif currentAnimation == "crouch" then
        if crouchFrames[currentFrameIndex] then
            crouchFrames[currentFrameIndex].isVisible = true
            crouchFrames[currentFrameIndex].x = player.x
            crouchFrames[currentFrameIndex].y = player.y
        end
    elseif currentAnimation == "idle" then
        if idleFrames[currentFrameIndex] then
            idleFrames[currentFrameIndex].isVisible = true
            idleFrames[currentFrameIndex].x = player.x
            idleFrames[currentFrameIndex].y = player.y
        end
    end
end

local function updateAnimation()
    if isDead or levelCompleted then return end
    
    currentFrameIndex = currentFrameIndex + 1
    
    if currentAnimation == "run" then
        if currentFrameIndex > #runFrames then
            currentFrameIndex = 1
        end
    elseif currentAnimation == "jump" then
        if currentFrameIndex > #jumpFrames then
            currentFrameIndex = #jumpFrames
        end
    elseif currentAnimation == "crouch" then
        if currentFrameIndex > #crouchFrames then
            currentFrameIndex = 1
        end
    elseif currentAnimation == "idle" then
        if currentFrameIndex > #idleFrames then
            currentFrameIndex = 1
        end
    end
    
    showCurrentFrame()
end

local function startRunAnimation()
    if animationTimer then
        timer.cancel(animationTimer)
        animationTimer = nil
    end
    
    currentAnimation = "run"
    currentFrameIndex = 1
    hideAllFrames()
    showCurrentFrame()
    
    animationTimer = timer.performWithDelay(70, updateAnimation, 0)
end

local function startJumpAnimation()
    if animationTimer then
        timer.cancel(animationTimer)
        animationTimer = nil
    end
    
    currentAnimation = "jump"
    currentFrameIndex = 1
    hideAllFrames()
    showCurrentFrame()
    
    animationTimer = timer.performWithDelay(110, updateAnimation, 0)
    
    timer.performWithDelay(500, function()
        if not isDead and not levelCompleted and currentAnimation == "jump" then
            startRunAnimation()
        end
    end)
end

local function startCrouchAnimation()
    if animationTimer then
        timer.cancel(animationTimer)
        animationTimer = nil
    end
    
    currentAnimation = "crouch"
    currentFrameIndex = 1
    hideAllFrames()
    showCurrentFrame()
    
    animationTimer = timer.performWithDelay(70, updateAnimation, 0)
end

local function startIdleAnimation()
    if animationTimer then
        timer.cancel(animationTimer)
        animationTimer = nil
    end
    
    currentAnimation = "idle"
    currentFrameIndex = 1
    hideAllFrames()
    showCurrentFrame()
    
    animationTimer = timer.performWithDelay(100, updateAnimation, 0)
end

local function loadAnimations()
    local frameWidth = 60
    local frameHeight = 60
    
    for i = 0, 9 do
        local path
        if i < 10 then
            path = "images/pers/Run__00" .. i .. ".png"
        else
            path = "images/pers/Run__0" .. i .. ".png"
        end
        local frame = display.newImageRect(path, frameWidth, frameHeight)
        frame.isVisible = false
        table.insert(runFrames, frame)
        scene.view:insert(frame)
    end
    
    for i = 0, 9 do
        local path
        if i < 10 then
            path = "images/pers/Jump__00" .. i .. ".png"
        else
            path = "images/pers/Jump__0" .. i .. ".png"
        end
        local frame = display.newImageRect(path, frameWidth, frameHeight)
        frame.isVisible = false
        table.insert(jumpFrames, frame)
        scene.view:insert(frame)
    end
    
    for i = 0, 9 do
        local path
        if i < 10 then
            path = "images/pers/Slide__00" .. i .. ".png"
        else
            path = "images/pers/Slide__0" .. i .. ".png"
        end
        local frame = display.newImageRect(path, frameWidth, frameHeight)
        frame.isVisible = false
        table.insert(crouchFrames, frame)
        scene.view:insert(frame)
    end
    
    for i = 0, 9 do
        local path
        if i < 10 then
            path = "images/pers/Idle__00" .. i .. ".png"
        else
            path = "images/pers/Idle__0" .. i .. ".png"
        end
        local frame = display.newImageRect(path, 40, 60)
        frame.isVisible = false
        frame.anchorX = 0.5
        frame.anchorY = 0.5
        frame.xScale = 1.0
        frame.yScale = 1.0
        table.insert(idleFrames, frame)
        scene.view:insert(frame)
    end
    
    print("Загружено кадров: бег - " .. #runFrames .. ", прыжок - " .. #jumpFrames .. ", присед - " .. #crouchFrames .. ", стоп - " .. #idleFrames)
    return #runFrames > 0
end

-- СОЗДАНИЕ ЗВЁЗД
local function createGoodStar(x, y)
    local star = display.newImageRect(scene.view, "images/coin.png", 16, 16)
    star.x = x
    star.y = y
    physics.addBody(star, "kinematic")
    star.isSensor = true
    star.myName = "goodStar"
    table.insert(goodStars, star)
end

local function createBadStar(x, y)
    local star = display.newImageRect(scene.view, "images/anticoin.png", 16, 16)
    star.x = x
    star.y = y
    physics.addBody(star, "kinematic")
    star.isSensor = true
    star.myName = "badStar"
    table.insert(badStars, star)
end

-- ЭКРАН ПОБЕДЫ
local function showWinScreen()
    if levelCompleted then return end
    levelCompleted = true
    isDead = true
    transitioning = true
    
    if deathTimer then
        timer.cancel(deathTimer)
        deathTimer = nil
    end
    
    if animationTimer then
        timer.cancel(animationTimer)
        animationTimer = nil
    end
    
    soundManager.playSound("level_complete")
    
    local sceneGroup = scene.view
    
    winScreenGroup = display.newGroup()
    sceneGroup:insert(winScreenGroup)
    
    local overlay = display.newRect(winScreenGroup, CX, CY, W, H)
    overlay:setFillColor(0, 0, 0, 0.7)
    
    local winBox = display.newRoundedRect(winScreenGroup, CX, CY, 300, 280, 15)
    winBox:setFillColor(0.12, 0.12, 0.2)
    winBox.strokeWidth = 2
    winBox:setStrokeColor(0.5, 0.5, 0.6)
    
    local winText = display.newText(winScreenGroup, "УРОВЕНЬ ПРОЙДЕН!", CX, CY - 85, native.systemFontBold, 22)
    winText:setFillColor(0.7, 0.9, 0.5)
    
    local finalScoreText = display.newText(winScreenGroup, "ОЧКИ: " .. score, CX, CY - 40, native.systemFontBold, 18)
    finalScoreText:setFillColor(1, 1, 0.5)
    
    local menuBtn = display.newRoundedRect(winScreenGroup, CX, CY + 15, 160, 35, 8)
    menuBtn:setFillColor(0.35, 0.2, 0.2)
    menuBtn:setStrokeColor(0.5, 0.5, 0.6)
    menuBtn.strokeWidth = 1
    local menuLabel = display.newText(winScreenGroup, "МЕНЮ", CX, CY + 15, native.systemFont, 18)
    menuLabel:setFillColor(0.9, 0.8, 0.8)
    
    local restartBtn = display.newRoundedRect(winScreenGroup, CX, CY + 60, 160, 35, 8)
    restartBtn:setFillColor(0.25, 0.35, 0.25)
    restartBtn:setStrokeColor(0.5, 0.5, 0.6)
    restartBtn.strokeWidth = 1
    local restartLabel = display.newText(winScreenGroup, "РЕСТАРТ", CX, CY + 60, native.systemFont, 18)
    restartLabel:setFillColor(0.8, 0.9, 0.8)
    
    local nextBtn = display.newRoundedRect(winScreenGroup, CX, CY + 105, 160, 35, 8)
    nextBtn:setFillColor(0.25, 0.35, 0.5)
    nextBtn:setStrokeColor(0.5, 0.5, 0.6)
    nextBtn.strokeWidth = 1
    local nextLabel = display.newText(winScreenGroup, "СЛЕДУЮЩИЙ", CX, CY + 105, native.systemFont, 18)
    nextLabel:setFillColor(0.8, 0.9, 0.9)
    
    menuBtn:addEventListener("tap", function()
        composer.removeScene("level3")
        composer.gotoScene("start", { effect = "fade", time = 200 })
    end)
    
    restartBtn:addEventListener("tap", function()
        composer.removeScene("level3")
        composer.gotoScene("level3", { effect = "fade", time = 200 })
    end)
    
    nextBtn:addEventListener("tap", function()
        composer.removeScene("level3")
        composer.gotoScene("level4", { effect = "slideLeft", time = 300 })
    end)
end

-- ПРЫЖОК 
local function jump()
    if isDead or levelCompleted or isDucking then return end
    if jumpsLeft <= 0 then return end
    
    player:setLinearVelocity(0, -350)
    soundManager.playSound("jump")
    startJumpAnimation()
    jumpsLeft = jumpsLeft - 1
end

-- ПРИГИБ
local function duck()
    if isDead or levelCompleted then return end
    if isDucking then return end
    isDucking = true
    startCrouchAnimation()
    player.height = 35
    physics.removeBody(player)
    physics.addBody(player, "dynamic", { bounce = 0, friction = 1 })
    player.isFixedRotation = true
    soundManager.playSound("crouch")
end

local function standUp()
    if not isDucking then return end
    isDucking = false
    startRunAnimation()
    player.height = 60
    physics.removeBody(player)
    physics.addBody(player, "dynamic", { bounce = 0, friction = 1 })
    player.isFixedRotation = true
end

-- СТОП
local function startStop()
    if isDead or levelCompleted then return end
    isStopped = true
    soundManager.playSound("stop")
    startIdleAnimation()
end

local function endStop()
    isStopped = false
    startRunAnimation()
end

-- ВЫХОД В МЕНЮ
local function exitToMenu()
    if transitioning or levelCompleted or isDead then return end
    transitioning = true
    isDead = true
    
    if deathTimer then
        timer.cancel(deathTimer)
        deathTimer = nil
    end
    
    if animationTimer then
        timer.cancel(animationTimer)
        animationTimer = nil
    end
    
    composer.removeScene("level3")
    composer.gotoScene("start", { effect = "fade", time = 200 })
end

-- РЕСТАРТ
local function restartLevel()
    if deathTimer then deathTimer = nil end
    if animationTimer then
        timer.cancel(animationTimer)
        animationTimer = nil
    end
    composer.removeScene("level3")
    composer.gotoScene("level3", { effect = "fade", time = 200 })
end

-- ПРЕПЯТСТВИЯ 
local function createObstacle(x, type)
    local obs
    if type == "top" then
        local gap = 55

    -- высота стены = почти весь экран
    local wallHeight = H - gap - 40

    obs = display.newImageRect(
        scene.view,
        "images/stone_wall.png",
        50,
        wallHeight
    )

    -- привязка к потолку
    obs.anchorY = 0
    obs.y = top + 20
    else
        obs = display.newImageRect(scene.view, "images/spike.png", 45, 45)
        obs.y = ground.y - 32
    end
    obs.x = x
    physics.addBody(obs, "kinematic")
    obs.isSensor = true
    table.insert(obstacles, obs)
end

-- ПАДАЮЩИЙ ШИП 
local function createFallingSpike(x)
    local spike = display.newImageRect(scene.view, "images/spike_falling.png", 40, 42)
    spike.x = x
    spike.y = top + 35
    
    spike.shadow = display.newImageRect(scene.view, "images/spike_falling.png", 30, 32)
    spike.shadow.x = x
    spike.shadow.y = ground.y - 10
    spike.shadow:setFillColor(0.1, 0.1, 0.1, 0.4)
    spike.shadow.alpha = 0.4
    
    spike.isFalling = false
    spike.hasTriggered = false
    spike.fallTimer = nil
    spike.soundPlayed = false
    
    spike.myName = "fallingSpike"
    table.insert(fallingSpikes, spike)
end

-- CREATE
function scene:create(event)
    local sceneGroup = self.view
    
    
    isDead = false
    transitioning = false
    levelCompleted = false
    isDucking = false
    isStopped = false
    lastSpikeFallTime = 0
    score = 0
    jumpsLeft = 2
    
    if deathTimer then
        timer.cancel(deathTimer)
        deathTimer = nil
    end
    
    if gameLoop then Runtime:removeEventListener("enterFrame", gameLoop) end
    if collisionHandler then Runtime:removeEventListener("collision", collisionHandler) end
    
    for i = #obstacles, 1, -1 do
        if obstacles[i] and obstacles[i].removeSelf then
            obstacles[i]:removeSelf()
        end
        obstacles[i] = nil
    end
    obstacles = {}
    
    for i = #fallingSpikes, 1, -1 do
        if fallingSpikes[i] then 
            if fallingSpikes[i].shadow then fallingSpikes[i].shadow:removeSelf() end
            if fallingSpikes[i].fallTimer then timer.cancel(fallingSpikes[i].fallTimer) end
            fallingSpikes[i]:removeSelf()
        end
        fallingSpikes[i] = nil
    end
    fallingSpikes = {}
    
    for i = #goodStars, 1, -1 do
        if goodStars[i] and goodStars[i].removeSelf then
            goodStars[i]:removeSelf()
        end
        goodStars[i] = nil
    end
    goodStars = {}
    
    for i = #badStars, 1, -1 do
        if badStars[i] and badStars[i].removeSelf then
            badStars[i]:removeSelf()
        end
        badStars[i] = nil
    end
    badStars = {}
    
    for i = #runFrames, 1, -1 do
        if runFrames[i] then
            runFrames[i]:removeSelf()
            runFrames[i] = nil
        end
    end
    runFrames = {}
    
    for i = #jumpFrames, 1, -1 do
        if jumpFrames[i] then
            jumpFrames[i]:removeSelf()
            jumpFrames[i] = nil
        end
    end
    jumpFrames = {}
    
    for i = #crouchFrames, 1, -1 do
        if crouchFrames[i] then
            crouchFrames[i]:removeSelf()
            crouchFrames[i] = nil
        end
    end
    crouchFrames = {}
    
    for i = #idleFrames, 1, -1 do
        if idleFrames[i] then
            idleFrames[i]:removeSelf()
            idleFrames[i] = nil
        end
    end
    idleFrames = {}
    
    if winScreenGroup then
        winScreenGroup:removeSelf()
        winScreenGroup = nil
    end

    physics.start()
    physics.setGravity(0, 22)
    
    soundManager.playBackground()

    -- ФОН
    local bg = display.newRect(sceneGroup, CX, CY, W, H)
    bg:setFillColor(0.1, 0.1, 0.2)
    bg:toBack()

    -- ЗЕМЛЯ
    for i = 0, math.ceil(W / 100) + 2 do
        local tile = display.newImageRect(sceneGroup, "images/ground.png", 100, 30)
        tile.anchorX = 0
        tile.x = i * 100
        tile.y = bottom - 10
    end
    
    ground = display.newRect(sceneGroup, CX, bottom - 10, W + 15000, 30)
    ground:setFillColor(0.2, 0.7, 0.2)
    ground.alpha = 0
    physics.addBody(ground, "static", { bounce = 0, friction = 1 })
    ground.myName = "ground"

    -- ПОТОЛОК
    for i = 0, math.ceil(W / 100) + 2 do
        local tile = display.newImageRect(sceneGroup, "images/ground.png", 100, 30)
        tile:setFillColor(0.5, 0.5, 0.5)
        tile.anchorX = 0
        tile.x = i * 100
        tile.y = top + 10
    end
    
    ceiling = display.newRect(sceneGroup, CX, top + 10, W + 15000, 30)
    ceiling:setFillColor(0.2, 0.7, 0.2)
    ceiling.alpha = 0
    physics.addBody(ceiling, "static", { bounce = 0, friction = 1 })
    ceiling.myName = "ceiling"

    -- ИГРОК 
    player = display.newRect(sceneGroup, 120, CY, 60, 60)
    player:setFillColor(0, 0.8, 1)
    player.alpha = 0
    physics.addBody(player, "dynamic", { bounce = 0, friction = 1 })
    player.isFixedRotation = true
    player.myName = "player"

    -- ЗАГРУЗКА АНИМАЦИЙ
    local animLoaded = loadAnimations()
    
    if animLoaded then
        startRunAnimation()
    else
        print("Анимации не загружены")
    end

    -- ПРЕПЯТСТВИЯ 
    local step = 1400
    local startX = 1500
    
    for i = 0, 4 do
        local x = startX + i * step
        if i % 2 == 0 then
            createObstacle(x, "top")
        else
            createObstacle(x, "bottom")
        end
    end
    
    for i = 0, 4 do
        local x = startX + step/2 + i * step
        createFallingSpike(x)
    end

    -- ЗВЁЗДЫ
    createGoodStar(1800, ground.y - 60)   
    createGoodStar(2500, ground.y - 70)   
    createGoodStar(3200, ground.y - 55)   
    createGoodStar(3900, ground.y - 80)   
    createGoodStar(4700, ground.y - 65)     
    createGoodStar(5500, ground.y - 70)   
    createGoodStar(6400, ground.y - 30)   
    createGoodStar(7200, ground.y - 65)   
    
    createBadStar(2100, ground.y - 90)    
    createBadStar(2900, ground.y - 85)    
   
    createBadStar(5100, ground.y - 95)    
    createBadStar(6000, ground.y - 85)    
    createBadStar(6800, ground.y - 90)    

    -- ФИНИШ 
    finish = display.newImageRect(sceneGroup, "images/finish.png", 50, H)
    finish.x = startX + 7 * 850 + 800
    finish.y = CY
    physics.addBody(finish, "static", { isSensor = false })
    finish.myName = "finish"

    finish.collision = function(self, event)
        if event.phase ~= "began" then return end
        if event.other ~= player then return end
        if transitioning then return end
        if levelCompleted then return end

        transitioning = true

        loadProgress()
        if progress.unlockedLevel < 4 then
            progress.unlockedLevel = 4
            saveProgress()
        end

        showWinScreen()
    end
    finish:addEventListener("collision")

    -- ТЕКСТ СЧЁТА
    scoreText = display.newText({
        parent = sceneGroup,
        text = "ОЧКИ: 0",
        x = right - 80,
        y = top + 35,
        font = native.systemFontBold,
        fontSize = 18
    })
    scoreText:setFillColor(1, 1, 0.5)

    -- НАДПИСЬ УРОВНЯ
    local levelText = display.newText({
        parent = sceneGroup,
        text = "УРОВЕНЬ 3",
        x = right - 70,
        y = top + 65,
        font = native.systemFontBold,
        fontSize = 16
    })
    levelText:setFillColor(0.8, 0.8, 0.6)

    -- КНОПКИ 
    local uiGroup = display.newGroup()
    sceneGroup:insert(uiGroup)

    local jumpBtn = display.newCircle(uiGroup, right - 60, bottom - 60, 28)
    jumpBtn:setFillColor(0.5, 0.4, 0.2, 0.85)
    jumpBtn:setStrokeColor(0.6, 0.6, 0.6)
    jumpBtn.strokeWidth = 1
    local jumpText = display.newText(uiGroup, "↑", right - 60, bottom - 60, native.systemFontBold, 22)
    jumpText:setFillColor(0.9, 0.9, 0.7)
    jumpBtn:addEventListener("tap", jump)

    local duckBtn = display.newCircle(uiGroup, right - 120, bottom - 60, 28)
    duckBtn:setFillColor(0.3, 0.4, 0.5, 0.85)
    duckBtn:setStrokeColor(0.6, 0.6, 0.6)
    duckBtn.strokeWidth = 1
    local duckText = display.newText(uiGroup, "↓", right - 120, bottom - 60, native.systemFontBold, 22)
    duckText:setFillColor(0.8, 0.9, 0.9)
    duckBtn:addEventListener("touch", function(event)
        if event.phase == "began" then
            duck()
        elseif event.phase == "ended" then
            standUp()
        end
        return true
    end)

    local stopBtn = display.newCircle(uiGroup, right - 180, bottom - 60, 28)
    stopBtn:setFillColor(0.4, 0.3, 0.5, 0.85)
    stopBtn:setStrokeColor(0.6, 0.6, 0.6)
    stopBtn.strokeWidth = 1
    local stopText = display.newText(uiGroup, "⏹", right - 180, bottom - 60, native.systemFontBold, 22)
    stopText:setFillColor(0.8, 0.8, 0.9)
    stopBtn:addEventListener("touch", function(event)
        if event.phase == "began" then
            startStop()
        elseif event.phase == "ended" then
            endStop()
        end
        return true
    end)

    local menuBtn = display.newRect(uiGroup, left + 60, top + 35, 70, 35)
    menuBtn:setFillColor(0.4, 0.2, 0.2, 0.85)
    menuBtn:setStrokeColor(0.6, 0.6, 0.6)
    menuBtn.strokeWidth = 1
    local menuText = display.newText(uiGroup, "МЕНЮ", left + 60, top + 35 + 2, native.systemFontBold, 16)
    menuText:setFillColor(0.9, 0.8, 0.8)
    menuBtn:addEventListener("tap", exitToMenu)

    -- ОБРАБОТЧИК СТОЛКНОВЕНИЙ
    collisionHandler = function(event)
        if isDead or levelCompleted then return end

        if event.phase == "began" then
            local a, b = event.object1, event.object2
            local other = (a == player) and b or a

            if not other then return end
            
            if other == ground then
                jumpsLeft = 2
            end
            
            if other.myName == "goodStar" then
                score = score + 1
                if scoreText then scoreText.text = "ОЧКИ: " .. score end
                if other.removeSelf then other:removeSelf() end
                return
            end
            
            if other.myName == "badStar" then
                if score > 0 then
                    score = score - 1
                end
                if scoreText then scoreText.text = "ОЧКИ: " .. score end
                if other.removeSelf then other:removeSelf() end
                return
            end
            
            if other == finish then
                transitioning = true
                loadProgress()
                if progress.unlockedLevel < 4 then
                    progress.unlockedLevel = 4
                    saveProgress()
                end
                showWinScreen()
                return
            end

            if other and other.myName == "fallingSpike" and other.isFalling then
                isDead = true
                soundManager.playDeath()
                deathTimer = timer.performWithDelay(800, restartLevel)
            elseif other and other ~= ground and other ~= ceiling then
                isDead = true
                soundManager.playDeath()
                deathTimer = timer.performWithDelay(800, restartLevel)
            end
        end
    end
    Runtime:addEventListener("collision", collisionHandler)

    -- ДВИЖЕНИЕ МИРА
    gameLoop = function()
        if isDead or levelCompleted then return end

        local currentSpeed = isStopped and 0 or SPEED

        if currentAnimation == "run" and runFrames[currentFrameIndex] then
            runFrames[currentFrameIndex].x = player.x
            runFrames[currentFrameIndex].y = player.y
        elseif currentAnimation == "jump" and jumpFrames[currentFrameIndex] then
            jumpFrames[currentFrameIndex].x = player.x
            jumpFrames[currentFrameIndex].y = player.y
        elseif currentAnimation == "crouch" and crouchFrames[currentFrameIndex] then
            crouchFrames[currentFrameIndex].x = player.x
            crouchFrames[currentFrameIndex].y = player.y
        elseif currentAnimation == "idle" and idleFrames[currentFrameIndex] then
            idleFrames[currentFrameIndex].x = player.x
            idleFrames[currentFrameIndex].y = player.y
        end

        for i = #obstacles, 1, -1 do
            local o = obstacles[i]
            if o and o.x then
                o.x = o.x - currentSpeed
                if o.x + 50 < left then
                    if o.removeSelf then o:removeSelf() end
                    table.remove(obstacles, i)
                end
            end
        end
        
        for i = #goodStars, 1, -1 do
            local s = goodStars[i]
            if s and s.x then
                s.x = s.x - currentSpeed
                if s.x + 50 < left then
                    if s.removeSelf then s:removeSelf() end
                    table.remove(goodStars, i)
                end
            end
        end
        
        for i = #badStars, 1, -1 do
            local s = badStars[i]
            if s and s.x then
                s.x = s.x - currentSpeed
                if s.x + 50 < left then
                    if s.removeSelf then s:removeSelf() end
                    table.remove(badStars, i)
                end
            end
        end

        for i = #fallingSpikes, 1, -1 do
            local spike = fallingSpikes[i]
            if spike then
                spike.x = spike.x - currentSpeed
                if spike.shadow then spike.shadow.x = spike.shadow.x - currentSpeed end
                
                local distanceToPlayer = spike.x - player.x
                
                if not spike.isFalling and not spike.hasTriggered then
                    if distanceToPlayer > 0 and distanceToPlayer < 220 then
                        spike.hasTriggered = true
                        if spike.shadow then    
                            if spike.shadow.setFillColor then
                                spike.shadow:setFillColor(0.6, 0.1, 0.1, 0.7)
                            end
                            spike.shadow.alpha = 0.7
                        end
                        if spike.setFillColor then
                            spike:setFillColor(0.9, 0.3, 0.1)
                        end
                        
                        spike.fallTimer = timer.performWithDelay(350, function()
                            if spike then
                                spike.isFalling = true
                                if spike.shadow then spike.shadow.alpha = 0 end
                                physics.addBody(spike, "kinematic")
                                spike.isSensor = true
                                
                                local currentTime = system.getTimer()
                                if currentTime - lastSpikeFallTime > 150 then
                                    lastSpikeFallTime = currentTime
                                    soundManager.playSound("spike_fall")
                                else
                                    timer.performWithDelay(150, function()
                                        soundManager.playSound("spike_fall")
                                    end)
                                end
                            end
                        end)
                    end
                end
                
                if spike.isFalling and spike.y < ground.y - 20 then
                    spike.y = spike.y + 15
                end
                
                if spike.y >= ground.y - 20 then
                    if spike.fallTimer then timer.cancel(spike.fallTimer) end
                    if spike.shadow then spike.shadow:removeSelf() end
                    display.remove(spike)
                    table.remove(fallingSpikes, i)
                elseif spike.x + 50 < left then
                    if spike.fallTimer then timer.cancel(spike.fallTimer) end
                    if spike.shadow then spike.shadow:removeSelf() end
                    display.remove(spike)
                    table.remove(fallingSpikes, i)
                end
            end
        end

        if finish and finish.x then
            finish.x = finish.x - currentSpeed
        end
    end
    Runtime:addEventListener("enterFrame", gameLoop)
end

-- HIDE
function scene:hide(event)
    if event.phase == "will" then
        if gameLoop then Runtime:removeEventListener("enterFrame", gameLoop) end
        if collisionHandler then Runtime:removeEventListener("collision", collisionHandler) end
        if deathTimer then
            timer.cancel(deathTimer)
            deathTimer = nil
        end
        if animationTimer then
            timer.cancel(animationTimer)
            animationTimer = nil
        end
        isStopped = false
    end
end

-- DESTROY
function scene:destroy(event)
    if gameLoop then Runtime:removeEventListener("enterFrame", gameLoop) end
    if collisionHandler then Runtime:removeEventListener("collision", collisionHandler) end
    if deathTimer then
        timer.cancel(deathTimer)
        deathTimer = nil
    end
    if animationTimer then
        timer.cancel(animationTimer)
        animationTimer = nil
    end
    
    if obstacles then
        for i = #obstacles, 1, -1 do
            if obstacles[i] and obstacles[i].removeSelf then
                obstacles[i]:removeSelf()
            end
        end
    end
    obstacles = {}
    
    if goodStars then
        for i = #goodStars, 1, -1 do
            if goodStars[i] and goodStars[i].removeSelf then
                goodStars[i]:removeSelf()
            end
        end
    end
    goodStars = {}
    
    if badStars then
        for i = #badStars, 1, -1 do
            if badStars[i] and badStars[i].removeSelf then
                badStars[i]:removeSelf()
            end
        end
    end
    badStars = {}
    
    if fallingSpikes then
        for i = #fallingSpikes, 1, -1 do
            if fallingSpikes[i] then 
                if fallingSpikes[i].fallTimer then timer.cancel(fallingSpikes[i].fallTimer) end
                if fallingSpikes[i].shadow then fallingSpikes[i].shadow:removeSelf() end
                fallingSpikes[i]:removeSelf()
            end
            fallingSpikes[i] = nil
        end
    end
    fallingSpikes = {}
    
    for i = #runFrames, 1, -1 do
        if runFrames[i] then
            runFrames[i]:removeSelf()
            runFrames[i] = nil
        end
    end
    runFrames = {}
    
    for i = #jumpFrames, 1, -1 do
        if jumpFrames[i] then
            jumpFrames[i]:removeSelf()
            jumpFrames[i] = nil
        end
    end
    jumpFrames = {}
    
    for i = #crouchFrames, 1, -1 do
        if crouchFrames[i] then
            crouchFrames[i]:removeSelf()
            crouchFrames[i] = nil
        end
    end
    crouchFrames = {}
    
    for i = #idleFrames, 1, -1 do
        if idleFrames[i] then
            idleFrames[i]:removeSelf()
            idleFrames[i] = nil
        end
    end
    idleFrames = {}
    
    if winScreenGroup then
        winScreenGroup:removeSelf()
        winScreenGroup = nil
    end
    
    physics.stop()
end

scene:addEventListener("create", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene