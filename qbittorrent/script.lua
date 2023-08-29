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
        print("update cookie---------",json.encode(loginRsp),data)
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
            line.AddAction(NewAction("delete", { hash = d.hash }, "删除").SetIcon("trash.circle").SetCheck(true))
            line.SetDetail(genDetail(d))
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

        local data = string.format("hashes=%s&deleteFiles=false",arg.hash )
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
