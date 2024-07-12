--[[

Note keys:
1 = Ignore errors here, should be fine as it's just type highlighting for missing types which we don't need
2 = .1 of a second is plenty fast enough
]]

--This is just setting up the module.
local server = {}
server.Events = {}
server.Functions = {}

local _services = { --Store services for easier access
	players = game:GetService("Players"),
	replicatedStorage = game:GetService("ReplicatedStorage")
}

local _settings = { --General settings
	oxygenReqAlt = 50, --Altitude for oxygen
	oxygenBurnRate = 5, --Seconds per %
	damageWait = 5, --Seconds between each damage
	damageNumber = 10, --Amount of damage to inflict every damageWait while oxygen is out and is needed
	oxygenRemote = _services.replicatedStorage:WaitForChild("Oxygen") --Remote function to communicate between client and server
}

--Types
----------------------------------------------------
type PlayerData = { --A type for PlayerData which will contain all the state info for each player.
	user: Player,
	altitude: number,
	flowInfo: {
		flow: boolean,
		tankLevel: number,
		shouldDamage: boolean
	},
	hasTank:boolean
}	

----------------------------------------------------

--Utility Functions
----------------------------------------------------
local function deepCopy(obj) --A function to copy varaibles and tables so we don't end up accidentally editing other player's data or similar.
	if type(obj) ~= 'table' then return obj end

	local copy = {}

	for key, value in pairs(obj) do
		if type(value) == 'table' then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end

	return copy
end

----------------------------------------------------

--Data setup
----------------------------------------------------
local _userData = {} --store all user data here
local _userDataMetatable = {} --metatable for user data, you can just use a metatable on _userData.

function _userDataMetatable:addRecord(player:Player) --Handles creating a record for the player
	local newPlayerData:PlayerData =  { --This should be your default states
		user = player,
		altitude = 0,
		flowInfo = {
			flow = false,
			tankLevel = 0,
			shouldDamage = false
		},
		hasTank = false
	}

	table.insert(_userData, newPlayerData)
end

function _userDataMetatable:removeRecord(player:Player) --Handles removing a record for the player
	for index, entry:PlayerData in pairs(_userData) do
		if entry.user == player then
			table.remove(_userData, index)
			return true
		end
	end

	return false
end

function _userDataMetatable:findRecord(player:Player) --Handles finding a record for the player
	for index, entry:PlayerData in pairs(_userData) do
		if entry.user == player then
			return entry
		end
	end

	return nil
end

function _userDataMetatable:updateRecord(player:Player, updateObject:PlayerData) --Handles updating a record for the player
	for index, entry:PlayerData in pairs(_userData) do
		if entry.user == player then
			for index, value in pairs(updateObject) do
				entry[index] = value
			end

			return true
		end
	end

	return false
end

_userDataMetatable.__index = _userDataMetatable --Set up the metatable, use _userData.__index = _userData if just using _userData
setmetatable(_userData, _userDataMetatable)

----------------------------------------------------

--Events
----------------------------------------------------
server.Events.PlayerAdded = { --Handle player joins
	listenFor = _services.players.PlayerAdded,
	load = true,
	callback = function(player:Player)
		_userDataMetatable:addRecord(player) --Create a record
		_settings.oxygenRemote:InvokeClient(player, {["level"] = 0}) --Make sure client GUI updates.

		local function charAdded(character) --Handle character added
			local head:Part = character:FindFirstChild("Head")

			local altTask = task.spawn(function() --Altitude update loop
				while task.wait(.1) do --Note key 2
					local altitude:number = head.Position.Y --Head position, can use any part if you want but head makes the most sense.
					local recordUpdate = {
						altitude = altitude
					}

					_userDataMetatable:updateRecord(player, recordUpdate) -- Note key 1
				end
			end)

			local tankTask = task.spawn(function() --Tank level update loop
				while task.wait(_settings.oxygenBurnRate) do --Note key 2
					local existingEntry:PlayerData = _userDataMetatable:findRecord(player) --Find old data

					if existingEntry then --Make sure there's old data
						if existingEntry.flowInfo.flow and existingEntry.hasTank then --If the tank level should be decreased
							local recordUpdate = {
								flowInfo = deepCopy(existingEntry.flowInfo) --Deep copy so we don't jumble data up
							}

							recordUpdate.flowInfo.tankLevel = existingEntry.flowInfo.tankLevel - 1 or 0 --Set tank level to 1 less than it currently is, or 0 so we don't get negative tank level

							_userDataMetatable:updateRecord(player, recordUpdate) -- Note key 1
							_settings.oxygenRemote:InvokeClient(player, {["level"] = recordUpdate.flowInfo.tankLevel}) --Update client GUI
						end
					end
				end
			end)

			local damageTask = task.spawn(function() --Damage loop
				while task.wait(_settings.damageWait) do --Note key 2
					local existingEntry:PlayerData = _userDataMetatable:findRecord(player) --Get exisitng data
					local character = player.Character --Get the player's character

					if existingEntry and character then --Check if we have existing data and the player's character
						if existingEntry.flowInfo.shouldDamage then
							local humanoid = character:FindFirstChildWhichIsA("Humanoid", true) --Find the humanoid. Check recursive in case we put the humanoid within another Instance

							humanoid:TakeDamage(_settings.damageNumber) --Damage the humanoid according to the settings
						end
					end
				end
			end)

			local shouldDamageTask = task.spawn(function() --Should damage check task
				while task.wait(.1) do --Note key 2
					local existingEntry:PlayerData = _userDataMetatable:findRecord(player) --Get existing data

					if existingEntry then --If we have existing data
						local alt = existingEntry.altitude --Get the altitude
						local flowInfo = deepCopy(existingEntry.flowInfo) --Get info on the player's oxygen
						local recordUpdate = {
							flowInfo = deepCopy(existingEntry.flowInfo) --Deep copy for safety
						}

						if alt >= _settings.oxygenReqAlt and (flowInfo.flow == false or flowInfo.tankLevel <= 0 or existingEntry.hasTank == false) then --If our altitude is higher than the minimum for oxygen to be required and the player's oxygen flow is off OR the tank is empty 
							recordUpdate.flowInfo.shouldDamage = true --Set the player to be damaged
						else
							recordUpdate.flowInfo.shouldDamage = false --The player doesn't need to be damaged if the above criteria isn't met
						end

						_userDataMetatable:updateRecord(player, recordUpdate) --Note key 1, update the player's data
						_settings.oxygenRemote:InvokeClient(player, {["level"] = existingEntry.flowInfo.tankLevel}) --Update tank level
						_settings.oxygenRemote:InvokeClient(player, {["hypoxia"] = recordUpdate.flowInfo.shouldDamage}) --Update hypoxia value
					end
				end
			end)

			_settings.oxygenRemote.OnServerInvoke = function(player, dataTable) --Deal with updates from the client
				for instruction, state in pairs(dataTable) do --Loop through the dataTable, instruction is what we should update, state is what it should be updated to
					if instruction == "flow" then --Check the instruction is to change flow
						local existingEntry:PlayerData = _userDataMetatable:findRecord(player) --Find the existing data
						local recordUpdate = {
							flowInfo = deepCopy(existingEntry.flowInfo) --Deep copy for safety
						}

						recordUpdate.flowInfo.flow = state --Set flow to the state it should be
						_userDataMetatable:updateRecord(player, recordUpdate) --Note key 1, update data
					else
						print("Instruction ", instruction, " is not known. Please add another if statement to include this instruction.") --Be nice and let the developer know they haven't added something
					end
				end
			end

			player.CharacterRemoving:Connect(function() --Deal with the character removing, this can be due to the player dying or leaving
				local existingEntry:PlayerData = _userDataMetatable:findRecord(player) --Get existing data

				--Cancel all our tasks to prevent unusual stuff happening
				task.cancel(altTask)
				task.cancel(tankTask)
				task.cancel(damageTask)
				task.cancel(shouldDamageTask)

				if existingEntry then --if we have data
					local recordUpdate = {
						flowInfo = deepCopy(existingEntry.flowInfo) --Deep copy for safety
					}

					--Restore defaults
					recordUpdate.altitude = 0
					recordUpdate.hasTank = false
					recordUpdate.flowInfo.flow = false
					recordUpdate.flowInfo.tankLevel = 0
					recordUpdate.flowInfo.shouldDamage = false

					_userDataMetatable:updateRecord(player, recordUpdate) --Note key 1, update the data
				end
			end)
		end

		if player.Character then --If the player's character is already present, the character can spawn before this section of code is reached so we need to check it
			charAdded(player.Character) --Run the character added function
		end
		
		player.CharacterAdded:Connect(charAdded) --Run the character added function when the player's character spawns
	end,
}

server.Events.PlayerRemoving = { --Handle player leaving
	load = true,
	listenFor = _services.players.PlayerRemoving,
	callback = function(player:Player)
		local existingEntry:PlayerData = _userDataMetatable:findRecord(player) --Get existing data

		if existingEntry then --If we have data
			_userDataMetatable:removeRecord(player) --Delete the data
		end
	end,
}

----------------------------------------------------

--Main functions
----------------------------------------------------
server.Functions.maskGivers = { --Handle mask givers
	load = false,
	callback = function(givers)
		local function equipMask(character) --Edit this function to give the player a mask accessory
			print("This is where the mask would be equipped.")
		end

		local function handler(player) --Handle for each player
			if player then --If we have a player
				local existingEntry = _userDataMetatable:findRecord(player) --Get existing data

				if existingEntry then --If existing data
					local recordUpdate = {
						flowInfo = deepCopy(existingEntry.flowInfo) --Deep copy for safety
					}

					if existingEntry.hasTank == false then --If the player hasn't got a tank, hasTank represents if the player has a mask in this setup
						recordUpdate.hasTank = true --Update to give mask in the data

						equipMask(player.Character) --Function to equip a mask model
					else
						recordUpdate.flowInfo.tankLevel = 100 --If not, let's refill their tank
					end

					_userDataMetatable:updateRecord(player, recordUpdate) --Note key 1, save the data
				end
			end
		end

		for _, giver in pairs(givers) do --Loop through the givers
			if giver:IsA("BasePart") or giver:IsA("UnionOperation") then --Deal with parts and unions
				giver.Touched:Connect(function(hit) --When it's touched
					local player = _services.players:GetPlayerFromCharacter(hit.Parent) --Try get a player from the parent of the part that touched

					handler(player) --Handle it
					task.wait() --Wait, this could be replaced with debounce. task.wait() here just stops the script freezing the game
				end)
			elseif giver:IsA("Model") then --If it's a model
				if giver.PrimaryPart then --Check for a primary part
					giver.PrimaryPart.Touched:Connect(function(hit) --When it's touched
						local player = _services.players:GetPlayerFromCharacter(hit.Parent) --Try get a player from the parent of the part that touched

						handler(player) --Handle it
						task.wait() --Wait, this could be replaced with debounce. task.wait() here just stops the script freezing the game
					end)
				end
			end
		end
	end,
}

server.Functions.oxygenGivers = { --Handle oxygen givers
	load = false,
	callback = function(tanks)
		local function handler(player) -- Function for the handler
			if player then --If we have a player
				local existingEntry = _userDataMetatable:findRecord(player) --Get the data

				if existingEntry then --If we have existing data
					local recordUpdate = {
						flowInfo = deepCopy(existingEntry.flowInfo) --Deep copy for safety
					}

					if existingEntry.hasTank == true then --If they have a tank
						recordUpdate.flowInfo.tankLevel = 100 --Refill their tank
						_userDataMetatable:updateRecord(player, recordUpdate) --Note key 1, save the data
					end
				end
			end
		end

		for _, giver in pairs(tanks) do --Loop through the refills
			if giver:IsA("BasePart") or giver:IsA("UnionOperation") then --Deal with parts and unions
				giver.Touched:Connect(function(hit) --When it's touched
					local player = _services.players:GetPlayerFromCharacter(hit.Parent) --Try get a player from the parent of the part that touched

					handler(player) --Handle it
					task.wait() --Wait, this could be replaced with debounce. task.wait() here just stops the script freezing the game
				end)
			elseif giver:IsA("Model") then --If it's a model
				if giver.PrimaryPart then --Check for a primary part
					giver.PrimaryPart.Touched:Connect(function(hit) --When it's touched
						local player = _services.players:GetPlayerFromCharacter(hit.Parent) --Try get a player from the parent of the part that touched

						handler(player) --Handle it
						task.wait() --Wait, this could be replaced with debounce. task.wait() here just stops the script freezing the game
					end)
				end
			end
		end
	end,
}

----------------------------------------------------

return server