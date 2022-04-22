-- Battleship mod for Minetest
-- EECS 481 Final Project
-- Authors:
--  John Stevens (jseager), Chris Kordyan (ckordyan)
-- April 19th 2022

-- Water check, checks if terrain is water -- COMPLETE
local function is_water(pos)
	local nn = minetest.get_node(pos).name
	return minetest.get_item_group(nn, "water") ~= 0
end

-- Calculate the velocity -- COMPLETE
local function get_velocity(v, yaw, y)
	local x = -math.sin(yaw)*v
	local z = math.cos(yaw)*v
	return {x=x, y=y, z=z}
end

local function get_v(v)
	return math.sqrt(v.x ^ 2 + v.z ^ 2)
end

-- Our boat entity
battleship = {
    description = "Battleship",
    physical = true,
    collisionbox = {-0.5, -0.35, -0.5, 0.5, 0.3, 0.5},
    visual = "mesh",
    mesh = "speedBoat.obj",
    -- ADD TEXTURE HERE
    textures = {"default_steel_block.png"},
     -- Attached driver (player) or nil if none
    driver = nil,
    -- Speed
	v = 0
}

-- Entering and exiting the boat on right click -- COMPLETE
function battleship.on_rightclick(self, clicker)

    -- If the person right clicks while they are driving
    if self.driver == clicker then
        -- Remove that driver from the boat
        clicker:set_detach()
        -- Set that he is attatched to boat to false
		default.player_attached[clicker:get_player_name()] = false
        -- The boat now does not have a driver
        self.driver = nil
        -- Make the person stand
        default.player_set_animation(clicker, "stand" , 20)
    -- If the person is not driving the boat
    else
        -- Make the driver the person who right clicked
        self.driver = clicker
        -- Attach the person to the boat
		clicker:set_attach(self.object, "", {x=0,y=10,z=-2}, {x=0,y=0,z=0})
        -- Set the player being attatched to true
		default.player_attached[clicker:get_player_name()] = true
        -- After pause make player sit
		minetest.after(0.25, function()
			default.player_set_animation(clicker, "sit" , 20)
		end)
        -- Set direct of boat to where you were looking
		self.object:setyaw(clicker:get_look_yaw()-math.pi/2)
    end

end

-- Setting the boat up once its placed -- NOT SURE WHAT THIS DOES
function battleship.on_activate(self, staticdata, dtime_s)
    self.object:set_armor_groups({immortal=1})
	if staticdata then
		self.v = tonumber(staticdata)
	end
end

-- Returns the speed as a string -- COMPLETE
function battleship.get_staticdata()
	return tostring(v)
end

-- How battleship interacts when punched -- COMPLETE
function battleship.on_punch(self, attacker, time_from_last_punch, tool_capabilities, direction)

    -- dismount whoever is mounted on the boat
    if self.driver then
        
        self.driver:set_detach()
        default.player_attached[self.driver:get_player_name()] = false
        self.driver = nil
    
    else
        
        battleship.schedule_removal(self)
        -- if in survival mode give some resources back, not all
        if not minetest.setting_getbool("creative_mode") then
            -- should give 4 steel blocks and 1 pine wood block
            for i = 1,4,1
            do
                attacker:get_inventory():add_item("main", "default:steelblock")
            end
            attacker:get_inventory():add_item("main", "default:pinewood")
        end
        
    end
end

-- After the boat is punched and removed help its removing time animation -- COMPLETE
function battleship.schedule_removal(self)

	minetest.after(0.25,function()
		self.object:remove()
	end)

end

-- On key press, how to move the boat
function battleship.on_step(self, dtime)
	self.v = get_v(self.object:get_velocity()) * math.sign(self.v)
	if self.driver then
		
        local control = self.driver:get_player_control()
        
        if control.down then
            self.v = self.v - dtime * 2.0
        elseif control.up then
            self.v = self.v + dtime * 2.0
        end
        if control.left then
            if self.v < -0.001 then
                self.object:set_yaw(self.object:get_yaw() - dtime * 0.9)
            else
                self.object:set_yaw(self.object:get_yaw() + dtime * 0.9)
            end
        elseif control.right then
            if self.v < -0.001 then
                self.object:set_yaw(self.object:get_yaw() + dtime * 0.9)
            else
                self.object:set_yaw(self.object:get_yaw() - dtime * 0.9)
            end
        end
		
	end
	local velo = self.object:get_velocity()
	if not self.driver and
			self.v == 0 and velo.x == 0 and velo.y == 0 and velo.z == 0 then
		self.object:set_pos(self.object:get_pos())
		return
	end
	-- We need to preserve velocity sign to properly apply drag force
	-- while moving backward
	local drag = dtime * math.sign(self.v) * (0.01 + 0.0796 * self.v * self.v)
	-- If drag is larger than velocity, then stop horizontal movement
	if math.abs(self.v) <= math.abs(drag) then
		self.v = 0
	else
		self.v = self.v - drag
	end

	local p = self.object:get_pos()
	p.y = p.y - 0.5
	local new_velo
	local new_acce = {x = 0, y = 0, z = 0}
	if not is_water(p) then
		local nodedef = minetest.registered_nodes[minetest.get_node(p).name]
		if (not nodedef) or nodedef.walkable then
			self.v = 0
			new_acce = {x = 0, y = 1, z = 0}
		else
			new_acce = {x = 0, y = -9.8, z = 0}
		end
		new_velo = get_velocity(self.v, self.object:get_yaw(),
			self.object:get_velocity().y)
		self.object:set_pos(self.object:get_pos())
	else
		p.y = p.y + 1
		if is_water(p) then
			local y = self.object:get_velocity().y
			if y >= 5 then
				y = 5
			elseif y < 0 then
				new_acce = {x = 0, y = 20, z = 0}
			else
				new_acce = {x = 0, y = 5, z = 0}
			end
			new_velo = get_velocity(self.v, self.object:get_yaw(), y)
			self.object:set_pos(self.object:get_pos())
		else
			new_acce = {x = 0, y = 0, z = 0}
			if math.abs(self.object:get_velocity().y) < 1 then
				local pos = self.object:get_pos()
				pos.y = math.floor(pos.y) + 0.5
				self.object:set_pos(pos)
				new_velo = get_velocity(self.v, self.object:get_yaw(), 0)
			else
				new_velo = get_velocity(self.v, self.object:get_yaw(),
					self.object:get_velocity().y)
				self.object:set_pos(self.object:get_pos())
			end
		end
	end
	self.object:set_velocity(new_velo)
	self.object:set_acceleration(new_acce)
end

-- Registers the entity -- COMPLETE
minetest.register_entity("battleship:battleship", battleship)

-- Registers the crafted item -- MAYBE DONE
minetest.register_craftitem("battleship:battleship", {
    description = "Battleship",
    inventory_image = "battleship.png",
    wield_image = "boats_wield.png",
    wield_scale = {x=2,y=2,z=1},
    liquids_pointable = true,

    on_place = function(itemstack, placer, pointed_thing)
		local under = pointed_thing.under
		local node = minetest.get_node(under)
		local udef = minetest.registered_nodes[node.name]
		if udef and udef.on_rightclick and
				not (placer and placer:is_player() and
				placer:get_player_control().sneak) then
			return udef.on_rightclick(under, node, placer, itemstack,
				pointed_thing) or itemstack
		end

		if pointed_thing.type ~= "node" then
			return itemstack
		end
		if not is_water(pointed_thing.under) then
			return itemstack
		end
		pointed_thing.under.y = pointed_thing.under.y + 0.5
		boat = minetest.add_entity(pointed_thing.under, "battleship:battleship")
		if boat then
			if placer then
				boat:set_yaw(placer:get_look_horizontal())
			end
			local player_name = placer and placer:get_player_name() or ""
			if not minetest.is_creative_enabled(player_name) then
				itemstack:take_item()
			end
		end
		return itemstack
	end,
})

-- Registers the crafting item recipe -- COMPLETE
minetest.register_craft({
    output = "battleship:battleship",
    recipe = {
        {"default:steelblock", "default:pine_wood", "default:pine_wood"},
		{"default:steelblock", "default:coalblock", "default:copperblock"},
		{"default:steelblock", "default:steelblock", "default:steelblock"},
    },
})

--List of things we need to do
    --[[

        register entity: not done
        register craftitem
        register craft: DONE
        on step
        on right click
        on punch: DONE ?
        get velocity
        on right click while in boat (optional)
        is water: DONE
        find textures
        create obj file
        sound function (optional)
        find sound file (optional)
        
    ]]
