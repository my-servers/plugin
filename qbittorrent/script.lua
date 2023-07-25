local json = require("json")

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
        loginRsp = net.Post(self.config.HostPort .. global.api.LoginUrl, {}, { username = self.config.Username, password = self.config.Password },
                "form")
        global.cookie = loginRsp.header["Set-Cookie"]
    end

    local function getSearchResult()
        cfg = self.config
        data = net.Post(cfg.HostPort .. global.api.SearchResultUrl, { Cookie = global.cookie },
                { id = global.searchTaskId, limit = tonumber(cfg.SearchNum) }, "form")
        table.sort(data.data.results, function(a, b)
            return a.nbSeeders * 1000000000000 + a.fileSize > b.nbSeeders * 1000000000000 + b.fileSize
        end)
        return data
    end


    ---@param app AppUI
    local function handleSearchList(app)
        -- 周期获取数据
        -- 周期获取数据
        config = ctx.config
        data = getSearchResult()
        if data.ret == 403 then
            updateCookie()
            data = getSearchResult()
        end
        print("search--------------", json.encode(data))
        list = data.data.results
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
            text = NewText("").SetAlignment("leading")
            text.AddString(1, NewString(string.sub(list[i].fileName, 0, 100)).SetFontSize(10))
            text.AddString(1, NewString(ByteToUiString(list[i].fileSize)).SetFontSize(10))
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
        return net.Get(self.config.HostPort .. global.api.Url .. global.urlArg, { Cookie = global.cookie }, {})
    end

    local function updateCookie()
        loginRsp = net.Post(self.config.HostPort .. global.api.LoginUrl, {}, { username = self.config.Username, password = self.config.Password },
                "form")
        global.cookie = loginRsp.header["Set-Cookie"]
    end


    local function getSearchResult()
        cfg = self.config
        data = net.Post(cfg.HostPort .. global.api.SearchResultUrl, { Cookie = global.cookie },
                { id = global.searchTaskId, limit = tonumber(cfg.SearchNum) }, "form")
        table.sort(data.data.results, function(a, b)
            return a.nbSeeders * 1000000000000 + a.fileSize > b.nbSeeders * 1000000000000 + b.fileSize
        end)
        return data
    end

    local function handleBittorrentList(app)
        -- 周期获取数据
        local config = self.config
        data = getBittorrentList()
        if data.ret == 403 then
            updateCookie(config)
            data = getBittorrentList()
        end

        local index = 2
        local col = 0
        for i = 1, #data.data do
            d = data.data[i]
            state = NewString(string.format("↓%s/S ↑%s/S", ByteToUiString(d.dlspeed), ByteToUiString(d.upspeed)))
                    .SetFontSize(10)
            if global.stateMsg[d.state] ~= nil then
                state.SetContent(global.stateMsg[d.state])
            end
            line = NewProcessLineUi().SetDesc(NewText("leading").AddString(1,
                    NewString(string.sub(d.name, 0, tonumber(config.NameLen))).SetFontSize(10).SetOpacity(0.5))
                                                                .AddString(2, NewString(string.format("%s", ByteToUiString(d.total_size))).SetFontSize(10))
                                                                .AddString(3, state))
                                     .SetTitle(NewText("").AddString(1,
                    NewString(string.format("%.2f%%", d.completed * 100 / d.total_size)).SetFontSize(8)))
                                     .SetProcessData(NewProcessData(d.completed, d.total_size))
            if d.state == "pausedDL" or d.state == "pausedUP" then
                line.AddAction(NewAction("resume", { hash = d.hash }, "继续").SetIcon("play.circle"))
            else
                line.AddAction(NewAction("pause", { hash = d.hash }, "暂停").SetIcon("pause.circle"))
            end
            line.AddAction(NewAction("delete", { hash = d.hash }, "删除").SetIcon("trash.circle").SetCheck(true))
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
        arg = self.arg
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
        arg = self.arg
        cfg = self.config
        net.Post(cfg.HostPort .. global.api.PauseUrl, { Cookie = global.cookie }, { hashes = arg.hash }, "form")
        return {}
    end

    local function Resume()
        arg = self.arg
        cfg = self.config
        net.Post(cfg.HostPort .. global.api.ResumeUrl, { Cookie = global.cookie }, { hashes = arg.hash }, "form")
        return {}
    end

    local function Delete()
        arg = self.arg
        cfg = self.config
        net.Post(cfg.HostPort .. global.api.DeleteUrl, { Cookie = global.cookie }, { hashes = arg.hash, deleteFiles = false }, "form")
        return {}
    end

    local function Search()
        input = self.input
        cfg = self.config
        data = net.Post(cfg.HostPort .. global.api.SearchUrl, { Cookie = global.cookie },
                { pattern = input.Key, plugins = "enabled", category = "all" }, "form")
        global.searchTaskId = data.data.id
        return {}
    end

    local function StopSearch()
        arg = self.arg
        cfg = self.config
        data = net.Post(cfg.HostPort .. global.api.StopSearchUrl, { Cookie = global.cookie }, { id = global.searchTaskId }, "form")
        global.searchTaskId = 0
        print("stop--------------", json.encode(data))
        return {}
    end

    local function Add()
        input = self.input
        cfg = self.config
        data = net.Post(cfg.HostPort .. global.api.AddUrl, { Cookie = global.cookie }, { urls = input.Url, savepath = "/downloads" },
                "form")
        return {}
    end

    local function Download()
        arg = self.arg
        cfg = self.config
        data = net.Post(cfg.HostPort .. global.api.AddUrl, { Cookie = global.cookie }, { urls = arg.Url, savepath = "/downloads" }, "form")
        return {}
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
