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

    [void] BaseSpline:_UpdateLength()
    [VectorQuantity] BaseSpline:Position([number] t)
    [VectorQuantity] BaseSpline:Velocity([number] t)
    [VectorQuantity] BaseSpline:Acceleration([number] t)
    [VectorQuantity] BaseSpline:Normal([number] t)
    [number] BaseSpline:Curvature([number] t)
    [number] BaseSpline:ArcLength([number] t)
    [number] BaseSpline:TransformRelativeToLength([number] t)
    [Tween] BaseSpline:CreateTween([Instance] object, [TweenInfo?] tweenInfo, [PropTable] props)
        type PropTable = {
            [string]: number | Vector2 | Vector3 | CFrame
        }

]]


--// constants
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
function BaseSpline:Normal(t: number): VectorQuantity

    error(PROTOTYPE_ERROR)
end



--[[    Returns the curvature of the spline at the given
        number t.    ]]
function BaseSpline:Curvature(t: number): number

    error(PROTOTYPE_ERROR)
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
function BaseSpline:ArcLength(t: number)

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
function BaseSpline:CreateTween(object: Instance, tweenInfo: TweenInfo?, props: {[string]: number | Vector2 | Vector3 | CFrame}, relativeToLength: boolean?)


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