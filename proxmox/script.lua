local http = require("http")
local json = require("json")
local strings = require("strings")
local httpClient = http.client({
    timeout = 1, -- 超时1s
    headers = {["Content-Type"]="application/x-www-form-urlencoded"},
    insecure_ssl=true,
})

local global = {
    api = {
        login = "/api2/json/access/ticket",
        resources = "/api2/json/cluster/resources?type=",
        start = "/api2/json/nodes/%s/%s/status/start",
        shutdown = "/api2/json/nodes/%s/%s/status/shutdown",
        stop = "/api2/json/nodes/%s/%s/status/stop",
        reboot = "/api2/json/nodes/%s/%s/status/reboot",
    },
    ticket = "",
    CSRFPreventionToken = "",
    menu = {
        cur = "vm",
        node = "node",
        qemu = "vm",
        storage = "storage",
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


    function self:updateCookie()
        local username = self.config.Username
        if strings.contains(self.config.Username,"@") == false then
            username = username .. "@pam"
        end
        local data = string.format("username=%s&password=%s", username,self.config.Password)
        local req = http.request("POST",self.config.HostPort .. global.api.login, data)
        local loginRsp,err = httpClient:do_request(req)
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
        end
        rsp,err = httpClient:do_request(req)
        if err then
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
        end
        rsp,err = httpClient:do_request(req)
        if err then
            print("do post err------",err)
            error(err)
        end
        return rsp
    end

    local function getInfoFromApi()
        return get(self.config.HostPort .. global.api.resources..global.menu.cur,{})
    end

    ---@param app AppUI
    function self:showQemuStatus(app, status, index)
        local color = "#000"
        if status.status ~= "running" then
            color = "#F00"
        end

        local cpu = NewProcessCircleUi().SetProcessData(NewProcessData(status.cpu*100, 100)).SetTitle(NewText("").AddString(1, NewString("cpu").SetFontSize(10)))
                                        .SetDesc(NewText("").AddString(1, NewString(string.format("%.0f%%",status.cpu*100)).SetFontSize(8)))
        app.AddUi(index, cpu)

        local mem = NewProcessCircleUi().SetProcessData(NewProcessData(status.mem, status.maxmem)).SetTitle(NewText("").AddString(1, NewString("内存").SetFontSize(10)))
                                        .SetDesc(NewText("").AddString(1, NewString(ByteToUiString(status.maxmem)).SetFontSize(8))
                                                            .AddString(2,NewString(string.format("%.0f%%",status.mem*100/status.maxmem)).SetFontSize(8))
        )
        app.AddUi(index, mem)

        local disk = NewProcessCircleUi().SetProcessData(NewProcessData(status.disk, status.maxdisk)).SetTitle(NewText("").AddString(1, NewString("存储").SetFontSize(10)))
                                         .SetDesc(NewText("").AddString(1, NewString(ByteToUiString(status.maxdisk)).SetFontSize(8))
                                                             .AddString(2,NewString(string.format("%.0f%%",status.disk*100/status.maxdisk)).SetFontSize(8))
        )
        app.AddUi(index, disk)

        local text = NewText("center").AddString(1, NewString(status.name).SetFontSize(12))

        local statusInfo = NewString(status.status).SetBackendColor("#339999").SetFontSize(8).SetColor("#FFF")
        if status.status ~= "running" then
            statusInfo.SetBackendColor(color)
        end
        text.AddString(2, statusInfo)

        local name = NewTextUi().SetText(text)
                                .AddAction(NewAction("startVm",status,"启动"))
                                .AddAction(NewAction("shutdownVm",status,"关机"))
                                .AddAction(NewAction("stopVm",status,"停止"))
                                .AddAction(NewAction("restartVm",status,"重启"))
        app.AddUi(index, name)
    end

    ---@param app AppUI
    function self:showNodeStatus(app, status, index)
        local color = "#000"
        if status.status ~= "online" then
            color = "#F00"
        end

        local cpu = NewProcessCircleUi().SetProcessData(NewProcessData(status.cpu*100, 100)).SetTitle(NewText("").AddString(1, NewString("cpu").SetFontSize(10)))
                                        .SetDesc(NewText("").AddString(1, NewString(string.format("%.0f%%",status.cpu*100)).SetFontSize(8)))
        app.AddUi(index, cpu)

        local mem = NewProcessCircleUi().SetProcessData(NewProcessData(status.mem, status.maxmem)).SetTitle(NewText("").AddString(1, NewString("内存").SetFontSize(10)))
                                        .SetDesc(NewText("").AddString(1, NewString(ByteToUiString(status.maxmem)).SetFontSize(8))
                                                            .AddString(2,NewString(string.format("%.0f%%",status.mem*100/status.maxmem)).SetFontSize(8))
        )
        app.AddUi(index, mem)

        local disk = NewProcessCircleUi().SetProcessData(NewProcessData(status.disk, status.maxdisk)).SetTitle(NewText("").AddString(1, NewString("存储").SetFontSize(10)))
                                         .SetDesc(NewText("").AddString(1, NewString(ByteToUiString(status.maxdisk)).SetFontSize(8))
                                                             .AddString(2,NewString(string.format("%.0f%%",status.disk*100/status.maxdisk)).SetFontSize(8))
        )
        app.AddUi(index, disk)

        local text = NewText("center").AddString(1, NewString(status.node).SetFontSize(12).SetColor(color))
        local statusInfo = NewString(status.status).SetBackendColor("#339999").SetFontSize(8).SetColor("#FFF")
        if status.status ~= "online" then
            statusInfo.SetBackendColor(color)
        end
        text.AddString(2, statusInfo)

        local name = NewTextUi().SetText(text)
        app.AddUi(index, name)
    end

    ---@param app AppUI
    function self:showStorageStatus(app, status, index)
        local color = "#000"
        if status.status ~= "available" then
            color = "#F00"
        end
        local text = NewText("center ").AddString(1, NewString(status.storage).SetFontSize(10).SetColor(color))
        local iconButton = NewIconButtonUi().SetIconButton(NewIconButton().SetDesc(text).SetIcon("externaldrive").SetSize(20).SetColor(color))

        local disk = NewProcessCircleUi()
                .SetDesc(NewText("").AddString(1, NewString(ByteToUiString(status.maxdisk)).SetFontSize(8))
                                    .AddString(2, NewString(string.format("%.0f%%",status.disk*100/status.maxdisk)).SetFontSize(8)))
                .SetProcessData(NewProcessData(status.disk,status.maxdisk))
                .SetTitle(NewText("").AddString(1,NewString(status.storage).SetFontSize(10)))
        app.AddUi(index, disk)
    end

    function self:StartVm()
        local status = self.arg
        local url = string.format(global.api.start,status.node,status.id)
        local res = post(self.config.HostPort .. url,{},{})
        print("start vm----", json.encode(res))
    end

    function self:ShutdownVm()
        local status = self.arg
        local url = string.format(global.api.shutdown,status.node,status.id)
        local res = post(self.config.HostPort .. url,{},{})
        print("shutdown vm----", json.encode(res))
    end

    function self:StopVm()
        local status = self.arg
        local url = string.format(global.api.stop,status.node,status.id)
        local res = post(self.config.HostPort .. url,{},{})
        print("stop vm----", json.encode(res))
    end

    function self:RestartVm()
        local status = self.arg
        local url = string.format(global.api.reboot,status.node,status.id)
        local res = post(self.config.HostPort .. url,{},{})
        print("reboot vm----", json.encode(res))
    end


    function self:ChangeMenu()
        global.menu.cur = self.arg.id
    end

    ---@param app AppUI
    function self:addMenu(app)
        local node = NewIconButton().SetIcon("server.rack").SetSize(14).SetAction(NewAction("changeMenu",{id="node"},""))
        local storage = NewIconButton().SetIcon("externaldrive").SetSize(14).SetAction(NewAction("changeMenu",{id="storage"},""))
        local vm = NewIconButton().SetIcon("play.desktopcomputer").SetSize(14).SetAction(NewAction("changeMenu",{id="vm"},""))
        if global.menu.cur == global.menu.node then
            node.SetColor("#F00")
        end
        if global.menu.cur == global.menu.storage then
            storage.SetColor("#F00")
        end
        if global.menu.cur == global.menu.qemu then
            vm.SetColor("#F00")
        end

        app.AddMenu(node)
        app.AddMenu(storage)
        app.AddMenu(vm)
    end
    ---@param app AppUI
    function self:showStatus(app)
        local rsp = getInfoFromApi()
        if rsp.code == 401 then
            rsp = getInfoFromApi()
        end

        local allStatus = json.decode(rsp.body)
        table.sort(allStatus.data, function(a, b)
            return a.id  > b.id
        end)
        local index = 100
        for i = 1, #allStatus.data do
            local status = allStatus.data[i]
            if status.type == "qemu" then
                --- 虚拟机
                self:showQemuStatus(app, status, index)
                index = index + 1
            elseif status.type == "node" then
                -- 节点
                self:showNodeStatus(app, status, index)
                index = index + 1
            elseif status.type == "storage" then
                -- 存储
                self:showStorageStatus(app, status, index)
                if i%4 == 0 then
                    index = index + 1
                end
            end
        end
    end

    function self:Update()
        local app = NewApp()
        self:showStatus(app)
        self:addMenu(app)
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