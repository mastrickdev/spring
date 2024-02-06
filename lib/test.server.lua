local Part = workspace.Part
local Spring = require(script.Parent)

local goal1 = Part.CFrame * CFrame.new(0, 5, 0) * CFrame.Angles(0, math.rad(35), 0)
local goal2 = Part.CFrame * CFrame.new(0, 0, 0)

while task.wait() do

    Spring.target(Part, 0.1, 4, { CFrame = goal1 }):andThen(function() print("Completed!") end)
    Spring.target(Part, 0.1, 4, { CFrame = goal2 }):andThen(function() print("Completed!") end)
end