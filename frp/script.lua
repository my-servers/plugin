
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

    function self:Update()
        data = config.LoadIni("/home/data/disk400G/data/server/frpc/frpc.ini")

        app = NewApp()
        index = 0
        row = 0
        arr = {}
        i = 1
        for k, v in pairs(data) do
            if k == "common" then
                goto continue
            end
            arr[i] = {
                local_port = v.local_port,
                type = v.type,
                remote_port = v.remote_port,
                name = k,
            }
            i = i + 1
            ::continue::
        end
        table.sort(arr,function(a, b)
            return a.type..a.local_port > b.type..b.local_port
        end)

        for i = 1, #arr do
            v = arr[i]
            app.AddUi(row,NewTextUi().SetText(NewText("")
                    .AddString(1,NewString(v.name).SetFontSize(10))
                    .AddString(2,NewString(string.format("%s/%s:%s",v.type,v.local_port,v.remote_port)).SetFontSize(10).SetOpacity(0.8)))
                    .AddAction(NewAction("delete",{id=v.name},"删除").SetCheck(true).SetIcon("trash.circle"))
                    .AddAction(NewAction("change",{id=v.name},"更新").AddInput("local_port",NewInput("本地端口",1).SetVal(v.local_port))
            .AddInput("type",NewInput("类型","2").SetVal(v.type))
                    .AddInput("remote_port",NewInput("远程端口",0).SetVal(v.remote_port))))

            index = index + 1
            if index%3 == 0 then
                row = row+1
            end
        end
        return app.Data()
    end


    function self:Change()
        go({restart=function()
            os.execute("docker restart frpc")
        end
        })
        end

    return self
end

function register()
    return {
    }
end

function update(ctx)
    return NewFrp(ctx).Update()
end

function change(ctx)
    return NewFrp(ctx).Change()
end