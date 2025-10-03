local tcs_battle = {
    selected_units = {},
    active_player_alliance_index = nil,
    current_phase = nil,
    last_targeted_enemy_sunit = nil,
    engagement_distance = 30,
    charge_range = 120,
    charge_dice_count = 4,
    ai_actively_shooting = {},
    ai_actively_moving = {},
    ai_actively_charging = {},
    ai_actively_fighting = {},
    ai_actively_retreating = {},
    ai_army_alliance = {},

    unit_actively_moving = {},
    unit_actively_fighting = {},
    unit_actively_shooting = {},
    unit_actively_charging = {},
    unit_actively_retreating = {},

    unit_ran = {},
    unit_retreated = {},

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
        "tcs_next_phase"
    }
}

core:add_static_object("tcs_battle", tcs_battle);
