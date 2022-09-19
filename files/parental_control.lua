--[[
    @object-name: parental-control
    @object-desc: 家长控制
--]]

local M = {}

local rpc = require "oui.rpc"
local ubus = require "ubus"
local uci = require "uci"

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

    return {"apps":[{"id":8001,"name":"baidu","type":8,},{"id":1002,"name":"facebook","type":1,}]}
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


    @in-example: {"jsonrpc":"2.0","id":1,"method":"call","params":["","parental-control","add_group",{"name":"group1","macs":["98:6B:46:F0:9B:A4","98:6B:46:F0:9B:A5"],"default_rule":"cfga067b","schedules":[{"week":1,"begin":"12:00","end":"13:00","rule":"cfga067c"},{"date":2,"begin":"17:00","end":"18:00","rule":"cfga067c"}]}]}
    @out-example: {"jsonrpc": "2.0", "id": 1, "result": {}}
--]]
M.add_group = function()

    return {}
end

--[[
    @method-type: call
    @method-name: remove_group
    @method-desc: 移除设备组。

    @in string   id 需要删除的分组ID，分组ID通过get_config获取。


    @in-example: {"jsonrpc":"2.0","id":1,"method":"call","params":["","parental-control","remove_group",{"id":"cfga01234b"}]}
    @out-example: {"jsonrpc": "2.0", "id": 1, "result": {}}
--]]
M.remove_group = function()

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
    @in number   ?schedules.week 日程在每周的第几天，允许范围为1-7，依次对应周一到周末。
    @in string   ?schedules.begin 日程的开始时间，格式为hh:mm，起始时间必须在结束时间之前。
    @in string   ?schedules.end 日程的结束时间，格式为hh:mm，结束时间必须在起始时间之后。
    @in string   ?schedules.rule 该日程需要使用的规则集ID，规则集ID需对应rules参数中传入的规则集ID。


    @in-example: {"jsonrpc":"2.0","id":1,"method":"call","params":["","parental-control","set_group",{"id":"cfga01234b","name":"group1","macs":["98:6B:46:F0:9B:A4","98:6B:46:F0:9B:A5"],"default_rule":"cfga067b","schedules":[{"week":1,"begin":"12:00","end":"13:00","rule":"cfga067c"},{"date":2,"begin":"17:00","end":"18:00","rule":"cfga067c"}]}]}
    @out-example: {"jsonrpc": "2.0", "id": 1, "result": {}}
--]]
M.set_group = function()

    return {}
end

--[[
    @method-type: call
    @method-name: add_rule
    @method-desc: 添加规则集。

    @in string  name   规则集的名字，全局唯一，用于区分不同的规则集。
    @in array   apps   规则集包含的应用的ID列表，为整数类型，应用和ID的对应关系通过get_app_list接口返回。
    @in array   exceptions   规则集的例外列表，为字符串类型，该列表相对于apps参数例外，遵循应用特征描述语法，应用特征描述语法请参见doc.gl-inet.com


    @in-example: {"jsonrpc":"2.0","id":1,"method":"call","params":["","parental-control","add_rule",{"name":"rule1","apps":[1001,2002],"exceptions":["[tcp;;;www.google.com;;]"]}]}
    @out-example: {"jsonrpc": "2.0", "id": 1, "result": {}}
--]]
M.add_rule = function()

    return {}
end

--[[
    @method-type: call
    @method-name: remove_rule
    @method-desc: 移除规则集。

    @in string   id 需要移除的规则ID，规则ID通过get_config获取。

    @in-example: {"jsonrpc":"2.0","id":1,"method":"call","params":["","parental-control","remove_rule",{"id":"cfga067b"}]}
    @out-example: {"jsonrpc": "2.0", "id": 1, "result": {}}
--]]
M.remove_rule = function()

    return {}
end

--[[
    @method-type: call
    @method-name: set_rule
    @method-desc: 设置规则集。

    @in string   id 需要设置的规则ID，规则ID通过get_config获取。
    @in string  name   规则集的名字，全局唯一，用于区分不同的规则集。
    @in array   apps   规则集包含的应用的ID列表，为整数类型，应用和ID的对应关系通过get_app_list接口返回。
    @in array   exceptions   规则集的例外列表，为字符串类型，该列表相对于apps参数例外，遵循应用特征描述语法，应用特征描述语法请参见doc.gl-inet.com


    @in-example: {"jsonrpc":"2.0","id":1,"method":"call","params":["","parental-control","set_rule",{"id":"cfga067b","name":"rule1","apps":[1001,2002],"exceptions":["[tcp;;;www.google.com;;]"]}]}
    @out-example: {"jsonrpc": "2.0", "id": 1, "result": {}}
--]]
M.set_rule = function()

    return {}
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
    @out array   ?rules.apps   规则集包含的应用的ID列表，为整数类型，应用和ID的对应关系通过get_app_list接口返回。
    @out array   ?rules.exceptions   规则集的例外列表，为字符串类型，该列表相对于apps参数例外，遵循应用特征描述语法，应用特征描述语法请参见doc.gl-inet.com
    @out array   ?groups 设备分组列表,如果分组列表不为空则返回。
    @out string   ?groups.id 分组ID，全局唯一，用于区分不同的设备组。
    @out string   ?groups.name 分组名字。
    @out string   ?groups.default_rule 分组使用的默认规则集ID，规则集ID需对应rules参数中返回的规则集ID。
    @out array   ?groups.macs 分组包含的设备MAC地址列表，为字符串类型。
    @out array   ?groups.schedules 分组包含的日程列表，如果对应分组存在日程设置则返回该参数。
    @out number   ?groups.schedules.week 日常在每周的第几天，允许范围为1-7，依次对应周一到周末。
    @out string   ?groups.schedules.begin 日程的开始时间，格式为hh:mm，起始时间必须在结束时间之前。
    @out string   ?groups.schedules.end 日程的结束时间，格式为hh:mm，结束时间必须在起始时间之后。
    @out string   ?groups.schedules.rule 该日程需要使用的规则集ID，规则集ID需对应rules参数中返回的规则集ID。


    @in-example: {"jsonrpc":"2.0","id":1,"method":"call","params":["","parental-control","get_config"]}
    @out-example: {"jsonrpc": "2.0", "id": 1, "result": {"enable":true,"drop_anonymous":false,"auto_update":false,"rules":[{"id":"cfga067b","name":"rule1","apps":[1001,2002],"exceptions":["[tcp;;;www.google.com;;]"]},{"id":"cfga067c","name":"rule2","apps":[3003,4004],"exceptions":["[tcp;;;www.google.com;;]"]}],"groups":[{"name":"group1","macs":["98:6B:46:F0:9B:A4","98:6B:46:F0:9B:A5"],"default_rule":"cfga067a","schedules":[{"week":1,"begin":"12:00","end":"13:00","rule":"cfga067c"},{"date":2,"begin":"14:00","end":"15:00","rule":"cfga067c"}]}]}}
--]]
M.get_config = function()

    return {"enable":true,"drop_anonymous":false,"auto_update":false,"rules":[{"id":"cfga067b","name":"rule1","apps":[1001,2002],"exceptions":["[tcp;;;www.google.com;;]"]},{"id":"cfga067c","name":"rule2","apps":[3003,4004],"exceptions":["[tcp;;;www.google.com;;]"]}],"groups":[{"name":"group1","macs":["98:6B:46:F0:9B:A4","98:6B:46:F0:9B:A5"],"default_rule":"cfga067a","schedules":[{"week":1,"begin":"12:00","end":"13:00","rule":"cfga067c"},{"date":2,"begin":"14:00","end":"15:00","rule":"cfga067c"}]}]}
end


--[[
    @method-type: call
    @method-name: update
    @method-desc: 更新特征库。
    

    @in-example: {"jsonrpc":"2.0","id":1,"method":"call","params":["","parental-control","update"]}
    @out-example: {"jsonrpc": "2.0", "id": 1, "result": {}}
--]]
M.update = function()
    return {}
end

return M
