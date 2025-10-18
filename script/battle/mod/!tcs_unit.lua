local tcs = core:get_static_object("tcs");
local tcs_battle = core:get_static_object("tcs_battle");


function freeze_unit(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);

    bm:remove_callback(tcs_battle.unit_callback_names["stopmove"] .. unit:unique_ui_id());
    bm:remove_callback(tcs_battle.unit_callback_names["engage_check"] .. unit:unique_ui_id())
    bm:remove_callback(tcs_battle.unit_callback_names["engage_warn"] .. unit:unique_ui_id())
    bm:remove_callback(tcs_battle.unit_callback_names["startmove"] .. unit:unique_ui_id())

    unit:disable_special_ability("tcs_main_unit_passive_stationary", false)

    disable_melee_attacks(unit)

    stop_scrunit(scrunit)

    tcs_battle.unit_actively_moving[unit:unique_ui_id()] = nil
    tcs_battle:clear_unit_status(unit:unique_ui_id())
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can no longer move.");
end;

function freeze_unit_in_engagement_range(scrunit)
    if scrunit_is_engaged(scrunit, 5) then
        freeze_unit(scrunit.unit)
        tcs:log("Unit(" .. scrunit.unit:unique_ui_id() .. ") entered engagement range.");
    end
end

function warn_about_engagement_range(scrunit, buffer, destination)
    local engaged, enemy_scrunit = scrunit_is_engaged(scrunit, buffer)
    if not tcs_battle.unit_movement_warned[scrunit.unit:unique_ui_id()] and engaged and enemy_scrunit then
        freeze_unit(scrunit.unit)

        tcs_battle.unit_movement_warned[scrunit.unit:unique_ui_id()] = true

        scrunit.unit:highlight(true)
        enemy_scrunit.unit:highlight(true)

        bm:callback(
            function()
                scrunit.unit:highlight(false)
                enemy_scrunit.unit:highlight(false)
            end,
            5000
        )

        bm:slow_game_over_time(bm:current_battle_speed(), 0.5, 500, 5)
        bm:callback(
            function()
                bm:slow_game_over_time(bm:current_battle_speed(), 1, 500, 5)
            end,
            3000
        )

        local destination_distance = scrunit.unit:position():distance_xz(destination)
        if destination_distance > 5 then
            tcs_battle.unit_movement_range[scrunit.unit:unique_ui_id()] = tcs_battle.unit_movement_range
                [scrunit.unit:unique_ui_id()] + destination_distance
        end

        tcs_get_battleunit_cco(scrunit.unit:unique_ui_id()):Call("ZoomTo")
        tcs:log("Unit(" .. scrunit.unit:unique_ui_id() .. ") nearing engagement range.");
    end
end

function unit_move(unit)
    --  try to use: unitcontroller:add_animated_selection_proxy(
    if tcs_battle.unit_actively_moving[unit:unique_ui_id()] then
        return
    end
    local scrunit = bm:get_scriptunit_for_unit(unit);
    local move_callback_name = tcs_battle.unit_callback_names["startmove"] .. unit:unique_ui_id()
    local callback_name = tcs_battle.unit_callback_names["stopmove"] .. unit:unique_ui_id()
    local engage_callback_name = tcs_battle.unit_callback_names["engage_check"] .. unit:unique_ui_id()

    bm:remove_callback(callback_name);
    bm:remove_callback(engage_callback_name)

    local destination = tcs_battle.last_clicked_position

    if not destination then
        tcs:log("Can't move; no destination clicked.")
        return
    end

    local destination_distance = get_unit_to_position_distance(unit, destination)

    if destination_distance > tcs_battle.unit_movement_range[scrunit.unit:unique_ui_id()] then
        tcs:log("Distance (" .. destination_distance .. ") too far to move");
        tcs_battle:set_unit_status(unit:unique_ui_id(),
            string.format("idle.\nCan't reach %d metres.", destination_distance))
        bm:callback(
            function()
                tcs_battle:clear_unit_status(unit:unique_ui_id())
            end,
            3000
        )
        enable_unit_move(unit)
        return
    end

    if not unit:can_reach_position(destination) then
        tcs:log("Can't move to destination; unreachable.");
        tcs_battle:set_unit_status(unit:unique_ui_id(), "idle.\nCan't reach destination.")
        bm:callback(
            function()
                tcs_battle:clear_unit_status(unit:unique_ui_id())
            end,
            3000
        )
        enable_unit_move(unit)
        return
    end

    if position_in_range(scrunit, destination, tcs_battle.engagement_distance, scrunit.unit:is_currently_flying()) then
        tcs:log("Can't move to destination; it is within engagement range.");
        tcs_battle:set_unit_status(unit:unique_ui_id(), "idle\nDestination is within engagement range.")
        bm:callback(
            function()
                tcs_battle:clear_unit_status(unit:unique_ui_id())
            end,
            3000
        )
        enable_unit_move(unit)
        return
    end

    unit:disable_special_ability("tcs_main_unit_passive_stationary", true)
    tcs_battle.unit_actively_moving[unit:unique_ui_id()] = true

    scrunit:take_control()

    local unit_bearing = r_to_d(get_bearing(scrunit.unit:position(), destination))
    local unit_width = scrunit.unit:ordered_width()

    tcs_battle:set_unit_status(unit:unique_ui_id(), "moving.")
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can move.");

    tcs_battle.unit_movement_range[scrunit.unit:unique_ui_id()] = tcs_battle.unit_movement_range
        [scrunit.unit:unique_ui_id()] - destination_distance

    bm:repeat_callback(
        function()
            if unit_entities_in_range(unit, unit:ordered_position(), 5) then
                bm:remove_callback(callback_name)
                bm:callback(
                    function()
                        freeze_unit(unit)
                    end,
                    3000
                )
                return
            end
            tcs:log("Unit(" ..
                unit:unique_ui_id() ..
                ") distance to target: " .. get_unit_to_position_distance(unit, destination))
        end,
        1000,
        callback_name
    )

    bm:repeat_callback(
        function()
            if not unit:is_moving() then
                if not tcs:get_config("force_straight_movement") then
                    scrunit.uc:goto_location_angle_width(destination, unit_bearing, unit_width, true)
                else
                    scrunit:goto_location_offset(0, destination_distance, true)
                end
                return
            end
            bm:remove_callback(move_callback_name)
        end,
        500,
        move_callback_name
    )

    bm:repeat_callback(
        function()
            freeze_unit_in_engagement_range(scrunit)
        end,
        500,
        engage_callback_name
    )

    if tcs:get_config("warn_about_engagement_range") and not tcs_battle.unit_movement_warned[scrunit.unit:unique_ui_id()] then
        bm:repeat_callback(
            function()
                warn_about_engagement_range(
                    scrunit,
                    tcs:get_config("warn_about_engagement_range_distance"),
                    destination
                )
            end,
            500,
            tcs_battle.unit_callback_names["engage_warn"] .. unit:unique_ui_id()
        )
    end
end

function unit_run(unit)
    if tcs_battle.unit_actively_moving[unit:unique_ui_id()] then
        return
    end

    local extra_distance = ((roll_dice(tcs:get_config("default_run_dice"), tcs:get_config("default_dice_eyes")) / tcs:get_config("default_dice_eyes")) * tcs:get_config("max_run_distance"))

    tcs_battle.unit_movement_range[unit:unique_ui_id()] = tcs_battle.unit_movement_range[unit:unique_ui_id()] +
        extra_distance

    tcs_battle.unit_ran[unit:unique_ui_id()] = true
end

function stopfight_unit(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);

    bm:remove_callback(tcs_battle.unit_callback_names["stopfight"] .. unit:unique_ui_id());
    bm:remove_callback(tcs_battle.unit_callback_names["startfight"] .. unit:unique_ui_id())

    unit:disable_special_ability("tcs_main_unit_passive_inactive_fighting", false)
    disable_melee_attacks(unit)

    stop_scrunit(scrunit)

    tcs_battle.unit_actively_fighting[unit:unique_ui_id()] = nil
    tcs_battle:clear_unit_status(unit:unique_ui_id())
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can no longer fight.");
end;

function unit_fight(unit, time)
    if tcs_battle.unit_actively_fighting[unit:unique_ui_id()] then
        return
    end

    enable_melee_attacks(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    scrunit:set_melee_mode(true, true)

    local attack_target = tcs_battle.last_targeted_enemy_sunit.unit

    if not attack_target then
        tcs:log("Blocking fight; target is not an enemy");
        enable_unit_fight(unit)
        stopfight_unit(unit)
        return
    end

    local target_distance = unit:unit_distance(attack_target)
    tcs:log("Target distance: " .. target_distance);


    if target_distance > tcs_battle.engagement_distance then
        tcs:log("Blocking attack; target is too far away");
        enable_unit_fight(unit)
        stopfight_unit(unit)
        tcs_battle:set_unit_status(unit:unique_ui_id(),
            string.format("idle.\nCombat target out of range (%d).", target_distance))
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
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can fight.");

    bm:callback(
        function()
            bm:remove_callback(callback_name)
            stopfight_unit(unit)
        end,
        time,
        callback_name
    )

    local start_fight_callback_name = tcs_battle.unit_callback_names["startfight"] .. unit:unique_ui_id()
    bm:callback(
        function()
            scrunit.uc:attack_unit(attack_target)
        end,
        500,
        start_fight_callback_name
    )
    bm:repeat_callback(
        function()
            if not scrunit:is_in_melee() then
                bm:remove_callback(start_fight_callback_name)
                tcs:log("Unit(" .. unit:unique_ui_id() .. ") not in melee; attacking again.");
                scrunit.uc:attack_unit(attack_target)
            end
        end,
        1000,
        start_fight_callback_name
    )

    bm:repeat_callback(function() decrease_unit_status_time(unit:unique_ui_id()) end, 1000, callback_name)
end

function stopshoot_unit(unit)
    local battle_unit_cco = tcs_get_battleunit_cco(unit:unique_ui_id())

    bm:remove_callback(tcs_battle.unit_callback_names["stopshoot"] .. unit:unique_ui_id());
    bm:remove_callback(tcs_battle.unit_callback_names["startshoot"] .. unit:unique_ui_id())

    local scrunit = bm:get_scriptunit_for_unit(unit);
    unit:disable_special_ability("tcs_main_unit_passive_inactive_shooting", false)

    disable_fire_at_will(unit)

    stop_scrunit(scrunit)

    tcs_battle.unit_actively_shooting[unit:unique_ui_id()] = nil
    tcs_battle:clear_unit_status(unit:unique_ui_id())
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can no longer shoot.");
end;

function unit_shoot(unit, time)
    if tcs_battle.unit_actively_shooting[unit:unique_ui_id()] then
        return
    end
    local callback_name = tcs_battle.unit_callback_names["stopshoot"] .. unit:unique_ui_id()
    bm:remove_callback(callback_name);

    local attack_target = tcs_battle.last_targeted_enemy_sunit.unit

    if not attack_target then
        tcs:log("Blocking shoot; target is not an enemy");
        enable_unit_shoot(unit)
        stopshoot_unit(unit)
        return
    end

    local unit_missile_range = get_unit_missile_range(unit)

    if not unit_missile_range then
        tcs:log("Blocking shoot; unit has no missile range.");
        stopshoot_unit(unit)
        tcs_battle:set_unit_status(unit:unique_ui_id(),
            string.format("idle.\nUnit has no missile weapon!"))
        return
    end

    local target_distance = unit:unit_distance(attack_target)
    tcs:log("Target distance: " .. target_distance);



    if target_distance > unit_missile_range then
        tcs:log("Blocking shoot; target is too far away");
        enable_unit_shoot(unit)
        stopshoot_unit(unit)
        tcs_battle:set_unit_status(unit:unique_ui_id(),
            string.format("idle.\nTarget out of missile range (%d/%d).", target_distance, unit_missile_range))
        return
    end

    -- TODO: Check for minimum distance?
    -- local unit_min_missile_range = ??
    -- if target_distance < unit_min_missile_range then
    --     tcs:log("Blocking shoot; target is within minimum range.");
    --     enable_unit_shoot(unit)
    --     stopshoot_unit(unit)
    --     tcs_battle:set_unit_status(unit:unique_ui_id(),
    --         string.format("idle.\nTarget within minimum missile range (%d/%d).", target_distance, unit_min_missile_range))
    --     return
    -- end

    unit:disable_special_ability("tcs_main_unit_passive_inactive_shooting", true)

    local scrunit = bm:get_scriptunit_for_unit(unit);
    scrunit:set_melee_mode(false, true)
    scrunit:take_control()

    tcs_battle.unit_actively_shooting[unit:unique_ui_id()] = true
    tcs_battle:set_unit_status(unit:unique_ui_id(), "shooting", time / 1000)
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can shoot.");

    bm:repeat_callback(
        function()
            decrease_unit_status_time(unit:unique_ui_id())
        end,
        1000,
        callback_name
    )

    bm:callback(
        function()
            stopshoot_unit(unit)
        end,
        time,
        callback_name
    )

    local start_shoot_callback_name = tcs_battle.unit_callback_names["startshoot"] .. unit:unique_ui_id()
    bm:callback(
        function()
            scrunit.uc:attack_unit(attack_target)
            if unit:missile_range() == 0 then
                scrunit.uc:fire_at_will(true)
            end
        end,
        500,
        start_shoot_callback_name
    )
    bm:repeat_callback(
        function()
            if not scrunit_is_firing_missiles(scrunit) then
                bm:remove_callback(start_shoot_callback_name)
                tcs:log("Unit(" .. unit:unique_ui_id() .. ") not firing missiles; attacking again.");
                scrunit.uc:attack_unit(attack_target)
            end
        end,
        1000,
        start_shoot_callback_name
    )
end

function unit_end_charge(unit)
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") ending charge.");
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
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") ended charging.");
end

function stopcharge_unit(unit, charge_target, overcharge_time, callback_name)
    local scrunit = bm:get_scriptunit_for_unit(unit);

    if unit:is_in_melee() then
        tcs:log("Unit (" .. unit:unique_ui_id() .. ") in melee.");
        tcs:log(string.format("Unit (%d) overcharging for %.2f seconds.", unit:unique_ui_id(), overcharge_time / 1000))

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
    tcs:log("Unit (" .. unit:unique_ui_id() .. ") not yet in melee.");
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
        tcs:log("Blocking charge; target is not an enemy");
        enable_unit_charge(unit)
        unit_end_charge(unit)
        return
    end

    local charge_target = tcs_battle.last_targeted_enemy_sunit.unit

    local charge_distance = unit:unit_distance(charge_target)
    tcs:log("Charge distance: " .. charge_distance);

    if charge_distance > tcs_battle.charge_range then
        tcs:log("Blocking charge; target is too far away");
        enable_unit_charge(unit)
        unit_end_charge(unit)
        tcs_battle:set_unit_status(unit:unique_ui_id(),
            string.format("idle.\nCharge target out of range (%d).", charge_distance))
        return
    end

    local diceroll = roll_dice(tcs:get_config("default_charge_dice"), tcs:get_config("default_dice_eyes"))
    local normalised_charge_distance = normalise_to_range(charge_distance, tcs_battle.charge_range)

    if not (diceroll >= normalised_charge_distance) then
        tcs:log("Blocking charge; the roll failed: " .. diceroll .. " / " .. normalised_charge_distance);
        unit_end_charge(unit)
        tcs_battle:set_unit_status(unit:unique_ui_id(),
            string.format("idle.\nCharge failed (%d/%.2f)", diceroll, normalised_charge_distance))
        return
    end

    local overcharge_time = ((diceroll - normalised_charge_distance) / (tcs:get_config("default_charge_dice") * tcs:get_config("default_dice_eyes"))) *
        tcs:get_config("overcharge_time") * 1000;

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
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") charging now.");

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
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can move freely.");

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
        tcs:log("Unit(" .. unit:unique_ui_id() .. ") still engaged.");
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
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") stopped retreating.");
end

function unit_retreat(unit, time)
    -- Maybe Use BattleEntity CCo DevSetCollisionRadius
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
    tcs_battle:set_unit_status(unit:unique_ui_id(), "retreating.")
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") is retreating.");
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

    tcs:log(string.format("Break testing Unit(%d) with morale %.2f", unit:unique_ui_id(), unit_cco:Call("MoralePercent")))

    if unit_cco:Call("MoralePercent") < (tcs:get_config("unit_break_point") / 100) then
        local unit_details_cco = unit_cco:Call("UnitDetailsContext")
        local unit_base_leadership = unit_details_cco:Call("BaseStatValueFromKey('stat_morale')")

        local diceroll = roll_dice(tcs:get_config("break_test_dice"), tcs:get_config("default_dice_eyes"))

        local breakpoint = normalise_to_range(unit_base_leadership, 100, tcs:get_config("break_test_dice"),
            tcs:get_config("default_dice_eyes"))

        tcs:log("Unit(" .. unit:unique_ui_id() .. ") rolled for breaking: " .. diceroll .. "/" .. breakpoint);

        if diceroll > breakpoint then
            tcs:log("Unit(" .. unit:unique_ui_id() .. ") broke");
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

function unit_reform(unit)
    if tcs_battle.unit_actively_moving[unit:unique_ui_id()] then
        return
    end
    local scrunit = bm:get_scriptunit_for_unit(unit);
    local callback_name = tcs_battle.unit_callback_names["stopmove"] .. unit:unique_ui_id()
    local engage_callback_name = tcs_battle.unit_callback_names["engage_check"] .. unit:unique_ui_id()

    bm:remove_callback(callback_name);
    bm:remove_callback(engage_callback_name)

    local destination = tcs_battle.last_clicked_position
    local destination_distance = get_unit_to_position_distance(unit, destination)

    if destination_distance > 1 then
        tcs:log("Distance (" .. destination_distance .. ") too far to pivot");
        tcs_battle:set_unit_status(unit:unique_ui_id(), "idle.\nDestination outside reform range.")
        bm:callback(
            function()
                tcs_battle:clear_unit_status(unit:unique_ui_id())
            end,
            3000
        )
        return
    end

    if not unit:can_reach_position(destination) then
        tcs:log("Can't reform at destination; unreachable.");
        tcs_battle:set_unit_status(unit:unique_ui_id(), "idle.\nCan't reach destination.")
        bm:callback(
            function()
                tcs_battle:clear_unit_status(unit:unique_ui_id())
            end,
            3000
        )
        return
    end

    if tcs_battle.unit_movement_range[scrunit.unit:unique_ui_id()] < tcs:get_config("unit_reform_cost") then
        tcs:log("Insufficient movement budget to reform.");
        tcs_battle:set_unit_status(unit:unique_ui_id(), "idle.\nNot enough movement to reform.")
        bm:callback(
            function()
                tcs_battle:clear_unit_status(unit:unique_ui_id())
            end,
            3000
        )
        return
    end

    unit:disable_special_ability("tcs_main_unit_passive_stationary", true)
    tcs_battle.unit_actively_moving[unit:unique_ui_id()] = true

    scrunit:take_control()

    tcs_battle:set_unit_status(unit:unique_ui_id(), "reforming.")
    tcs:log("Unit(" .. unit:unique_ui_id() .. ") can reform.");

    -- Allow user to reform unit at cost of arbitrary amount of movement.
    tcs_battle.unit_movement_range[scrunit.unit:unique_ui_id()] = tcs_battle.unit_movement_range
        [scrunit.unit:unique_ui_id()] - tcs:get_config("unit_reform_cost")


    bm:repeat_callback(
        function()
            if not unit_entities_in_range(unit, destination, 5) then
                bm:remove_callback(callback_name)
                bm:callback(
                    function()
                        freeze_unit(unit)
                    end,
                    500
                )
                return
            end
            tcs:log("Unit(" ..
                unit:unique_ui_id() .. ") distance to reform: " .. unit:position():distance_xz(destination))
        end,
        500,
        callback_name
    )
    bm:repeat_callback(
        function()
            if not unit:is_moving() then
                tcs:log("Unit(" .. unit:unique_ui_id() .. ") stopped reforming.")
                bm:remove_callback(callback_name)
                bm:callback(
                    function()
                        freeze_unit(unit)
                    end,
                    500
                )
                return
            end
            tcs:log("Unit(" .. unit:unique_ui_id() .. ") still reforming.")
        end,
        5000,
        callback_name
    )
    bm:repeat_callback(
        function()
            tcs:log("Unit(" .. unit:unique_ui_id() .. ") reform timed out.")
            bm:remove_callback(callback_name)
            bm:callback(
                function()
                    freeze_unit(unit)
                end,
                500
            )
        end,
        25000,
        callback_name
    )

    bm:repeat_callback(
        function()
            freeze_unit_in_engagement_range(scrunit)
        end,
        500,
        engage_callback_name
    )
end
