--// written by bhrist (september 23, 2022)
--// the BaseSpline class which contains the setup for
--// the Spline objects we're about to organize B)


--// api:
--[[

[Constructors]:

    [BaseSplineObject] BaseSpline.new()

[Properties]:

    [number] BaseSpline.LengthSegments
    [number] BaseSpline.Length
    [table] BaseSpline._LengthCache
        {
            [number]: {
                t: number,
                l: number,
            }
        }

[Functions]:

    [VectorQuantity] BaseSpline:Position([number] t)
    [VectorQuantity] BaseSpline:Velocity([number] t)
    [VectorQuantity] BaseSpline:Acceleration([number] t)
    [VectorQuantity] BaseSpline:Normal([number] t)
    [number] BaseSpline:Curvature([number] t)
    [number] BaseSpline:ArcLength([number] t)
    [number] BaseSpline:TransformRelativeToLength([number] t)
    [Tween] BaseSpline:CreateTween([Instance] object, [TweenInfo?] tweenInfo, [PropTable] props, [boolean?] relativeToLength)
        type PropTable = {
            [string]: number | Vector2 | Vector3 | CFrame
        }
    [void] BaseSpline:_UpdateLength()
    [NumberValue] BaseSpline:_CreateProxyTweener([any] object, [{string}] props, [boolean?] relativeToLength)

]]


--// constants
local DEFAULT_TWEEN_TIME = 10
local DEFAULT_TWEEN_EASING_STYLE = Enum.EasingStyle.Sine
local DEFAULT_TWEEN_EASING_DIRECTION = Enum.EasingDirection.Out
local DEFAULT_TWEEN_REPEAT_COUNT = 0
local DEFAULT_TWEEN_REVERSES = false
local DEFAULT_TWEEN_DELAY = 0


local PROTOTYPE_ERROR = "This is a prototype function, it should never be called from the BaseSpline!"



--// BaseSpline class
local BaseSpline = {}
BaseSpline.__index = BaseSpline



--// BaseSpline constructor
function BaseSpline.new()

    local self = setmetatable({}, BaseSpline)

    self.LengthSegments = 1000
    self.Length = 0

    self._LengthCache = {}

    return self
end



--// BaseSpline functions
--[[    Returns the position of the spline at the given
        number t.    ]]
function BaseSpline:Position(t: number): VectorQuantity

    error(PROTOTYPE_ERROR)
end



--[[    Returns the velocity of the spline at the given
        number t.    ]]
function BaseSpline:Velocity(t: number): VectorQuantity

    error(PROTOTYPE_ERROR)
end



--[[    Returns the acceleration of the spline at the given
        number t.    ]]
function BaseSpline:Acceleration(t: number): VectorQuantity

    error(PROTOTYPE_ERROR)
end



--[[    Returns the normal Vector3 of a Vector3 constructed
        spline object at the given number t.    ]]
function BaseSpline:Normal(t: number): Vector3

    local dTdt = self:Acceleration(t)
    if typeof(dTdt) ~= "Vector3" then
        error("BaseSpline:Normal() only works with Vector3 constructed splines!")
    end
    return dTdt.Unit
end



--[[    Returns the curvature of the spline at the given
        number t.    ]]
function BaseSpline:Curvature(t: number): number

    local drdt = self:Velocity(t)    --// dr/dt
    local d2rdt2 = self:Acceleration(t)    --// d^2r/dt^2

    if typeof(drdt) ~= "Vector3" or typeof(d2rdt2) ~= "Vector3" then
        error("BaseSpline:Curvature() only works with Vector3 constructed splines!")
    end

    local drdtXd2rdt2 = drdt:Cross(d2rdt2)    --// dr/dt cross d^2r/dt^2
    local drdtXd2rdt2m = drdtXd2rdt2.Magnitude
    local drdtm = drdt.Magnitude

    return drdtXd2rdt2m / (drdtm ^ 3)
end



--[[    Updates the length of the spline and updates the
        BaseSpline._LengthCache table    ]]
function BaseSpline:_UpdateLength()

    local lengthCache = {}
    local lengthSegments = self.LengthSegments
    local t_int = 1 / (lengthSegments + 1)
    local l = 0

    for i = 0, lengthSegments + 1 do

        local p0 = self:Position(i * t_int)
        local p1 = self:Position((i + 1) * t_int)
        local displacement = (p1 - p0)

        table.insert(lengthCache, {t = t_int * i, l = l})

        if i == lengthSegments + 1 then
            break
        end

        l += ( type(displacement) == "number" )
            and math.abs(p1 - p0)
            or (p1 - p0).Magnitude
    end

    self.Length = l
    self._LengthCache = lengthCache
end



--[[    Returns the arc length of the spline at the given
        number t. This is only an approximation, not the
        exact length of the spline.    ]]
function BaseSpline:ArcLength(t: number): number

    local lengthCache = self._LengthCache
    if #lengthCache == 0 then
        return 0
    end

    local c0: {t: number, l: number}
    local c1: {t: number, l: number}

    if t < 0 then

        c0 = lengthCache[1]
        c1 = lengthCache[2]
    elseif t > 1 then

        c0 = lengthCache[#lengthCache-1]
        c1 = lengthCache[#lengthCache]
    else

        for i = 1, #lengthCache - 1 do
            local cc0, cc1 = lengthCache[i], lengthCache[i + 1]
            if cc0.t <= t and t <= cc1.t then
                c0 = cc0
                c1 = cc1
                break
            end
        end
    end

    return c0.l + (c1.l - c0.l) * ((t - c0.t) / (c1.t - c0.t))
end



--[[    Transforms the given t into a number in [0, 1] that
        relates to the length of the spline.    ]]
function BaseSpline:TransformRelativeToLength(t: number): number

    local lengthCache = self._LengthCache
    if #lengthCache == 0 then
        return 0
    end

    local c0: {t: number, l: number}
    local c1: {t: number, l: number}
    local tLength = self.Length * t

    if tLength < 0 then

        c0 = lengthCache[0]
        c1 = lengthCache[1]
    elseif tLength > lengthCache[#lengthCache].l then

        c0 = lengthCache[#lengthCache-1]
        c1 = lengthCache[#lengthCache]
    else

        for i = 1, #lengthCache - 1 do
            local cc0, cc1 = lengthCache[i], lengthCache[i + 1]
            if cc0.l <= tLength and tLength <= cc1.l then
                c0 = cc0
                c1 = cc1
                break
            end
        end
    end

    return c0.t + (c1.t - c0.t) * ((tLength - c0.l) / (c1.l - c0.l))
end



--[[    Creates a Tween object that can be played to control
        something along the spline    ]]
do

    local tweenService = game:GetService("TweenService")

    --// returns the length of the given dictionary
    local function dictLen(
        dict: {[string]: any}
    ): number

        local n = 0
        for _, _ in pairs(dict) do
            n += 1
        end
        return n
    end

    --// returns whether the given value is a numeric value
    --// numeric values are values that can be linearly interpolated
    local function isNumericValue(n: any): boolean

        return
            typeof(n) == "number"
            or typeof(n) == "Vector2"
            or typeof(n) == "Vector3"
            or typeof(n) == "CFrame"
    end

    --// returns the default properties of the instance specified
    --// in the given property tables
    local function objectDefaultNumericProperties(
        object: any,
        props: {string}
    ): {[string]: VectorQuantity}

        local defaultProperties = {}
        for _, prop in pairs(props) do
            local success, default = pcall(function()
                return object[prop]
            end)
            if success and isNumericValue(default) then
                defaultProperties[prop] = default
            end
        end
        return defaultProperties
    end

    function BaseSpline:_CreateProxyTweener(
        object: any,
        props: {string},
        relativeToLength: boolean?
    )

        local numberValue = Instance.new("NumberValue")
        numberValue:GetPropertyChangedSignal("Value"):Connect(function()

            local t = numberValue.Value
            for i = 1, #props do

                local propIndex = props[i]
                local propType = typeof(object[propIndex])
                local t_transform = relativeToLength and self:TransformRelativeToLength(t) or t

                if propType == "number" or propType == "Vector2" or propType == "Vector3" then

                    object[propIndex] = self:Position(t_transform)
                elseif propType == "CFrame" then

                    local position = self:Position(t_transform)
                    local direction = self:Velocity(t_transform).Unit
                    local normal = self:Normal(t_transform)
                    object[propIndex] = CFrame.lookAt(position, position + direction, normal)
                end
            end
        end)

        return numberValue
    end

    --// creates a tween object for the given object
    --// playing the tween will make the object traverse
    --// through the spline
    function BaseSpline:CreateTween(
        object: any,
        tweenInfo: TweenInfo?,
        props: {string},
        relativeToLength: boolean?
    ): Tween

        local defaultNumericProperties = objectDefaultNumericProperties(object, props)

        if dictLen(defaultNumericProperties) == 0 then
            error("Cannot find the given properties inside the given object!")
        end

        local processedTweenInfo = tweenInfo or TweenInfo.new(
            DEFAULT_TWEEN_TIME,
            DEFAULT_TWEEN_EASING_STYLE,
            DEFAULT_TWEEN_EASING_DIRECTION,
            DEFAULT_TWEEN_REPEAT_COUNT,
            DEFAULT_TWEEN_REVERSES,
            DEFAULT_TWEEN_DELAY
        )
        local proxyTweener = self:_CreateProxyTweener(object, props, relativeToLength)
        local tween = tweenService:Create(proxyTweener, processedTweenInfo, {Value = 1})
        return tween
    end
end



--// types
export type VectorQuantity = number | Vector2 | Vector3
export type BaseSpline = {

    LengthSegments: number,
    Length: number,

    _LengthCache: {
        [number]: {
            t: number,
            l: number,
        }
    }
} & typeof(BaseSpline)



--// return
return BaseSpline