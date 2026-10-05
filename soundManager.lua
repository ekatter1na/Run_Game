
local M = {}

local sounds = {}
local backgroundChannel = nil
local isSoundOn = true
local isPlaying = false 

-- Громкость
local SFX_VOLUME = 0.8
local MUSIC_VOLUME = 0.1

function M.load()
    -- Загрузка звуковых эффектов 
    local function safeLoad(path)
        local success, sound = pcall(audio.loadSound, path)
        if success then
            return sound
        else
            print("Не удалось загрузить звук: " .. path)
            return nil
        end
    end
    
    local function safeLoadStream(path)
        local success, sound = pcall(audio.loadStream, path)
        if success then
            return sound
        else
            print("Не удалось загрузить музыку: " .. path)
            return nil
        end
    end
    
    sounds.jump = safeLoad("sounds/jump.mp3")
    sounds.crouch = safeLoad("sounds/crouch.mp3")
    sounds.stop = safeLoad("sounds/stop.mp3")
    sounds.shoot = safeLoad("sounds/shoot.mp3")
    sounds.spike_fall = safeLoad("sounds/spike_fall.mp3")
    sounds.enemy_death = safeLoad("sounds/enemy_death.mp3")
    sounds.level_complete = safeLoad("sounds/level_complete.mp3")
    sounds.game_over = safeLoad("sounds/game_over.mp3")
    sounds.background = safeLoadStream("sounds/background.mp3")
    
    print("Звуки загружены")
end

function M.playSound(soundName)
    if not isSoundOn then return end
    local sound = sounds[soundName]
    if sound then
        audio.play(sound, { channel = 1, volume = SFX_VOLUME })
    end
end

function M.playBackground()
    if not isSoundOn then return end
    if isPlaying then return end
    if backgroundChannel then
        audio.stop(backgroundChannel)
        backgroundChannel = nil
    end
    if sounds.background then
        backgroundChannel = audio.play(sounds.background, { channel = 2, loops = -1, volume = MUSIC_VOLUME })
        isPlaying = true
    end
end

function M.stopBackground()
    if backgroundChannel then
        audio.stop(backgroundChannel)
        backgroundChannel = nil
    end
    isPlaying = false
end

-- ДОБАВЛЕННЫЕ ФУНКЦИИ
function M.playDeath()
    if not isSoundOn then return end
    M.stopBackground()
    M.playSound("game_over")
end

function M.playLevelComplete()
    if not isSoundOn then return end
    M.playSound("level_complete")
end

function M.setSoundOn(enabled)
    isSoundOn = enabled
    if not enabled then
        M.stopBackground()
    else
        isPlaying = false
        M.playBackground()
    end
end

function M.unload()
    M.stopBackground()
    for name, sound in pairs(sounds) do
        if sound then
            audio.dispose(sound)
        end
    end
    sounds = {}
    isPlaying = false
end

return M