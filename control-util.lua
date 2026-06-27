local control_util = require "shared-util"

---@type Global
--storage = storage

---@type LuaGameScript
--game = game

---@type LuaRendering
--rendering = rendering

---@type LuaBootstrap
--script = script


tower_names = {}
is_tower = {}

function control_util.register_tower_name(name)
	is_tower[name] = true
	table.insert(tower_names, name)
end

function control_util.is_tower(name)
	return is_tower[name] ~= nil
end

function control_util.dist_sqr(p1, p2)
	return (p1.x - p2.x) ^ 2 + (p1.y - p2.y) ^ 2
end

---@nodiscard
function control_util.inv_lerp(a, b, v)
	return math.max(math.min((v - a) / (b - a), 1), 0)
end

---@nodiscard
function control_util.calc_sun(surface)
	if surface.daytime > surface.evening then
		--game.print("morning!")
		return control_util.inv_lerp(surface.morning, surface.dawn, surface.daytime)
	else
		--game.print("evening!")
		return control_util.inv_lerp(surface.evening, surface.dusk, surface.daytime)
	end
end

function control_util.average_daylight(surface)
	if surface.platform then return 1.0 end

	-- Ticks for 3 regions of time
	local ticks_sunset = (surface.evening - surface.dusk)
	local ticks_night = (surface.morning - surface.evening)
	local ticks_sunrise = (surface.dawn - surface.morning)

	-- Night is annoying the middle range; this is the easier way to find day

	local day_length = 1 - ticks_sunset - ticks_night - ticks_sunrise

	return (day_length + ticks_sunset / 2 + ticks_sunrise / 2)
end

---@param tower LuaEntity
---@return MapPosition
function control_util.towerTarget(tower)
	return { x = tower.position.x, y = tower.position.y - 13 }
end

function control_util.get_tower_catch_area(inputs)
	return { { inputs.tower.position.x - inputs.radius, inputs.tower.position.y - inputs.radius },
		{ inputs.tower.position.x + inputs.radius, inputs.tower.position.y + inputs.radius } }
end

---@param inputs { entity:LuaEntity, radius:number? }
---@return LuaEntity[]
---@nodiscard
function control_util.find_towers_around_entity(inputs)
	return inputs.entity.surface.find_entities_filtered {
		name = tower_names,
		force = inputs.entity.force,
		area = control_util.get_tower_catch_area {
			tower = inputs.entity,
			-- Reduce radius by 2 to account for the size of the tower's base collider
			radius = (inputs.radius or control_util.tower_capture_radius) - 2,
		}
	}
end

---@param inputs { entity:LuaEntity, radius:number? }
---@return LuaEntity[]
---@nodiscard
function control_util.find_mirrors_around_entity(inputs)
	return inputs.entity.surface.find_entities_filtered {
		name = control_util.heliostat_mirror,
		force = inputs.entity.force,
		area = control_util.get_tower_catch_area {
			tower = inputs.entity,
			-- reduce radius by 1 to account of size of mirror's base collider
			radius = (inputs.radius or control_util.tower_capture_radius) - 1,
		},
		-- Only a certain number of mirrors can fit in this capture radius
		limit = math.min(control_util.max_mirrors_within_capture_radius, control_util.surface_max_mirrors(inputs.entity.surface)),
	}
end

function control_util.convert_to_indexed_table(array)
	t = {}
	for _, e in pairs(array) do
		t[e.unit_number] = e
	end
	return t
end

-- Variables for how often towers are updated
-- Interval is time between update bursts
-- Full update is time for these bursts to updated ALL towers
-- Update Fraction is what proportion of towers to update in each burst

control_util.tower_update_interval = 12
control_util.tower_full_update_time = 60
control_util.beam_update_interval = 120
control_util.beam_full_update_time = 600

control_util.tower_update_fraction = control_util.tower_update_interval / control_util.tower_full_update_time
control_util.beam_update_fraction = control_util.beam_update_interval / control_util.beam_full_update_time




control_util.register_tower_name(control_util.solar_power_tower)
control_util.register_tower_name(control_util.solar_laser_tower)

return control_util
