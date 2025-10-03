local tcs = core:get_static_object("tcs");
local tcs_battle = core:get_static_object("tcs_battle");

function ai_freeze_unit(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    scrunit:take_control()
    unit:disable_special_ability("tcs_main_unit_passive_stationary", false)
    unit:disable_special_ability("tcs_ai_unit_passive_ranged_fix", true)
    disable_melee_attacks(unit)

    scrunit:halt()
    scrunit:taunt()
    scrunit:release_control()
    tcs_battle.ai_actively_moving[unit:unique_ui_id()] = nil
    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") can no longer move.");
end;

function ai_freeze_unit_in_engagement_range(scrunit, callback_name)
    if scrunit_is_engaged(scrunit, 10) then
        tcs:log("AI Unit(" .. scrunit.unit:unique_ui_id() .. ") entered engagement range.");
        bm:remove_callback(callback_name)
        ai_freeze_unit(scrunit.unit)
    end
end

function ai_unit_move(unit, time)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    local callback_name = "freeze_unit_" .. unit:unique_ui_id();

    bm:remove_callback(callback_name);

    if scrunit_is_engaged(scrunit) then
        tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") is engaged, cannot move.");
        return
    end

    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") can move.");
    tcs_battle.ai_actively_moving[unit:unique_ui_id()] = true

    if not unit:is_in_melee() then
        enable_melee_attacks(unit)
    else
        ai_freeze_unit(unit)
        return
    end

    unit:disable_special_ability("tcs_ai_unit_passive_ranged_fix", false)
    unit:disable_special_ability("tcs_main_unit_passive_stationary", true)

    scrunit:take_control()
    scrunit:release_control()

    bm:callback(
        function()
            if tcs_get_battleunit_cco(unit:unique_ui_id()):Call("IsFiringMissiles") then
                tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") is firing missiles.");
                bm:remove_callback(callback_name);
                ai_freeze_unit(unit)
            end
        end,
        500
    )

    bm:repeat_callback(function() ai_freeze_unit_in_engagement_range(scrunit, callback_name) end, 100,
        callback_name)

    bm:callback(
        function()
            if not (unit:is_moving() or unit:is_moving_fast()) then
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

    scrunit:take_control()
    unit:disable_special_ability("tcs_main_unit_passive_inactive_fighting", false)
    unit:disable_special_ability("tcs_main_unit_passive_stationary", false)
    disable_melee_attacks(unit)
    scrunit:stop_attack_closest_enemy()
    scrunit:halt()
    scrunit:taunt()
    scrunit:release_control()

    tcs_battle.ai_actively_fighting[unit:unique_ui_id()] = nil
    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") can no longer fight.");
end;

function ai_unit_fight(unit, time)
    local scrunit = bm:get_scriptunit_for_unit(unit);

    if not scrunit_is_engaged(scrunit) then
        tcs:log("Blocking fight; unit(" .. unit:unique_ui_id() .. ") is not engaged!")
        return
    end

    tcs_battle.ai_actively_fighting[unit:unique_ui_id()] = true
    unit:disable_special_ability("tcs_main_unit_passive_inactive_fighting", true)
    enable_melee_attacks(unit)
    ai_unit_free_move(unit, time)

    scrunit:take_control()
    scrunit:start_attack_closest_enemy()
    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") can fight.");

    local callback_name = "stopfight_" .. unit:unique_ui_id();

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
    unit:disable_special_ability("tcs_main_unit_passive_inactive_shooting", false)
    unit:disable_special_ability("tcs_ai_unit_passive_ranged_fix", true)

    scrunit:take_control()
    scrunit:halt()
    scrunit:taunt()
    scrunit:release_control()
    tcs_battle.ai_actively_shooting[unit:unique_ui_id()] = nil
    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") is done shooting.");
end

local function ai_check_slow_projectile(unit, unit_cco, iteration)
    if unit_cco:Call("DamageInflictedRecently") == 0 and iteration < 20 then
        tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") still shooting iteration: " .. iteration);
        bm:callback(
            function()
                ai_check_slow_projectile(unit, unit_cco, iteration + 1)
            end,
            2000
        )
    else
        tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") has dealt damage recently.");
        ai_stopshoot_unit(unit)
    end
end

function ai_check_stopshoot_unit(unit, time)
    local battle_unit_cco = tcs_get_battleunit_cco(unit:unique_ui_id())

    local callback_name = "stopshoot_" .. unit:unique_ui_id();

    if battle_unit_cco and (battle_unit_cco:Call("DamageInflictedRecently") == 0 and battle_unit_cco:Call("IsFiringMissiles")) then
        tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") has dealt no damage yet.");
        bm:callback(
            function()
                ai_check_slow_projectile(unit, battle_unit_cco, 1)
            end,
            2000,
            callback_name
        )
    else
        ai_stopshoot_unit(unit)
    end
end;

function ai_unit_shoot(unit, time)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    unit:disable_special_ability("tcs_main_unit_passive_inactive_shooting", true)
    unit:disable_special_ability("tcs_ai_unit_passive_ranged_fix", false)

    enable_melee_attacks(unit)

    scrunit:take_control()
    scrunit:halt()
    scrunit:release_control()

    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") can shoot.");

    tcs_battle.ai_actively_shooting[unit:unique_ui_id()] = true

    local callback_name = "stopshoot_" .. unit:unique_ui_id();

    bm:callback(
        function()
            if not tcs_get_battleunit_cco(unit:unique_ui_id()):Call("IsFiringMissiles") then
                tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") is not shooting.");
                bm:remove_callback(callback_name);
                ai_stopshoot_unit(unit)
            end
        end,
        4000
    )

    bm:callback(
        function()
            ai_check_stopshoot_unit(unit, time)
        end,
        time,
        callback_name
    )
end

function ai_unit_end_charge(unit)    
    disable_melee_attacks(unit)
    unit:disable_special_ability("tcs_main_unit_passive_stationary", false)

    local scrunit = bm:get_scriptunit_for_unit(unit);
    scrunit:take_control();
    scrunit:grant_infinite_ammo();
    scrunit:halt();
    scrunit:taunt();
    scrunit:release_control()
    tcs_battle.ai_actively_charging[unit:unique_ui_id()] = nil
    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") stopped charging.");
end

function ai_stopcharge_unit(unit, target, callback_name)
    if unit:is_in_melee() then
        tcs:log("AI Unit (" .. unit:unique_ui_id() .. ") in melee.")
        bm:remove_callback(callback_name)

        bm:callback(
            function()
                ai_unit_end_charge(unit)
            end,
            3000
        )
        return
    end
    tcs:log("AI Unit (" .. unit:unique_ui_id() .. ") not yet in melee.")

    local scrunit = bm:get_scriptunit_for_unit(unit);
    scrunit:take_control()
    scrunit.uc:attack_unit(target.unit)
    tcs:log("Attacking again.")
end

function ai_unit_charge(unit)
    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") charging.");
    local battle_unit_cco = tcs_get_battleunit_cco(unit:unique_ui_id())
    tcs_battle.ai_actively_charging[unit:unique_ui_id()] = true

    local scrunit = bm:get_scriptunit_for_unit(unit);

    if battle_unit_cco and battle_unit_cco:Call("IsFiringMissiles") then
        tcs:log("Blocking charge; unit(" .. unit:unique_ui_id() .. ") is firing missiles!")
        ai_unit_end_charge(unit)
        return
    end

    if scrunit_is_engaged(scrunit) then
        tcs:log("Blocking charge; unit(" .. unit:unique_ui_id() .. ") is in melee!")
        ai_unit_end_charge(unit)
        return
    end

    enable_melee_attacks(unit)

    local ai_target = nearest_enemy_at_destination(scrunit)
    
    if ai_target then
        local charge_distance = unit:unit_distance(ai_target.unit);
        tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") targeting unit(" .. ai_target.unit:unique_ui_id() .. ") to charge.");

        if charge_distance > tcs_battle.charge_range then
            tcs:log("Blocking charge; target is out of range!")
            ai_unit_end_charge(unit)
            return
        end

        if not normalised_dice_check(charge_distance, tcs_battle.charge_range) then
            tcs:log("Blocking charge; the roll failed!")
            ai_unit_end_charge(unit)
            return
        end

        unit:disable_special_ability("tcs_main_unit_passive_stationary", true)

        local callback_name = "ai_stopcharge_" .. unit:unique_ui_id();

        bm:remove_callback(callback_name)

        scrunit:play_sound_charge()
        scrunit.uc:attack_unit(ai_target.unit)
        tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") attacking target unit(" .. ai_target.unit:unique_ui_id() .. ")");

        bm:repeat_callback(function() ai_stopcharge_unit(unit, ai_target, callback_name) end, 500,
            callback_name)
    else
        tcs:log("AI has no target to attack.")
        ai_unit_end_charge(unit)
    end
end

function ai_unit_free_move(unit, time)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    local callback_name = "freeze_unit_" .. unit:unique_ui_id();

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

    local callback_name = "stopretreat_unit_" .. unit:unique_ui_id();

    if scrunit_is_engaged(scrunit) then
        tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") still engaged.")
        bm:callback(
            function()
                stopretreat_unit(unit)
            end,
            2000,
            callback_name
        )
        return
    end

    scrunit:halt()

    tcs_battle.ai_actively_retreating[unit:unique_ui_id()] = false

    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") stopped retreating.")
end

function ai_unit_retreat(unit, time)
    local scrunit = bm:get_scriptunit_for_unit(unit);

    local callback_name = "stopretreat_unit_" .. unit:unique_ui_id();

    scrunit:withdraw(true)

    bm:callback(
        function()
            ai_stopretreat_unit(unit)
        end,
        time,
        callback_name
    )

    tcs_battle.ai_actively_retreating[unit:unique_ui_id()] = true

    tcs:log("AI Unit(" .. unit:unique_ui_id() .. ") is retreating.")
end