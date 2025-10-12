local tcs = core:get_static_object("tcs");
local tcs_battle = core:get_static_object("tcs_battle");

function reselect_units()
    bm:clear_selection()
    -- local unit_cco = cco("CcoBattleSelection", 1):Call("FirstUnitContext")
    -- if not unit_cco then
    --     return
    -- end

    -- local scrunit = get_sunit_by_id(unit_cco:Call("UniqueUiId"))

    -- for _, ability in pairs(tcs_battle.unit_activations) do
    --     local ability_cco = get_ability_button_cco(ability)
    --     tcs:log("Unit can perform " .. ability .. ": " .. tostring(scrunit.unit:can_perform_special_ability(ability)))
    --     if ability_cco and scrunit.unit:can_perform_special_ability(ability) then
    --         ability_cco:SetVisible(true)
    --     end
    -- end
end

function zoom_to(unique_ui_id)
    local unit_cco = tcs_get_battleunit_cco(unique_ui_id)
    if unit_cco then
        unit_cco:Call("ZoomTo")
    end
end

function create_unit_status()
    local parent = core:get_ui_root()
    local info_panel = find_uicomponent(parent, "hud_battle", "info_panel_parent")

    local info_background = find_uicomponent(info_panel, "info_panel_background")

    local unit_status_component = core:get_or_create_component("unit_status", "ui/templates/tcs_unit_status.twui.xml",
        info_panel)

    if not info_background:VisibleFromRoot() then
        unit_status_component:Destroy()
        return
    end

    local unit_cco = find_uicomponent(parent, "hud_battle", "info_panel_parent", "info_panel_background"):GetContextObject("CcoUnitDetails")

    if not unit_cco then
        return
    end

    if not unit_cco:Call("BattleUnitContext.IsPlayerUnit") then
        unit_status_component:Destroy()
    end

    unit_status_component:SetDockingPoint(2)
    unit_status_component:SetDockOffset(0, -20)

    local unit_status = tcs_battle:get_unit_status(unit_cco:Call("BattleUnitContext.UniqueUiId"))
    local some_text = "Unit is currently "

    if unit_status then
        some_text = some_text .. unit_status.status

        if unit_status.time then
            some_text = some_text .. " for " .. string.format("%.1f", unit_status.time) .. " seconds"
        end
    else
        some_text = some_text .. "idle"
    end

    unit_status_component:SetCanResizeWidth(true)

    unit_status_component:SetStateText(some_text)

    return unit_status_component
end

function decrease_unit_status_time(unit_uid)
    local current_status = tcs_battle:get_unit_status(unit_uid)
    local new_time = current_status.time - 1

    if new_time <= 0 then
        return
    else
        tcs_battle:set_unit_status(unit_uid, current_status.status, new_time)
    end
end

function set_active_phase(phase)
    tcs_battle.current_phase = phase;
    local parent = core:get_ui_root()
    local bop_holder = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar")
    local phase_button_holder = find_uicomponent(bop_holder, "phase_control_panel", "control_buttons")

    local phase_button_component = find_uicomponent(phase_button_holder, phase)
    phase_button_component:SetState("selected")
    phase_button_component:SetInteractive(false)

    if not (phase == "button_fight_phase") then
        local next_phase_button_component = find_uicomponent(phase_button_holder,
            tcs_battle.phase_buttons[tcs_battle.phase_button_to_key[phase] + 1])
        next_phase_button_component:SetState("active")
        next_phase_button_component:SetInteractive((bm:local_alliance() == tcs_battle.active_player_alliance_index))
    end
end

function highlight_next_phase_button(seconds)
    local parent = core:get_ui_root()
    local next_phase_button_component = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar", "phase_control_panel",
        "next_phase_button")
    next_phase_button_component:Highlight(true)
    next_phase_button_component:StartPulseHighlight(10)
    bm:real_callback(
        function()
            stop_highlight_next_phase_button()
        end,
        seconds * 1000
    )
end

function stop_highlight_next_phase_button()
    local parent = core:get_ui_root()
    local next_phase_button_component = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar", "phase_control_panel",
        "next_phase_button")
    next_phase_button_component:StopPulseHighlight()
    next_phase_button_component:Highlight(false)
end

function enable_next_phase_button(bool)
    local parent = core:get_ui_root()
    local next_phase_button_component = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar", "phase_control_panel",
        "next_phase_button")

    next_phase_button_component:SetDisabled(not bool)

    if not bool then
        next_phase_button_component:SetState("inactive")
    else
        next_phase_button_component:SetState("active")
    end
end

function is_enabled_next_phase_button()
    local parent = core:get_ui_root()
    local next_phase_button_component = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar", "phase_control_panel",
        "next_phase_button")
    next_phase_button_component:IsDisabled()
    return not next_phase_button_component:IsDisabled()
end

function reset_phases()
    local parent = core:get_ui_root()
    local bop_holder = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar")

    local phase_control_panel = core:get_or_create_component("phase_control_panel",
        "ui/templates/tcs_phase_control_panel.twui.xml", bop_holder)
    local phase_button_holder = find_uicomponent(phase_control_panel, "control_buttons")

    for key, phase_button in pairs(tcs_battle.phase_buttons) do
        local phase_button_component = find_uicomponent(phase_button_holder, phase_button)
        phase_button_component:SetState("inactive")
        phase_button_component:SetInteractive(false)
    end
end

function setup_phase_controls()
    local parent = core:get_ui_root()
    local bop_holder = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar")

    local phase_control_panel = core:get_or_create_component("phase_control_panel",
        "ui/templates/tcs_phase_control_panel.twui.xml", bop_holder)

    reset_phases();
end

function remake_flag_path(flag_path)
    local flag_path_parts = lua_split(flag_path, "\\")
    return flag_path_parts[1] .. "/" .. flag_path_parts[2] .. "/" .. flag_path_parts[3] .. "/mon_64.png"
end

function set_active_crest()
    local parent = core:get_ui_root()
    local bop_holder = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar")

    local phase_control_panel = core:get_or_create_component("phase_control_panel",
        "ui/templates/tcs_phase_control_panel.twui.xml", bop_holder)

    local active_player_crest = find_uicomponent(phase_control_panel, "player_pane", "player_holder", "player_crest")
    local active_player_flag = remake_flag_path(active_player_alliance():armies():item(1):flag_path())
    active_player_crest:SetImagePath(active_player_flag)
end

function battleshock_tickdown(seconds)
    local parent = core:get_ui_root()
    local bop_holder = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar")

    local player_title = find_uicomponent(bop_holder, "phase_control_panel", "player_pane", "player_title")
    
    local title_text = "Battleshock: " .. seconds

    player_title:SetStateText(title_text)
    player_title:Resize(player_title:WidthOfTextLine(title_text) + 10, player_title:Height(), true)

    if seconds == 0 then
        return
    end
    bm:callback(
        function()
            battleshock_tickdown(seconds - 1)
        end,
        1000
    )
end

function show_ai_controls(bool)
    local parent = core:get_ui_root()
    local army_ability_parent = find_uicomponent(parent, "hud_battle", "army_ability_container", "army_ability_parent")

    for _, army_ability in pairs(tcs_battle.army_ai_controls) do
        local army_ability_component = find_uicomponent(army_ability_parent, "button_holder_" .. army_ability)
        if army_ability_component then
            army_ability_component:SetVisible(bool)
        end
    end
end

function flash_title_message(message)
    bm:remove_callback("tcs_flash_message")
    local parent = core:get_ui_root()
    local bop_holder = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar")

    local player_title = find_uicomponent(bop_holder, "phase_control_panel", "player_pane", "player_title")

    local title_text = player_title:GetStateText()

    player_title:SetStateText(message)
    player_title:Resize(player_title:WidthOfTextLine(message) + 10, player_title:Height(), true)

    bm:callback(
        function()
            player_title:SetStateText(title_text)
            player_title:Resize(player_title:WidthOfTextLine(title_text) + 10, player_title:Height(), true)
        end,
        3000,
        "tcs_flash_message"
    )
end

function set_title_message(message)
    bm:remove_callback("tcs_flash_message")
    local parent = core:get_ui_root()
    local bop_holder = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar")

    local player_title = find_uicomponent(bop_holder, "phase_control_panel", "player_pane", "player_title")

    player_title:SetStateText(message)
    player_title:Resize(player_title:WidthOfTextLine(message) + 10, player_title:Height(), true)
end

function get_ability_button_cco(ability_key)
    local root = core:get_ui_root()
    local unit_ability_holder = find_uicomponent(root, "hud_battle", "porthole_parent", "ability_parent")
    for i = 1, unit_ability_holder:ChildCount() do
        local ability = nil
        if i == 1 then
            ability = find_uicomponent(unit_ability_holder, "button_slot" .. i, "button_ability")
        else
            ability = find_uicomponent(unit_ability_holder, "button_slot" .. i, "button_ability" .. i)
        end
        if ability and ability:GetContextObject("CcoUnitAbilityDetails") and ability:GetContextObject("CcoUnitAbilityDetails"):Call("Key") == ability_key then
            return find_uicomponent(unit_ability_holder, "button_slot" .. i)
        end
    end
    return nil
end
