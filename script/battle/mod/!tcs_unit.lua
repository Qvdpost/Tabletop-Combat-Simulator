local tcs = core:get_static_object("tcs");
local tcs_battle = core:get_static_object("tcs_battle");


function freeze_unit(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    unit:disable_special_ability("tcs_main_unit_passive_stationary", false)
    disable_melee_attacks(unit)
    scrunit:halt()
    tcs_battle.unit_actively_moving[unit:unique_ui_id()] = false
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can no longer move.");
end;

function freeze_unit_in_engagement_range(scrunit, callback_name)
    if scrunit_is_engaged(scrunit, 10) then
        tcs:log("Unit(" .. scrunit.unit:unique_ui_id() .. ") entered engagement range.");
        scrunit:halt()
    end
end

function unit_move(unit, time)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    local callback_name = "freeze_unit_" .. unit:unique_ui_id();

    bm:remove_callback(callback_name);

    unit:disable_special_ability("tcs_main_unit_passive_stationary", true)
    tcs_battle.unit_actively_moving[unit:unique_ui_id()] = true

    unit:disable_special_ability("tcs_main_unit_passive_run", true)
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can move.");

    bm:repeat_callback(function() freeze_unit_in_engagement_range(scrunit, callback_name) end, 500,
        callback_name)

    bm:callback(
        function()
            bm:remove_callback(callback_name)
            freeze_unit(unit)
        end,
        time,
        callback_name
    )
end

function unit_run(unit, time)
    local extra_time = ((roll_dice(1, 6)/6) * time)
    time = time + extra_time
    
    unit_move(unit, time)

    tcs_battle.unit_ran[unit:unique_ui_id()] = true
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") running for " .. (extra_time/1000) .. " extra seconds.");
end

function stopfight_unit(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    unit:disable_special_ability("tcs_main_unit_passive_inactive_fighting", false)
    disable_melee_attacks(unit)

    scrunit:take_control()
    scrunit:halt()
    scrunit:taunt()
    scrunit:release_control()

    tcs_battle.unit_actively_fighting[unit:unique_ui_id()] = false
    
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can no longer fight.");
end;

function unit_fight(unit, time)
    enable_melee_attacks(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    scrunit:set_melee_mode(true, true)

    local attack_target = tcs_battle.last_targeted_enemy_sunit.unit

    local target_distance = unit:unit_distance(attack_target)
    tcs:log("Target distance: " .. target_distance)


    if target_distance > tcs_battle.engagement_distance then
        tcs:log("Blocking attack; target is too far away")
        stopfight_unit(unit)
        return
    end

    unit_free_move(unit, time)

    local callback_name = "stopfight_" .. unit:unique_ui_id();

    bm:remove_callback(callback_name);

    unit:disable_special_ability("tcs_main_unit_passive_inactive_fighting", true)
    tcs_battle.unit_actively_fighting[unit:unique_ui_id()] = true

    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can fight.");

    bm:callback(
        function()
            stopfight_unit(unit)
        end,
        time,
        callback_name
    )

    bm:callback(
        function()
            scrunit.uc:attack_unit(attack_target)
        end,
        500
    )
end

function stopshoot_unit(unit)
    local battle_unit_cco = tcs_get_battleunit_cco(unit:unique_ui_id())

    local callback_name = "stopshoot_" .. unit:unique_ui_id();

    local scrunit = bm:get_scriptunit_for_unit(unit);
    unit:disable_special_ability("tcs_main_unit_passive_inactive_shooting", false)
    scrunit:halt();
    tcs_battle.unit_actively_shooting[unit:unique_ui_id()] = false
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can no longer shoot.");
end;

function unit_shoot(unit, time)
    
    local callback_name = "stopshoot_" .. unit:unique_ui_id();
    bm:remove_callback(callback_name);
    
    unit:disable_special_ability("tcs_main_unit_passive_inactive_shooting", true)
    
    local scrunit = bm:get_scriptunit_for_unit(unit);
    scrunit:set_melee_mode(false, true)
    tcs_battle.unit_actively_shooting[unit:unique_ui_id()] = true
    
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can shoot.");
    bm:callback(
        function()
            stopshoot_unit(unit)
        end,
        time,
        callback_name
    )
end

function unit_end_charge(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    disable_melee_attacks(unit)
    unit:disable_special_ability("tcs_main_unit_passive_stationary", false)
    scrunit:halt();
    scrunit:taunt();
    scrunit:release_control()

    tcs_battle.unit_actively_charging[unit:unique_ui_id()] = false

    tcs:log("Unit(" .. unit:unique_ui_id() .. ") stopped charging.");
end

function stopcharge_unit(unit, charge_target, callback_name)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    if unit:is_in_melee() then
        tcs:log("Unit (" .. unit:unique_ui_id() .. ") in melee.")
        bm:remove_callback(callback_name)
        unit_end_charge(unit)
        return
    elseif not unit:is_moving() then
        tcs:log("Unit (" .. unit:unique_ui_id() .. ") in not moving. Aborting charge.")
        bm:remove_callback(callback_name)
        unit_end_charge(unit)
        return
    end

    tcs:log("Unit (" .. unit:unique_ui_id() .. ") not yet in melee.")
    scrunit.uc:attack_unit(charge_target)
end

function unit_charge(unit)
    
    local scrunit = bm:get_scriptunit_for_unit(unit);
    scrunit:halt();
    enable_melee_attacks(unit)
    scrunit:set_melee_mode(true, true)
    
    if not tcs_battle.last_targeted_enemy_sunit then
        tcs:log("Blocking charge; target is not an enemy")
        unit_end_charge(unit)
        return
    end
    
    if unit:is_in_melee() then
        tcs:log("Blocking charge; unit(" .. unit:unique_ui_id() .. ") is in melee!")
        unit_end_charge(unit)
        return
    end
    
    local charge_target = tcs_battle.last_targeted_enemy_sunit.unit
    
    local charge_distance = unit:unit_distance(charge_target)
    tcs:log("Charge distance: " .. charge_distance)
    
    
    if charge_distance > tcs_battle.charge_range then
        tcs:log("Blocking charge; target is too far away")
        unit_end_charge(unit)
        return
    end
    
    if not normalised_dice_check(charge_distance, tcs_battle.charge_range) then
        tcs:log("Blocking charge; the roll failed!")
        unit_end_charge(unit)
        return
    end
    
    local callback_name = "stopcharge_" .. unit:unique_ui_id();
    
    bm:remove_callback(callback_name);
    
    scrunit:play_sound_charge()
    
    unit:disable_special_ability("tcs_main_unit_passive_stationary", true)
    
    tcs_battle.unit_actively_charging[unit:unique_ui_id()] = true
    
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") charging now.");

    bm:repeat_callback(function() stopcharge_unit(unit, charge_target, callback_name) end, 2000,
        callback_name)

    bm:callback(
        function()
            scrunit.uc:attack_unit(charge_target)
        end,
        500
    )
end

function unit_free_move(unit, time)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    local callback_name = "freeze_unit_" .. unit:unique_ui_id();

    bm:remove_callback(callback_name);

    unit:disable_special_ability("tcs_main_unit_passive_stationary", true)
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can move freely.");

    bm:callback(
        function()
            bm:remove_callback(callback_name)
            freeze_unit(unit)
        end,
        time,
        callback_name
    )
end

function stopretreat_unit(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);

    local callback_name = "stopretreat_unit_" .. unit:unique_ui_id();

    if scrunit_is_engaged(scrunit) then
        tcs:log("Unit(" .. unit:unique_ui_id() .. ") still engaged.")
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

    tcs_battle.unit_actively_retreating[unit:unique_ui_id()] = false

    tcs:log("Unit(" .. unit:unique_ui_id() .. ") stopped retreating.")
end

function unit_retreat(unit, time)
    local scrunit = bm:get_scriptunit_for_unit(unit);

    local callback_name = "stopretreat_unit_" .. unit:unique_ui_id();

    scrunit:withdraw(true)

    bm:callback(
        function()
            stopretreat_unit(unit)
        end,
        time,
        callback_name
    )

    tcs_battle.unit_actively_retreating[unit:unique_ui_id()] = true
    tcs_battle.unit_retreated[unit:unique_ui_id()] = true

    tcs:log("Unit(" .. unit:unique_ui_id() .. ") is retreating.")
end
