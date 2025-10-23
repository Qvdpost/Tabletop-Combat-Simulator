local tcs = core:get_static_object("tcs");
local tcs_battle = core:get_static_object("tcs_battle");

function get_first_selected_unit(mode)
    if not mode then
        mode = "unit"
    end
    local unit_cco = cco("CcoBattleSelection", 1):Call("FirstUnitContext")
    if not unit_cco then
        return
    end

    if mode == "unit" then
        return get_unit_by_id(unit_cco:Call("UniqueUiId"))
    elseif mode == "sunit" then
        return get_sunit_by_id(unit_cco:Call("UniqueUiId"))
    elseif mode == "cco" then
        return unit_cco
    end

    tcs:log("Invalid mode requested.")
    return nil
end

function reselect_units()
    -- TODO: Find a way to reload the porthole ability parent.
    local unit = get_first_selected_unit()

    bm:clear_selection()

    if not unit then
        return
    end

    bm:callback(
        function()
            unit:select_in_ui()
        end,
        500
    )
end

function reselect_unit(unit)
    local selection_cco = cco("CcoBattleSelection", 1)

    if selection_cco:Call("AnyUnitSelectedIncludingEnemy") and not selection_cco:Call("IsOrderable") then
        bm:callback(
            function()
                bm:clear_selection()
                unit:select_in_ui()
            end,
            500
        )
    end
end

function zoom_to(unique_ui_id)
    local unit_cco = tcs_get_battleunit_cco(unique_ui_id)
    if unit_cco then
        unit_cco:Call("ZoomTo")
    end
end

function get_cursor_position()
    local battle_root = cco("CcoBattleRoot", 1)
    local cursor = battle_root:Call("CursorContextContext")

    if cursor:Call("HasIntersections") then
        local cursor_vector = battle_vector:new(
            cursor:Call("GroundIntersectPosition.x"),
            cursor:Call("GroundIntersectPosition.y"),
            cursor:Call("GroundIntersectPosition.z")
        )
        return cursor_vector
    end

    return nil
end

function get_or_create_unit_status()
    local parent = core:get_ui_root()
    local info_panel = find_uicomponent(parent, "hud_battle", "info_panel_parent")

    local info_background = find_uicomponent(info_panel, "info_panel_background")

    local unit_status_component = core:get_or_create_component("unit_status", "ui/templates/tcs_unit_status.twui.xml",
        info_panel)

    unit_status_component:SetVisible(info_background:VisibleFromRoot())

    if not info_background:VisibleFromRoot() then
        return unit_status_component
    end

    local unit_cco = find_uicomponent(parent, "hud_battle", "info_panel_parent", "info_panel_background")
        :GetContextObject("CcoUnitDetails")

    if not unit_cco then
        return unit_status_component
    end

    if not unit_cco:Call("BattleUnitContext.IsPlayerUnit") then
        unit_status_component:Destroy()
    end

    unit_status_component:SetDockingPoint(2)
    unit_status_component:SetDockOffset(0, -20)

    local scrunit = get_sunit_by_id(unit_cco:Call("BattleUnitContext.UniqueUiId"))

    if not scrunit then
        return unit_status_component
    end

    local unit_status = tcs_battle:get_unit_status(scrunit.unit:unique_ui_id())
    local some_text = "Unit is currently "

    if unit_status.status then
        some_text = some_text .. unit_status.status

        if unit_status.time then
            some_text = some_text .. " for " .. string.format("%.1f", unit_status.time) .. " seconds"
        end
    else
        some_text = some_text .. "idle."
        if tcs_battle.current_phase == "button_move_phase" then
            local cursor_vector = get_cursor_position()
            if cursor_vector then
                local unit_distance = get_unit_to_position_distance(scrunit.unit, cursor_vector)
                local movement_range = tcs_battle.unit_movement_range[scrunit.unit:unique_ui_id()]
                if unit_distance and movement_range then
                    if unit_distance <= movement_range then
                        some_text = some_text .. "\nCan move: "
                    else
                        some_text = some_text .. "\nCannot move: "
                    end

                    some_text = some_text .. string.format("%d/%d", unit_distance, movement_range)
                end
            end
        end
    end

    unit_status_component:SetCanResizeWidth(true)
    unit_status_component:SetCanResizeHeight(true)

    local text_width, text_height = unit_status_component:TextDimensionsForText(some_text)

    if type(text_height) == "number" and type(text_width) == "number" then
        unit_status_component:Resize(text_width + 10, text_height + 10)
        unit_status_component:SetDockOffset(0, -10 - text_height)
        unit_status_component:SetStateText(some_text)
    end

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
    local phase_control_panel = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar", "phase_control_panel")
    local phase_button_holder = find_uicomponent(phase_control_panel, "control_buttons")
    local next_phase_button_component = find_uicomponent(phase_control_panel, "next_phase_button")

    next_phase_button_component:SetDisabled(not bool)

    if not bool then
        next_phase_button_component:SetState("inactive")
    else
        next_phase_button_component:SetState("active")
    end

    if not tcs_battle.current_phase then
        return
    end

    if tcs_battle.current_phase ~= "button_fight_phase" then
        local next_square_phase_button_component = find_uicomponent(phase_button_holder,
            tcs_battle.phase_buttons[tcs_battle.phase_button_to_key[tcs_battle.current_phase] + 1])
        if not bool then
            next_square_phase_button_component:SetState("inactive")
            next_square_phase_button_component:SetInteractive(false)
        else
            next_square_phase_button_component:SetState("active")
            next_square_phase_button_component:SetInteractive(true)
        end
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

function remove_phase_controls()
    local parent = core:get_ui_root()
    local bop_holder = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar")

    local phase_control_panel = core:get_or_create_component("phase_control_panel",
        "ui/templates/tcs_phase_control_panel.twui.xml", bop_holder)

    phase_control_panel:Destroy()
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

function flash_unit_status(unit, message, duration)
    tcs_battle:set_unit_status(unit:unique_ui_id(), message)
    if duration then
        bm:callback(
            function()
                tcs_battle:clear_unit_status(unit:unique_ui_id())
            end,
            duration
        )
    end
end

function tickdown_unit_status(unit, message, duration, callback_name)
    tcs_battle:set_unit_status(unit:unique_ui_id(), message, duration)

    bm:repeat_callback(
        function()
            decrease_unit_status_time(unit:unique_ui_id())
        end,
        1000,
        callback_name
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

function animate_selection_proxy_on_cursor()
    local scrunit = get_first_selected_unit('sunit')

    if not scrunit then
        return
    end
    scrunit:cache_location()
    local scrunit_width = scrunit:get_cached_width();
    local scrunit_bearing = scrunit:get_cached_bearing();
    local combat_area_depth = 10;

    local centre_pos = v_offset_by_bearing(scrunit.unit:position(), d_to_r(scrunit_bearing), combat_area_depth / 2);
    local bounding_box = {
        pos = centre_pos,
        bearing = scrunit_bearing,
        width = scrunit_width,
        depth = combat_area_depth
    }
    local bounding_box_bearing_r = d_to_r(bounding_box.bearing);
    local bounding_box_half_width = bounding_box.width / 2;

    local bounding_box_left = v_offset_by_bearing(bounding_box.pos, bounding_box_bearing_r - math.pi / 2,
        bounding_box_half_width);
    local bounding_box_right = v_offset_by_bearing(bounding_box.pos, bounding_box_bearing_r + math.pi / 2,
        bounding_box_half_width);

    local distance_of_units_to_proxy = 60

    pos_proxy_centre = v_offset_by_bearing(bounding_box.pos, bounding_box_bearing_r, distance_of_units_to_proxy);
    pos_proxy_left = v_to_ground(
        v_offset_by_bearing(pos_proxy_centre, bounding_box_bearing_r - math.pi / 2, bounding_box_half_width), 10);
    pos_proxy_right = v_to_ground(
        v_offset_by_bearing(pos_proxy_centre, bounding_box_bearing_r + math.pi / 2, bounding_box_half_width), 10);

    local function show_movement_proxies()
        if not tcs_battle.proxy_id then
            -- tcs_battle.proxy_id = scrunit.uc:add_animated_selection_proxy(pos_proxy_left, pos_proxy_right, 1, 3, true);
            tcs_battle.proxy_id = scrunit.uc:add_animated_selection_proxy(pos_proxy_left, pos_proxy_right, 1);
        end;
    end;


    local function remove_movement_proxies()
        if tcs_battle.proxy_id then
            scrunit.uc:remove_animated_selection_proxy(tcs_battle.proxy_id);
            tcs_battle.proxy_id = nil;
        end;
    end;

    show_movement_proxies()

    bm:callback(remove_movement_proxies, 5000)
end

function highlight_tcs_interface(bool)
    local parent = core:get_ui_root()
    local bop_holder = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar")
    local phase_control_panel = find_uicomponent(bop_holder, "phase_control_panel")
    local unit_info_panel = find_uicomponent(parent, "hud_battle", "info_panel_parent")

    local general = bm:get_scriptunits_for_local_players_army():get_general_sunit()



    if bool then
        general.unit:select_in_ui()

        unit_info_panel:SetVisible(true)
        phase_control_panel:Highlight(true)
        phase_control_panel:StartPulseHighlight(10)

        local unit_status_component = get_or_create_unit_status()

        if unit_status_component then
            unit_status_component:Highlight(true, true)
        end
    else
        phase_control_panel:Highlight(false)
        phase_control_panel:StopPulseHighlight()

        local root = core:get_ui_root()
        local unit_info_button = find_uicomponent(root, "hud_battle", "porthole_parent", "button_toggle_infopanel")

        unit_info_panel:SetVisible(unit_info_button:CurrentState() == "selected")

        local unit_status_component = get_or_create_unit_status()
        if unit_status_component then
            unit_status_component:Highlight(false, true)
        end
    end
end

function add_help_pages()
    local parser = get_link_parser();

    hp_tcs_help = help_page:new(
        "script_link_battle_tcs",
        hpr_title("war.battle.hp.tcs_info.001"),
        hpr_leader("war.battle.hp.tcs_info.002"),
        hpr_normal("war.battle.hp.tcs_info.003")
    );
    parser:add_record("battle_tcs", "script_link_battle_tcs", "tooltip_battle_tcs");
    tp_tcs = tooltip_patcher:new("tooltip_battle_tcs");
    tp_tcs:set_layout_data("tooltip_title_and_text", "ui_text_replacements_localised_text_hp_battle_title_tcs",
        "ui_text_replacements_localised_text_hp_battle_description_tcs");

    hp_tcs_phases = help_page:new(
        "script_link_battle_tcs_phases",
        hpr_title("war.battle.hp.tcs_phases.001"),
        hpr_leader("war.battle.hp.tcs_phases.002"),
        hpr_normal("war.battle.hp.tcs_phases.003"),

        hpr_section("hero"),
        hpr_normal_unfaded("war.battle.hp.tcs_phases.004", "hero"),
        hpr_normal("war.battle.hp.tcs_phases.005", "hero"),
        hpr_normal("war.battle.hp.tcs_phases.006", "hero"),
        hpr_normal("war.battle.hp.tcs_phases.007", "hero"),
        hpr_normal("war.battle.hp.tcs_phases.008", "hero"),

        hpr_section("move"),
        hpr_normal_unfaded("war.battle.hp.tcs_phases.010", "move"),
        hpr_normal("war.battle.hp.tcs_phases.010", "move"),
        hpr_normal("war.battle.hp.tcs_phases.011", "move"),
        hpr_normal("war.battle.hp.tcs_phases.012", "move"),
        hpr_normal("war.battle.hp.tcs_phases.013", "move"),
        hpr_normal("war.battle.hp.tcs_phases.014", "move"),
        hpr_normal("war.battle.hp.tcs_phases.015", "move"),
        hpr_normal("war.battle.hp.tcs_phases.016", "move"),
        hpr_normal("war.battle.hp.tcs_phases.017", "move"),

        hpr_section("shoot"),
        hpr_normal_unfaded("war.battle.hp.tcs_phases.018", "shoot"),
        hpr_normal("war.battle.hp.tcs_phases.019", "shoot"),
        hpr_normal("war.battle.hp.tcs_phases.020", "shoot"),

        hpr_section("charge"),
        hpr_normal_unfaded("war.battle.hp.tcs_phases.021", "charge"),
        hpr_normal("war.battle.hp.tcs_phases.022", "charge"),
        hpr_normal("war.battle.hp.tcs_phases.023", "charge"),
        hpr_normal("war.battle.hp.tcs_phases.024", "charge"),


        hpr_section("fight"),
        hpr_normal_unfaded("war.battle.hp.tcs_phases.025", "fight"),
        hpr_normal("war.battle.hp.tcs_phases.026", "fight"),
        hpr_normal("war.battle.hp.tcs_phases.027", "fight"),
        hpr_normal("war.battle.hp.tcs_phases.028", "fight"),
        hpr_normal("war.battle.hp.tcs_phases.029", "fight"),

        hpr_normal("war.battle.hp.tcs_phases.030")
    );
    parser:add_record("battle_tcs_phases", "script_link_battle_tcs_phases", "tooltip_battle_tcs_phases");
    tp_tcs_phases = tooltip_patcher:new("tooltip_battle_tcs_phases");
    tp_tcs_phases:set_layout_data("tooltip_title_and_text",
        "ui_text_replacements_localised_text_hp_battle_title_tcs_phases",
        "ui_text_replacements_localised_text_hp_battle_description_tcs_phases");

    battle_tcs_activations = help_page:new(
        "script_link_battle_tcs_activations",
        hpr_title("war.battle.hp.tcs_activations.001"),
        hpr_leader("war.battle.hp.tcs_activations.002"),
        hpr_normal("war.battle.hp.tcs_activations.003")
    )
    parser:add_record("battle_tcs_activations", "script_link_battle_tcs_activations", "tooltip_battle_tcs_activations");
    tp_battle_tcs_activations = tooltip_patcher:new("tooltip_battle_tcs_activations");
    tp_battle_tcs_activations:set_layout_data("tooltip_title_and_text",
        "ui_text_replacements_localised_text_hp_battle_title_tcs_activations",
        "ui_text_replacements_localised_text_hp_battle_description_tcs_activations");

    batle_tcs_controls = help_page:new(
        "script_link_battle_tcs_controls",
        hpr_title("war.battle.hp.tcs_controls.001"),
        hpr_leader("war.battle.hp.tcs_controls.002"),
        hpr_normal("war.battle.hp.tcs_controls.003")
    )
    parser:add_record("battle_tcs_controls", "script_link_battle_tcs_controls", "tooltip_battle_tcs_controls");
    tp_battle_tcs_controls = tooltip_patcher:new("tooltip_battle_tcs_controls");
    tp_battle_tcs_controls:set_layout_data("tooltip_title_and_text",
        "ui_text_replacements_localised_text_hp_battle_title_tcs_controls",
        "ui_text_replacements_localised_text_hp_battle_description_tcs_controls");
    tl_battle_tcs_controls = tooltip_listener:new(
        "tooltip_battle_tcs_controls",
        function()
            highlight_tcs_interface(true);
        end,
        function()
            highlight_tcs_interface(false);
        end
    );


    batle_tcs_config = help_page:new(
        "script_link_battle_tcs_config",
        hpr_title("war.battle.hp.tcs_config.001"),
        hpr_leader("war.battle.hp.tcs_config.002"),
        hpr_normal("war.battle.hp.tcs_config.003")
    )
    parser:add_record("battle_tcs_config", "script_link_battle_tcs_config", "tooltip_battle_tcs_config");
    tp_battle_tcs_config = tooltip_patcher:new("tooltip_battle_tcs_config");
    tp_battle_tcs_config:set_layout_data("tooltip_title_and_text",
        "ui_text_replacements_localised_text_hp_battle_title_tcs_config",
        "ui_text_replacements_localised_text_hp_battle_description_tcs_config");

    batle_tcs_tips = help_page:new(
        "script_link_battle_tcs_tips",
        hpr_title("war.battle.hp.tcs_tips.001"),
        hpr_leader("war.battle.hp.tcs_tips.002"),
        hpr_normal("war.battle.hp.tcs_tips.003")
    )
    parser:add_record("battle_tcs_tips", "script_link_battle_tcs_tips", "tooltip_battle_tcs_tips");
    tp_battle_tcs_tips = tooltip_patcher:new("tooltip_battle_tcs_tips");
    tp_battle_tcs_tips:set_layout_data("tooltip_title_and_text",
        "ui_text_replacements_localised_text_hp_battle_title_tcs_tips",
        "ui_text_replacements_localised_text_hp_battle_description_tcs_tips");


    table.inject(hp_contents.content, 2,
        hpr_section("tcs"),
        hpr_title("war.battle.hp.tcs.001", "tcs"),
        hpr_image("war.battle.hp.tcs.002", "UI/help_images/advisor.png", "tcs"),
        hpr_normal("war.battle.hp.tcs.003", "tcs"),
        hpr_section_index("tcs", "battle_tcs_phases")
    )
end
