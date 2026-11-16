-- Read the config with inert API objects; never register binds or execute callbacks.
local function quote(s) return string.format('%q', s) end
local function lua(v)
    if type(v) == 'string' then return quote(v) end
    if type(v) ~= 'table' then return tostring(v) end
    local parts = {}
    for k,x in pairs(v) do parts[#parts+1] = '[' .. lua(k) .. ']=' .. lua(x) end
    return '{' .. table.concat(parts, ',') .. '}'
end
local function json(v)
    if type(v) == 'string' then
        return '"' .. v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\t','\\t') .. '"'
    end
    if type(v) ~= 'table' then return tostring(v) end
    local parts = {}
    for k,x in pairs(v) do parts[#parts+1] = json(tostring(k)) .. ':' .. json(x) end
    return '{' .. table.concat(parts, ',') .. '}'
end
local function dispatcher(path)
    return setmetatable({}, {
        __index = function(_, key) return dispatcher(path .. '.' .. key) end,
        __call = function(_, ...)
            local args, parts = {...}, {}
            for i,v in ipairs(args) do parts[i] = lua(v) end
            return {expression=path .. '(' .. table.concat(parts, ',') .. ')',
                command=path == 'hl.dsp.exec_cmd' and args[1] or '',
                workspace=path == 'hl.dsp.focus' and type(args[1]) == 'table' and args[1].workspace or '',
                label=path:gsub('hl.dsp.', ''):gsub('[_.]', ' ') .. ' ' .. table.concat(parts, ',')}
        end
    })
end
hl = setmetatable({_dynamite_catalogue=true, dsp=dispatcher('hl.dsp')}, {__index=function() return function() end end})
function hl.bind(keys, action, options)
    if type(action) ~= 'table' then return end
    action.keys = keys
    action.description = options and (options.description or options.desc) or ''
    print(json(action))
end
package.path = (arg[1]:match("^(.*)/") or ".") .. "/?.lua;" .. package.path
dofile(arg[1])
