local json = require("json")
local global = {
    cpuPoints = {},
    netState = {
        recv = 0,
        send = 0,
        ts = 0,
    },
}

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

    ---@return number,number
    local function calNetSpeed()
        local diffRecv = self.runCtx.netInfo[self.config.Interface].BytesRecv - global.netState.recv
        local diffSend = self.runCtx.netInfo[self.config.Interface].BytesSent - global.netState.send
        local now = os.time()
        local diffTs = now - global.netState.ts
        if diffTs == 0 then
            diffTs = 1
        end
        return diffRecv / diffTs, diffSend / diffTs
    end

    -- updateNetWin 更新网络窗口，计算网速用
    local function updateNetWin()
        global.netState.ts = os.time()
        global.netState.send = self.runCtx.netInfo[self.config.Interface].BytesSent
        global.netState.recv = self.runCtx.netInfo[self.config.Interface].BytesRecv
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
        local recvSpeed, sendSpeed = calNetSpeed()
        local title = NewText("").AddString(1, NewString("网络")
            .SetFontSize(10))

        local desc = NewText("").AddString(1, NewString("↑" .. ByteToUiString(sendSpeed)).SetFontSize(9))
            .AddString(2, NewString("↓" .. ByteToUiString(recvSpeed)).SetFontSize(9))

        local netUi = NewProcessCircleUi().SetTitle(title)
            .SetDesc(desc)
            .SetProcessData(NewProcessData(recvSpeed, recvSpeed + sendSpeed))
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
        return memUi
    end

    local function getCpuDetail(cpus)
        local detail = [[
### cpu
|  VendorID   | Family  | Model | PhysicalID | CoreID | ModelName | Mhz | CacheSize |
|  ----  | ----  | ----  | ----  | ----  | ----  | ----  | ----  |
]]
        if type(cpus) == "table" then
            for i = 1, #cpus do
                local c = cpus[i]
                detail = detail .. string.format([[|%s|%s|%s|%s|%s|%s|%s|%s|
]],c.vendorId,c.family,c.model,c.physicalId,c.coreId,c.modelName,ByteToUiString(c.mhz),ByteToUiString(c.cacheSize))
            end
        end
        return detail
    end

    ---@return ProcessCircleUi
    local function getCpuUi()
        local cpuTitle = NewText("").AddString(1, NewString("cpu").SetFontSize(10))
        local cpuDesc = NewText("").AddString(1, NewString(tostring(#self.runCtx.cpuInfo) .. "核").SetFontSize(9))
            .AddString(2, NewString(string.format("%.0f%%", self.runCtx.cpuPercent[1])).SetFontSize(9))
        local cpuUi = NewProcessCircleUi().SetTitle(cpuTitle)
            .SetDesc(cpuDesc)
            .SetProcessData(NewProcessData(self.runCtx.cpuPercent[1], 100))
        cpuUi.SetDetail(getCpuDetail(self.runCtx.cpuInfo))
        return cpuUi
    end

    ---@return ProcessCircleUi
    local function getNasUi()
        diskName = self.config.Disk
        local nasTitle = NewText("").AddString(1, NewString("nas").SetFontSize(10))
        local nasDesc = NewText("").AddString(1,
                NewString(ByteToUiString(self.runCtx.diskInfo[diskName].Total)).SetFontSize(9))
            .AddString(2, NewString(string.format("%.0f%%", self.runCtx.diskInfo[diskName].UsedPercent)).SetFontSize(9))

        local nasUi = NewProcessCircleUi().SetTitle(nasTitle)
            .SetDesc(nasDesc)
            .SetProcessData(NewProcessData(self.runCtx.diskInfo[diskName].Used, self.runCtx.diskInfo[diskName].Total))
        return nasUi
    end

    ---@return LineChartUi
    local function getCpuLineChart()
        title = NewText("").AddString(1, NewString("cpu走势").SetFontSize(8).SetOpacity(0.8))
        cpuLineChart = NewLineChartUi()
        cpuLineChart.SetTitle(title)
        for i, v in ipairs(calCpuPoint()) do
            cpuLineChart.AddPoint(NewPoint(v, tostring(i)))
        end
        return cpuLineChart
    end

    ---@param app AppUI
    local function getAllMenu(app)
        --  运行命令
        local button = NewIconButton()
                .SetAction(NewAction("exec",{},"").AddInput("Cmd",NewInput("命令",1)))
                .SetIcon("terminal")
                .SetSize(14)
        app.AddMenu(button)
    end

    function self:GetUi()
        local app = NewApp()
        getAllMenu(app)
        app.AddUi(1, getNetUi())
        app.AddUi(1, getMemUi())
        app.AddUi(1, getCpuUi())
        app.AddUi(1, getNasUi())
        app.AddUi(2, getCpuLineChart())
        updateNetWin()
        return app.Data()
    end

    function self:Exec()
        local handle = io.popen(self.input.Cmd)
        local result = handle:read("*a")
        handle:close()
        return NewMarkdown(string.format("### 运行结果:\n```\n%s```",result))
    end

    function self:Clear()
        return {}
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

---@param ctx Ctx
function exec(ctx)
    print("exec start----")
    return NewSystem(ctx):Exec()
end

---@param ctx Ctx
function clear(ctx)
    print("clear start----")
    return NewSystem(ctx):Clear()
end