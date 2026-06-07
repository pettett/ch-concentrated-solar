local data_util = require("data-util")
local sounds = require("__base__.prototypes.entity.sounds")
local hit_effects = require("__base__.prototypes.entity.hit-effects")


local lens_height = -13.1

local function solar_laser_turret_extension(inputs)
	return data_util.auto_hr {
		filename = "solar-laser-tower-raise",
		priority = "medium",
		size = 64 * 3,
		frame_count = inputs.frame_count or 15,
		line_length = inputs.line_length or 0,
		run_mode = inputs.run_mode or "forward",
		axially_symmetrical = false,
		direction_count = 4,
		scale = 1.5,
		shift = { 0, lens_height },
	}
end

local tower_base_size = { x = 4, y = 15 }
local tower_base_shift = { -0.1105, -(16 / 2 - 2.6) }

local function solar_laser_turret_shooting()
	return data_util.auto_hr {
		filename = "solar-laser-tower-fire",
		line_length = 8,
		width = 64 * 3,
		height = 64 * 3,
		frame_count = 1,
		direction_count = 64,
		scale = 1.5,
		shift = { 0, lens_height },
	}
end

data:extend {
	{
		type = "fluid-turret",

		name = data_util.mod_prefix .. "solar-laser-tower",
		icon = data_util.sprite "icons/solar-laser-tower-icon.png",
		icon_size = 64,
		flags = { "placeable-player", "placeable-enemy", "player-creation" },
		minable = { mining_time = 1, result = data_util.mod_prefix .. "solar-laser-tower" },
		max_health = 4000,
		collision_box = { { -2.2, -2.2 }, { 2.2, 2.2 } },
		selection_box = { { -2.5, -2.5 }, { 2.5, 2.5 } },
		drawing_box = { { -2.5, -14.5 }, { 2.5, 2.5 } },
		damaged_trigger_effect = hit_effects.entity(),
		rotation_speed = 0.01,
		preparing_speed = 0.05,
		folding_speed = 0.05,
		preparing_sound = sounds.laser_turret_activate,
		folding_sound = sounds.laser_turret_deactivate,
		corpse = "medium-remnants",
		dying_explosion = "laser-turret-explosion",
		radius_visualisation_specification = {
			sprite = { filename = data_util.sprite "solar-power-tower-radius-visualisation.png", size = 12 },
			distance = data_util.tower_capture_radius
		},
		-- SE Compat
		se_allow_in_space = true,

		fluid_box =
		{
			volume           = data_util.solar_max_temp,
			pipe_connections = {},
			production_type  = "input",
			filter           = data_util.mod_prefix .. "solar-fluid"
		},
		fluid_buffer_input_flow = data_util.solar_max_temp,
		activation_buffer_ratio = 1 / 6,
		fluid_buffer_size = data_util.solar_max_temp,

		attack_parameters =
		{
			type              = "stream",
			fluids            = { { type = data_util.mod_prefix .. "solar-fluid" } },
			-- fluid_consumption = 1,
			-- warmup = 1,
			cooldown          = 1,
			range             = 150,
			min_range         = 6,
			turn_range        = 1.5 / 3.0,
			fluid_consumption = 10,
			--source_direction_count = 64,
			--source_offset = { 0, -3.423489 / 4 },
			ammo_category     = "laser",
			damage_modifier   = 1,
			ammo_type         =
			{
				action =
				{
					{
						type = "direct",
						action_delivery =
						{
							type = "beam",
							beam = data_util.mod_prefix .. "solar-beam",
							max_length = 50,
							duration = 30,
							source_offset = { 0, -13 },
							target_effects = {
								{
									type = "create-fire",
									entity_name = "fire-flame",
									check_buildability = true
								},
								-- {
								-- 	type = "script",
								-- 	effect_id = data_util.mod_prefix .. "sunlight-laser-damage"
								-- },
							}
						},
					},
					{
						type = "area",
						radius = 2.5,
						action_delivery =
						{
							type = "instant",
							target_effects =
							{
								{
									type = "damage",
									damage = { amount = 3, type = "laser" },
									apply_damage_to_trees = false
								}
							}
						}
					}
				}
			}
		},

		folded_animation =
		{
			layers =
			{
				solar_laser_turret_extension { frame_count = 1, line_length = 1 },
				--solar_laser_turret_extension_shadow { frame_count = 1, line_length = 1 },
				--solar_laser_turret_extension_mask { frame_count = 1, line_length = 1 }
			}
		},
		preparing_animation =
		{
			layers =
			{
				solar_laser_turret_extension {},
				--solar_laser_turret_extension_shadow {},
				--solar_laser_turret_extension_mask {}
			}
		},
		prepared_animation =
		{
			layers =
			{
				solar_laser_turret_shooting(),
				--solar_laser_turret_shooting_shadow(),
				--solar_laser_turret_shooting_mask()
			}
		},
		--attacking_speed = 0.1,
		--energy_glow_animation = laser_turret_shooting_glow(),
		glow_light_intensity = 0.5, -- defaults to 0
		folding_animation =
		{
			layers =
			{
				solar_laser_turret_extension { run_mode = "backward" },
				--solar_laser_turret_extension_shadow { run_mode = "backward" },
				--solar_laser_turret_extension_mask { run_mode = "backward" }
			}
		},
		base_picture_render_layer = "elevated-object",
		gun_animation_render_layer = "elevated-higher-object",
		--integration_patch_render_layer = "elevated-higher-object",
		graphics_set = {
			base_visualisation = {
				render_layer = "elevated-object",
				animation =
				{
					north = {
						layers =
						{
							data_util.auto_hr {
								filename = "solar-laser-tower",
								width = 64 * tower_base_size.x,
								height = 64 * tower_base_size.y,
								shift = tower_base_shift,
								priority = "high",
								direction_count = 1,
								frame_count = 1,
							},
							{
								filename = data_util.sprite "solar-laser-tower-shadow.png",
								width = 672,
								height = 109,
								shift = { 8, 0.5 },
								draw_as_shadow = true,
								priority = "high",
								direction_count = 1,
								frame_count = 1,
							},
							data_util.auto_hr {
								filename = "solar-laser-tower-mask",
								width = 64 * tower_base_size.x,
								height = 64 * tower_base_size.y,
								shift = tower_base_shift,
								flags = { "mask" },
								priority = "high",
								axially_symmetrical = false,
								apply_runtime_tint = true,
								direction_count = 1,
								frame_count = 1,
							}
						}
					}
				}
			}
		},
		vehicle_impact_sound = sounds.generic_impact,
		is_military_target = true,
		turret_base_has_direction = true,


		call_for_help_radius = 40,
		--water_reflection =
		--{
		--	pictures =
		--	{
		--		filename = "__base__/graphics/entity/laser-turret/laser-turret-reflection.png",
		--		priority = "extra-high",
		--		width = 20,
		--		height = 32,
		--		shift = util.by_pixel(0, 40),
		--		variation_count = 1,
		--		scale = 5
		--	},
		--	rotate = false,
		--	orientation_to_variation = false
		--}
	},
}
