local db = {}
local control_util = require "control-util"

function db.on_init()
	-- Ensure every storage table used exists

	---@type  {[uint] : MirrorTowerRelation}
	storage.mirrors = storage.mirrors or {}

	---@type {[uint] : {tower:LuaEntity, mirrors: {[uint] : LuaEntity}}}
	storage.towers = storage.towers or {}

	---@type {[uint] : LuaEntity}
	storage.player_boxes = storage.player_boxes or {}

	---@type {[uint] : LuaEntity}
	storage.player_tower_rect = storage.player_tower_rect or {}

	--control_util.buildTrees()

	db.consistency_check()

	game.print(control_util.mod_prefix .. "welcome")
end

---@param tid uint?
---@nodiscard
function db.tid_registered(tid)
	return tid and storage.towers[tid]
end

-- catch all functions for if a tid or mid is safe to use
---@param tid uint?
---@nodiscard
function db.valid_tid(tid)
	return db.tid_registered(tid) and storage.towers[tid].tower and storage.towers[tid].tower.valid
end

---@param mid uint?
---@nodiscard
function db.mid_registered(tid)
	return tid and storage.mirrors[tid]
end

---@param mid uint?
---@nodiscard
function db.valid_mid(mid)
	return db.mid_registered(mid) and storage.mirrors[mid].mirror and storage.mirrors[mid].mirror.valid
end

---@param inputs {towers:LuaEntity[], position:Vector, ignore_id : number?}
---@return LuaEntity?
---@nodiscard
function db.closest_tower(inputs)
	local bestTower = nil
	local bestDistance = nil
	for _, tower in pairs(inputs.towers) do
		if tower and tower.valid and tower.unit_number ~= inputs.ignore_id then
			local dist = control_util.dist_sqr(tower.position, inputs.position)

			if bestTower == nil or
				(bestTower and dist < bestDistance) then
				bestTower = tower
				bestDistance = dist
			end
		end
	end

	return bestTower
end

---@param args {mirror:LuaEntity, tower:LuaEntity, all_in_range : LuaEntity[]? }
--- Link a mirror and a tower, rotating the mirror to point in the correct direction
--- `all_in_range` - all towers in range of the mirror, assigned to `[mid]=in_range` if mirror is new
function db.link_mirror_to_tower(args)
	local tower = args.tower
	local mirror = args.mirror

	assert(mirror, "No mirror")
	assert(tower, "No tower")
	assert(tower.surface.index == mirror.surface.index, "Attempted to link tower and mirror on different surfaces")

	local mid = mirror.unit_number

	if db.valid_mid(mid) then
                if storage.mirrors[mid].tower then
                        -- If this mirror has a tower, do something about it    

                        local prior_tower = storage.mirrors[mid].tower
                        if not prior_tower.valid then
                                -- Clean up stale tower references instead of crashing.
                                if storage.towers then
                                        for _, tdata in pairs(storage.towers) do
                                                if tdata.mirrors and tdata.mirrors[mid] then
                                                        tdata.mirrors[mid] = nil
                                                end
                                        end
                                end
                                storage.mirrors[mid].tower = nil
                        elseif prior_tower.unit_number == tower.unit_number then
                                -- We are already linked to this tower!
                                return
                        else
                                --add the previous link to in_range
                                db.mark_in_range(mid, prior_tower)
                                -- Clean up previous link
                                db.remove_mirror_from_tower { mid = mid, tid = prior_tower.unit_number }
                        end
                end
		-- If this tower was marked in range before, remove it
		db.mark_out_range(mid, tower)
		-- Link in the mirror -> tower direction
		storage.mirrors[mid].tower = tower
	else
		storage.mirrors[mid] = {
			tower = tower,
			mirror = mirror,
			in_range = args.all_in_range
		}
		-- In range could include the closest tower, due to lazyness
		db.mark_out_range(mid, tower)
	end


	-- Don't generate beams, this will happen naturally

	-- Link in the tower -> mirrors direction

	if not storage.towers[tower.unit_number] then
		storage.towers[tower.unit_number] = {
			tower = tower,
			mirrors = { [mirror.unit_number] = mirror },
		}
	else
		if not storage.towers[tower.unit_number].mirrors then
			-- This shouldn't be possible, but happened so I had to add it
			storage.towers[tower.unit_number].mirrors = { [mirror.unit_number] = mirror }
		else
			storage.towers[tower.unit_number].mirrors[mirror.unit_number] = mirror
		end
	end

	local x = mirror.position.x - tower.position.x
	local y = mirror.position.y - tower.position.y

	mirror.orientation = math.atan2(y, x) * 0.15915494309 - 0.25
end

---@param inputs MirrorTower
--- run `linkMirrorToTower` if the new tower has a distance lower than the original
--- and store the tower as in range is it is
function db.link_mirror_to_tower_if_closer(inputs)
	-- Only link towers and mirrors if they have the same force
	if inputs.mirror.force.name ~= inputs.tower.force.name then
		return
	end

	-- tower is valid if not nil
	local tower = db.get_tower_for_mirror(inputs.mirror)

	if tower then
		local curDist = control_util.dist_sqr(inputs.mirror.position, tower.position)

		local newDist = control_util.dist_sqr(inputs.mirror.position, inputs.tower.position)

		if newDist < curDist and newDist < control_util.tower_capture_radius_sqr then
			db.link_mirror_to_tower(inputs)
		elseif newDist < control_util.tower_capture_radius_sqr then
			-- Tower not closer, but still in range, could be used later,
			-- add it to the mirror's list of other towers in range
			-- TODO: should use bounds, but not important

			--game.print("alternate tower in range")
			db.mark_in_range(inputs.mirror.unit_number, inputs.tower)
		end
	else
		db.link_mirror_to_tower(inputs)
	end
end

---@param tid uint
function db.notify_tower_invalid(tid)
	-- Delete a tower from the database
	--game.print("tower " .. entity.unit_number .. " destroyed")

	-- Remove every mirror -> tower relation

	for mid, mirror in pairs(storage.towers[tid].mirrors) do
		db.remove_mirror_from_tower { mid = mid }

		-- Find new targets for orphaned mirrors, if it still exists

		if db.valid_mid(mid) and storage.mirrors[mid].in_range then
			local tower = db.closest_tower {
				towers = storage.mirrors[mid].in_range,
				position = mirror.position,
				ignore = tid,
			}

			if tower then
				db.link_mirror_to_tower {
					mirror = mirror,
					tower = tower
				}
			end
		end
	end
	--end
	-- remove this tower from record
	-- Remove every tower -> mirror relation, return to consistency
	storage.towers[tid] = nil


	-- Fixes issue when last updated tower has just been destroyed
	-- "invalid key to next"

	if storage.last_updated_tower == tid then
		storage.last_updated_tower = nil
	end
	if storage.last_updated_tower_beam == tid then
		storage.last_updated_tower_beam = nil
	end

	db.on_tower_count_changed()
end

function db.on_tower_count_changed()
	storage.tower_update_count = math.ceil(table_size(storage.towers) * control_util.tower_update_fraction)
	storage.tower_beam_update_count = math.ceil(table_size(storage.towers) * control_util.beam_update_fraction)

	print(table_size(storage.towers) .. " " .. storage.tower_update_count)
end

---@param mirror LuaEntity
---@return LuaEntity?
---@nodiscard
function db.get_tower_for_mirror(mirror)
	if storage.mirrors[mirror.unit_number] then
		local tower = storage.mirrors[mirror.unit_number].tower

		if tower and tower.valid then
			return tower
		end
	end

	return nil
end

---@param mirror LuaEntity
---@return number
---@nodiscard
--- Distance from `mirror` to it's tower
function db.distance_to_tower(mirror)
	local tower = db.get_tower_for_mirror(mirror)

	if tower then
		return control_util.dist_sqr(mirror.position, tower.position)
	else
		return math.huge
	end
end

function db.mark_in_range(mid, tower)
	if storage.mirrors[mid].in_range then
		storage.mirrors[mid].in_range[tower.unit_number] = tower
	else
		storage.mirrors[mid].in_range = { [tower.unit_number] = tower }
	end
end

function db.mark_out_range(mid, tower)
	if storage.mirrors[mid] and storage.mirrors[mid].in_range then
		storage.mirrors[mid].in_range[tower.unit_number] = nil
	end
end

function db.build_trees()
	print("Generating tower relations")

	--beams.delete_all_beams()

	--control_util.consistencyCheck()

	for _, surface in pairs(game.surfaces) do
		local towers = surface.find_entities_filtered({ name = tower_names });

		if towers then
			for _, tower in pairs(towers) do
				-- Mark each tower as new
				db.on_built_entity_callback(tower)
			end
		end
	end

	db.consistency_check()
end

-- If we don't want to remove the mirror from the tower's list of mirrors
-- (tower destroyed), simply do not include the tid in calling
---@param args { tid : uint?  , mid:uint}
function db.remove_mirror_from_tower(args)
	-- unpack and verify arguments

	if not db.mid_registered(args.mid) then return end

	local mid = args.mid

	--assert(storage.mirrors[mid].tower.unit_number == tid,

	--"Mirror not connected to tower in mirrors->tower")

	-- Destroy beams if we have them
	if storage.mirrors[mid].beam then
		storage.mirrors[mid].beam.destroy()
	end

	-- Remove mirror -> tower relation
	storage.mirrors[mid].tower = nil


	if args.tid then
		-- Remove tower -> mirrors relation
		-- Skip this step for deleting a tower, when entire relation can be removed at once later
		storage.towers[args.tid].mirrors[mid] = nil


		--control_util.consistencyCheck()
	end

	--control_util.consistencyCheck()
end

function db.consistency_check()
	for tid, mirrors in pairs(storage.towers) do
		if not db.valid_tid(tid) then
			db.notify_tower_invalid(tid)

			log("NOT CONSISTENT: tower " .. tid .. " ref to invalid tower")
		else
			for _, mirror in pairs(mirrors) do
				assert(storage.mirrors[mirror.unit_number],
					"NOT CONSISTENT: tower->mirror->tower relation does not exist")

				assert(storage.mirrors[mirror.unit_number].tower.unit_number == tid,
					"NOT CONSISTENT: mirror points to multiple towers")

				assert(mirror.valid, "NOT CONSISTENT: tower->mirrors ref to invalid mirror")


				assert(storage.towers[tid].tower.unit_number == tid, "NOT CONSISTENT: tower does not point to self")
			end
		end
	end


	for mid, mirror in pairs(storage.mirrors) do
		assert(storage.mirrors[mid].mirror.unit_number == mid, "NOT CONSISTENT: mirror does not point to self")
		assert(storage.mirrors[mid].mirror.valid, "NOT CONSISTENT: mirror ref to invalid mirror")
	end
end

---@param entity LuaEntity
function db.on_built_entity_callback(entity)
	assert(entity, "Called back with nil entity")

	-- game.print("Something was built")

	if storage.mirrors == nil then
		db.build_trees()
	else
		local relevant = false

		if entity.name == control_util.heliostat_mirror then
			-- Register this mirror
			storage.mirrors[entity.unit_number] = { mirror = entity }

			-- Find a tower for this mirror
			local towers = control_util.find_towers_around_entity { entity = entity }

			local tower = db.closest_tower { towers = towers, position = entity.position }

			if tower then
				-- Pick the closest tower out of the avaliable
				db.link_mirror_to_tower {
					mirror = entity,
					tower = tower,
					all_in_range = control_util.convert_to_indexed_table(towers)
				}
			else
				-- Handle case with no towers in range
				game.get_player(1).create_local_flying_text {
					text = { control_util.mod_prefix .. "no-tower-in-range" },
					position = entity.position,
					color = nil,
					time_to_live = 60,
					speed = 1.0,
				}
			end

			relevant = true
		elseif control_util.is_tower(entity.name) then
			-- Register this tower
			storage.towers[entity.unit_number] = { tower = entity, mirrors = {} }

			--get mirrors in radius around us
			local mirrors = control_util.find_mirrors_around_entity { entity = entity }

			-- if any are closer to this tower then their current, switch their target
			for _, mirror in pairs(mirrors) do
				-- will always succed if this mirror has no tower
				db.link_mirror_to_tower_if_closer { mirror = mirror, tower = entity }
			end

			db.on_tower_count_changed()

			relevant = true
		end

		if relevant then
			-- Register for deletion events. More reliable than on_entity_died, etc, as this is always called (eventually)
			-- Downside is, it is not called immediately, so data structures may contain invalid data for short periods of time
			local id, sec_id, type = script.register_on_object_destroyed(entity)
			assert(sec_id == entity.unit_number,
				"Register on object destroyed should return the entity ID of the object")
		end
	end

	--control_util.consistencyCheck()
end

---@param eid integer?
---@return boolean
function db.on_destroyed_entity_callback(eid)
	if eid == nil then
		return false
	end

	if db.mid_registered(eid) then
		-- if this miror is connected to a tower
		if storage.mirrors[eid].tower then
			-- remove this mirror from our tower's list
			-- nd remove the reference from this mirror to the tower
			db.remove_mirror_from_tower {
				tid = storage.mirrors[eid].tower.unit_number,
				mid = eid }
		end

		--Lone mirrors have no data that needs to be cleaned up
		storage.mirrors[eid] = nil

		return true
	elseif db.tid_registered(eid) then
		db.notify_tower_invalid(eid)

		return true
	end

	--game.print("entity " .. entity.unit_number .. " destroyed")

	--control_util.consistencyCheck()

	return false
end

return db
