local M = {}

function M.TrimWhiteSpace(s)
    return s:match "^%s*(.*)":match "(.-)%s*$"
end

function M.TempFile(toWrite)
    local tmpName = os.tmpname()
    local file = io.open(tmpName, "w")
    print(tmpName)
    if (file) then
        file:write(toWrite)
        file.close()
        print("success write")
    else
        print("Failed write")
    end
end

function M.DistanceSquaredXZY_XYZ(p1, p2)
    return (p1[1] - p2[1])^2 + (p1[2] - p2[3])^2 + (p1[3] - p2[2])^2
end

function M.DistanceSquaredXYZ_XYZ(p1, p2)
    return (p1[1] - p2[1])^2 + (p1[2] - p2[2])^2 + (p1[3] - p2[3])^2
end

return M