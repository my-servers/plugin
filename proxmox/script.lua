local http = require("http")
local json = require("json")
local strings = require("strings")
local httpClient = http.client({
    timeout = 4, -- 超时1s
    headers = {["Content-Type"]="application/x-www-form-urlencoded"},
    insecure_ssl=true,
})

local httpClientForLogin = http.client({
    timeout = 5, -- 超时1s
    headers = {["Content-Type"]="application/x-www-form-urlencoded"},
    insecure_ssl=true,
})

local global = {
    api = {
        tasks = "/api2/json/cluster/tasks",
        allResources = "/api2/json/cluster/resources",
        login = "/api2/json/access/ticket",
        nodeList = "/api2/json/nodes",
        nodeDetail = "/api2/json/nodes/%s/status",
        rrdData = "/api2/json/nodes/%s/rrddata",
        lxcDetail = "/api2/json/nodes/pve/%s/status/current",
        lxcRrdData = "/api2/json/nodes/pve/%s/rrddata",

        resources = "/api2/json/cluster/resources?type=",
        start = "/api2/json/nodes/%s/%s/status/start",
        shutdown = "/api2/json/nodes/%s/%s/status/shutdown",
        stop = "/api2/json/nodes/%s/%s/status/stop",
        reboot = "/api2/json/nodes/%s/%s/status/reboot",
        delete = "/api2/json/nodes/%s/%s",
        deleteTask = "/api2/json/nodes/%s/tasks/%s",
        startAll = "/api2/json/nodes/%s/startall",
        stopAll = "/api2/json/nodes/%s/stopall",
    },
    ticket = "",
    CSRFPreventionToken = "",
    menu = {
        cur = "vm",
        node = "node",
        qemu = "vm",
        storage = "storage",
    },
    allResourcesState = {
        allTimeType = {
            {
                type = "?timeframe=hour&cf=AVERAGE",
                name = {"小时","平均"}
            },
            {
                type = "?timeframe=hour&cf=MAX",
                name = {"小时","最大"}
            },
            {
                type = "?timeframe=day&cf=AVERAGE",
                name = {"天","平均"}
            },
            {
                type = "?timeframe=day&cf=MAX",
                name = {"天","最大"}
            },
            {
                type = "?timeframe=week&cf=AVERAGE",
                name = {"周","平均"}
            },
            {
                type = "?timeframe=week&cf=MAX",
                name = {"周","最大"}
            },
            {
                type = "?timeframe=month&cf=AVERAGE",
                name = {"月","平均"}
            },
            {
                type = "?timeframe=month&cf=MAX",
                name = {"月","最大"}
            },
            {
                type = "?timeframe=year&cf=AVERAGE",
                name = {"年","平均"}
            },
            {
                type = "?timeframe=year&cf=MAX",
                name = {"年","最大"}
            },
        },
        timeType = "?timeframe=hour&cf=AVERAGE",
        taskTypes = {
            vzcreate = {id = "vzcreate", name = "创建新的容器"},
            vzdestroy = {id = "vzdestroy", name = "删除容器"},
            vzstart = {id = "vzstart", name = "启动容器"},
            vzstop = {id = "vzstop", name = "停止容器"},
            vzmigrate = {id = "vzmigrate", name = "迁移容器"},
            vzrestore = {id = "vzrestore", name = "恢复容器"},
            vzsnapshot = {id = "vzsnapshot", name = "为容器创建快照"},
            vzrollback = {id = "vzrollback", name = "回滚到之前的快照"},
            vzupdate = {id = "vzupdate", name = "更新容器配置"},
            qmcreate = {id = "qmcreate", name = "创建新的虚拟机"},
            qmdestroy = {id = "qmdestroy", name = "删除虚拟机"},
            qmstart = {id = "qmstart", name = "启动虚拟机"},
            qmstop = {id = "qmstop", name = "停止虚拟机"},
            qmmigrate = {id = "qmmigrate", name = "迁移虚拟机"},
            qmrestore = {id = "qmrestore", name = "恢复虚拟机"},
            qmsnapshot = {id = "qmsnapshot", name = "为虚拟机创建快照"},
            qmrollback = {id = "qmrollback", name = "回滚到之前的快照"},
            qmupdate = {id = "qmupdate", name = "更新虚拟机配置"},
            ha_group = {id = "ha_group", name = "高可用性组操作"},
            ha_manager = {id = "ha_manager", name = "高可用性管理器操作"},
            ha_fence = {id = "ha_fence", name = "高可用性围栏操作"},
            ha_start = {id = "ha_start", name = "高可用性启动操作"},
            ha_stop = {id = "ha_stop", name = "高可用性停止操作"},
            ha_migrate = {id = "ha_migrate", name = "高可用性迁移操作"},
            ha_restart = {id = "ha_restart", name = "高可用性重启操作"},
            storage = {id = "storage", name = "存储相关操作"},
            backup = {id = "backup", name = "备份操作"},
            restore = {id = "restore", name = "恢复操作"},
            firewall = {id = "firewall", name = "防火墙相关操作"},
            cluster = {id = "cluster", name = "集群相关操作"},
            network = {id = "network", name = "网络相关操作"},
            pool = {id = "pool", name = "资源池相关操作"},
            ceph = {id = "ceph", name = "Ceph 存储相关操作"},
            startall = {id = "startall", name = "启动所有"},
            stoptall = {id = "stoptall", name = "关闭所有"},
            vzshutdown = {id = "vzshutdown", name = "关机"},
        },
        buttonDescFontColor = "#b8b8b8",
        buttonDescFontSize = 16,
        buttonFontSize = 24,
        buttons = {
            "node",
            "storage",
            -- "pool",
            -- "qemu",
            "vm",
            "task",
        },
        type = {
            node = {
                id = "node",
                name =  "节点",
                buttonDescFontColor = "#b8b8b8",
                buttonFontSize = 24,
                fontColor = "#34a853",
                page = {
                    func = "nodeList",
                }
            },
            storage = {
                id = "storage",
                name =  "存储",
                buttonDescFontColor = "#b8b8b8",
                buttonFontSize = 24,
                fontColor = "#4285f4",
                page = {
                    func = "storageList",
                }
            },
            pool = {
                id = "pool",
                name =  "资源池",
                buttonDescFontColor = "#b8b8b8",
                buttonFontSize = 24,
                fontColor = "#34a853",
                page = {
                    func = "poolList",
                }
            },
            qemu = {
                id = "vm",
                name =  "KVM",
                buttonDescFontColor = "#b8b8b8",
                buttonFontSize = 24,
                fontColor = "#34a853",
                page = {
                    func = "qemuList",
                }
            },
            lxc = {
                id = "vm",
                name =  "虚拟机",
                buttonDescFontColor = "#b8b8b8",
                buttonFontSize = 24,
                fontColor = "#34a853",
                page = {
                    func = "lxcList",
                }
            },
            vm = {
                id = "vm",
                name =  "虚拟机",
                buttonDescFontColor = "#b8b8b8",
                buttonFontSize = 24,
                fontColor = "#fbbc07",
                page = {
                    func = "lxcList",
                }
            },
            sdn = {
                id = "sdn",
                name =  "虚拟网络",
                buttonDescFontColor = "#b8b8b8",
                buttonFontSize = 24,
                fontColor = "#34a853",
                page = {
                    func = "sdnList",
                }
            },
            task = {
                id = "task",
                name =  "任务",
                buttonDescFontColor = "#b8b8b8",
                buttonFontSize = 24,
                fontColor = "#ea4335",
                page = {
                    func = "taskList",
                }
            },
        },
        chartType = {
            cpu = {
                id = "cpu",
                name = "cpu利用率(%)",
                cal = function (value)
                    return Tonumber(value.cpu)*100
                end,
            },
            netout = {
                id = "netout",
                name = "网络出(单位Mb)",
                cal = function (value)
                    return string.format("%.2f",Tonumber(value.netout)/1024/1024)
                end,
            },
            swaptotal = {
                id = "swaptotal",
                name = "swap使用率(%)",
                cal = function (value)
                    if Tonumber(value.swaptotal) == 0 then
                        return 0
                    end
                    return string.format("%.2f", Tonumber(value.swapused)/Tonumber(value.swaptotal)*100)
                end,
            },
            memused = {
                id = "memused",
                name = "内存使用率(%)",
                cal = function (value)
                    if Tonumber(value.memtotal) == 0 then
                        return 0
                    end
                    return string.format("%.2f", Tonumber(value.memused)/Tonumber(value.memtotal)*100)
                end,
            },
            mem = {
                id = "mem",
                name = "内存使用率(%)",
                cal = function (value)
                    if Tonumber(value.maxmem) == 0 then
                        return 0
                    end
                    return string.format("%.2f", Tonumber(value.mem)/Tonumber(value.maxmem)*100)
                end,
            },
            swapused = {
                id = "swapused",
                name = "swap使用率(%)",
                cal = function (value)
                    if Tonumber(value.swaptotal) == 0 then
                        return 0
                    end
                    return string.format("%.2f", Tonumber(value.swapused)/Tonumber(value.swaptotal)*100)
                end,
            },
            iowait = {
                id = "iowait",
                name = "io等待",
                cal = function (value)
                    return value.iowait
                end,
            },
            netin = {
                id = "netin",
                name = "网络进(单位Mb)",
                cal = function (value)
                    return string.format("%.2f", Tonumber(value.netin)/1024/1024)
                end,
            },
            loadavg = {
                id = "loadavg",
                name = "平均负载",
                cal = function (value)
                    return value.loadavg
                end,
            },
            rootused = {
                id = "rootused",
                name = "磁盘使用率(%)",
                cal = function (value)
                    if Tonumber(value.roottotal) == 0 then
                        return 0
                    end
                    return string.format("%.2f", Tonumber(value.rootused)/Tonumber(value.roottotal)*100)
                end,
            },
            diskread = {
                id = "diskread",
                name = "磁盘读(Mb)",
                cal = function (value)
                    return string.format("%.2f", Tonumber(value.diskread)/1024/1024)
                end,
            },
            diskwrite = {
                id = "diskwrite",
                name = "磁盘写(Mb)",
                cal = function (value)
                    return string.format("%.2f", Tonumber(value.diskwrite)/1024/1024)
                end,
            }
        },
        allChart = {
            "cpu",
            "memused",
            "rootused",
            "swapused",
            "netout",
            "netin",
            "loadavg",
            "iowait",
        },
        lxcAllChart = {
            "cpu",
            "mem",
            "netout",
            "netin",
            "diskwrite",
            "diskread",
        },
        node = {}, -- 只有一个
        stateColor = {
            running = {
                name = "运行中",
                color = "#4285f4"
            },
            stopped = {
                name = "已停止",
                color = "#ea4335"
            },
            online = {
                name = "在线",
                color = "#4285f4"
            },
            available = {
                name = "正常",
                color = "#4285f4"
            }
        }
    }
}


---@param ctx Ctx
---@return Pve
local function NewPve(ctx)
    ---@class Pve
    local self = {
        arg    = ctx.arg,    -- 参数
        input  = ctx.input,  -- 输入
        config = ctx.config, -- 配置
        runCtx = ctx.ctx     -- 运行上下文
    }


    function getTimeInfo()
        local uiRow = NewUiRow()
        local section = NewPageSection("时间周期")
        for index, value in ipairs(global.allResourcesState.allTimeType) do
            local color = global.allResourcesState.buttonDescFontColor
            if value.type == global.allResourcesState.timeType then
                color = "#F00"
            end
            if index == 6 then
                section.AddUiRow(uiRow)
                uiRow = NewUiRow()
                section.AddUiRow(uiRow)
            end
            uiRow.AddUi(
                    NewIconButtonUi().SetIconButton(
                            NewIconButton().SetDesc(
                                    NewText("")
                                            .AddString(
                                            1,
                                            NewString(value.name[1])
                                                    .SetColor(color)
                                                    .SetFontSize(10)
                                    )
                                            .AddString(
                                            2,
                                            NewString(value.name[2])
                                                    .SetColor(color)
                                                    .SetFontSize(10)
                                    )
                            ).SetAction(
                                    NewAction("changeTime",{type=value.type},"")
                            )
                    )
            )
        end

        return section
    end
    function self:updateCookie()
        local username = self.config.Username
        if strings.contains(self.config.Username,"@") == false then
            username = username .. "@pam"
        end
        local data = string.format("username=%s&password=%s", username,self.config.Password)
        local req = http.request("POST",self.config.HostPort .. global.api.login, data)
        local loginRsp,err = httpClientForLogin:do_request(req)
        if err then
            error(err)
        end
        local results = json.decode(loginRsp.body)
        global.ticket = "PVEAuthCookie=" .. results["data"]["ticket"]
        global.CSRFPreventionToken = results["data"]["CSRFPreventionToken"]
        print("update pve cookie---------", json.encode(loginRsp),global.ticket)
    end

    ---@param url string
    ---@param header table
    local function get(url, header)
        local req = http.request("GET", url)
        for key, value in pairs(header) do
            req:header_set(key, value)
        end
        req:header_set("Cookie",global.ticket)
        req:header_set("Csrfpreventiontoken",global.CSRFPreventionToken)
        local rsp,err = httpClient:do_request(req)
        if err then
            error(err)
        end
        if rsp.code == 401 then
            self:updateCookie()
            req:header_set("Cookie",global.ticket)
            req:header_set("Csrfpreventiontoken",global.CSRFPreventionToken)
            rsp,err = httpClient:do_request(req)
        end
        if err then
            error(err)
        end
        return rsp
    end


    ---@param url string
    ---@param header table
    ---@param data table
    local function delete(url, header, data)
        local req = http.request("DELETE", url)
        if #data > 0 then
            req = http.request("DELETE", url, json.encode(data))
        end

        for key, value in pairs(header) do
            req:header_set(key, value)
        end
        req:header_set("Cookie",global.ticket)
        req:header_set("Csrfpreventiontoken",global.CSRFPreventionToken)
        local rsp,err = httpClient:do_request(req)
        if err then
            print("do post err------",err)
            error(err)
        end
        if rsp.code == 401 then
            self:updateCookie()
            rsp,err = httpClient:do_request(req)
        end
        if err then
            print("do post err------",err)
            error(err)
        end
        return rsp
    end

    ---@param url string
    ---@param header table
    ---@param data table
    local function post(url, header, data)
        local req = http.request("POST", url)
        if #data > 0 then
            req = http.request("POST", url, json.encode(data))
        end

        for key, value in pairs(header) do
            req:header_set(key, value)
        end
        req:header_set("Cookie",global.ticket)
        req:header_set("Csrfpreventiontoken",global.CSRFPreventionToken)
        local rsp,err = httpClient:do_request(req)
        if err then
            print("do post err------",err)
            error(err)
        end
        if rsp.code == 401 then
            self:updateCookie()
            rsp,err = httpClient:do_request(req)
        end
        if err then
            print("do post err------",err)
            error(err)
        end
        return rsp
    end


    function self:StartAll()
        local status = self.arg
        local url = string.format(global.api.startAll,status.node)
        local res = post(self.config.HostPort .. url,{},{})
        return NewToast("启动成功","info","")
    end

    function self:ChangeTime()
        global.allResourcesState.timeType = self.arg.type
    end

    function self:StopAll()
        local status = self.arg
        local url = string.format(global.api.stopAll,status.node)
        local res = post(self.config.HostPort .. url,{},{})
        return NewToast("启动成功","info","")
    end

    function self:StartVm()
        local status = self.arg
        local url = string.format(global.api.start,status.node,status.id)
        local res = post(self.config.HostPort .. url,{},{})
        print("shutdown vm----", json.encode(res))
        return NewToast("启动成功","info","")
    end

    function self:ShutdownVm()
        local status = self.arg
        local url = string.format(global.api.shutdown,status.node,status.id)
        local res = post(self.config.HostPort .. url,{},{})
        print("shutdown vm----", json.encode(res))
        return NewToast("关机成功","info","")
    end

    function self:StopVm()
        local status = self.arg
        local url = string.format(global.api.stop,status.node,status.id)
        local res = post(self.config.HostPort .. url,{},{})
        print("stop vm----", json.encode(res))
        return NewToast("暂停成功","info","")
    end

    function self:RestartVm()
        local status = self.arg
        local url = string.format(global.api.reboot,status.node,status.id)
        local res = post(self.config.HostPort .. url,{},{})
        print("reboot vm----", json.encode(res))
        return NewToast("重启成功","info","")
    end

    function self:DeleteVm()
        local status = self.arg
        local url = string.format(global.api.delete,status.node,status.id)
        local res = delete(self.config.HostPort .. url,{},{})
        print("delete vm----", json.encode(res))
        return NewToast("删除成功","info","")
    end

    local function setChart(page, url, chart)
        local data = json.decode(get(url,{}).body)
        local allChart = {}
        local allStartEndTs = {}
        for index, value in ipairs(chart) do
            allChart[value] = NewLineChartUi()
            allStartEndTs[value] = {
                startTs = 10000000000000,
                endTs = 0
            }
        end
        for index, value in ipairs(data.data) do
            for key, c in pairs(allChart) do
                c.AddPoint(
                        NewPoint(global.allResourcesState.chartType[key].cal(value), tostring(index))
                )
                if value.time < allStartEndTs[key].startTs then
                    allStartEndTs[key].startTs = value.time
                end
                if value.time > allStartEndTs[key].endTs then
                    allStartEndTs[key].endTs = value.time
                end
            end
        end
        for index, value in ipairs(chart) do
            page.AddPageSection(
                    NewPageSection(global.allResourcesState.chartType[value].name)
                            .AddUiRow(
                            NewUiRow().AddUi(
                                    allChart[value].SetTitle(
                                            NewText("").AddString(
                                                    1,
                                                    NewString(os.date("%Y-%m-%d %H:%M:%S",allStartEndTs[value].startTs))
                                                            .SetColor(global.allResourcesState.buttonDescFontColor)
                                                            .SetFontSize(10)
                                            ).AddString(
                                                    1,
                                                    NewString("->")
                                                            .SetBackendColor(global.allResourcesState.buttonDescFontColor)
                                                            .SetFontSize(10)
                                                            .SetColor("#FFF")
                                            ).AddString(
                                                    1,
                                                    NewString(os.date("%Y-%m-%d %H:%M:%S",allStartEndTs[value].endTs))
                                                            .SetColor(global.allResourcesState.buttonDescFontColor)
                                                            .SetFontSize(10)
                                            )
                                    )
                            )
                    )
            )
        end
    end

    function self:getStatePageSection(data)
        local fontSize = 10
        local swapUsedPercent = 0
        if Tonumber(data.swapTotal) > 0 then
            swapUsedPercent = data.swapUsed/data.swapTotal*100
        end

        local rootFsPercent = 0
        if Tonumber(data.rootfsTotal) > 0 then
            rootFsPercent = data.rootfsUsed/data.rootfsTotal*100
        end

        local memPercent = 0
        if Tonumber(data.memoryTotal) > 0 then
            memPercent = data.memoryUsed/data.memoryTotal*100
        end

        return NewPageSection("运行状态")
                .AddUiRow(
                NewUiRow()
                        .AddUi(
                        NewProcessCircleUi()
                                .SetProcessData(
                                NewProcessData(data.cpu,1)
                        )
                                .SetDesc(
                                NewText("")
                                        .AddString(
                                        1,
                                        NewString(string.format("%d核",data.cpus))
                                                .SetFontSize(fontSize)
                                )
                                        .AddString(
                                        2,
                                        NewString(string.format("%.1f%%",data.cpu*100))
                                                .SetFontSize(fontSize)
                                                .SetColor(global.allResourcesState.buttonDescFontColor)
                                )
                        )
                                .SetTitle(
                                NewText("").AddString(
                                        1,
                                        NewString("cpu")
                                )
                        )
                )
                        .AddUi(
                        NewProcessCircleUi()
                                .SetProcessData(
                                NewProcessData(data.memoryUsed, data.memoryTotal)
                        )
                                .SetDesc(
                                NewText("")
                                        .AddString(
                                        1,
                                        NewString(ByteToUiString(data.memoryTotal))
                                                .SetFontSize(fontSize)
                                )
                                        .AddString(
                                        2,
                                        NewString(string.format("%.1f%%", memPercent))
                                                .SetFontSize(fontSize)
                                                .SetColor(global.allResourcesState.buttonDescFontColor)
                                )
                        )
                                .SetTitle(
                                NewText("").AddString(
                                        1,
                                        NewString("内存")
                                )
                        )
                )
                        .AddUi(
                        NewProcessCircleUi()
                                .SetProcessData(
                                NewProcessData(data.rootfsUsed,data.rootfsTotal)
                        )
                                .SetDesc(
                                NewText("")
                                        .AddString(
                                        1,
                                        NewString(ByteToUiString(data.rootfsTotal))
                                                .SetFontSize(fontSize)
                                )
                                        .AddString(
                                        2,
                                        NewString(string.format("%.1f%%",rootFsPercent))
                                                .SetFontSize(fontSize)
                                                .SetColor(global.allResourcesState.buttonDescFontColor)
                                )
                        )
                                .SetTitle(
                                NewText("").AddString(
                                        1,
                                        NewString("硬盘")
                                )
                        )
                )
                        .AddUi(
                        NewProcessCircleUi()
                                .SetProcessData(
                                NewProcessData(data.swapUsed,data.swapTotal)
                        )
                                .SetDesc(
                                NewText("")
                                        .AddString(
                                        1,
                                        NewString(ByteToUiString(data.swapTotal))
                                                .SetFontSize(fontSize)
                                )
                                        .AddString(
                                        2,
                                        NewString(string.format("%.1f%%",swapUsedPercent))
                                                .SetFontSize(fontSize)
                                                .SetColor(global.allResourcesState.buttonDescFontColor)
                                )
                        )
                                .SetTitle(
                                NewText("").AddString(
                                        1,
                                        NewString("swap")
                                )
                        )
                )
        )
    end

    function self:NodeDetail()
        local page = NewPage()
        local nodeDetailUrl = string.format(self.config.HostPort .. global.api.nodeDetail,self.arg.node)
        local nodeDetailRsp = get(nodeDetailUrl,{})
        local nodeDetail = json.decode(nodeDetailRsp.body)
        page.AddPageSection(
                self:getStatePageSection({
                    cpu = nodeDetail.data.cpu,
                    cpus = nodeDetail.data.cpuinfo.cores,
                    memoryUsed = nodeDetail.data.memory.used,
                    memoryTotal = nodeDetail.data.memory.total,
                    rootfsUsed = nodeDetail.data.rootfs.used,
                    rootfsTotal = nodeDetail.data.rootfs.total,
                    swapUsed = nodeDetail.data.swap.used,
                    swapTotal = nodeDetail.data.swap.total,
                })
                    .AddUiRow(
                        NewUiRow()
                                .AddUi(
                                NewProcessLineUi()
                                        .SetDesc(
                                        NewText("leading").AddString(
                                                1,
                                                NewString("CPU(s)")
                                                        .SetColor(global.allResourcesState.buttonDescFontColor)
                                        )
                                )
                                        .SetTitle(
                                        NewText("trailing").AddString(
                                                1,
                                                NewString(string.format("%d * %s", nodeDetail.data.cpuinfo.cpus, tostring(nodeDetail.data.cpuinfo.model)))
                                                        .SetFontSize(10)
                                        )
                                )
                        )
                )
                    .AddUiRow(
                        NewUiRow()
                                .AddUi(
                                NewProcessLineUi()
                                        .SetDesc(
                                        NewText("leading").AddString(
                                                1,
                                                NewString("内核版本")
                                                        .SetColor(global.allResourcesState.buttonDescFontColor)
                                        )
                                )
                                        .SetTitle(
                                        NewText("trailing").AddString(
                                                1,
                                                NewString(tostring(nodeDetail.data.kversion))
                                                        .SetFontSize(10)
                                        )
                                )
                        )
                )
                    .AddUiRow(
                        NewUiRow()
                                .AddUi(
                                NewProcessLineUi()
                                        .SetDesc(
                                        NewText("leading").AddString(
                                                1,
                                                NewString("Boot Mode")
                                                        .SetColor(global.allResourcesState.buttonDescFontColor)
                                        )
                                )
                                        .SetTitle(
                                        NewText("trailing").AddString(
                                                1,
                                                NewString(tostring(nodeDetail.data["boot-info"].mode))
                                                        .SetFontSize(10)
                                        )
                                )
                        )
                )
                    .AddUiRow(
                        NewUiRow()
                                .AddUi(
                                NewProcessLineUi()
                                        .SetDesc(
                                        NewText("leading").AddString(
                                                1,
                                                NewString("Manager Version")
                                                        .SetColor(global.allResourcesState.buttonDescFontColor)
                                        )
                                )
                                        .SetTitle(
                                        NewText("trailing").AddString(
                                                1,
                                                NewString(tostring(nodeDetail.data.pveversion))
                                                        .SetFontSize(10)
                                        )
                                )
                        )
                )
        )

        page.AddPageSection(getTimeInfo())
        local chartUrl = string.format(self.config.HostPort .. global.api.rrdData..global.allResourcesState.timeType,self.arg.node)
        setChart(page, chartUrl,global.allResourcesState.allChart)
        return page.Data()
    end


    function self:SdnList()
        local page = NewPage()
        local lxcListUrl = self.config.HostPort .. global.api.resources .. "sdn"
        local vmList = json.decode(get(lxcListUrl,{}).body)
        local section = NewPageSection("列表")
        table.sort(vmList.data,function (a, b)
            return a.maxdisk > b.maxdisk
        end)
        for index, value in ipairs(vmList.data) do
            section.AddUiRow(
                    NewUiRow().AddUi(
                            NewProcessLineUi().SetDesc(
                                    NewText("leading").AddString(
                                            1,
                                            NewString(value.sdn)
                                    )
                            )
                                              .SetTitle(
                                    NewText("trailing").AddString(
                                            1,
                                            NewString(value.status)
                                    )
                            )
                                              .SetPage("","lxcDetail",value,value.sdn.."详情")
                    )
            )
        end

        return page.AddPageSection(section).Data()
    end

    function self:StorageList()
        local page = NewPage()
        local lxcListUrl = self.config.HostPort .. global.api.resources .. "storage"
        local vmList = json.decode(get(lxcListUrl,{}).body)
        local section = NewPageSection("列表")
        table.sort(vmList.data,function (a, b)
            return a.maxdisk > b.maxdisk
        end)
        for index, value in ipairs(vmList.data) do
            local usePercent = value.disk/value.maxdisk*100
            local color = global.allResourcesState.buttonDescFontColor
            if usePercent > 90 then
                color = "#F00"
            end
            local state = value.status
            local stateColor  = "#F00"
            if global.allResourcesState.stateColor[value.status] ~= nil then
                state = global.allResourcesState.stateColor[value.status].name
                stateColor = global.allResourcesState.stateColor[value.status].color
            end
            section.AddUiRow(
                    NewUiRow().AddUi(
                            NewProcessLineUi().SetDesc(
                                    NewText("leading")
                                            .AddString(
                                            1,
                                            NewString(value.storage)
                                    )
                                            .AddString(
                                            2,
                                            NewString(string.format("%s/%s",ByteToUiString(value.disk),ByteToUiString(value.maxdisk)))
                                                    .SetColor(color)
                                                    .SetFontSize(10)
                                    )
                            )
                                              .SetTitle(
                                    NewText("trailing")
                                            .AddString(
                                            1,
                                            NewString(state)
                                                    .SetColor(stateColor)
                                    )
                                            .AddString(
                                            2,
                                            NewString(string.format("%.2f%%", usePercent))
                                                    .SetColor(color)
                                                    .SetFontSize(10)
                                    )
                            )
                                              .SetProcessData(
                                    NewProcessData(value.disk, value.maxdisk)
                            )
                    )
            )
        end

        return page.AddPageSection(section).Data()
    end

    function self:DeleteTask()
        local status = self.arg
        local url = string.format(global.api.deleteTask,status.node,http.query_escape(status.upid))
        local res = delete(self.config.HostPort .. url,{},{})
        print("delete vm----",url, json.encode(res))
        return NewToast("删除成功","info","")
    end

    function self:TaskList()
        local page = NewPage()
        local taskUrl = self.config.HostPort .. global.api.tasks
        local taskData = get(taskUrl,{})
        local task = json.decode(taskData.body)
        local section = NewPageSection("运行中")
        local finished = NewPageSection("已结束")
        local runningNum = 0
        local finishedNum = 0
        for index, value in ipairs(task.data) do
            if index > Tonumber(self.config.TaskMaxNum) then
                break
            end
            local name = value.type
            if global.allResourcesState.taskTypes[value.type] ~= nil then
                name = global.allResourcesState.taskTypes[value.type].name
            end
            local color = global.allResourcesState.buttonDescFontColor
            if value.status ~= "OK" then
                color = "#F00"
            end
            if value.status == nil then
                color = ""
            end
            local taskItem = NewUiRow().AddUi(
                    NewProcessLineUi()
                            .SetDesc(
                            NewText("leading")
                                    .AddString(
                                    1,
                                    NewString(name)
                                            .SetColor(color)
                            )
                                    .AddString(
                                    1,
                                    NewString(value.id)
                                            .SetColor(color)
                            )
                    )
                            .SetTitle(
                            NewText("").AddString(
                                    1,
                                    NewString(value.status)
                                            .SetFontSize(10)
                                            .SetColor(color)
                            )
                    )
            )
            if value.status == nil then
                runningNum = runningNum+1
                section.AddUiRow(taskItem)
            else
                finishedNum = finishedNum+1
                finished.AddUiRow(taskItem)
            end

        end
        if runningNum == 0 then
            section.AddUiRow(
                    NewUiRow().AddUi(NewTextUi().SetText(NewText("").AddString(1,NewString("无数据").SetColor(global.allResourcesState.buttonDescFontColor))))
            )
        end
        if finishedNum == 0 then
            finished.AddUiRow(
                    NewUiRow().AddUi(NewTextUi().SetText(NewText("").AddString(1,NewString("无数据").SetColor(global.allResourcesState.buttonDescFontColor))))
            )
        end

        return page.AddPageSection(section).AddPageSection(finished).Data()
    end

    function self:LxcDetail()
        local page = NewPage()
        local lxcDetailUrl = string.format(self.config.HostPort .. global.api.lxcDetail,self.arg.id)
        local lxcInfo = json.decode(get(lxcDetailUrl,{}).body).data


        local infoSection = NewPageSection("状态")
        infoSection.AddUiRow(
                NewUiRow()
                        .AddUi(
                        NewProcessCircleUi()
                                .SetProcessData(
                                NewProcessData(lxcInfo.cpu,1)
                        )
                                .SetDesc(
                                NewText("'")
                                        .AddString(
                                        1,
                                        NewString(string.format("%d核",lxcInfo.cpus))
                                )
                                        .AddString(
                                        2,
                                        NewString(string.format("%.1f%%",lxcInfo.cpu*100))
                                )
                        )
                                .SetTitle(
                                NewText("")
                                        .AddString(
                                        1,
                                        NewString("cpu")
                                )
                        )
                )
        )
        page.AddPageSection(self:getStatePageSection({
            cpu = lxcInfo.cpu,
            cpus = lxcInfo.cpus,
            memoryUsed = lxcInfo.mem,
            memoryTotal = lxcInfo.maxmem,
            rootfsUsed = lxcInfo.disk,
            rootfsTotal = lxcInfo.maxdisk,
            swapUsed = lxcInfo.swap,
            swapTotal = lxcInfo.maxswap,
        })
        )
        page.AddPageSection(getTimeInfo())

        local lxcRddUrl = string.format(self.config.HostPort .. global.api.lxcRrdData..global.allResourcesState.timeType,self.arg.id)
        setChart(page, lxcRddUrl, global.allResourcesState.lxcAllChart)


        return page.Data()
    end

    function self:LxcList()
        local page = NewPage()
        local lxcListUrl = self.config.HostPort .. global.api.resources .. "vm"
        local vmList = json.decode(get(lxcListUrl,{}).body)
        local section = NewPageSection("列表")
        for index, value in ipairs(vmList.data) do
            section.AddUiRow(
                    NewUiRow().AddUi(
                            NewProcessLineUi().SetDesc(
                                    NewText("leading").AddString(
                                            1,
                                            NewString(value.name)
                                    )
                            )
                                              .SetTitle(
                                    NewText("trailing").AddString(
                                            1,
                                            NewString(global.allResourcesState.stateColor[value.status].name)
                                                    .SetColor(
                                                    global.allResourcesState.stateColor[value.status].color
                                            )
                                    )
                            )
                                              .SetPage("","lxcDetail",value,value.name.."详情")
                                              .AddAction(NewAction("startVm",value,"启动"))
                                              .AddAction(NewAction("shutdownVm",value,"关机").SetCheck(true))
                                              .AddAction(NewAction("stopVm",value,"停止").SetCheck(true))
                                              .AddAction(NewAction("restartVm",value,"重启").SetCheck(true))
                                              .AddAction(NewAction("deleteVm",value,"移除").SetCheck(true))
                    )
            )
        end

        return page.AddPageSection(section).Data()
    end

    -- 节点列表
    function  self:NodeList()
        local nodeListUrl = self.config.HostPort .. global.api.nodeList
        local nodeList = get(nodeListUrl,{})
        local nodes = json.decode(nodeList.body)
        local page = NewPage()
        local section = NewPageSection("列表")
        for index, value in ipairs(nodes.data) do
            local state = value.status
            local stateColor  = "#F00"
            if global.allResourcesState.stateColor[value.status] ~= nil then
                state = global.allResourcesState.stateColor[value.status].name
                stateColor = global.allResourcesState.stateColor[value.status].color
            end
            section.AddUiRow(
                    NewUiRow().AddUi(
                            NewProcessLineUi().SetDesc(
                                    NewText("leading").AddString(
                                            1,
                                            NewString(value.node)
                                    )
                            )
                                              .SetTitle(
                                    NewText("trailing").AddString(
                                            1,
                                            NewString(state)
                                                    .SetColor(stateColor)
                                    )
                            )
                                              .SetPage("","nodeDetail",value,value.node.."详情")
                    )
            )
        end
        page.AddPageSection(section)
        return page.Data()
    end

    function self:Update()
        local app = NewApp()
        local allTask = {
            all = {},
            num = 0,
            hasFail = false,
        }

        local resource = {}
        local task = {}
        local err = goAndWait({
            allResourceKey = function ()
                local taskUrl = self.config.HostPort .. global.api.allResources
                local taskData = get(taskUrl,{})
                resource = json.decode(taskData.body)
            end,
            taskListKey = function ()
                local taskUrl = self.config.HostPort .. global.api.tasks
                local taskData = get(taskUrl,{})
                task = json.decode(taskData.body)
            end
        })
        if err ~= nil then
            error(err)
        end


        local allResource = {}
        for index, value in ipairs(resource.data) do
            if value.type == "node" then
                global.allResourcesState.node = value
            end
            local id = global.allResourcesState.type[value.type].id
            if allResource[id] == nil then
                allResource[id] = {}
            end

            table.insert(allResource[id], value)
        end

        --task
        allResource[global.allResourcesState.type.task.id] = {}
        for index, value in ipairs(task.data) do
            if value.status == nil then
                table.insert(allResource[global.allResourcesState.type.task.id], value)
            end
        end
        local i = 1
        for index, value in ipairs(global.allResourcesState.buttons) do
            if allResource[value] == nil then
                allResource[value] = {}
            end
            local button = global.allResourcesState.type[value]
            app
                    .AddUi(
                    i,
                    NewTextUi().SetText(
                            NewText("").AddString(
                                    1,
                                    NewString(tostring(#allResource[value]))
                                            .SetFontSize(button.buttonFontSize)
                                            .SetColor(button.fontColor)
                            ).AddString(
                                    2,
                                    NewString(button.name)
                                            .SetColor(button.buttonDescFontColor)
                            )
                    )
                               .SetPage("",button.page.func,{},button.name)
            )
            if index % 4 == 0 then
                i = i+1
            end
        end

        return app.Data()
    end

    return self
end


function register(ctx)
    return {
    }
end


function update(ctx)
    return NewPve(ctx):Update()
end

function changeMenu(ctx)
    return NewPve(ctx):ChangeMenu()
end

function startVm(ctx)
    return NewPve(ctx):StartVm()
end

function shutdownVm(ctx)
    return NewPve(ctx):ShutdownVm()
end

function stopVm(ctx)
    return NewPve(ctx):StopVm()
end

function restartVm(ctx)
    return NewPve(ctx):RestartVm()
end

function deleteVm(ctx)
    return NewPve(ctx):DeleteVm()
end

function nodeList(ctx)
    return NewPve(ctx):NodeList()
end

function nodeDetail(ctx)
    return NewPve(ctx):NodeDetail()
end

function lxcList(ctx)
    return NewPve(ctx):LxcList()
end


function storageList(ctx)
    return NewPve(ctx):StorageList()
end

function sdnList(ctx)
    return NewPve(ctx):SdnList()
end

function lxcDetail(ctx)
    return NewPve(ctx):LxcDetail()
end

function taskList(ctx)
    return NewPve(ctx):TaskList()
end

function deleteTask(ctx)
    return NewPve(ctx):DeleteTask()
end

function startAll(ctx)
    return NewPve(ctx):StartAll()
end

function changeTime(ctx)
    return NewPve(ctx):ChangeTime()
end