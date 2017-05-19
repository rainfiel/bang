
local utls = require "ejoy2dx.utls"
local sound = require "ejoy2dx.Liekkas.sound"
local sprite = require "ejoy2d.sprite"
local ejoy2dx = require "ejoy2dx"
local render = ejoy2dx.render

local function play(res)
	local p = utls.get_path("sound/"..res)
	sound:load(p)
	sound:play(p)
end

local info_label
local function info(txt)
	if not info_label then
		info_label = sprite.label({width=500, height=30,size=24,color=0xFFFFFFFF, edge=0, align="c"})
		render:get(0):show(info_label, 0, render.center)
		info_label:ps(-250, 0)
	end
	info_label.text = txt
end


local M = {}

function M:init(node)
	node.on_default = self.on_message
end

function M.on_message(node, str, num, stat)
	print(node, str, num, stat)
	if stat == "click" then
		play("FO_FX_M4_FIRE.wav")
	elseif stat == "connect" then
		print("connect")
		info("connect")
	end
end

return M