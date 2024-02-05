return function()
    local Spring = require(script.Parent)

    describe("Should start a spring animation on a given instance", function()

        it("Should return a promise object", function()
            local basePart = Instance.new("Part")
            --local promiseReturned = Spring.target(basePart, 0.1, 4, { Transparency = 1 })

            --expect(promiseReturned).to.be.a("table")
        end)

        describe("basePart", function()
            local basePart = workspace.Part

            it("basePart.Transparency", function()

                Spring.target(basePart, 0.1, 2, { Transparency = 1, Size = Vector3.new(20, 20, 20) }):andThen(function() print("Finished!") end)
            end)
        end)
    end)
end