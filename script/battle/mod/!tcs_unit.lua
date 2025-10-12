local tcs = core:get_static_object("tcs");
local tcs_battle = core:get_static_object("tcs_battle");


function freeze_unit(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);

    bm:remove_callback(tcs_battle.unit_callback_names["stopmove"] .. unit:unique_ui_id());
    bm:remove_callback(tcs_battle.unit_callback_names["engage_check"] .. unit:unique_ui_id())
    bm:remove_callback(tcs_battle.unit_callback_names["engage_warn"] .. unit:unique_ui_id())

    unit:disable_special_ability("tcs_main_unit_passive_stationary", false)

    disable_melee_attacks(unit)

    stop_scrunit(scrunit)

    tcs_battle.unit_actively_moving[unit:unique_ui_id()] = nil
    tcs_battle:clear_unit_status(unit:unique_ui_id())
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can no longer move.", __FILE__(), __LINE__(), __FUNC__());
end;

function freeze_unit_in_engagement_range(scrunit, callback_name)
    if scrunit_is_engaged(scrunit, 5) then
        bm:remove_callback(callback_name)
        freeze_unit(scrunit.unit)
        tcs:log("Unit(" .. scrunit.unit:unique_ui_id() .. ") entered engagement range.", __FILE__(), __LINE__(),
            __FUNC__());
    end
end

function warn_about_engagement_range(scrunit, buffer, callback_name)
    if scrunit_is_engaged(scrunit, buffer) then
        bm:remove_callback(callback_name)
        scrunit.unit:highlight(true)
        local nearest_enemy_scrunit = nearest_enemy(scrunit, true)
        nearest_enemy_scrunit.unit:highlight(true)

        bm:callback(
            function()
                scrunit.unit:highlight(false)
                nearest_enemy_scrunit.unit:highlight(false)
            end,
            5000
        )

        scrunit.uc:change_move_speed(false)

        bm:slow_game_over_time(bm:current_battle_speed(), 0.5, 500, 5)
        bm:callback(
            function()
                bm:slow_game_over_time(bm:current_battle_speed(), 1, 1000, 10)
            end,
            3000
        )
        tcs_get_battleunit_cco(scrunit.unit:unique_ui_id()):Call("ZoomTo")
        tcs:log("Unit(" .. scrunit.unit:unique_ui_id() .. ") nearing engagement range.", __FILE__(), __LINE__(),
            __FUNC__());
    end
end

function unit_move(unit, time)
    -- MoveToDraggableUnit CcoBattleUnit?? Perhaps interesting?? Ability that let's you place unit in a location. Reduce their movement range in status tracking.
    if tcs_battle.unit_actively_moving[unit:unique_ui_id()] then
        return
    end
    local scrunit = bm:get_scriptunit_for_unit(unit);
    local callback_name = tcs_battle.unit_callback_names["stopmove"] .. unit:unique_ui_id()
    local engage_callback_name = tcs_battle.unit_callback_names["engage_check"] .. unit:unique_ui_id()

    bm:remove_callback(callback_name);
    bm:remove_callback(engage_callback_name)

    unit:disable_special_ability("tcs_main_unit_passive_stationary", true)
    tcs_battle.unit_actively_moving[unit:unique_ui_id()] = true

    unit:disable_special_ability("tcs_main_unit_active_run", true)

    tcs_battle:set_unit_status(unit:unique_ui_id(), "moving", time / 1000)
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can move.", __FILE__(), __LINE__(), __FUNC__());

    bm:repeat_callback(function() freeze_unit_in_engagement_range(scrunit, engage_callback_name) end, 500,
        engage_callback_name)

    if tcs:get_config("warn_about_engagement_range") then
        local engage_warning_callback_name = tcs_battle.unit_callback_names["engage_warn"] .. unit:unique_ui_id()
        bm:repeat_callback(
            function()
                warn_about_engagement_range(scrunit, tcs:get_config("warn_about_engagement_range_distance"),
                    engage_warning_callback_name)
            end,
            500,
            engage_warning_callback_name
        )
    end

    bm:callback(
        function()
            freeze_unit(unit)
        end,
        time,
        callback_name
    )

    bm:repeat_callback(function() decrease_unit_status_time(unit:unique_ui_id()) end, 1000, callback_name)
end

function unit_run(unit, time)
    if tcs_battle.unit_actively_moving[unit:unique_ui_id()] then
        return
    end
    local extra_time = ((roll_dice(tcs:get_config("default_run_dice"), tcs:get_config("default_dice_eyes")) / tcs:get_config("default_dice_eyes")) * time)
    time = time + extra_time

    unit_move(unit, time)

    unit:disable_special_ability("tcs_main_unit_active_move", true)

    tcs_battle.unit_ran[unit:unique_ui_id()] = true
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") running for " .. (extra_time / 1000) .. " extra seconds.", __FILE__(),
        __LINE__(), __FUNC__());
end

function stopfight_unit(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);

    bm:remove_callback(tcs_battle.unit_callback_names["stopfight"] .. unit:unique_ui_id());

    unit:disable_special_ability("tcs_main_unit_passive_inactive_fighting", false)
    disable_melee_attacks(unit)

    stop_scrunit(scrunit)

    tcs_battle.unit_actively_fighting[unit:unique_ui_id()] = nil
    tcs_battle:clear_unit_status(unit:unique_ui_id())
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can no longer fight.", __FILE__(), __LINE__(), __FUNC__());
end;

function unit_fight(unit, time)
    if tcs_battle.unit_actively_fighting[unit:unique_ui_id()] then
        return
    end
    enable_melee_attacks(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    scrunit:set_melee_mode(true, true)

    local attack_target = tcs_battle.last_targeted_enemy_sunit.unit

    local target_distance = unit:unit_distance(attack_target)
    tcs:log("Target distance: " .. target_distance, __FILE__(), __LINE__(), __FUNC__())


    if target_distance > tcs_battle.engagement_distance then
        tcs:log("Blocking attack; target is too far away", __FILE__(), __LINE__(), __FUNC__())
        enable_unit_fight(unit)
        stopfight_unit(unit)
        tcs_battle:set_unit_status(unit:unique_ui_id(),
            string.format("idle; combat target out of range (%d).", target_distance))
        return
    end

    unit:disable_special_ability("tcs_main_unit_passive_stationary", true)

    bm:callback(
        function()
            unit:disable_special_ability("tcs_main_unit_passive_stationary", false)
        end,
        tcs:get_config("pile_in_time") * 1000
    )

    local callback_name = tcs_battle.unit_callback_names["stopfight"] .. unit:unique_ui_id()

    bm:remove_callback(callback_name);

    unit:disable_special_ability("tcs_main_unit_passive_inactive_fighting", true)
    tcs_battle.unit_actively_fighting[unit:unique_ui_id()] = true
    tcs_battle:set_unit_status(unit:unique_ui_id(), "fighting", time / 1000)
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can fight.", __FILE__(), __LINE__(), __FUNC__());

    bm:callback(
        function()
            bm:remove_callback(callback_name)
            stopfight_unit(unit)
        end,
        time,
        callback_name
    )

    bm:repeat_callback(
        function()
            if not scrunit:is_in_melee() then
                tcs:log("Unit(" .. unit:unique_ui_id() .. ") not in melee; attacking again.", __FILE__(), __LINE__(),
                    __FUNC__());
                scrunit.uc:attack_unit(attack_target)
            end
        end,
        2000,
        callback_name
    )

    bm:repeat_callback(function() decrease_unit_status_time(unit:unique_ui_id()) end, 1000, callback_name)
end

function stopshoot_unit(unit)
    local battle_unit_cco = tcs_get_battleunit_cco(unit:unique_ui_id())

    bm:remove_callback(tcs_battle.unit_callback_names["stopshoot"] .. unit:unique_ui_id());

    local scrunit = bm:get_scriptunit_for_unit(unit);
    unit:disable_special_ability("tcs_main_unit_passive_inactive_shooting", false)

    stop_scrunit(scrunit)

    tcs_battle.unit_actively_shooting[unit:unique_ui_id()] = nil
    tcs_battle:clear_unit_status(unit:unique_ui_id())
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can no longer shoot.", __FILE__(), __LINE__(), __FUNC__());
end;

function unit_shoot(unit, time)
    if tcs_battle.unit_actively_shooting[unit:unique_ui_id()] then
        return
    end
    local callback_name = tcs_battle.unit_callback_names["stopshoot"] .. unit:unique_ui_id()
    bm:remove_callback(callback_name);

    unit:disable_special_ability("tcs_main_unit_passive_inactive_shooting", true)

    local scrunit = bm:get_scriptunit_for_unit(unit);
    scrunit:set_melee_mode(false, true)

    tcs_battle.unit_actively_shooting[unit:unique_ui_id()] = true
    tcs_battle:set_unit_status(unit:unique_ui_id(), "shooting", time / 1000)
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can shoot.", __FILE__(), __LINE__(), __FUNC__());

    bm:callback(
        function()
            stopshoot_unit(unit)
        end,
        time,
        callback_name
    )
    bm:repeat_callback(function() decrease_unit_status_time(unit:unique_ui_id()) end, 1000, callback_name)
end

function unit_end_charge(unit)
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") ending charge.", __FILE__(), __LINE__(), __FUNC__());
    local scrunit = bm:get_scriptunit_for_unit(unit);

    disable_melee_attacks(unit)

    stop_scrunit(scrunit)

    unit:disable_special_ability("tcs_main_unit_passive_stationary", false)
    unit:disable_special_ability("tcs_main_unit_passive_inactive_fighting", false)

    if tcs_battle.unit_should_land[unit:unique_ui_id()] then
        bm:repeat_callback(
            function()
                land_unit(unit)
            end,
            1000,
            tcs_battle.unit_callback_names["landunit"] .. unit:unique_ui_id()
        )
    end

    tcs_battle.unit_actively_charging[unit:unique_ui_id()] = nil
    tcs_battle:clear_unit_status(unit:unique_ui_id())
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") ended charging.", __FILE__(), __LINE__(), __FUNC__());
end

function stopcharge_unit(unit, charge_target, overcharge_time, callback_name)
    local scrunit = bm:get_scriptunit_for_unit(unit);

    if unit:is_in_melee() then
        tcs:log("Unit (" .. unit:unique_ui_id() .. ") in melee.", __FILE__(), __LINE__(), __FUNC__())
        tcs:log(
            string.format(
                "Unit (" .. unit:unique_ui_id() .. ") overcharging for %.2f seconds.", overcharge_time / 1000
            ), __FILE__(), __LINE__(), __FUNC__()
        )

        bm:remove_callback(callback_name)

        bm:callback(
            function()
                unit_end_charge(unit)
                stop_unit(charge_target)
            end,
            overcharge_time
        )
        return
    end

    scrunit.uc:attack_unit(charge_target, true, true)
    tcs:log("Unit (" .. unit:unique_ui_id() .. ") not yet in melee.", __FILE__(), __LINE__(), __FUNC__())
end

function unit_charge(unit)
    if tcs_battle.unit_actively_charging[unit:unique_ui_id()] then
        return
    end
    local scrunit = bm:get_scriptunit_for_unit(unit);
    stop_scrunit(scrunit)
    enable_melee_attacks(unit)
    scrunit:set_melee_mode(true, true)

    if not tcs_battle.last_targeted_enemy_sunit then
        tcs:log("Blocking charge; target is not an enemy", __FILE__(), __LINE__(), __FUNC__())
        enable_unit_charge(unit)
        unit_end_charge(unit)
        return
    end

    local charge_target = tcs_battle.last_targeted_enemy_sunit.unit

    local charge_distance = unit:unit_distance(charge_target)
    tcs:log("Charge distance: " .. charge_distance, __FILE__(), __LINE__(), __FUNC__())

    if charge_distance > tcs_battle.charge_range then
        tcs:log("Blocking charge; target is too far away", __FILE__(), __LINE__(), __FUNC__())
        enable_unit_charge(unit)
        unit_end_charge(unit)
        tcs_battle:set_unit_status(unit:unique_ui_id(),
            string.format("idle; charge target out of range (%d).", charge_distance))
        return
    end

    local diceroll = roll_dice(tcs:get_config("default_charge_dice"), tcs:get_config("default_dice_eyes"))
    local normalised_charge_distance = normalise_to_range(charge_distance, tcs_battle.charge_range)

    if not (diceroll >= normalised_charge_distance) then
        tcs:log("Blocking charge; the roll failed: " .. diceroll .. " / " .. normalised_charge_distance, __FILE__(),
            __LINE__(), __FUNC__())
        unit_end_charge(unit)
        tcs_battle:set_unit_status(unit:unique_ui_id(),
            string.format("idle; charge failed (%d/%.2f)", diceroll, normalised_charge_distance))
        return
    end

    local overcharge_time = ((diceroll - normalised_charge_distance) / (tcs:get_config("default_charge_dice") * tcs:get_config("default_dice_eyes"))) *
        tcs:get_config("move_time") * 1000;

    if unit:is_currently_flying() and not charge_target:is_currently_flying() and not unit:has_attribute("always_flying") then
        tcs_battle.unit_should_land[unit:unique_ui_id()] = true
    end

    local callback_name = tcs_battle.unit_callback_names["stopcharge"] .. unit:unique_ui_id()

    bm:remove_callback(callback_name);

    scrunit:play_sound_charge()
    scrunit:take_control()

    unit:disable_special_ability("tcs_main_unit_passive_stationary", true)
    unit:disable_special_ability("tcs_main_unit_passive_inactive_fighting", true)

    tcs_battle.unit_actively_charging[unit:unique_ui_id()] = true
    tcs_battle:set_unit_status(unit:unique_ui_id(),
        string.format("charging (%d/%.2f)", diceroll, normalised_charge_distance))
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") charging now.", __FILE__(), __LINE__(), __FUNC__());

    bm:repeat_callback(
        function()
            stopcharge_unit(unit, charge_target, overcharge_time, callback_name)
        end,
        2000,
        callback_name
    )

    bm:callback(
        function()
            scrunit.uc:attack_unit(charge_target, true, true)
        end,
        500
    )
end

function unit_free_move(unit, time)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    local callback_name = tcs_battle.unit_callback_names["stopmove"] .. unit:unique_ui_id()

    bm:remove_callback(callback_name);

    unit:disable_special_ability("tcs_main_unit_passive_stationary", true)
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can move freely.", __FILE__(), __LINE__(), __FUNC__());

    bm:callback(
        function()
            freeze_unit(unit)
        end,
        time,
        callback_name
    )
end

function stopretreat_unit(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);

    if scrunit_is_engaged(scrunit) then
        tcs:log("Unit(" .. unit:unique_ui_id() .. ") still engaged.", __FILE__(), __LINE__(), __FUNC__())
        scrunit:withdraw(true)
        bm:callback(
            function()
                stopretreat_unit(unit)
            end,
            3000,
            tcs_battle.unit_callback_names["stopretreat"] .. unit:unique_ui_id()
        )
        return
    end

    unit:disable_special_ability("tcs_main_unit_passive_stationary", false)
    stop_scrunit(scrunit)
    tcs_battle.unit_actively_retreating[unit:unique_ui_id()] = nil
    tcs_battle:clear_unit_status(unit:unique_ui_id())
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") stopped retreating.", __FILE__(), __LINE__(), __FUNC__())
end

function unit_retreat(unit, time)
    if tcs_battle.unit_actively_retreating[unit:unique_ui_id()] then
        return
    end
    local scrunit = bm:get_scriptunit_for_unit(unit);

    unit:disable_special_ability("tcs_main_unit_passive_stationary", true)
    scrunit:take_control()
    scrunit:withdraw(true)

    bm:callback(
        function()
            stopretreat_unit(unit)
        end,
        time,
        tcs_battle.unit_callback_names["stopretreat"] .. unit:unique_ui_id()
    )

    tcs_battle.unit_actively_retreating[unit:unique_ui_id()] = true
    tcs_battle.unit_retreated[unit:unique_ui_id()] = true
    tcs_battle:set_unit_status(unit:unique_ui_id(), "retreating")
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") is retreating.", __FILE__(), __LINE__(), __FUNC__())
end

function unit_crumble(unit, time)
    local scrunit = bm:get_scriptunit_for_unit(unit)
    scrunit:morale_behavior_rout()
    bm:callback(
        function()
            disable_morale(unit)
        end,
        time
    )
end

function unit_break(unit, time)
    local unit_cco = tcs_get_battleunit_cco(unit:unique_ui_id())
    if not unit_cco then
        return
    end

    tcs:log(
        string.format("Break testing Unit(%d) with morale %.2f", unit:unique_ui_id(), unit_cco:Call("MoralePercent")),
        __FILE__(), __LINE__(), __FUNC__())

    if unit_cco:Call("MoralePercent") < (tcs:get_config("unit_break_point") / 100) then
        local unit_details_cco = unit_cco:Call("UnitDetailsContext")
        local unit_base_leadership = unit_details_cco:Call("BaseStatValueFromKey('stat_morale')")

        local diceroll = roll_dice(tcs:get_config("break_test_dice"), tcs:get_config("default_dice_eyes"))

        local breakpoint = normalise_to_range(unit_base_leadership, 100, tcs:get_config("break_test_dice"),
            tcs:get_config("default_dice_eyes"))

        tcs:log("Unit(" .. unit:unique_ui_id() .. ") rolled for breaking: " .. diceroll .. "/" .. breakpoint, __FILE__(),
            __LINE__(), __FUNC__())

        if diceroll > breakpoint then
            tcs:log("Unit(" .. unit:unique_ui_id() .. ") broke", __FILE__(), __LINE__(), __FUNC__())
            if unit_cco:Call("IsUndead") then
                unit_crumble(unit, time)
            else
                disable_morale(unit)
                unit_retreat(unit, time)
            end
        else
            tcs_battle:set_unit_status(unit:unique_ui_id(),
                string.format("did not break (%d/%.2f)", diceroll, breakpoint))
            disable_morale(unit)
        end
        return
    end
    disable_morale(unit)
end
