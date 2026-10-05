local composer = require("composer")
local scene = composer.newScene()
local physics = require("physics")

local json = require("json")
local soundManager = require("soundManager")

local player
local ground, ceiling
local obstacles = {}
local enemies = {}
local finish
local canShoot = true
local shootTimer = nil
local goodStars = {}
local badStars = {}
local score = 0
local scoreText = nil

local isDead = false
local isDucking = false
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
local deathFrames = {}
local currentAnimation = nil
local animationTimer = nil
local currentFrameIndex = 1
local deathAnimationComplete = false

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
local progress = { unlockedLevel = 4 }

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

-- РЕСТАРТ
local function restartLevel()
    if deathTimer then deathTimer = nil end
    if shootTimer then timer.cancel(shootTimer) end
    if animationTimer then timer.cancel(animationTimer) end
    
    soundManager.stopBackground()
    
    composer.removeScene("level4")
    composer.gotoScene("level4", { effect = "fade", time = 200 })
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
    for i = 1, #deathFrames do
        if deathFrames[i] then deathFrames[i].isVisible = false end
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
    elseif currentAnimation == "death" then
        if deathFrames[currentFrameIndex] then
            deathFrames[currentFrameIndex].isVisible = true
            deathFrames[currentFrameIndex].x = player.x
            deathFrames[currentFrameIndex].y = player.y
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
    elseif currentAnimation == "death" then
        if currentFrameIndex > #deathFrames then
            if not deathAnimationComplete then
                deathAnimationComplete = true
                timer.performWithDelay(500, function()
                    restartLevel()
                end)
            end
            return
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

local function startDeathAnimation()
    if animationTimer then
        timer.cancel(animationTimer)
        animationTimer = nil
    end
    
    for i = 1, #runFrames do
        if runFrames[i] then runFrames[i].isVisible = false end
    end
    for i = 1, #jumpFrames do
        if jumpFrames[i] then jumpFrames[i].isVisible = false end
    end
    for i = 1, #crouchFrames do
        if crouchFrames[i] then crouchFrames[i].isVisible = false end
    end
    
    currentAnimation = "death"
    currentFrameIndex = 1
    deathAnimationComplete = false
    
    if deathFrames[1] then
        deathFrames[1].isVisible = true
        deathFrames[1].x = player.x
        deathFrames[1].y = player.y
    end
    
    animationTimer = timer.performWithDelay(100, function()
        if currentAnimation == "death" and not deathAnimationComplete then
            if deathFrames[currentFrameIndex] then
                deathFrames[currentFrameIndex].isVisible = false
            end
            
            currentFrameIndex = currentFrameIndex + 1
            
            if currentFrameIndex <= #deathFrames then
                if deathFrames[currentFrameIndex] then
                    deathFrames[currentFrameIndex].isVisible = true
                    deathFrames[currentFrameIndex].x = player.x
                    deathFrames[currentFrameIndex].y = player.y
                end
            else
                deathAnimationComplete = true
                if animationTimer then
                    timer.cancel(animationTimer)
                    animationTimer = nil
                end
                timer.performWithDelay(300, function()
                    restartLevel()
                end)
            end
        end
    end, 0)
end

-- ЗАГРУЗКА АНИМАЦИЙ
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
            path = "images/pers/Dead__00" .. i .. ".png"
        else
            path = "images/pers/Dead__0" .. i .. ".png"
        end
        local frame = display.newImageRect(path, frameWidth, frameHeight)
        frame.isVisible = false
        table.insert(deathFrames, frame)
        scene.view:insert(frame)
    end
    
    print("Загружено кадров: бег - " .. #runFrames .. ", прыжок - " .. #jumpFrames .. ", присед - " .. #crouchFrames .. ", смерть - " .. #deathFrames)
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
    
    if shootTimer then
        timer.cancel(shootTimer)
        shootTimer = nil
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
    
    menuBtn:addEventListener("tap", function()
        composer.removeScene("level4")
        composer.gotoScene("start", { effect = "fade", time = 200 })
    end)
    
    restartBtn:addEventListener("tap", function()
        composer.removeScene("level4")
        composer.gotoScene("level4", { effect = "fade", time = 200 })
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

-- ПРИГИБАНИЕ
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

-- СТРЕЛЬБА
local function shoot()
    if isDead or levelCompleted or not canShoot then return end
    
    canShoot = false
    soundManager.playSound("shoot")
    
    local bullet = display.newRect(scene.view, player.x + 20, player.y, 10, 5)
    bullet:setFillColor(1, 1, 0)
    physics.addBody(bullet, "kinematic")
    bullet.isSensor = true
    bullet.myName = "bullet"
    bullet.isHit = false
    
    local hitTimer = timer.performWithDelay(16, function()
        if not bullet or bullet.isHit then return end
        for i = #enemies, 1, -1 do
            local enemy = enemies[i]
            if enemy and bullet and math.abs(bullet.x - enemy.x) < 30 and math.abs(bullet.y - enemy.y) < 30 then
                bullet.isHit = true
                soundManager.playSound("enemy_death")
                
                local explosion = display.newCircle(scene.view, enemy.x, enemy.y, 15)
                explosion:setFillColor(1, 0.5, 0)
                transition.fadeOut(explosion, { time = 150 })
                
                if enemy.eyes then
                    for _, eye in ipairs(enemy.eyes) do 
                        if eye then eye:removeSelf() end
                    end
                end
                display.remove(enemy)
                table.remove(enemies, i)
                if bullet then bullet:removeSelf() end
                break
            end
        end
    end, 0)
    
    transition.to(bullet, {
        x = bullet.x + 500,
        time = 300,
        onComplete = function()
            if hitTimer then timer.cancel(hitTimer) end
            if bullet and not bullet.isHit then bullet:removeSelf() end
        end
    })
    
    shootTimer = timer.performWithDelay(500, function()
        canShoot = true
        shootTimer = nil
    end)
end

-- ВРАГ
local function createEnemy(x)
    local enemy = display.newImageRect(scene.view, "images/enemy.png", 45, 45)
    enemy.x = x
    enemy.y = ground.y - 30
    physics.addBody(enemy, "kinematic")
    enemy.isSensor = true
    enemy.myName = "enemy"
    table.insert(enemies, enemy)
    return enemy
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

-- ВЫХОД В МЕНЮ
local function exitToMenu()
    if transitioning or levelCompleted or isDead then return end
    transitioning = true
    isDead = true
    
    if deathTimer then
        timer.cancel(deathTimer)
        deathTimer = nil
    end
    
    if shootTimer then
        timer.cancel(shootTimer)
        shootTimer = nil
    end
    
    if animationTimer then
        timer.cancel(animationTimer)
        animationTimer = nil
    end
    
    composer.removeScene("level4")
    composer.gotoScene("start", { effect = "fade", time = 200 })
end

-- CREATE
function scene:create(event)
    local sceneGroup = self.view
    
    
    soundManager.stopBackground()
    timer.performWithDelay(100, function()
        soundManager.playBackground()
    end)
    
    isDead = false
    transitioning = false
    levelCompleted = false
    isDucking = false
    canShoot = true
    score = 0
    jumpsLeft = 2
    deathAnimationComplete = false
    
    if deathTimer then
        timer.cancel(deathTimer)
        deathTimer = nil
    end
    
    if shootTimer then
        timer.cancel(shootTimer)
        shootTimer = nil
    end
    
    if animationTimer then
        timer.cancel(animationTimer)
        animationTimer = nil
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
    
    for i = #enemies, 1, -1 do
        if enemies[i] then 
            if enemies[i].eyes then
                for _, eye in ipairs(enemies[i].eyes) do eye:removeSelf() end
            end
            enemies[i]:removeSelf()
        end
        enemies[i] = nil
    end
    enemies = {}
    
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
    
    for i = #deathFrames, 1, -1 do
        if deathFrames[i] then
            deathFrames[i]:removeSelf()
            deathFrames[i] = nil
        end
    end
    deathFrames = {}
    
    if winScreenGroup then
        winScreenGroup:removeSelf()
        winScreenGroup = nil
    end

    physics.start()
    physics.setGravity(0, 22)

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
    
    -- ВРАГИ
    local enemyPositions = {
        startX + step * 0.6,
        startX + step * 1.6,
        startX + step * 2.6,
        startX + step * 3.6,
        startX + step * 4.6,
    }
    
    for _, x in ipairs(enemyPositions) do
        createEnemy(x)
    end

    -- ЗВЁЗДЫ 
    createGoodStar(1900, ground.y - 60)   
    createGoodStar(2600, ground.y - 70)   
    createGoodStar(3300, ground.y - 55)   
    createGoodStar(4000, ground.y - 80)   
    createGoodStar(5200, ground.y - 50)   
    createGoodStar(5900, ground.y - 70)   
    createGoodStar(6600, ground.y - 60)   
    createGoodStar(7300, ground.y - 65)   
    createGoodStar(8100, ground.y - 55)   
    createGoodStar(8800, ground.y - 60)  

    createBadStar(2200, ground.y - 85)    
    createBadStar(3600, ground.y - 90)    
    createBadStar(4800, ground.y - 85)    
    createBadStar(6200, ground.y - 85)    
    createBadStar(7500, ground.y - 90)    
    createBadStar(8300, ground.y - 85)         

    -- ФИНИШ
    finish = display.newImageRect(sceneGroup, "images/finish.png", 50, H)
    finish.x = startX + 5 * step + 800
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
        text = "УРОВЕНЬ 4",
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

    local shootBtn = display.newCircle(uiGroup, right - 180, bottom - 60, 28)
    shootBtn:setFillColor(0.5, 0.3, 0.4, 0.85)
    shootBtn:setStrokeColor(0.6, 0.6, 0.6)
    shootBtn.strokeWidth = 1
    local shootText = display.newText(uiGroup, "🔫", right - 180, bottom - 60, native.systemFontBold, 22)
    shootText:setFillColor(0.9, 0.8, 0.9)
    shootBtn:addEventListener("tap", shoot)

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
            
            if other and other.myName == "enemy" then
                isDead = true
                soundManager.playDeath()
                startDeathAnimation()
                if deathTimer then
                    timer.cancel(deathTimer)
                    deathTimer = nil
                end
                return
            end

            if other and other ~= ground and other ~= ceiling and other.myName ~= "bullet" and other.myName ~= "goodStar" and other.myName ~= "badStar" then
                isDead = true
                soundManager.playDeath()
                startDeathAnimation()
                if deathTimer then
                    timer.cancel(deathTimer)
                    deathTimer = nil
                end
            end
        end
    end
    Runtime:addEventListener("collision", collisionHandler)

    -- ДВИЖЕНИЕ МИРА
    gameLoop = function()
        if isDead or levelCompleted then return end

        if currentAnimation == "run" and runFrames[currentFrameIndex] then
            runFrames[currentFrameIndex].x = player.x
            runFrames[currentFrameIndex].y = player.y
        elseif currentAnimation == "jump" and jumpFrames[currentFrameIndex] then
            jumpFrames[currentFrameIndex].x = player.x
            jumpFrames[currentFrameIndex].y = player.y
        elseif currentAnimation == "crouch" and crouchFrames[currentFrameIndex] then
            crouchFrames[currentFrameIndex].x = player.x
            crouchFrames[currentFrameIndex].y = player.y
        elseif currentAnimation == "death" and deathFrames[currentFrameIndex] then
            deathFrames[currentFrameIndex].x = player.x
            deathFrames[currentFrameIndex].y = player.y
        end

        for i = #obstacles, 1, -1 do
            local o = obstacles[i]
            if o and o.x then
                o.x = o.x - SPEED
                if o.x + 50 < left then
                    if o.removeSelf then o:removeSelf() end
                    table.remove(obstacles, i)
                end
            end
        end
        
        for i = #enemies, 1, -1 do
            local e = enemies[i]
            if e then
                e.x = e.x - SPEED
                if e.eyes then
                    for _, eye in ipairs(e.eyes) do
                        if eye then eye.x = eye.x - SPEED end
                    end
                end
                if e.x + 50 < left then
                    if e.eyes then
                        for _, eye in ipairs(e.eyes) do eye:removeSelf() end
                    end
                    display.remove(e)
                    table.remove(enemies, i)
                end
            end
        end
        
        for i = #goodStars, 1, -1 do
            local s = goodStars[i]
            if s and s.x then
                s.x = s.x - SPEED
                if s.x + 50 < left then
                    if s.removeSelf then s:removeSelf() end
                    table.remove(goodStars, i)
                end
            end
        end
        
        for i = #badStars, 1, -1 do
            local s = badStars[i]
            if s and s.x then
                s.x = s.x - SPEED
                if s.x + 50 < left then
                    if s.removeSelf then s:removeSelf() end
                    table.remove(badStars, i)
                end
            end
        end

        if finish and finish.x then
            finish.x = finish.x - SPEED
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
        if shootTimer then
            timer.cancel(shootTimer)
            shootTimer = nil
        end
        if animationTimer then
            timer.cancel(animationTimer)
            animationTimer = nil
        end
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
    if shootTimer then
        timer.cancel(shootTimer)
        shootTimer = nil
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
    
    if enemies then
        for i = #enemies, 1, -1 do
            if enemies[i] then 
                if enemies[i].eyes then
                    for _, eye in ipairs(enemies[i].eyes) do eye:removeSelf() end
                end
                enemies[i]:removeSelf()
            end
            enemies[i] = nil
        end
    end
    enemies = {}
    
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
    
    for i = #deathFrames, 1, -1 do
        if deathFrames[i] then
            deathFrames[i]:removeSelf()
            deathFrames[i] = nil
        end
    end
    deathFrames = {}
    
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