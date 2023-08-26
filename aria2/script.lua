local http = require("http")
local json = require("json")
local httpClient = http.client({
    timeout = 2, -- 超时1s
})

local global = {
    addDownloadUrl = "aria2.addUri",
    getDownloading = "aria2.tellActive",
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
    menu = 1,
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

    ---@param app AppUI
    function getDownloadingInfo(app)
        local dataJson = getApi(global.getDownloading,global.getDownloadDingArg)
        req = http.request("POST",self.config.HostPort,json.encode(dataJson))
        local stateRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        local data  = json.decode(stateRsp.body)
        local index = 1
        local fontSize = 10
        for i = 1, #data.result do
            local info = data.result[i]
            local name = "unknown"
            if info.bittorrent and info.bittorrent.info then
                name = info.bittorrent.info.name
            end
            app.AddUi(
                    index,
                    NewProcessLineUi()
                            .SetDesc(NewText("leading")
                            .AddString(1,
                            NewString(name)
                                    .SetFontSize(fontSize)
                    )
                            .AddString(2,
                            NewString(ByteToUiString(info.totalLength))
                                    .SetFontSize(8)
                                    .SetBackendColor("#333366")
                                    .SetColor("#FFF")
                    )
                            .AddString(2,
                            NewString(string.format("↓%s/S ↑%s/S", ByteToUiString(info.downloadSpeed), ByteToUiString(info.uploadSpeed)))
                                    .SetFontSize(8)
                                    .SetBackendColor("#663366")
                                    .SetColor("#FFF")
                    )
                    )
                            .SetTitle(NewText("trailing")
                            .AddString(1,
                            NewString(string.format("%.2f%%", info.completedLength * 100 / info.totalLength))
                                    .SetFontSize(8)
                                    .SetOpacity(0.5)
                    )
                    )
                            .SetProcessData(NewProcessData(info.completedLength,info.totalLength))
                            .AddAction(NewAction("pause",{gid=info.gid},"暂停"))
                            .AddAction(NewAction("delete",{gid=info.gid},"删除").SetCheck(true))
            )

            if i%2 == 0 then
                index = index+1
            end
        end
    end


    function getFinishedInfo(app)
        local dataJson = getApi(global.stopUrl,-1,1000,global.getDownloadDingArg)
        req = http.request("POST",self.config.HostPort,json.encode(dataJson))
        local stateRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        local data  = json.decode(stateRsp.body)
        local index = 1
        local fontSize = 10
        for i = 1, #data.result do
            local info = data.result[i]
            app.AddUi(
                    index,
                    NewProcessLineUi()
                            .SetDesc(NewText("leading")
                            .AddString(1,
                            NewString(info.bittorrent.info.name)
                                    .SetFontSize(fontSize)
                    )
                            .AddString(2,
                            NewString(ByteToUiString(info.totalLength))
                                    .SetFontSize(8)
                                    .SetBackendColor("#333366")
                                    .SetColor("#FFF")
                    )
                            .AddString(2,
                            NewString(string.format("↓%s/S ↑%s/S", ByteToUiString(info.downloadSpeed), ByteToUiString(info.uploadSpeed)))
                                    .SetFontSize(8)
                                    .SetBackendColor("#663366")
                                    .SetColor("#FFF")
                    )
                    )
                            .SetTitle(NewText("trailing")
                            .AddString(1,
                            NewString(string.format("%.2f%%", info.completedLength * 100 / info.totalLength))
                                    .SetFontSize(8)
                                    .SetOpacity(0.5)
                    )
                    )
                            .SetProcessData(NewProcessData(info.completedLength,info.totalLength))
                            .AddAction(NewAction("delete",{gid=info.gid},"删除").SetCheck(true))

            )

            if i%2 == 0 then
                index = index+1
            end
        end
    end

    function getWaitingInfo(app)
        local dataJson = getApi(global.waitingUrl,0,1000,global.getDownloadDingArg)
        req = http.request("POST",self.config.HostPort,json.encode(dataJson))
        local stateRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        local data  = json.decode(stateRsp.body)
        local index = 1
        local fontSize = 10
        for i = 1, #data.result do
            local info = data.result[i]
            app.AddUi(
                    index,
                    NewProcessLineUi()
                            .SetDesc(NewText("leading")
                            .AddString(1,
                            NewString(info.bittorrent.info.name)
                                    .SetFontSize(fontSize)
                    )
                            .AddString(2,
                            NewString(ByteToUiString(info.totalLength))
                                    .SetFontSize(8)
                                    .SetBackendColor("#333366")
                                    .SetColor("#FFF")
                    )
                            .AddString(2,
                            NewString(string.format("↓%s/S ↑%s/S", ByteToUiString(info.downloadSpeed), ByteToUiString(info.uploadSpeed)))
                                    .SetFontSize(8)
                                    .SetBackendColor("#663366")
                                    .SetColor("#FFF")
                    )
                    )
                            .SetTitle(NewText("trailing")
                            .AddString(1,
                            NewString(string.format("%.2f%%", info.completedLength * 100 / info.totalLength))
                                    .SetFontSize(8)
                                    .SetOpacity(0.5)
                    )
                    )
                            .SetProcessData(NewProcessData(info.completedLength,info.totalLength))
                            .AddAction(NewAction("unpause",{gid=info.gid},"继续"))
                            .AddAction(NewAction("delete",{gid=info.gid},"删除").SetCheck(true))

            )

            if i%2 == 0 then
                index = index+1
            end
        end
    end

    function self:Update()
        local app =NewApp()
        local buttonSize = 17
        local play = NewIconButton().SetIcon("play.circle").SetAction(NewAction("changeMenu",{id=1},"")).SetSize(buttonSize)
        local pause = NewIconButton().SetIcon("pause.circle").SetAction(NewAction("changeMenu",{id=2},"")).SetSize(buttonSize)
        local finished = NewIconButton().SetIcon("list.bullet.circle").SetAction(NewAction("changeMenu",{id=3},"")).SetSize(buttonSize)
        local plus = NewIconButton().SetIcon("plus.circle")
                .SetAction(
                    NewAction("add",{},"").AddInput("Url",NewInput("下载url",1))
                ).SetSize(buttonSize)

        if global.menu == 1 then
            getDownloadingInfo(app)
            play.SetColor("#F00")
        elseif global.menu == 2 then
            pause.SetColor("#F00")
            getWaitingInfo(app)
        elseif global.menu == 3 then
            print("get finisted info----------")
            finished.SetColor("#F00")
            --getFinishedInfo(app)
        end
        app.AddMenu(plus).AddMenu(play).AddMenu(pause).AddMenu(finished)
        return app.Data()
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

    function self:ChangeMenu()
        global.menu = tonumber(self.arg.id)
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

function changeMenu(ctx)
    return NewAria2(ctx):ChangeMenu()
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