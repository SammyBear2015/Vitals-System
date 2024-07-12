
--Just setup the module
local client = {}
client.Events = {}
client.Functions = {}

--Store services here for easy access
local _services = {
	players = game:GetService("Players"),
	replicatedStorage = game:GetService("ReplicatedStorage")
}

--General settings
local _settings = {
	flowOnColour = Color3.fromRGB(77, 255, 0), --Colour of the button when flow is on
	flowOffColour = Color3.fromRGB(255, 0, 0), --Colour of the button when flow is off
	oxygenRemote = _services.replicatedStorage:WaitForChild("Oxygen"), --Remote function for server and client communication
	defaultFlowState = false --Deafult flow state, this isa sort of hacky implementation. I would change this in future
}

--Types
----------------------------------------------------
type PlayerData = { --Type for player data
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
local function deepCopy(obj) --Utility function to deep copy tables so we don't update other people's stuff
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

--Events
----------------------------------------------------

----------------------------------------------------

--Functions
----------------------------------------------------

client.Functions.Init = { --Initiate the GUI
	load = true,
	callback = function()
		local player = _services.players.LocalPlayer --Get the player
		local playerGui = player:WaitForChild("PlayerGui") --Wait for PlayerGui
		local oxygenGui = playerGui:WaitForChild("Oxygen") --Wait for the Oxygen GUI

		local currentHypoxiaState = deepCopy(_settings.defaultFlowState) --Copy the flow state for safety. If we don't then we may change the default state in settings

		if oxygenGui then --If we have data
			local flowButton:TextButton = oxygenGui.Frame.FlowToggle --Get the flow toggle button

			local function changeFlowButton(flowState:boolean) --Function to change the GUI based on flow change
				if flowState == true then --If flow is ON
					flowButton.TextColor3 = _settings.flowOnColour --Change the colour
				elseif flowState == false then --If flow is OFF
					flowButton.TextColor3 = _settings.flowOffColour --Change the colour				
				end
			end

			changeFlowButton(currentHypoxiaState) --Change the GUI for the default state
		
			client.Functions.RemoteHandler.callback() --Handle remote function

			flowButton.Activated:Connect(function() --Wait for the button to be activated, this works for all platforms
				currentHypoxiaState = not currentHypoxiaState --Set the state to the opposite of what it is 
				_settings.oxygenRemote:InvokeServer({["flow"] = currentHypoxiaState}) --Tell the server the flow should change
				changeFlowButton(currentHypoxiaState) --Change the button
			end)
			
			player.Character:FindFirstChildWhichIsA("Humanoid").Died:Connect(function() --Wait for the player to die
				changeFlowButton(false) --Restore default state of false
			end)
		end
	end,
}

client.Functions.RemoteHandler = { --Handle remote function
	load = false,
	callback = function()
		local player = _services.players.LocalPlayer --Get the player
		local playerGui = player:WaitForChild("PlayerGui") --Wait for PlayerGui
		local oxygenGui = playerGui:WaitForChild("Oxygen") --wait for Oxygen GUI
		
		local function toogleHypoxia(state) --Edit this function to apply your hypoxia effects
			print("Hypoxia state set to:", state)
		end
		
		local function changeOxygenLevel(level) --Function to change the oxygen level label
			local oxygenLevelLabel = oxygenGui.Frame.OxygenLevel --Find the label
			
			oxygenLevelLabel.Text = level --Change the text to the level
		end
		
		_settings.oxygenRemote.OnClientInvoke = function(dataTable) --Bind to client invoke
			if dataTable then --If there's a datatable
				for instruction, state in pairs(dataTable) do --Loop through dataTable. Instruction is what we should edit and state is what we set it to
					if instruction == "hypoxia" then --If it's hypoxia
						toogleHypoxia(state) --Set the hypoxia to this state
					elseif instruction == "level" then --If it's to update the oxygen level
						changeOxygenLevel(state) --Set it to this level.
					else
						print("Instruction ", instruction, " is not known. Please add another if statement to include this instruction.") --Be nice and let the developer know they haven't added something
					end
				end
			end
		end
	end,
}

----------------------------------------------------

return client
