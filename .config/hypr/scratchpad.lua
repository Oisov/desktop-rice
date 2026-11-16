-- Named scratchpads on special workspaces, plus focus-or-launch.
-- Special workspaces open on the focused monitor, so a pad follows you
-- between screens. Matching is a case-insensitive substring of the window
-- class, used both here and (as RE2 "(?i)...") in the placement rule.
local M = {}
local pads = {}

local function find(match)
    local found = {}
    for _, w in ipairs(hl.get_windows()) do
        if (w.class or ""):lower():find(match, 1, true) then
            found[#found + 1] = w
        end
    end
    -- Stable creation order keeps app keys on the first window, not the last used.
    table.sort(found, function(a, b) return a.stable_id < b.stable_id end)
    return found
end

-- spec = { match = "mattermost", cmd = "...", float = false }
function M.define(name, spec)
    pads[name] = spec
    local rule = {
        name = "scratchpad-" .. name,
        match = { class = "(?i)" .. spec.match },
        workspace = "special:" .. name .. " silent",
    }
    if spec.float then
        rule.float = true
        rule.size = "monitor_w*0.6 monitor_h*0.7"
        rule.center = true
    end
    hl.window_rule(rule)
end

local function shown(ws)
    for _, m in ipairs(hl.get_monitors()) do
        local s = hl.get_active_special_workspace(m)
        if s and s.name == ws then return true end
    end
    return false
end

-- Launch if missing, stash strays back into the pad, then show/hide it on
-- the focused monitor.
function M.toggle(name)
    local pad, ws = pads[name], "special:" .. name
    local wins = find(pad.match)
    if #wins == 0 then
        hl.dispatch(hl.dsp.exec_cmd(pad.cmd))
        if not shown(ws) then hl.dispatch(hl.dsp.workspace.toggle_special(name)) end
        return
    end
    for _, w in ipairs(wins) do
        if not (w.workspace and w.workspace.name == ws) then
            hl.dispatch(hl.dsp.window.move({ workspace = ws, follow = false, window = "address:" .. w.address }))
        end
    end
    hl.dispatch(hl.dsp.workspace.toggle_special(name))
end

-- Realforce/Ctrl+Alt app keys: pads toggle, normal apps get focused
-- (switching workspace/monitor as needed) or launched.
function M.focus_or_launch(match, cmd, primary_class)
    for name, pad in pairs(pads) do
        if pad.match == match then return M.toggle(name) end
    end
    local wins = find(match)
    local w = wins[1]
    if primary_class then
        for _, candidate in ipairs(wins) do
            if candidate.class == primary_class then
                w = candidate
                break
            end
        end
    end
    if w then
        hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address }))
    else
        hl.dispatch(hl.dsp.exec_cmd(cmd))
    end
end

return M
