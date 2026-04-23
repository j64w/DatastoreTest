local Ignite = require(script.Parent.Parent.Packages.Ignite)
local DataBridge = require(script.Parent.Parent.Services.DataBridge)

local App = {}
App.__index = App

function App.new(widget)
    local self = setmetatable({}, App)

    self.Widget = widget
    self.Tree = Ignite.CreateTree(widget)

    self.State = {
        sessions = {},
        metrics = {}
    }

    self:Render()

    task.spawn(function()
        while true do
            self.State.sessions = DataBridge.GetSessions()
            self.State.metrics = DataBridge.GetMetrics()
            self:Render()
            task.wait(2)
        end
    end)

    return self
end

function App:Render()
    self.Tree:Render(function()
        return Ignite.createElement("Frame", {
            Size = UDim2.fromScale(1,1),
            BackgroundTransparency = 1
        }, {

            Metrics = Ignite.createElement("TextLabel", {
                Size = UDim2.fromOffset(300, 50),
                Text = "Saves: " .. (self.State.metrics.saves or 0)
                    .. " | Fails: " .. (self.State.metrics.fails or 0),
                BackgroundTransparency = 1
            }),

            List = Ignite.createElement("ScrollingFrame", {
                Position = UDim2.fromOffset(0, 60),
                Size = UDim2.fromScale(1, 1),
                CanvasSize = UDim2.fromOffset(0, #self.State.sessions * 80)
            }, self:RenderSessions())

        })
    end)
end

function App:RenderSessions()
    local children = {}

    for i, session in ipairs(self.State.sessions) do
        children["Session"..i] = Ignite.createElement("TextButton", {
            Size = UDim2.fromOffset(350, 70),
            Position = UDim2.fromOffset(0, (i-1)*80),
            Text = "UserId: " .. session.userId .. " | Dirty: " .. tostring(session.dirty),

            [Ignite.Event.MouseButton1Click] = function()
                print(session.data)
            end
        })
    end

    return children
end

return App