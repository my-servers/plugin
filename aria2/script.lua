-- 根据aria2的文档开发 https://aria2.github.io/manual/en/html/aria2c.html#methods
local http = require("http")
local json = require("json")
local httpClient = http.client({
    timeout = 2, -- 超时1s
    insecure_ssl=true,
})

local global = {
    addDownloadUrl = "aria2.addUri",
    getDownloading = "aria2.tellActive",
    getState = "aria2.getGlobalStat",
    getDownloadDingArg  = {
        "gid",
        "totalLength",
        "completedLength",
        "uploadSpeed",
        "downloadSpeed",
        "connections",
        "numSeeders",
        "seeder",
        "status",
        "errorCode",
        "verifiedLength",
        "verifyIntegrityPending",
        "files",
        "infoHash",
        "bittorrent"
    },
    pauseUrl = "aria2.forcePause",
    unpauseUrl = "aria2.unpause",
    deleteUrl = "aria2.forceRemove",
    stopUrl = "aria2.tellStopped",
    waitingUrl = "aria2.tellWaiting",
    detailUrl = "aria2.tellStatus",
    deleteDownloadResult= "aria2.removeDownloadResult",
    them = {
        descFontColor = "#b8b8b8",
        infoFontSize = 16,
        descFontSize = 12,
        downloadingFontColor = "#4285f4",
        finishedFontColor = "#fbbc07",
        stopFontColor = "#ea4335",
        downloadFontColor = "#4dbf7a",
        upFontColor = "#ff4f00",
        sizeFontClolor = "#6348f2"
    },
    type = {
        active = {
            id = "active",
            name = "活动中"
        },
        stop =  {
            id = "stop",
            name = "已完成",
        },
        waiting =  {
            id = "waiting",
            name = "等待中",
        },
    }
}


---@param ctx Ctx
---@return Aria2
function NewAria2(ctx)
    ---@class Aria2
    local self = {
        arg = ctx.arg,
        input = ctx.input,
        config = ctx.config,
        runCtx = ctx.ctx,
    }

    function getApi(path,...)
        return {
            jsonrpc = "2.0",
            method = path,
            id = "1",
            params = {
                "token:"..self.config.Token,
                unpack(arg),
            }
        }
    end

    function getName(info)
        local name = "unknown"
        if info.bittorrent and info.bittorrent.info then
            name = info.bittorrent.info.name
        end
        if name == "unknown" and #info.files > 0 then
            name = info.files[1].path
        end
        return name
    end

    function doRequest(data)
        local api = string.format("http://%s:%s/jsonrpc",self.config.Host,self.config.Port)
        local req = http.request("POST",api,json.encode(data))
        local stateRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        if stateRsp.code == 400 then
            error("密钥验证失败")
        end
        return json.decode(stateRsp.body)
    end

    function self:Update()
        local app = NewApp()
        local state = {}
        local dataJson = getApi(global.getState)
        state = doRequest(dataJson)
        app
                .AddUi(
                1,
                NewTextUi().SetText(
                        NewText("")
                                .AddString(
                                1,
                                NewString(ByteToUiString(state.result.downloadSpeed))
                                        .SetFontSize(global.them.infoFontSize)
                        )
                                .AddString(
                                2,
                                NewString("下载速度")
                                        .SetColor(global.them.descFontColor)
                                        .SetFontSize(global.them.descFontSize)
                        )
                )
        )
                .AddUi(
                1,
                NewTextUi().SetText(
                        NewText("")
                                .AddString(
                                1,
                                NewString(ByteToUiString(state.result.uploadSpeed))
                                        .SetFontSize(global.them.infoFontSize)
                        )
                                .AddString(
                                2,
                                NewString("上传速度")
                                        .SetColor(global.them.descFontColor)
                                        .SetFontSize(global.them.descFontSize)
                        )
                )
        )
                .AddUi(
                1,
                NewTextUi().SetText(
                        NewText("").AddString(
                                1,
                                NewString(tostring(state.result.numActive))
                                        .SetFontSize(global.them.infoFontSize)
                                        .SetColor(global.them.downloadingFontColor)
                        )
                                   .AddString(
                                2,
                                NewString(global.type.active.name)
                                        .SetColor(global.them.descFontColor)
                                        .SetFontSize(global.them.descFontSize)
                        )
                ).SetPage("","torrentList",global.type.active,global.type.active.name)
        )

                .AddUi(
                1,
                NewTextUi().SetText(
                        NewText("").AddString(
                                1,
                                NewString(tostring(state.result.numStopped))
                                        .SetFontSize(global.them.infoFontSize)
                                        .SetColor(global.them.finishedFontColor)
                        )
                                   .AddString(
                                2,
                                NewString(global.type.stop.name)
                                        .SetColor(global.them.descFontColor)
                                        .SetFontSize(global.them.descFontSize)
                        )
                ).SetPage("","torrentList",global.type.stop,global.type.stop.name)
        )
                .AddUi(
                1,
                NewTextUi().SetText(
                        NewText("").AddString(
                                1,
                                NewString(tostring(state.result.numWaiting))
                                        .SetFontSize(global.them.infoFontSize)
                                        .SetColor(global.them.stopFontColor)
                        )
                                   .AddString(
                                2,
                                NewString(global.type.waiting.name)
                                        .SetColor(global.them.descFontColor)
                                        .SetFontSize(global.them.descFontSize)
                        )
                ).SetPage("","torrentList",global.type.waiting,global.type.waiting.name)
        )
                .AddMenu(
                NewIconButton().SetIcon("plus.circle")
                               .SetAction(
                        NewAction("add",{},"").AddInput("Url",NewInput("下载url",1))
                ).SetSize(17)
        )
        return app.Data()
    end

    function self:TorrentDeail()
        local page = NewPage()
        local dataJson = getApi(global.detailUrl,self.arg.gid)
        local detail = doRequest(dataJson)

        local section = NewPageSection(getName(detail.result))
        section.AddUiRow(
                NewUiRow()
                        .AddUi(
                        NewTextUi().SetText(
                                NewText("")
                                        .AddString(
                                        1,
                                        NewString(ByteToUiString(detail.result.downloadSpeed).."B/s")
                                                .SetColor(global.them.downloadFontColor)
                                                .SetFontSize(global.them.infoFontSize)
                                )
                                        .AddString(
                                        2,
                                        NewString("下载速度")
                                                .SetColor(global.them.descFontColor)
                                )
                        )
                )
                        .AddUi(
                        NewTextUi().SetText(
                                NewText("")
                                        .AddString(
                                        1,
                                        NewString(ByteToUiString(detail.result.uploadSpeed).."B/s")
                                                .SetColor(global.them.upFontColor)
                                                .SetFontSize(global.them.infoFontSize)
                                )
                                        .AddString(
                                        2,
                                        NewString("上传速度")
                                                .SetColor(global.them.descFontColor)
                                )
                        )
                )
                        .AddUi(
                        NewTextUi().SetText(
                                NewText("")
                                        .AddString(
                                        1,
                                        NewString(ByteToUiString(detail.result.completedLength))
                                                .SetColor(global.them.sizeFontClolor)
                                                .SetFontSize(global.them.infoFontSize)
                                )
                                        .AddString(
                                        2,
                                        NewString("已下载")
                                                .SetColor(global.them.descFontColor)
                                )
                        )
                )
                        .AddUi(
                        NewTextUi().SetText(
                                NewText("")
                                        .AddString(
                                        1,
                                        NewString(ByteToUiString(detail.result.totalLength))
                                                .SetColor(global.them.sizeFontClolor)
                                                .SetFontSize(global.them.infoFontSize)
                                )
                                        .AddString(
                                        2,
                                        NewString("总大小")
                                                .SetColor(global.them.descFontColor)
                                )
                        )
                )
        )
               .AddUiRow(
                NewUiRow().AddUi(
                        NewProcessLineUi()
                                .SetProcessData(
                                NewProcessData(detail.result.completedLength,detail.result.totalLength)
                        )
                                .SetTitle(
                                NewText("").AddString(
                                        1,
                                        NewString(string.format("%.2f%%",detail.result.completedLength/detail.result.totalLength*100))
                                                .SetColor(global.them.sizeFontClolor)
                                                .SetFontSize(10)
                                )
                        )
                )
        )

        local files = NewPageSection("内容")
        for index, value in ipairs(detail.result.files) do
            files.AddUiRow(
                    NewUiRow().AddUi(
                            NewProcessLineUi()
                                    .SetProcessData(
                                    NewProcessData(value.completedLength, value.length)
                            )
                                    .SetDesc(
                                    NewText("leading")
                                            .AddString(
                                            1,
                                            NewString(value.path)
                                                    .SetFontSize(10)
                                    )
                                            .AddString(
                                            2,
                                            NewString(ByteToUiString(value.length))
                                                    .SetFontSize(10)
                                                    .SetColor(global.them.sizeFontClolor)
                                    )
                                            .AddString(
                                            2,
                                            NewString(string.format("%.2f%%",value.completedLength/value.length*100))
                                                    .SetFontSize(10)
                                                    .SetColor(global.them.sizeFontClolor)
                                    )
                            )
                    )
            )
        end
        page.AddPageSection(
                section
        ).AddPageSection(
                files
        )
        return page.Data()
    end

    function self:TorrentList()
        local page = NewPage()
        local section = NewPageSection("列表")
        local list = {}
        if self.arg.id == global.type.active.id then
            local dataJson = getApi(global.getDownloading,global.getDownloadDingArg)
            list = doRequest(dataJson)
        elseif self.arg.id == global.type.waiting.id then
            local dataJson = getApi(global.waitingUrl,0,1000,global.getDownloadDingArg)
            list = doRequest(dataJson)
        else
            local dataJson = getApi(global.stopUrl,-1,1000,global.getDownloadDingArg)
            list = doRequest(dataJson)
        end
        if #list.result == 0 then
            return page.AddPageSection(section.AddUiRow(NewUiRow().AddUi(NewTextUi().SetText(NewText("").AddString(1,NewString("无数据").SetColor(global.them.descFontColor)))))).Data()
        end
        for index, value in ipairs(list.result) do
            local download = NewString(ByteToUiString(value.downloadSpeed).."/s")
                    .SetFontSize(10)
                    .SetColor(global.them.descFontColor)

            local up = NewString(ByteToUiString(value.uploadSpeed).."/s")
                    .SetFontSize(10)
                    .SetColor(global.them.descFontColor)
            if tonumber(value.downloadSpeed) > 0 then
                download.SetColor(global.them.downloadFontColor)
            end
            if tonumber(value.uploadSpeed) > 0 then
                up.SetColor(global.them.upFontColor)
            end
            local torrent = NewProcessLineUi()
                    .SetDesc(
                    NewText("leading").AddString(
                            1,
                            NewString(getName(value))
                                    .SetFontSize(10)
                    )
                                      .AddString(2,
                            NewString(ByteToUiString(value.totalLength))
                                    .SetFontSize(10)
                                    .SetColor(global.them.descFontColor)
                    )
            )
                    .SetTitle(
                    NewText("trailing")
                            .AddString(2,
                            download
                    )
                            .AddString(2,
                            up
                    )
                            .AddString(1,
                            NewString(string.format("%.2f%%", value.completedLength * 100 / value.totalLength))
                                    .SetFontSize(10)
                    )
            )
                    .SetProcessData(
                    NewProcessData(value.completedLength,value.totalLength)
            )

            if self.arg.id == global.type.stop.id then
                torrent.AddAction(
                        NewAction("deleteDownloadResult",{gid=value.gid},"删除任务").SetCheck(true)
                )
            elseif self.arg.id == global.type.active.id  then
                torrent
                        .AddAction(NewAction("pause",{gid=value.gid},"暂停"))
                        .AddAction(NewAction("delete",{gid=value.gid},"删除").SetCheck(true))
            elseif self.arg.id == global.type.waiting.id then
                torrent
                        .AddAction(NewAction("unpause",{gid=value.gid},"继续"))
                        .AddAction(NewAction("delete",{gid=value.gid},"删除").SetCheck(true))
            end

            torrent.SetPage("","torrentDeail",{gid=value.gid},"下载详情")

            section.AddUiRow(
                    NewUiRow().AddUi(
                            torrent
                    )
            )
        end
        page.AddPageSection(
                section
        )
        return page.Data()
    end


    function self:Pause()
        local data = getApi(global.pauseUrl,self.arg.gid)
        req = http.request("POST",self.config.HostPort,json.encode(data))
        local stateRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        print("pause---",json.encode(data),json.encode(stateRsp))
        return NewToast("暂停","stop.circle","#000")
    end



    function self:Unpause()
        local data = getApi(global.unpauseUrl,self.arg.gid)
        req = http.request("POST",self.config.HostPort,json.encode(data))
        local stateRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        print("unpause---",json.encode(data),json.encode(stateRsp))
        return NewToast("继续","info.circle","#000")
    end

    function self:Delete()
        local data = getApi(global.deleteUrl,self.arg.gid)
        req = http.request("POST",self.config.HostPort,json.encode(data))
        local stateRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        print("delete---",json.encode(data),json.encode(stateRsp))
        return NewToast("删除成功","trash","#F00")
    end

    function self:DeleteDownloadResult()
        local data = getApi(global.deleteDownloadResult,self.arg.gid)
        req = http.request("POST",self.config.HostPort,json.encode(data))
        local stateRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        print("delete---",json.encode(data),json.encode(stateRsp))
        return NewToast("删除成功","trash","#F00")
    end

    function self:Add()
        local data = getApi(global.addDownloadUrl,{self.input.Url})
        req = http.request("POST",self.config.HostPort,json.encode(data))
        local stateRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        print("add---",json.encode(data),json.encode(stateRsp))
        return NewToast("添加下载成功","info.circle","#000")
    end

    return self
end

function register()
    return {
    }
end


function update(ctx)
    return NewAria2(ctx):Update()
end


function pause(ctx)
    return NewAria2(ctx):Pause()
end


function unpause(ctx)
    return NewAria2(ctx):Unpause()
end

function delete(ctx)
    return NewAria2(ctx):Delete()
end

function add(ctx)
    return NewAria2(ctx):Add()
end

function deleteDownloadResult(ctx)
    return NewAria2(ctx):DeleteDownloadResult()
end

function torrentList(ctx)
    return NewAria2(ctx):TorrentList()
end

function torrentDeail(ctx)
    return NewAria2(ctx):TorrentDeail()
end