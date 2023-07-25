
local global = {
    api = {
        containersList = "/containers/json?all=1",
        containersStatsFormat = "/containers/%s/stats?stream=false&one-shot=true",
        stopContainer = "/containers/%s/stop",
        restartContainer = "/containers/%s/restart",
        startContainer = "/containers/%s/start",
    },
    containerState = {},
    updateStateTs = 0,
}
---@param ctx Ctx
---@return Docker
function NewDocker(ctx)
    ---@class Docker
    local self = {
        arg = ctx.arg,
        input = ctx.input,
        config = ctx.config,
        runCtx = ctx.ctx,
    }


    local function fetch_all(containers)
        if os.time() - global.updateStateTs <= 3 then
            return
        end
        print("update---------")
        global.updateStateTs = os.time()
        local coroutines = {}
        local result = {}
        for i = 1, #containers do
            coroutines[i] = function()
                stats = getStats(containers[i])
                global.containerState[containers[i].Id] = stats
            end
        end
        go(coroutines)
        return result
    end

    function getStats(c)
        local data = net.Get(string.format(self.config.HostPort..global.api.containersStatsFormat,c.Id),{},{})
        return data.data
    end

    ---@param app AppUI
    function getContainersStats(app)
        local data = net.Get(self.config.HostPort..global.api.containersList,{},{})
        index = 0
        text = NewText("leading").AddString(1,NewString("状态").SetFontSize(10).SetOpacity(0.5))
        app.AddUi(index,NewTextUi().SetText(text))
        text = NewText("leading").AddString(1,NewString("名字").SetFontSize(10).SetOpacity(0.5))
        app.AddUi(index,NewTextUi().SetText(text))
        index = 1
        for i = 1, #data.data do
            c = data.data[i]
            color = "#000"
            if c.State ~= "running" then
                color = "#F00"
            end

            state = NewString(c.State).SetFontSize(12).SetColor(color)
            status = NewString(c.Status).SetFontSize(8).SetColor(color).SetOpacity(0.5)
            app.AddUi(index,NewTextUi().SetText(NewText("").AddString(1,state).AddString(2,status)))
            name = NewString(string.sub(c.Names[1],2,string.len(c.Names[1])))
                    .SetFontSize(12)
                    .SetColor(color)
            image = NewString(c.Image).SetFontSize(8).SetOpacity(0.5)
            nameText = NewText("").AddString(1,name).AddString(2,image)
            nameAndOp = NewTextUi()
                    .SetText(nameText)
                    .AddAction(NewAction("restart",{id=c.Id},"重启"))
            if c.State ~= "running" then
                nameAndOp.AddAction(NewAction("start",{id=c.Id},"启动"))
            else
                nameAndOp.AddAction(NewAction("stop",{id=c.Id},"停止"))
            end
            app.AddUi(index,nameAndOp)
            if i%1 == 0 then
                index = index+1
            end
        end
    end

    function self:Stop()
        net.Post(string.format(self.config.HostPort..global.api.stopContainer,self.arg.id),{},{})
    end

    function self:Restart()
        net.Post(string.format(self.config.HostPort..global.api.restartContainer,self.arg.id),{},{})
    end

    function self:Start()
        net.Post(string.format(self.config.HostPort..global.api.startContainer,self.arg.id),{},{})
    end




    function self:GetUi()

        app = NewApp()
        getContainersStats(app)
        return app.Data()
    end


    return self
end


function register()
    return {
    }
end


function update(ctx)
    return NewDocker(ctx):GetUi()
end


function stop(ctx)
    return NewDocker(ctx):Stop()
end

function restart(ctx)
    return NewDocker(ctx):Restart()
end

function start(ctx)
    return NewDocker(ctx):Start()
end