local tcs = core:get_static_object("tcs");
local tcs_battle = core:get_static_object("tcs_battle");


core:add_listener(
    "tcs_next_phase_button",
    "ComponentLClickUp",
    function(context)
        return context.string == "next_phase_button"
    end,
    function(context)
        perform_next_phase()
        return true
    end,
    true
)

core:add_listener(
    "tcs_button_move_phase",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_move_phase"
    end,
    function(context)
        perform_next_phase()
        return true
    end,
    true
)

core:add_listener(
    "tcs_button_shoot_phase",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_shoot_phase"
    end,
    function(context)
        perform_next_phase()
        return true
    end,
    true
)

core:add_listener(
    "tcs_button_charge_phase",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_charge_phase"
    end,
    function(context)
        perform_next_phase()
        return true
    end,
    true
)

core:add_listener(
    "tcs_button_fight_phase",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_fight_phase"
    end,
    function(context)
        perform_next_phase()
        return true
    end,
    true
)

core:add_listener(
    "tcs_Next_Phase",
    "tcs_next_phase",
    true,
    function(context)
        if tcs_battle.current_phase == "button_fight_phase" then
            tcs_battle.active_player_alliance_index = get_next_alliance_index()
        end

        core:trigger_custom_event(tcs_battle.phase_transition_map[tcs_battle.current_phase], {})
    end,
    true
)

core:add_listener(
    "tcs_Hero_Phase",
    "button_hero_phase",
    true,
    function(context)
        tcs:log("Hero Phase started: ")

        reset_phases()
        set_active_phase("button_hero_phase")
        set_active_crest()
        mapf_to_all_units(disable_unit_activations)
        reselect_units()

        if not (active_player_alliance():armies():item(1):is_player_controlled()) then
            mapf_to_ai_units(enable_non_passives, tcs:get_config("ai_hero_time") * 1000)
            bm:callback(
                function()
                    core:trigger_custom_event("tcs_next_phase", {})
                end,
                tcs:get_config("ai_hero_time") * 1000,
                "tcs_ai_hero_phase"
            )
        end
    end,
    true
)

core:add_listener(
    "tcs_Move_Phase",
    "button_move_phase",
    true,
    function(context)
        tcs:log("Move Phase started: ")

        set_active_phase("button_move_phase")


        if not (active_player_alliance():armies():item(1):is_player_controlled()) then
            mapf_to_ai_units(ai_unit_move, tcs:get_config("ai_move_time") * 1000);

            local scrunits = bm:get_scriptunits_for_main_enemy_army_to_local_player()

            local callback_name = "stopmove_phase_ai";

            bm:remove_callback(callback_name);

            bm:repeat_callback(
                function()
                    if next(tcs_battle.ai_actively_moving) == nil then
                        bm:remove_callback(callback_name);
                        core:trigger_custom_event("tcs_next_phase", {});
                    else
                        tcs:log("AI units still moving.")
                    end
                end,
                2000,
                callback_name
            )
        else
            mapf_to_all_units(disable_unit_activations)
            mapf_to_active_player_units(enable_unit_move)
            mapf_to_active_player_units(enable_unit_retreat)
            reselect_units()
        end
    end,
    true
)

core:add_listener(
    "tcs_Shooting_Phase",
    "button_shoot_phase",
    true,
    function(context)
        tcs:log("Shooting Phase started: ")

        set_active_phase("button_shoot_phase")

        if not (active_player_alliance():armies():item(1):is_player_controlled()) then
            mapf_to_ai_units(ai_unit_shoot, tcs:get_config("ai_shoot_time") * 1000);

            local callback_name = "stopshoot_phase"

            bm:remove_callback(callback_name);

            bm:repeat_callback(
                function()
                    if next(tcs_battle.ai_actively_shooting) == nil then
                        bm:remove_callback(callback_name)
                        core:trigger_custom_event("tcs_next_phase", {})
                    else
                        tcs:log("AI units still shooting.")
                    end
                end,
                2000,
                callback_name
            )
        else
            mapf_to_all_units(disable_unit_activations)
            mapf_to_active_player_units(enable_unit_shoot)
            reselect_units()
        end
    end,
    true
)

core:add_listener(
    "tcs_Charge_Phase",
    "button_charge_phase",
    true,
    function(context)
        tcs:log("Charge Phase started: ")

        set_active_phase("button_charge_phase")

        if not (active_player_alliance():armies():item(1):is_player_controlled()) then
            mapf_to_ai_units(ai_unit_charge)

            local callback_name = "stopcharge_phase_ai";

            bm:remove_callback(callback_name);

            bm:repeat_callback(
                function()
                    if next(tcs_battle.ai_actively_charging) == nil then
                        bm:remove_callback(callback_name);
                        core:trigger_custom_event("tcs_next_phase", {});
                    else
                        tcs:log("AI units still charging.")
                    end
                end,
                2000,
                callback_name
            )
        else
            mapf_to_all_units(disable_unit_activations)
            mapf_to_active_player_units(enable_unit_charge)
            reselect_units()
        end
    end,
    true
)

core:add_listener(
    "tcs_Fight_Phase",
    "button_fight_phase",
    true,
    function(context)
        tcs:log("Combat Phase started: ")

        set_active_phase("button_fight_phase")

        if not (active_player_alliance():armies():item(1):is_player_controlled()) then
            mapf_to_ai_units(ai_unit_fight, tcs:get_config("ai_fight_time") * 1000);
            mapf_to_local_player_units(enable_unit_fight)

            local callback_name = "stopcombat_phase_ai";

            bm:remove_callback(callback_name);

            function stopcombat_phase()
                if next(tcs_battle.ai_actively_fighting) == nil then
                    bm:remove_callback(callback_name);
                    enable_next_phase_button(true)
                else
                    tcs:log("AI units still fighting.")
                end
            end

            bm:repeat_callback(stopcombat_phase, 2000, callback_name)
        else
            mapf_to_all_units(disable_unit_activations)
            mapf_to_all_units(enable_unit_fight)
            mapf_to_ai_units(ai_unit_fight, tcs:get_config("ai_fight_time") * 1000)
            reselect_units()
        end
    end,
    true
)

core:add_listener(
    "tcs_target_tracker",
    "ComponentLClickUp",
    function(context)
        return context.string == "root"
    end,
    function()
        local battle_root = cco("CcoBattleRoot", 1);
        if not battle_root:Call("CursorContextContext.UnitContext") then
            return
        end
        if battle_root:Call("CursorContextContext.UnitContext.IsPlayerUnit") then
            return
        end

        local enemy_sunits = bm:get_scriptunits_for_main_enemy_army_to_local_player()
        tcs_battle.last_targeted_enemy_sunit = enemy_sunits:get_sunit_by_name(tostring(battle_root:Call(
            "CursorContextContext.UnitContext.UniqueUiId")));

        tcs:log("New last target: " .. tcs_battle.last_targeted_enemy_sunit.unit:unique_ui_id())
    end,
    true
)
