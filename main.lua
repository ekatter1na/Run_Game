local composer = require("composer")
local soundManager = require("soundManager")

display.setStatusBar(display.HiddenStatusBar)

soundManager.load()

composer.gotoScene("start")