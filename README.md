# Spring

Spring is an animation library for Roblox, which uses the method of harmonic response to create smooth and natural movements. Spring allows you to animate any property of any instance, using only two variables: **damping ratio** and **frequency**.

## Wally Installation

To install with wally, insert it inside wally.toml [dependencies]

```toml
spring = "mastrickdev/spring@0.2.3"
```

## Usability

To use Spring, you need to first load the library:

```lua
local Spring = require(...)
```

Then, you can create an animation using the method `Spring.target`, which takes four arguments:

- `instance`: the instance that you want to animate, such as a `BasePart`, a `GuiObject`, or a `Camera`.
- `dampingRatio`: a number between 0 and 1 that describes the shape of the animation. The lower the value, the more the animation will oscillate and take longer to reach the target. The higher the value, the faster and smoother the animation will be. The recommended value is 1, which is called **critical damping**.
- `frequency`: a positive number that describes the speed of the animation. The higher the value, the faster the animation will be. The recommended value is 1, which is called **natural frequency**.
- `properties`: a table that contains the properties that you want to animate and the target values. For example, if you want to animate the position and orientation of a `BasePart`, you can use something like:

```lua
Spring.target(basePart, 0.75, 1, {  CFrame = CFrame.new(20, 20, 20) })
```

The method `Spring.target` returns a `Promise`, which is an object that represents an asynchronous operation. You can use the method `:andThen` to execute a function when the animation finishes, or the method `:cancel` to cancel the animation and the `Promise`. For example, if you want to print a message when the animation is over, you can do something like:

```lua
Spring.target(basePart, 0.75, 1, { CFrame = CFrame.new(20, 20, 20) })
    :andThen(function() print("Animation completed!") end)
```

If you want to cancel the animation before it finishes, you can do something like:

```lua
local promise = Spring.target(basePart, 0.75, 1, { CFrame = CFrame.new(20, 20, 20) })

-- Some time later...
promise:cancel()
```

## Fundamental concepts

Damping ratio and frequency are the two properties that describe the motion of a spring.

- **Damping ratio** describes the shape of the animation. The damping ratio is the ratio between the actual damping of the spring and the critical damping, which is the minimum required to avoid oscillations. The damping ratio can be classified into three types:

    - **Underdamped** (damping ratio < 1): the animation exceeds the target value and converges to it with decreasing oscillations. This type of animation is recommended for situations that need more dynamism and energy.
    - **Critically damped** (damping ratio = 1): the animation converges to the target value without exceeding it. This type of animation is recommended for situations that need more neutrality and smoothness.
    - **Overdamped** (damping ratio > 1): the animation converges to the target value without exceeding it, but more slowly. This type of animation is recommended for situations that need more calm and control.

- **Frequency** describes the speed of the animation. The frequency is the natural frequency of the spring, which is the rate of oscillation of the spring when there is no damping. The frequency can be adjusted to change the time that the animation takes to reach the target value.

You can visualize the effect of the damping ratio and the frequency on the animation using this [viewer](https://www.desmos.com/calculator/rzvw27ljh9).

## Supported types

Spring supports a subset of the native Roblox and Luau types for which interpolation makes sense. Currently, these are:

- `boolean`: a logical value that can be `true` or `false`.
- `CFrame`: a 4x4 matrix that represents the position and orientation of an object in 3D space.
- `Color3`: a color represented by three components: red, green, and blue.
- `ColorSequence`: a sequence of colors that can be used to interpolate between them.
- `number`: a numerical value that can be integer or decimal.
- `NumberRange`: a range of numbers that can be used to generate random numbers within it.
- `UDim`: a relative dimension that can be used to position and size objects in the user interface.
- `UDim2`: a relative dimension in two dimensions that can be used to position and size objects in the user interface.
- `Vector2`: a two-dimensional vector that represents a direction or a position in the 2D plane.
- `Vector3`: a three-dimensional vector that represents a direction or a position in the 3D space.
