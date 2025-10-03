-- TODO: Unglobal these; for dev purpose only
tcs = core:get_static_object("tcs");
tcs_battle = core:get_static_object("tcs_battle");

-----------------------------------------------------
-- BATTLE TEST SCRIPTS
-----------------------------------------------------

function reselect_units()
    bm:clear_selection();
end

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

function disable_non_passives(unit, time)
    for key, ability in pairs(unit:owned_non_passive_special_abilities()) do
        unit:disable_special_ability(ability, true)
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

function fix_ai_shooting()
    for alliance = 1, bm:alliances():count() do
        army_alliance = bm:alliances():item(alliance);
        for army = 1, army_alliance:armies():count() do
            units_army = army_alliance:armies():item(army);
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

function enable_unit_move(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    if not scrunit_is_engaged(scrunit) then
        scrunit.uc:reset_ability_number_of_uses("tcs_main_unit_active_move")
        unit:disable_special_ability("tcs_main_unit_active_move", false)
    end
end

function enable_unit_shoot(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    if  not tcs_battle.unit_ran[unit:unique_ui_id()] and not tcs_battle.unit_retreated[unit:unique_ui_id()] then
        scrunit.uc:reset_ability_number_of_uses("tcs_main_unit_active_shoot")
        unit:disable_special_ability("tcs_main_unit_active_shoot", false)
    end
end

function enable_unit_fight(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    if scrunit_is_engaged(scrunit) and not tcs_battle.unit_ran[unit:unique_ui_id()] and not tcs_battle.unit_retreated[unit:unique_ui_id()] then
        local scrunit = bm:get_scriptunit_for_unit(unit);
        scrunit.uc:reset_ability_number_of_uses("tcs_main_unit_active_fight")
        unit:disable_special_ability("tcs_main_unit_active_fight", false)
    end
end

function enable_unit_charge(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    if not scrunit_is_engaged(scrunit) and not tcs_battle.unit_ran[unit:unique_ui_id()] and not tcs_battle.unit_retreated[unit:unique_ui_id()] then
        local scrunit = bm:get_scriptunit_for_unit(unit);
        scrunit.uc:reset_ability_number_of_uses("tcs_main_unit_active_charge")
        unit:disable_special_ability("tcs_main_unit_active_charge", false)
    end
end

function enable_unit_retreat(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    if scrunit_is_engaged(scrunit) then
        local scrunit = bm:get_scriptunit_for_unit(unit);
        scrunit.uc:reset_ability_number_of_uses("tcs_main_unit_active_retreat")
        unit:disable_special_ability("tcs_main_unit_active_retreat", false)
    end
end

function enable_unit_run(unit)
    local scrunit = bm:get_scriptunit_for_unit(unit);
    if not scrunit_is_engaged(scrunit) then
        local scrunit = bm:get_scriptunit_for_unit(unit);
        scrunit.uc:reset_ability_number_of_uses("tcs_main_unit_active_run")
        unit:disable_special_ability("tcs_main_unit_active_run", false)
    end
end

function disable_unit_activations(unit)
    for key, ability in pairs(tcs_battle.unit_activations) do
        unit:disable_special_ability(ability, true)
    end
end

function set_active_phase(phase)
    tcs_battle.current_phase = phase;
    local parent = core:get_ui_root()
    local bop_holder = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar")
    local phase_button_holder = find_uicomponent(bop_holder, "phase_control_panel", "control_buttons")

    local phase_button_component = find_uicomponent(phase_button_holder, phase)
    phase_button_component:SetState("selected")
    phase_button_component:SetInteractive(false)

    if not (phase == "button_fight_phase") then
        local next_phase_button_component = find_uicomponent(phase_button_holder,
            tcs_battle.phase_buttons[tcs_battle.phase_button_to_key[phase] + 1])
        next_phase_button_component:SetState("active")
        next_phase_button_component:SetInteractive((bm:local_alliance() == tcs_battle.active_player_alliance_index))
    end
end

function enable_next_phase_button(bool)
    local parent = core:get_ui_root()
    local next_phase_button_component = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar", "phase_control_panel", "next_phase_button")

    next_phase_button_component:SetDisabled(not bool)

    if not bool then
        next_phase_button_component:SetState("inactive")
    else
        next_phase_button_component:SetState("active")
    end
end

function reset_phases()
    local parent = core:get_ui_root()
    local bop_holder = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar")

    local phase_control_panel = core:get_or_create_component("phase_control_panel",
        "ui/templates/tcs_phase_control_panel.twui.xml", bop_holder)
    local phase_button_holder = find_uicomponent(phase_control_panel, "control_buttons")

    for key, phase_button in pairs(tcs_battle.phase_buttons) do
        local phase_button_component = find_uicomponent(phase_button_holder, phase_button)
        phase_button_component:SetState("inactive")
        phase_button_component:SetInteractive(false)
    end

    -- Disable the Next Phase button when it is not their turn.
    enable_next_phase_button((bm:local_alliance() == tcs_battle.active_player_alliance_index))

    -- Reset info on units that ran/retreated
    tcs_battle.unit_ran = {};
    tcs_battle.unit_retreated = {};
end

function setup_phase_controls()
    local parent = core:get_ui_root()
    local bop_holder = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar")

    local phase_control_panel = core:get_or_create_component("phase_control_panel",
        "ui/templates/tcs_phase_control_panel.twui.xml", bop_holder)

    reset_phases();
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

function remake_flag_path(flag_path)
    local flag_path_parts = lua_split(flag_path, "\\")
    return flag_path_parts[1] .. "/" .. flag_path_parts[2] .. "/" .. flag_path_parts[3] .. "/mon_64.png"
end

function set_active_crest()
    local parent = core:get_ui_root()
    local bop_holder = find_uicomponent(parent, "BOP_frame", "hud_battle_top_bar")

    local phase_control_panel = core:get_or_create_component("phase_control_panel",
        "ui/templates/tcs_phase_control_panel.twui.xml", bop_holder)

    local active_player_crest = find_uicomponent(phase_control_panel, "player_pane", "player_holder", "player_crest")
    local active_player_flag = remake_flag_path(active_player_alliance():armies():item(1):flag_path())
    active_player_crest:SetImagePath(active_player_flag)

    local active_player_title = find_uicomponent(phase_control_panel, "player_pane", "player_title")

    if tcs_battle.active_player_alliance_index == bm:local_alliance() then
        active_player_title:SetStateText("Your Turn")
    else
        active_player_title:SetStateText("Their Turn")
    end
end

function enable_formed_attack(unit)
    unit:set_stat_attribute("formed_attack", true)
end

function disable_formed_attack(unit)
    unit:set_stat_attribute("formed_attack", false)
end

function roll_dice(n, eyes)
    local diceroll = 0;
    for i = 1, n do
        diceroll = diceroll + math.ceil(bm:random_number() * eyes)
    end
    return diceroll
end

function normalised_dice_check(target, range, number_of_dice, size_of_dice)
    number_of_dice = number_of_dice or 2
    size_of_dice = size_of_dice or 6
    check = (((target - (range / 6)) / (range - (range / 6))) * ((number_of_dice * size_of_dice) - number_of_dice)) + number_of_dice

    local diceroll = roll_dice(number_of_dice, size_of_dice)

    tcs:log("Rolled a " .. diceroll .. " (target: " .. check .. ")");
    return diceroll >= check
end

function scrunit_is_currently_flying(scrunit)
    return scrunit.unit:is_currently_flying()
end

function scrunit_is_currently_grounded(scrunit)
    return not scrunit_is_currently_flying(scrunit)
end

function reachable_enemy_scrunits(scrunit)
    local enemy_scrunits = bm:get_scriptunits_for_army(get_next_alliance_index(scrunit.unit:alliance_index()), 1)

    if not scrunit.unit:is_currently_flying() then
        enemy_scrunits = enemy_scrunits:filter("nearest_enemies", scrunit_is_currently_grounded)
    end

    return enemy_scrunits
end

function nearest_enemy_at_destination(scrunit)
    scrunit:cache_destination()
    if not scrunit:get_cached_destination_position() then
        return nil
    end
    local enemy_scrunits = reachable_enemy_scrunits(scrunit)
    return enemy_scrunits:item(get_nearest(scrunit:get_cached_destination_position(), enemy_scrunits))
end

function nearest_enemy(scrunit, reachable)
    reachable = reachable or true

    local enemy_scrunits = reachable_enemy_scrunits(scrunit)

    if enemy_scrunits:count() == 0 then
        return nil
    end

    return enemy_scrunits:item(get_nearest(scrunit.unit:position(), enemy_scrunits))
end

function nearest_flying_enemy(scrunit)
    local enemy_scrunits = reachable_enemy_scrunits(scrunit):filter("nearest_enemies", scrunit_is_currently_flying)
    if enemy_scrunits:count() == 0 then
        return nil
    end
    return enemy_scrunits:item(get_nearest(scrunit.unit:position(), enemy_scrunits))
end

function scrunit_is_engaged(scrunit, offset)
    offset = offset or 0
    local nearest_enemy_scrunit = nil
    if scrunit.unit:is_currently_flying() then
        nearest_enemy_scrunit = nearest_flying_enemy(scrunit)
    else
        nearest_enemy_scrunit = nearest_enemy(scrunit)
    end

    if not nearest_enemy_scrunit then
        return false
    end

    local nearest_distance = scrunit.unit:unit_distance(nearest_enemy_scrunit.unit);

    return nearest_distance < tcs_battle.engagement_distance + offset
end

function perform_next_phase()
    bm:alliances():item(bm:local_alliance()):armies():item(bm:local_army()):use_special_ability("tcs_next_phase", battle_vector:new())
end

function mapf_to_selected_units(func, time, ability)
    local time = time or nil;
    for unit_id, unit in pairs(tcs_battle.selected_units) do
        if unit:can_perform_special_ability(ability) then
            local battle_ability = get_unit_battle_ability_cco(unit, ability)
            if battle_ability and battle_ability:Call("CurrentState") == "selected" then
                func(unit, time);
            end
        end
    end
end

function mapf_to_local_player_units(func, time)
    local time = time or nil;
    local player_scrunits = bm:get_scriptunits_for_local_players_army()
    for k, unit in pairs(player_scrunits:get_unit_table()) do
        func(unit, time)
    end
end

function mapf_to_active_player_units(func, time)
    local time = time or nil;
    for army = 1, active_player_alliance():armies():count() do
        battle_army = active_player_alliance():armies():item(army);
        for unit_id = 1, battle_army:units():count() do
            local unit = battle_army:units():item(unit_id);
            func(unit, time)
        end
    end
end

function mapf_to_ai_units(func, time)
    local time = time or nil;
    for alliance = 1, bm:alliances():count() do
        if not (alliance == bm:local_alliance()) then
            ai_alliance = bm:alliances():item(alliance);
            for army = 1, ai_alliance:armies():count() do
                ai_army = ai_alliance:armies():item(army);
                if not (ai_army:is_player_controlled()) then
                    for unit_id = 1, ai_army:units():count() do
                        local ai_unit = ai_army:units():item(unit_id);
                        func(ai_unit, time)
                    end
                end
            end
        end
    end
end

function mapf_to_all_units(func, time)
    local time = time or nil;
    for alliance = 1, bm:alliances():count() do
        army_alliance = bm:alliances():item(alliance);
        for army = 1, army_alliance:armies():count() do
            units_army = army_alliance:armies():item(army);
            for unit_id = 1, units_army:units():count() do
                local ai_unit = units_army:units():item(unit_id);
                func(ai_unit, time)
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

function any_units_firing_missile(scrunits)
    for k, unit in pairs(scrunits:get_unit_table()) do
        if tcs_get_battleunit_cco(unit:unique_ui_id()):Call("IsFiringMissiles") then
            return true
        end
    end
    return false
end

local function switch(x, cases)
    local match = cases[x] or cases.default or function() end

    return match()
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
    local unit_cco = cco("CcoBattleSelection", 1):Call("FirstUnitContext")

    for i = 1, unit_cco:Call("AbilityList.Size") do
        if unit_cco:Call("AbilityList")[i]:Call("RecordKey") == ability_record then
            return unit_cco:Call("AbilityList")[i]
        end
    end

    return nil
end

function get_sunit_by_id(uid)
    local enemy_sunits = bm:get_scriptunits_for_main_enemy_army_to_local_player()

    for k, unit in pairs(enemy_sunits:get_sunit_table()) do
        if unit.unit:unique_ui_id() == uid then
            return unit
        end
    end
    local friendly_sunits = bm:get_scriptunits_for_local_players_army()

    for k, unit in pairs(friendly_sunits:get_sunit_table()) do
        if unit.unit:unique_ui_id() == uid then
            return unit
        end
    end

    return nil
end

function get_selected_unit_ability_cco(ability_record)
    local unit_cco = cco("CcoBattleSelection", 1):Call("FirstUnitContext")

    for i = 1, unit_cco:Call("AbilityList.Size") do
        if unit_cco:Call("AbilityList")[i]:Call("RecordKey") == ability_record then
            return unit_cco:Call("AbilityList")[i]
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

-- Test scripts placed here will be called when the battle script environment is started - this happens
-- right at the end of the loading sequence in to any battle
function battle_startup_test_scripts_here()
    tcs:log("*** tcs script loaded - Tabletop Combat Simulator engaged. ***\n\n");

    function active_unit_handler(unit, is_selected)
        if is_selected then
            -- track selected units
            tcs_battle.selected_units[unit:unique_ui_id()] = unit;
        else
            -- track unselected units
            tcs_battle.selected_units[unit:unique_ui_id()] = nil;
        end

        tcs:log("Selected units:")
        for k, v in pairs(tcs_battle.selected_units) do
            tcs:log(k .. ":" .. v:type());
        end
    end

    bm:register_unit_selection_handler("active_unit_handler")

    function special_ability_handler(event)
        local event_name = event:get_name()

        if not (event_name == "Special Ability") then
            return
        end

        local cases = {
            default = function() return end,
            tcs_main_unit_active_fight = function() mapf_to_selected_units(unit_fight, tcs:get_config("fight_time") * 1000, "tcs_main_unit_active_fight") end,
            tcs_main_unit_active_move = function() mapf_to_selected_units(unit_move, tcs:get_config("move_time") * 1000, "tcs_main_unit_active_move") end,
            tcs_main_unit_active_shoot = function() mapf_to_selected_units(unit_shoot, tcs:get_config("shoot_time") * 1000, "tcs_main_unit_active_shoot") end,
            tcs_main_unit_active_charge = function() mapf_to_selected_units(unit_charge, nil, "tcs_main_unit_active_charge") end,
            tcs_main_unit_active_retreat = function() mapf_to_selected_units(unit_retreat, tcs:get_config("retreat_time") * 1000, "tcs_main_unit_active_retreat") end,
            tcs_main_unit_active_run = function() mapf_to_selected_units(unit_run, tcs:get_config("move_time") * 1000, "tcs_main_unit_active_run") end,
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
            tcs_next_phase = function() core:trigger_custom_event("tcs_next_phase", {}) end
        }

        local ability_name = event:get_string1();
        tcs:log("Ability used: " .. ability_name);

        switch(ability_name, cases)
    end

    bm:register_command_handler_callback("Special Ability", special_ability_handler, "special_ability_handler")
end;

-- Test scripts placed here will be called in battle when deployment phase commences
function battle_deployment_test_scripts_here()
    tcs:clear_log();
    tcs:log("Battle Deployment started.");

    mapf_to_ai_units(disable_non_passives);
    fix_ai_shooting();
    mapf_to_all_units(disable_fire_at_will);

    if tcs.force_formed_attack then
        mapf_to_ai_units(enable_formed_attack)
    end

    tcs_battle.active_player_alliance_index = bm:random_number(1, 2);

    setup_phase_controls()
    set_active_crest()
end;

function battle_conflict_test_scripts_here()
    tcs:log("Battle Deployment done; combat starting.");

    core:trigger_custom_event('button_hero_phase', {})
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
