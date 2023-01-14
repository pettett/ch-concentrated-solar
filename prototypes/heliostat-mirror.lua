local data_util = require("data-util")

data:extend {

	{
		type  = "turret",
		name  = data_util.mod_prefix .. "heliostat-mirror",
		flags = { "placeable-neutral", "player-creation" },

		icon = data_util.sprite "heliostat-mirror-icon.png",
		icon_size = 64, icon_mipmaps = 4,

		--show_recipe_icon = false,
		is_military_target   = false,
		call_for_help_radius = 0,
		attack_parameters    = {
			type      = "beam",
			ammo_type = { category = "beam" },
			range     = 0,
			cooldown  = 1000000,
		},
		minable              = {
			mining_time = 0.5,
			result      = data_util.mod_prefix .. 'heliostat-mirror'
		},
		friendly_map_color   = data.raw["utility-constants"]["default"].chart.default_friendly_color_by_type["solar-panel"],
		max_health           = 150,
		corpse               = 'medium-small-remnants',
		collision_box        = { { -1.1, -1.1 }, { 1.2, 1.2 } },
		selection_box        = { { -1.5, -1.5 }, { 1.5, 1.5 } },
		drawing_box          = { { -1.5, -2 }, { 1.5, 1.5 } },

		base_picture = {
			layers = {
				data_util.auto_hr {
					filename = "heliostat-mirror-turret-base",
					size = 32 * 3,
					direction_count = 1,
					scale = 1,
					shift = { 0, 0 },
					frame_count = 1,
				},
				{

					filename = data_util.sprite("heliostat-mirror-turret-base-shadow.png"),
					line_length = 1,
					size = 32 * 3,
					draw_as_shadow = true,
					direction_count = 1,
					frame_count = 1,
					shift = util.by_pixel(0, 6),

				}
			}
		},

		folded_animation = {
			layers = {
				data_util.auto_hr {
					direction_count = 32,
					filename = "heliostat-mirror-turret",
					size = 32 * 4,
					frame_count = 1,
					shift = { 0, -0.6 },
					line_length = 8,
				},
				{
					direction_count = 32,
					filename = data_util.sprite("heliostat-mirror-turret-shadow.png"),
					width = 160,
					height = 112,
					frame_count = 1,
					draw_as_shadow = true,
					shift = { 1.5, 0 },
					line_length = 8
				},
			}
		},
	},


}
