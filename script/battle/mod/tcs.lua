-- TODO: Unglobal these; for dev purpose only
tcs = core:get_static_object("tcs");
tcs_battle = core:get_static_object("tcs_battle");

-----------------------------------------------------
-- BATTLE TEST SCRIPTS
-----------------------------------------------------

function get_next_alliance_index(index)
    index = index or tcs_battle.active_player_alliance_index
    local next_index = math.fmod(index + 1, bm:alliances():count())

    if next_index == 0 then
        return bm:alliances():count()
    end
    return next_index
end

function active_player_alliance()
    return bm:alliances():item(tcs_battle.active_player_alliance_index)
end

function disable_non_passives(unit, bool)
    if bool == nil then
        bool = true
    end
    for key, ability in pairs(unit:owned_non_passive_special_abilities()) do
        if not table.contains(tcs_battle.unit_activations, ability) then
            unit:disable_special_ability(ability, bool)
        end
    end
end

function disable_tcs_passives(unit, time)
    for key, ability in pairs(tcs_battle.unit_passives) do
        unit:disable_special_ability(ability, true)
    end
end

function disable_tcs_actives(unit)
    for key, ability in pairs(tcs_battle.unit_activations) do
        unit:disable_special_ability(ability, true)
    end
end

function enable_tcs_passives(unit, time)
    for key, ability in pairs(tcs_battle.unit_passives) do
        unit:disable_special_ability(ability, false)
    end
end

function enable_non_passives(unit, time)
    for key, ability in pairs(unit:owned_non_passive_special_abilities()) do
        unit:disable_special_ability(ability, false)
    end

    bm:callback(
        function()
            disable_non_passives(unit)
        end,
        time
    )
end

function tag_active(unit)
    tcs_battle.active_units[unit] = true
end

function cleanup_inactive_units()
    local activity_tables = {
        { units = tcs_battle.ai_actively_shooting,     status = "shooting (AI)" },
        { units = tcs_battle.ai_actively_moving,       status = "moving (AI)" },
        { units = tcs_battle.ai_actively_charging,     status = "charging (AI)" },
        { units = tcs_battle.ai_actively_fighting,     status = "fighting (AI)" },
        { units = tcs_battle.ai_actively_retreating,   status = "retreating (AI)" },
        { units = tcs_battle.unit_actively_moving,     status = "moving" },
        { units = tcs_battle.unit_actively_fighting,   status = "fighting" },
        { units = tcs_battle.unit_actively_shooting,   status = "shooting" },
        { units = tcs_battle.unit_actively_charging,   status = "charging" },
        { units = tcs_battle.unit_actively_retreating, status = "retreating" },
    }
    for unit, _ in pairs(tcs_battle.active_units) do
        if unit:number_of_men_alive() == 0 then
            tcs:log("Cleaning up unit: " .. unit:unique_ui_id());
            tcs_battle.active_units[unit] = nil

            for key, callback_name in pairs(tcs_battle.unit_callback_names) do
                bm:remove_callback(callback_name .. unit:unique_ui_id())
            end
            for _, activity_table in pairs(activity_tables) do
                activity_table.units[unit:unique_ui_id()] = nil
            end
        end
    end
end

function cleanup_all_units()
    local activity_tables = {
        { units = tcs_battle.ai_actively_shooting,     status = "shooting (AI)" },
        { units = tcs_battle.ai_actively_moving,       status = "moving (AI)" },
        { units = tcs_battle.ai_actively_charging,     status = "charging (AI)" },
        { units = tcs_battle.ai_actively_fighting,     status = "fighting (AI)" },
        { units = tcs_battle.ai_actively_retreating,   status = "retreating (AI)" },
        { units = tcs_battle.unit_actively_moving,     status = "moving" },
        { units = tcs_battle.unit_actively_fighting,   status = "fighting" },
        { units = tcs_battle.unit_actively_shooting,   status = "shooting" },
        { units = tcs_battle.unit_actively_charging,   status = "charging" },
        { units = tcs_battle.unit_actively_retreating, status = "retreating" },
    }
    for unit, _ in pairs(tcs_battle.active_units) do
        tcs:log("Cleaning up unit: " .. unit:unique_ui_id());
        tcs_battle.active_units[unit] = nil

        for key, callback_name in pairs(tcs_battle.unit_callback_names) do
            bm:remove_callback(callback_name .. unit:unique_ui_id())
        end
        for _, activity_table in pairs(activity_tables) do
            activity_table.units[unit:unique_ui_id()] = nil
        end
    end
end

function fix_ai_shooting()
    for alliance = 1, bm:alliances():count() do
        local army_alliance = bm:alliances():item(alliance);
        for army = 1, army_alliance:armies():count() do
            local units_army = army_alliance:armies():item(army);
            for unit_id = 1, units_army:units():count() do
                local unit = units_army:units():item(unit_id);
                if units_army:is_player_controlled() then
                    unit:disable_special_ability("tcs_ai_unit_passive_ranged_fix", true)
                else
                    unit:disable_special_ability("tcs_ai_unit_passive_ranged_fix", true)
                    local scrunit = bm:get_scriptunit_for_unit(unit);
                    scrunit:grant_infinite_ammo();
                end
            end
        end
    end
end

function disable_spell_effects(unit)
    disable_non_passives(unit, true)
    bm:callback(
        function()
            disable_non_passives(unit, false)
        end,
        500
    )
end

function normalise_stat_to_range(unit_stat, maximum_stat_value, minium_range, maximum_range)
    return (unit_stat / maximum_stat_value) * (maximum_range - minium_range) + minium_range
end

function set_unit_movement(unit)
    local unit_cco = tcs_get_battleunit_cco(unit:unique_ui_id())
    if not unit_cco then
        return
    end
    local unit_details_cco = unit_cco:Call("UnitDetailsContext")

    local unit_speed = unit_details_cco:Call("StatContextFromKey('scalar_speed').Value")
    local movement_range = normalise_stat_to_range(unit_speed, tcs:get_config("max_unit_speed"),
        tcs:get_config("min_movement_range"), tcs:get_config("max_movement_range"))
    tcs_battle.unit_movement_range[unit:unique_ui_id()] = movement_range
end

function has_missile_spell(unit)
    local unit_cco = tcs_get_battleunit_cco(unit:unique_ui_id())
    if not unit_cco then
        return false
    end

    for i = 1, unit_cco:Call("BattleAbilityList.Size") do
        local ability_cco = unit_cco:Call("BattleAbilityList")[i]
        if not table.contains(tcs_battle.unit_activations, ability_cco:Call("SetupAbilityContext.RecordKey")) and
            ability_cco:Call("IsTargettedAbility") then
            return true
        end
    end

    return false
end

function has_unit_in_missile_range(scrunit)
    for _, enemy_scrunit in pairs(get_enemy_scrunits(scrunit):get_sunit_table()) do
        if scrunit.unit:unit_in_range(enemy_scrunit.unit) then
            return true
        end
    end
    return false
end

function get_unit_missile_range(unit)
    local unit_cco = tcs_get_battleunit_cco(unit:unique_ui_id())
    if not unit_cco then
        return
    end
    local unit_details_cco = unit_cco:Call("UnitDetailsContext")

    return unit_details_cco:Call("StatContextFromKey('scalar_missile_range').Value")
end

function enable_melee_attacks(unit)
    unit:set_stat_attribute("melee_disabled", false)
    --     TODO: Only enable non splash attackers?
    --     if tcs_splash_units[ai_unit:type()] then
    --         ai_unit:set_stat_attribute("melee_disabled", false)
    --     end
end

function disable_melee_attacks(unit)
    unit:set_stat_attribute("melee_disabled", true)
    --     TODO: Only disable splash attackers?
    --     if tcs_splash_units[ai_unit:type()] then
    --         ai_unit:set_stat_attribute("melee_disabled", true)
    --     end
end

function enable_missile_attacks(unit)
    unit:set_stat_attribute("shoot_disabled", false)
    --     TODO: Only enable non splash attackers?
    --     if tcs_splash_units[ai_unit:type()] then
    --         ai_unit:set_stat_attribute("melee_disabled", false)
    --     end
end

function disable_missile_attacks(unit)
    unit:set_stat_attribute("shoot_disabled", true)
    --     TODO: Only enable non splash attackers?
    --     if tcs_splash_units[ai_unit:type()] then
    --         ai_unit:set_stat_attribute("melee_disabled", false)
    --     end
end

function enable_morale(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit)
    scrunit:morale_behavior_default()
    scrunit:hide_unbreakable_in_ui(false)
end

function disable_morale(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit)
    scrunit:morale_behavior_fearless()
    scrunit:hide_unbreakable_in_ui(true)
end

function enable_unit_move(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    if not tcs_battle.unit_retreated[unit:unique_ui_id()] and not scrunit_is_engaged(scrunit) then
        unit:disable_special_ability("tcs_main_unit_active_move", false)
    end
end

function enable_unit_shoot(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    if (not tcs_battle.unit_ran[unit:unique_ui_id()] or unit:has_attribute("mounted_fire_move")) and not tcs_battle.unit_retreated[unit:unique_ui_id()] then
        scrunit.uc:reset_ability_number_of_uses("tcs_main_unit_active_shoot")
        unit:disable_special_ability("tcs_main_unit_active_shoot", false)
    end
end

function enable_unit_fight(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    if scrunit_is_engaged(scrunit) and not tcs_battle.unit_retreated[unit:unique_ui_id()] then
        scrunit.uc:reset_ability_number_of_uses("tcs_main_unit_active_fight")
        unit:disable_special_ability("tcs_main_unit_active_fight", false)
    end
end

function enable_unit_charge(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    if not scrunit_is_engaged(scrunit) and not tcs_battle.unit_ran[unit:unique_ui_id()] and not tcs_battle.unit_retreated[unit:unique_ui_id()] then
        scrunit.uc:reset_ability_number_of_uses("tcs_main_unit_active_charge")
        unit:disable_special_ability("tcs_main_unit_active_charge", false)
    end
end

function enable_unit_retreat(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    if not tcs_battle.unit_retreated[unit:unique_ui_id()] and scrunit_is_engaged(scrunit) then
        local scrunit = bm:get_scriptunit_for_unit(unit);
        scrunit.uc:reset_ability_number_of_uses("tcs_main_unit_active_retreat")
        unit:disable_special_ability("tcs_main_unit_active_retreat", false)
    end
end

function enable_unit_run(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    if not tcs_battle.unit_retreated[unit:unique_ui_id()] and not scrunit_is_engaged(scrunit) then
        local scrunit = bm:get_scriptunit_for_unit(unit);
        scrunit.uc:reset_ability_number_of_uses("tcs_main_unit_active_run")
        unit:disable_special_ability("tcs_main_unit_active_run", false)
    end
end

function enable_unit_reform(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    if not tcs_battle.unit_retreated[unit:unique_ui_id()] and not scrunit_is_engaged(scrunit) then
        unit:disable_special_ability("tcs_main_unit_active_reform", false)
    end
end

function stop_scrunit(scrunit)
    scrunit:take_control()
    scrunit:halt();
    scrunit:taunt();
    scrunit:release_control()

    bm:callback(
        function()
            scrunit:take_control()
            scrunit:halt();
            scrunit:taunt();
            scrunit:release_control()
        end,
        500
    )
end

function stop_unit(unit)
    -- TODO: stop_sound() use this to prevent the halt sound?
    local scrunit = bm:get_scriptunit_for_unit(unit)
    scrunit:take_control()
    scrunit:halt();
    scrunit:taunt();
    scrunit:release_control()

    bm:callback(
        function()
            scrunit:take_control()
            scrunit:halt();
            scrunit:taunt();
            scrunit:release_control()
        end,
        500
    )
end

function land_unit(unit)
    if not tcs_battle.unit_should_land[unit:unique_ui_id()] then
        bm:remove_callback(tcs_battle.unit_callback_names["landunit"] .. unit:unique_ui_id())
        return
    end

    if not unit:is_currently_flying() then
        tcs:log(string.format("Unit (%d) is currently not flying.", unit:unique_ui_id()));
        return
    end

    local unit_cco = tcs_get_battleunit_cco(unit:unique_ui_id())
    if not unit_cco then
        return
    end

    if not unit_cco:Call("CanToggleFlying") then
        tcs:log(string.format("Unit (%d) cannot toggle not flying now.", unit:unique_ui_id()));
        return
    end

    unit_cco:Call("ToggleFlying")
    bm:remove_callback(tcs_battle.unit_callback_names["landunit"] .. unit:unique_ui_id())
    tcs_battle.unit_should_land[unit:unique_ui_id()] = nil
end

function disable_unit_activations(unit)
    for key, ability in pairs(tcs_battle.unit_activations) do
        unit:disable_special_ability(ability, true)
    end
end

function lua_split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

function enable_formed_attack(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit)
    unit:set_stat_attribute("formed_attack", true)
    scrunit:change_behaviour_active("formed_attack", true)
end

function disable_formed_attack(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit)
    -- TODO: Exclude Cathay attribute groups
    unit:set_stat_attribute("formed_attack", false)
    scrunit:change_behaviour_active("formed_attack", false)
end

function roll_dice(n, eyes)
    local diceroll = 0;
    for i = 1, n do
        diceroll = diceroll + math.ceil(bm:random_number() * eyes)
    end
    return diceroll
end

function normalise_to_range(target, range, number_of_dice, size_of_dice)
    number_of_dice = number_of_dice or 2
    size_of_dice = size_of_dice or tcs:get_config("default_dice_eyes")
    check = (((target - (range / size_of_dice)) / (range - (range / size_of_dice))) * ((number_of_dice * size_of_dice) - number_of_dice)) +
        number_of_dice

    return check
end

function scrunit_is_currently_flying(scrunit)
    return scrunit.unit:is_currently_flying()
end

function scrunit_is_currently_grounded(scrunit)
    return not scrunit_is_currently_flying(scrunit)
end

function get_enemy_scrunits_to_local_player()
    local scrunits = script_units:new("enemy_scrunits")
    for army = 1, bm:alliances():item(get_next_alliance_index(bm:local_alliance())):armies():count() do
        local battle_army = bm:alliances():item(get_next_alliance_index(bm:local_alliance())):armies():item(army)
        for unit_id = 1, battle_army:units():count() do
            local unit = battle_army:units():item(unit_id);
            if unit:number_of_men_alive() > 0 then
                scrunits:add_sunits(bm:get_scriptunit_for_unit(unit))
            end
        end
    end
    return scrunits
end

function get_enemy_scrunits(scrunit, match_y_axis)
    local scrunits = script_units:new("enemy_scrunits")

    for army = 1, bm:alliances():item(get_next_alliance_index(scrunit.unit:alliance_index())):armies():count() do
        local battle_army = bm:alliances():item(get_next_alliance_index(scrunit.unit:alliance_index())):armies():item(
        army)
        for unit_id = 1, battle_army:units():count() do
            local unit = battle_army:units():item(unit_id);
            if unit:number_of_men_alive() > 0 then
                scrunits:add_sunits(bm:get_scriptunit_for_unit(unit))
            end
        end
    end

    if match_y_axis then
        if scrunit.unit:is_currently_flying() then
            scrunits = scrunits:filter("enemy_scrunits", scrunit_is_currently_flying)
        else
            scrunits = scrunits:filter("enemy_scrunits", scrunit_is_currently_grounded)
        end
    end

    return scrunits:filter("enemy_scrunits", scrunit_is_alive)
end

function reachable_enemy_scrunits(scrunit)
    return get_enemy_scrunits(scrunit, not scrunit.unit:is_currently_flying())
end

function nearest_enemy_at_ai_destination(scrunit)
    scrunit:cache_destination()
    if not scrunit:get_cached_destination_position() then
        return nil
    end

    local enemy_scrunits = reachable_enemy_scrunits(scrunit)

    return enemy_scrunits:item(get_nearest(scrunit:get_cached_destination_position(), enemy_scrunits))
end

function scrunit_is_alive(scrunit)
    return scrunit.unit:number_of_men_alive() > 0
end

function nearest_enemy(scrunit, reachable)
    -- TODO: look into get_closest_unit with extra checks
    -- get_closest_standing_unit(object unit collection, vector position, [function additional test])
    reachable = reachable or true

    local enemy_scrunits = reachable_enemy_scrunits(scrunit):filter("nearest_enemies", scrunit_is_alive)

    if enemy_scrunits:count() == 0 then
        return nil
    end

    return enemy_scrunits:item(get_nearest(scrunit.unit:position(), enemy_scrunits))
end

function nearest_flying_enemy(scrunit)
    local enemy_scrunits = reachable_enemy_scrunits(scrunit):filter("nearest_enemies", scrunit_is_alive):filter(
        "nearest_enemies", scrunit_is_currently_flying)
    if enemy_scrunits:count() == 0 then
        return nil
    end
    return enemy_scrunits:item(get_nearest(scrunit.unit:position(), enemy_scrunits))
end

function filter_scrunits_by_unit_distance(name, scrunit, scrunits, distance)
    local filtered_scrunits = script_units:new(name)
    for _, other in pairs(scrunits:get_sunit_table()) do
        if scrunit.unit:unit_distance(other.unit) < distance then
            filtered_scrunits:add_sunits(other)
        end
    end
    return filtered_scrunits
end

function filter_scrunits_by_point_distance(name, position, scrunits, distance)
    local filtered_scrunits = script_units:new(name)
    for _, other in pairs(scrunits:get_sunit_table()) do
        if position:distance_xz(other.unit:position()) < distance then
            filtered_scrunits:add_sunits(other)
        end
    end
    return filtered_scrunits
end

function unit_entity_distances(unit, destination)
    local unit_cco = tcs_get_battleunit_cco(unit:unique_ui_id())

    local unit_entities = unit_cco:Call("ManList")

    local distances = {}

    for i = 1, unit_cco:Call("ManList.Size") do
        local entity = unit_entities[i]
        local position = battle_vector:new(
            entity:Call("Position.x"),
            entity:Call("Position.y"),
            entity:Call("Position.z")
        )
        table.insert(distances, { entity = entity, distance = position:distance_xz(destination) })
    end

    return distances
end

function unit_entity_min_distance(unit, destination)
    local entity_distances = unit_entity_distances(unit, destination)
    table.sort(entity_distances, function(a, b) return a.distance < b.distance end)
    local closest_entity_distance = entity_distances[1]
    return closest_entity_distance.distance, closest_entity_distance.entity
end

function unit_entities_in_range(unit, destination, distance)
    local unit_cco = tcs_get_battleunit_cco(unit:unique_ui_id())

    local unit_entities = unit_cco:Call("ManList")

    for i = 1, unit_cco:Call("ManList.Size") do
        local entity = unit_entities[i]
        local position = battle_vector:new(
            entity:Call("Position.x"),
            entity:Call("Position.y"),
            entity:Call("Position.z")
        )
        if position:distance_xz(destination) < distance then
            return true
        end
    end
    return false
end

function position_in_range(scrunit, destination, distance, flying_only)
    flying_only = flying_only or false
    local near_enemies = filter_scrunits_by_point_distance("nearest_enemies", destination,
        reachable_enemy_scrunits(scrunit), distance + 30)
    if flying_only then
        near_enemies = near_enemies:filter("nearest_enemies", scrunit_is_currently_flying)
    end

    for _, enemy_scrunit in pairs(near_enemies:get_sunit_table()) do
        if unit_entities_in_range(enemy_scrunit.unit, destination, distance) then
            return true
        end
    end

    return false
end

function scrunit_has_enemy_unit_in_range(scrunit, distance, match_y_axis)
    flying_only = flying_only or false
    local scrunits = get_enemy_scrunits(scrunit, match_y_axis)

    for _, enemy_scrunit in pairs(scrunits:get_sunit_table()) do
        if scrunit.unit:unit_distance(enemy_scrunit.unit) < distance then
            return true, enemy_scrunit
        end
    end

    return false, nil
end

function scrunit_is_engaged(scrunit, offset)
    offset = offset or 0
    return scrunit_has_enemy_unit_in_range(scrunit, tcs_battle.engagement_distance + offset, true)
end

function perform_next_phase()
    mapf_to_all_units(stop_unit)
    bm:alliances():item(bm:local_alliance()):armies():item(bm:local_army()):use_special_ability("tcs_next_phase",
        battle_vector:new())
end

function mapf_to_first_unit_context(func, ability)
    local scrunit = get_first_selected_unit('sunit')

    if not scrunit then
        return
    end

    if scrunit.unit:can_perform_special_ability(ability) then
        local battle_ability = get_unit_battle_ability_cco(scrunit.unit, ability)
        if battle_ability and battle_ability:Call("CurrentState") == "selected" then
            func(scrunit.unit)
        end
    end
end

function mapf_to_selected_units(func, time, ability)
    local time = time or nil;
    tcs:log("Selected units:");
    for k, v in pairs(tcs_battle.selected_units) do
        tcs:log(k .. ":" .. v:type());
    end
    for unit_id, unit in pairs(tcs_battle.selected_units) do
        if unit:can_perform_special_ability(ability) then
            local battle_ability = get_unit_battle_ability_cco(unit, ability)
            if battle_ability and battle_ability:Call("CurrentState") == "selected" then
                func(unit, time);
            end
        end
    end
end

function mapf_to_local_player_scrunits(func)
    local time = time or nil;
    for army = 1, bm:alliances():item(bm:local_alliance()):armies():count() do
        local battle_army = bm:alliances():item(bm:local_alliance()):armies():item(army)
        for unit_id = 1, battle_army:units():count() do
            local scrunit = get_sunit_by_id(battle_army:units():item(unit_id):unique_ui_id())
            if scrunit.unit:number_of_men_alive() > 0 then
                func(scrunit, time)
            end
        end
    end
end

function mapf_to_local_player_units(func, time)
    local time = time or nil;
    for army = 1, bm:alliances():item(bm:local_alliance()):armies():count() do
        local battle_army = bm:alliances():item(bm:local_alliance()):armies():item(army)
        for unit_id = 1, battle_army:units():count() do
            local unit = battle_army:units():item(unit_id);
            if unit:number_of_men_alive() > 0 then
                func(unit, time)
            end
        end
    end
end

function mapf_to_active_player_units(func, time)
    local time = time or nil;
    for army = 1, active_player_alliance():armies():count() do
        local battle_army = active_player_alliance():armies():item(army);
        for unit_id = 1, battle_army:units():count() do
            local unit = battle_army:units():item(unit_id);
            if unit:number_of_men_alive() > 0 then
                func(unit, time)
            end
        end
    end
end

function mapf_to_ai_units(func, time)
    local time = time or nil;
    for alliance = 1, bm:alliances():count() do
        if not (alliance == bm:local_alliance()) then
            local ai_alliance = bm:alliances():item(alliance);
            for army = 1, ai_alliance:armies():count() do
                local ai_army = ai_alliance:armies():item(army);
                if not (ai_army:is_player_controlled()) then
                    for unit_id = 1, ai_army:units():count() do
                        local ai_unit = ai_army:units():item(unit_id);
                        if ai_unit:number_of_men_alive() > 0 then
                            func(ai_unit, time)
                        end
                    end
                end
            end
        end
    end
end

function mapf_to_all_units(func, time)
    if bm:is_multiplayer() then
        mapf_to_local_player_units(func, time)
        return
    end

    local time = time or nil;
    for alliance = 1, bm:alliances():count() do
        local army_alliance = bm:alliances():item(alliance);
        for army = 1, army_alliance:armies():count() do
            local units_army = army_alliance:armies():item(army);
            for unit_id = 1, units_army:units():count() do
                local ai_unit = units_army:units():item(unit_id);
                if ai_unit:number_of_men_alive() > 0 then
                    func(ai_unit, time)
                end
            end
        end
    end
end

function mapf_to_all_scrunits(func)
    if bm:is_multiplayer() then
        mapf_to_local_player_scrunits(func)
        return
    end
    for alliance = 1, bm:alliances():count() do
        local army_alliance = bm:alliances():item(alliance);
        for army = 1, army_alliance:armies():count() do
            local units_army = army_alliance:armies():item(army);
            for unit_id = 1, units_army:units():count() do
                local unit = units_army:units():item(unit_id);

                func(bm:get_scriptunit_for_unit(unit))
            end
        end
    end
end

function disable_fire_at_will(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit)
    scrunit.uc:fire_at_will(false)
end

function any_units_moving(scrunits)
    for k, unit in pairs(scrunits:get_unit_table()) do
        if unit:is_moving() then
            return true
        end
    end
    return false
end

function any_units_in_melee(scrunits)
    for k, unit in pairs(scrunits:get_unit_table()) do
        if unit:is_in_melee() then
            return true
        end
    end
    return false
end

function any_units_vulnerable(scrunits)
    for k, unit in pairs(scrunits:get_unit_table()) do
        if not tcs_get_battleunit_cco(unit:unique_ui_id()):Call("IsInvincible") then
            return true
        end
    end
    return false
end

function any_units_under_fire(scrunits)
    for k, unit in pairs(scrunits:get_unit_table()) do
        if tcs_get_battleunit_cco(unit:unique_ui_id()):Call("IsUnderMissileAttack") then
            return true
        end
    end
    return false
end

function scrunit_is_firing_missiles(scrunit)
    return tcs_get_battleunit_cco(scrunit.unit:unique_ui_id()):Call("IsFiringMissiles")
end

function any_units_firing_missile(scrunits)
    for k, scrunit in pairs(scrunits:get_sunit_table()) do
        if scrunit_is_firing_missiles(scrunit) then
            return true
        end
    end
    return false
end

function any_unit_still_active()
    local activity_tables = {
        { units = tcs_battle.ai_actively_shooting,     status = "shooting (AI)" },
        { units = tcs_battle.ai_actively_moving,       status = "moving (AI)" },
        { units = tcs_battle.ai_actively_charging,     status = "charging (AI)" },
        { units = tcs_battle.ai_actively_fighting,     status = "fighting (AI)" },
        { units = tcs_battle.ai_actively_retreating,   status = "retreating (AI)" },
        { units = tcs_battle.unit_actively_moving,     status = "moving" },
        { units = tcs_battle.unit_actively_fighting,   status = "fighting" },
        { units = tcs_battle.unit_actively_shooting,   status = "shooting" },
        { units = tcs_battle.unit_actively_charging,   status = "charging" },
        { units = tcs_battle.unit_actively_retreating, status = "retreating" },
    }

    for _, activity_table in pairs(activity_tables) do
        local active_unit = next(activity_table.units)
        if active_unit then
            tcs:log("Unit(" .. active_unit .. ") still actively :" .. activity_table.status);
            return active_unit, activity_table.status
        end
    end
    return nil, nil
end

local function switch(x, cases)
    local match = cases[x] or cases.default or function() end

    return match()
end

function unit_entity_count(unit)
    local unit_cco = tcs_get_battleunit_cco(unit:unique_ui_id())
    if not unit_cco then
        return nil
    end

    return unit_cco:Call("EntityList.Size")
end

function tcs_get_battleunit_cco(unit_uid)
    local battle_root_cco = cco("CcoBattleRoot", 1);
    local unit_list = battle_root_cco:Call("UnitList");
    for i = 1, battle_root_cco:Call("UnitList.Size") do
        if unit_uid == unit_list[i]:Call("UniqueUiId") then
            return unit_list[i];
        end
    end
    return nil
end

function get_selected_unit_ability_cco(ability_record)
    local unit_cco = get_first_selected_unit('cco')

    if not unit_cco then
        return
    end

    for i = 1, unit_cco:Call("AbilityList.Size") do
        if unit_cco:Call("AbilityList")[i]:Call("RecordKey") == ability_record then
            return unit_cco:Call("AbilityList")[i]
        end
    end

    return nil
end

---@type (script_unit | nil)
function get_sunit_by_id(uid)
    for alliance = 1, bm:alliances():count() do
        local army_alliance = bm:alliances():item(alliance);
        for army = 1, army_alliance:armies():count() do
            local units_army = army_alliance:armies():item(army);
            for unit_id = 1, units_army:units():count() do
                local unit = units_army:units():item(unit_id);
                if unit:unique_ui_id() == uid then
                    return bm:get_scriptunit_for_unit(unit)
                end
            end
        end
    end
    return nil
end

function get_unit_by_id(uid)
    for alliance = 1, bm:alliances():count() do
        local army_alliance = bm:alliances():item(alliance);
        for army = 1, army_alliance:armies():count() do
            local units_army = army_alliance:armies():item(army);
            for unit_id = 1, units_army:units():count() do
                local ai_unit = units_army:units():item(unit_id);
                if ai_unit:unique_ui_id() == uid then
                    return ai_unit
                end
            end
        end
    end
    return nil
end

function get_unit_battle_ability_cco(unit, ability_record)
    local unit_cco = cco("CcoBattleUnit", unit:unique_ui_id())

    for i = 1, unit_cco:Call("BattleAbilityList.Size") do
        if unit_cco:Call("BattleAbilityList")[i]:Call("SetupAbilityContext.RecordKey") == ability_record then
            return unit_cco:Call("BattleAbilityList")[i]
        end
    end

    return nil
end

function terminate_tcs()
    mapf_to_all_units(disable_tcs_passives)
    mapf_to_all_units(disable_tcs_actives)
    mapf_to_all_units(enable_melee_attacks)
    mapf_to_all_units(enable_morale)

    bm:unregister_command_handler_callback("Special Ability", "tcs_special_ability_handler")
    bm:unregister_unit_selection_handler()

    local function remove_unit_callbacks(unit)
        for _, callback in pairs(tcs_battle.unit_callback_names) do
            bm:remove_real_callback(callback .. unit:unique_ui_id())
        end
    end

    mapf_to_all_units(remove_unit_callbacks)

    for _, callback in pairs(tcs_battle.real_callback_names) do
        bm:remove_real_callback(callback)
    end

    cleanup_all_units()

    remove_phase_controls()

    show_ai_controls(false)

    local parent = core:get_ui_root()
    local army_ability_parent = find_uicomponent(parent, "hud_battle", "army_ability_container", "army_ability_parent")

    local army_ability_component = find_uicomponent(army_ability_parent, "button_holder_tcs_terminate_simulation")
    if army_ability_component then
        army_ability_component:SetVisible(false)
    end

    for key, listener_name in pairs(tcs_battle.listener_names) do
        core:remove_listener(listener_name)
    end
end

function get_unit_to_position_distance(unit, position)
    return math.floor(unit_entity_min_distance(unit, position))
end

function setup_tcs_units(unit)
    if not unit then
        mapf_to_ai_units(disable_non_passives);
        mapf_to_all_units(disable_fire_at_will);
        mapf_to_all_units(disable_melee_attacks)
        mapf_to_all_units(disable_morale)
        mapf_to_all_units(set_unit_movement)

        if tcs:get_config("force_formed_attack") then
            mapf_to_all_units(enable_formed_attack)
        else
            mapf_to_all_units(disable_formed_attack)
        end
    else
        disable_tcs_actives(unit)
        disable_non_passives(unit);
        disable_fire_at_will(unit);
        disable_melee_attacks(unit);
        disable_morale(unit);
        set_unit_movement(unit);

        if tcs:get_config("force_formed_attack") then
            enable_formed_attack(unit)
        else
            disable_formed_attack(unit)
        end
    end
end

-- Test scripts placed here will be called when the battle script environment is started - this happens
-- right at the end of the loading sequence in to any battle
function battle_startup_test_scripts_here()
    tcs:log("*** tcs script loaded - Tabletop Combat Simulator engaged. ***\n\n");

    function tcs_active_unit_handler(unit, is_selected)
        if is_selected then
            -- track selected units
            -- tcs:log("Selected: " .. unit:unique_ui_id() .. ":" .. unit:type());
            tcs_battle.selected_units[unit:unique_ui_id()] = unit;
        else
            -- track unselected units
            -- tcs:log("Unselected: " .. unit:unique_ui_id() .. ":" .. unit:type());
            tcs_battle.selected_units[unit:unique_ui_id()] = nil;
        end
    end

    bm:register_unit_selection_handler("tcs_active_unit_handler")

    function tcs_special_ability_handler(event)
        local event_name = event:get_name()

        if not (event_name == "Special Ability") then
            return
        end

        local cases = {
            default = function() return end,
            tcs_main_unit_active_fight = function()
                mapf_to_selected_units(unit_fight,
                    tcs:get_config("fight_time") * 1000, "tcs_main_unit_active_fight")
            end,
            tcs_main_unit_active_move = function()
                -- Only move the first selected unit. Maybe later move all as one UC?
                mapf_to_first_unit_context(unit_move, "tcs_main_unit_active_move")
            end,
            tcs_main_unit_active_shoot = function()
                mapf_to_selected_units(unit_shoot,
                    tcs:get_config("shoot_time") * 1000, "tcs_main_unit_active_shoot")
            end,
            tcs_main_unit_active_charge = function()
                mapf_to_selected_units(unit_charge, nil,
                    "tcs_main_unit_active_charge")
            end,
            tcs_main_unit_active_retreat = function()
                mapf_to_selected_units(unit_retreat,
                    tcs:get_config("retreat_time") * 1000, "tcs_main_unit_active_retreat")
            end,
            tcs_main_unit_active_run = function()
                mapf_to_selected_units(unit_run, nil,
                    "tcs_main_unit_active_run")
            end,
            tcs_main_unit_active_reform = function()
                mapf_to_first_unit_context(unit_reform, "tcs_main_unit_active_reform")
            end,
            tcs_army_ai_move = function()
                mapf_to_ai_units(ai_unit_move, tcs:get_config("ai_move_time") * 1000);
            end,
            tcs_army_ai_fight = function()
                mapf_to_ai_units(ai_unit_fight, tcs:get_config("ai_fight_time") * 1000);
            end,
            tcs_army_ai_shoot = function()
                mapf_to_ai_units(ai_unit_shoot, tcs:get_config("ai_shoot_time") * 1000);
            end,
            tcs_army_ai_charge = function() mapf_to_ai_units(ai_unit_charge) end,
            tcs_army_ai_hero = function() mapf_to_ai_units(enable_non_passives, tcs:get_config("ai_hero_time") * 1000) end,
            tcs_next_phase = function() core:trigger_custom_event("tcs_next_phase", {}) end,
            tcs_terminate_simulation = function() terminate_tcs() end,
        }

        local ability_name = event:get_string1();
        tcs:log("Ability used: " .. ability_name);

        switch(ability_name, cases)
    end

    bm:register_command_handler_callback("Special Ability", tcs_special_ability_handler, "tcs_special_ability_handler")
end;

-- Test scripts placed here will be called in battle when deployment phase commences
function battle_deployment_test_scripts_here()
    tcs:clear_log();
    tcs:log("Battle Deployment started.");

    if bm:is_multiplayer() or not tcs:get_config("enable_ai_controls") then
        show_ai_controls(false)
    end

    fix_ai_shooting();

    setup_tcs_units()

    tcs_battle.active_player_alliance_index = bm:random_number(1, 2);

    setup_phase_controls()
    set_active_crest()

    if tcs:get_config("simultaneous_turns") then
        set_title_message("Simultaneous Turns")
    else
        if tcs_battle.active_player_alliance_index == bm:local_alliance() then
            set_title_message("You Go First")
        else
            set_title_message("You Go Second")
        end
    end
end;

function battle_conflict_test_scripts_here()
    tcs:log("Battle Deployment done; combat starting.");

    core:trigger_custom_event('button_hero_phase', {})

    bm:repeat_real_callback(
        function()
            create_unit_status()
        end,
        200,
        tcs_battle.real_callback_names["unit_status"]
    )

    mapf_to_all_units(tag_active)

    bm:repeat_real_callback(
        function()
            cleanup_inactive_units()
        end,
        1000,
        tcs_battle.real_callback_names["unit_dies"]
    )

    bm:repeat_real_callback(
        summoned_unit_check,
        1000,
        tcs_battle.real_callback_names["unit_summoned"]
    )
    bm:repeat_real_callback(
        enemy_summoned_unit_check,
        1000,
        tcs_battle.real_callback_names["unit_summoned"]
    )
end

-----------------------------------------------------
-- LISTENERS
-----------------------------------------------------

if core:is_battle() then
    -- in battle, the script is loaded last, so just call the test functions
    battle_startup_test_scripts_here();
    bm:register_phase_change_callback("Deployment", battle_deployment_test_scripts_here);
    bm:register_phase_change_callback("Deployed", battle_conflict_test_scripts_here);
end;
