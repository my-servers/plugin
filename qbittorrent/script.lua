local json = require("json")
local http = require("http")
local httpClient = http.client({
    timeout = 1, -- 超时1s
    headers = {["Content-Type"]="application/x-www-form-urlencoded"},
})

local global = {
    cookie = "",
    choiceButton = "2",
    urlArg = "?filter=downloading",
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
        SearchUrl = "/api/v2/search/start",
        AddUrl = "/api/v2/torrents/add",
        SearchResultUrl = "/api/v2/search/results",
        StopSearchUrl = "/api/v2/search/stop",
    }
}

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

    ---@param app AppUI
    local function setMenu(app)
        buttonSize = 17
        addTorrentButton = NewIconButton().SetIcon("plus.circle")
                                          .SetAction(NewAction("add", {}, "").AddInput("Url", NewInput("磁链接", 1)))
                                          .SetSize(buttonSize)
        searchButton = NewIconButton().SetIcon("magnifyingglass.circle")
                                      .SetAction(NewAction("search", {}, "").AddInput("Key", NewInput("搜索关键字", 1)))
                                      .SetSize(buttonSize)
        allBtButton = NewIconButton().SetIcon("list.bullet.circle")
                                     .SetAction(NewAction("choice", { id = 1 }, ""))
                                     .SetSize(buttonSize)
                                     .SetColor(global.choiceButton == "1" and global.blue or global.black)

        downloadingBtButton = NewIconButton().SetIcon("arrow.down.circle")
                                             .SetAction(NewAction("choice", { id = 2 }, ""))
                                             .SetSize(buttonSize)
                                             .SetColor(global.choiceButton == "2" and global.blue or global.black)
        finishBtButton = NewIconButton().SetIcon("checkmark.circle")
                                        .SetAction(NewAction("choice", { id = 3 }, ""))
                                        .SetSize(buttonSize)
                                        .SetColor(global.choiceButton == "3" and global.blue or global.black)
        app.AddMenu(addTorrentButton)
        if global.searchTaskId ~= 0 then
            searchStopButton = NewIconButton().SetIcon("stop.circle")
                                              .SetAction(NewAction("stopSearch", {}, ""))
                                              .SetSize(buttonSize)
                                              .SetColor("#F00")
            app.AddMenu(searchStopButton)
        else
            app.AddMenu(searchButton)
        end
        app.AddMenu(allBtButton)
        app.AddMenu(downloadingBtButton)
        app.AddMenu(finishBtButton)
    end

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

    local function getBittorrentList()
        req = http.request("GET",self.config.HostPort .. global.api.Url .. global.urlArg)
        loginRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        return loginRsp
    end

    local function genDetail(d)
        return string.format([[
#### %s
|  项   | 值  |
|  ----  | ----  |
| 下载目录  | %s |
| hash  | %s |
| 已下载  | %s |
| 总大小  | %s |
| 创建时间  | %s |
| 下载完成时间  | %s |
| 上次活跃时间  | %s |
        ]],d.name,d.content_path,d.infohash_v1,
                ByteToUiString(d.downloaded),ByteToUiString(d.total_size),
                os.date("%Y/%m/%d %H:%M:%S", d.added_on),
                os.date("%Y/%m/%d %H:%M:%S", d.completion_on),
                os.date("%Y/%m/%d %H:%M:%S", d.last_activity))
    end

    local function handleBittorrentList(app)
        -- 周期获取数据
        local config = self.config
        local data = getBittorrentList()
        if data.code == 403 then
            updateCookie(config)
            data = getBittorrentList()
        end
        local list = json.decode(data.body)
        local index = 2
        local col = 0
        for i = 1, #list do
            local d = list[i]
            local state = NewString(string.format("↓%s/S ↑%s/S", ByteToUiString(d.dlspeed), ByteToUiString(d.upspeed)))
                    .SetFontSize(8)
            if global.stateMsg[d.state] ~= nil then
                state.SetContent(global.stateMsg[d.state])
            end
            line = NewProcessLineUi()
                    .SetDesc(NewText("leading")
                    .AddString(1, NewString(string.sub(d.name, 0, tonumber(config.NameLen)))
                    .SetFontSize(10))
                    .AddString(2, NewString(string.format("%s", ByteToUiString(d.total_size)))
                    .SetFontSize(8)
                    .SetBackendColor("#663366")
                    .SetColor("#FFF")
            )
                    .AddString(2, state.SetBackendColor("#333366")
                                       .SetColor("#FFF")))
                    .SetTitle(NewText("")
                    .AddString(1, NewString(string.format("%.2f%%", d.completed * 100 / d.total_size))
                    .SetFontSize(8)))
                    .SetProcessData(NewProcessData(d.completed, d.total_size))
            if d.state == "pausedDL" or d.state == "pausedUP" then
                line.AddAction(NewAction("resume", { hash = d.hash }, "继续").SetIcon("play.circle"))
            else
                line.AddAction(NewAction("pause", { hash = d.hash }, "暂停").SetIcon("pause.circle"))
            end
            line.AddAction(NewAction("delete", { hash = d.hash,clean = "false" }, "删除").SetIcon("trash.circle").SetCheck(true))
            line.AddAction(NewAction("delete", { hash = d.hash,clean = "true" }, "删除并清理文件").SetIcon("trash.circle").SetCheck(true))
            line.SetDetail(genDetail(d))
                .SetPage("","torrentDetail",d,"Torrent详情")
            app.AddUi(index, line)
            col = col + 1
            if col % tonumber(config.ColNum) == 0 then
                index = index + 1
            end
        end
    end

    local function GetUi()
        local app = NewApp()
        setMenu(app)
        if global.searchTaskId == 0 then
            handleBittorrentList(app)
        else
            handleSearchList(app)
        end
        return app.Data()
    end


    local function Choice()
        local arg = self.arg
        global.choiceButton = tostring(arg.id)
        if global.choiceButton == "1" then
            global.urlArg = "?filter=all"
        end
        if global.choiceButton == "2" then
            global.urlArg = "?filter=downloading"
        end
        if global.choiceButton == "3" then
            global.urlArg = "?filter=completed"
        end
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
        local fontColor = "#FF00FF"
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
                                            NewString(ByteToUiString(value.dl_speed).."/S").SetColor(fontColor).SetFontSize(fontSize)
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


        local fontColor = "#FF00FF"
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
                                                    .SetColor(fontColor)
                                                    .SetFontSize(10)
                                    )
                                                      .AddString(
                                            2,
                                            NewString(string.format("%.2f%%",value.progress))
                                                    .SetColor(fontColor)
                                                    .SetFontSize(10)
                                    )
                            ).SetProcessData(
                                    NewProcessData(value.progress*100,100)
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
                                            .SetColor(fontColor)
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
                                                        .SetColor(fontColor)
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
                                                        .SetColor(fontColor)
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
                                                        .SetColor(fontColor)
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
                                                        .SetColor(fontColor)
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
                                                        .SetColor(fontColor)
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