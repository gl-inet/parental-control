--[[
    @object-name: parental-control
    @object-desc: 家长控制
--]]

local M = {}

local uci = require "uci"

local function apply()
    os.execute("/etc/init.d/parental-control restart")
end


--[[
    @method-type: call
    @method-name: get_app_list
    @method-desc: 获取可识别的应用列表。

    @out array   apps  可识别的应用列表。
    @out number  apps.id   应用id，全局唯一,应用ID从1001开始，0-1000为特殊ID，保留使用，其中1-8是类型ID，如果设置该ID则表示该类型下所有的应用。
    @out string  apps.name   应用名字。
    @out number  apps.type   应用类型（1:社交类，2:游戏类，3:视频类，4:购物类，5:音乐类，6:招聘类，7:下载类，8:门户网站）。
    

    @in-example: {"jsonrpc":"2.0","id":1,"method":"call","params":["","parental-control","get_app_list"]}
    @out-example: {"jsonrpc": "2.0", "id": 1, "result": {"apps":[{"id":8001,"name":"baidu","type":8,},{"id":1002,"name":"facebook","type":1,}]}}
--]]
M.get_app_list = function()
    local ret = {}
    local apps = {}

    for line in io.lines("/etc/parental_control/app_feature.cfg") do
        local fields = {}
        local app = {}
        for field in line:gmatch("[^%s:]+") do
            fields[#fields + 1] = field
        end
        if #fields > 0  then
            if string.sub(fields[1],1,1) ~= "#" then
                app["id"] = tonumber(fields[1])
                app["name"] = fields[2]
                app["type"] = math.floor(tonumber(fields[1])/1000)
                apps[#apps + 1] = app
            end
        end
    end
    ret["apps"] = apps
    return ret
end

--[[
    @method-type: call
    @method-name: add_group
    @method-desc: 添加设备组。

    @in string   name 分组名字
    @in string   default_rule 分组使用的默认规则集ID，规则集ID需对应rules参数中返回的规则集ID。
    @in array    macs 分组包含的设备MAC地址列表，为字符串类型。
    @in array   ?schedules 分组包含的日程列表，如果对应分组存在日程设置则传入该参数。
    @in number   ?schedules.week 日程在每周的第几天，允许范围为1-7，依次对应周一到周末。
    @in string   ?schedules.begin 日程的开始时间，格式为hh:mm，起始时间必须在结束时间之前。
    @in string   ?schedules.end 日程的结束时间，格式为hh:mm，结束时间必须在起始时间之后。
    @in string   ?schedules.rule 该日程需要使用的规则集ID，规则集ID需对应rules参数中传入的规则集ID。

    @out number ?err_code     错误码(-1: 缺少必须参数, -2:传递了shedules但是缺少必须参数)
    @out string ?err_msg      错误信息

    @in-example: {"jsonrpc":"2.0","id":1,"method":"call","params":["","parental-control","add_group",{"name":"group1","macs":["98:6B:46:F0:9B:A4","98:6B:46:F0:9B:A5"],"default_rule":"cfga067b","schedules":[{"week":1,"begin":"12:00","end":"13:00","rule":"cfga067c"},{"date":2,"begin":"17:00","end":"18:00","rule":"cfga067c"}]}]}
    @out-example: {"jsonrpc": "2.0", "id": 1, "result": {}}
--]]
M.add_group = function(params)
    if params.name == nil or params.default_rule == nil or params.macs == nil then
        return {
            err_code = -1,
            err_msg = "parameter missing"
        }
    end

    local c = uci.cursor()

    local sid = c:add("parental_control", "group")
    c:set("parental_control", sid, "name", params.name)
    c:set("parental_control", sid, "default_rule", params.default_rule)
    if type(params.macs) == "table" and #params.macs ~= 0  then
        c:set("parental_control", sid, "macs",params.macs)
    end
    if type(params.schedules) == "table" and #params.schedules ~= 0  then
        for i = 1, #params.schedules do
            if params.schedules[i].week == nil or params.schedules[i].begin == nil or params.schedules[i]["end"] == nil or params.schedules[i].rule == nil then
                return {
                    err_code = -2,
                    err_msg = "schedule parameter missing"
                }
            end
            local sche = c:add("parental_control", "schedule")
            c:set("parental_control", sche, "group",sid)
            c:set("parental_control", sche, "week",params.schedules[i].week)
            c:set("parental_control", sche, "begin",params.schedules[i].begin)
            c:set("parental_control", sche, "end",params.schedules[i]["end"])
            c:set("parental_control", sche, "rule",params.schedules[i].rule)
        end
    end
    c:commit("parental_control")
    apply()

    return {}
end

--[[
    @method-type: call
    @method-name: remove_group
    @method-desc: 移除设备组。

    @in string   id 需要删除的分组ID，分组ID通过get_config获取。

    @out number ?err_code     错误码(-1: 缺少必须参数)
    @out string ?err_msg      错误信息

    @in-example: {"jsonrpc":"2.0","id":1,"method":"call","params":["","parental-control","remove_group",{"id":"cfga01234b"}]}
    @out-example: {"jsonrpc": "2.0", "id": 1, "result": {}}
--]]
M.remove_group = function(params)
    if params.id == nil then
        return {
            err_code = -1,
            err_msg = "parameter missing"
        }
    end
    local c = uci.cursor()

    if params.id then
        c:delete("parental_control", params.id)
    end
    c:foreach("parental_control", "schedule", function(s)
        if s.group and s.group ==params.id then 
            c:delete("parental_control", s[".name"]) 
        end
    end)
    c:commit("parental_control")
    apply()

    return {}
end

--[[
    @method-type: call
    @method-name: set_group
    @method-desc: 修改设备组配置。

    @in string   id 需要设置的分组ID，分组ID通过get_config获取。
    @in string   name 分组名字
    @in string   default_rule 分组使用的默认规则集ID，规则集ID需对应rules参数中返回的规则集ID。
    @in array    macs 分组包含的设备MAC地址列表，为字符串类型。
    @in array   ?schedules 分组包含的日程列表，如果对应分组存在日程设置则传入该参数。
    @in array   ?schedules.week 日程在每周的第几天，允许范围为0-6，依次对应周末到周六。
    @in string   ?schedules.begin 日程的开始时间，格式为hh:mm，起始时间必须在结束时间之前。
    @in string   ?schedules.end 日程的结束时间，格式为hh:mm，结束时间必须在起始时间之后。
    @in string   ?schedules.rule 该日程需要使用的规则集ID，规则集ID需对应rules参数中传入的规则集ID。

    @out number ?err_code     错误码(-1: 缺少必须参数, -2:传递了shedules但是缺少必须参数)
    @out string ?err_msg      错误信息

    @in-example: {"jsonrpc":"2.0","id":1,"method":"call","params":["","parental-control","set_group",{"id":"cfga01234b","name":"group1","macs":["98:6B:46:F0:9B:A4","98:6B:46:F0:9B:A5"],"default_rule":"cfga067b","schedules":[{"week":[1,3,5],"begin":"12:00","end":"13:00","rule":"cfga067c"},{"date":2,"begin":"17:00","end":"18:00","rule":"cfga067c"}]}]}
    @out-example: {"jsonrpc": "2.0", "id": 1, "result": {}}
--]]
M.set_group = function(params)
    if params.id == nil  then
        return {
            err_code = -1,
            err_msg = "parameter missing"
        }
    end
    local c = uci.cursor()

    local sid = params.id
    -- 如果传递了name参数则进行修改
    if params.name ~= nil then
        c:set("parental_control", sid, "name", params.name)
    end

    -- 如果传递了default_rule参数则进行修改
    if params.default_rule ~= nil then
        c:set("parental_control", sid, "default_rule", params.default_rule)
    end

    -- 如果传递了macs参数则进行修改
    if params.macs ~= nil then
      if type(params.macs) == "table" and #params.macs ~= 0  then
        c:set("parental_control", sid, "macs",params.macs)
      else
        c:delete("parental_control", sid, "macs")
      end
    end

    -- 如果传递了日程参数则进行修改
    if params.schedules ~= nil then
        -- 先删除旧的日程
        c:foreach("parental_control", "schedule", function(s)
          if s.group and s.group ==params.id then 
              c:delete("parental_control", s[".name"])
          end
        end)
        -- 添加新日程
        if type(params.schedules) == "table" and #params.schedules ~= 0  then
          for i = 1, #params.schedules do
            if params.schedules[i].week == nil or params.schedules[i].begin == nil or params.schedules[i]["end"] == nil or params.schedules[i].rule == nil then
                return {
                    err_code = -2,
                    err_msg = "schedule parameter missing"
                }
            end
            local sche = c:add("parental_control", "schedule")
            c:set("parental_control", sche, "group",sid)
            c:set("parental_control", sche, "week",params.schedules[i].week)
            if(#params.schedules[i].begin < 8) then
                c:set("parental_control", sche, "begin",params.schedules[i].begin .. ":00")
            else
                c:set("parental_control", sche, "begin",params.schedules[i].begin)
            end
            if(#params.schedules[i].["end"] < 8) then
                c:set("parental_control", sche, "end",params.schedules[i]["end"] .. ":00")
            else
                c:set("parental_control", sche, "end",params.schedules[i]["end"])
            end
            c:set("parental_control", sche, "rule",params.schedules[i].rule)
          end
        end
    end

    c:commit("parental_control")
    apply()

    return {}
end

--[[
    @method-type: call
    @method-name: add_rule
    @method-desc: 添加规则集。

    @in string  name   规则集的名字，全局唯一，用于区分不同的规则集。
    @in string  color   规则集的标签颜色，提供给显示UI使用。
    @in array   apps   规则集包含的应用的ID或应用类型，为整数类型，应用和ID的对应关系通过get_app_list接口返回。
    @in array   ?exceptions   规则集的例外列表，为字符串类型，该列表相对于apps参数例外。一个规则集中最多添加32个例外特征，遵循应用特征描述语法，应用特征描述语法请参见doc.gl-inet.com

    @out number ?err_code     错误码(-1: 缺少必须参数)
    @out string ?err_msg      错误信息

    @in-example: {"jsonrpc":"2.0","id":1,"method":"call","params":["","parental-control","add_rule",{"name":"rule1","color":"#aabbccddee","apps":[1001,2002],"exceptions":["[tcp;;;www.google.com;;]"]}]}
    @out-example: {"jsonrpc": "2.0", "id": 1, "result": {}}
--]]
M.add_rule = function(params)
    if params.name == nil or  params.color == nil or  params.apps == nil then
        return {
            err_code = -1,
            err_msg = "parameter missing"
        }
    end
    local c = uci.cursor()

    local sid = c:add("parental_control", "rule")
    c:set("parental_control", sid, "name", params.name)
    c:set("parental_control", sid, "color", params.color)
    if type(params.apps) == "table" and #params.apps ~= 0  then
        c:set("parental_control", sid, "apps",params.apps)
    end
    if type(params.exceptions) == "table" and #params.exceptions ~= 0  then
        c:set("parental_control", sid, "exceptions",params.exceptions)
    end
    c:set("parental_control", sid, "action", "POLICY_DROP")
    c:commit("parental_control")
    apply()

    return {}
end

--[[
    @method-type: call
    @method-name: remove_rule
    @method-desc: 移除规则集。

    @in string   id 需要移除的规则ID，规则ID通过get_config获取。

    @out number ?err_code     错误码(-1: 缺少必须参数)
    @out string ?err_msg      错误信息

    @in-example: {"jsonrpc":"2.0","id":1,"method":"call","params":["","parental-control","remove_rule",{"id":"cfga067b"}]}
    @out-example: {"jsonrpc": "2.0", "id": 1, "result": {}}
--]]
M.remove_rule = function(params)
    if params.id == nil then
        return {
            err_code = -1,
            err_msg = "parameter missing"
        }
    end   
    local c = uci.cursor()

    if params.id then
        c:delete("parental_control", params.id)
    end
    c:commit("parental_control")
    apply()

    return {}
end

--[[
    @method-type: call
    @method-name: set_rule
    @method-desc: 设置规则集。

    @in string   id 需要设置的规则ID，规则ID通过get_config获取。
    @in string  color   规则集的标签颜色，UI使用。
    @in string  name   规则集的名字，全局唯一，用于区分不同的规则集。
    @in array   apps   规则集包含的应用的ID或应用类型，为整数类型，应用和ID的对应关系通过get_app_list接口返回。
    @in array   ?exceptions   规则集的例外列表，为字符串类型，该列表相对于apps参数例外，一个规则集中最多添加32个例外特征, 遵循应用特征描述语法，应用特征描述语法请参见doc.gl-inet.com

    @out number ?err_code     错误码(-1: 缺少必须参数)
    @out string ?err_msg      错误信息

    @in-example: {"jsonrpc":"2.0","id":1,"method":"call","params":["","parental-control","set_rule",{"id":"cfga067b","name":"rule1","color":"#aabbccddee","apps":[1001,2002],"exceptions":["[tcp;;;www.google.com;;]"]}]}
    @out-example: {"jsonrpc": "2.0", "id": 1, "result": {}}
--]]
M.set_rule = function(params)
    if params.id == nil or params.name == nil or  params.color == nil or  params.apps == nil then
        return {
            err_code = -1,
            err_msg = "parameter missing"
        }
    end
    local c = uci.cursor()

    local sid = params.id
    c:set("parental_control", sid, "name", params.name)
    c:set("parental_control", sid, "color", params.color)
    if type(params.apps) == "table" and #params.apps ~= 0  then
        c:set("parental_control", sid, "apps",params.apps)
    end
    if type(params.exceptions) == "table" and #params.exceptions ~= 0  then
        c:set("parental_control", sid, "exceptions",params.exceptions)
    else
        c:delete("parental_control", sid, "exceptions")
    end
    c:commit("parental_control")
    apply()

    return {}
end

function key_in_array(list,key)
    if list then
        for k, v in pairs(list) do
          if k == key then
           return true
          end
        end
    end
end 
  
--[[
    @method-type: call
    @method-name: get_config
    @method-desc: 获取家长控制参数配置。

    @out bool     enable  是否使能。
    @out bool     drop_anonymous  是否禁止匿名设备访问。
    @out bool     auto_update  是否自动更新特征库。
    @out array   ?rules  规则集列表,如果规则集不为空则返回。
    @out string  ?rules.id   规则集ID，全局唯一，用于区分不同的规则集。
    @out string  ?rules.name   规则集的名字。
    @out string  ?rules.color   规则集的标签颜色，UI使用。
    @out array   ?rules.apps   规则集包含的应用的ID列表，为整数类型，应用和ID的对应关系通过get_app_list接口返回。
    @out array   ?rules.exceptions   规则集的例外列表，为字符串类型，该列表相对于apps参数例外，遵循应用特征描述语法，应用特征描述语法请参见doc.gl-inet.com
    @out array   ?groups 设备分组列表,如果分组列表不为空则返回。
    @out string   ?groups.id 分组ID，全局唯一，用于区分不同的设备组。
    @out string   ?groups.name 分组名字。
    @out string   ?groups.default_rule 分组使用的默认规则集ID，规则集ID需对应rules参数中返回的规则集ID。
    @out array   ?groups.macs 分组包含的设备MAC地址列表，为字符串类型。
    @out array   ?groups.schedules 分组包含的日程列表，如果对应分组存在日程设置则返回该参数。
    @out number   ?groups.schedules.week 日常在每周的第几天，允许范围为0-6，依次对应周末到周六。
    @out string   ?groups.schedules.begin 日程的开始时间，格式为hh:mm，起始时间必须在结束时间之前。
    @out string   ?groups.schedules.end 日程的结束时间，格式为hh:mm，结束时间必须在起始时间之后。
    @out string   ?groups.schedules.rule 该日程需要使用的规则集ID，规则集ID需对应rules参数中返回的规则集ID。


    @in-example: {"jsonrpc":"2.0","id":1,"method":"call","params":["","parental-control","get_config"]}
    @out-example: {"jsonrpc": "2.0", "id": 1, "result": {"enable":true,"drop_anonymous":false,"auto_update":false,"rules":[{"id":"cfga067b","name":"rule1","color":"#aabbccddee","apps":[1001,2002],"exceptions":["[tcp;;;www.google.com;;]"]},{"id":"cfga067c","name":"rule2","color":"#aabbccddee","apps":[3003,4004],"exceptions":["[tcp;;;www.google.com;;]"]}],"groups":[{"name":"group1","macs":["98:6B:46:F0:9B:A4","98:6B:46:F0:9B:A5"],"default_rule":"cfga067a","schedules":[{"week":1,"begin":"12:00","end":"13:00","rule":"cfga067c"},{"date":2,"begin":"14:00","end":"15:00","rule":"cfga067c"}]}]}}
--]]
M.get_config = function()
    local c = uci.cursor()
    local ret = {}
    local enable = c:get("parental_control", "global", "enable") or '0'
    local drop_anonymous = c:get("parental_control", "global", "drop_anonymous") or '0'
    local auto_update = c:get("parental_control", "global", "auto_update") or '0'
    local rules ={}
    local groups ={}
    c:foreach("parental_control", "rule", function(s)
        local rule = {}
        rule["id"] = s[".name"]
        rule["name"] = s.name
        rule["color"] = s.color or "#FFFFFFFF"
        rule["apps"] = s.apps
        if s.exceptions then
            rule["exceptions"] = s.exceptions
        end
        rules[#rules + 1] = rule
    end)
    c:foreach("parental_control", "group", function(s)
        local group = {}
        group["id"] = s[".name"]
        group["name"] = s.name
        group["default_rule"] = s.default_rule
        if s.macs then
            group["macs"] = s.macs
        end
        groups[#groups + 1] = group
    end)

    c:foreach("parental_control", "schedule", function(s)
        local schedule = {}
        schedule["group"] = s.group
        schedule["week"] = tonumber(s.week)
        schedule["rule"] = s.rule
        schedule["begin"] = s.begin
        schedule["end"] = s["end"]
        if #groups then
            for i=1,#groups do
                if groups[i]["id"] == s.group then
                    if not key_in_array(groups[i],"schedules") then
                        groups[i]["schedules"] ={}
                    end
                    groups[i]["schedules"][#groups[i]["schedules"]+1] = schedule
                    break
                end
            end
        end
    end)

    ret["enable"] = enable ~= "0"
    ret["drop_anonymous"] = drop_anonymous ~= "0"
    ret["auto_update"] = auto_update ~= "0"
    ret["rules"] = rules
    ret["groups"] = groups

    return ret
end


--[[
    @method-type: call
    @method-name: set_config
    @method-desc: 设置基础配置。
    @in bool     enable  是否使能。
    @in bool     drop_anonymous  是否禁止匿名设备访问。
    @in bool     auto_update  是否自动更新特征库。

    @out number ?err_code     错误码(-1: 缺少必须参数)
    @out string ?err_msg      错误信息

    @in-example: {"jsonrpc":"2.0","id":1,"method":"call","params":["","parental-control","set_config",{"enable":true,"drop_anonymous":false,"auto_update":false}]}
    @out-example: {"jsonrpc": "2.0", "id": 1, "result": {}}
--]]
M.set_config = function(params)
    if params.enable == nil or params.drop_anonymous == nil or  params.update == nil then
        return {
            err_code = -1,
            err_msg = "parameter missing"
        }
    end
    local c = uci.cursor()

    c:set("parental_control", "global", "enable", params.enable and "1" or "0")
    c:set("parental_control", "global", "drop_anonymous", params.drop_anonymous and "1" or "0")
    c:set("parental_control", "global", "auto_update", params.update and "1" or "0")
    c:commit("parental_control")
    apply()

    return {}
end

--[[
    @method-type: call
    @method-name: update
    @method-desc: 手动更新特征库。
    

    @in-example: {"jsonrpc":"2.0","id":1,"method":"call","params":["","parental-control","update"]}
    @out-example: {"jsonrpc": "2.0", "id": 1, "result": {}}
--]]
M.update = function()
    return {}
end

return M
