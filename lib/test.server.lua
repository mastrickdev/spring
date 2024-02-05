local Part = workspace.Part
local Spring = require(script.Parent)

while task.wait() do

    Spring.target(Part, 0.5, 1, { Size = Vector3.new(2, 2, 2) })
    task.wait()
    Spring.target(Part, 0.5, 1, { Size = Vector3.new(5, 5, 5) })
end