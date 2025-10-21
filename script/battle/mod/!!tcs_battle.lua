local tcs_battle = {
    selected_units = {},
    active_player_alliance_index = nil,
    current_phase = nil,
    last_targeted_enemy_sunit = nil,
    engagement_distance = 20,
    charge_range = 120,
    charge_dice_count = 4,

    proxy_id = nil,

    ai_actively_shooting = {},
    ai_actively_moving = {},
    ai_actively_charging = {},
    ai_actively_fighting = {},
    ai_actively_retreating = {},

    unit_actively_moving = {},
    unit_actively_fighting = {},
    unit_actively_shooting = {},
    unit_actively_charging = {},
    unit_actively_retreating = {},

    unit_should_land = {},
    unit_cards_count = 0,
    enemy_unit_count = 0,

    active_units = {},
    unit_ran = {},
    unit_retreated = {},

    unit_status = {},

    phase_buttons = {
        "button_hero_phase",
        "button_move_phase",
        "button_shoot_phase",
        "button_charge_phase",
        "button_fight_phase"
    },

    phase_button_to_key = {
        button_hero_phase = 1,
        button_move_phase = 2,
        button_shoot_phase = 3,
        button_charge_phase = 4,
        button_fight_phase = 5
    },

    phase_transition_map = {
        button_hero_phase = "button_move_phase",
        button_move_phase = "button_shoot_phase",
        button_shoot_phase = "button_charge_phase",
        button_charge_phase = "button_fight_phase",
        button_fight_phase = "button_hero_phase"
    },

    unit_activations = {
        "tcs_main_unit_active_move",
        "tcs_main_unit_active_fight",
        "tcs_main_unit_active_shoot",
        "tcs_main_unit_active_charge",
        "tcs_main_unit_active_retreat",
        "tcs_main_unit_active_run",
        "tcs_main_unit_active_reform",
        "tcs_next_phase"
    },

    unit_callback_names = {
        stopmove = "freeze_unit_",
        engage_check = "engagement_unit_",
        engage_warn = "engagement_warning_unit",
        stopfight = "stopfight_",
        stopshoot = "stopshoot_",
        stopcharge = "stopcharge_",
        stopretreat = "stopretreat_",
        landunit = "landunit_",
        startmove = "startmove_unit_",
        startfight = "startfight_unit_",
        startshoot = "startshoot_unit_"
    },

    army_ai_controls = {
        "tcs_army_ai_move",
        "tcs_army_ai_fight",
        "tcs_army_ai_shoot",
        "tcs_army_ai_hero",
        "tcs_army_ai_charge",
    },

    unit_passives = {
        "tcs_main_unit_passive_inactive_fighting",
        "tcs_main_unit_passive_inactive_shooting",
        "tcs_main_unit_passive_stationary",
    },

    real_callback_names = {
        unit_status = "tcs_unit_status",
        unit_dies = "tcs_unit_dies",
        unit_summoned = "tcs_unit_summoned"
    },

    listener_names = {
        button_next_phase = "tcs_next_phase_button",
        button_move = "tcs_button_move_phase",
        button_shoot = "tcs_button_shoot_phase",
        button_charge = "tcs_button_charge_phase",
        button_fight = "tcs_button_fight_phase",
        next_phase = "tcs_Next_Phase",
        hero_phase = "tcs_Hero_Phase",
        move_phase = "tcs_Move_Phase",
        shoot_phase = "tcs_Shooting_Phase",
        charge_phase = "tcs_Charge_Phase",
        fight_phase = "tcs_Fight_Phase",
        target_tracker = "tcs_target_tracker",
        position_tracker = "tcs_position_tracker",
    },

    unit_movement_range = {},
    unit_movement_warned = {}
}

function tcs_battle:set_unit_status(unit_id, status, seconds)
    self.unit_status[unit_id] = { status = status, time = seconds}
end

function tcs_battle:get_unit_status(unit_id)
    if not self.unit_status[unit_id] then
        return {status = nil, time = nil}
    end
    return self.unit_status[unit_id]
end

function tcs_battle:clear_unit_status(unit_id)
    self.unit_status[unit_id] = nil
end

function tcs_battle:clear_all_unit_statuses()
    self.unit_status = {}
end

function tcs_battle:get_listener_name(key)
    return self.listener_names[key]
end

core:add_static_object("tcs_battle", tcs_battle);
