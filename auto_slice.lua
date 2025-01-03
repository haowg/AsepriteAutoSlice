--------------------------------------------------------------------------------
-- auto_detect_split_maxsize_centered.lua
-- Description:
-- 1. Detect all non-transparent blocks (including corner connections) through 8-direction flood fill and obtain the bounding rectangles.
-- 2. Create a new Sprite with canvas size equal to the maximum bounding rectangle's width and height.
-- 3. Place each detected block as a new frame centered on the new canvas.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 1. Preliminary check: Ensure there is an active Sprite, Layer, and Cel
--------------------------------------------------------------------------------
local srcSprite = app.activeSprite
if not srcSprite then
  return app.alert("No active Sprite detected. Please open the Spritesheet to be processed.")
end

local srcLayer = srcSprite.layers[1]
if not srcLayer then
  return app.alert("No valid layer detected.")
end

local srcCel = srcLayer.cels[1]
if not srcCel then
  return app.alert("No valid Cel in this layer.")
end

local srcImg = srcCel.image
local w, h = srcImg.width, srcImg.height
local colorMode = srcSprite.colorMode

--------------------------------------------------------------------------------
-- 2. Utility functions
--------------------------------------------------------------------------------

-- Check if a pixel is fully transparent
local function isTransparent(img, x, y)
  return img:getPixel(x, y) == 0
end

-- Convert (x, y) to index for marking access in a one-dimensional array
local function index(x, y, width)
  return y * width + x
end

--------------------------------------------------------------------------------
-- 3. Find the bounding rectangles of all non-transparent "blocks" using 8-direction flood fill
--------------------------------------------------------------------------------
local visited = {}
for i = 0, w * h - 1 do
  visited[i] = false
end

-- Use BFS to search for non-transparent regions and return the bounding rectangle of the region
-- Here we use 8 directions (including diagonals)
local function floodFill(startX, startY)
  local queue = {}
  table.insert(queue, {x = startX, y = startY})
  visited[index(startX, startY, w)] = true

  local minX, minY = startX, startY
  local maxX, maxY = startX, startY

  while #queue > 0 do
    local current = table.remove(queue, 1)
    local cx, cy = current.x, current.y

    -- Update bounding rectangle
    if cx < minX then minX = cx end
    if cy < minY then minY = cy end
    if cx > maxX then maxX = cx end
    if cy > maxY then maxY = cy end

    -- 8 directions
    local directions = {
      { 1,  0}, {-1,  0}, { 0,  1}, { 0, -1},
      { 1,  1}, { 1, -1}, {-1,  1}, {-1, -1}
    }

    for _, dir in ipairs(directions) do
      local nx, ny = cx + dir[1], cy + dir[2]
      if nx >= 0 and nx < w and ny >= 0 and ny < h then
        local idx = index(nx, ny, w)
        if (not visited[idx]) and (not isTransparent(srcImg, nx, ny)) then
          visited[idx] = true
          table.insert(queue, {x = nx, y = ny})
        end
      end
    end
  end

  return {x1 = minX, y1 = minY, x2 = maxX, y2 = maxY}
end

-- Collect bounding rectangles of all non-transparent blocks
local regions = {}
for y = 0, h - 1 do
  for x = 0, w - 1 do
    local idx = index(x, y, w)
    if (not isTransparent(srcImg, x, y)) and (not visited[idx]) then
      local rect = floodFill(x, y)
      table.insert(regions, rect)
    end
  end
end

if #regions == 0 then
  return app.alert("No non-transparent regions detected. Script ends.")
end

--------------------------------------------------------------------------------
-- 4. Find the maximum bounding rectangle width and height to determine the new Sprite size
--------------------------------------------------------------------------------
local maxWidth, maxHeight = 0, 0
for _, rect in ipairs(regions) do
  local regionW = rect.x2 - rect.x1 + 1
  local regionH = rect.y2 - rect.y1 + 1
  if regionW > maxWidth then maxWidth = regionW end
  if regionH > maxHeight then maxHeight = regionH end
end

--------------------------------------------------------------------------------
-- 5. Create a new Sprite with canvas size (maxWidth x maxHeight) and the same color mode as the original
--------------------------------------------------------------------------------
local dstSprite = Sprite(maxWidth, maxHeight, colorMode)
dstSprite.filename = ""  -- Not saved yet
local dstLayer = dstSprite.layers[1]

-- Create enough frames
local framesNeeded = #regions
for i = 2, framesNeeded do
  dstSprite:newFrame()
end

--------------------------------------------------------------------------------
-- 6. Copy each detected block to the new Sprite
--    Center the image within the range (0, 0) ~ (maxWidth, maxHeight)
--------------------------------------------------------------------------------
for i, rect in ipairs(regions) do
  local frameObj = dstSprite.frames[i]

  -- If there is no Cel in this frame, use the newly created Cel
  local newCel = dstLayer:cel(frameObj)
  if not newCel then
    newCel = dstSprite.cels[#dstSprite.cels]
  end

  local regionW = rect.x2 - rect.x1 + 1
  local regionH = rect.y2 - rect.y1 + 1

  -- Extract pixels from the region
  local subImg = Image(regionW, regionH, colorMode)
  for yy = rect.y1, rect.y2 do
    for xx = rect.x1, rect.x2 do
      local pixelVal = srcImg:getPixel(xx, yy)
      subImg:putPixel(xx - rect.x1, yy - rect.y1, pixelVal)
    end
  end

  -- Center the sub-image in the new Sprite
  local offsetX = math.floor((maxWidth - regionW) / 2)
  local offsetY = math.floor((maxHeight - regionH) / 2)

  newCel.image = subImg
  newCel.position = Point(offsetX, offsetY)
end

app.refresh()
app.alert("Script execution completed!\n" ..
          "Detected " .. #regions .. " regions, " ..
          "and generated the corresponding number of frames in the new Sprite.")

