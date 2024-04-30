-- Settings callbacks
SettingsPluginClass = {
  name = ""
}

function SettingsPluginClass:new(obj)
    local obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function SettingsPluginClass:_loadConfig()
  local parms = config.getParameter("pluginParameters")[self.name]
  if parms then
    for name, value in pairs(parms) do 
      self[name] = value
    end
  end
  self.chatConfig = config.getParameter("chatConfig")
  self.layoutWidget = "lytPluginSettings." .. self.name
end

function SettingsPluginClass:init(localeConfig)
  
end

function SettingsPluginClass:update(dt)
  
end

function SettingsPluginClass:_callback(callbackInfo, widgetName, widgetData)
  if callbackInfo and callbackInfo.pluginName and callbackInfo.pluginName == self.name and self[callbackInfo.callback] then
    widgetData["actualPluginCallback"] = nil
    self[callbackInfo.callback](self, widgetName, widgetData)
  end
end

function SettingsPluginClass:_spinner_callback(callbackInfo, direction, widgetName, widgetData)
  if callbackInfo and callbackInfo.pluginName and callbackInfo.pluginName == self.name and self[callbackInfo.callback] then
    widgetData["actualPluginCallback"] = nil
    self[callbackInfo.callback][direction](self, widgetName, widgetData)
  end
end

function SettingsPluginClass:_canvasClick(position, button, isDown)
  if self["clickCanvasCallback"] then
    self["clickCanvasCallback"](self, position, button, isDown)
  end
end

function SettingsPluginClass:onLocaleChange(localeConfig)
  
end

function SettingsPluginClass:cursorOverride(screenPosition)
  
end

function SettingsPluginClass:save(localeConfig)

end

function SettingsPluginClass:uninit()

end