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
        systemInfo = "/info",
        containersListFilter = "/containers/json?filters=%s",
        containersInspect = "/containers/%s/json",
    },
    them = {
        systemInfoNumFrontSize = 24,
        allContainersColor = "#000",
        allRunningContainersColor = "#6348f2",
        allPausedContainersColor = "#4dbf7a",
        allStoppedontainersColor = "#ff4f00",
        systemInfoDescFontColor = "#b8b8b8",
        containerListFontColor = "#000",
        containerImageFontColor = "#b8b8b8",
    },
    -- 容器的cpu
    containerCpu = {
        curContainer = "",
        -- 每个cpu窗口
        perWindown = {},
        -- 总的cpu的窗口
        totalWindown = {},
        oldData = {
            cpu_usage = {
                cpu_usage = {
                    total_usage = 0,
                }
            },
            system_cpu_usage = 0,
        },
        preTs = 0,
    },
    containersPage = {
        curType = "running",
        stateMap = {
            ["running"] = "运行中",
            ["paused"] = "暂停",
            ["exited"] = "停止",
            ["all"] = "全部",
        },
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
        return {}
    end
    return rsp
end

function asyncDoRequestWithBackendClient(method,url,data)
    req = http.request(method,url,data)
    local rsp,err = backendHttpClient:do_request(req)
    if err then
        return {}
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

    function getContainersDetail(c)
        local detail = string.format([[
|  项   | 值  |
|  ----  | ----  |
| 容器id  | %s |
| 容器名  | %s |
| 镜像  | %s |
| 命令  | `%s` |
| 状态  | `%s` |
| 网络模式  | %s |
]],
                c.Id,
                string.join(c.Names,"<br>"),
                c.Image,
                c.Command,
                c.State,
                c.HostConfig.NetworkMode
        )
        for i = 1, #c.Ports do
            local p = c.Ports[i]
            detail = detail .. string.format([[| 端口  | `%s`:`%s`->`%s` |
]],p.Type,tostring(p.PrivatePort),tostring(p.PublicPort))
        end
        for i = 1, #c.Mounts do
            local m = c.Mounts[i]
            detail = detail .. string.format([[| 目录映射  | `%s`->`%s` |
]],m.Source,m.Destination)
        end
        return detail
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
            nameAndOp.AddAction(NewAction("",{},"容器日志").SetTerminalAction("docker logs -n 10 -f " .. c.Id.." \n"))
            nameAndOp.AddAction(NewAction("",{},"登陆容器").SetTerminalAction("docker exec -it " .. c.Id .. " sh \n"))
            app.AddUi(index,nameAndOp.SetDetail(getContainersDetail(c)))
            if i%1 == 0 then
                index = index+1
            end
        end
    end

    function getImageDetail(c)
        local detail = string.format([[
|  项   | 值  |
|  ----  | ----  |
| id  | %s |
| 父id  | %s |
| 创建于  | %s |
| 大小  | `%s` |
| 容器数量  | `%s` |
| tags  | %s |
]],
                c.Id,
                c.ParentId,
                os.date("%Y/%m/%d %H:%M:%S", tonumber(c.Created)),
                ByteToUiString(c.Size),
                tostring(c.Containers),
                string.join(c.RepoTags,"<br>")
        )
        if type(c.RepoDigests) == "table" then
            for i = 1, #c.RepoDigests do
                detail = detail .. string.format([[| 层  | `%s` |
]], c.RepoDigests[i])
            end
        end

        return detail
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
        table.sort(data,function(a, b)
            return tonumber(a.Created) > tonumber(b.Created)
        end)
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
            nameAndOp.SetDetail(getImageDetail(c))
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
        req = http.request("GET",self.config.HostPort..global.api.systemInfo)
        local stateRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        local data = json.decode(stateRsp.body)
        app
                .AddUi(
                1,
                NewTextUi().SetText(
                        NewText("")
                                .AddString(
                                1,
                                NewString(tostring(data.Containers))
                                        .SetFontSize(global.them.systemInfoNumFrontSize)
                                        .SetColor(global.them.allContainersColor)
                        )
                                .AddString(
                                1,
                                NewString("/")
                                        .SetFontSize(global.them.systemInfoNumFrontSize)
                                        .SetColor(global.them.systemInfoDescFontColor)
                        )
                                .AddString(
                                1,
                                NewString(tostring(data.ContainersRunning))
                                        .SetFontSize(global.them.systemInfoNumFrontSize)
                                        .SetColor(global.them.allRunningContainersColor)
                        )
                                .AddString(
                                1,
                                NewString("/")
                                        .SetFontSize(global.them.systemInfoNumFrontSize)
                                        .SetColor(global.them.systemInfoDescFontColor)
                        )
                                .AddString(
                                1,
                                NewString(tostring(data.ContainersPaused))
                                        .SetFontSize(global.them.systemInfoNumFrontSize)
                                        .SetColor(global.them.allPausedContainersColor)
                        )
                                .AddString(
                                1,
                                NewString("/")
                                        .SetFontSize(global.them.systemInfoNumFrontSize)
                                        .SetColor(global.them.systemInfoDescFontColor)
                        )
                                .AddString(
                                1,
                                NewString(tostring(data.ContainersStopped))
                                        .SetFontSize(global.them.systemInfoNumFrontSize)
                                        .SetColor(global.them.allStoppedontainersColor)
                        )
                                .AddString(
                                2,
                                NewString("\n容器")
                                        .SetColor(global.them.systemInfoDescFontColor)
                        )
                ).SetPage("docker","containers",{},"容器列表")
        )
                .AddUi(
                1,
                NewTextUi().SetText(
                        NewText("")
                                .AddString(
                                1,
                                NewString(tostring(data.Images))
                                        .SetFontSize(global.them.systemInfoNumFrontSize)
                        )
                                .AddString(
                                2,
                                NewString("\n镜像")
                                        .SetColor(global.them.systemInfoDescFontColor)
                        )
                )
        )

        return app.Data()
    end
    function self:GetUi1()
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
        return NewToast("删除镜像","info.circle","#000")
    end

    function self:DeleteContainer()
        print("delete Container ------",self.arg.id)
        local url = string.format(self.config.HostPort..global.api.deleteContainer,self.arg.id)
        go("asyncDoRequest",function()
        end,"DELETE",url,"")
        return NewToast("删除容器","info.circle","#000")
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
        return NewToast("拉取镜像","info.circle","#000")
    end

    function self:ContainerDetail()
        local page = NewPage()
        local state  = {}
        local inspect = {}
        goAndWait({
            stateKey = function ()
                local url = string.format(self.config.HostPort..global.api.containersStatsFormat,self.arg.Id)
                local req = http.request("GET",url)
                local stateRsp,err = httpClient:do_request(req)
                if err then
                    error(err)
                end
                state = json.decode(stateRsp.body)
            end,
            inspectKey = function ()
                local url = string.format(self.config.HostPort..global.api.containersInspect,self.arg.Id)
                local req = http.request("GET",url)
                local stateRsp,err = httpClient:do_request(req)
                if err then
                    error(err)
                end
                inspect = json.decode(stateRsp.body)
            end
        })
        if inspect.State.Running == false then
            page.AddPageSection(NewPageSection("容器未运行"))
            return page.Data()
        end
        if global.containerCpu.curContainer ~= self.arg.Id then
            global.containerCpu.totalWindown = {}
            global.containerCpu.curContainer = self.arg.Id
        end

        local container_cpu_delta = Tonumber(global.containerCpu.oldData.cpu_usage.total_usage) - Tonumber(state.cpu_stats.cpu_usage.total_usage)
        local system_cpu_delta = (Tonumber(global.containerCpu.oldData.system_cpu_usage) - Tonumber(state.cpu_stats.system_cpu_usage))
        local cpu_usage_percent = (container_cpu_delta / system_cpu_delta) * 100 * Tonumber(state.cpu_stats.online_cpus)
        if cpu_usage_percent < 0 then
            cpu_usage_percent = 0
        end
        if cpu_usage_percent > 100 then
            cpu_usage_percent = 100
        end
        global.containerCpu.oldData = state.cpu_stats
        table.insert(global.containerCpu.totalWindown, cpu_usage_percent)


        print("totalWindown ", json.encode(global.containerCpu.totalWindown))
        local section = NewPageSection(string.sub(self.arg.Command,0 ,30).."...")
        local line = NewLineChartUi()
        for index, value in ipairs(global.containerCpu.totalWindown) do
            line.AddPoint(
                    NewPoint(value,tostring(index))
            )
        end
        local memUse = Tonumber(state.memory_stats.usage)/Tonumber(state.memory_stats.limit)*100

        section.AddUiRow(
                NewUiRow().AddUi(
                        NewProcessCircleUi().SetProcessData(
                                NewProcessData(cpu_usage_percent, 100)
                        )
                                            .SetDesc(
                                NewText("")
                                        .AddString(
                                        1, NewString(string.format("%d核",state.cpu_stats.online_cpus)).SetFontSize(10)
                                )
                                        .AddString(
                                        2, NewString(string.format("%d%%",cpu_usage_percent)).SetFontSize(10)
                                )
                        )
                                            .SetTitle(
                                NewText("").AddString(1,NewString("cpu"))
                        )
                ).AddUi(
                        NewProcessCircleUi().SetProcessData(
                                NewProcessData(memUse, 100)
                        )
                                            .SetDesc(
                                NewText("").AddString(
                                        2, NewString(string.format("%d%%",memUse)).SetFontSize(10)
                                ).AddString(
                                        1, NewString(ByteToUiString(state.memory_stats.limit)).SetFontSize(10)
                                )
                        )
                                            .SetTitle(
                                NewText("").AddString(1,NewString("内存"))
                        )
                )
        ).AddMenu(
                NewIconButton().SetIcon("doc.on.doc").SetAction(
                        NewAction("",{},"").SetCopyAction(self.arg.Command)
                ).SetSize(14)
        )
        -- .AddUiRow(
        --     NewUiRow()
        -- )
        table.sort(inspect.Mounts,function (a, b)
            return a.Source < b.Source
        end)
        local disk = NewPageSection("磁盘挂载")
        for index, value in ipairs(inspect.Mounts) do
            disk.AddUiRow(
                    NewUiRow().AddUi(
                            NewProcessLineUi().SetDesc(
                                    NewText("leading").AddString(
                                            1,
                                            NewString(value.Source)
                                    ).AddString(
                                            3,
                                            NewString(value.Destination).SetColor(global.them.systemInfoDescFontColor)
                                    )
                            ).SetTitle(
                                    NewText("trailing")
                                            .AddString(1, NewString(value.Mode))
                            )
                                              .AddAction(
                                    NewAction("",{},"复制源目录").SetCopyAction(value.Source)
                            ).AddAction(
                                    NewAction("",{},"复制目标目录").SetCopyAction(value.Destination)
                            ).AddAction(
                                    NewAction("",{},"终端打开源目录").SetTerminalAction("cd "..value.Source.."\n")
                            ).AddAction(
                                    NewAction("",{},"容器中打开目标录").SetTerminalAction("docker exec -it "..self.arg.Id.." sh \n cd "..value.Destination.."\n")
                            )
                    )
            )
        end

        local network = NewPageSection("网络 "..inspect.HostConfig.NetworkMode)
        for key, value in pairs(inspect.HostConfig.PortBindings) do
            network.AddUiRow(
                    NewUiRow().AddUi(
                            NewTextUi().SetText(
                                    NewText("").AddString(
                                            1,
                                            NewString(key)
                                    )
                            )
                    )
            )
        end

        section.AddUiRow(
                NewUiRow()
                        .AddUi(
                        line
                )
        )
        page.AddPageSection(
                section
        ).AddPageSection(
                disk
        ).AddPageSection(
                network
        )
        return page.Data()
    end
    function self:ChangeCurChoiceState()
        print("changeCurChoiceState")
        global.containersPage.curType = self.arg.state
    end

    function self:Containers()
        local state = {}
        local list = {}
        goAndWait({
            stateKey = function ()
                local req = http.request("GET",self.config.HostPort..global.api.systemInfo)
                local stateRsp,err = httpClient:do_request(req)
                if err then
                    error(err)
                end
                state = json.decode(stateRsp.body)
            end,
            listKey = function ()
                local url = self.config.HostPort..global.api.containersList
                if global.containersPage.curType ~= "all" then
                    url = string.format(self.config.HostPort..global.api.containersListFilter,json.encode({status={global.containersPage.curType}}))
                end
                local req = http.request("GET", url)
                local stateRsp,err = httpClient:do_request(req)
                if err then
                    error(err)
                end
                list = json.decode(stateRsp.body)
            end
        })
        local page = NewPage()
        local allDesc = NewString("全部").SetColor(global.them.systemInfoDescFontColor)
        if global.containersPage.curType == "all" then
            -- allDesc.SetBackendColor(global.them.allContainersColor)
        end
        local all = NewIconButtonUi().SetIconButton(
                NewIconButton().SetDesc(
                        NewText("")
                                .AddString(
                                1,
                                NewString(tostring(state.Containers)).SetFontSize(global.them.systemInfoNumFrontSize)
                        )
                                .AddString(
                                2,
                                allDesc
                        )
                ).SetAction(
                        NewAction("changeCurChoiceState",{state="all"},"切换状态")
                )
        )
        local runningDesc = NewString("运行中").SetColor(global.them.systemInfoDescFontColor)
        if global.containersPage.curType == "running" then
            -- runningDesc.SetBackendColor(global.them.allRunningContainersColor)
        end
        local running = NewIconButtonUi().SetIconButton(
                NewIconButton().SetDesc(
                        NewText("")
                                .AddString(
                                1,
                                NewString(tostring(state.ContainersRunning))
                                        .SetFontSize(global.them.systemInfoNumFrontSize)
                                        .SetColor(global.them.allRunningContainersColor)
                        )
                                .AddString(
                                2,
                                runningDesc
                        )
                ).SetAction(
                        NewAction("changeCurChoiceState",{state="running"},"切换状态")
                )
        )
        local pausedDesc = NewString("暂停").SetColor(global.them.systemInfoDescFontColor)
        if global.containersPage.curType == "paused" then
            -- pausedDesc.SetBackendColor(global.them.allPausedContainersColor)
        end
        local paused = NewIconButtonUi().SetIconButton(
                NewIconButton()
                        .SetDesc(
                        NewText("")
                                .AddString(
                                1,
                                NewString(tostring(state.ContainersPaused))
                                        .SetFontSize(global.them.systemInfoNumFrontSize)
                                        .SetColor(global.them.allPausedContainersColor)
                        )
                                .AddString(
                                2,
                                pausedDesc
                        )
                ).SetAction(
                        NewAction("changeCurChoiceState",{state="paused"},"切换状态")
                )
        )
        local stopedDesc = NewString("停止").SetColor(global.them.systemInfoDescFontColor)
        if global.containersPage.curType == "exited" then
            -- stopedDesc.SetBackendColor(global.them.allStoppedontainersColor)
        end
        local stoped = NewIconButtonUi().SetIconButton(
                NewIconButton()
                        .SetDesc(
                        NewText("")
                                .AddString(
                                1,
                                NewString(tostring(state.ContainersStopped))
                                        .SetFontSize(global.them.systemInfoNumFrontSize)
                                        .SetColor(global.them.allStoppedontainersColor)
                        )
                                .AddString(
                                2,
                                stopedDesc
                        )
                ).SetAction(
                        NewAction("changeCurChoiceState",{state="exited"},"切换状态")
                )
        )
        -- 容器状态
        page.AddPageSection(
                NewPageSection("容器状态").AddUiRow(
                        NewUiRow()
                                .AddUi(
                                all
                        )
                                .AddUi(
                                running
                        )
                                .AddUi(
                                paused
                        )
                                .AddUi(
                                stoped
                        )
                )
        )
        local section = NewPageSection(global.containersPage.stateMap[global.containersPage.curType])
        for index, value in ipairs(list) do
            local fontColor = global.them.allRunningContainersColor
            if value.State == "paused" then
                fontColor = global.them.allPausedContainersColor
            end
            if value.State == "exited" then
                fontColor = global.them.allStoppedontainersColor
            end
            local name = string.sub(value.Names[1],2,string.len(value.Names[1]))
            local container = NewProcessLineUi().SetDesc(
                    NewText("leading")
                            .AddString(
                            1,
                            NewString(name)
                                    .SetColor(fontColor).SetFontSize(12)
                    )
                            .AddString(
                            2,
                            NewString(value.Image).SetFontSize(10)
                                                  .SetColor(global.them.containerImageFontColor)
                    )
            ).SetTitle(
                    NewText("trailing")
                            .AddString(
                            2,
                            NewString(value.Status)
                                    .SetColor(global.them.containerImageFontColor)
                                    .SetFontSize(10)
                    )
                            .AddString(
                            1,
                            NewString(value.State)
                                    .SetColor(fontColor)
                                    .SetFontSize(10)
                    )
            ).AddAction(NewAction("restart",{id=value.Id},"重启"))
                                                .AddAction(NewAction("start",{id=value.Id},"启动"))
                                                .AddAction(NewAction("stop",{id=value.Id},"停止"))
                                                .AddAction(NewAction("",{},"容器日志").SetTerminalAction("docker logs -n 10 -f " .. value.Id.." \n"))
                                                .AddAction(NewAction("",{},"登陆容器").SetTerminalAction("docker exec -it " .. value.Id .. " sh \n"))
            -- if value.State == "running" then
            container.SetPage("docker","containerDetail",value,name)
            -- end
            section.AddUiRow(
                    NewUiRow().AddUi(
                            container
                    )
            )
        end
        page.AddPageSection(
                section
        )
        return page.Data()
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

function containers(ctx)
    return NewDocker(ctx):Containers()
end

function changeCurChoiceState(ctx)
    return NewDocker(ctx):ChangeCurChoiceState()
end

function containerDetail(ctx)
    return NewDocker(ctx):ContainerDetail()
end