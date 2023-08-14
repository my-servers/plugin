local http = require("http")
local json = require("json")
local httpClient = http.client({
    timeout = 2, -- 超时1s
})
local global = {
    urlFormat = "%s/transmission/rpc",
    getListArg = {
        arguments = {
            fields = {
                "id",
                "name",
                "rateDownload",
                "rateUpload",
                "totalSize",
                "status",
                "percentDone",
                "labels",
                "percentComplete"
            },
            format = "json"
        },
        method = "torrent-get"
    },
    sessionId = "",
    sessionKey = "X-Transmission-Session-Id",
    statusName = {
        [0] = "暂停",
        [1] = "等待检查",
        [2] = "检查中",
        [3] = "等待下载",
        [4] = "下载中",
        [5] = "等待做种",
        [6] = "做种中",
    }
}

function getState(status)

end


function doRequest(method,url,data)
    req = http.request(method,url,json.encode(data))
    local stateRsp,err = httpClient:do_request(req)
    if err then
        error(err)
    end
    if stateRsp.code == 409 then
        httpClient = http.client({
            timeout = 2, -- 超时1s
            headers = {
                [global.sessionKey] = stateRsp.headers[global.sessionKey]
            }
        })
        stateRsp,err = httpClient:do_request(req)
    end
    if err then
        error(err)
    end
    return stateRsp
end
---@param ctx Ctx
---@return Transmission
local function NewTransmission(ctx)
    ---@class Transmission
    local self = {
        arg    = ctx.arg,    -- 参数
        input  = ctx.input,  -- 输入
        config = ctx.config, -- 配置
        runCtx = ctx.ctx     -- 运行上下文
    }


    function self:Update()
        local app = NewApp()
        local url = string.format(global.urlFormat,self.config.HostPort)
        local stateRsp = doRequest("POST",url,global.getListArg)
        local data = json.decode(stateRsp.body)
        local index = 1
        local fontSize = 10
        for i = 1, #data.arguments.torrents do
            local d = data.arguments.torrents[i]
            local line = NewProcessLineUi()
                    .SetDesc(
                        NewText("leading")
                                .AddString(1,
                                    NewString(d.name).SetFontSize(fontSize))
                                .AddString(2,
                                    NewString(global.statusName[d.status]).SetFontSize(8)
                                            .SetBackendColor("#F00")
                                            .SetColor("#FFF"))
                                .AddString(2,
                                NewString(string.format("↓%s/S ↑%s/S", ByteToUiString(d.rateDownload), ByteToUiString(d.rateUpload)))
                                        .SetFontSize(8)
                                        .SetBackendColor("#66cccc")
                                        .SetColor("#FFF"))
                                .AddString(2,
                                NewString(ByteToUiString(d.totalSize))
                                        .SetFontSize(8)
                                        .SetBackendColor("#66cccc")
                                        .SetColor("#FFF"))


                    )
                    .SetTitle(NewText("trailing")
                    .AddString(1,
                    NewString(string.format("%.2f%%", d.percentDone * 100 ))
                            .SetFontSize(8)
                            .SetOpacity(0.5)
                    )
                    )
                    .SetProcessData(NewProcessData(d.percentDone*100,100))
            app.AddUi(index,line)
            if i%2 == 0 then
                index = index+1
            end
        end
        return app.Data()
    end

    return self
end

function register()
    -- 初始化ui
    return {
    }
end

---@param ctx Ctx
---@return AppUIData
function update(ctx)
    return NewTransmission(ctx):Update()
end
