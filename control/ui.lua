local ui = {}

local control_util = require "control-util"


ui.on_gui_opened = function(event)
	if event.gui_type == defines.gui_type.entity and event.entity and event.entity.name == control_util.solar_power_tower then
		local player = game.get_player(event.player_index)

		if player == nil then
			return
		end

		local main_frame = player.gui.screen.add {
			type = "frame",
			name = "solar_tower_main_frame",
			direction = "vertical"
		}
		local entity = event.entity
		main_frame.style.vertically_stretchable = true
		main_frame.style.horizontally_stretchable = true
		main_frame.auto_center = true
		main_frame.tags = { tid = entity.unit_number }
		-- TItlebar
		local titlebar = main_frame.add { type = "flow" }

		titlebar.drag_target = main_frame
		titlebar.add {
			type = "label",
			style = "frame_title",
			caption = event.entity.prototype.localised_name,
			ignored_by_interaction = true,
		}
		local filler = titlebar.add {
			type = "empty-widget",
			style = "draggable_space",
			ignored_by_interaction = true,
		}
		filler.style.height = 24
		filler.style.horizontally_stretchable = true
		titlebar.add {
			type = "sprite-button",
			name = "chcs-solar-tower-x-button",
			style = "frame_action_button",
			sprite = "utility/close",
			tooltip = { "gui.close-instruction" },
		}

		player.opened = main_frame

		local content_frame = main_frame.add { type = 'frame', name = 'content_frame', style =
		'inside_shallow_frame_with_padding' }


		local content_flow = content_frame.add { type = 'flow', name = 'content_flow', direction = 'vertical' }
		-- Standard factorio stylings

		content_flow.style.vertical_spacing = 8
		content_flow.style.left_margin = 4
		content_flow.style.vertical_align = 'center'

		local preview_frame = content_flow.add { type = 'frame', name = 'camera_frame' }
		local preview = preview_frame.add { type = 'entity-preview', name = 'preview' }
		preview.visible = true
		preview.style.height = 200
		preview.style.width = 260
		preview.entity = entity


		content_flow.add { type = 'progressbar', name = 'sun_progressbar', style =
		'electric_satisfaction_statistics_progressbar' }.style.horizontally_stretchable = true

		content_flow.add { type = 'progressbar', name = 'heat_progressbar', style =
		'electric_satisfaction_statistics_progressbar' }.style.horizontally_stretchable = true


		content_flow.add { type = 'line' }

		content_flow.add { type = 'label', name = 'mirrors' }
		content_flow.add { type = 'label', name = 'current_power' }
		content_flow.add { type = 'label', name = 'average_power' }
		content_flow.add { type = 'label', name = 'daylight' }

		ui.update_gui(main_frame)
	end
end

ui.on_gui_closed = function(event)
	if event.element and event.element.name == "solar_tower_main_frame" then
		event.element.destroy()
	end
end

ui.on_gui_click = function(event)
	if event.element and event.element.name == "chcs-solar-tower-x-button" then
		event.element.parent.parent.destroy()
	end
end

ui.update_guis = function()
	for _, player in pairs(game.connected_players) do
		local gui = player.gui.screen.solar_tower_main_frame
		if gui then ui.update_gui(gui) end
	end
end



ui.update_gui = function(gui)
	if not storage.towers[gui.tags.tid] then
		gui.destroy()
		return
	end


	local mirrors = storage.towers[gui.tags.tid].mirrors
	local tower = storage.towers[gui.tags.tid].tower
	if not tower then
		gui.destroy();
		return
	end

	local content_flow = gui.content_frame.content_flow
	local surface = tower.surface
	local daylight = control_util.calc_sun(surface)


	local fluid = tower.fluidbox[1]

	if not fluid then
		fluid = {
			temperature = 0,
			amount = 0,
			name = "chcs-solar-fluid"
		}
	end

	local solar_mult = control_util.surface_solar_mult(surface)

	local mirror_count = table_size(mirrors)
	local unit_ratio = 0.000001
	local current_production = fluid.temperature * prototypes.fluid[fluid.name].heat_capacity * unit_ratio
	local max_production = mirror_count * solar_mult * control_util.fluid_temp_per_mirror *
		prototypes.fluid[fluid.name].heat_capacity * unit_ratio * (1.0 + tower.quality.level * 0.3)


	content_flow.sun_progressbar.value = daylight
	content_flow.sun_progressbar.caption = {
		'ch-gui.tower-solar-energy',
		math.floor(daylight * 100),
		math.floor(solar_mult * 100.0)
	}


	content_flow.heat_progressbar.value = fluid.temperature /
		(control_util.solar_max_temp * (1.0 + tower.quality.level * 0.3))
	content_flow.heat_progressbar.caption = { 'ch-gui.tower-heat', math.floor(fluid.temperature * 100) / 100 }

	content_flow.mirrors.caption = {
		'ch-gui.mirrors',
		mirror_count,
		control_util.surface_max_mirrors(surface)
	}

	content_flow.current_power.caption = { 'ch-gui.current-power', math.floor(current_production * 100) / 100 }

	content_flow.average_power.caption = { 'ch-gui.average-power',
		math.floor(max_production * control_util.average_daylight(surface) * 100) / 100 }
end

return ui
