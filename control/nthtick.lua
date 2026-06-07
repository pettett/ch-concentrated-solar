local nthtick      = {}

local control_util = require "control-util"
local beams        = require "control.beams"
local db           = require "control.database"

function nthtick.on_nth_tick_beam_update(event)
	--control_util.consistencyCheck()

	--beams.delete_all_beams()

	if not storage.towers[storage.last_updated_tower_beam] then
		storage.last_updated_tower_beam = nil
	end

	for i = 1, storage.tower_beam_update_count or 1, 1 do
		storage.last_updated_tower_beam = next(storage.towers, storage.last_updated_tower_beam)

		if storage.last_updated_tower_beam and db.valid_tid(storage.last_updated_tower_beam) then
			local tower = storage.towers[storage.last_updated_tower_beam].tower
			local sid = tower.surface.index

			--log("Generating beams on " .. data.surface.name)

			-- Start spawning beams for the day

			local stage = math.floor(control_util.calc_sun(tower.surface) * control_util.sun_stages) - 1

			--print("Generating beams around " .. storage.last_updated_tower_beam)
			-- max possible time a beam could live for, to account for possible errors
			local ttl = math.abs(tower.surface.evening - tower.surface.dawn) * tower.surface.ticks_per_day

			--game.print("New sun stage " .. stage .. " with life of " .. ttl)
			for mid, mirror in pairs(storage.towers[storage.last_updated_tower_beam].mirrors) do
				-- Can only spawn sun rays on mirrors with towers
				if db.valid_mid(mid) then
					local group = (mid * 29) % control_util.mirror_groups

					if group <= stage and storage.mirrors[mid].beam == nil then
						-- at this point, we dont need to worry about the old beams,
						-- as they have been destroyed
						storage.mirrors[mid].beam = beams.generateBeam
							{
								mirror = mirror,
								tower = tower,
								ttl = ttl
							}
					elseif group > stage and storage.mirrors[mid].beam then
						storage.mirrors[mid].beam.destroy()
						storage.mirrors[mid].beam = nil
					end
				end
			end
		end
	end
end

function nthtick.on_nth_tick_tower_update(event)
	--control_util.buildTrees()
	--control_util.consistencyCheck()

	-- Place fluid in towers

	if not storage.towers[storage.last_updated_tower] then
		storage.last_updated_tower = nil
	end

	for i = 1, storage.tower_update_count or 1, 1 do
		storage.last_updated_tower = next(storage.towers, storage.last_updated_tower)

		if storage.last_updated_tower then
			local tid = storage.last_updated_tower
			local mirrors = storage.towers[tid].mirrors

			--print("Updating tower " .. tid)

			local tower = storage.towers[tid].tower

			if db.valid_tid(tid) then
				local sun = control_util.calc_sun(tower.surface)

				if sun > 0 and table_size(mirrors) > 0 then
					local target_amount = control_util.surface_solar_mult(tower.surface) *
						control_util.fluid_temp_per_mirror *
						sun *
						table_size(mirrors)

					-- game.print("updating tower " .. tid .. "power" .. amount)

					-- set to temperature and amount, as fluid turrets cannot display temperature
					local fluid = tower.get_fluid_contents()
					local current_amount = 0

					if fluid ~= nil then
						current_amount = fluid[control_util.mod_prefix .. "solar-fluid"] or 0
					end

					local input_amount = target_amount - current_amount
					if input_amount > 0.01 then
						tower.insert_fluid({
							name = control_util.mod_prefix .. "solar-fluid",
							temperature = input_amount * (1.0 + tower.quality.level * 0.3),
							amount = input_amount
						})
					elseif input_amount < -0.01 then
						if input_amount < -0.01 then
							tower.remove_fluid({
								name = control_util.mod_prefix .. "solar-fluid",
								amount = -input_amount
							})
						end
					end
				end
			else
				--print("Deleting tower " .. tid)
				db.notify_tower_invalid(tid)
			end
		end
	end
end

return nthtick
