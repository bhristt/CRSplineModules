--// written by bhristt (september 22, 2022)
--// creates catmull-rom splines



--// api:
--[[

    [Constructor]:

        [CatmullRomSplineObject] CatmullRomSpline.new(points: {CatmullRomSplinePoint}?, tension: number?)

    [Properties]:

		[table] CatmullRomSpline.Points
			{
				[1]: CatmullRomPoint?,
				[2]: CatmullRomPoint?,
				[3]: CatmullRomPoint?,
				[4]: CatmullRomPoint?
			}
		[number] CatmullRomSpline.Tension
		[string] CatmullRomSpline._PointType
		[table] CatmullRomSpline._Connections
			{
				[BasePart]: RBXScriptConnection
			}

        Inherited from BaseSpline:

            [number] CatmullRomSpline.LengthSegments
            [number] CatmullRomSpline.Length
            [table] CatmullRomSpline._LengthCache
                {
                    [number]: {
                        t: number,
                        l: number,
                    }
                }

    [Functions]:

        [void] CatmullRomSpline:ChangeTension([number] tension)
        [void] CatmullRomSpline:AddPoint([CatmullRomPoint] point, [number?] index)
        [void] CatmullRomSpline:RemovePoint([number] index)
        [boolean] CatmullRomSpline:IsValidPoint([any] point)
        [{number} | {Vector2} | {Vector3}] CatmullRomSpline:GetVectorPoints()
        [VectorQuantity, VectorQuantity, VectorQuantity, VectorQuantity] CatmullRomSpline:GetVectorConstants()

        [void] CatmullRomSpline:_ListenToPositionChange([BasePart] part)
        [void] CatmullRomSpline:_StopListeningToPositionChange([BasePart] part)

        Inherited from BaseSpline:

            [void] CatmullRomSpline:_UpdateLength()
            [VectorQuantity] CatmullRomSpline:Position([number] t)
            [VectorQuantity] CatmullRomSpline:Velocity([number] t)
            [VectorQuantity] CatmullRomSpline:Acceleration([number] t)
            [Vector3] CatmullRomSpline:Normal([number] t)
            [number] CatmullRomSpline:Curvature([number] t)
            [number] CatmullRomSpline:ArcLength([number] t)
            [number] CatmullRomSpline:TransformRelativeToLength([number] t)

]]



--// modules
local BaseSpline = require(script.Parent:WaitForChild("BaseSpline"))



--// general functions
local isCatmullRomPoint do

    local catmullRomPointTypes = {
        "number",
        "Vector2",
        "Vector3",
        "Instance",
    }

    function isCatmullRomPoint(point: any)
        local pointType = typeof(point)
        if table.find(catmullRomPointTypes, pointType) == nil then
            return false
        end
        if pointType == "Instance" then
            return point:IsA("BasePart")
        end
        return true
    end
end



--// CatmullRomSpline class
local CatmullRomSpline = setmetatable({}, BaseSpline)
CatmullRomSpline.__index = CatmullRomSpline



--// CatmullRomSpline constructor
function CatmullRomSpline.new(points: {CatmullRomPoint}?, tension: number?): CatmullRomSpline

    local self = setmetatable(BaseSpline.new(), CatmullRomSpline)

    self.Points = {}
    self.Tension = tension or 0.5

    self._PointType = "nil"
	self._Connections = {}

    if points ~= nil then
        for i = 1, #points do
            self:AddPoint(points[i])
        end
    end

    return self
end



--// CatmullRomSpline functions
--[[    Sets the tension of the CatmullRomSpline to the given number.    ]]
function CatmullRomSpline:ChangeTension(tension: number)

    if self.Tension == tension then
        return
    end
    self.Tension = tension

    if #self.Points == 4 then
        self:_UpdateLength()
    end
end



--[[    Returns whether the given point matches the type of points composing the
        CatmullRomSpline.    ]]
function CatmullRomSpline:IsValidPoint(point: any): boolean

    return isCatmullRomPoint(point) and ( self._PointType == typeof(point) )
end



--[[    Adds the given point to the CatmullRomSpline.
        Optional index parameter to specify the index of the point.
        Errors if the CatmullRomSpline already has 4 points.    ]]
function CatmullRomSpline:AddPoint(point: CatmullRomPoint, index: number?)

    local points = self.Points
    if #points == 0 then
        self._PointType = typeof(point)
    elseif #points > 3 then
        error("Cannot add more points to this CatmullRomSpline object!")
    end

    local isCRPoint = isCatmullRomPoint(point)
    local isVPoint = self:IsValidPoint(point)
    if not isCRPoint or not isVPoint then
        error("The given point is not a valid point for this CatmullRomSpline object!")
	end

	if typeof(point) == "Instance" and point:IsA("BasePart") then
		self:_ListenToPositionChange(point)
	end

    table.insert(points, index or #points + 1, point)

    if #points == 4 then
        self:_UpdateLength()
    end
end



--[[    Removes the point in the CatmullRomSpline at the given index.    ]]
function CatmullRomSpline:RemovePoint(index: number)

    local points = self.Points
    local pointRemoving = points[index]
    if pointRemoving == nil then
        return
	end

	local point = table.remove(points, index)
	if typeof(point) == "Instance" and point:IsA("BasePart") then
		self:_StopListeningToPositionChange(point)
	end

    if #points < 4 then
        self.Length = 0
        self._LengthCache = {}
    end
end



--[[    Returns a table with only vectors instead of BaseParts.    ]]
function CatmullRomSpline:GetVectorPoints(): {number} | {Vector2} | {Vector3}

    local points = self.Points
    local vectorPoints = {}
    for i, v in ipairs(points) do
		if typeof(v) == "Instance" then
			if v:IsA("BasePart")  then
				vectorPoints[i] = v.Position
			else
				error("CatmullRomSpline expected a BasePart Instance, got " .. tostring(v.ClassName) .. "!")
			end
        else
            vectorPoints[i] = v
        end
    end
    return vectorPoints
end



--[[    Returns the constants of the Catmull-Rom Spline.    ]]
function CatmullRomSpline:GetVectorConstants(): (VectorQuantity, VectorQuantity, VectorQuantity, VectorQuantity)

    local points = self:GetVectorPoints()
    local numPoints = #points
    if numPoints < 4 then
        error("CatmullRomSpline:GetVectorConstants() expected 4 points, got " .. tostring(numPoints) .. " points.")
    end

    local tension = self.Tension
    local c0 = points[2]
    local c1 = tension * (points[3] - points[1])
    local c2 = 3 * (points[3] - points[2]) - tension * (points[4] - points[2]) - 2 * tension * (points[3] - points[1])
    local c3 = -2 * (points[3] - points[2]) + tension * (points[4] - points[2]) + tension * (points[3] - points[1])
    return c0, c1, c2, c3
end



function CatmullRomSpline:_ListenToPositionChange(part: BasePart)

	local connections = self._Connections
	local positionConn = part:GetPropertyChangedSignal("Position"):Connect(function()
        if #self.Points < 4 then
            return
        end
		self:_UpdateLength()
	end)
    connections[part] = positionConn
end



function CatmullRomSpline:_StopListeningToPositionChange(part: BasePart)

	local connections = self._Connections
	local positionConn = connections[part]
	if positionConn == nil then
		return
	end
	positionConn:Disconnect()
	connections[part] = nil
end



--[[    Returns the position of the CatmullRomSpline at the given t value.
        A CatmullRomSpline is parameterized within the interval [0, 1].    ]]
function CatmullRomSpline:Position(t: number): VectorQuantity

    local c0, c1, c2, c3 = self:GetVectorConstants()
    return c0 + c1 * t + c2 * t * t + c3 * t * t * t
end



--[[    Returns the instantaneous velocity of the CatmullRomSpline at the given t value.
        A CatmullRomSpline is parameterized within the interval [0, 1].    ]]
function CatmullRomSpline:Velocity(t: number): VectorQuantity

    local _, c1, c2, c3 = self:GetVectorConstants()
    return c1 + 2 * c2 * t + 3 * c3 * t * t
end



--[[    Returns the acceleration of the CatmullRomSpline at the given t value.
        A CatmullRomSpline is parameterized within the interval [0, 1].    ]]
function CatmullRomSpline:Acceleration(t: number): VectorQuantity

    local _, _, c2, c3 = self:GetVectorConstants()
    return 2 * c2 + 6 * c3 * t
end



--// types
type VectorQuantity = BaseSpline.VectorQuantity
export type CatmullRomPoint = number | Vector2 | Vector3 | BasePart
export type CatmullRomSpline = {

    Points: {CatmullRomPoint},
    Tension: number,

    _PointType: string,
	_Connections: {
		[BasePart]: RBXScriptConnection,
	}
} & typeof(CatmullRomSpline)



--// return
return CatmullRomSpline