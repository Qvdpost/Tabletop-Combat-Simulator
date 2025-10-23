local tcs = core:get_static_object("tcs");
local tcs_battle = core:get_static_object("tcs_battle");


core:add_listener(
    tcs_battle:get_listener_name("button_next_phase"),
    "ComponentLClickUp",
    function(context)
        return context.string == "next_phase_button"
    end,
    function(context)
        local active_unit, status = any_unit_still_active()
        if active_unit then
            flash_title_message("A unit is still " .. status)
            zoom_to(active_unit)
            return
        end
        stop_highlight_next_phase_button()
        perform_next_phase()
        return true
    end,
    true
)

core:add_listener(
    tcs_battle:get_listener_name("button_move"),
    "ComponentLClickUp",
    function(context)
        return context.string == "button_move_phase"
    end,
    function(context)
        local active_unit, status = any_unit_still_active()
        if active_unit then
            flash_title_message("A unit is still " .. status)
            zoom_to(active_unit)
            UIComponent(context.component):SetState("active")
            return
        end
        perform_next_phase()
        return true
    end,
    true
)

core:add_listener(
    tcs_battle:get_listener_name("button_shoot"),
    "ComponentLClickUp",
    function(context)
        return context.string == "button_shoot_phase"
    end,
    function(context)
        local active_unit, status = any_unit_still_active()
        if active_unit then
            flash_title_message("A unit is still " .. status)
            zoom_to(active_unit)
            UIComponent(context.component):SetState("active")
            return
        end
        perform_next_phase()
        return true
    end,
    true
)

core:add_listener(
    tcs_battle:get_listener_name("button_charge"),
    "ComponentLClickUp",
    function(context)
        return context.string == "button_charge_phase"
    end,
    function(context)
        local active_unit, status = any_unit_still_active()
        if active_unit then
            flash_title_message("A unit is still " .. status)
            zoom_to(active_unit)
            UIComponent(context.component):SetState("active")
            return
        end
        perform_next_phase()
        return true
    end,
    true
)

core:add_listener(
    tcs_battle:get_listener_name("button_fight"),
    "ComponentLClickUp",
    function(context)
        return context.string == "button_fight_phase"
    end,
    function(context)
        local active_unit, status = any_unit_still_active()
        if active_unit then
            flash_title_message("A unit is still " .. status)
            zoom_to(active_unit)
            UIComponent(context.component):SetState("active")
            return
        end
        perform_next_phase()
        return true
    end,
    true
)

core:add_listener(
    tcs_battle:get_listener_name("next_phase"),
    "tcs_next_phase",
    true,
    function(context)
        if not bm:is_multiplayer() then
            if tcs_battle.current_phase == "button_fight_phase" then
                tcs_battle.active_player_alliance_index = get_next_alliance_index()
            end

            core:trigger_custom_event(tcs_battle.phase_transition_map[tcs_battle.current_phase], {})
            return
        end

        if tcs_battle.current_phase == "button_fight_phase" or tcs:get_config("simultaneous_turns") then
            if not tcs_battle.priority_passed then
                tcs_battle.priority_passed = true
                if tcs_battle.active_player_alliance_index == bm:local_alliance() then
                    set_title_message("Priority Passed")
                    enable_next_phase_button(false)
                else
                    set_title_message("Priority Received")
                    enable_next_phase_button(true)
                    highlight_next_phase_button(3)
                end
            else
                tcs_battle.priority_passed = false
                if tcs_battle.current_phase == "button_fight_phase" then
                    tcs_battle.active_player_alliance_index = get_next_alliance_index()
                end

                enable_next_phase_button(tcs_battle.active_player_alliance_index == bm:local_alliance())
                core:trigger_custom_event(tcs_battle.phase_transition_map[tcs_battle.current_phase], {})
            end
            return
        end

        core:trigger_custom_event(tcs_battle.phase_transition_map[tcs_battle.current_phase], {})
    end,
    true
)

core:add_listener(
    tcs_battle:get_listener_name("hero_phase"),
    "button_hero_phase",
    true,
    function(context)
        tcs:log("Hero Phase started: ");

        enable_next_phase_button(false)
        mapf_to_all_units(disable_unit_activations)

        reselect_units()

        tcs_battle:clear_all_unit_statuses()

        tcs_battle.unit_ran = {};
        tcs_battle.unit_retreated = {};

        if tcs:get_config("simultaneous_turns") then
            mapf_to_all_units(enable_morale)
        else
            mapf_to_active_player_units(enable_morale)
        end

        local morale_delay = 5000
        battleshock_tickdown(morale_delay / 1000)

        bm:callback(
            function()
                if tcs:get_config("simultaneous_turns") then
                    mapf_to_all_units(unit_break, tcs:get_config("unit_break_duration") * 1000)
                else
                    mapf_to_active_player_units(unit_break, tcs:get_config("unit_break_duration") * 1000)
                end
                bm:callback(
                    function()
                        set_active_crest()

                        set_title_message("Hero Phase")

                        if tcs:get_config("simultaneous_turns") then
                            mapf_to_all_armies(null_wom)
                            mapf_to_all_units(disable_spell_effects)
                            mapf_to_all_armies(add_wom, tcs:get_config("wom_per_turn"))
                        else
                            mapf_to_active_player_armies(null_wom)
                            mapf_to_active_player_units(disable_spell_effects)
                            mapf_to_active_player_armies(add_wom, tcs:get_config("wom_per_turn"))
                        end

                        local battleshock_delay = 500
                        if next(tcs_battle.unit_retreated) then
                            battleshock_delay = tcs:get_config("unit_break_duration") * 1000
                        end
                        bm:callback(
                            function()
                                reset_phases()
                                set_active_phase("button_hero_phase")
                                enable_next_phase_button((bm:local_alliance() == tcs_battle.active_player_alliance_index))
                            end,
                            battleshock_delay,
                            "tcs_ai_hero_phase"
                        )

                        if not (active_player_alliance():armies():item(1):is_player_controlled()) or (tcs:get_config("simultaneous_turns") and not bm:is_multiplayer()) then
                            local ai_hero_time = tcs:get_config("ai_hero_time") * 1000
                            mapf_to_ai_armies(add_wom, tcs_battle.ai_wom_reserve)

                            bm:callback(
                                function()
                                    -- NOTE: Give AI wom or not during their full turn?
                                    set_reserve_ai_wom()
                                    mapf_to_ai_armies(null_wom)

                                    if tcs:get_config("simultaneous_turns") then
                                        highlight_next_phase_button(3)
                                        enable_next_phase_button(true)
                                    else
                                        core:trigger_custom_event("tcs_next_phase", {});
                                    end
                                end,
                                math.max(battleshock_delay, ai_hero_time),
                                "tcs_ai_hero_phase"
                            )
                        end
                    end,
                    500
                )
            end,
            morale_delay
        )
    end,
    true
)

core:add_listener(
    tcs_battle:get_listener_name("move_phase"),
    "button_move_phase",
    true,
    function(context)
        tcs:log("Move Phase started: ");

        set_active_phase("button_move_phase")

        set_title_message("Move Phase")

        enable_next_phase_button((bm:local_alliance() == tcs_battle.active_player_alliance_index))

        tcs_battle:clear_all_unit_statuses()

        tcs_battle.unit_movement_warned = {}

        mapf_to_all_units(set_unit_movement)

        mapf_to_all_units(disable_unit_activations)

        if not (active_player_alliance():armies():item(1):is_player_controlled()) then
            mapf_to_ai_units(ai_unit_move, tcs:get_config("ai_move_time") * 1000);

            if tcs:get_config("simultaneous_turns") then
                mapf_to_all_units(enable_unit_move)
                mapf_to_all_units(enable_unit_run)
                mapf_to_all_units(enable_unit_retreat)
                mapf_to_all_units(enable_unit_reform)

                mapf_to_local_player_rampaging_units(ai_unit_move, tcs:get_config("ai_move_time") * 1000);
            end

            local callback_name = "stopmove_phase_ai";

            bm:remove_callback(callback_name);

            bm:repeat_callback(
                function()
                    if not next(tcs_battle.ai_actively_moving) then
                        bm:remove_callback(callback_name);
                        if tcs:get_config("simultaneous_turns") then
                            enable_next_phase_button(true)
                            highlight_next_phase_button(3)
                        else
                            core:trigger_custom_event("tcs_next_phase", {});
                        end
                    else
                        tcs:log("AI units still moving.");
                    end
                end,
                2000,
                callback_name
            )
        else
            if tcs:get_config("simultaneous_turns") then
                mapf_to_all_units(enable_unit_move)
                mapf_to_all_units(enable_unit_run)
                mapf_to_all_units(enable_unit_retreat)
                mapf_to_all_units(enable_unit_reform)

                mapf_to_all_rampaging_units(ai_unit_move, tcs:get_config("ai_move_time") * 1000);

                mapf_to_ai_units(ai_unit_move, tcs:get_config("ai_move_time") * 1000);
            else
                mapf_to_active_player_units(enable_unit_move)
                mapf_to_active_player_units(enable_unit_run)
                mapf_to_active_player_units(enable_unit_retreat)
                mapf_to_active_player_units(enable_unit_reform)

                mapf_to_active_player_rampaging_units(ai_unit_move, tcs:get_config("ai_move_time") * 1000);
            end
            reselect_units()
        end
    end,
    true
)

core:add_listener(
    tcs_battle:get_listener_name("shoot_phase"),
    "button_shoot_phase",
    true,
    function(context)
        tcs:log("Shooting Phase started: ");

        set_active_phase("button_shoot_phase")

        set_title_message("Shoot Phase")

        enable_next_phase_button((bm:local_alliance() == tcs_battle.active_player_alliance_index))

        tcs_battle:clear_all_unit_statuses()

        mapf_to_all_units(disable_unit_activations)

        if not (active_player_alliance():armies():item(1):is_player_controlled()) then
            mapf_to_ai_units(ai_unit_shoot, tcs:get_config("ai_shoot_time") * 1000);

            if tcs:get_config("simultaneous_turns") then
                mapf_to_all_units(enable_unit_shoot)

                mapf_to_local_player_rampaging_units(ai_unit_shoot, tcs:get_config("ai_shoot_time") * 1000);
            end

            local callback_name = "stopshoot_phase"

            bm:remove_callback(callback_name);

            bm:repeat_callback(
                function()
                    if next(tcs_battle.ai_actively_shooting) == nil then
                        bm:remove_callback(callback_name)
                        if tcs:get_config("simultaneous_turns") then
                            enable_next_phase_button(true)
                            highlight_next_phase_button(3)
                        else
                            core:trigger_custom_event("tcs_next_phase", {});
                        end
                    else
                        tcs:log("AI units still shooting.");
                    end
                end,
                2000,
                callback_name
            )
        else
            if tcs:get_config("simultaneous_turns") then
                mapf_to_all_units(enable_unit_shoot)
                mapf_to_all_rampaging_units(ai_unit_shoot, tcs:get_config("ai_shoot_time") * 1000);
                mapf_to_ai_units(ai_unit_shoot, tcs:get_config("ai_shoot_time") * 1000);
            else
                mapf_to_active_player_units(enable_unit_shoot)

                mapf_to_active_player_rampaging_units(ai_unit_shoot, tcs:get_config("ai_shoot_time") * 1000);
            end

            reselect_units()
        end
    end,
    true
)

core:add_listener(
    tcs_battle:get_listener_name("charge_phase"),
    "button_charge_phase",
    true,
    function(context)
        tcs:log("Charge Phase started: ");

        set_active_phase("button_charge_phase")

        set_title_message("Charge Phase")

        enable_next_phase_button((bm:local_alliance() == tcs_battle.active_player_alliance_index))

        tcs_battle:clear_all_unit_statuses()

        mapf_to_all_units(disable_unit_activations)

        if not (active_player_alliance():armies():item(1):is_player_controlled()) then
            mapf_to_ai_units(ai_unit_charge)

            if tcs:get_config("simultaneous_turns") then
                mapf_to_all_units(enable_unit_charge)

                mapf_to_local_player_rampaging_units(ai_unit_charge)
            end

            local callback_name = "stopcharge_phase_ai";

            bm:remove_callback(callback_name);

            bm:repeat_callback(
                function()
                    if next(tcs_battle.ai_actively_charging) == nil then
                        bm:remove_callback(callback_name);
                        if tcs:get_config("simultaneous_turns") then
                            enable_next_phase_button(true)
                            highlight_next_phase_button(3)
                        else
                            core:trigger_custom_event("tcs_next_phase", {});
                        end
                    else
                        tcs:log("AI units still charging.");
                    end
                end,
                2000,
                callback_name
            )
        else
            if tcs:get_config("simultaneous_turns") then
                mapf_to_all_units(enable_unit_charge)
                mapf_to_all_rampaging_units(ai_unit_charge)
                mapf_to_ai_units(ai_unit_charge)
            else
                mapf_to_active_player_units(enable_unit_charge)
                mapf_to_all_rampaging_units(ai_unit_charge);
            end
            reselect_units()
        end
    end,
    true
)

core:add_listener(
    tcs_battle:get_listener_name("fight_phase"),
    "button_fight_phase",
    true,
    function(context)
        tcs:log("Combat Phase started: ");

        set_active_phase("button_fight_phase")

        set_title_message("Fight Phase")

        enable_next_phase_button((bm:local_alliance() == tcs_battle.active_player_alliance_index))

        tcs_battle:clear_all_unit_statuses()

        mapf_to_all_units(disable_unit_activations)

        if not (active_player_alliance():armies():item(1):is_player_controlled()) then
            mapf_to_ai_units(ai_unit_fight, tcs:get_config("ai_fight_time") * 1000);
            mapf_to_local_player_units(enable_unit_fight)
            mapf_to_local_player_rampaging_units(ai_unit_fight, tcs:get_config("ai_fight_time") * 1000);

            local callback_name = "stopcombat_phase_ai";

            bm:remove_callback(callback_name);

            function stopcombat_phase()
                if next(tcs_battle.ai_actively_fighting) == nil then
                    bm:remove_callback(callback_name);
                    enable_next_phase_button(true)
                    highlight_next_phase_button(3)
                else
                    tcs:log("AI units still fighting.");
                end
            end

            bm:repeat_callback(stopcombat_phase, 2000, callback_name)
        else
            mapf_to_all_units(enable_unit_fight)
            mapf_to_all_rampaging_units(ai_unit_fight, tcs:get_config("ai_fight_time") * 1000);
            mapf_to_ai_units(ai_unit_fight, tcs:get_config("ai_fight_time") * 1000)
            reselect_units()
        end
    end,
    true
)

core:add_listener(
    tcs_battle:get_listener_name("target_tracker"),
    "ComponentLClickUp",
    function(context)
        return context.string == "root"
    end,
    function()
        local battle_root = cco("CcoBattleRoot", 1);
        local unit_context = battle_root:Call("CursorContextContext.UnitContext")
        if not unit_context then
            return
        end
        if unit_context:Call("IsPlayerUnit") then
            return
        end

        local enemy_sunits = get_enemy_scrunits_to_local_player()
        local enemy_sunit = enemy_sunits:get_sunit_by_name(tostring(unit_context:Call("UniqueUiId")));
        if not enemy_sunit then
            local enemy_unit = get_unit_by_id(unit_context:Call("UniqueUiId"))
            if not enemy_unit then
                return
            end
            local scrunits = bm:get_scriptunits_for_army(enemy_unit:alliance_index(), enemy_unit:army_index())
            enemy_sunit = script_unit:new(enemy_unit)
            scrunits:add_sunits(enemy_sunit)
        end

        tcs_battle.last_targeted_enemy_sunit = enemy_sunit

        tcs:log("New last target: " .. tcs_battle.last_targeted_enemy_sunit.unit:unique_ui_id());
    end,
    true
)

core:add_listener(
    tcs_battle:get_listener_name("position_tracker"),
    "ComponentLClickUp",
    function(context)
        return context.string == "root"
    end,
    function()
        local cursor_vector = get_cursor_position()

        if not cursor_vector then
            return
        end

        tcs_battle.last_clicked_position = cursor_vector

        tcs:log(string.format("New last click location: (%.2f,%.2f,%.2f)", tcs_battle.last_clicked_position:get_x(),
            tcs_battle.last_clicked_position:get_y(), tcs_battle.last_clicked_position:get_z()))
    end,
    true
)

function summoned_unit_check()
    local unit_cards_component = find_uicomponent(core:get_ui_root(), "hud_battle", "battle_orders", "battle_orders_pane",
        "card_panel_docker", "cards_panel", "review_DY")

    local current_count = tcs_battle.unit_cards_count

    tcs_battle.unit_cards_count = unit_cards_component:ChildCount()
    if not current_count or current_count >= unit_cards_component:ChildCount() then
        return
    end
    for i = 0, unit_cards_component:ChildCount() - 1 do
        local uic_child = UIComponent(unit_cards_component:Find(i))

        local unit_uid = tonumber(uic_child:Id())
        local scrunit = get_sunit_by_id(unit_uid)

        if not scrunit then
            local unit = get_unit_by_id(unit_uid)
            if unit then
                local scrunits = bm:get_scriptunits_for_army(unit:alliance_index(), unit:army_index())
                local scrunit = script_unit:new(unit, tostring(unit:unique_ui_id()))
                scrunits:add_sunits(scrunit)

                setup_tcs_unit(unit)
            end
        end
    end
end

function enemy_summoned_unit_check()
    local current_count = 0

    for army_id = 1, bm:alliances():item(get_next_alliance_index(bm:local_alliance())):armies():count() do
        local battle_army = bm:alliances():item(get_next_alliance_index(bm:local_alliance())):armies():item(army_id)

        current_count = current_count + battle_army:units():count()
    end

    if current_count == tcs_battle.enemy_unit_count then
        return
    end

    for army_id = 1, bm:alliances():item(get_next_alliance_index(bm:local_alliance())):armies():count() do
        local battle_army = bm:alliances():item(get_next_alliance_index(bm:local_alliance())):armies():item(army_id)

        local scrunits = bm:get_scriptunits_for_army(get_next_alliance_index(bm:local_alliance()), army_id)
        for unit_id = 1, battle_army:units():count() do
            local unit = battle_army:units():item(unit_id);
            local script_unit = get_sunit_by_id(unit:unique_ui_id())
            if not script_unit then
                local scrunit = script_unit:new(unit, tostring(unit:unique_ui_id()))
                scrunits:add_sunits(scrunit)

                setup_tcs_unit(unit)
            end
        end
    end

    tcs_battle.enemy_unit_count = current_count
end
