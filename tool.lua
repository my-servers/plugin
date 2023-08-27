local json = require("json")
local black = "#000"

local ByteToOther = { "B", "K", "M", "G", "T", "P" }
function ByteToUiString(number)
   local  num = tonumber(number)
    if num <= 0 then
        return "0B"
    end
    local count = 1
    while num / 1024 > 1 do
        count = count + 1
        num = num / 1024
    end
    return string.format("%.1f%s", num, ByteToOther[count])
end

function getKeyByRowCol(row, col)
    return string.format("_%d_%d", tonumber(row), tonumber(col))
end

function Tonumber(num)
    if num == nil then
        return 0
    end
    return tonumber(num)
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

---@class CpuInfo
local cpuInfo = {
    CPU        = "",
    VendorID   = "",
    Family     = "",
    Model      = "",
    Stepping   = 0,
    PhysicalID = "",
    CoreID     = "",
    Cores      = 0,
    ModelName  = "",
    Mhz        = 0,
    CacheSize  = 0,
    ---@type table<number,string>
    Flags      = {},
    Microcode  = "",
}


---@class Ctx
local ctx = {
    ---@type table<string,string>
    arg = {},
    ---@type table<string,InputData>
    input = {},
    ---@type table<string,string>
    config = {},
    ---@class RunCtx
    ctx = {
        ---@type table<number,CpuInfo>
        cpuInfo = {},
        ---@type table<number,number>
        cpuPercent = {},
        ---@class MemInfo
        memInfo = {
            Total = 0,
            UsedPercent = 0,
        },
    }
}

-----------------------------------基础数据-------------------------------------------------

-- NewPoint 坐标点
---@param val number 值
---@param x string x
---@return Point 点
function NewPoint(val, x)
    ---@class Point
    local point = {
        ---@class PointData
        data = {
            val = tonumber(val),
            x = tostring(x),
        }
    }
    -- SetVal 设置值
    ---@param val number 值
    ---@return Point
    local function SetVal(val)
        point.data.val = tonumber(val)
        return point
    end

    -- SetX 设置x
    ---@param x string 值
    ---@return Point
    local function SetX(x)
        point.data.x = tostring(x)
        return point
    end

    ---@return PointData
    local function Data()
        return point.data
    end

    point.SetVal = SetVal
    point.SetX = SetX
    point.Data = Data
    return point
end

-- NewAction 动作
---@param func string 执行的函数
---@param arg table 参数
---@param name string 显示的名字
---@return Action 动作
function NewAction(func, arg, name)
    ---@class Action
    local a = {
        ---@class ActionData
        actionData = {
            func = tostring(func),
            arg = json.encode(arg),
            name = tostring(name),
            input = nil,
            icon = "",
            check = false,
        }
    }

    -- SetIcon 设置展示的名字
    ---@param icon string icon
    ---@return Action
    local function SetIcon(icon)
        a.actionData.icon = tostring(icon)
        return a
    end

    -- SetCheck
    ---@param check boolean icon
    ---@return Action
    local function SetCheck(check)
        a.actionData.check = check
        return a
    end

    -- SetName 设置展示的名字
    ---@param name string 名字
    ---@return Action
    local function SetName(name)
        a.actionData.name = tostring(name)
        return a
    end

    -- SetFunc 设置展示的名字
    ---@param func string 函数名
    ---@return Action
    local function SetFunc(func)
        a.actionData.func = tostring(func)
        return a
    end

    -- SetArg 设置展示的名字
    ---@param arg table 参数
    ---@return Action
    local function SetArg(arg)
        a.actionData.arg = json.encode(arg)
        return a
    end

    ---- AddInput 添加用户输入
    -----@param key string key
    -----@param input Input 输入
    -----@return Action
    local function AddInput(key, input)
        if a.actionData.input == nil then
            a.actionData.input = {}
        end
        a.actionData.input[tostring(key)] = input.Data()
        return a
    end

    ---@return ActionData
    local function Data()
        return a.actionData
    end

    a.SetName = SetName
    a.SetFunc = SetFunc
    a.SetArg  = SetArg
    a.Data    = Data
    a.AddInput = AddInput
    a.SetCheck = SetCheck
    a.SetIcon = SetIcon
    return a
end

-- NewString 一段字符
---@param str string 内容
---@return String 字符内容
function NewString(str)
    ---@class String
    local s = {
        ---@class StringData
        strData = {
            content   = str,
            color     = black,
            opacity   = 1,
            font_size = 12,
        }
    }

    -- SetContent 设置内容
    ---@param content string 内容
    ---@return String
    local function SetContent(content)
        s.strData.content = content
        return s
    end

    -- SetColor 设置颜色
    ---@param color string 颜色
    ---@return String
    local function SetColor(color)
        s.strData.color = tostring(color)
        return s
    end


    -- SetBackendColor 设置背景颜色
    ---@param color string 颜色
    ---@return String
    local function SetBackendColor(color)
        s.strData.backend_color = tostring(color)
        return s
    end

    -- SetOpacity 设置透明度
    ---@param opacity number 透明度
    ---@return String
    local function SetOpacity(opacity)
        s.strData.opacity = tonumber(opacity)
        return s
    end

    -- SetFontSize 设置字体大小
    ---@param size number 字体大小
    ---@return String
    local function SetFontSize(size)
        s.strData.font_size = tonumber(size)
        return s
    end

    ---@return StringData
    local function Data()
        return s.strData
    end
    s.SetContent  = SetContent
    s.SetColor    = SetColor
    s.SetBackendColor    = SetBackendColor
    s.SetOpacity  = SetOpacity
    s.SetFontSize = SetFontSize
    s.Data        = Data

    return s
end

-- NewProcessData 进度数据
---@return ProcessData 进度数据
function NewProcessData(cur, total)
    local percent = 0
    if tonumber(total) > 0 then
        percent = math.ceil(cur * 100 / total)
    end
    ---@class ProcessData
    local processData = {
        ---@class ProcessDataData
        data = {
            total = 100,
            cur = tonumber(percent),
        }
    }

    ---@return ProcessDataData
    local function Data()
        return processData.data
    end

    processData.Data = Data
    return processData
end

-- NewText 文本
---@param alignment string 对齐方式，leading 左，center 中，trailing 右
---@return Text 多段文本
function NewText(alignment)
    ---@class Text
    local text = {
        rowColIndex = {},
        ---@class TextData
        textData = {
            texts = nil,
            alignment = alignment,
        }
    }

    -- SetString 添加文本段
    ---@param row string 行
    ---@param col string 列
    ---@param str String 文本
    ---@return Text
    local function SetString(row, col, str)
        if text.textData.texts == nil then
            text.textData.texts = {}
        end
        text.textData.texts[getKeyByRowCol(row, col)] = str.Data()
        return text
    end

    -- AddString 添加文本段
    ---@param row string 行
    ---@param str String 文本
    ---@return Text
    local function AddString(row, str)
        rowStr = tostring(row)
        if text.rowColIndex[rowStr] == nil then
            text.rowColIndex[rowStr] = tonumber(0)
        end
        text.rowColIndex[rowStr] = text.rowColIndex[rowStr] + 1
        SetString(row, text.rowColIndex[rowStr], str)
        return text
    end

    -- SetAlignment 设置对齐
    ---@param a string 对齐方式leading左，center中，trailing右
    ---@return Text
    local function SetAlignment(a)
        text.textData.alignment = a
        return text
    end

    ---@return TextData
    local function Data()
        return text.textData
    end

    text.SetString = SetString
    text.Data = Data
    text.SetAlignment = SetAlignment
    text.AddString = AddString
    return text
end

-- NewInput 输入
---@param desc string 描述
---@param priority number 排序
---@return Input 输入
function NewInput(desc, priority)
    ---@class Input
    local input = {
        ---@class InputData
        data = {
            val = "",
            desc = tostring(desc),
            priority = tonumber(priority),
        }
    }

    ---@return Input
    local function SetVal(val)
        input.data.val = tostring(val)
        return input
    end

    ---@return InputData
    local function Data()
        return input.data
    end

    input.Data = Data
    input.SetVal = SetVal
    return input
end

-- NewIconButton 输入
---@return IconButton 按钮
function NewIconButton()
    ---@class IconButton
    local iconButton = {
        ---@class IconButtonData
        data = {
            icon = "",
            color = "",
            size = 10,
            id = "",
            desc = nil,
            action = nil,
            extend = nil,
        }
    }

    ---SetIcon 设置icon
    ---@param icon string icon
    ---@return IconButton
    local function SetIcon(icon)
        iconButton.data.icon = tostring(icon)
        return iconButton
    end

    ---SetColor 设置颜色
    ---@param color string 颜色
    ---@return IconButton
    local function SetColor(color)
        iconButton.data.color = tostring(color)
        return iconButton
    end

    ---SetSize 设置大小
    ---@param size number icon大小
    ---@return IconButton
    local function SetSize(size)
        iconButton.data.size = tonumber(size)
        return iconButton
    end

    -- SetDesc 设置描述
    ---@param desc Text 动作
    ---@return IconButton
    local function SetDesc(desc)
        if iconButton.data.desc == nil then
            iconButton.data = {}
        end
        iconButton.data.desc = desc.Data()
        return iconButton
    end

    -- SetAction 设置动作
    ---@param action Action 动作
    ---@return IconButton
    local function SetAction(action)
        if iconButton.data.action == nil then
            iconButton.data.action = {}
        end
        iconButton.data.action = action.Data()
        return iconButton
    end

    -- SetId 设置id
    ---@param id string key
    ---@return IconButton
    local function SetId(id)
        iconButton.data.id = tostring(id)
        return iconButton
    end

    ---@return IconButtonData
    local function Data()
        return iconButton.data
    end

    iconButton.SetIcon = SetIcon
    iconButton.SetColor = SetColor
    iconButton.SetSize = SetSize
    iconButton.SetDesc = SetDesc
    iconButton.SetAction = SetAction
    --iconButton.AddInput = AddInput
    iconButton.SetId = SetId
    iconButton.Data = Data

    return iconButton
end

-----------------------------------所有ui-------------------------------------------------
---@return LineChartUi
function NewLineChartUi()
    ---@class LineChartUi
    local lineChart = {
        ---@class LineChartUiData
        data = {
            ui_type = 3,
            actions = nil,
            ui_line_chart = {},
        }
    }

    -- AddAction 添加动作
    ---@param action Action 动作
    ---@return LineChartUi
    local function AddAction(action)
        if lineChart.data.actions == nil then
            lineChart.data.actions = {}
        end
        table.insert(lineChart.data.actions, action.Data())
        return lineChart
    end

    -- SetTitle 设置标题
    ---@param data Text 文本段
    ---@return LineChartUi
    local function SetTitle(data)
        if lineChart.data.ui_line_chart.title == nil then
            lineChart.data.ui_line_chart.title = {}
        end
        lineChart.data.ui_line_chart.title = data.Data()
        return lineChart
    end

    -- AddPoint 设置标题
    ---@param point Point 文本段
    ---@return LineChartUi
    local function AddPoint(point)
        if lineChart.data.ui_line_chart.points == nil then
            lineChart.data.ui_line_chart.points = {}
        end
        table.insert(lineChart.data.ui_line_chart.points, point.Data())
        return lineChart
    end

    -- SetHeight 添加动作
    ---@param height number 高度
    ---@return LineChartUi
    local function SetHeight(height)
        lineChart.data.height = height
        return lineChart
    end

    ---@return LineChartUiData
    local function Data()
        return lineChart.data
    end

    lineChart.AddAction = AddAction
    lineChart.SetTitle = SetTitle
    lineChart.AddPoint = AddPoint
    lineChart.Data = Data
    lineChart.SetHeight = SetHeight
    return lineChart
end

---@return ProcessCircleUi 环形进度ui
function NewProcessCircleUi()
    ---@class ProcessCircleUi
    local processCircle = {
        ---@class ProcessCircleUiData
        processCircleUiData = {
            ui_type = 1,
            actions = nil,
            ui_process_circle = {},
        }
    }

    -- AddAction 添加动作
    ---@param action Action 动作
    ---@return ProcessCircleUi
    local function AddAction(action)
        if processCircle.processCircleUiData.actions == nil then
            processCircle.processCircleUiData.actions = {}
        end
        table.insert(processCircle.processCircleUiData.actions, action.Data())
        return processCircle
    end

    -- SetProcessData 设置进度数据
    ---@param data ProcessData 文本段
    ---@return ProcessCircleUi
    local function SetProcessData(data)
        if processCircle.processCircleUiData.ui_process_circle.process_data == nil then
            processCircle.processCircleUiData.ui_process_circle.process_data = {}
        end
        processCircle.processCircleUiData.ui_process_circle.process_data = data.Data()
        return processCircle
    end

    -- SetDesc 设置描述
    ---@param data Text 文本段
    ---@return ProcessCircleUi
    local function SetDesc(data)
        if processCircle.processCircleUiData.ui_process_circle.process_desc == nil then
            processCircle.processCircleUiData.ui_process_circle.process_desc = {}
        end
        processCircle.processCircleUiData.ui_process_circle.process_desc = data.Data()
        return processCircle
    end

    -- SetTitle 设置标题
    ---@param data Text 文本段
    ---@return ProcessCircleUi
    local function SetTitle(data)
        if processCircle.processCircleUiData.ui_process_circle.title == nil then
            processCircle.processCircleUiData.ui_process_circle.title = {}
        end
        processCircle.processCircleUiData.ui_process_circle.title = data.Data()
        return processCircle
    end

    -- SetHeight 添加动作
    ---@param height number 高度
    ---@return ProcessCircleUi
    local function SetHeight(height)
        processCircle.processCircleUiData.height = height
        return processCircle
    end

    ---@return ProcessCircleUiData
    local function Data()
        return processCircle.processCircleUiData
    end

    processCircle.SetProcessData = SetProcessData
    processCircle.SetDesc = SetDesc
    processCircle.SetTitle = SetTitle
    processCircle.Data = Data
    processCircle.AddAction = AddAction
    processCircle.SetHeight = SetHeight
    return processCircle
end

---@return ProcessLineUi 条形进度ui
function NewProcessLineUi()
    ---@class ProcessLineUi
    local processLine = {
        ---@class ProcessLineUiData
        processLineUiData = {
            ui_type = 2,
            actions = nil,
            ui_process_line = {},
        }
    }

    -- AddAction 添加动作
    ---@param action Action 动作
    ---@return ProcessLineUi
    local function AddAction(action)
        if processLine.processLineUiData.actions == nil then
            processLine.processLineUiData.actions = {}
        end
        table.insert(processLine.processLineUiData.actions, action.Data())
        return processLine
    end

    -- SetProcessData 设置进度数据
    ---@param data ProcessData 文本段
    ---@return ProcessCircleUi
    local function SetProcessData(data)
        if processLine.processLineUiData.ui_process_line.process_data == nil then
            processLine.processLineUiData.ui_process_line.process_data = {}
        end
        processLine.processLineUiData.ui_process_line.process_data = data.Data()
        return processLine
    end

    -- SetDesc 设置描述
    ---@param data Text 文本段
    ---@return ProcessCircleUi
    local function SetDesc(data)
        if processLine.processLineUiData.ui_process_line.process_desc == nil then
            processLine.processLineUiData.ui_process_line.process_desc = {}
        end
        processLine.processLineUiData.ui_process_line.process_desc = data.Data()
        return processLine
    end

    -- SetTitle 设置标题
    ---@param data Text 文本段
    ---@return ProcessCircleUi
    local function SetTitle(data)
        if processLine.processLineUiData.ui_process_line.title == nil then
            processLine.processLineUiData.ui_process_line.title = {}
        end
        processLine.processLineUiData.ui_process_line.title = data.Data()
        return processLine
    end

    -- SetHeight 添加动作
    ---@param height number 高度
    ---@return ProcessCircleUi
    local function SetHeight(height)
        processLine.processLineUiData.height = height
        return processLine
    end

    ---@return ProcessCircleUiData
    local function Data()
        return processLine.processLineUiData
    end

    processLine.SetProcessData = SetProcessData
    processLine.SetDesc = SetDesc
    processLine.SetTitle = SetTitle
    processLine.Data = Data
    processLine.AddAction = AddAction
    processLine.SetHeight = SetHeight
    return processLine
end

-- NewMarkdownUi markdown
---@return MarkdownUi 文本ui
function NewMarkdownUi()
    ---@class MarkdownUi
    local markdownUi = {
        ---@class NewMarkdownUiData
        uiMarkdownData = {
            ui_type = 5,
            ui_markdown = nil,
            actions = nil
        }
    }

    -- SetText 添加markdown
    ---@param text string 文本段
    ---@return MarkdownUi
    local function SetMarkdown(text)
        markdownUi.uiMarkdownData.ui_markdown = text
        return markdownUi
    end

    -- AddAction 添加动作
    ---@param action Action 动作
    ---@return MarkdownUi
    local function AddAction(action)
        if markdownUi.uiMarkdownData.actions == nil then
            markdownUi.uiMarkdownData.actions = {}
        end
        table.insert(markdownUi.uiMarkdownData.actions, action.Data())
        return markdownUi
    end

    -- SetHeight 添加动作
    ---@param height number 高度
    ---@return TextUi
    local function SetHeight(height)
        markdownUi.uiMarkdownData.height = height
        return markdownUi
    end

    ---@return TextUiData
    local function Data()
        return markdownUi.uiMarkdownData
    end

    markdownUi.SetMarkdown   = SetMarkdown
    markdownUi.Data      = Data
    markdownUi.AddAction = AddAction
    markdownUi.SetHeight = SetHeight
    return markdownUi
end

-- NewTextUi textui
---@return TextUi 文本ui
function NewTextUi()
    ---@class TextUi
    local textUi = {
        ---@class TextUiData
        uiTextData = {
            ui_type = 0,
            ui_text = nil,
            actions = nil
        }
    }

    -- SetText 添加文本段
    ---@param text Text 文本段
    ---@return TextUi
    local function SetText(text)
        textUi.uiTextData.ui_text = text.Data()
        return textUi
    end

    -- AddAction 添加动作
    ---@param action Action 动作
    ---@return TextUi
    local function AddAction(action)
        if textUi.uiTextData.actions == nil then
            textUi.uiTextData.actions = {}
        end
        table.insert(textUi.uiTextData.actions, action.Data())
        return textUi
    end

    -- SetHeight 添加动作
    ---@param height number 高度
    ---@return TextUi
    local function SetHeight(height)
        textUi.uiTextData.height = height
        return textUi
    end

    ---@return TextUiData
    local function Data()
        return textUi.uiTextData
    end

    textUi.SetText   = SetText
    textUi.Data      = Data
    textUi.AddAction = AddAction
    textUi.SetHeight = SetHeight
    return textUi
end

-- NewIconButtonUi 创建button ui
---@return IconButtonUi
function NewIconButtonUi()
    ---@class IconButtonUi
    local iconButtonUi = {
        buttonId = 1,
        ---@class IconButtonUiData
        data = {
            ui_type = 4,
            ui_icon_button = nil,
            actions = nil,
        }
    }
    -- AddAction 添加动作
    ---@param action Action 动作
    ---@return IconButtonUi
    local function AddAction(action)
        if iconButtonUi.data.actions == nil then
            iconButtonUi.data.actions = {}
        end
        table.insert(iconButtonUi.data.actions, action.Data())
        return iconButtonUi
    end

    -- SetIconButtonUi 添加文本
    ---@param iconButton IconButton 按钮
    ---@return IconButtonUi
    local function SetIconButton(iconButton)
        if iconButtonUi.data.ui_icon_button == nil then
            iconButtonUi.data.ui_icon_button = {}
        end
        iconButton.SetId(iconButtonUi.buttonId)
        iconButtonUi.buttonId = iconButtonUi.buttonId + 1
        iconButtonUi.data.ui_icon_button = iconButton.Data()
        return iconButtonUi
    end

    -- SetHeight 添加动作
    ---@param height number 高度
    ---@return IconButtonUi
    local function SetHeight(height)
        iconButtonUi.data.height = height
        return iconButtonUi
    end

    ---@return IconButtonUiData
    local function Data()
        return iconButtonUi.data
    end
    iconButtonUi.SetIconButton = SetIconButton
    iconButtonUi.Data = Data
    iconButtonUi.AddAction = AddAction
    iconButtonUi.SetHeight = SetHeight
    return iconButtonUi
end

-- NewApp 一个app的ui
---@return AppUI
function NewApp()
    ---@class AppUI
    local app = {
        menuIndex = 0,
        rowColIndex = {},
        ---@class AppUIData
        appData = {
            uis  = nil, -- 所有展示的ui
            menu = nil, -- 所有功能
        }
    }

    -- SetIconButtonUi 添加点击button ui
    ---@param row string 行
    ---@param col string 列
    ---@param ui TextUi|ProcessLineUi|ProcessCircleUi|IconButtonUi|LineChartUi ui
    ---@return AppUI
    local function SetUi(row, col, ui)
        if app.appData.uis == nil then
            app.appData.uis = {}
        end
        app.appData.uis[getKeyByRowCol(row, col)] = ui.Data()
        return app
    end


    -- AddIconButtonUi
    ---@param row string 行
    ---@param ui TextUi|ProcessLineUi|ProcessCircleUi|IconButtonUi|LineChartUi|MarkdownUi ui
    ---@return AppUI
    local function AddUi(row, ui)
        if app.rowColIndex[row] == nil then
            app.rowColIndex[row] = tonumber(0)
        end
        app.rowColIndex[row] = app.rowColIndex[row] + 1
        SetUi(row, app.rowColIndex[row], ui)
        return app
    end

    -- AddIconButtonUi
    ---@param button IconButton
    ---@return AppUI
    local function AddMenu(button)
        if app.appData.menu == nil then
            app.appData.menu = {}
        end
        button.SetId(tostring(app.menuIndex))
        app.menuIndex = app.menuIndex + 1
        table.insert(app.appData.menu, button.Data())
        return app
    end

    ---@return AppUIData
    local function Data()
        return app.appData
    end

    app.SetUi   = SetUi
    app.AddUi   = AddUi
    app.AddMenu = AddMenu
    app.Data    = Data
    return app
end

function NewToast(text,icon,color)
    return {
        text = tostring(text),
        color = tostring(color),
        icon = tostring(icon),
        show_toast = true,
    }
end