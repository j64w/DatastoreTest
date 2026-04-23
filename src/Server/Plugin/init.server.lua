local toolbar = plugin:CreateToolbar("DataLib")
local button = toolbar:CreateButton("Open", "Open Data Panel", "")

local widgetInfo = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Float,
    true,
    true,
    400,
    500,
    300,
    300
)

local widget = plugin:CreateDockWidgetPluginGui("DataLibPanel", widgetInfo)
widget.Title = "DataLib Inspector"

local App = require(script.UI.App)

local app = App.new(widget)

button.Click:Connect(function()
    widget.Enabled = not widget.Enabled
end)