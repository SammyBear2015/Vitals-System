local ReplicatedStorage = game:GetService("ReplicatedStorage")
local oxygen = require(ReplicatedStorage:WaitForChild("OxygenClient"))

--Load all the client functions
for _, func in pairs(oxygen.Functions) do
	if func.load then
		func.callback()
	end
end