local json = require("json")
local black = "#000"

function Tonumber(num)
    if num == nil then
        return 0
    end
    local res = tonumber(num)
    if res == nil then
        return 0
    end
    return res
end

local ByteToOther = { "B", "K", "M", "G", "T", "P" }
function ByteToUiString(number)
    local  num = Tonumber(number)
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
    return string.format("_%d_%d", Tonumber(row), Tonumber(col))
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

function string.join(input, delimiter)
    if type(input) ~= "table" then
        return ""
    end
    local res = ""
    for i = 1, #input do
        if i == #input then
            res = res .. tostring(input[i])
        else
            res = res .. tostring(input[i]) .. delimiter
        end
    end
    return res
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


function NewPieChartData(value,name,desc,color)
    local pieData = {
        data = {
            value = value,
            name = name,
            desc = desc,
            color = color
        }
    }
    function Data()
        return pieData.data
    end

    pieData.Data = Data
    return pieData
end

-- NewPoint 坐标点
---@param val number 值
---@param x string x
---@return Point 点
function NewPoint(val, x)
    ---@class Point
    local point = {
        ---@class PointData
        data = {
            val = Tonumber(val),
            x = tostring(x),
        }
    }
    -- SetVal 设置值
    ---@param val number 值
    ---@return Point
    local function SetVal(val)
        point.data.val = Tonumber(val)
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
            app = "",
            type = 0,
            client_terminal_action = {
                cmd = "",
            },
            client_open_url_action = {
                url = "",
            },
            client_copy_action = {
                text = "",
            }
        }
    }

    -- SetApp 设置展示的名字
    ---@param app string app
    ---@return Action
    local function SetApp(app)
        a.actionData.app = app
        return a
    end

    -- SetTerminalAction 设置执行终端命令
    ---@param cmd string 命令
    ---@return Action
    local function SetTerminalAction(cmd)
        a.actionData.type = 1
        a.actionData.client_terminal_action.cmd = cmd
        return a
    end

    -- SetOpenUrlAction 设置执行终端命令
    ---@param url string 命令
    ---@return Action
    local function SetOpenUrlAction(url)
        a.actionData.type = 2
        a.actionData.client_open_url_action.url = url
        return a
    end

    -- SetCopyAction 复制
    ---@param url string 命令
    ---@return Action
    local function SetCopyAction(text)
        a.actionData.type = 3
        a.actionData.client_copy_action.text = text
        return a
    end

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
    a.SetApp = SetApp
    a.SetTerminalAction = SetTerminalAction
    a.SetOpenUrlAction = SetOpenUrlAction
    a.SetCopyAction = SetCopyAction
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
            content   = tostring(str),
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
        s.strData.opacity = Tonumber(opacity)
        return s
    end

    -- SetFontSize 设置字体大小
    ---@param size number 字体大小
    ---@return String
    local function SetFontSize(size)
        s.strData.font_size = Tonumber(size)
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
    if Tonumber(total) > 0 then
        percent = math.ceil(Tonumber(cur) * 100 / total)
    end
    ---@class ProcessData
    local processData = {
        ---@class ProcessDataData
        data = {
            total = 100,
            cur = Tonumber(percent),
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
            text.rowColIndex[rowStr] = Tonumber(0)
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
            priority = Tonumber(priority),
            input_type = 0,
            input_list = nil
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

    local function AddList(name,val)
        if input.data.input_list == nil then
            input.data.input_list = {}
        end
        input.data.input_type = 1
        table.insert(input.data.input_list,{name=name,val=val})
        return input
    end

    input.Data = Data
    input.SetVal = SetVal
    input.AddList = AddList
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
        iconButton.data.size = Tonumber(size)
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

function AddBaseFunc(ui)
    -- AddAction 添加动作
    ---@param action Action 动作
    local function AddAction(action)
        if ui.data.actions == nil then
            ui.data.actions = {}
        end
        table.insert(ui.data.actions, action.Data())
        return ui
    end

    -- SetPage 设置二级页跳转
    local function SetPage(app,func,arg,name)
        ui.data.page = {
            app = app,
            func = func,
            arg = json.encode(arg),
            name = name,
        }
        return ui
    end

    -- SetHeight 添加动作
    ---@param height number 高度
    local function SetHeight(height)
        ui.data.height = height
        return ui
    end

    -- SetWidth 设置ui宽度
    local function SetWidth(width)
        ui.data.width = width
        return ui
    end

    -- SetOpacity 设置ui透明度
    local function SetOpacity(opacity)
        ui.data.opacity = opacity
        return ui
    end

    -- SetCornerRadius 设置ui圆角
    local function SetCornerRadius(radius)
        ui.data.corner_radius = radius
        return ui
    end

    -- SetBackgroundColor 设置ui背景
    local function SetBackgroundColor(color)
        ui.data.background_color = color
        return ui
    end

    -- SetDetail 添加详情
    ---@param detail string 详情 markdown
    local function SetDetail(detail)
        ui.data.detail = detail
        return ui
    end

    local function Data()
        return ui.data
    end

    ui.SetWidth = SetWidth
    ui.AddAction = AddAction
    ui.SetPage = SetPage
    ui.SetHeight = SetHeight
    ui.SetOpacity = SetOpacity
    ui.SetCornerRadius = SetCornerRadius
    ui.SetBackgroundColor = SetBackgroundColor
    ui.SetDetail = SetDetail
    ui.Data = Data
    return ui
end


---@return LineChartUi
function NewLineChartUi()
    ---@class LineChartUi
    local lineChart = {
        ---@class LineChartUiData
        data = {
            ui_type = 3,
            actions = nil,
            ui_line_chart = {},
            detail = "",
            height = 0,
            page = {},
        }
    }

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

    lineChart = AddBaseFunc(lineChart)

    lineChart.SetTitle = SetTitle
    lineChart.AddPoint = AddPoint
    return lineChart
end

---@return ProcessCircleUi 环形进度ui
function NewProcessCircleUi()
    ---@class ProcessCircleUi
    local processCircle = {
        ---@class ProcessCircleUiData
        data = {
            ui_type = 1,
            actions = nil,
            ui_process_circle = {},
            page = {},
        }
    }


    -- SetProcessData 设置进度数据
    ---@param data ProcessData 文本段
    ---@return ProcessCircleUi
    local function SetProcessData(data)
        if processCircle.data.ui_process_circle.process_data == nil then
            processCircle.data.ui_process_circle.process_data = {}
        end
        processCircle.data.ui_process_circle.process_data = data.Data()
        return processCircle
    end

    -- SetDesc 设置描述
    ---@param data Text 文本段
    ---@return ProcessCircleUi
    local function SetDesc(data)
        if processCircle.data.ui_process_circle.process_desc == nil then
            processCircle.data.ui_process_circle.process_desc = {}
        end
        processCircle.data.ui_process_circle.process_desc = data.Data()
        return processCircle
    end

    -- SetTitle 设置标题
    ---@param data Text 文本段
    ---@return ProcessCircleUi
    local function SetTitle(data)
        if processCircle.data.ui_process_circle.title == nil then
            processCircle.data.ui_process_circle.title = {}
        end
        processCircle.data.ui_process_circle.title = data.Data()
        return processCircle
    end

    local function SetProcessLineColor(color)
        processCircle.data.ui_process_circle.color = color
        return processCircle
    end

    processCircle = AddBaseFunc(processCircle)
    processCircle.SetProcessLineColor = SetProcessLineColor
    processCircle.SetProcessData = SetProcessData
    processCircle.SetDesc = SetDesc
    processCircle.SetTitle = SetTitle
    return processCircle
end

---@return ProcessLineUi 条形进度ui
function NewProcessLineUi()
    ---@class ProcessLineUi
    local processLine = {
        ---@class ProcessLineUiData
        data = {
            ui_type = 2,
            actions = nil,
            ui_process_line = {},
            detail = "",
            height = 0,
            page = {},
        }
    }

    -- SetProcessData 设置进度数据
    ---@param data ProcessData 文本段
    ---@return ProcessLineUi
    local function SetProcessData(data)
        if processLine.data.ui_process_line.process_data == nil then
            processLine.data.ui_process_line.process_data = {}
        end
        processLine.data.ui_process_line.process_data = data.Data()
        return processLine
    end

    -- SetDesc 设置描述
    ---@param data Text 文本段
    ---@return ProcessLineUi
    local function SetDesc(data)
        if processLine.data.ui_process_line.process_desc == nil then
            processLine.data.ui_process_line.process_desc = {}
        end
        processLine.data.ui_process_line.process_desc = data.Data()
        return processLine
    end

    -- SetTitle 设置标题
    ---@param data Text 文本段
    ---@return ProcessLineUi
    local function SetTitle(data)
        if processLine.data.ui_process_line.title == nil then
            processLine.data.ui_process_line.title = {}
        end
        processLine.data.ui_process_line.title = data.Data()
        return processLine
    end

    local function SetProcessLineColor(color)
        processLine.data.ui_process_line.color = color
        return processLine
    end

    processLine = AddBaseFunc(processLine)
    processLine.SetProcessLineColor = SetProcessLineColor
    processLine.SetProcessData = SetProcessData
    processLine.SetDesc = SetDesc
    processLine.SetTitle = SetTitle
    return processLine
end

-- NewMarkdownUi markdown
---@return MarkdownUi 文本ui
function NewMarkdownUi()
    ---@class MarkdownUi
    local markdownUi = {
        ---@class NewMarkdownUiData
        data = {
            ui_type = 5,
            ui_markdown = {
                markdown = ""
            },
            actions = nil,
            height = 0,
            detail = "",
            page = {},
        }
    }

    -- SetText 添加markdown
    ---@param text string 文本段
    ---@return MarkdownUi
    local function SetMarkdown(text)
        markdownUi.data.ui_markdown.markdown = text
        return markdownUi
    end

    markdownUi = AddBaseFunc(markdownUi)
    markdownUi.SetMarkdown   = SetMarkdown
    return markdownUi
end

function NewChildUi()
    local child = {
        data = {
            ui_type = 100,
            ui_child = {
                ui_row = nil
            },
            actions = nil,
            height = 0,
            width = 0,
            background_color = "",
            corner_radius = 0,
            opacity = 0,
            page = {},
        }
    }

    local function AddChildUi(uiRow)
        if child.data.ui_child.ui_row == nil then
            child.data.ui_child.ui_row  = {}
        end
        table.insert(child.data.ui_child.ui_row, uiRow.Data())
        return child
    end

    child = AddBaseFunc(child)

    child.AddChildUi = AddChildUi
    return child
end


-- NewTextUi textui
---@return TextUi 文本ui
function NewTextUi()
    ---@class TextUi
    local textUi = {
        ---@class TextUiData
        data = {
            ui_type = 0,
            ui_text = nil,
            actions = nil,
            height = 0,
            width = 0,
            background_color = "",
            corner_radius = 0,
            opacity = 0,
            detail = "",
            page = {},
        }
    }

    -- SetText 添加文本段
    ---@param text Text 文本段
    ---@return TextUi
    local function SetText(text)
        textUi.data.ui_text = text.Data()
        return textUi
    end

    textUi = AddBaseFunc(textUi)
    textUi.SetText   = SetText
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
            page = {},
        }
    }


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

    iconButtonUi = AddBaseFunc(iconButtonUi)
    iconButtonUi.SetIconButton = SetIconButton
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
            app.rowColIndex[row] = Tonumber(0)
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


function NewUiRow()
    ---@class UiRow
    local uiRoW = {
        data = {
            height = 0,
            uis = {},
        }
    }

    local function AddUi(ui)
        table.insert(uiRoW.data.uis, ui.Data())
        return uiRoW
    end

    local function Data()
        return uiRoW.data
    end

    uiRoW.Data = Data
    uiRoW.AddUi = AddUi

    return uiRoW
end

function NewPageSection(name)
    ---@class PageSection
    local pageSection = {
        data = {
            name = name,
            ui_row = nil,
            menu = nil,
            pre = {},
            next = {},
            page_info = "",
        }
    }

    function AddUiRow(uiRow)
        if pageSection.data.ui_row == nil then
            pageSection.data.ui_row = {}
        end
        table.insert(pageSection.data.ui_row, uiRow.Data())
        return pageSection
    end

    local function AddMenu(menu)
        if pageSection.data.menu == nil then
            pageSection.data.menu = {}
        end
        table.insert(pageSection.data.menu, menu.Data())
        return pageSection
    end

    local function Data()
        return pageSection.data
    end

    local function SetPre(action)
        pageSection.data.pre = action.Data()
        return pageSection
    end

    local function SetNext(action)
        pageSection.data.next = action.Data()
        return pageSection
    end

    local function SetPageInfo(info)
        pageSection.data.page_info = info
        return pageSection
    end

    pageSection.AddUiRow = AddUiRow
    pageSection.AddMenu = AddMenu
    pageSection.SetPre = SetPre
    pageSection.SetNext = SetNext
    pageSection.SetPageInfo = SetPageInfo
    pageSection.Data = Data

    return pageSection
end


function NewPage()
    ---@class Page
    local page = {
        data = {
            page_section_data = {}
        }
    }

    local function AddPageSection(pageSection)
        table.insert(page.data.page_section_data, pageSection.Data())
        return page
    end

    local function Data()
        return page.data
    end

    page.AddPageSection = AddPageSection
    page.Data = Data
    return page
end


function NewToast(text,icon,color)
    return {
        text = tostring(text),
        color = tostring(color),
        icon = tostring(icon),
        show_result_type = 1,
    }
end

function NewMarkdown(text)
    return {
        text = tostring(text),
        show_result_type = 2,
    }
end

function NewWidget()
    local widget = {
        data = {
            medium = nil,
            small = nil,
            large = nil,
        }
    }

    local function AddSmallWidget(uiRow)
        if widget.data.small == nil then
            widget.data.small = {}
        end
        table.insert(widget.data.small, uiRow.Data())
        return widget
    end

    local function AddMediumWidget(uiRow)
        if widget.data.medium == nil then
            widget.data.medium = {}
        end
        table.insert(widget.data.medium, uiRow.Data())
        return widget
    end

    local function AddLargeWidget(uiRow)
        if widget.data.large == nil then
            widget.data.large = {}
        end
        table.insert(widget.data.large, uiRow.Data())
        return widget
    end

    local function Data()
        return widget.data
    end

    widget.AddSmallWidget = AddSmallWidget
    widget.AddMediumWidget = AddMediumWidget
    widget.AddLargeWidget = AddLargeWidget
    widget.Data = Data
    return widget
end

function NewImageUi(url)
    local img = {
        data = {
            ui_type = 6,
            ui_image = {
                color = "",
                url = url,
                corner_radius = 0,
            },
            actions = nil,
            height = 0,
            width = 0,
            background_color = "",
            corner_radius = 0,
            opacity = 0,
            detail = "",
            page = {},
        }
    }

    local function SetUrl(url)
        img.data.ui_image.url = url
        return img
    end


    local function SetColor(color)
        img.data.ui_image.color = color
        return img
    end
    img = AddBaseFunc(img)
    img.SetUrl = SetUrl
    img.SetColor = SetColor
    return img
end

function NewPieChart()
    local pie = {
        data = {
            ui_type = 7,
            ui_pie_chart = {
                inner_radius = 0,
                pie_chart_data = nil,
                desc = {},
            },
            actions = nil,
            height = 0,
            width = 0,
            background_color = "",
            corner_radius = 0,
            opacity = 0,
            detail = "",
            page = {},
        }
    }

    local function SetInnerRadius(radius)
        pie.data.ui_pie_chart.inner_radius = radius
        return pie
    end

    local function AddPieChartData(data)
        if pie.data.ui_pie_chart.pie_chart_data == nil then
            pie.data.ui_pie_chart.pie_chart_data = {}
        end
        table.insert(pie.data.ui_pie_chart.pie_chart_data, data.Data())
        return pie
    end

    local function AddDesc(text)
        pie.data.ui_pie_chart.desc = text.Data()
        return pie
    end

    pie = AddBaseFunc(pie)
    pie.AddPieChartData = AddPieChartData
    pie.SetInnerRadius = SetInnerRadius
    pie.AddDesc = AddDesc
    return pie
end




