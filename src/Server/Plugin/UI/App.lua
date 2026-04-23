local Ignite = require(script.Parent.Ignite)
local DataBridge = require(script.Parent.Parent.Services.DataBridge)

local App = {}
App.__index = App

print(Ignite)
for k,v in pairs(Ignite) do
    print(k,v)
end

function App.new(widget)
    local self = setmetatable({}, App)

    self.Widget = widget

    self.State = {
        sessions = {},
        metrics = {}
    }

    self.Root = Instance.new("Frame")
    self.Root.Size = UDim2.fromScale(1,1)
    self.Root.BackgroundTransparency = 1
    self.Root.Parent = widget

    self:Render()

    task.spawn(function()
        while true do
            local ok1, sessions = pcall(DataBridge.GetSessions)
            local ok2, metrics = pcall(DataBridge.GetMetrics)

            if ok1 then self.State.sessions = sessions or {} end
            if ok2 then self.State.metrics = metrics or {} end

            self:Render()
            task.wait(2)
        end
    end)

    return self
end

function App:Render()
    local children = {}

    print("Ignite.new:", Ignite.new)
    print("Ignite.mount:", Ignite.mount)

    local metricsText = "Saves: "
        .. tostring(self.State.metrics.saves or 0)
        .. " | Fails: "
        .. tostring(self.State.metrics.fails or 0)

    children.Metrics = Ignite.new("TextLabel", {
        Size = UDim2.fromOffset(300, 40),
        Text = metricsText,
        BackgroundTransparency = 1
    })

    local listChildren = {}

    local i = 0
    for userId, session in pairs(self.State.sessions) do
        i += 1

    listChildren["S"..userId] = Ignite.new("TextButton", {
        Size = UDim2.fromOffset(350, 60),
        Position = UDim2.fromOffset(0, (i-1)*70),
        Text = "UserId: "..userId.." | Dirty: "..tostring(session.dirty),

        MouseButton1Click = function()
            print(session.data)
        end
    })
    end

    children.List = Ignite.new("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 50),
        Size = UDim2.fromScale(1,1),
        CanvasSize = UDim2.fromOffset(0, i * 70)
    }, listChildren)

    Ignite.mount(
        Ignite.new("Frame", {
            Size = UDim2.fromScale(1,1),
            BackgroundTransparency = 1
        }, children),
        self.Root
    )
end

return App