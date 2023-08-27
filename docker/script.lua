local http = require("http")
local json = require("json")
local time = require("time")
local strings = require("strings")
local httpClient = http.client({
    timeout = 2, -- 超时1s
})
local backendHttpClient = http.client({
    timeout = 300, -- 超时300s
    headers = {["Content-Type"]="application/x-www-form-urlencoded"},
    --headers = {["Content-Type"]="application/json"},
})

local global = {
    api = {
        containersList = "/containers/json?all=1",
        containersStatsFormat = "/containers/%s/stats?stream=false&one-shot=true",
        stopContainer = "/containers/%s/stop?t=1",
        restartContainer = "/containers/%s/restart?t=1",
        startContainer = "/containers/%s/start?t=1",
        deleteContainer = "/containers/%s",
        deleteImage = "/images/%s",
        imageList = "/images/json?all=true",
        searchImage = "/images/search?term=%s",
        pullImage = "/images/create",
    },
    containerState = {},
    updateStateTs = 0,
    menu = 0, -- 0 容器 1 镜像
    searchKey = "",
    searchResult = {},
}

function asyncDoRequest(method,url,data)
    req = http.request(method,url,data)
    local rsp,err = httpClient:do_request(req)
    if err then
        error(err)
    end
    return rsp
end

function asyncDoRequestWithBackendClient(method,url,data)
    req = http.request(method,url,data)
    local rsp,err = backendHttpClient:do_request(req)
    if err then
        error(err)
    end
    return rsp
end

function string.split(input, delimiter)
    input = tostring(input)
    delimiter = tostring(delimiter)
    if (delimiter=='') then return false end
    local pos,arr = 0, {}
    for st,sp in function() return string.find(input, delimiter, pos, true) end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end

---@param ctx Ctx
---@return Docker
function NewDocker(ctx)
    ---@class Docker
    local self = {
        arg = ctx.arg,
        input = ctx.input,
        config = ctx.config,
        runCtx = ctx.ctx,
    }

    function getStats(c)
        req = http.request("GET",string.format(self.config.HostPort..global.api.containersStatsFormat,c.Id))
        local stateRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        return json.decode(stateRsp.body)
    end

    ---@param app AppUI
    function getContainersStats(app)
        req = http.request("GET",self.config.HostPort..global.api.containersList)
        local stateRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end

        local data = json.decode(stateRsp.body)
        index = 0
        text = NewText("leading").AddString(1,NewString("状态").SetFontSize(10).SetOpacity(0.5))
        app.AddUi(index,NewTextUi().SetText(text).SetHeight(8))
        text = NewText("leading").AddString(1,NewString("名字").SetFontSize(10).SetOpacity(0.5))
        app.AddUi(index,NewTextUi().SetText(text).SetHeight(8))
        local index = 1
        local height = 50
        for i = 1, #data do
            local c = data[i]
            image = NewString(c.Image).SetFontSize(8).SetBackendColor("#339999").SetColor("#FFF")

            color = "#000"
            if c.State ~= "running" then
                color = "#F00"
                image.SetBackendColor("#F00")
            end
            state = NewString(c.State).SetFontSize(12).SetColor(color)
            status = NewString(c.Status).SetFontSize(8).SetColor(color).SetOpacity(0.5)
            app.AddUi(index,NewTextUi()
                    .SetText(NewText("").AddString(1,state).AddString(2,status))
                    .SetHeight(height))
            name = NewString(string.sub(c.Names[1],2,string.len(c.Names[1])))
                    .SetFontSize(12)
                    .SetColor(color)
            nameText = NewText("").AddString(1,name).AddString(2,image)
            nameAndOp = NewTextUi()
                    .SetText(nameText)
                    .AddAction(NewAction("restart",{id=c.Id},"重启"))
                    .SetHeight(height)
            if c.State ~= "running" then
                nameAndOp.AddAction(NewAction("start",{id=c.Id},"启动"))
                nameAndOp.AddAction(NewAction("deleteContainer",{id=c.Id},"删除").SetCheck(true))
            else
                nameAndOp.AddAction(NewAction("stop",{id=c.Id},"停止"))
            end
            app.AddUi(index,nameAndOp)
            if i%1 == 0 then
                index = index+1
            end
        end
    end

    ---@param app AppUI
    function getImageList(app)
        req = http.request("GET",self.config.HostPort..global.api.imageList)
        local stateRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        local height = 35
        local data = json.decode(stateRsp.body)
        index = 1
        for i = 1, #data do
            local c = data[i]
            size = NewString(ByteToUiString(c.Size)).SetFontSize(8).SetOpacity(0.5)
            nameAndVersion = string.split("name:none",":")
            if type(c.RepoTags) == "table" then
                nameAndVersion = string.split(c.RepoTags[1],":")
            end
            nameText = NewText("")
                    .AddString(1,NewString(nameAndVersion[1]).SetFontSize(10))
                    .AddString(2,NewString(nameAndVersion[2]).SetFontSize(8)
                                                             .SetBackendColor("#336699").SetColor("#FFF"))
                    .AddString(2,NewString(ByteToUiString(c.Size)).SetFontSize(8).SetBackendColor("#339999").SetColor("#FFF"))
            nameAndOp = NewTextUi()
                    .SetText(nameText)
                    .AddAction(NewAction("delete",{id=c.Id},"删除")
                    .SetCheck(true)
            )
            -- .SetHeight(height)

            app.AddUi(index,nameAndOp)
            if i%3 == 0 then
                index = index+1
            end
        end
    end

    function self:Stop()
        local url = string.format(self.config.HostPort..global.api.stopContainer,self.arg.id)
        go("asyncDoRequest",function()

        end,"POST",url,"")
        return NewToast("暂停成功","info.circle","#000")
    end

    function self:Restart()
        local url = string.format(self.config.HostPort..global.api.restartContainer, self.arg.id)
        go("asyncDoRequest",function()

        end,"POST",url,"")
        return NewToast("重启成功","info.circle","#000")
    end

    function self:Start()
        local url = string.format(self.config.HostPort..global.api.startContainer,self.arg.id)
        go("asyncDoRequest",function()

        end,"POST",url,"")
        return NewToast("启动成功","info.circle","#000")
    end

    -- @param app: AppUI
    function getSearchResult(app)
        local index = 1
        for i = 1, #global.searchResult do
            local s = global.searchResult[i]
            nameText = NewText("")
                    .AddString(1,NewString(s.name).SetFontSize(12))
                    .AddString(2,NewString(tostring(s.star_count).." star").SetFontSize(10).SetOpacity(0.8))
            --.AddString(3,NewString(tostring(s.description)).SetFontSize(10).SetOpacity(0.8))
            descriptionText = NewText("")
                    .AddString(1,NewString(s.description).SetFontSize(10).SetOpacity(0.8))
            app.AddUi(index,NewTextUi()
                    .SetText(descriptionText).SetHeight(50))
            app.AddUi(index,NewTextUi()
                    .SetText(nameText).SetHeight(50).AddAction(NewAction("pull",{name=s.name},"拉取镜像")))
            if i%1 == 0 then
                index = index+1
            end
        end
    end

    function self:GetUi()
        local app = NewApp()
        local buttonSize = 17
        imageMenu = NewIconButton().SetIcon("shippingbox.circle")
                                   .SetAction(NewAction("changeMenu", {id=1}, ""))
                                   .SetSize(buttonSize)
        containerMenu = NewIconButton().SetIcon("play.circle")
                                       .SetAction(NewAction("changeMenu", {id=0}, ""))
                                       .SetSize(buttonSize)
        searchButton = NewIconButton().SetIcon("magnifyingglass.circle")
                                      .SetAction(NewAction("search", {}, "").AddInput("Key", NewInput("镜像关键字", 1)))
                                      .SetSize(buttonSize)
        if global.searchKey ~= "" then
            searchButton.SetIcon("stop.circle").SetAction(NewAction("stopSearch", {}, ""))
                        .SetColor("#F00")
        end
        app.AddMenu(searchButton)
        app.AddMenu(imageMenu)
        app.AddMenu(containerMenu)
        if global.searchKey ~= "" then
            getSearchResult(app)
            -- 搜索优先级高，提前返回
            return app.Data()
        end

        if global.menu == 0 then
            containerMenu.SetColor("#F00")
            getContainersStats(app)
        else
            imageMenu.SetColor("#F00")
            getImageList(app)
        end
        local markdown = [[
# docker 管理

## 配置
### 接口
- 指定ip和端口 `http://127.0.0.1:6666`

## 功能
### 镜像
- 搜索
- 拉取
### 容器
- 启动
- 运行
- 停止

```yaml
name: docker
enable: true
priority: 80
height: 6
padding: 3
extend:
  HostPort:
    val: "http://127.0.0.1:6666"
    desc: 接口
    priority: 200
```

![img](https://plugin.codeloverme.cn/qbittorrent/qbittorrent.jpg)
        ]]
        app.AddUi(100,NewMarkdownUi().SetMarkdown(markdown))

        return app.Data()
    end

    function self:ChangeMenu()
        global.menu = tonumber(self.arg.id)
    end

    function self:DeleteImage()
        local url = string.format(self.config.HostPort..global.api.deleteImage,self.arg.id)
        go("asyncDoRequest",function()
        end,"DELETE",url,"")
        print("delete image ------",self.arg.id)
    end

    function self:DeleteContainer()
        print("delete Container ------",self.arg.id)
        local url = string.format(self.config.HostPort..global.api.deleteContainer,self.arg.id)
        go("asyncDoRequest",function()
        end,"DELETE",url,"")
    end

    function self:Search()
        print("search-----",self.input.Key)
        global.searchKey = self.input.Key
        ::continue::
        if global.searchKey == "" then
            return
        end

        function callback(rsp)
            if rsp.code ~= 200 then
                print("search retry",url,";")
                return
            end
            print("search result---",url,json.encode(rsp))
            global.searchResult = json.decode(rsp.body)
            table.sort(global.searchResult,function(a, b)
                return a.star_count > b.star_count
            end)
        end

        local url = string.format(self.config.HostPort..global.api.searchImage,strings.trim_space(global.searchKey))
        go("asyncDoRequestWithBackendClient",callback,"GET",url,"")
    end

    function self:StopSearch()
        global.searchKey = ""
        global.searchResult = {}
    end

    function self:Pull()
        local url = self.config.HostPort .. global.api.pullImage
        local data = string.format("fromImage=%s:latest",self.arg.name)
        go("asyncDoRequestWithBackendClient",function()
        end,"POST",url,data)
        return {}
    end

    return self
end


function register()
    return {
    }
end


function update(ctx)
    return NewDocker(ctx):GetUi()
end


function stop(ctx)
    return NewDocker(ctx):Stop()
end

function restart(ctx)
    return NewDocker(ctx):Restart()
end

function start(ctx)
    return NewDocker(ctx):Start()
end

function changeMenu(ctx)
    return NewDocker(ctx):ChangeMenu()
end

function delete(ctx)
    return NewDocker(ctx):DeleteImage()
end

function deleteContainer(ctx)
    return NewDocker(ctx):DeleteContainer()
end

function search(ctx)
    return NewDocker(ctx):Search()
end

function stopSearch(ctx)
    return NewDocker(ctx):StopSearch()
end

function pull(ctx)
    return NewDocker(ctx):Pull()
end