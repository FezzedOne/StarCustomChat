local shared = getmetatable('').shared

if type(shared) ~= "table" then
  shared = {}
  getmetatable('').shared = shared
end

starcustomchat = {
  utils = {},
  locale = {},
  currentLocale = "en",
  defaultLocale = "en"
}


function starcustomchat.utils.setSharedValue(key, value)
  starcustomchat.utils.resetShared()
  shared[key] = value
  starcustomchat.shared = shared
end

function starcustomchat.utils.getSharedValue(key)
  starcustomchat.utils.resetShared()
  return starcustomchat.shared[key]
end

function starcustomchat.utils.resetShared()
  if type(shared) ~= "table" then
    shared = {}
    getmetatable('').shared = shared
  end

  shared = getmetatable('').shared
  starcustomchat.shared = shared

  starcustomchat.utils.setMessageHandler = _ENV["message"] and _ENV["message"].setHandler or shared.setMessageHandler
end

function starcustomchat.utils.getLocale()
  starcustomchat.currentLocale = root.getConfiguration("scclocale") or starcustomchat.defaultLocale
  return starcustomchat.currentLocale
end

function starcustomchat.utils.clearNick(nick)
  return string.gsub(nick, "%^#?%w+;", "")
end


function starcustomchat.utils.buildLocale(fullLocalizationTable)
  starcustomchat.currentLocale = starcustomchat.utils.getLocale()
  starcustomchat.locale = copy(fullLocalizationTable)
end

function starcustomchat.utils.getTranslation(key, ...)
  local translation = starcustomchat.locale[starcustomchat.currentLocale][key] or starcustomchat.locale[starcustomchat.defaultLocale][key]
  if not translation then
    sb.logWarn("Can't get transaction of key: %s", key)
    return "???"
  else
    return ... and string.format(translation, ...) or translation
  end
end

function starcustomchat.utils.alert(key, ...)
  local text = starcustomchat.utils.getTranslation(key)
  interface.queueMessage(... and string.format(text, ...) or text)
end

function starcustomchat.utils.saveMessage(message)
  table.insert(self.sentMessages, message)

  if #self.sentMessages > self.sentMessagesLimit then
    table.remove(self.sentMessages, 1)
  end
  self.currentSentMessage = #self.sentMessages
end

function starcustomchat.utils.getCommands(allCommands, substr)
  local availableCommands = {}

  local function addCommandToList(command, data, description)
    if string.find(command, substr, nil, true) then
      table.insert(availableCommands, {
        name = command,
        description = description,
        data = data,
        color = nil
      })
    end
  end

  local function runThroughCommands(commType, commandList, prefix, level)
    for _, comm in ipairs(commandList) do
      if type(comm) == "string" then
          addCommandToList(prefix .. comm, comm, nil)
      elseif type(comm) == "table" then
        if not comm.admin or player.isAdmin() then
          local fullCommand = prefix .. comm.command
          addCommandToList(fullCommand, comm.command, comm.description)
          if string.find(substr, fullCommand .. " ", 1, true) then
            runThroughCommands(commType, comm.subcommands or {}, fullCommand .. " ", level + 1)
          end
        end
      end
    end
  end

  for commType, commlist in pairs(allCommands) do
    if (not string.find(commType, "admin") or player.isAdmin()) 
      and (commType ~= "openstarbound" or self.isOpenSB)
      and (commType ~= "starextentions" or not self.isOpenSB) then
        runThroughCommands(commType, commlist, "", 0)
    end
  end

  self.runCallbackForPlugins("addCustomCommandPreview", availableCommands, substr)

  --table.sort(availableCommands, function(a, b) return a.name:upper() < b.name:upper() end)
  return availableCommands
end

function starcustomchat.utils.sendMessageToStagehand(stagehandType, message, data, callback, errcallback)
  local totalTries = 10
  local function sendMessageToStagehand()
    if not player.id() or not world.entityPosition(player.id()) then 
      return false
    end

    for _, sh in ipairs(world.entityQuery(world.entityPosition(player.id()), 10, {
      includedTypes = {"stagehand"}
    })) do
      if world.stagehandType(sh) == stagehandType then
        promises:add(world.sendEntityMessage(sh, message, data), callback, errcallback)
        return true
      end
    end
    totalTries = totalTries - 1
    if totalTries < 0 then 
      if errcallback then errcallback("TIMEOUT") end
      return true
    end
  end

  local sendMessagePromise
  if player.id() and world.entityPosition(player.id()) then
    world.spawnStagehand(world.entityPosition(player.id()), stagehandType)

    sendMessagePromise = {
      finished = sendMessageToStagehand,
      succeeded = function() return true end
    }
  else
    sendMessagePromise = {
      finished = function() return player.id() and world.entityPosition(player.id()) end,
      succeeded = function() 
        world.spawnStagehand(world.entityPosition(player.id()), stagehandType)

        promises:add({
          finished = sendMessageToStagehand,
          succeeded = function() return true end
        })
      end
    }

  end
  promises:add(sendMessagePromise)
end

function starcustomchat.utils.sendMessageToUniqueStagehand(stagehandType, message, data, callback, errcallback)

  local ensureSending = function ()
    promises:add(world.sendEntityMessage(stagehandType, message, data), function (result)
      if callback then
        callback(result)
      end
    end, ensureSending)
  end

  local ensureSpawning = function()
    promises:add(world.findUniqueEntity(stagehandType), ensureSending, ensureSpawning)
  end

  promises:add(world.findUniqueEntity(stagehandType), ensureSending, function()
    world.spawnStagehand(world.entityPosition(player.id()), stagehandType)

    promises:add(world.findUniqueEntity(stagehandType), ensureSending, ensureSpawning)
  end)
end

function starcustomchat.utils.createStagehandWithData(stagehandType, data)
  world.spawnStagehand(world.entityPosition(player.id()), stagehandType, {data = data})
end

function starcustomchat.utils.cropMessage(text, trimLength)
  return utf8.len(text) < trimLength and text or starcustomchat.utils.utf8Substring(text, 1, trimLength) .. "..."
end

function starcustomchat.utils.utf8Substring(inputString, startPos, endPos)
    -- Check if startPos is within the valid range
  startPos = math.min(startPos, endPos)
  
  endPos = math.min(endPos, utf8.len(inputString))

  -- Calculate the byte offsets for the start and end positions
  local byteStart = utf8.offset(inputString, startPos)
  local byteEnd = utf8.offset(inputString, endPos + 1) - 1

  -- Extract the substring
  local result = string.sub(inputString, byteStart, byteEnd)

  return result
end

function starcustomchat.utils.clearPortraitFromInvisibleLayers(portrait)
  if portrait and type(portrait) == "table" then
    local filteredPortrait = {}
    for _, layer in ipairs(portrait) do 
      local imageSize = root.imageSize(layer.image)
      if layer.image and not vec2.eq(imageSize, {0, 0}) and not string.find(layer.image, "?crop.?0;0;0") and not string.match(layer.image, "^?multiply.?000;?$") then
        
        -- Set the idle emote
        if string.find(layer.image, "/emote.png") then
          layer.image = string.gsub(layer.image, ":%w+%.%d", ":idle.1")
        end

        if vec2.eq(imageSize, {85, 85}) then
          layer.image = layer.image .. "?crop;21;21;85;85"
        end
        table.insert(filteredPortrait, layer)
      end
    end

    return filteredPortrait
  end

  return portrait
end


function starcustomchat.utils.drawCircle(center, radius, color, sections)
  sections = sections or 20

  for i = 1, sections do
    local startAngle = math.pi * 2 / sections * (i-1)
    local endAngle = math.pi * 2 / sections * i
    local startLine = vec2.add(center, {radius * math.cos(startAngle), radius * math.sin(startAngle)})
    local endLine = vec2.add(center, {radius * math.cos(endAngle), radius * math.sin(endAngle)})

    if self.isOSBXSB then
      if not self.drawingCanvas then
        self.drawingCanvas = interface.bindCanvas("chatInterfaceCanvas")
      end

      self.drawingCanvas:drawLine(vec2.div(camera.worldToScreen(startLine), interface.scale()), vec2.div(camera.worldToScreen(endLine), interface.scale()), color)
    else
      interface.drawDrawable({
        line = {camera.worldToScreen(startLine), camera.worldToScreen(endLine)},
        width = 1,
        color = color
      }, {0, 0}, 1, color)
    end
  end
end

function starcustomchat.utils.safeImageSize(image)
  if image and type(image) == "string" and image ~= "" then
    local imageSize
    if pcall(function() imageSize = root.imageSize(image) end) then
      if imageSize[1] == 0 or imageSize[2] == 0 then
        return nil
      end
      return imageSize
    else
      return nil
    end
  end

  return nil
end