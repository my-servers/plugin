local json = require("json")
local strings = require("strings")


local global = {
    listKey = "list",
    checkTime = 0,
    allPort = {},
}


function testPort(port)
    local tcp = require("tcp")
    if port == nil or port == "" then
        return true
    end
    local conn, err = tcp.open(port)
    if err then
        return false
    end
    conn:close()
    return true
end

function asyncUpdatePortStatus(data)
    local checkResult = {}
    for k, v in pairs(data) do
        checkResult[v.id] = testPort(v.host_port)
    end
    return {result=checkResult}
end


---@param ctx Ctx
---@return SelfServer
local function NewSelfServer(ctx)
    ---@class SelfServer
    local self = {
        arg    = ctx.arg,    -- 参数
        input  = ctx.input,  -- 输入
        config = ctx.config, -- 配置
        runCtx = ctx.ctx     -- 运行上下文
    }


    function checkHealthy(data)
        local now = os.time()
        if now - global.checkTime < tonumber(self.config.Second) then
            return
        end
        global.checkTime = now
        go("asyncUpdatePortStatus", function(arg)
            global.allPort = arg.result
        end,data)
    end

    function guessIcon(url)
        if strings.contains(url,"http://") == true then
            return "safari"
        elseif strings.contains(url,"https://") == true  then
            return "safari"
        elseif strings.contains(url,"wechat://") == true  then
            return "message.circle.fill"
        elseif strings.contains(url,"sms://") == true  then
            return "ellipsis.message"
        elseif strings.contains(url,"tel://") == true  then
            return "phone.circle"
        elseif strings.contains(url,"mailto://") == true  then
            return "person.circle.fill"
        else
            return "paperplane.circle"
        end
    end

    function self:Update()
        local jsonData = db.get(global.listKey)
        local list = json.decode(jsonData)
        checkHealthy(list)

        table.sort(list, function(a, b)
            return tonumber(a.id) > tonumber(b.id)
        end)
        local app = NewApp().AddMenu(
                NewIconButton().SetIcon("plus.circle").SetAction(
                        NewAction("add",{},"添加")
                                .AddInput("name",NewInput("名字",3))
                                .AddInput("host_port",NewInput("探活ip(域名)端口",2))
                                .AddInput("url",NewInput("url",1))
                                .AddInput("icon",NewInput("图标",1))
                ).SetSize(17)
        )
        local index = 1
        local col = self.config.ColNum
        if col == 0 then
            col = 4
        end
        for key, value in pairs(list) do
            local color = "#F00"
            local icon = "xmark.circle"
            if global.allPort[value.id] then
                color = "#000"
                icon = value.icon
                if icon == "" then
                    icon = guessIcon(value.url)
                end
            end
            local service = NewIconButtonUi()
                    .SetIconButton(
                    NewIconButton().SetDesc(
                            NewText("").AddString(1, NewString("").SetColor(color).SetOpacity(0.6))
                                       .AddString(2, NewString(value.name).SetColor(color).SetOpacity(0.6))
                    ).SetAction(
                            NewAction("",{},"").SetOpenUrlAction(value.url)
                    ).SetIcon(icon)
                                   .SetSize(20)
                                   .SetColor(color)
            ).AddAction(
                    NewAction("edit",value,"编辑")
                            .AddInput("name",NewInput("名字",3).SetVal(value.name))
                            .AddInput("host_port",NewInput("探活ip(域名)端口",2).SetVal(value.host_port))
                            .AddInput("url",NewInput("url",1).SetVal(value.url))
                            .AddInput("icon",NewInput("图标",0).SetVal(value.icon))
            )
                    .AddAction(
                    NewAction("copy",value,"复制").SetCheck(true)
            )
                    .AddAction(
                    NewAction("del",value,"删除").SetCheck(true)
            )
            app.AddUi(index, service)
            if key%col ==0  then
                index = index + 1
            end
        end

        return app.Data()
    end


    function self:Del()
        local jsonData = db.get(global.listKey)
        local list = json.decode(jsonData)
        for key, value in pairs(list) do
            if value.id == self.arg.id then
                table.remove(list,key)
            end
        end
        db.set(global.listKey,json.encode(list))
        return {}
    end


    function self:Add()
        local jsonData = db.get(global.listKey)
        local list = json.decode(jsonData)
        table.insert(list,{
            id = os.time(),
            name = self.input.name,
            host_port = self.input.host_port,
            url =  self.input.url,
            icon = self.input.icon,
        })
        db.set(global.listKey,json.encode(list))
        return {}
    end

    function self:Edit()
        local jsonData = db.get(global.listKey)
        local list = json.decode(jsonData)
        for i = 1, #list do
            local temp = list[i]
            if temp.id == self.arg.id then
                list[i].name = self.input.name
                list[i].host_port = self.input.host_port
                list[i].url = self.input.url
                list[i].icon = self.input.icon
            end
        end
        db.set(global.listKey,json.encode(list))
        return {}
    end

    function self:Copy()
        local jsonData = db.get(global.listKey)
        local list = json.decode(jsonData)
        table.insert(list, {
            id = os.time(),
            name = self.arg.name.."_copy",
            host_port = self.arg.host_port,
            url = self.arg.url,
            icon = self.arg.icon,
        })
        db.set(global.listKey,json.encode(list))
        return {}
    end
    return self
end

function register()

    local listJson = db.get(global.listKey)
    local list = json.decode(listJson)
    local hasMyServers = false
    if list == nil then
        list = {}
    end
    for key, value in pairs(list) do
        if value.url == "https://myservers.codeloverme.cn" then
            hasMyServers = true
        end
    end
    if hasMyServers or #list > 0 then
        return
    end
    local list = {
        {
            id = os.time(),
            name = "MyServers",
            host_port = "myservers.codeloverme.cn:443",
            url = "https://myservers.codeloverme.cn",
            icon = "safari",
        }
    }
    db.set(global.listKey,json.encode(list))
    return {
    }
end


function update(ctx)
    return NewSelfServer(ctx):Update()
end

function del(ctx)
    return NewSelfServer(ctx):Del()
end

function add(ctx)
    return NewSelfServer(ctx):Add()
end

function edit(ctx)
    return NewSelfServer(ctx):Edit()
end


function copy(ctx)
    return NewSelfServer(ctx):Copy()
end