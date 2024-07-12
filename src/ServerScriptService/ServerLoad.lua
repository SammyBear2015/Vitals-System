local ServerStorage = game:GetService("ServerStorage")
local oxygen = require(ServerStorage:WaitForChild("OxygenServer"))

--Load all the events
for _, event in pairs(oxygen.Events) do
	if event.load then
		event.listenFor:Connect(event.callback)
	end
end

--Make the mask givers and oxygen refills work. Use CollectionService to get tags in your game, pass the result straight into the appropriate function below.
oxygen.Functions.maskGivers.callback({workspace.Giver}) --Mask givers
oxygen.Functions.oxygenGivers.callback({workspace.Tank}) --Oxygen Refills