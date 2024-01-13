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
        allContainersColor = "#34a853",
        allRunningContainersColor = "#4285f4",
        allPausedContainersColor = "#fbbc07",
        allStoppedontainersColor = "#ea4335",
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
        local req = http.request("GET",self.config.HostPort..global.api.systemInfo)
        local stateRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        local data = json.decode(stateRsp.body)

        app.AddUi(
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
                                2,
                                NewString("全部").SetColor(global.them.systemInfoDescFontColor)
                        )
                ).SetPage("docker","containersList",{type="all"},"全部")
        ).AddUi(
                1,
                NewTextUi().SetText(
                        NewText("")
                                .AddString(
                                1,
                                NewString(tostring(data.ContainersRunning))
                                        .SetFontSize(global.them.systemInfoNumFrontSize)
                                        .SetColor(global.them.allRunningContainersColor)
                        )
                                .AddString(
                                2,
                                NewString("运行中").SetColor(global.them.systemInfoDescFontColor)
                        )
                ).SetPage("docker","containersList",{type="running"},"运行中")
        ).AddUi(
                1,
                NewTextUi().SetText(
                        NewText("")
                                .AddString(
                                1,
                                NewString(tostring(data.ContainersPaused))
                                        .SetFontSize(global.them.systemInfoNumFrontSize)
                                        .SetColor(global.them.allPausedContainersColor)
                        )
                                .AddString(
                                2,
                                NewString("暂停").SetColor(global.them.systemInfoDescFontColor)
                        )
                ).SetPage("docker","containersList",{type="paused"},"暂停")
        ).AddUi(
                1,
                NewTextUi().SetText(
                        NewText("")
                                .AddString(
                                1,
                                NewString(tostring(data.ContainersStopped))
                                        .SetFontSize(global.them.systemInfoNumFrontSize)
                                        .SetColor(global.them.allStoppedontainersColor)
                        )
                                .AddString(
                                2,
                                NewString("停止").SetColor(global.them.systemInfoDescFontColor)
                        )
                ).SetPage("docker","containersList",{type="exited"},"停止")
        ).AddUi(
                1,
                NewTextUi()
                        .SetText(
                        NewText("")
                                .AddString(
                                1,
                                NewString(tostring(data.Images))
                                        .SetFontSize(global.them.systemInfoNumFrontSize)
                        )
                                .AddString(
                                2,
                                NewString("镜像")
                                        .SetColor(global.them.systemInfoDescFontColor)
                        )
                ).SetPage("docker","imageList",{},"镜像列表")
        )
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
            print("search result---",url,rsp.body)
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

    function self:ImageMd()
        local req = http.request("GET","https://hub.docker.com/v2/repositories/"..self.arg.name)
        local stateRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        local readme = json.decode(stateRsp.body)

        local page = NewPage()
        page.AddPageSection(
                NewPageSection(readme.description).AddUiRow(
                        NewUiRow().AddUi(
                                NewMarkdownUi().SetMarkdown(readme.full_description)
                        )
                )
        )
        return page.Data()
    end
    function self:ImageList()
        local page = NewPage()

        local req = http.request("GET",self.config.HostPort..global.api.imageList)
        local stateRsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        local data = json.decode(stateRsp.body)
        table.sort(data,function(a, b)
            return tonumber(a.Created) > tonumber(b.Created)
        end)
        local images = NewPageSection("镜像")
        local nameSize = 13

        for index, value in ipairs(data) do
            local nameVersion = string.split(value.RepoTags[1],":")
            images.AddUiRow(
                    NewUiRow().AddUi(
                            NewProcessLineUi().SetDesc(
                                    NewText("leading")
                                            .AddString(
                                            1,
                                            NewString(nameVersion[1])
                                                    .SetFontSize(nameSize)
                                    )
                                            .AddString(
                                            2,
                                            NewString(nameVersion[2])
                                                    .SetFontSize(12)
                                                    .SetColor(global.them.systemInfoDescFontColor)
                                    )
                            )
                                              .SetTitle(
                                    NewText("").AddString(
                                            1,
                                            NewString(ByteToUiString(value.Size)).SetColor(global.them.systemInfoDescFontColor)
                                    )
                            )
                                              .AddAction(
                                    NewAction("delete",{id=value.Id},"删除")
                                            .SetCheck(true)
                            )
                                              .SetPage("docker","imageMd",{name=nameVersion[1]},"镜像详情")
                    )
            )
        end

        images.AddMenu(
                NewIconButton().SetIcon("magnifyingglass.circle")
                               .SetAction(NewAction("search", {}, "").AddInput("Key", NewInput("镜像关键字", 1)))
                               .SetSize(17)
        )
        local searchResult = NewPageSection("搜索结果")
        for index, value in ipairs(global.searchResult) do
            searchResult.AddUiRow(
                    NewUiRow().AddUi(
                            NewProcessLineUi().SetDesc(
                                    NewText("leading").AddString(
                                            1,
                                            NewString(value.name)
                                                    .SetFontSize(nameSize)
                                    )
                                                      .AddString(
                                            2,
                                            NewString(value.description)
                                                    .SetColor(global.them.systemInfoDescFontColor)
                                                    .SetFontSize(10)
                                    )
                            )
                                              .SetTitle(
                                    NewText("trailing").AddString(
                                            1,
                                            NewString(tostring(value.star_count).."🌟").SetColor(global.them.systemInfoDescFontColor)
                                    )
                            )
                                              .AddAction(NewAction("pull",{name=value.name},"拉取镜像"))
                                              .SetPage("docker","imageMd",{name=value.name},"镜像详情")
                    )
            )
        end
        searchResult.AddMenu(
                NewIconButton()
                        .SetIcon("stop.circle")
                        .SetAction(NewAction("stopSearch", {}, ""))
                        .SetColor("#F00")
                        .SetSize(17)
        )
        if #global.searchResult > 0 then
            page.AddPageSection(searchResult)
        end
        page.AddPageSection(
                images
        )
        return page.Data()
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

        local allPort = {}
        for key, value in pairs(inspect.HostConfig.PortBindings) do
            table.insert(allPort, {
                HostIp = value[1].HostIp,
                HostPort = value[1].HostPort,
                BindingPort = key,
            })
        end
        table.sort(allPort,function (a, b)
            return a.HostPort..a.BindingPort < b.HostPort..b.BindingPort
        end)
        local network = NewPageSection("网络 "..inspect.HostConfig.NetworkMode)
        local row = NewUiRow()
        for index, value in ipairs(allPort) do
            row.AddUi(
                    NewTextUi().SetText(
                            NewText("")
                                    .AddString(
                                    2,
                                    NewString(value.BindingPort).SetColor(global.them.systemInfoDescFontColor)
                            )
                                    .AddString(
                                    1,
                                    NewString(value.HostPort)
                            )
                    ).AddAction(
                            NewAction("add",{},"添加到自建服务")
                                    .AddInput("name",NewInput("名字",3).SetVal(string.sub(inspect.Name,2,string.len(inspect.Name))))
                                    .AddInput("host_port",NewInput("探活ip(域名)端口",2).SetVal("127.0.0.1:"..value.HostPort))
                                    .AddInput("url",NewInput("url",1))
                                    .AddInput("icon",NewInput("图标",1))
                                    .SetApp("self_server")
                    )
            )
            if index % 2 == 0 then
                network.AddUiRow(row)
                row = NewUiRow()
            end
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

    function self:ContainersList()
        local state = {}
        local list = {}
        global.containersPage.curType = self.arg.type
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
                                    .SetFontSize(14)
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

function containersList(ctx)
    return NewDocker(ctx):ContainersList()
end


function containerDetail(ctx)
    return NewDocker(ctx):ContainerDetail()
end


function imageList(ctx)
    return NewDocker(ctx):ImageList()
end

function imageMd(ctx)
    return NewDocker(ctx):ImageMd()
end