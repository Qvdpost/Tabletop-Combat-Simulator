local tcs = core:get_static_object("tcs");
local tcs_battle = core:get_static_object("tcs_battle");

function ai_freeze_unit(unit)      
    local scrunit = bm:get_scriptunit_for_unit(unit);
    scrunit:take_control()
    unit:disable_special_ability("tcs_main_unit_passive_stationary", false)
    unit:disable_special_ability("tcs_ai_unit_passive_ranged_fix", true)
    unit:set_stat_attribute("melee_disabled", true)
    scrunit:halt()

    bm:callback(
        function()
            scrunit:release_control()
            tcs:log("AI Unit("..unit:unique_ui_id()..") can no longer move.");
            tcs_battle.ai_actively_moving = math.max(tcs_battle.ai_actively_moving - 1, 0)   
        end, 
        500
    )
end;

function ai_unit_move(unit, time)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    local callback_name = "freeze_unit_"..unit:unique_ui_id();
    bm:remove_callback(callback_name);
    
    tcs:log("AI Unit("..unit:unique_ui_id()..") can move.");
    tcs_battle.ai_actively_moving = tcs_battle.ai_actively_moving + 1
    
    if not unit:is_in_melee() then
        unit:set_stat_attribute("melee_disabled", false)
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
            if tcs_get_battleunit_cco(unit:unique_ui_id()):Call("IsFiringMissiles")  then
                tcs:log("AI Unit("..unit:unique_ui_id()..") is firing missiles.");
                bm:remove_callback(callback_name);
                ai_freeze_unit(unit) 
            else 
                bm:callback(
                    function()
                        if not (unit:is_moving() or unit:is_moving_fast())  then
                            tcs:log("AI Unit("..unit:unique_ui_id()..") is not moving.");
                            bm:remove_callback(callback_name);
                            ai_freeze_unit(unit) 
                        end
                    end, 
                    1500
                )
            end
        end, 
        500
    )
    

    bm:callback(
        function() 
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
    unit:set_stat_attribute("melee_disabled", true)
    scrunit:halt()
    
    bm:callback(
        function()
            scrunit:release_control()
            tcs:log("AI Unit("..unit:unique_ui_id()..") can no longer fight.");
        end, 
        500
    )
end;

function ai_unit_fight(unit, time)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    
    unit:disable_special_ability("tcs_main_unit_passive_inactive_fighting", true)
    unit:set_stat_attribute("melee_disabled", false)
    tcs:log("AI Unit("..unit:unique_ui_id()..") can fight.");
    
    local callback_name = "stopfight_"..unit:unique_ui_id();
    
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

    bm:callback(
        function()
            scrunit:release_control()
            tcs_battle.ai_actively_shooting = math.max(0, tcs_battle.ai_actively_shooting - 1)
            tcs:log("AI Unit("..unit:unique_ui_id()..") is done shooting.");
        end, 
        500
    )
end

local function ai_check_slow_projectile(unit, unit_cco, iteration)

    if unit_cco:Call("DamageInflictedRecently") == 0 and iteration < 20 then
        tcs:log("AI Unit("..unit:unique_ui_id()..") still shooting iteration: "..iteration);
        bm:callback(
            function() 
                ai_check_slow_projectile(unit, unit_cco, iteration + 1) 
            end, 
            2000,
            callback_name
        )
    else
        tcs:log("AI Unit("..unit:unique_ui_id()..") has dealt damage recently.");
        ai_stopshoot_unit(unit)
    end
end

function ai_check_stopshoot_unit(unit, time)
    local battle_unit_cco = tcs_get_battleunit_cco(unit:unique_ui_id())
    
    local callback_name = "stopshoot_"..unit:unique_ui_id();
    
    if battle_unit_cco:Call("DamageInflictedRecently") == 0 and battle_unit_cco:Call("IsFiringMissiles") then
        tcs:log("AI Unit("..unit:unique_ui_id()..") has dealt no damage yet.");
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
    
    unit:set_stat_attribute("melee_disabled", false)
    
    scrunit:take_control()
    scrunit:halt()
    scrunit:release_control()

    tcs:log("AI Unit("..unit:unique_ui_id()..") can shoot.");
    
    tcs_battle.ai_actively_shooting = tcs_battle.ai_actively_shooting + 1;
        
    local callback_name = "stopshoot_"..unit:unique_ui_id();
    
    bm:callback(
        function()
            if not tcs_get_battleunit_cco(unit:unique_ui_id()):Call("IsFiringMissiles") then
                tcs:log("AI Unit("..unit:unique_ui_id()..") is not shooting.");
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
    unit:disable_special_ability("tcs_main_unit_passive_stationary", false)
    unit:set_stat_attribute("melee_disabled", true)

    local scrunit = bm:get_scriptunit_for_unit(unit);  
    scrunit:grant_infinite_ammo();
    scrunit:halt()

    bm:callback(
        function()
            scrunit:release_control()
            tcs_battle.ai_actively_charging = math.max(0, tcs_battle.ai_actively_charging - 1)
            tcs:log("AI Unit("..unit:unique_ui_id()..") stopped charging.");
        end, 
        500
    )
end

function ai_stopcharge_unit(unit, charge_unit, charge_target, callback_name)
    if unit:is_in_melee() then
        tcs:log("AI Unit ("..unit:unique_ui_id()..") in melee.")
        bm:remove_callback(callback_name)
        charge_unit:stop_attack_enemy_scriptunits()
        ai_unit_end_charge(unit)
        return
    elseif not unit:is_moving() then
        tcs:log("AI Unit ("..unit:unique_ui_id()..") in not moving. Aborting charge.")
        bm:remove_callback(callback_name)
        charge_unit:stop_attack_enemy_scriptunits()
        ai_unit_end_charge(unit)
        return
    end
    
    tcs:log("AI Unit ("..unit:unique_ui_id()..") not yet in melee.")
    ai_unit_move(unit, 5000);
    charge_unit:attack_enemy_scriptunits(charge_target, true)
end

function scrunit_is_currently_flying(scrunit)
    return scrunit.unit:is_currently_flying()
end

function scrunit_is_currently_grounded(scrunit)
    return not scrunit_is_currently_flying(scrunit)
end

function ai_unit_charge(unit)
    tcs:log("Unit("..unit:unique_ui_id()..") charging.");
    local battle_unit_cco = tcs_get_battleunit_cco(unit:unique_ui_id())
    tcs_battle.ai_actively_charging = tcs_battle.ai_actively_charging + 1
    
    local scrunit = bm:get_scriptunit_for_unit(unit);     
    
    scrunit:take_control()

    if battle_unit_cco:Call("IsFiringMissiles") then
        tcs:log("Blocking charge; unit("..unit:unique_ui_id()..") is firing missiles!")
        ai_unit_end_charge(unit)
        return
    end
    
    if unit:is_in_melee() then
        tcs:log("Blocking charge; unit("..unit:unique_ui_id()..") is in melee!")
        ai_unit_end_charge(unit)
        return
    end
    
    unit:set_stat_attribute("melee_disabled", false)
    
    local player_scrunits = bm:get_scriptunits_for_local_players_army()
    
    if not unit:is_currently_flying() then
        player_scrunits = player_scrunits:filter("charge_targets", scrunit_is_currently_grounded)
    end
    
    local nearest_target_sunit_index = get_nearest(scrunit.unit:position(), player_scrunits)
    local nearest_target_sunit = bm:get_scriptunits_for_local_players_army():item(nearest_target_sunit_index)
    
    local charge_distance = scrunit.unit:position():distance_xz(nearest_target_sunit.unit:position());
    
    if charge_distance > tcs_battle.charge_range then
        tcs:log("Blocking charge; target is out of range!")
        ai_unit_end_charge(unit)
        return
    end

    local diceroll = 0;
    for i = 1, tcs_battle.charge_dice_count do 
        diceroll = diceroll + math.ceil(bm:random_number() * (tcs_battle.charge_range/tcs_battle.charge_dice_count))
    end 
    
    tcs:log("AI Charge rolled: "..diceroll);
    
    if diceroll < charge_distance then
        tcs:log("Blocking charge; the roll failed!")
        ai_unit_end_charge(unit)
        return
    end
    
    local callback_name = "ai_stopcharge_"..unit:unique_ui_id();
    
    local charge_unit = script_units:new("tcs_charge_unit", scrunit)
    local charge_target = script_units:new("tcs_charge_target", nearest_target_sunit)
    
    unit_move(unit, 5000)
    
    bm:callback(
        function() 
            scrunit:play_sound_charge()
            charge_unit:attack_enemy_scriptunits(charge_target, true)
        end, 
        500
    )

    bm:repeat_callback(function() ai_stopcharge_unit(unit, charge_unit, charge_target, callback_name) end, 2000, callback_name)
end