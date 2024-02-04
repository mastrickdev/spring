--!strict
--!native

--// Services
local RunService = game:GetService("RunService")

--// Abbreviations
local rad = math.rad
local pi = math.pi
local exp = math.exp
local sin = math.sin
local cos = math.cos
local min = math.min
local sqrt = math.sqrt
local round = math.round

--// Vars | Constants
local SLEEP_OFFSET_SQUARE_LIMIT = (1 / 3840) ^ 2
local SLEEP_VELOCITY_SQUARE_LIMIT = 1e-2 ^ 2
local SLEEP_ROTATION_OFFSET = rad(0.01)
local SLEEP_ROTATION_VELOCITY = rad(0.1)
local EPSILON = 1e-5
local AXIS_MATRIX_EPSILON = 1e-6

--// Functions
local function getSquaredMagnitude(magnitude: Magnitude)
	local out = 0

	for _, value: number in magnitude do out += value ^ 2 end
	return out
end

local function getSquaredDistance(origin: Magnitude, goal: Magnitude)
	local out = 0

	for index, value in origin do out += (goal[index] - value) ^ 2 end
	return out
end

local function getSinRatio(deltaTime: number, root: number)

    return deltaTime + ((deltaTime ^ 2) * (root ^ 2) ^ 2 / 20 - root ^ 2) * (deltaTime ^ 3) / 6
end

--// Linear Spring Class
local LinearSpring = {}
LinearSpring.__index = LinearSpring

--// Constructor
function LinearSpring.new<T>(...)
    local self = setmetatable({}, LinearSpring)

    LinearSpring.Constructor(self, ...)
    return self
end

function LinearSpring:Constructor<T>(dampingRatio: number, frequency: number, position: T, rawGoal: T, typeMetadata: TypeMetadata<T>)

    self.linearPosition = typeMetadata.toIntermediate(position)

    self.dampingRatio = dampingRatio
    self.frequency = frequency

    self.rawGoal = rawGoal
    self.goal = self.linearPosition

    self.position = self.linearPosition
    self.velocity = table.create(#self.linearPosition, 0)

    self.typeMetadata = typeMetadata
    return self
end

--// Methods
function LinearSpring:setGoal<T>(goal: T)

    self.rawGoal = goal
    self.goal = self.typeMetadata.toIntermediate(goal)
end

function LinearSpring:setDampingRatio(dampingRatio: number)

    self.dampingRatio = dampingRatio
end

function LinearSpring:setFrequency(frequency: number)

    self.frequency = frequency
end

function LinearSpring:canSleep()

    if getSquaredMagnitude(self.velocity) > SLEEP_VELOCITY_SQUARE_LIMIT then return false end
    if getSquaredDistance(self.position, self.goal) > SLEEP_OFFSET_SQUARE_LIMIT then return false end

    return true
end

function LinearSpring:step(deltaTime: number)
    local angularFrequency = self.frequency * pi * 2

    if self.dampingRatio == 1 then
        local decayFactor = exp(-angularFrequency * deltaTime)
        local timeFactor = deltaTime * decayFactor

        local coefficients = {

            Position = decayFactor + timeFactor * angularFrequency,
            Velocity = decayFactor - timeFactor * angularFrequency,
            Frequency = timeFactor * angularFrequency * angularFrequency
        }

        for index = 1, #self.position do
            local offset = self.position[index] - self.goal[index]

            self.position[index] = offset * coefficients.Position + self.velocity[index] * timeFactor + self.goal[index]
            self.velocity[index] = self.velocity[index] * coefficients.Velocity - offset * coefficients.Frequency
        end
    elseif self.dampingRatio < 1 then
        local decayFactor = exp(-self.dampingRatio * angularFrequency * deltaTime)
        local root = sqrt(1 - self.dampingRatio * self.dampingRatio)

        local cosAngle = cos(deltaTime * angularFrequency * root)
        local sinAngle = sin(deltaTime * angularFrequency * root)

        local sinRatio
        local sinDivision

        if root > EPSILON then sinRatio = sinAngle / root else sinRatio = getSinRatio(deltaTime * angularFrequency, root) end
        if angularFrequency * root > EPSILON then sinDivision = sinAngle / (angularFrequency * root) else sinDivision = getSinRatio(deltaTime, angularFrequency * root) end

        for index = 1, #self.position do
            local offset = self.position[index] - self.goal[index]

            self.position[index] = (offset * (cosAngle + sinRatio * self.dampingRatio) + self.velocity[index] * sinDivision) * decayFactor + self.goal[index]
            self.velocity[index] = (self.velocity[index] * (cosAngle - sinRatio * self.dampingRatio) - offset * (sinRatio * angularFrequency)) * decayFactor
        end
    else

        
    end
end

--// Rotation Spring Class
local RotationSpring = {}

--// CFrame Spring Class
local CFrameSpring = {}

--// Spring
local Spring = {}

--// Types
type LinearSpring = typeof(LinearSpring.Constructor())
type RotationSpring = typeof(RotationSpring.new())
type CFrameSpring = typeof(CFrameSpring.new())

type Magnitude = { number }
type TypeMetadata<T> = {

    springType: LinearSpring | RotationSpring | CFrameSpring,
    toIntermediate: (value: T) -> Magnitude,
    fromIntermediate: (magnitude: Magnitude) -> T
}

--// End
return table.freeze(Spring)