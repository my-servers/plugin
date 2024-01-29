local json = require("json")
local http = require("http")
local httpClient = http.client({
    timeout = 1, -- 超时1s
    headers = {["Content-Type"]="application/x-www-form-urlencoded"},
    insecure_ssl=true,
})

local global = {
    fontColor = "#6348f2",
    downloadFontColor = "#4dbf7a",
    upFontColor = "#ff4f00",
    cookie = "",
    choiceButton = "2",
    urlArg = "downloading",
    allStateConfig = {
        all = {
            fontColor = "#34a853",
            name = "全部",
            pageArg = "all",
            priority = 1,
            icon = "≡",
        },
        downloading = {
            fontColor = "#4285f4",
            name = "下载中",
            pageArg = "downloading",
            priority = 2,
            icon = "⇣",
        },
        completed = {
            fontColor = "#fbbc07",
            name = "已完成",
            pageArg = "completed",
            priority = 3,
            icon = "✓",
        },
        paused = {
            fontColor = "#ea4335",
            name = "暂停",
            pageArg = "paused",
            priority = 4,
            icon = "⏸︎",
        }
    },
    allStateButton= {},
    blue = "#F00",
    black = "#000",
    stateMsg = {
        error = "出错",
        missingFiles = "种子数据文件丢失",
        pausedUP = "暂停上传",
        metaDL = "获取元数据",
        pausedDL = "暂停下载",
    },
    searchTaskId = 0,
    api = {
        PauseUrl = "/api/v2/torrents/pause",
        ResumeUrl = "/api/v2/torrents/resume",
        DeleteUrl = "/api/v2/torrents/delete",
        LoginUrl = "/api/v2/auth/login",
        Url = "/api/v2/torrents/info",
        TorrentDetail = "/api/v2/torrents/properties",
        Files = "/api/v2/torrents/files",
        Peers = "/api/v2/sync/torrentPeers",
        Trackers = "/api/v2/torrents/trackers",
        FilePrio = "/api/v2/torrents/filePrio",
        SearchUrl = "/api/v2/search/start",
        AddUrl = "/api/v2/torrents/add",
        SearchResultUrl = "/api/v2/search/results",
        StopSearchUrl = "/api/v2/search/stop",
        GlobalInfo = "/api/v2/transfer/info",
    },
    priorityMap = {
        ["0"] = "不下载",
        ["1"] = "正常",
        ["6"] = "较高",
        ["7"] = "最高",
    },
    listPageArg = {
        offset = 0,
        type = "downloading",
        limit = 10,
        firstHash = "",-- 由于qb没有返回分页结束符
    },
    them = {
        descFontColor = "#b8b8b8",
        infoFontSize = 16,
        buttonSize = 28,
        listInfoFontSize = 11,
        listDescFontSize = 10,
    }
}

local function initButton()
    global.allStateButton = {}
    for key, value in pairs(global.allStateConfig) do
        table.insert(global.allStateButton,value)
    end
    table.sort(global.allStateButton,function (a, b)
        return a.priority < b.priority
    end)
end

---@param ctx Ctx
---@return QBittorrent
local function NewQBittorrent(ctx)
    ---@class QBittorrent
    local self = {
        arg    = ctx.arg,    -- 参数
        input  = ctx.input,  -- 输入
        config = ctx.config, -- 配置
        runCtx = ctx.ctx     -- 运行上下文
    }

    local function updateCookie()
        data = string.format("username=%s&password=%s",self.config.Username,self.config.Password)
        req = http.request("POST",self.config.HostPort .. global.api.LoginUrl,data)
        loginRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        if loginRsp.code == 403 then
            error(loginRsp.body)
        end
    end

    local function getSearchResult()
        cfg = self.config
        data = string.format("id=%s&limit=%d",global.searchTaskId,tonumber(cfg.SearchNum) )
        req = http.request("POST",self.config.HostPort .. global.api.SearchResultUrl,data)
        loginRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        if loginRsp.code ~= 200 then
            global.searchTaskId = 0
            return {},loginRsp.code
        end
        results = json.decode(loginRsp.body)
        table.sort(results.results, function(a, b)
            return a.nbSeeders * 1000000000000 + a.fileSize > b.nbSeeders * 1000000000000 + b.fileSize
        end)
        return results,loginRsp.code
    end


    ---@param app AppUI
    local function handleSearchList(app)
        -- 周期获取数据
        -- 周期获取数据
        local data,code = getSearchResult()
        if code == 403 then
            updateCookie()
            data,code = getSearchResult()
        end
        list = data.results
        row = 1000
        index = 1
        if #list == 0 then
            text = NewText("").AddString(1, NewString("搜索中...").SetOpacity(0.8))
            app.AddUi(1, NewTextUi().SetText(text))
            return
        end
        for i = 1, #list do
            if string.len(list[i].fileName) == 0 then
                goto continue
            end
            text = NewText("leading")
            text.AddString(1, NewString(string.sub(list[i].fileName, 0, 100))
                    .SetFontSize(10))
            text.AddString(2, NewString(ByteToUiString(list[i].fileSize))
                    .SetFontSize(8)
                    .SetBackendColor("#66cccc")
                    .SetColor("#FFF"))
                .AddString(2,
                    NewString(tostring(list[i].nbSeeders).." 做种")
                            .SetFontSize(8)
                            .SetBackendColor("#66cccc")
                            .SetColor("#FFF"))
            ui = NewTextUi().SetText(text)
                            .AddAction(NewAction("download", { Url = list[i].fileUrl }, "下载"))
            app.AddUi(row, ui)
            if index % 2 == 0 then
                row = row + 1
            end
            index = index + 1
            ::continue::
        end
    end

    local function getBittorrentList(type,offset,limit)
        local url = string.format("%s%s?filter=%s&limit=%d&offset=%d",self.config.HostPort,global.api.Url,type,limit,offset)
        local req = http.request("GET",url)
        local loginRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        return loginRsp
    end

    local function getBtOneItem(d)
        local download = NewString(string.format("↓%s/S", ByteToUiString(d.dlspeed)))
                .SetFontSize(global.them.listDescFontSize).SetColor(global.downloadFontColor)
        local upload = NewString(string.format("↑%s/S", ByteToUiString(d.upspeed)))
                .SetFontSize(global.them.listDescFontSize).SetColor(global.upFontColor)

        if d.dlspeed == 0 then
            download.SetColor(global.them.descFontColor)
        end
        if d.upspeed == 0 then
            upload.SetColor(global.them.descFontColor)
        end

        local right = NewText("trailing")
                .AddString(
                1,
                NewString(string.format("%.2f%%", d.completed * 100 / d.total_size))
                        .SetFontSize(global.them.listDescFontSize)
        )

        if global.stateMsg[d.state] ~= nil then
            right.AddString(
                    2,
                    NewString(global.stateMsg[d.state]).SetFontSize(global.them.listDescFontSize)
            )
        else
            right
                    .AddString(
                    2,
                    download
            )
                    .AddString(
                    2,
                    upload
            )
        end


        local line = NewProcessLineUi()
                .SetDesc(NewText("leading")
                .AddString(
                1,
                NewString(string.sub(d.name, 0, tonumber(self.config.NameLen)))
                        .SetFontSize(global.them.listInfoFontSize)
        )
                .AddString(
                2,
                NewString(string.format("%s", ByteToUiString(d.total_size)))
                        .SetFontSize(global.them.listDescFontSize).SetColor(global.them.descFontColor)
        )
        )
                .SetTitle(
                right
        )
                .SetProcessData(NewProcessData(d.completed, d.total_size))
        if d.state == "pausedDL" or d.state == "pausedUP" then
            line.AddAction(NewAction("resume", { hash = d.hash }, "继续").SetIcon("play.circle"))
        else
            line.AddAction(NewAction("pause", { hash = d.hash }, "暂停").SetIcon("pause.circle"))
        end
        line.AddAction(NewAction("delete", { hash = d.hash,clean = "false" }, "删除").SetIcon("trash.circle").SetCheck(true))
        line.AddAction(NewAction("delete", { hash = d.hash,clean = "true" }, "删除并清理文件").SetIcon("trash.circle").SetCheck(true))
            .SetPage("qbittorrent","torrentDetail",d,"任务详情")
        return line
    end

    local function doRequestWithLogin(req)
        local loginRsp,err = httpClient:do_request(req)
        if loginRsp.code == 403 then
            updateCookie()
            loginRsp,err = httpClient:do_request(req)
        end
        if err then
            error(err)
        end
        if loginRsp.code == 403 then
            error("登陆失败")
        end
        return loginRsp
    end

    local function getGlobalInfo(text, desc)
        return NewTextUi().SetText(
                NewText("")
                        .AddString(
                        1,
                        NewString(text)
                                .SetFontSize(global.them.infoFontSize)
                )
                        .AddString(
                        2,
                        NewString(desc).SetColor(global.them.descFontColor)
                )
        )
    end

    function GetUi()
        local app = NewApp()
        if #global.allStateButton == 0 then
            initButton()
        end
        local globalInfo = {}
        goAndWait({
            globalInfoKey = function ()
                local url = string.format("%s%s",self.config.HostPort,global.api.GlobalInfo)
                local req = http.request("GET",url)
                local info = doRequestWithLogin(req)
                globalInfo = json.decode(info.body)
            end
        })

        app
                .AddUi(
                1,
                getGlobalInfo(ByteToUiString(globalInfo.dl_info_speed).."/s","下载速度")
        )
                .AddUi(
                1,
                getGlobalInfo(ByteToUiString(globalInfo.dl_info_data),"累计下载")
        )
                .AddUi(
                1,
                getGlobalInfo(ByteToUiString(globalInfo.up_info_speed).."/s","上传速度")
        )
                .AddUi(
                1,
                getGlobalInfo(ByteToUiString(globalInfo.up_info_data),"累计上传")
        )

        for index, value in ipairs(global.allStateButton) do
            app
                    .AddUi(
                    2,
                    NewTextUi().SetText(
                            NewText("")
                                    .AddString(
                                    1,
                                    NewString(value.icon)
                                            .SetFontSize(global.them.buttonSize)
                                            .SetColor(value.fontColor)
                            )
                                    .AddString(
                                    2,
                                    NewString(value.name).SetColor(global.them.descFontColor)
                            )
                    ).SetPage("qbittorrent","moreList",{type=value.pageArg},value.name)
            )
        end
        app
                .AddMenu(
                NewIconButton().SetIcon("plus.circle")
                               .SetAction(NewAction("add", {}, "").AddInput("Url", NewInput("磁链接", 1)))
                               .SetSize(17)
        )
        return app.Data()
    end


    local function Choice()
        local arg = self.arg
        global.choiceButton = tostring(arg.id)
        if global.choiceButton == "1" then
            global.urlArg = "all"
        end
        if global.choiceButton == "2" then
            global.urlArg = "downloading"
        end
        if global.choiceButton == "3" then
            global.urlArg = "completed"
        end
        global.listPageArg.type = global.urlArg
        global.listPageArg.offset = 0
        global.listPageArg.firstHash = ""
        return {}
    end

    local function Pause()
        local arg = self.arg
        local cfg = self.config

        local data = string.format("hashes=%s",arg.hash )
        local req = http.request("POST",self.config.HostPort .. global.api.PauseUrl,data)
        local pauseRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end

        return {}
    end

    local function Resume()
        local arg = self.arg
        local cfg = self.config

        local data = string.format("hashes=%s",arg.hash )
        local req = http.request("POST",self.config.HostPort .. global.api.ResumeUrl,data)
        local pauseRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end

        return {}
    end

    local function Delete()
        local arg = self.arg
        local cfg = self.config

        local data = string.format("hashes=%s&deleteFiles=%s",arg.hash,arg.clean)
        local req = http.request("POST",self.config.HostPort .. global.api.DeleteUrl,data)
        local pauseRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end

        return NewToast("删除成功","trash","#F00")
    end

    local function Search()
        local input = self.input
        local cfg = self.config
        local data = string.format("pattern=%s&plugins=enabled&category=all",input.Key )
        local req = http.request("POST",self.config.HostPort .. global.api.SearchUrl,data)
        local searchRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        global.searchTaskId = json.decode(searchRsp.body).id
        return {}
    end

    local function StopSearch()
        local arg = self.arg
        local cfg = self.config

        local data = string.format("id=%s",tostring(global.searchTaskId))
        local req = http.request("POST",self.config.HostPort .. global.api.StopSearchUrl,data)
        local searchRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        global.searchTaskId = 0
        return NewToast("停止搜索","stop.circle","#000")
    end

    local function Add()
        local input = self.input
        local cfg = self.config
        local data = string.format("urls=%s&savepath=/downloads", input.Url)
        local req = http.request("POST",self.config.HostPort .. global.api.AddUrl,data)
        local addRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        return NewToast("添加下载成功","info.circle","#000")
    end

    local function Download()
        local arg = self.arg
        local cfg = self.config

        local data = string.format("urls=%s&savepath=/downloads", arg.Url)
        local req = http.request("POST",self.config.HostPort .. global.api.AddUrl,data)
        local addRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        return NewToast("添加下载成功","info.circle","#000")
    end


    function escapePattern(text)
        return text:gsub("([^%w])", "%%%1")
    end

    function self:ChangePriority()
        local data = string.format("hash=%s&id=%s&priority=%s", self.arg.hash,self.arg.index,self.input.Priority)
        local req = http.request("POST",self.config.HostPort .. global.api.FilePrio,data)
        local addRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        return NewToast("修改优先级成功:"..global.priorityMap[self.input.Priority],"info.circle","#000")
    end

    function self:PeersCountry()
        local data = string.format("?hash=%s",tostring(self.arg.hash))
        local req = http.request("GET",self.config.HostPort .. global.api.Peers .. data)
        local detailRsp,err = httpClient:do_request(req)
        if detailRsp.code == 403 then
            updateCookie()
            detailRsp,err = httpClient:do_request(req)
            if err then
                error(err)
            end
        end
        local peers = json.decode(detailRsp.body)
        local afterFilter = {}
        for key, value in pairs(peers.peers) do
            if value.country == self.arg.country and value.dl_speed > 0 then
                table.insert(afterFilter, value)
            end
        end

        table.sort(afterFilter,function (a, b)
            return a.dl_speed > b.dl_speed
        end)

        local page = NewPage()
        local userSection = NewPageSection("用户")
        local fontSize = 10
        for index, value in ipairs(afterFilter) do
            userSection.AddUiRow(
                    NewUiRow().AddUi(
                            NewProcessLineUi().SetDesc(
                                    NewText("leading").AddString(
                                            1,
                                            NewString(value.ip..":"..tostring(value.port)).SetFontSize(fontSize)
                                    ).AddString(
                                            1,
                                            NewString(value.connection).SetFontSize(fontSize)
                                    ).AddString(
                                            1,
                                            NewString(value.client).SetFontSize(fontSize)
                                    )
                            ).SetProcessData(
                                    NewProcessData(value.progress,1)
                            ).SetTitle(
                                    NewText("trailing").AddString(
                                            1,
                                            NewString(ByteToUiString(value.dl_speed).."/S").SetColor(global.downloadFontColor).SetFontSize(fontSize)
                                    )
                            ).AddAction(
                                    NewAction("",{},"复制ip").SetCopyAction(value.ip..":"..tostring(value.port))
                            )
                    )
            )
        end
        return page.AddPageSection(userSection).Data()
    end

    function self:TorrentDetail()
        local page = NewPage()
        local torrentDetail = {}
        local files = {}
        local peers = {}
        local trackers = {}
        goAndWait({
            getDetail = function ()
                local data = string.format("?hash=%s",tostring(self.arg.hash))
                local req = http.request("GET",self.config.HostPort .. global.api.TorrentDetail .. data)
                local detailRsp,err = httpClient:do_request(req)
                if detailRsp.code == 403 then
                    updateCookie()
                    detailRsp,err = httpClient:do_request(req)
                    if err then
                        error(err)
                    end
                end
                torrentDetail = json.decode(detailRsp.body)
            end,
            files = function ()
                local data = string.format("?hash=%s",tostring(self.arg.hash))
                local req = http.request("GET",self.config.HostPort .. global.api.Files .. data)
                local detailRsp,err = httpClient:do_request(req)
                if detailRsp.code == 403 then
                    updateCookie()
                    detailRsp,err = httpClient:do_request(req)
                    if err then
                        error(err)
                    end
                end
                files = json.decode(detailRsp.body)
            end,
            peers = function ()
                local data = string.format("?hash=%s",tostring(self.arg.hash))
                local req = http.request("GET",self.config.HostPort .. global.api.Peers .. data)
                local detailRsp,err = httpClient:do_request(req)
                if detailRsp.code == 403 then
                    updateCookie()
                end
                peers = json.decode(detailRsp.body)
            end,
            trackers = function ()
                local data = string.format("?hash=%s",tostring(self.arg.hash))
                local req = http.request("GET",self.config.HostPort .. global.api.Trackers .. data)
                local detailRsp,err = httpClient:do_request(req)
                if detailRsp.code == 403 then
                    updateCookie()
                    detailRsp,err = httpClient:do_request(req)
                    if err then
                        error(err)
                    end
                end
                trackers = json.decode(detailRsp.body)
            end
        })

        local fontSize = 16
        local contentSection = NewPageSection("内容")
        for index, value in ipairs(files) do
            contentSection.AddUiRow(
                    NewUiRow().AddUi(
                            NewProcessLineUi().SetDesc(
                                    NewText("leading").AddString(
                                            1,
                                            NewString(string.gsub(value.name, escapePattern(torrentDetail.name), "", 1))
                                                    .SetFontSize(10)
                                    ).AddString(
                                            2,
                                            NewString(ByteToUiString(value.size))
                                                    .SetColor(global.fontColor)
                                                    .SetFontSize(10)
                                    ).AddString(
                                            2,
                                            NewString(string.format("%.2f%%",value.progress*100))
                                                    .SetColor(global.fontColor)
                                                    .SetFontSize(10)
                                    ).AddString(
                                            2,
                                            NewString(global.priorityMap[tostring(value.priority)])
                                            -- .SetColor(global.fontColor)
                                                    .SetFontSize(10)
                                    )
                            ).SetProcessData(
                                    NewProcessData(value.progress*100,100)
                            )
                                              .AddAction(
                                    NewAction("changePriority",{hash=self.arg.hash,index=value.index},"修改下载优先级")
                                            .AddInput(
                                            "Priority",
                                            NewInput("优先级","1")
                                                    .AddList("不下载", "0")
                                                    .AddList("正常", "1")
                                                    .AddList("较高", "6")
                                                    .AddList("最高", "7")
                                    )
                            )
                    )
            )
        end

        local data = {}
        for key, value in pairs(peers.peers) do
            if data[value.country] == nil then
                data[value.country] = {
                    country = value.country,
                    dl_speed = 0,
                    peers = {},
                }
            end
            data[value.country].dl_speed = data[value.country].dl_speed+value.dl_speed
            table.insert(data[value.country].peers, value)
        end

        local afterFilter = {}
        for key, value in pairs(data) do
            if value.dl_speed > 0 then
                table.insert(afterFilter, value)
            end
        end
        table.sort(afterFilter, function (a, b)
            return a.dl_speed > b.dl_speed
        end)
        data = afterFilter
        local peersSection = NewPageSection("用户")
        local row = NewUiRow()
        local index = 1
        for i, value in ipairs(data) do
            local key = value.country
            row.AddUi(
                    NewTextUi().SetText(
                            NewText("").AddString(
                                    1,
                                    NewString(ByteToUiString(value.dl_speed).."/S")
                                            .SetFontSize(fontSize)
                                            .SetColor(global.downloadFontColor)
                            ).AddString(
                                    2,
                                    NewString(key)
                            )
                    ).SetPage("qbittorrent","peersCountry",{hash=self.arg.hash, country=key},key.."用户")
            )
            if index % 4 == 0 then
                peersSection.AddUiRow(row)
                row = NewUiRow()
            end
            index = index + 1
        end

        local trackersSection = NewPageSection("Tracker")
        table.sort(trackers,function (a, b)
            return a.num_peers > b.num_peers
        end)
        for index, value in ipairs(trackers) do
            if value.status == 2 then
                trackersSection.AddUiRow(
                        NewUiRow().AddUi(
                                NewProcessLineUi().SetDesc(
                                        NewText("leading").AddString(
                                                1,
                                                NewString(value.url).SetFontSize(10)
                                        ).AddString(
                                                2,
                                        -- 用户
                                                NewString("用户:").SetFontSize(10)
                                        ).AddString(
                                                2,
                                        -- 用户
                                                NewString(tostring(value.num_peers)).SetFontSize(10)
                                        ).AddString(
                                                2,
                                        -- 用户
                                                NewString(" 种子:").SetFontSize(10)
                                        ).AddString(
                                                2,
                                        -- 种子
                                                NewString(tostring(value.num_seeds)).SetFontSize(10)
                                        ).AddString(
                                                2,
                                        -- 用户
                                                NewString(" 下载:").SetFontSize(10)
                                        ).AddString(
                                                2,
                                        -- 下载
                                                NewString(tostring(value.num_leeches)).SetFontSize(10)
                                        )
                                )
                                                  .AddAction(
                                        NewAction("",{},"复制url").SetCopyAction(value.url)
                                )
                        )
                )
            end
        end

        page.AddPageSection(
                NewPageSection(self.arg.name)
                        .AddMenu(
                        NewIconButton()
                                .SetIcon("doc.on.doc")
                                .SetAction(
                                NewAction("",{},"复制").SetCopyAction(self.arg.magnet_uri)
                        ).SetSize(14)
                ).AddUiRow(
                        NewUiRow().AddUi(
                                NewTextUi().SetText(
                                        NewText("").AddString(
                                                1,
                                                NewString(ByteToUiString(torrentDetail.dl_speed).."/S")
                                                        .SetColor(global.downloadFontColor)
                                                        .SetFontSize(fontSize)
                                        ).AddString(
                                                2,
                                                NewString("下载速度")
                                        )
                                )
                        ).AddUi(
                                NewTextUi().SetText(
                                        NewText("").AddString(
                                                1,
                                                NewString(ByteToUiString(torrentDetail.up_speed).."/S")
                                                        .SetColor(global.upFontColor)
                                                        .SetFontSize(fontSize)
                                        ).AddString(
                                                2,
                                                NewString("上传速度")
                                        )
                                )
                        ).AddUi(
                                NewTextUi().SetText(
                                        NewText("").AddString(
                                                1,
                                                NewString(ByteToUiString(torrentDetail.total_downloaded))
                                                        .SetColor(global.fontColor)
                                                        .SetFontSize(fontSize)
                                        ).AddString(
                                                2,
                                                NewString("已下载")
                                        )
                                )
                        ).AddUi(
                                NewTextUi().SetText(
                                        NewText("").AddString(
                                                1,
                                                NewString(ByteToUiString(torrentDetail.total_size))
                                                        .SetColor(global.fontColor)
                                                        .SetFontSize(fontSize)
                                        ).AddString(
                                                2,
                                                NewString("总大小")
                                        )
                                )
                        )
                ).AddUiRow(
                        NewUiRow().AddUi(
                                NewProcessLineUi().SetProcessData(
                                        NewProcessData(torrentDetail.total_downloaded,torrentDetail.total_size)
                                ).SetTitle(
                                        NewText("").AddString(
                                                1,
                                                NewString(string.format("%.0f小时%.0f分钟",torrentDetail.eta/3600,(torrentDetail.eta%3600)/60))
                                                        .SetColor(global.fontColor)
                                                        .SetFontSize(10)
                                        )
                                )
                        )
                )
        ).AddPageSection(
                contentSection
        ).AddPageSection(
                peersSection
        ).AddPageSection(
                trackersSection
        )

        return page.Data()
    end


    function self:Next()
        global.listPageArg.offset =  global.listPageArg.offset+global.listPageArg.limit
    end

    function self:Pre()
        global.listPageArg.offset = global.listPageArg.offset-global.listPageArg.limit
        if global.listPageArg.offset < 0 then
            global.listPageArg.offset = 0
        end
    end

    function self:MoreList()
        local page = NewPage()
        if global.listPageArg.type ~= self.arg.type then
            global.listPageArg.offset = 0
        end
        global.listPageArg.type = self.arg.type
        local data = getBittorrentList(global.listPageArg.type,global.listPageArg.offset,global.listPageArg.limit)
        if data.code == 403 then
            updateCookie()
            data = getBittorrentList(global.listPageArg.type,global.listPageArg.offset,global.listPageArg.limit)
        end
        local listSection = NewPageSection("列表")
        local list = json.decode(data.body)
        local hasNext = true
        local isEmpty = true
        if #list == 0 then
            return page.AddPageSection(listSection.AddUiRow(NewUiRow().AddUi(NewTextUi().SetText(NewText("").AddString(1,NewString("无数据").SetColor(global.them.descFontColor)))))).Data()
        end
        for index, value in ipairs(list) do
            if  global.listPageArg.offset == 0 and index == 1 then
                global.listPageArg.firstHash = value.hash
            end
            if global.listPageArg.offset ~= 0 and value.hash == global.listPageArg.firstHash then
                hasNext = false
                break
            end
            isEmpty = false
            listSection.AddUiRow(
                    NewUiRow().AddUi(
                            getBtOneItem(value)
                    )
            )
        end

        if #list < global.listPageArg.limit then
            hasNext = false
        end


        if hasNext then
            listSection.SetNext(
                    NewAction("next",{},"下一页")
            )
        end
        if global.listPageArg.offset > 0 then
            listSection.SetPre(
                    NewAction("pre",{},"上一页")
            )
        end
        if isEmpty then
            self:Pre()
        end
        listSection.SetPageInfo(tostring(global.listPageArg.offset))
                   .AddMenu(
                NewIconButton().SetIcon("plus.circle")
                               .SetAction(NewAction("add", {}, "").AddInput("Url", NewInput("磁链接", 1)))
                               .SetSize(17)
        )

        page.AddPageSection(
                listSection
        )
        return page.Data()
    end


    self.GetUi = GetUi
    self.Choice = Choice
    self.Pause = Pause
    self.Resume = Resume
    self.Delete = Delete
    self.Search = Search
    self.StopSearch = StopSearch
    self.Add = Add
    self.Download = Download
    return self
end

function register()
    initButton()
    return {
    }
end


function update(ctx)
    return NewQBittorrent(ctx).GetUi()
end


function choice(ctx)
    return NewQBittorrent(ctx).Choice()
end


function pause(ctx)
    return NewQBittorrent(ctx).Pause()
end

function resume(ctx)
    return NewQBittorrent(ctx).Resume()
end

function delete(ctx)
    return NewQBittorrent(ctx).Delete()
end

function search(ctx)
    return NewQBittorrent(ctx).Search()
end

function stopSearch(ctx)
    return NewQBittorrent(ctx).StopSearch()
end

function add(ctx)
    return NewQBittorrent(ctx).Add()
end

function download(ctx)
    return NewQBittorrent(ctx).Download()
end

function torrentDetail(ctx)
    return NewQBittorrent(ctx):TorrentDetail()
end

function peersCountry(ctx)
    return NewQBittorrent(ctx):PeersCountry()
end

function changePriority(ctx)
    return NewQBittorrent(ctx):ChangePriority()
end

function moreList(ctx)
    return NewQBittorrent(ctx):MoreList()
end

function next(ctx)
    return NewQBittorrent(ctx):Next()
end

function pre(ctx)
    return NewQBittorrent(ctx):Pre()
end