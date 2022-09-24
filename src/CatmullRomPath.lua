--// written by bhristt (september 22, 2022)
--// Catmull-Rom paths created by joining several splines
--// together to form one big path



--// api:
--[[

[Constructor]:

    [CatmullRomPathObject] CatmullRomPath.new([{CatmullRomSpline}?] splines, linkConnectedSplinesOnly: boolean?)
    [CatmullRomPathObject] CatmullRomPath.fromPoints([{CatmullRomPoint}] points, tension: number?)

[Properties]:

    [table] CatmullRomPath.LinkedSplines
        {
            CatmullRomSpline
        }
    [boolean] CatmullRomPath.LinkConnectedSplinesOnly

    Inherited from BaseSpline:

        [number] CatmullRomPath.LengthSegments
        [number] CatmullRomPath.Length
        [table] CatmullRomPath._LengthCache
            {
                [number]: {
                    t: number,
                    l: number,
                }
            }

[Functions]:

    [void] CatmullRomPath:LinkSpline(spline: CatmullRomSpline)
    [void] CatmullRomPath:UnlinkSpline(spline: CatmullRomSpline | number)
    [CatmullRomSpline, number] CatmullRomPath:PiecewiseTransform([number] t)

    Inherited from BaseSpline:

        [void] CatmullRomPath:_UpdateLength()
        [VectorQuantity] CatmullRomPath:Position([number] t, [boolean?] relativeToLength)
        [VectorQuantity] CatmullRomPath:Velocity([number] t, [boolean?] relativeToLength)
        [VectorQuantity] CatmullRomPath:Acceleration([number] t, [boolean?] relativeToLength)
        [number] CatmullRomPath:ArcLength([number] t)
        [number] CatmullRomPath:TransformRelativeToLength([number] t)

]]



--// modules
local BaseSpline = require(script.Parent:WaitForChild("BaseSpline"))
local CatmullRomSpline = require(script.Parent:WaitForChild("CatmullRomSpline"))



--// CatmullRomPath class
local CatmullRomPath = setmetatable({}, BaseSpline)
CatmullRomPath.__index = CatmullRomPath



--// CatmullRomPath constructor
--[[    Creates a new CatmullRomPath from given CatmullRomSplines.
        Optional linkConnectedSplinesOnly parameter to specify whether the
        CatmullRomPath can add splines that are not connected to eachother
        via 3 control points.    ]]
function CatmullRomPath.new(splines: {CatmullRomSpline.CatmullRomSpline}?, linkConnectedSplinesOnly: boolean?): CatmullRomPath

    local self = setmetatable(BaseSpline.new(), CatmullRomPath)

    self.LinkedSplines = {}
    self.LinkConnectedSplinesOnly = linkConnectedSplinesOnly or false

    if splines ~= nil then
        for i = 1, #splines do
            self:LinkSpline(splines[i])
        end
    end

    return self
end



--[[    Creates a new CatmullRomPath from the given CatmullRomPoints.
        Optional tension parameter to specify the tension of the CatmullRomSplines.
        This function forcibly sets CatmullRomPath.LinkConnectedSplinesOnly to true    ]]
function CatmullRomPath.fromPoints(points: {CatmullRomSpline.CatmullRomPoint}, tension: number?): CatmullRomPath

    if #points < 4 then
        error("Cannot create a CatmullRomPath from less than 4 control points!")
    end

    local splines: {CatmullRomSpline.CatmullRomSpline} = {}
    for i = 3, #points - 1 do
        table.insert(
            splines,
            CatmullRomSpline.new({
                points[i-2],
                points[i-1],
                points[i],
                points[i+1]
            }, tension)
        )
    end

    return CatmullRomPath.new(splines, true)
end



--// CatmullRomPath functions
--[[    Links the given spline to the last CatmullRomSpline in the CatmullRomPath.
        If CatmullRomPath.LinkConnectedSplinesOnly is enabled, this function will
        only allow links with splines that share 3 points.

        In specific, Spline1 must be {p1, p2, p3, p4} and Spline2 must be
        {p2, p3, p4, p5}    ]]
function CatmullRomPath:LinkSpline(spline: CatmullRomSpline.CatmullRomSpline)

    local linkedSplines = self.LinkedSplines
    local lastSpline = linkedSplines[#linkedSplines]
    local linkConnectedSplinesOnly = self.LinkConnectedSplinesOnly

    if lastSpline == nil then

        table.insert(linkedSplines, spline)
    elseif not linkConnectedSplinesOnly then

        table.insert(linkedSplines, spline)
    else

        local lsp = lastSpline.Points
        local csp = spline.Points
        local compatibleLink = true
        for i = 2, 4 do
            if lsp[i] ~= csp[i - 1] then
                compatibleLink = false
                break
            end
        end
        if not compatibleLink then
            error("Unable to link the given CatmullRomSpline to the CatmullRomPath!")
        end
        table.insert(linkedSplines, spline)
    end

    for i = 1, #linkedSplines do
        if #linkedSplines[i].Points < 4 then
            return
        end
    end
    self:_UpdateLength()
end



--[[	Unlinks the given spline from then CatmullRomPath. If this function is given
		a number instead of a CatmullRomSpline, this removes the spline at
		given index.    ]]
function CatmullRomPath:UnlinkSpline(spline: CatmullRomSpline.CatmullRomSpline | number)

    local linkedSplines = self.LinkedSplines
    local linkConnectedSplinesOnly = self.LinkConnectedSplinesOnly

    if typeof(spline) == "number" then

        if linkConnectedSplinesOnly then
            if spline ~= #linkedSplines then
                warn("Cannot unlink the spline; this path is meant to be connected by connected splines!\nTry setting CatmullRomSpline.LinkConnectedSplinesOnly to false!")
                return
            end
        end
        local splineRemoving = linkedSplines[spline]
        if splineRemoving == nil then
            return
        end
        table.remove(linkedSplines, spline)
    else

        local splineIndex = table.find(linkedSplines, spline)
        if splineIndex == nil then
            return
        end
        if linkConnectedSplinesOnly then
            if splineIndex ~= #linkedSplines then
                return
            end
        end
        table.remove(linkedSplines, splineIndex)
    end

    if #linkedSplines < 1 then
        return
    end

    for i = 1, #linkedSplines do
        if #linkedSplines[i].Points < 4 then
            return
        end
    end
    self:_UpdateLength()
end



function CatmullRomPath:PiecewiseTransform(t: number, relativeToLength: boolean?): (CatmullRomSpline.CatmullRomSpline, number)

    local linkedSplines = self.LinkedSplines
    local n_splines = #linkedSplines

    if n_splines == 1 then
        return linkedSplines[1], t
    elseif n_splines < 1 then
        error("Cannot return a spline at value t without splines!")
    end

    local recip_n_spline = 1 / n_splines
    local splineIndex: number
    local t_transform: number
    if t <= 0 then
        splineIndex = 1
        t_transform = t * recip_n_spline
    elseif t >= 1 then
        splineIndex = #linkedSplines
        t_transform = (t - 1) * recip_n_spline + 1
    else
        splineIndex = math.ceil(t * n_splines)
        t_transform = t * n_splines - splineIndex + 1
    end

    return linkedSplines[splineIndex], t_transform
end



function CatmullRomPath:Position(t: number, relativeToLength: boolean?): VectorQuantity

    local spline, t_transform = self:PiecewiseTransform(t)
    return spline:Position(t_transform)
end



function CatmullRomPath:Velocity(t: number, relativeToLength: boolean?): VectorQuantity

	local spline, t_transform = self:PiecewiseTransform(t)
	return spline:Velocity(t_transform)
end



function CatmullRomPath:Acceleration(t: number): VectorQuantity

	local spline, t_transform = self:PiecewiseTransform(t)
	return spline:Acceleration(t_transform)
end



function CatmullRomPath:Normal(t: number): VectorQuantity

    local spline, t_transform = self:PiecewiseTransform(t)
    return spline:Normal(t_transform)
end



function CatmullRomPath:Curvature(t: number): number

    local spline, t_transform = self:PiecewiseTransform(t)
    return spline:Curvature(t_transform)
end



--// types
type VectorQuantity = BaseSpline.VectorQuantity
export type CatmullRomPath = {

    LinkConnectedSplinesOnly: boolean,
    LinkedSplines: {CatmullRomSpline.CatmullRomSpline},
} & typeof(CatmullRomPath)



--// return
return CatmullRomPath