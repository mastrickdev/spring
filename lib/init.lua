--!strict
--!native

-----------------------[[ Spring-driven motion library ]]----------------------------------------------

-- Credits for: https://github.com/Fraktality/spr
-- Visualizer: https://www.desmos.com/calculator/rzvw27ljh9

---------------------------------------------------------------------

--// Services
local RunService = game:GetService("RunService")

--// Packages
local Promise = require(script.Parent.Promise)

--// Import Types
type Promise = Promise.Promise

--// Abbreviations
local rad = math.rad
local pi = math.pi
local huge = math.huge
local exp = math.exp
local sin = math.sin
local cos = math.cos
local min = math.min
local sqrt = math.sqrt
local round = math.round
local abs = math.abs

--// Vars | Constants
local SLEEP_OFFSET_SQUARE_LIMIT = (1 / 3840) ^ 2
local SLEEP_VELOCITY_SQUARE_LIMIT = 1e-2 ^ 2
local SLEEP_ROTATION_OFFSET = rad(0.01)
local SLEEP_ROTATION_VELOCITY = rad(0.1)
local EPSILON = 1e-5
local AXIS_MATRIX_EPSILON = 1e-6

local PSEUDO_PROPERTIES = {

	Pivot = {

		class = "PVInstance",

		get = function(instance: PVInstance) return instance:GetPivot() end,
		set = function(instance: PVInstance, value: CFrame) instance:PivotTo(value) end

	} :: PropertyOverride<PVInstance, CFrame>,

	Scale = {

		class = "Model",

		get = function(instance: Model) return instance:GetScale() end,
		set = function(instance: Model, value: number) instance:ScaleTo(value) end

	} :: PropertyOverride<Model, number>
}

local renderSpringStates: {[Instance]: Properties} = {}
local otherSpringStates: {[Instance]: Properties} = {}

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

local function assertType(argumentNumber: number, expectedType: string, value: any)
    local functionName = debug.info(2, "n")

    if typeof(value) ~= expectedType then error(`bad argument #{argumentNumber} to {"Spring." .. functionName} ({expectedType} expected, got {typeof(value)})`, 3) end
end

local function getProperty(instance: Instance, propertyName: string)
	local override = PSEUDO_PROPERTIES[propertyName]

	if override and instance:IsA(override.class) then return override.get(instance) else return instance[propertyName] end
end

local function setProperty(instance: Instance, propertyName: string, value: any)
	local override = PSEUDO_PROPERTIES[propertyName]

	if override and instance:IsA(override.class) then override.set(instance, value) else instance[propertyName] = value end
end

local function inverseGammaCorrectD65(colorValue: number)

    return colorValue < 0.0404482362771076 and colorValue / 12.92 or 0.87941546140213 * (colorValue + 0.055) ^ 2.4
end

local function gammaCorrectD65(colorValue: number)

    return colorValue < 3.1306684425e-3 and 12.92 * colorValue or 1.055 * colorValue ^ (1 / 2.4) - 0.055
end

function rgbToLUV(color3: Color3)
    local r, g, b = color3.R, color3.G, color3.B

    r = inverseGammaCorrectD65(r)
    g = inverseGammaCorrectD65(g)
    b = inverseGammaCorrectD65(b)

    local x = 0.9257063972951867 * r - 0.8333736323779866 * g - 0.09209820666085898 * b
    local y = 0.2125862307855956 * r + 0.71517030370341085 * g + 0.0722004986433362 * b
    local z = 3.6590806972265883 * r + 11.4426895800574232 * g + 4.1149915024264843 * b

    local l = y > 0.008856451679035631 and 116 * y ^ (1 / 3) - 16 or 903.296296296296 * y
    local u
    local v

    if z > 1e-14 then

        u = l * x / z
        v = l * (9 * y / z - 0.46832)
    else

        u = -0.19783 * l
        v = -0.46832 * l
    end

    return { l, u, v }
end

function luvToRGB(luv: {number})
    local l = luv[1]
    if l < 0.0197955 then return Color3.new(0, 0, 0) end

    local u = luv[2] / l + 0.19783
    local v = luv[3] / l + 0.46832

    local y = (l + 16) / 116 do y = y > 0.206896551724137931 and y ^ 3 or 0.12841854934601665 * y - 0.01771290335807126 end
    local x = y * u / v
    local z = y * ((3 - 0.75 * u) / v - 5)

    local r =  7.2914074 * x - 1.5372080 * y - 0.4986286 * z
    local g = -2.1800940 * x + 1.8757561 * y + 0.0415175 * z
    local b =  0.1253477 * x - 0.2040211 * y + 1.0569959 * z

    if r < 0 and r < g and r < b then

        r, g, b = 0, g - r, b - r
    elseif g < 0 and g < b then

        r, g, b = r - g, 0, b - g
    elseif b < 0 then

        r, g, b = r - b, g - b, 0
    end

    return Color3.new( min(gammaCorrectD65(r), 1), min(gammaCorrectD65(g), 1), min(gammaCorrectD65(b), 1) )
end

local function processSprings(springStates: {[Instance]: Properties}, deltaTime: number)

	for instance, springState in springStates do

		for propertyName, spring: LinearSpring | RotationSpring | CFrameSpring in springState do

			if spring:canSleep() then

                springState[propertyName] = nil
				setProperty(instance, propertyName, spring.rawGoal)

                spring.completedCallback()
			else

				setProperty(instance, propertyName, spring:step(deltaTime))
			end
		end

		if not next(springState) then springStates[instance] = nil end
	end
end

local function angleBetween(origin: CFrame, goal: CFrame)
    local _, angle = (goal:ToObjectSpace(origin)):ToAxisAngle()

    return abs(angle)
end

local function matrixToAxis(matrix: CFrame)
    local axis, angle = matrix:ToAxisAngle()

    return axis * angle
end

local function axisToMatrix(axis: Vector3)
    local magnitude = axis.Magnitude

    if magnitude > AXIS_MATRIX_EPSILON then return CFrame.fromAxisAngle(axis.Unit, magnitude) else return CFrame.identity end
end

--// Linear Spring Class
local LinearSpring = {}
LinearSpring.__index = LinearSpring

--// Constructor
function LinearSpring.new(...)
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
function LinearSpring:setGoal<T>(value: T)

    self.rawGoal = value
    self.goal = self.typeMetadata.toIntermediate(value)
end

function LinearSpring:setDampingRatio(value: number)

    self.dampingRatio = value
end

function LinearSpring:setFrequency(value: number)

    self.frequency = value
end

function LinearSpring:setCompletedCallback(callback: () -> nil)

    self.completedCallback = callback
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
        local dampingConstant = sqrt(self.dampingRatio * self.dampingRatio - 1)

		local decayRate1 = -angularFrequency * (self.dampingRatio - dampingConstant)
		local decayRate2 = -angularFrequency * (self.dampingRatio + dampingConstant)

		local decayFactor1 = exp(decayRate1 * deltaTime)
		local decayFactor2 = exp(decayRate2 * deltaTime)

		for index = 1, #self.position do
			local offset = self.position[index] - self.goal[index]

			local coefficient2 = (self.velocity[index] - offset * decayRate1) / (2 * angularFrequency * dampingConstant)
			local coefficient1 = decayFactor1 * (offset - coefficient2)

			self.position[index] = coefficient1 + coefficient2 * decayFactor2 + self.goal[index]
			self.velocity[index] = coefficient1 * decayRate1 + coefficient2 * decayFactor2 * decayRate2

		end
    end

    return self.typeMetadata.fromIntermediate(self.position)
end

--// Rotation Spring Class
local RotationSpring = {}
RotationSpring.__index = RotationSpring

--// Constructor
function RotationSpring.new(...)
    local self = setmetatable({}, RotationSpring)

    RotationSpring.Constructor(self, ...)
    return self
end

function RotationSpring:Constructor(dampingRatio: number, frequency: number, position: CFrame, goal: CFrame)

    self.dampingRatio = dampingRatio
    self.frequency = frequency

    self.position = position
    self.goal = goal

    self.velocity = Vector3.zero
    return self
end

--// Methods
function RotationSpring:setGoal(value: CFrame)

    self.goal = value
end

function RotationSpring:setDampingRatio(value: number)

    self.dampingRatio = value
end

function RotationSpring:setFrequency(value: number)

    self.frequency = value
end

function RotationSpring:setCompletedCallback(callback: () -> nil)

    self.completedCallback = callback
end

function RotationSpring:canSleep()
    local position = angleBetween(self.position, self.goal) < SLEEP_ROTATION_OFFSET
    local velocity = self.velocity.Magnitude < SLEEP_ROTATION_VELOCITY

    return position and velocity
end

function RotationSpring:step(deltaTime: number)
    local angularFrequency = self.frequency * pi * 2

    local angularDisplacement = matrixToAxis(self.position * self.goal:Inverse())
    local decayFactor = exp(-self.dampingRatio * angularFrequency * deltaTime)

    local finalPosition: CFrame
    local finalVelocity: Vector3

    if self.dampingRatio == 1 then

        finalPosition = axisToMatrix((angularDisplacement * (1 + angularFrequency * deltaTime) + self.velocity * deltaTime) * decayFactor) * self.goal
        finalVelocity = (self.velocity * (1 - deltaTime * angularFrequency) - angularDisplacement * (deltaTime * angularFrequency * angularFrequency)) * decayFactor

    elseif self.dampingRatio < 1 then
        local dampingConstant = sqrt(1 - self.dampingRatio * self.dampingRatio)

        local cosTerm = cos(deltaTime * angularFrequency * dampingConstant)
        local sinTerm = sin(deltaTime * angularFrequency * dampingConstant)

        local velocityCoefficient = sinTerm / (angularFrequency * dampingConstant)
        local displacementCoefficient = sinTerm / dampingConstant

        finalPosition = axisToMatrix((angularDisplacement * (cosTerm + displacementCoefficient * self.dampingRatio) + self.velocity * velocityCoefficient) * decayFactor) * self.goal
        finalVelocity = (self.velocity * (cosTerm - displacementCoefficient * self.dampingRatio) - angularDisplacement * (displacementCoefficient * angularFrequency)) * decayFactor

    else
        local dampingConstant = sqrt(self.dampingRatio * self.dampingRatio - 1)

        local decayRate1 = -angularFrequency * (self.dampingRatio - dampingConstant)
        local decayRate2 = -angularFrequency * (self.dampingRatio + dampingConstant)

        local coefficient2 = (self.velocity - angularDisplacement * decayRate1) / (2  * angularFrequency * dampingConstant)
        local coefficient1 = angularDisplacement - coefficient2

        local decayFactor1 = coefficient1 * exp(decayRate1 * deltaTime)
        local decayFactor2 = coefficient2 * exp(decayRate2 * deltaTime)

        finalPosition = axisToMatrix(decayFactor1 + decayFactor2) * self.goal
        finalVelocity = decayFactor1 * decayRate1 + decayFactor2 * decayRate2

    end

    self.position = finalPosition
    self.velocity = finalVelocity

    return finalPosition
end

--// Vector3 Metadata
local vector3Metadata: TypeMetadata<Vector3> = {

    springType = LinearSpring.new,

    toIntermediate = function(value) return { value.X, value.Y, value.Z } end,
    fromIntermediate = function(value) return Vector3.new(value[1], value[2], value[3]) end
}

--// CFrame Spring Class
local CFrameSpring = {}
CFrameSpring.__index = CFrameSpring

--// Constructor
function CFrameSpring.new(...)
    local self = setmetatable({}, CFrameSpring)

    CFrameSpring.Constructor(self, ...)
    return self
end

function CFrameSpring:Constructor(dampingRatio: number, frequency: number, origin: CFrame, goal: CFrame)

    self.rawGoal = goal

    self.position = LinearSpring.new(dampingRatio, frequency, origin.Position, goal.Position, vector3Metadata)
    self.rotation = RotationSpring.new(dampingRatio, frequency, origin.Rotation, goal.Rotation)

    return self
end

--// Methods
function CFrameSpring:setGoal(value: CFrame)

    self.rawGoal = value

    self.position:setGoal(value.Position)
    self.rotation:setGoal(value.Rotation)
end

function CFrameSpring:setDampingRatio(value: number)

    self.position:setDampingRatio(value)
    self.rotation:setDampingRatio(value)
end

function CFrameSpring:setFrequency(value: number)

    self.position:setFrequency(value)
    self.rotation:setFrequency(value)
end

function CFrameSpring:setCompletedCallback(callback: () -> nil)

    self.completedCallback = callback
end

function CFrameSpring:canSleep()

    return self.position:canSleep() and self.rotation:canSleep()
end

function CFrameSpring:step(deltaTime)
    local position: Vector3 = self.position:step(deltaTime)
    local rotation: CFrame = self.rotation:step(deltaTime)

    return rotation + position
end

--// Type Metadata
local typeMetadata = {

	boolean = {

		springType = LinearSpring.new,

		toIntermediate = function(value) return { value and 1 or 0 } end,
		fromIntermediate = function(value) return value[1] >= 0.5 end

	} :: TypeMetadata<boolean>,

	number = {

		springType = LinearSpring.new,

		toIntermediate = function(value) return { value } end,
        fromIntermediate = function(value) return value[1] end

	} :: TypeMetadata<number>,

	NumberRange = {

		springType = LinearSpring.new,

		toIntermediate = function(value) return { value.Min, value.Max } end,
		fromIntermediate = function(value) return NumberRange.new(value[1], value[2]) end

	} :: TypeMetadata<NumberRange>,

	UDim = {

		springType = LinearSpring.new,

		toIntermediate = function(value) return { value.Scale, value.Offset } end,
		fromIntermediate = function(value) return UDim.new(value[1], round(value[2])) end

	} :: TypeMetadata<UDim>,

	UDim2 = {

		springType = LinearSpring.new,

		toIntermediate = function(value)
			local x = value.X
			local y = value.Y

			return { x.Scale, x.Offset, y.Scale, y.Offset }
		end,

		fromIntermediate = function(value) return UDim2.new(value[1], round(value[2]), value[3], round(value[4])) end

	} :: TypeMetadata<UDim2>,

	Vector2 = {

		springType = LinearSpring.new,

		toIntermediate = function(value) return { value.X, value.Y } end,
		fromIntermediate = function(value) return Vector2.new(value[1], value[2]) end

	} :: TypeMetadata<Vector2>,

	Vector3 = vector3Metadata,

	Color3 = {

		springType = LinearSpring.new,

		toIntermediate = rgbToLUV,
		fromIntermediate = luvToRGB

	} :: TypeMetadata<Color3>,

	ColorSequence = {

		springType = LinearSpring.new,

		toIntermediate = function(value)
			local keypoints = value.Keypoints

			local origin = rgbToLUV(keypoints[1].Value)
			local goal = rgbToLUV(keypoints[#keypoints].Value)

			return { origin[1], origin[2], origin[3], goal[1], goal[2], goal[3] }
		end,

		fromIntermediate = function(value) return ColorSequence.new( luvToRGB{value[1], value[2], value[3]}, luvToRGB{value[4], value[5], value[6]} ) end

	} :: TypeMetadata<ColorSequence>,

	CFrame = {

		springType = CFrameSpring.new,

		toIntermediate = error, -- custom (CFrameSpring)
		fromIntermediate = error -- custom (CFrameSpring)

	}
}

--// Spring
local Spring = {}

--// Functions
function Spring._cancel(instance: Instance)

    assertType(1, "Instance", instance)

    otherSpringStates[instance] = nil
    renderSpringStates[instance] = nil
end

function Spring.target(instance: Instance, dampingRatio: number, frequency: number, properties: Properties)

    assertType(1, "Instance", instance)
    assertType(2, "number", dampingRatio)

    assertType(3, "number", frequency)
    assertType(4, "table", properties)

    if dampingRatio < 0 then error(("expected damping ratio >= 0; got %.2f"):format(dampingRatio), 2) end
    if frequency < 0 then error(("expected undamped frequency >= 0; got %.2f"):format(frequency), 2) end

    return Promise.new(function(resolve, reject, onCancel)
        local springStates: {[Instance]: Properties} = if instance:IsA("Camera") then renderSpringStates else otherSpringStates
        local springState = springStates[instance]

        if not springState then springState = {}; springStates[instance] = springState end
        if onCancel(function() Spring._cancel(instance) end) then return end

        local amountOfOverwrites = 0
        local amountOfProperties = 0

        for propertyName in springState do if properties[propertyName] then amountOfOverwrites += 1 end amountOfProperties += 1 end

        for propertyName, rawGoal in properties do
            local origin = getProperty(instance, propertyName)

            if typeof(rawGoal) ~= typeof(origin) then error(`bad property {propertyName} to Spring.target ({typeof(origin)} expected, got {typeof(rawGoal)})`, 2) end
            if frequency == huge then setProperty(instance, propertyName, rawGoal); springState[propertyName] = nil continue end

            local spring = springState[propertyName]

            if not spring then
                local metadata = typeMetadata[typeof(rawGoal)]
                if not metadata then error(`unsupported type: {typeof(rawGoal)}`, 2) end

                spring = metadata.springType(dampingRatio, frequency, origin, rawGoal, metadata)
                springState[propertyName] = spring
            else

                if amountOfOverwrites == amountOfProperties then spring.completedCallback() end
            end

            spring:setCompletedCallback(resolve)
            spring:setGoal(rawGoal)

            spring:setDampingRatio(dampingRatio)
            spring:setFrequency(frequency)
        end

	    if not next(springState) then springStates[instance] = nil end
    end)
end

--// Events
RunService.PreSimulation:Connect(function(deltaTime) processSprings(otherSpringStates, deltaTime) end)
RunService.PostSimulation:Connect(function(deltaTime) processSprings(renderSpringStates, deltaTime) end)

--// Types
type LinearSpring = typeof(LinearSpring.Constructor())
type RotationSpring = typeof(RotationSpring.Constructor())
type CFrameSpring = typeof(CFrameSpring.Constructor())

type Magnitude = {number}
type TypeMetadata<T> = {

    springType: LinearSpring | RotationSpring | CFrameSpring,
    toIntermediate: (value: T) -> Magnitude,
    fromIntermediate: (magnitude: Magnitude) -> T
}

type Properties = {[string]: any}
type PropertyOverride<instance, value> = {

	class: string,

	get: (instance: instance) -> value,
	set: (instance: instance, value: value) -> nil
}

--// End
return table.freeze(Spring)