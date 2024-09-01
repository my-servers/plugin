local json = require("json")
local lfs = require("lfs")
local strings = require("strings")
local db = require("db")

local global = {
    db = {},
    fontColor = "#000",
    fontDescColor = "#b8b8b8",
    cpuPoints = {},
    allCpuPoints = {},
    netState = {
        recv = 0,
        send = 0,
        ts = 0,
    },
    isConfigInterface = false,
    allNotShowDir = {
        ["/etc/resolv.conf"] = "",
        ["/etc/hostname"] = "",
        ["/etc/hosts"] = "",
        ["/app/config"] = "",
    },
    allNeedShowDisk = {
        "ext",
        "xfs",
        "ntfs",
        "fat",
        "hfs",
        "apfs",
        "btrfs",
        "zfs",
        "ufs",
        "msdos",
    },

    curCpuRate = {},
    curCpuTimes = {},
    lastCpuTimes = {},
    allCpuTimesKey = {
        "Idle",
        "System",
        "User",
        "Irq",
        "Softirq",
        "Iowait",
        "Guest",
        "GuestNice",
        "Nice",
        "Steal",
    },
    recvSpeed = 0,
    sendSpeed = 0,
}

function tsToString(ts)
    return string.format("%d天%d小时%d分钟%d秒", ts/86400, (ts%86400)/3600, (ts%3600)/60 , ts%60)
end

---@param ctx Ctx
---@return System
local function NewSystem(ctx)
    ---@class System
    local self = {
        arg    = ctx.arg,    -- 参数
        input  = ctx.input,  -- 输入
        config = ctx.config, -- 配置
        runCtx = ctx.ctx     -- 运行上下文
    }

    local function getInterface()
        local interface = self.runCtx.netInfo[self.config.Interface]
        global.isConfigInterface = true
        if interface == nil then
            global.isConfigInterface = false
            return nil
        end
        return interface
    end

    ---@return number,number
    local function calNetSpeed()
        local interface = getInterface()
        if interface == nil then
            return 0,0
        end
        local diffRecv = interface.BytesRecv - global.netState.recv
        local diffSend = interface.BytesSent - global.netState.send
        local now = os.time()
        local diffTs = now - global.netState.ts
        if diffTs == 0 then
            diffTs = 1
        end
        global.sendSpeed =  diffSend / diffTs
        global.recvSpeed = diffRecv / diffTs
        return diffRecv / diffTs, diffSend / diffTs
    end

    -- updateNetWin 更新网络窗口，计算网速用
    local function updateNetWin()
        local interface = getInterface()
        if interface == nil then
            return
        end
        global.netState.ts = os.time()
        global.netState.send = interface.BytesSent
        global.netState.recv = interface.BytesRecv
    end


    local function calAllCpuPoint(allPoint)
        for index, value in ipairs(allPoint) do
            if global.allCpuPoints[index] == nil then
                global.allCpuPoints[index] = {}
            end
            global.allCpuPoints[index][#global.allCpuPoints[index] + 1] = value
        end
        for index, value in ipairs(global.allCpuPoints) do
            while #value > tonumber(self.config.CpuWin) do
                table.remove(value, 1)
            end
        end
        return global.allCpuPoints
    end

    ---@return table
    local function calCpuPoint()
        global.cpuPoints[#global.cpuPoints + 1] = self.runCtx.cpuPercent[1]
        while #global.cpuPoints > tonumber(self.config.CpuWin) do
            table.remove(global.cpuPoints, 1)
        end
        return global.cpuPoints
    end

    ---@return ProcessCircleUi
    local function getNetUi()
        local recvSpeed, sendSpeed = global.recvSpeed,global .sendSpeed
        local title = NewText("")
        if global.isConfigInterface then
            title.AddString(1, NewString(self.config.Interface)
                    .SetFontSize(10))
        else
            title.AddString(1, NewString(self.config.Interface .. "错误")
                    .SetFontSize(10).SetColor("#F00"))
        end

        local desc = NewText("").AddString(1, NewString("↑" .. ByteToUiString(sendSpeed)).SetFontSize(9))
                                .AddString(2, NewString("↓" .. ByteToUiString(recvSpeed)).SetFontSize(9))

        local netUi = NewProcessCircleUi().SetTitle(title)
                                          .SetDesc(desc)
                                          .SetProcessData(NewProcessData(recvSpeed, 100*1024*1024))
                                          .SetProcessLineColor("#34a853")
                                          .SetPage("","netDetail",{},"网络")

        return netUi
    end

    ---@return ProcessCircleUi
    local function getMemUi()
        local memTitle = NewText("").AddString(1, NewString("内存").SetFontSize(10))
        local memDesc = NewText("").AddString(1, NewString(ByteToUiString(self.runCtx.memInfo.Total)).SetFontSize(9))
                                   .AddString(2, NewString(string.format("%.0f%%", self.runCtx.memInfo.UsedPercent)).SetFontSize(9))

        local memUi = NewProcessCircleUi().SetTitle(memTitle)
                                          .SetDesc(memDesc)
                                          .SetProcessData(NewProcessData(self.runCtx.memInfo.Used, self.runCtx.memInfo.Total))
                                          .SetProcessLineColor("#666666")
                                          .SetPage("","memDetail",{},"内存")
        return memUi
    end

    ---@return ProcessCircleUi
    local function getCpuUi()
        local cpuTitle = NewText("").AddString(1, NewString("cpu").SetFontSize(10))
        local cpuDesc = NewText("").AddString(1, NewString(tostring(#self.runCtx.cpuInfo) .. "核").SetFontSize(9))
                                   .AddString(2, NewString(string.format("%.0f%%", self.runCtx.cpuPercent[1])).SetFontSize(9))
        local cpuUi = NewProcessCircleUi().SetTitle(cpuTitle)
                                          .SetDesc(cpuDesc)
                                          .SetProcessData(NewProcessData(self.runCtx.cpuPercent[1], 100))
                                          .SetPage("","cpuDetail",{},"CPU")
                                          .SetProcessLineColor("#4285f4")
        return cpuUi
    end

    ---@return ProcessCircleUi
    local function getNasUi()
        diskName = self.config.Disk
        local nasTitle = NewText("").AddString(1, NewString("磁盘").SetFontSize(10))
        local nasDesc = NewText("").AddString(1,
                NewString(ByteToUiString(self.runCtx.diskInfo[diskName].Total)).SetFontSize(9))
                                   .AddString(2, NewString(string.format("%.0f%%", self.runCtx.diskInfo[diskName].UsedPercent)).SetFontSize(9))

        local nasUi = NewProcessCircleUi().SetTitle(nasTitle)
                                          .SetDesc(nasDesc)
                                          .SetProcessData(NewProcessData(self.runCtx.diskInfo[diskName].Used, self.runCtx.diskInfo[diskName].Total))
                                          .SetPage("","diskDetail",{},"磁盘")
                                          .SetProcessLineColor("#fbbc07")
        return nasUi
    end

    ---@return LineChartUi
    local function getCpuLineChart(needPage)
        local file = io.popen("cat "..self.config.TempFile, "r")
        local output = file:read("*all")
        file:close()
        local color = ""
        if Tonumber(output)/1000 > 80 then
            color = "#F00"
        end
        local title = NewText("").AddString(
                1,
                NewString(string.format("cpu走势 %d°C",Tonumber(output)/1000))
                        .SetFontSize(8).SetOpacity(0.8)
                        .SetColor(color)
        )
        local cpuLineChart = NewLineChartUi()
        cpuLineChart.SetTitle(title)
        for i, v in ipairs(calCpuPoint()) do
            cpuLineChart.AddPoint(NewPoint(v, tostring(i)))
        end
        if needPage then
            cpuLineChart.SetPage("","cpuDetail",{},"cpu详情")
        end
        return cpuLineChart
    end

    function getMemUiNew ()
        local mem = NewPieChart()
                .AddPieChartData(
                NewPieChartData(self.runCtx.memInfo.Used,"已使用",ByteToUiString(self.runCtx.memInfo.Used),"#fab1a0")
        )
                .AddPieChartData(
                NewPieChartData(self.runCtx.memInfo.Free,"空闲",ByteToUiString(self.runCtx.memInfo.Free),"#DCDCDC")
        )
                .AddPieChartData(
                NewPieChartData(self.runCtx.memInfo.Cached,"cache",ByteToUiString(self.runCtx.memInfo.Cached),"#81ecec")
        )
                .AddDesc(
                NewText("").AddString(
                        1,
                        NewString("内存")
                )
        )
                .SetPage("","memDetail",{},"内存")
                .SetInnerRadius(0.05)
        return mem
    end

    function getUpDownloadloadUi()
        local recvSpeed,sendSpeed = global.recvSpeed,global.sendSpeed
        return NewUiRow()
                .AddUi(
                NewTextUi()
                        .SetText(
                        NewText("")
                                .AddString(
                                2,
                                NewString("↑").SetColor("#C7C8CC")
                        )
                                .AddString(
                                1,
                                NewString(ByteToUiString(sendSpeed)).SetFontSize(16).SetColor("#008DDA")
                        )

                )
                        .SetBackgroundColor("#DCDCDC")
                        .SetOpacity(0.3)
                        .SetCornerRadius(10)
                        .SetWidth(80)
                        .SetHeight(60)
                        .SetPage("","netDetail",{},"网络")
        )
                .AddUi(
                NewTextUi()
                        .SetText(
                        NewText("")
                                .AddString(
                                2,
                                NewString("↓").SetColor("#C7C8CC")
                        )
                                .AddString(
                                1,
                                NewString(ByteToUiString(recvSpeed)).SetFontSize(16).SetColor("#FF204E")
                        )

                )
                        .SetBackgroundColor("#DCDCDC")
                        .SetOpacity(0.3)
                        .SetCornerRadius(10)
                        .SetWidth(80)
                        .SetHeight(60)
                        .SetPage("","netDetail",{},"网络")
        )
    end

    function getNetUiNew()
        local download = NewChildUi()
                .AddChildUi(
                NewUiRow()
                        .AddUi(
                        getCpuUi()
                )
                        .AddUi(
                        getNasUi()
                )
        )
                .AddChildUi(
                getUpDownloadloadUi()
        )

        local net = NewChildUi()
                .AddChildUi(
                NewUiRow()
                        .AddUi(
                        download
                )
        )
        return net
    end

    function getSystemInfo(app)
        local info = host.Info()
        local logo = NewImageUi("https://www.kernel.org/theme/images/logos/tux.png").SetWidth(40)
        local system = NewChildUi()
                .AddChildUi(
                NewUiRow()
                        .AddUi(logo)
                        .AddUi(
                        NewTextUi().SetText(
                                NewText("leading")
                                        .AddString(
                                        1,
                                        NewString(info.OS).SetFontSize(10).SetColor("#B4B4B8")
                                )
                                        .AddString(
                                        1,
                                        NewString(info.Hostname).SetFontSize(10).SetColor("#B4B4B8")
                                )
                                        .AddString(
                                        1,
                                        NewString(info.KernelArch).SetFontSize(10).SetColor("#B4B4B8")
                                )
                                        .AddString(
                                        1,
                                        NewString(info.Platform).SetFontSize(10).SetColor("#B4B4B8")
                                )
                                        .AddString(
                                        1,
                                        NewString(info.PlatformFamily).SetFontSize(10).SetColor("#B4B4B8")
                                )
                                        .AddString(
                                        1,
                                        NewString(info.VirtualizationSystem).SetFontSize(10).SetColor("#B4B4B8")
                                )

                        ).SetBackgroundColor("#DCDCDC").SetOpacity(0.3).SetCornerRadius(5).SetWidth(300)
                )
        )
        return system
    end

    function self:GetUi()
        calNetSpeed()
        calCpuTimes()
        local app = NewApp()
        if self.config.CloseCpuLine == "false" then
            app.AddUi(4, getCpuLineChart(true))
        end
        app.AddUi(1, getNetUi())
        app.AddUi(1, getMemUi())
        app.AddUi(1, getCpuUi())
        app.AddUi(1, getNasUi())

        local info = cpu.Percent(0, true)
        calAllCpuPoint(info)
        updateNetWin()
        return app.Data()
    end

    function CpuDetailNew()
        local page = NewPage()

        page.AddPageSection(
                NewPageSection("cpu").AddUiRow(
                        NewUiRow().AddUi(
                                getCpuUi()
                        )
                )
        )
        return page.Data()
    end

    function getCpuTimeInfo(value,key)
        return NewTextUi()
                .SetText(
                NewText("")
                        .AddString(
                        1,
                        NewString(tostring(value))
                )
                        .AddString(
                        2,
                        NewString(key).SetFontSize(10).SetColor(global.fontDescColor)
                )
        ).SetBackgroundColor("#DCDCDC").SetOpacity(0.3).SetCornerRadius(7).SetWidth(70)
    end

    function calCpuTimes()
        local cpuTimes = cpu.Times(false)
        if #cpuTimes == 0 then
            return
        end

        global.curCpuTimes = cpuTimes[1]
        local diffCpuTime = {}
        for index, value in ipairs(global.allCpuTimesKey) do
            diffCpuTime[value] = Tonumber(global.curCpuTimes[value]) - Tonumber(global.lastCpuTimes[value])
        end

        local sum = 0
        for index, value in ipairs(global.allCpuTimesKey) do
            sum = sum + diffCpuTime[value]
        end

        for index, value in ipairs(global.allCpuTimesKey) do
            if sum > 0 then
                global.curCpuRate[value] = diffCpuTime[value]/sum
            else
                global.curCpuRate[value] = 0
            end
        end
        global.lastCpuTimes = global.curCpuTimes
    end

    function self:CpuDetailNew()
        calCpuTimes()
        local cpuInfo =  NewPageSection("cpu")
        local tempInfo = global.curCpuRate
        local uiRow = NewUiRow()
        local child = NewChildUi().SetWidth(250)
        for index, value in ipairs(global.allCpuTimesKey) do
            if index ~= 1 then
                uiRow.AddUi(
                        getCpuTimeInfo(string.format("%.2f%%", tempInfo[value]*100), value)
                )
                if (index-1)%3 == 0 then
                    child.AddChildUi(uiRow)
                    uiRow = NewUiRow()
                end
            end
        end

        local cpuIdle = NewChildUi()
                .AddChildUi(
                NewUiRow().AddUi(
                        NewImageUi("cpu")
                                .SetWidth(100)
                                .SetOpacity(0.001)
                                .SetColor("#fbbc07")
                )
        ).AddChildUi(
                NewUiRow()
                        .AddUi(
                        NewTextUi()
                                .SetText(
                                NewText("")
                                        .AddString(
                                        1,
                                        NewString(string.format("%.1f%%", tempInfo["Idle"]*100))
                                                .SetColor(global.fontColor)
                                                .SetFontSize(22)
                                )
                                        .AddString(
                                        2,
                                        NewString("Idle")
                                                .SetColor(global.fontDescColor)
                                                .SetFontSize(16)
                                )
                        )
                                .SetOpacity(0.001)
                )
        )
                .SetBackgroundColor("#81ecec")
                .SetOpacity(0.3)
                .SetCornerRadius(7)
                .SetHeight(140)
                .SetWidth(100)
        cpuInfo.AddUiRow(
                NewUiRow()
                        .AddUi(
                        cpuIdle
                )
                        .AddUi(
                        child
                )
        )

        cpuInfo.AddUiRow(
                NewUiRow().AddUi(
                        getCpuLineChart(false)
                )
        )
        local page = NewPage()
        page.AddPageSection(
                cpuInfo
        )
        return page.Data()
    end

    function self:CpuDetail()
        local page = NewPage()

        local info = cpu.Percent(0, true)
        local res = calAllCpuPoint(info)

        for index1, value1 in ipairs(res) do
            local line = NewLineChartUi()
            local text = NewTextUi().SetText(
                    NewText("").AddString(1,NewString(self.runCtx.cpuInfo[index1].ModelName).SetColor(global.fontDescColor))
            )
            for index, value in ipairs(value1) do
                line.AddPoint(
                        NewPoint(value, tostring(index))
                )

            end
            local pageName = string.format(
                    "cpu-%s / cache-%s / 主频-%s Mhz",
                    self.runCtx.cpuInfo[index1].CPU,
                    ByteToUiString(self.runCtx.cpuInfo[index1].CacheSize),
                    ByteToUiString(tostring(self.runCtx.cpuInfo[index1].Mhz))
            )
            page.AddPageSection(
                    NewPageSection(pageName).AddUiRow(
                            NewUiRow().AddUi(
                                    line
                            )
                    ).AddUiRow(
                            NewUiRow().AddUi(
                                    text
                            )
                    )
            )
        end
        calCpuPoint()
        return page.Data()
    end

    function self:MemDetail()
        local page = NewPage()
        local fontSize = 18
        page.AddPageSection(
                NewPageSection("内存信息").AddUiRow(
                        NewUiRow().AddUi(
                                NewTextUi().SetText(
                                        NewText("").AddString(
                                                1,
                                                NewString(ByteToUiString(self.runCtx.memInfo.Total))
                                                        .SetColor(global.fontColor)
                                                        .SetFontSize(fontSize)
                                        ).AddString(
                                                2,
                                                NewString("")
                                        ).AddString(
                                                3,
                                                NewString("总内存").SetFontSize(10).SetColor(global.fontDescColor)
                                        )
                                )
                        ).AddUi(
                                NewTextUi().SetText(
                                        NewText("").AddString(
                                                1,
                                                NewString(ByteToUiString(self.runCtx.memInfo.Available))
                                                        .SetColor(global.fontColor)
                                                        .SetFontSize(fontSize)
                                        ).AddString(
                                                2,
                                                NewString("")
                                        ).AddString(
                                                3,
                                                NewString("空闲内存").SetFontSize(10).SetColor(global.fontDescColor)
                                        )
                                )
                        )
                ).AddUiRow(
                        NewUiRow().AddUi(
                                NewTextUi().SetText(
                                        NewText("").AddString(
                                                1,
                                                NewString(ByteToUiString(self.runCtx.memInfo.Buffers))
                                                        .SetColor(global.fontColor)
                                                        .SetFontSize(fontSize)
                                        ).AddString(
                                                2,
                                                NewString("")
                                        ).AddString(
                                                3,
                                                NewString("Buffer").SetFontSize(10).SetColor(global.fontDescColor)
                                        )
                                )
                        ).AddUi(
                                NewTextUi().SetText(
                                        NewText("").AddString(
                                                1,
                                                NewString(ByteToUiString(self.runCtx.memInfo.Cached))
                                                        .SetColor(global.fontColor)
                                                        .SetFontSize(fontSize)
                                        ).AddString(
                                                2,
                                                NewString("")
                                        ).AddString(
                                                3,
                                                NewString("Cached").SetFontSize(10).SetColor(global.fontDescColor)
                                        )
                                )
                        )
                ).AddUiRow(
                        NewUiRow().AddUi(
                                NewTextUi().SetText(
                                        NewText("").AddString(
                                                1,
                                                NewString(ByteToUiString(self.runCtx.memInfo.SwapTotal))
                                                        .SetColor(global.fontColor)
                                                        .SetFontSize(fontSize)
                                        ).AddString(
                                                2,
                                                NewString("")
                                        ).AddString(
                                                3,
                                                NewString("分区总大小").SetFontSize(10).SetColor(global.fontDescColor)
                                        )
                                )
                        ).AddUi(
                                NewTextUi().SetText(
                                        NewText("").AddString(
                                                1,
                                                NewString(ByteToUiString(self.runCtx.memInfo.SwapFree))
                                                        .SetColor(global.fontColor)
                                                        .SetFontSize(fontSize)
                                        ).AddString(
                                                2,
                                                NewString("")
                                        ).AddString(
                                                3,
                                                NewString("空闲分区").SetFontSize(10).SetColor(global.fontDescColor)
                                        )
                                )
                        )
                ).AddUiRow(
                        NewUiRow().AddUi(
                                NewTextUi().SetText(
                                        NewText("").AddString(
                                                1,
                                                NewString(ByteToUiString(self.runCtx.memInfo.Shared))
                                                        .SetColor(global.fontColor)
                                                        .SetFontSize(fontSize)
                                        ).AddString(
                                                2,
                                                NewString("")
                                        ).AddString(
                                                3,
                                                NewString("共享内存").SetFontSize(10).SetColor(global.fontDescColor)
                                        )
                                )
                        ).AddUi(
                                NewTextUi().SetText(
                                        NewText("").AddString(
                                                1,
                                                NewString(ByteToUiString(self.runCtx.memInfo.Slab))
                                                        .SetColor(global.fontColor)
                                                        .SetFontSize(fontSize)
                                        ).AddString(
                                                2,
                                                NewString("")
                                        ).AddString(
                                                3,
                                                NewString("内核数据slab").SetFontSize(10).SetColor(global.fontDescColor)
                                        )
                                )
                        )
                ).AddUiRow(
                        NewUiRow().AddUi(
                                NewTextUi().SetText(
                                        NewText("").AddString(
                                                1,
                                                NewString(ByteToUiString(self.runCtx.memInfo.Dirty))
                                                        .SetColor(global.fontColor)
                                                        .SetFontSize(fontSize)
                                        ).AddString(
                                                2,
                                                NewString("")
                                        ).AddString(
                                                3,
                                                NewString("脏页").SetFontSize(10).SetColor(global.fontDescColor)
                                        )
                                )
                        ).AddUi(
                                NewTextUi().SetText(
                                        NewText("").AddString(
                                                1,
                                                NewString(ByteToUiString(self.runCtx.memInfo.WriteBack))
                                                        .SetColor(global.fontColor)
                                                        .SetFontSize(fontSize)
                                        ).AddString(
                                                2,
                                                NewString("")
                                        ).AddString(
                                                3,
                                                NewString("正在写回磁盘的虚拟内存").SetFontSize(10).SetColor(global.fontDescColor)
                                        )
                                )
                        )
                )
        )
        return page.Data()
    end

    function self:NetDetail()
        local netInfo = net.IOCountersList()
        local page = NewPage()
        local fontSize = 18
        for i = 1, #netInfo do
            local value = netInfo[i]
            page.AddPageSection(
                    NewPageSection(tostring(value.Name))
                            .AddUiRow(
                            NewUiRow().AddUi(
                                    NewTextUi().SetText(
                                            NewText("")
                                                    .AddString(
                                                    1,
                                                    NewString(ByteToUiString(value.BytesSent))
                                                            .SetColor(global.fontColor)
                                                            .SetFontSize(fontSize)
                                            ).AddString(
                                                    2,
                                                    NewString("").SetColor(global.fontDescColor)
                                            ).AddString(
                                                    3,
                                                    NewString("发送字节数").SetColor(global.fontDescColor)
                                            )
                                    )
                            ).AddUi(
                                    NewTextUi().SetText(
                                            NewText("")
                                                    .AddString(
                                                    1,
                                                    NewString(ByteToUiString(value.BytesRecv))
                                                            .SetColor(global.fontColor)
                                                            .SetFontSize(fontSize)
                                            ).AddString(
                                                    2,
                                                    NewString("").SetColor(global.fontDescColor)
                                            )
                                                    .AddString(
                                                    3,
                                                    NewString("接收字节数").SetColor(global.fontDescColor)
                                            )
                                    )
                            ).AddUi(
                                    NewTextUi().SetText(
                                            NewText("")
                                                    .AddString(
                                                    1,
                                                    NewString(ByteToUiString(value.PacketsSent))
                                                            .SetColor(global.fontColor)
                                                            .SetFontSize(fontSize)
                                            ).AddString(
                                                    2,
                                                    NewString("").SetColor(global.fontDescColor)
                                            )
                                                    .AddString(
                                                    3,
                                                    NewString("发送数据包").SetColor(global.fontDescColor)
                                            )
                                    )
                            ).AddUi(
                                    NewTextUi().SetText(
                                            NewText("")
                                                    .AddString(
                                                    1,
                                                    NewString(ByteToUiString(value.PacketsRecv))
                                                            .SetColor(global.fontColor)
                                                            .SetFontSize(fontSize)
                                            ).AddString(
                                                    2,
                                                    NewString("").SetColor(global.fontDescColor)
                                            )
                                                    .AddString(
                                                    3,
                                                    NewString("接收数据包").SetColor(global.fontDescColor)
                                            )
                                    )
                            )
                    )
                            .AddUiRow(
                            NewUiRow().AddUi(
                                    NewTextUi().SetText(
                                            NewText("")
                                                    .AddString(
                                                    1,
                                                    NewString(ByteToUiString(value.Errout))
                                                            .SetColor(global.fontColor)
                                                            .SetFontSize(fontSize)
                                            ).AddString(
                                                    2,
                                                    NewString("").SetColor(global.fontDescColor)
                                            )
                                                    .AddString(
                                                    3,
                                                    NewString("发送错误包").SetColor(global.fontDescColor)
                                            )
                                    )
                            ).AddUi(
                                    NewTextUi().SetText(
                                            NewText("")
                                                    .AddString(
                                                    1,
                                                    NewString(ByteToUiString(value.Errin))
                                                            .SetColor(global.fontColor)
                                                            .SetFontSize(fontSize)
                                            ).AddString(
                                                    2,
                                                    NewString("").SetColor(global.fontDescColor)
                                            )
                                                    .AddString(
                                                    3,
                                                    NewString("接收错误包").SetColor(global.fontDescColor)
                                            )
                                    )
                            ).AddUi(
                                    NewTextUi().SetText(
                                            NewText("")
                                                    .AddString(
                                                    1,
                                                    NewString(ByteToUiString(value.Dropout))
                                                            .SetColor(global.fontColor)
                                                            .SetFontSize(fontSize)
                                            ).AddString(
                                                    2,
                                                    NewString("").SetColor(global.fontDescColor)
                                            )
                                                    .AddString(
                                                    3,
                                                    NewString("发送丢弃包").SetColor(global.fontDescColor)
                                            )
                                    )
                            ).AddUi(
                                    NewTextUi().SetText(
                                            NewText("")
                                                    .AddString(
                                                    1,
                                                    NewString(ByteToUiString(value.Dropin))
                                                            .SetColor(global.fontColor)
                                                            .SetFontSize(fontSize)
                                            ).AddString(
                                                    2,
                                                    NewString("").SetColor(global.fontDescColor)
                                            )
                                                    .AddString(
                                                    3,
                                                    NewString("接收丢弃包").SetColor(global.fontDescColor)
                                            )
                                    )
                            )
                    )
                            .AddMenu(
                            NewIconButton()
                                    .SetIcon("doc.on.doc")
                                    .SetAction(
                                    NewAction("",{},"复制").SetCopyAction(value.Name)
                            ).SetSize(14)
                    )
            )
        end

        return page.Data()
    end

    function checkDiskNeedShow(v)
        for key, value in pairs(global.allNotShowDir) do
            if v.Path == key then
                return false
            end
        end
        if strings.contains(v.Path, "docker/") and v.Fstype == "btrfs" then
            -- 特殊逻辑，过滤下docker的磁盘
            return false
        end
        if strings.contains(v.Path, "docker/btrfs") then
            -- 特殊逻辑，过滤下docker的磁盘
            return false
        end
        for index, value in ipairs(global.allNeedShowDisk) do
            if strings.contains(v.Fstype, value) then
                return true
            end
        end
        return false
    end

    function self:DiskDetail()
        local page = NewPage()
        local disk = disk.IOCountersList()
        local fontSize = 18
        local uniq = {}
        table.sort(disk, function (a, b)
            return a.Total > b.Total
        end)
        for i=1, #disk do
            local value = disk[i]
            local fontColor = global.fontColor
            if value.UsedPercent > 90 then
                fontColor = "#F00"
            end
            if checkDiskNeedShow(value) and uniq[value.Path] == nil then
                local name = string.format("%s (%.2f%%)",string.gsub(value.Path,"/hostDisk","主机目录:",1),value.UsedPercent)
                if value.Path == "/app/apps" then
                    name = "容器磁盘"
                end
                page.AddPageSection(
                        NewPageSection(name).AddUiRow(
                                NewUiRow().AddUi(
                                        NewTextUi().SetText(
                                                NewText("")
                                                        .AddString(
                                                        1,
                                                        NewString(value.Fstype).SetFontSize(fontSize).SetColor(fontColor)
                                                ).AddString(
                                                        2,
                                                        NewString("").SetFontSize(fontSize).SetColor(fontColor)
                                                )
                                                        .AddString(3,NewString("类型").SetColor(global.fontDescColor))
                                        )
                                ).AddUi(
                                        NewTextUi().SetText(
                                                NewText("")
                                                        .AddString(
                                                        1,
                                                        NewString(ByteToUiString(value.Total)).SetFontSize(fontSize).SetColor(fontColor)
                                                ).AddString(
                                                        2,
                                                        NewString("").SetFontSize(fontSize).SetColor(fontColor)
                                                )
                                                        .AddString(3,NewString("容量").SetColor(global.fontDescColor))
                                        )
                                ).AddUi(
                                        NewTextUi().SetText(
                                                NewText("")
                                                        .AddString(
                                                        1,
                                                        NewString(ByteToUiString(value.Free)).SetFontSize(fontSize).SetColor(fontColor)
                                                ).AddString(
                                                        2,
                                                        NewString("").SetFontSize(fontSize).SetColor(fontColor)
                                                )
                                                        .AddString(3,NewString("空闲").SetColor(global.fontDescColor))
                                        )
                                ).AddUi(
                                        NewTextUi().SetText(
                                                NewText("")
                                                        .AddString(
                                                        1,
                                                        NewString(ByteToUiString(value.Used)).SetFontSize(fontSize).SetColor(fontColor)
                                                ).AddString(
                                                        2,
                                                        NewString("").SetFontSize(fontSize).SetColor(fontColor)
                                                )
                                                        .AddString(3,NewString("已使用").SetColor(global.fontDescColor))
                                        )
                                )
                        ).AddUiRow(
                                NewUiRow().AddUi(
                                        NewProcessLineUi().SetProcessData(
                                                NewProcessData(value.Used, value.Total)
                                        )
                                )
                        ).AddMenu(
                                NewIconButton()
                                        .SetIcon("doc.on.doc")
                                        .SetAction(
                                        NewAction("",{},"复制").SetCopyAction(value.Path)
                                ).SetSize(14)
                        )
                )
            end
            uniq[value.Path] = value.Path
        end
        return page.Data()
    end


    function self:Widget()
        local data = {
            medium = {},
            small = {},
            large = {},
        }
        local widget = NewWidget()

        local net = getNetUi()
        local cpu = getCpuUi()
        widget.AddSmallWidget(
                NewUiRow()
                        .AddUi(
                        getCpuUi()
                )
                        .AddUi(
                        getNasUi()
                )
        )

        local medium = NewUiRow()
        widget.AddMediumWidget(
                NewUiRow()
                        .AddUi(
                        getNetUi()
                ).AddUi(
                        getMemUi()
                ).AddUi(
                        getCpuUi()
                ).AddUi(
                        getNasUi()
                )
        )

        widget
                .AddLargeWidget(
                NewUiRow()
                        .AddUi(
                        getMemUiNew()
                ).AddUi(
                        getNetUiNew()
                )
        )
                .AddLargeWidget(
                NewUiRow()
                        .AddUi(
                        getCpuLineChart(false)
                )
        )
        return widget.Data()
    end

    return self
end


function register()
    -- 初始化ui
    return {
    }
end


---@param ctx Ctx
---@return AppUIData
function update(ctx)
    return NewSystem(ctx):GetUi()
end

function cpuDetail(ctx)
    return NewSystem(ctx):CpuDetailNew()
end

function memDetail(ctx)
    return NewSystem(ctx):MemDetail()
end

function netDetail(ctx)
    return NewSystem(ctx):NetDetail()
end


function diskDetail(ctx)
    return NewSystem(ctx):DiskDetail()
end

function widget(ctx)
    return NewSystem(ctx):Widget()
end