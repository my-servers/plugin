local json = require("json")
local lfs = require("lfs")
local global = {
    cpuPoints = {},
    netState = {
        recv = 0,
        send = 0,
        ts = 0,
    },
    menuInfo = "info",
    menuFile = "file",
    menu = "info",
    curDir = "/",
    pageStart = 1,
    page = 0,
    pageSize = 20,
    isConfigInterface = false,
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
                                          .SetProcessData(NewProcessData(recvSpeed, recvSpeed + sendSpeed))
        return netUi
    end

    local function getMemDetail(m)
        local detail = string.format([[
### 内存
|  项   | 值  |
| -- | -- |
| 总内存 | %s |
| 可用  | %s |
| 已使用  | %s |
]],ByteToUiString(m.Total),ByteToUiString(m.Available),ByteToUiString(m.Used))
        return detail
    end

    ---@return ProcessCircleUi
    local function getMemUi()
        local memTitle = NewText("").AddString(1, NewString("内存").SetFontSize(10))
        local memDesc = NewText("").AddString(1, NewString(ByteToUiString(self.runCtx.memInfo.Total)).SetFontSize(9))
                                   .AddString(2, NewString(string.format("%.0f%%", self.runCtx.memInfo.UsedPercent)).SetFontSize(9))

        local memUi = NewProcessCircleUi().SetTitle(memTitle)
                                          .SetDesc(memDesc)
                                          .SetProcessData(NewProcessData(self.runCtx.memInfo.Used, self.runCtx.memInfo.Total))
                                          .SetDetail(getMemDetail(self.runCtx.memInfo))
        return memUi
    end

    local function getCpuDetail(cpus)
        local detail = [[
### cpu
]]
        for i = 1, #cpus do
            local c = cpus[i]
            detail = detail .. string.format([[
#### 核%d
- VendorID: `%s`
- Family: `%s`
- Model: `%s`
- PhysicalID: `%s`
- CoreID: `%s`
- ModelName: `%s`
- Mhz: `%s`
- CacheSize: `%s`
]],i,c.VendorID,c.Family,c.Model,c.PhysicalID,c.CoreID,c.ModelName,
                    tostring(c.Mhz),
                    ByteToUiString(Tonumber(c.CacheSize)))
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
        local nasTitle = NewText("").AddString(1, NewString("磁盘").SetFontSize(10))
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
        -- 文件
        local fileButton = NewIconButton()
                .SetAction(NewAction("changeMenu",{},"").SetArg({id=global.menuFile}))
                .SetIcon("folder.circle")
                .SetSize(17)
        if global.menu == global.menuFile then
            fileButton.SetColor("#F00")
        end
        app.AddMenu(fileButton)

        -- 信息
        local infoButton = NewIconButton()
                .SetAction(NewAction("changeMenu",{},"").SetArg({id=global.menuInfo}))
                .SetIcon("chart.line.uptrend.xyaxis.circle")
                .SetSize(17)
        if global.menu == global.menuInfo then
            infoButton.SetColor("#F00")
        end
        app.AddMenu(infoButton)

        --  运行命令
        local button = NewIconButton()
                .SetAction(NewAction("exec",{},"").AddInput("Cmd",NewInput("命令",1)))
                .SetIcon("terminal")
                .SetSize(15)
        app.AddMenu(button)
    end


    function  self:ChangeMenu()
        global.menu = self.arg.id
    end

    function  self:ChoiceDir()
        if  self.arg["mode"] == "file" then
            return
        end
        global.curDir = self.arg["path"].."/"
        global.pageStart = 1
    end

    function  self:Back()
        local arr = string.split(global.curDir,"/")
        local res = {}
        for i = 1, #arr do
            if i < #arr-1 then
                res[i] = arr[i]
            end
        end
        global.curDir = string.join(res,"/").."/"
        global.pageStart = 1
        print("path-------", global.curDir )

    end

    function  self:Next()
        global.pageStart = global.pageStart+global.pageSize
    end

    function  self:Pre()
        global.pageStart = global.pageStart-global.pageSize
        if global.pageStart <= 0 then
            global.pageStart = 1
        end
    end


    function self:remove_dir(path)
        for entry in lfs.dir(path) do
            if entry ~= "." and entry ~= ".." then
                local entry_path = path .. "/" .. entry
                local attr = lfs.attributes(entry_path)

                if attr.mode == "directory" then
                    self:remove_dir(entry_path) -- 递归删除子目录
                else
                    os.remove(entry_path) -- 删除文件
                end
            end
        end

        local result, err = os.remove(path) -- 删除空目录
    end

    function  self:Delete()
        if self.arg["mode"] == "file" then
            os.remove(self.arg["path"])
            return
        end
        self:remove_dir(self.arg["path"])
    end
    ---@return table
    function self:getAllFiles(dir)
        local allFiles = {}
        for file in lfs.dir(dir) do
            if file ~= "." and file ~= ".." then
                local path = dir .. file
                local attr = lfs.attributes(path)
                if (attr["mode"] == "file" or attr["mode"] == "directory") then
                    attr["path"] = path
                    attr["name"] = file
                    -- print("file:-------",json.encode(attr))
                    table.insert(allFiles, attr)
                end
            end
        end
        return allFiles
    end

    ---@param app AppUI
    function self:addAllFileUi(app)
        local allFile = self:getAllFiles(global.curDir)
        local row = 101

        local pageStart = global.pageStart
        local pageEnd =  global.pageStart + global.pageSize
        if pageStart > #allFile then
            pageStart = 1
            pageEnd = global.pageSize
        end
        if pageEnd > #allFile then
            pageEnd = #allFile
        end
        if global.pageStart > 1 then
            local pre = NewIconButton()
                    .SetAction(NewAction("pre",{},""))
                    .SetIcon("chevron.left.circle")
                    .SetSize(17)
            app.AddMenu(pre)
        end
        local back = NewIconButton()
                .SetAction(NewAction("back",{},""))
                .SetIcon("arrowshape.turn.up.backward.circle")
                .SetSize(17)
        app.AddMenu(back)
        if pageEnd < #allFile then
            local next = NewIconButton()
                    .SetAction(NewAction("next",{},""))
                    .SetIcon("chevron.right.circle")
                    .SetSize(17)
            app.AddMenu(next)
        end



        for i = pageStart, pageEnd do
            local value  = allFile[i]
            local fontColor = "#000"
            if value["mode"] == "directory" then
                fontColor = "#00F"
            end
            local fileNameText = NewText("center").AddString(0, NewString(value["name"]).SetFontSize(12).SetColor(fontColor))
                                                  .AddString(1, NewString(ByteToUiString(value["size"])).SetBackendColor("#339999").SetFontSize(8).SetColor("#FFF"))
            local iconButton = NewIconButtonUi().SetIconButton(NewIconButton().SetDesc(fileNameText).SetAction(NewAction("choiceDir",value,"")))
                                                .SetHeight(50)
                                                .AddAction(NewAction("delete",value,"删除").SetCheck(true))
            app.AddUi(row, iconButton)
            if i%4 == 0 then
                row = row+1
            end
        end
    end

    function self:GetUi()
        local app = NewApp()
        if global.menu == global.menuInfo then
            app.AddUi(1, getNetUi())
            app.AddUi(1, getMemUi())
            app.AddUi(1, getCpuUi())
            app.AddUi(1, getNasUi())
            app.AddUi(2, getCpuLineChart())
            updateNetWin()
        else
            self:addAllFileUi(app)
        end
        getAllMenu(app)
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


function changeMenu(ctx)
    return NewSystem(ctx):ChangeMenu()
end

function choiceDir(ctx)
    return NewSystem(ctx):ChoiceDir()
end

function back(ctx)
    return NewSystem(ctx):Back()
end

function next(ctx)
    return NewSystem(ctx):Next()
end

function pre(ctx)
    return NewSystem(ctx):Pre()
end

function delete(ctx)
    return NewSystem(ctx):Delete()
end