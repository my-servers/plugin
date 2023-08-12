local strings = require("strings")
local global = {
    allPort = {},
    checkTime = 0,
}
---@param ctx Ctx
---@return Frp
local function NewFrp(ctx)
    ---@class Frp
    local self = {
        arg    = ctx.arg,    -- 参数
        input  = ctx.input,  -- 输入
        config = ctx.config, -- 配置
        runCtx = ctx.ctx     -- 运行上下文
    }

    function checkHealthy(data)
        local handle = {}
        handle.restart = function()
            local now = os.time()
            lock()
            if now - global.checkTime < 2 then
                unlock()
                return
            end
            unlock()

            local checkResult = {}
            for k, v in pairs(data) do
                if k == "common" then
                    goto continueCheck
                end
                if v.type ~= "tcp" then
                    goto continueCheck
                end
                checkResult[v.local_port] = testPort("127.0.0.1:"..v.local_port)
                ::continueCheck::
            end
            lock()
            global.checkTime = now
            global.allPort = checkResult
            unlock()
        end
        go(handle)
    end

    function testPort(port)
        local tcp = require("tcp")
        local conn, err = tcp.open(port)
        if err then
            return false
        end
        conn:close()
        return true
    end

    function self:Update()
        local data = config.LoadIni(self.config.ConfigPath)
        local app = NewApp()
        local index = 0
        local row = 0
        local arr = {}
        i = 1
        checkHealthy(data)
        for k, v in pairs(data) do
            if k == "common" then
                goto continue
            end
            arr[i] = {
                local_port = v.local_port,
                type = v.type,
                remote_port = v.remote_port,
                name = k,
                local_ip = v.local_ip,
            }
            i = i + 1
            ::continue::
        end
        table.sort(arr,function(a, b)
            return a.type..a.local_port > b.type..b.local_port
        end)

        local add = NewIconButton().SetIcon("plus.circle")
                       .SetAction(NewAction("add", {}, "")
                                .AddInput("Name", NewInput("名字", 1))
                                .AddInput("Type",NewInput("tcp/udp",2).SetVal("tcp"))
                                .AddInput("LocalPort",NewInput("本地端口",3))
                                .AddInput("LocalIp",NewInput("本地ip",4).SetVal("127.0.0.1"))
                                .AddInput("RemotePort",NewInput("远端端口",5))
                        )
                       .SetSize(17)
        app.AddMenu(add)
        lock()--global.allPort
        for i = 1, #arr do
            local v = arr[i]
            local name = NewString(v.name).SetFontSize(10)
            local portInfo = NewString(string.format("%s/%s:%s",v.type,v.local_port,v.remote_port))
                    .SetFontSize(10).SetOpacity(0.8)
            if v.type == "tcp" and global.allPort[v.local_port] == false then
                name.SetColor("#F00")
                portInfo.SetColor("#F00")
            end
            app.AddUi(row,NewTextUi().SetText(NewText("")
                    .AddString(1,name)
                    .AddString(2,portInfo))
                    .AddAction(NewAction("delete",{id=v.name},"删除").SetCheck(true).SetIcon("trash.circle"))
                    .AddAction(NewAction("change",{id=v.name},"更新")
                        .AddInput("local_ip",NewInput("本地ip",1).SetVal(v.local_ip))
                        .AddInput("local_port",NewInput("本地端口",1).SetVal(v.local_port))
                        .AddInput("type",NewInput("类型",3).SetVal(v.type))
                        .AddInput("remote_port",NewInput("远程端口",4).SetVal(v.remote_port))))

            index = index + 1
            if index%3 == 0 then
                row = row+1
            end
        end
        unlock()

        return app.Data()
    end

    function restart()
        go({restart=function()
            os.execute(self.config.RestartScript)
        end
        })
    end

    function self:Change()
        local data = config.LoadIni(self.config.ConfigPath)
        data[self.arg.id] = {
            type = strings.trim_space(self.input.type),
            local_ip = strings.trim_space(self.input.local_ip),
            local_port = strings.trim_space(self.input.local_port),
            remote_port = strings.trim_space(self.input.remote_port),
        }
        config.SaveIni(self.config.ConfigPath,data)
        restart()
        return {}
    end

    function self:Delete()
        print("delete----",self.arg.id)
        local data = config.LoadIni(self.config.ConfigPath)
        data[self.arg.id] = nil
        config.SaveIni(self.config.ConfigPath,data)
        restart()
    end

    function self:Add()
        local data = config.LoadIni(self.config.ConfigPath)
        data[self.input.Name] = {
            type = strings.trim_space(self.input.Type),
            local_ip = strings.trim_space(self.input.LocalIp),
            local_port = strings.trim_space(self.input.LocalPort),
            remote_port = strings.trim_space(self.input.RemotePort),
        }
        config.SaveIni(self.config.ConfigPath,data)
        restart()
    end

    return self
end

function register()
    return {
    }
end

function update(ctx)
    return NewFrp(ctx):Update()
end

function change(ctx)
    print("start call change----")
    return NewFrp(ctx):Change()
end

function delete(ctx)
    return NewFrp(ctx):Delete()
end

function add(ctx)
    return NewFrp(ctx):Add()
end