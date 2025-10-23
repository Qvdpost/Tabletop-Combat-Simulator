local tcs = core:get_static_object("tcs");
local tcs_battle = core:get_static_object("tcs_battle");

function ai_freeze_unit(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);

    bm:remove_callback(tcs_battle.unit_callback_names["stopmove"] .. unit:unique_ui_id());

    unit:disable_special_ability("tcs_main_unit_passive_stationary", false)
    unit:disable_special_ability("tcs_ai_unit_passive_ranged_fix", true)
    disable_melee_attacks(unit)

    stop_scrunit(scrunit)

    tcs_battle.ai_actively_moving[unit:unique_ui_id()] = nil
    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") can no longer move.");
end;

function ai_freeze_unit_in_engagement_range(scrunit)
    if scrunit_is_engaged(scrunit, 5) then
        tcs:log("AI Unit(" .. scrunit.unit:unique_ui_id() .. ") entered engagement range.");
        bm:remove_callback(tcs_battle.unit_callback_names["stopmove"] .. scrunit.unit:unique_ui_id());
        ai_freeze_unit(scrunit.unit)
    elseif scrunit.unit:is_moving_fast() and scrunit_is_engaged(scrunit, 15) then
        scrunit.uc:change_move_speed(false)
    end
end

function ai_unit_move(unit, time)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    local callback_name = tcs_battle.unit_callback_names["stopmove"] .. unit:unique_ui_id()

    bm:remove_callback(callback_name);

    if scrunit_is_engaged(scrunit) then
        tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") is engaged, cannot move.");
        return
    end

    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") can move.");
    tcs_battle.ai_actively_moving[unit:unique_ui_id()] = true

    enable_melee_attacks(unit)

    unit:disable_special_ability("tcs_ai_unit_passive_ranged_fix", false)
    unit:disable_special_ability("tcs_main_unit_passive_stationary", true)

    bm:callback(
        function()
            scrunit:cache_destination()

            if has_unit_in_missile_range(scrunit) then
                tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") has enemy in range. Should it move?");
            end

            if not scrunit:get_cached_destination_position() and not unit:current_target() then
                tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") has no destination or target.");
                ai_freeze_unit(unit)
                return
            end

            if tcs_get_battleunit_cco(unit:unique_ui_id()):Call("IsFiringMissiles") then
                tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") is firing missiles.");
                bm:remove_callback(callback_name);
                ai_freeze_unit(unit)
            end
        end,
        500
    )

    bm:repeat_callback(
        function()
            ai_freeze_unit_in_engagement_range(scrunit)
        end,
        200,
        callback_name
    )

    bm:callback(
        function()
            if not unit:is_moving() then
                tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") is not moving.");
                bm:remove_callback(callback_name);
                ai_freeze_unit(unit)
            end
        end,
        2000,
        callback_name
    )

    bm:callback(
        function()
            bm:remove_callback(callback_name);
            ai_freeze_unit(unit)
        end,
        time,
        callback_name
    )
end

function ai_stopfight_unit(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);

    bm:remove_callback(tcs_battle.unit_callback_names["stopfight"] .. unit:unique_ui_id())

    scrunit:take_control()

    scrunit:stop_attack_closest_enemy()

    unit:disable_special_ability("tcs_main_unit_passive_inactive_fighting", false)
    disable_melee_attacks(unit)

    stop_scrunit(scrunit)

    tcs_battle.ai_actively_fighting[unit:unique_ui_id()] = nil
    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") can no longer fight.");
end;

function ai_unit_fight(unit, time)
    local scrunit = bm:get_scriptunit_for_unit(unit);

    if not scrunit_is_engaged(scrunit) then
        tcs:log("Blocking fight; unit(" .. unit:unique_ui_id() .. ") is not engaged!");
        return
    end

    tcs_battle.ai_actively_fighting[unit:unique_ui_id()] = true
    unit:disable_special_ability("tcs_main_unit_passive_inactive_fighting", true)
    unit:disable_special_ability("tcs_main_unit_passive_stationary", true)
    enable_melee_attacks(unit)
    scrunit:set_melee_mode(true, true)

    bm:callback(
        function()
            unit:disable_special_ability("tcs_main_unit_passive_stationary", false)
        end,
        tcs:get_config("pile_in_time") * 1000
    )

    scrunit:take_control()
    scrunit:start_attack_closest_enemy(2000)

    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") can fight.");

    local callback_name = tcs_battle.unit_callback_names["stopfight"] .. unit:unique_ui_id()

    bm:remove_callback(callback_name)

    bm:callback(
        function()
            ai_stopfight_unit(unit)
        end,
        time,
        callback_name
    )
end

function ai_stopshoot_unit(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);

    bm:remove_callback(tcs_battle.unit_callback_names["stopshoot"] .. unit:unique_ui_id())

    unit:disable_special_ability("tcs_main_unit_passive_inactive_shooting", false)
    unit:disable_special_ability("tcs_ai_unit_passive_ranged_fix", true)

    disable_melee_attacks(unit)
    stop_scrunit(scrunit)

    tcs_battle.ai_actively_shooting[unit:unique_ui_id()] = nil
    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") is done shooting.");
end

function reload_remaining_time(unit_cco)
    local reload_time = 0
    local entity_list = unit_cco:Call("EntityList")
    for i = 1, unit_cco:Call("EntityList.Size") do
        reload_time = math.max(reload_time, entity_list[i]:Call("ReloadRemainingTime"))
    end
    return reload_time
end

function ai_unit_shoot(unit, time)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    local unit_cco = tcs_get_battleunit_cco(unit:unique_ui_id())

    local callback_name = tcs_battle.unit_callback_names["stopshoot"] .. unit:unique_ui_id()

    bm:remove_callback(callback_name)

    if not unit_cco then
        return
    end

    if not get_unit_missile_range(unit) then
        tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") has no missile weapon.");
        return
    end

    local reload_time = reload_remaining_time(unit_cco)
    if reload_time > 1 then
        tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") still reloading : " .. reload_time);
        tcs_battle.ai_actively_shooting[unit:unique_ui_id()] = true
        bm:callback(
            function()
                ai_unit_shoot(unit, time)
            end,
            500
        )
        return
    end

    unit:disable_special_ability("tcs_main_unit_passive_inactive_shooting", true)
    unit:disable_special_ability("tcs_ai_unit_passive_ranged_fix", false)

    enable_melee_attacks(unit)

    scrunit:set_melee_mode(false, true)

    stop_scrunit(scrunit)

    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") can shoot.");

    tcs_battle.ai_actively_shooting[unit:unique_ui_id()] = true

    bm:callback(
        function()
            if not has_unit_in_missile_range(scrunit) then
                tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") has no target in range.");
                ai_stopshoot_unit(unit)
                return
            end
        end,
        500,
        callback_name
    )


    bm:callback(
        function()
            if not unit:current_target() then
                tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") is not targetting anything.");
                ai_stopshoot_unit(unit)
            end
        end,
        5000,
        callback_name
    )

    bm:callback(
        function()
            ai_stopshoot_unit(unit)
        end,
        time,
        callback_name
    )
end

function ai_unit_end_charge(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    unit:disable_special_ability("tcs_main_unit_passive_stationary", false)

    disable_melee_attacks(unit)
    stop_scrunit(scrunit)

    if tcs_battle.unit_should_land[unit:unique_ui_id()] then
        bm:repeat_callback(
            function()
                land_unit(unit)
            end,
            1000,
            tcs_battle.unit_callback_names["landunit"] .. unit:unique_ui_id()
        )
    end

    tcs_battle.ai_actively_charging[unit:unique_ui_id()] = nil

    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") stopped charging.");
end

function ai_stopcharge_unit(unit, target, overcharge_time)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    local callback_name = tcs_battle.unit_callback_names["stopcharge"] .. unit:unique_ui_id()

    if unit:is_in_melee() then
        tcs:log("AI Unit (" .. unit:unique_ui_id() .. ") in melee.");

        bm:remove_callback(callback_name)

        bm:callback(
            function()
                stop_unit(target.unit)
                ai_unit_end_charge(unit)
            end,
            overcharge_time
        )
        return
    elseif not unit:is_moving_fast() then
        tcs:log("AI Unit (" .. unit:unique_ui_id() .. ") has stopped moving at destination (stuck in the air?).");
        bm:remove_callback(callback_name)
        ai_unit_end_charge(unit)
        return
    end

    scrunit:take_control()
    scrunit.uc:attack_unit(target.unit, true, true)

    tcs:log("AI Unit (" .. unit:unique_ui_id() .. ") not yet in melee.");
end

function ai_unit_charge(unit)
    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") charging.");
    local battle_unit_cco = tcs_get_battleunit_cco(unit:unique_ui_id())
    tcs_battle.ai_actively_charging[unit:unique_ui_id()] = true

    local scrunit = bm:get_scriptunit_for_unit(unit);

    if battle_unit_cco and battle_unit_cco:Call("IsFiringMissiles") then
        tcs:log("Blocking charge; unit(" .. unit:unique_ui_id() .. ") is firing missiles!");
        ai_unit_end_charge(unit)
        return
    end

    if scrunit_is_engaged(scrunit) then
        tcs:log("Blocking charge; unit(" .. unit:unique_ui_id() .. ") is in melee!");
        ai_unit_end_charge(unit)
        return
    end

    enable_melee_attacks(unit)

    local ai_target = nearest_enemy_at_ai_destination(scrunit)

    if not ai_target then
        tcs:log("AI has no target to attack.");
        ai_unit_end_charge(unit)
        return
    end

    local charge_distance = unit:unit_distance(ai_target.unit);
    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") targeting unit(" .. ai_target.unit:unique_ui_id() .. ") to charge.");

    if charge_distance > tcs_battle.charge_range then
        tcs:log("Blocking charge; target is out of range!");
        ai_unit_end_charge(unit)
        return
    end

    local diceroll = roll_dice(tcs:get_config("default_charge_dice"), tcs:get_config("default_dice_eyes"))
    local normalised_charge_distance = normalise_to_range(charge_distance, tcs_battle.charge_range)

    if not (diceroll >= normalised_charge_distance) then
        tcs:log("Blocking charge; the roll failed: " .. diceroll .. " / " .. normalised_charge_distance);
        ai_unit_end_charge(unit)
        return
    end

    local overcharge_time = ((diceroll - normalised_charge_distance) / (tcs:get_config("default_charge_dice") * tcs:get_config("default_dice_eyes"))) *
        tcs:get_config("overcharge_time") * 1000;

    unit:disable_special_ability("tcs_main_unit_passive_stationary", true)

    if tcs:get_config("enable_damage_on_charge") then
        unit:disable_special_ability("tcs_main_unit_passive_inactive_fighting")
    end

    if unit:is_currently_flying() and not ai_target.unit:is_currently_flying() and not unit:has_attribute("always_flying") then
        tcs_battle.unit_should_land[unit:unique_ui_id()] = true
    end

    local callback_name = tcs_battle.unit_callback_names["stopcharge"] .. unit:unique_ui_id()

    bm:remove_callback(callback_name)

    scrunit:take_control()
    scrunit:play_sound_charge()
    scrunit.uc:attack_unit(ai_target.unit, true, true)
    

    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") attacking target unit(" .. ai_target.unit:unique_ui_id() .. ")");

    bm:callback(
        function()
            scrunit.uc:attack_unit(ai_target.unit, true, true)
        end,
        500,
        callback_name
    )

    bm:repeat_callback(
        function()
            ai_stopcharge_unit(unit, ai_target, overcharge_time)
        end,
        1000,
        callback_name
    )
end

function ai_unit_free_move(unit, time)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    local callback_name = tcs_battle.unit_callback_names["stopmove"] .. unit:unique_ui_id()

    bm:remove_callback(callback_name);

    unit:disable_special_ability("tcs_main_unit_passive_stationary", true)
    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") can move freely.");

    bm:callback(
        function()
            bm:remove_callback(callback_name)
            freeze_unit(unit)
        end,
        time,
        callback_name
    )
end

function ai_stopretreat_unit(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);

    local callback_name = tcs_battle.unit_callback_names["stopretreat"] .. unit:unique_ui_id()

    if scrunit_is_engaged(scrunit) then
        tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") still engaged.");
        bm:callback(
            function()
                stopretreat_unit(unit)
            end,
            2000,
            callback_name
        )
        return
    end

    stop_scrunit(scrunit)

    tcs_battle.ai_actively_retreating[unit:unique_ui_id()] = nil

    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") stopped retreating.");
end

function ai_unit_retreat(unit, time)
    local scrunit = bm:get_scriptunit_for_unit(unit);

    local callback_name = tcs_battle.unit_callback_names["stopretreat"] .. unit:unique_ui_id()

    scrunit:withdraw(true)

    bm:callback(
        function()
            ai_stopretreat_unit(unit)
        end,
        time,
        callback_name
    )

    tcs_battle.ai_actively_retreating[unit:unique_ui_id()] = true

    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") is retreating.");
end
