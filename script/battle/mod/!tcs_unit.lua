local tcs = core:get_static_object("tcs");
local tcs_battle = core:get_static_object("tcs_battle");


function freeze_unit(unit) 
    unit:disable_special_ability("tcs_main_unit_passive_stationary", false)
    tcs:log("Unit("..unit:unique_ui_id()..") can no longer move.");
    unit:set_stat_attribute("melee_disabled", true)
    bm:get_scriptunit_for_unit(unit):halt()
end;

function unit_move(unit, time)
    local callback_name = "freeze_unit_"..unit:unique_ui_id();
    
    bm:remove_callback(callback_name);
    
    unit:disable_special_ability("tcs_main_unit_passive_stationary", true)
    tcs:log("Unit("..unit:unique_ui_id()..") can move.");

    bm:callback(
        function() 
            freeze_unit(unit) 
        end, 
        time,
        callback_name
    )
end

function stopfight_unit(unit) 
    unit:disable_special_ability("tcs_main_unit_passive_inactive_fighting", false)
    unit:set_stat_attribute("melee_disabled", true)
    bm:get_scriptunit_for_unit(unit):halt()
    tcs:log("Unit("..unit:unique_ui_id()..") can no longer fight.");
end;

function unit_fight(unit, time)
    unit:set_stat_attribute("melee_disabled", false)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    scrunit:set_melee_mode(true, true)
    
    local callback_name = "stopfight_"..unit:unique_ui_id();
    
    bm:remove_callback(callback_name);
    
    unit:disable_special_ability("tcs_main_unit_passive_inactive_fighting", true)
    tcs:log("Unit("..unit:unique_ui_id()..") can fight.");
    
    bm:callback(
        function() 
            stopfight_unit(unit)
        end, 
        time,
        callback_name
    )
end

function stopshoot_unit(unit) 
    local battle_unit_cco = tcs_get_battleunit_cco(unit:unique_ui_id())
    
    local callback_name = "stopshoot_"..unit:unique_ui_id();
    
    local scrunit = bm:get_scriptunit_for_unit(unit);
    unit:disable_special_ability("tcs_main_unit_passive_inactive_shooting", false)
    scrunit:halt();
    tcs:log("Unit("..unit:unique_ui_id()..") can no longer shoot.");
    
end;

function unit_shoot(unit, time)
    tcs:log("Unit("..unit:unique_ui_id()..") can shoot.");
    
    local callback_name = "stopshoot_"..unit:unique_ui_id();
    bm:remove_callback(callback_name);
        
    unit:disable_special_ability("tcs_main_unit_passive_inactive_shooting", true)
    
    local scrunit = bm:get_scriptunit_for_unit(unit);
    scrunit:set_melee_mode(false, true)
    
    bm:callback(
        function() 
            stopshoot_unit(unit) 
        end, 
        time,
        callback_name
    )
end

function unit_end_charge(unit)
    tcs:log("Unit("..unit:unique_ui_id()..") stopped charging.");
    local scrunit = bm:get_scriptunit_for_unit(unit);
    unit:set_stat_attribute("melee_disabled", true)
    scrunit:halt();
end

function stopcharge_unit(unit, charge_unit, charge_target, callback_name)
    if unit:is_in_melee() then
        tcs:log("Unit ("..unit:unique_ui_id()..") in melee.")
        bm:remove_callback(callback_name)
        charge_unit:stop_attack_enemy_scriptunits()
        unit_end_charge(unit)
        return
    elseif not unit:is_moving() then
        tcs:log("Unit ("..unit:unique_ui_id()..") in not moving. Aborting charge.")
        bm:remove_callback(callback_name)
        charge_unit:stop_attack_enemy_scriptunits()
        unit_end_charge(unit)
        return
    end
    
    tcs:log("Unit ("..unit:unique_ui_id()..") not yet in melee.")
    ai_unit_move(unit, 5000);
    charge_unit:attack_enemy_scriptunits(charge_target, true)
end

function unit_charge(unit)
    tcs:log("Unit("..unit:unique_ui_id()..") charging now.");
    
    local scrunit = bm:get_scriptunit_for_unit(unit);
    scrunit:halt();
    unit:set_stat_attribute("melee_disabled", false)
    scrunit:set_melee_mode(true, true)
        
    if not tcs_battle.last_targeted_enemy_sunit then
        tcs:log("Blocking charge; target is not an enemy")
        unit_end_charge(unit)
        return
    end
      
    local charge_distance = tcs_battle.last_targeted_enemy_sunit.unit:position():distance_xz(unit:position());
    tcs:log("Charge distance: "..charge_distance)

    
    if charge_distance > tcs_battle.charge_range then
        tcs:log("Blocking charge; target is too far away")
        unit_end_charge(unit)
        return
    end
    
    local diceroll = 0;
    for i = 1, tcs_battle.charge_dice_count do 
        diceroll = diceroll + math.ceil(bm:random_number() * (tcs_battle.charge_range/tcs_battle.charge_dice_count))
    end 
    
    tcs:log("Charge rolled: "..diceroll);
    
    if diceroll < charge_distance then
        tcs:log("Blocking charge; the roll failed!")
        unit_end_charge(unit)
        return
    end
    local callback_name = "stopcharge_"..unit:unique_ui_id();
    
    bm:remove_callback(callback_name);
    
    scrunit:play_sound_charge()
    local charge_unit = script_units:new("tcs_charge_unit", scrunit)
    local charge_target = script_units:new("tcs_charge_target", tcs_battle.last_targeted_enemy_sunit)
    
    unit_move(unit, 5000)
    
    bm:repeat_callback(function() stopcharge_unit(unit, charge_unit, charge_target, callback_name) end, 2000, callback_name)
    
    bm:callback(
        function() 
            charge_unit:attack_enemy_scriptunits(charge_target, true)
        end, 
        500
    )
end