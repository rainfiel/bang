local ej = require "ejoy2d"
local ejoy2dx = require "ejoy2dx"
local fw = require "ejoy2d.framework"
local package = require "ejoy2dx.package"
local image = require "ejoy2dx.image"
local render = ejoy2dx.render

local message = require "ejoy2dx.message"
local bluetooth = require "bluetooth"

local id, bt = message.register(-2)
bluetooth:init(bt)

local default = render:create(0, 'default')

package:path(fw.WorkDir..[[/asset/?]])


local game = {}
local screencoord = { x = 496, y = 316, scale = 1 }

function game.update()
end

function game.drawframe()
	render:draw()
end

function game.touch(what, x, y)
end

function game.message(...)
	message.on_message(...)
end

function game.handle_error(...)
end

function game.on_resume()
end

function game.on_pause()
end

function game.gesture()
end

ej.start(game)


