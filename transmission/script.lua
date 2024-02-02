local http = require("http")
local json = require("json")
local httpClient = http.client({
    timeout = 2, -- 超时1s
    insecure_ssl=true,
})
local asyncHttpClient = http.client({
    timeout = 5, -- 超时1s
    insecure_ssl=true,
})
local global = {
    urlFormat = "http://%s:%s@%s/transmission/rpc",
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
            },
            format = "json"
        },
        method = "torrent-get"
    },
    getDetail = {
        method= "torrent-get",
        arguments= {
            ids={},
            fields= {
                "magnetLink",
                "files",
                "id",
                "name",
                "status",
                "hashString",
                "totalSize",
                "percentDone",
                "addedDate",
                "trackerStats",
                "leftUntilDone",
                "rateDownload",
                "rateUpload",
                "recheckProgress",
                "rateDownload",
                "rateUpload",
                "peers",
                "peersGettingFromUs",
                "peersSendingToUs",
                "uploadRatio",
                "uploadedEver",
                "downloadedEver",
                "downloadDir",
                "error",
                "errorString",
                "doneDate",
                "queuePosition",
                "activityDate"
            }
        },
        tag= ""
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
    },
    getGlobalState = {
        method = "session-stats",
        arguments = {},
        tag = "",
    },
    them = {
        descFontColor = "#b8b8b8",
        infoFontSize = 16,
        buttonSize = 28,
        listInfoFontSize = 11,
        listDescFontSize = 10,
        allFontColor = "#34a853",
        downlodingFontColor = "#4285f4",
        pausedFontColor = "#ea4335",
        finishedFontColor = "#fbbc07",
        downloadFontColor = "#4dbf7a",
        upFontColor = "#ff4f00",
        sizeFontClolor = "#6348f2"
    },
    allButton = {
        {
            name = "全部",
            arg = "all",
            descFontColor = "#b8b8b8",
            fontColor = "#34a853",
        },
        {
            name = "下载中",
            arg = "downloding",
            descFontColor = "#b8b8b8",
            fontColor = "#34a853"
        },
        {
            name = "已完成",
            arg = "finished",
            descFontColor = "#b8b8b8",
            fontColor = "#fbbc07"
        },
        {
            name = "已暂停",
            arg = "paused",
            descFontColor = "#b8b8b8",
            fontColor = "#ea4335"
        },
    },
    allTorrentList = {}, -- 0-6
    downlodingTorrentList = {}, -- 1 2 3 4
    pausedTorrentList = {}, -- 0
    finishedTorrentList = {}, -- 6
    listPage = {
        curType = "",
        cursor = 1,
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

function getReanounceArg(id)
    return {
        arguments = {
            ids = id,
        },
        method = "torrent-reannounce"
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

function asyncDoRequest(method,url,data)
    local req = http.request(method,url,json.encode(data))
    local stateRsp,err = asyncHttpClient:do_request(req)
    if err then
        error(err)
    end
    if stateRsp.code == 409 then
        asyncHttpClient = http.client({
            timeout = 5, -- 超时1s
            headers = {
                [global.sessionKey] = stateRsp.headers[global.sessionKey]
            }
        })
        stateRsp,err = asyncHttpClient:do_request(req)
    end
    if err then
        print("do req err", err)
        return {body=""}
    end
    return stateRsp
end


function doRequest(method,url,data)
    local req = http.request(method,url,json.encode(data))
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
        print("do req err", err)
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

    local function getUrl()
        return string.format(global.urlFormat, http.query_escape(self.config.UserName),http.query_escape(self.config.Password),self.config.HostPort)
    end

    local function getDetail(d)
        local detail = string.format([[
### %s
|  项   | 值  |
|  ----  | ----  |
| 大小  | %s |
| 进度  | %s |
| 状态  | %s |
| 路径  | %s |
]],
                d.name,ByteToUiString(d.totalSize),
                string.format("%.2f%%", d.percentDone * 100 ),
                global.statusName[d.status],
                d.downloadDir
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

    local function getList(type)
        local list = global.allTorrentList
        if type == "downloding" then
            list = global.downlodingTorrentList
        end
        if type == "paused" then
            list = global.pausedTorrentList
        end
        if type == "finished" then
            list = global.finishedTorrentList
        end
        return list
    end

    local function asyncUpdate()
        go("asyncGetAllTorrentList",function(allList)
            local allTorrentList = {}
            local downlodingTorrentList = {} -- 1 2 3 4
            local pausedTorrentList = {} -- 0
            local finishedTorrentList = {} -- 6
            for index, value in ipairs(allList.arguments.torrents) do
                table.insert(allTorrentList, value)
                if value.status == 1 or value.status == 2 or value.status == 3 or value.status == 4 then
                    table.insert(downlodingTorrentList, value)
                end
                if value.status == 0 then
                    table.insert(pausedTorrentList, value)
                end
                if value.status == 6 then
                    table.insert(finishedTorrentList, value)
                end
            end
            global.downlodingTorrentList = downlodingTorrentList
            global.pausedTorrentList = pausedTorrentList
            global.finishedTorrentList = finishedTorrentList
            global.allTorrentList = allTorrentList
        end,self.config.UserName,self.config.Password,self.config.HostPort)
    end

    function self:Update()
        local app = NewApp()
        local globalState = {}
        goAndWait({
            globalStateKey = function ()
                local stateRsp = doRequest("POST",getUrl(),global.getGlobalState)
                globalState = json.decode(stateRsp.body)
            end
        })
        asyncUpdate()

        app
                .AddUi(
                1,
                NewTextUi().SetText(
                        NewText("")
                                .AddString(
                                1,
                                NewString(ByteToUiString(globalState.arguments.downloadSpeed).."/s")
                                        .SetFontSize(global.them.infoFontSize)
                        )
                                .AddString(
                                2,
                                NewString("下载速度").SetColor(global.them.descFontColor)
                        )
                )
        )
                .AddUi(
                1,
                NewTextUi().SetText(
                        NewText("")
                                .AddString(
                                1,
                                NewString(ByteToUiString(globalState.arguments["cumulative-stats"].downloadedBytes))
                                        .SetFontSize(global.them.infoFontSize)
                        )
                                .AddString(
                                2,
                                NewString("累计下载").SetColor(global.them.descFontColor)
                        )
                )
        )
                .AddUi(
                1,
                NewTextUi().SetText(
                        NewText("")
                                .AddString(
                                1,
                                NewString(ByteToUiString(globalState.arguments.uploadSpeed).."/s")
                                        .SetFontSize(global.them.infoFontSize)
                        )
                                .AddString(
                                2,
                                NewString("上传速度").SetColor(global.them.descFontColor)
                        )
                )
        )
                .AddUi(
                1,
                NewTextUi().SetText(
                        NewText("")
                                .AddString(
                                1,
                                NewString(ByteToUiString(globalState.arguments["cumulative-stats"].uploadedBytes))
                                        .SetFontSize(global.them.infoFontSize)
                        )
                                .AddString(
                                2,
                                NewString("累计上传").SetColor(global.them.descFontColor)
                        )
                )
        )


        for index, value in ipairs(global.allButton) do
            local list = getList(value.arg)
            app
                    .AddUi(
                    2,
                    NewTextUi()
                            .SetText(
                            NewText("")
                                    .AddString(
                                    1,
                                    NewString(tostring(#list))
                                            .SetFontSize(24)
                                            .SetColor(value.fontColor)
                            )
                                    .AddString(
                                    2,
                                    NewString(value.name).SetColor(value.descFontColor)
                            )
                    ).SetPage("","torrentList",value,value.name)
            )
        end

        app.AddMenu(
                NewIconButton().SetSize(17)
                               .SetIcon("plus.circle")
                               .SetAction(NewAction("download",{},"")
                        .AddInput("Path",NewInput("路径",1).SetVal(self.config.DownloadPath))
                        .AddInput("Url",NewInput("下载链接",2))
                )
        )
        return app.Data()
    end

    function self:Update1()
        local app = NewApp()
        local url = getUrl()
        local stateRsp = doRequest("POST",url,global.getListArg)
        local data = json.decode(stateRsp.body)
        local index = 1
        local fontSize = 10
        for i = 1, #data.arguments.torrents do
            local d = data.arguments.torrents[i]
            local downloadAndUpload = ""
            if tonumber(d.rateDownload) > 0 then
                downloadAndUpload = string.format("↓%s",ByteToUiString(d.rateDownload))
            end
            if tonumber(d.rateUpload) > 0 then
                downloadAndUpload = downloadAndUpload..string.format(" ↑%s",ByteToUiString(d.rateUpload))
            end
            if downloadAndUpload == "" then
                downloadAndUpload = string.format("↓%s",ByteToUiString(d.rateDownload))
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
            line.AddAction(NewAction("reannounce",{id=d.id},"刷新Peers列表"))
            line.AddAction(NewAction("delete",{id=d.id},"删除").SetCheck(true))
                .AddAction(NewAction("deleteFile",{id=d.id},"删除并清理文件").SetCheck(true))
                .SetDetail(getDetail(d))
            app.AddUi(index,line)
            if i%2 == 0 then
                index = index+1
            end
        end
        local buttonSize = 17
        addTorrentButton = NewIconButton().SetSize(buttonSize)
                                          .SetIcon("plus.circle")
                                          .SetAction(NewAction("download",{},"")
                .AddInput("Path",NewInput("路径",1).SetVal(self.config.DownloadPath))
                .AddInput("Url",NewInput("下载链接",2))
        )
        app.AddMenu(addTorrentButton)
        return app.Data()
    end

    function escapePattern(text)
        return text:gsub("([^%w])", "%%%1")
    end

    function deepCopy(obj)
        if type(obj) ~= 'table' then return obj end
        local res = {}
        for k, v in pairs(obj) do
            res[deepCopy(k)] = deepCopy(v)
        end
        return res
    end
    function self:Pre()

        local temp = global.listPage.cursor - getLimit()
        if temp < 1 then
            temp = 1
        end
        global.listPage.cursor = temp
    end

    function self:Next()
        local temp = global.listPage.cursor + getLimit()
        local list = getList(global.listPage.curType)
        if temp > #list then
            temp = #list
        end
        global.listPage.cursor = temp
    end

    function self:TorrentDetail()
        asyncUpdate()
        local detail = {}
        goAndWait({
            setailKey = function ()
                local getDetailArg = deepCopy(global.getDetail)
                table.insert(getDetailArg.arguments.ids, self.arg.id)
                local stateRsp = doRequest("POST",getUrl(), getDetailArg)
                detail = json.decode(stateRsp.body)
            end
        })
        local page = NewPage()
        if #detail.arguments.torrents == 0 then
            return page.AddPageSection(NewPageSection("无数据")).Data()
        end
        local torrent = detail.arguments.torrents[1]
        local section = NewPageSection(torrent.name)

        section.AddUiRow(
                NewUiRow()
                        .AddUi(
                        NewTextUi().SetText(
                                NewText("")
                                        .AddString(
                                        1,
                                        NewString(ByteToUiString(torrent.rateDownload).."/s")
                                                .SetColor(global.them.downloadFontColor)
                                                .SetFontSize(global.them.infoFontSize)
                                )
                                        .AddString(
                                        2,
                                        NewString("下载速度").SetColor(global.them.descFontColor)
                                )
                        )
                )
                        .AddUi(
                        NewTextUi().SetText(
                                NewText("")
                                        .AddString(
                                        1,
                                        NewString(ByteToUiString(torrent.rateUpload).."/s")
                                                .SetColor(global.them.upFontColor)
                                                .SetFontSize(global.them.infoFontSize)
                                )
                                        .AddString(
                                        2,
                                        NewString("上传速度").SetColor(global.them.descFontColor)
                                )
                        )
                )
                        .AddUi(
                        NewTextUi().SetText(
                                NewText("")
                                        .AddString(
                                        1,
                                        NewString(ByteToUiString(torrent.downloadedEver))
                                                .SetColor(global.them.sizeFontClolor)
                                                .SetFontSize(global.them.infoFontSize)
                                )
                                        .AddString(
                                        2,
                                        NewString("已下载").SetColor(global.them.descFontColor)
                                )
                        )
                )
                        .AddUi(
                        NewTextUi().SetText(
                                NewText("")
                                        .AddString(
                                        1,
                                        NewString(ByteToUiString(torrent.totalSize))
                                                .SetColor(global.them.sizeFontClolor)
                                                .SetFontSize(global.them.infoFontSize)
                                )
                                        .AddString(
                                        2,
                                        NewString("总大小").SetColor(global.them.descFontColor)
                                )
                        )
                )
        )
               .AddUiRow(
                NewUiRow().AddUi(
                        NewProcessLineUi().SetProcessData(
                                NewProcessData(torrent.percentDone, 1)
                        ).SetTitle(
                                NewText("trailing").AddString(
                                        1,
                                        NewString(string.format("%.2f%%", torrent.percentDone*100))
                                                .SetColor(global.them.sizeFontClolor)
                                                .SetFontSize(10)
                                )
                        )
                )
        )
               .AddMenu(
                NewIconButton()
                        .SetIcon("doc.on.doc")
                        .SetAction(
                        NewAction("",{},"复制").SetCopyAction(torrent.magnetLink)
                ).SetSize(14)
        )


        local content = NewPageSection("内容")
        for index, value in ipairs(torrent.files) do
            content.AddUiRow(
                    NewUiRow().AddUi(
                            NewProcessLineUi().SetDesc(
                                    NewText("leading")
                                            .AddString(
                                            1,
                                            NewString(string.gsub(value.name, escapePattern(torrent.name), "", 1))
                                                    .SetFontSize(10)
                                    )
                                            .AddString(
                                            2,
                                            NewString(ByteToUiString(value.length))
                                                    .SetColor(global.them.sizeFontClolor)
                                                    .SetFontSize(10)
                                    )
                                            .AddString(
                                            2,
                                            NewString(string.format("%.2f%%",value.bytesCompleted/value.length*100))
                                                    .SetColor(global.them.sizeFontClolor)
                                                    .SetFontSize(10)
                                    )
                            )
                                              .SetProcessData(
                                    NewProcessData(value.bytesCompleted,value.length)
                            )
                    )
            )
        end

        local peer = NewPageSection("用户")
        page
                .AddPageSection(
                section
        )
                .AddPageSection(
                content
        )

        return page.Data()
    end

    function getLimit()
        if Tonumber(self.config.Limit)  > 0 then
            return Tonumber(self.config.Limit)
        end
        return 20
    end
    function self:TorrentList()
        asyncUpdate()
        local page = NewPage()
        local listSection = NewPageSection("列表")
        if self.arg.arg ~= global.listPage.curType then
            global.listPage.cursor = 1
            global.listPage.curType = self.arg.arg
        end
        local list = getList(global.listPage.curType)
        if #list == 0 then
            return page.AddPageSection(listSection.AddUiRow(NewUiRow().AddUi(NewTextUi().SetText(NewText("").AddString(1,NewString("无数据").SetColor(global.them.descFontColor)))))).Data()
        end
        if global.listPage.cursor > 1 then
            listSection.SetPre(
                    NewAction("pre",{},"前一页")
            )
        end
        listSection.SetPageInfo(tostring(global.listPage.cursor))
        local limit = getLimit()
        if global.listPage.cursor + limit <= #list then
            -- 结束了
            listSection.SetNext(
                    NewAction("next",{},"后一页")
            )
        end
        if global.listPage.cursor > #list then
            global.listPage.cursor = #list
        end
        for i = global.listPage.cursor, global.listPage.cursor+limit-1 do
            if i > #list then
                break
            end
            local value = list[i]
            local download = NewString(string.format("↓%s/S", ByteToUiString(value.rateDownload)))
                    .SetFontSize(global.them.listDescFontSize)
                    .SetColor(global.them.downloadFontColor)

            if value.rateDownload == 0 then
                download.SetColor(global.them.descFontColor)
            end
            local upload = NewString(string.format("↑%s/S", ByteToUiString(value.rateUpload)))
                    .SetFontSize(global.them.listDescFontSize)
                    .SetColor(global.them.upFontColor)
            if value.rateUpload == 0 then
                upload.SetColor(global.them.descFontColor)
            end
            local title = NewText("trailing")
                    .AddString(
                    1,
                    NewString(string.format("%.2f%%", value.percentDone * 100 ))
                            .SetFontSize(global.them.listDescFontSize)
            )
            if value.status ~= 4 then
                title.AddString(
                        2,
                        NewString(global.statusName[value.status])
                                .SetFontSize(global.them.listDescFontSize)
                )
            else
                title.AddString(
                        2,
                        download
                )
                     .AddString(
                        2,
                        upload
                )
            end

            local line = NewProcessLineUi().SetDesc(
                    NewText("leading")
                            .AddString(
                            1,
                            NewString(value.name).SetFontSize(10)
                    )
                            .AddString(
                            2,
                            NewString(ByteToUiString(value.totalSize)).SetFontSize(10)
                                                                      .SetColor(global.them.descFontColor)
                    )
            ).SetTitle(
                    title
            )
            if value.status == 0 then
                line.AddAction(NewAction("start",{id=value.id},"继续"))
            else
                line.AddAction(NewAction("stop",{id=value.id},"暂停"))
            end
            line.AddAction(NewAction("reannounce",{id=value.id},"刷新Peers列表"))
                .AddAction(NewAction("delete",{id=value.id},"删除").SetCheck(true))
                .AddAction(NewAction("deleteFile",{id=value.id},"删除并清理文件").SetCheck(true))
                .SetProcessData(NewProcessData(value.percentDone*100,100))
                .SetPage("","torrentDetail",value,"种子详情")
            listSection.AddUiRow(
                    NewUiRow().AddUi(
                            line
                    )
            )
        end
        page.AddPageSection(
                listSection
        )
        return page.Data()
    end

    function self:Start()
        local url = getUrl()
        doRequest("POST",url,getStartArg(self.arg.id))
        return NewToast("启动下载","info.circle","#000")
    end

    function self:Stop()
        local url = getUrl()
        doRequest("POST",url,getStopArg(self.arg.id))
        return NewToast("暂停","stop.circle","#000")
    end

    function self:Reannounce()
        local url = getUrl()
        doRequest("POST",url,getReanounceArg(self.arg.id))
        return NewToast("刷新Peers列表成功","antenna.radiowaves.left.and.right.circle","#000")
    end

    function self:Delete()
        local url = getUrl()
        doRequest("POST",url,getDeleteArg(self.arg.id))
        return NewToast("删除成功","trash","#F00")
    end

    function self:DeleteFile()
        local url = getUrl()
        doRequest("POST",url,getDeleteFileArg(self.arg.id))
        return NewToast("删除成功","trash","#F00")
    end

    function self:Download()
        local url = getUrl()
        doRequest("POST",url,getDownloadFileArg(self.input.Url,self.input.Path))
        return NewToast("下载","info.circle","#000")
    end


    return self
end

function register(ctx)
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

function reannounce(ctx)
    return NewTransmission(ctx):Reannounce()
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

function asyncGetAllTorrentList(UserName,Password,HostPort)
    local url = string.format(global.urlFormat, http.query_escape(UserName),http.query_escape(Password),HostPort)
    local stateRsp = asyncDoRequest("POST", url, global.getListArg)
    local data = json.decode(stateRsp.body)
    return data
end

function torrentList(ctx)
    return NewTransmission(ctx):TorrentList()
end

function torrentDetail(ctx)
    return NewTransmission(ctx):TorrentDetail()
end

function pre(ctx)
    return NewTransmission(ctx):Pre()
end

function next(ctx)
    return NewTransmission(ctx):Next()
end