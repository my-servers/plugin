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
                "percentComplete",
                "downloadDir",
                "addedDate",
                "doneDate",
                "comment",
                "peers",
                "files"
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

function getStartArg(id)
    return {
        arguments = {
            ids = id,
        },
        method = "torrent-start"
    }
end

function getStopArg(id)
    return {
        arguments = {
            ids = id,
        },
        method = "torrent-stop"
    }
end

function getDeleteArg(id)
    return {
        arguments = {
            ids = id,
        },
        method = "torrent-remove"
    }
end

function getDeleteFileArg(id)
    return {
        arguments = {
            ids = id,
            ["delete-local-data"] = true,
        },
        method = "torrent-remove"
    }
end

function getDownloadFileArg(url,path)
    return {
        arguments = {
            filename = url,
            ["download-dir"] = path,
        },
        method = "torrent-add"
    }
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

    function getDetail(d)
        local detail = string.format([[
### %s
|  项   | 值  |
|  ----  | ----  |
| 大小  | %s |
| 下载进度  | %s |
| 状态  | %s |
]],
                d.name,ByteToUiString(d.totalSize),
                string.format("%.2f%%", d.percentDone * 100 ),
                global.statusName[d.status]
        )
        if type(d.files) == "table" then
            for i = 1, #d.files do
                local f = d.files[i]
                detail = detail .. string.format([[| 文件  | %s<br><br>已下载/总大小: %s/%s |
]], f.name,ByteToUiString(f.bytesCompleted),ByteToUiString(f.length))
            end
        end
        return detail
    end

    function self:Update()
        local app = NewApp()
        local url = string.format(global.urlFormat,self.config.HostPort)
        local stateRsp = doRequest("POST",url,global.getListArg)
        local data = json.decode(stateRsp.body)
        local index = 1
        local fontSize = 10
        for i = 1, #data.arguments.torrents do
            local d = data.arguments.torrents[i]
            local downloadAndUpload = ""
            if tonumber(d.rateDownload) > 0 then
                downloadAndUpload =  string.format("↓%s",ByteToUiString(d.rateDownload))
            end
            if tonumber(d.rateUpload) > 0 then
                downloadAndUpload = downloadAndUpload..string.format(" ↑%s",ByteToUiString(d.rateUpload))
            end
            if downloadAndUpload == "" then
                downloadAndUpload =  string.format("↓%s",ByteToUiString(d.rateDownload))
            end
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
                                NewString(downloadAndUpload)
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

            if d.status == 0 then
                line.AddAction(NewAction("start",{id=d.id},"继续"))
            else
                line.AddAction(NewAction("stop",{id=d.id},"暂停"))
            end
            line.AddAction(NewAction("delete",{id=d.id},"删除").SetCheck(true))
                .AddAction(NewAction("deleteFile",{id=d.id},"删除并清理文件").SetCheck(true))
            .SetDetail(getDetail(d))
            app.AddUi(index,line)
            if i%2 == 0 then
                index = index+1
            end
        end
        local buttonSize = 17
        app.AddMenu(NewIconButton()
                .SetSize(buttonSize)
                .SetIcon("plus.circle")
                .SetAction(NewAction("download",{},"")
                    .AddInput("Path",NewInput("路径",1).SetVal(self.config.DownloadPath))
                    .AddInput("Url",NewInput("下载链接",2))
                )
        )
        return app.Data()
    end

    function self:Start()
        local url = string.format(global.urlFormat,self.config.HostPort)
        doRequest("POST",url,getStartArg(self.arg.id))
        return NewToast("启动下载","info.circle","#000")
    end

    function self:Stop()
        local url = string.format(global.urlFormat,self.config.HostPort)
        doRequest("POST",url,getStopArg(self.arg.id))
        return NewToast("暂停","stop.circle","#000")
    end

    function self:Delete()
        local url = string.format(global.urlFormat,self.config.HostPort)
        doRequest("POST",url,getDeleteArg(self.arg.id))
        return NewToast("删除成功","trash","#F00")
    end

    function self:DeleteFile()
        local url = string.format(global.urlFormat,self.config.HostPort)
        doRequest("POST",url,getDeleteFileArg(self.arg.id))
        return NewToast("删除成功","trash","#F00")
    end

    function self:Download()
        local url = string.format(global.urlFormat,self.config.HostPort)
        doRequest("POST",url,getDownloadFileArg(self.input.Url,self.input.Path))
        return NewToast("下载","info.circle","#000")
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


function start(ctx)
    return NewTransmission(ctx):Start()
end

function stop(ctx)
    return NewTransmission(ctx):Stop()
end

function delete(ctx)
    return NewTransmission(ctx):Delete()
end

function deleteFile(ctx)
    return NewTransmission(ctx):DeleteFile()
end


function  download(ctx)
    return NewTransmission(ctx):Download()
end