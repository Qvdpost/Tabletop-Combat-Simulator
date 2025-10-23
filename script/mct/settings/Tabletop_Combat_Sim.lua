if not get_mct then return end
local mct = get_mct();

if not mct then return end
local mct_mod = mct:register_mod("tcs")

mct_mod:set_title("Tabletop Combat Simulator")
mct_mod:set_author("Quinner")
mct_mod:set_description("A simulation of tabletop mechanics for Total War: Warhammer III battles.")

mct_mod:set_log_file_path("mod_logs/tcs.log")

-- Move Timer
local mct_move_option = mct_mod:add_new_option("max_movement_range", "slider")
mct_move_option:set_text("Move Activation maximum range.")
mct_move_option:slider_set_min_max(0, 300)
mct_move_option:slider_set_step_size(1)
mct_move_option:set_default_value(120)
mct_move_option:set_tooltip_text("The distance a unit with the highest speed could traverse.");
mct_move_option:set_is_global(true)

local mct_move_option = mct_mod:add_new_option("min_movement_range", "slider")
mct_move_option:set_text("Move Activation minimum range.")
mct_move_option:slider_set_min_max(0, 300)
mct_move_option:slider_set_step_size(1)
mct_move_option:set_default_value(30)
mct_move_option:set_tooltip_text("The distance a unit with the lowest speed could traverse.");
mct_move_option:set_is_global(true)

local mct_move_option = mct_mod:add_new_option("max_run_distance", "slider")
mct_move_option:set_text("Run Activation maximum additional distance")
mct_move_option:slider_set_min_max(0, 300)
mct_move_option:slider_set_step_size(1)
mct_move_option:set_default_value(60)
mct_move_option:set_tooltip_text("The maximum distance a unit can add to their movement range by running. The distance is calculated by an internal dice roll each activation.");
mct_move_option:set_is_global(true)

local mct_move_option = mct_mod:add_new_option("unit_reform_cost", "slider")
mct_move_option:set_text("Wheel Activation movement cost.")
mct_move_option:slider_set_min_max(0, 300)
mct_move_option:slider_set_step_size(1)
mct_move_option:set_default_value(15)
mct_move_option:set_tooltip_text("The cost incurred to the movement distance of a unit for wheeling about their axis. This cost is paid per 15 degrees of turning.");
mct_move_option:set_is_global(true)

local mct_fight_option = mct_mod:add_new_option("fight_time", "slider")
mct_fight_option:set_text("Fight Activation duration")
mct_fight_option:slider_set_min_max(0, 300)
mct_fight_option:slider_set_step_size(1)
mct_fight_option:set_default_value(20)
mct_fight_option:set_tooltip_text("The number of seconds a unit is given to fight during a Fight Activation.");
mct_fight_option:set_is_global(true)


local mct_shoot_option = mct_mod:add_new_option("shoot_time", "slider")
mct_shoot_option:set_text("Shoot Activation duration")
mct_shoot_option:slider_set_min_max(0, 300)
mct_shoot_option:slider_set_step_size(1)
mct_shoot_option:set_default_value(10)
mct_shoot_option:set_tooltip_text("The number of seconds a unit is given to shoot during a Shoot Activation.");
mct_shoot_option:set_is_global(true)

local mct_retreat_option = mct_mod:add_new_option("retreat_time", "slider")
mct_retreat_option:set_text("Retreat Activation duration")
mct_retreat_option:slider_set_min_max(0, 300)
mct_retreat_option:slider_set_step_size(1)
mct_retreat_option:set_default_value(10)
mct_retreat_option:set_tooltip_text("The number of seconds a unit is given to move during a Retreat Activation. Note that units keep retreating whilst in engagement range of an enemy unit if their initial time does not move them far away enough.");
mct_retreat_option:set_is_global(true)


local mct_ai_move_option = mct_mod:add_new_option("ai_move_time", "slider")
mct_ai_move_option:set_text("AI Move Activation duration")
mct_ai_move_option:slider_set_min_max(0, 300)
mct_ai_move_option:slider_set_step_size(1)
mct_ai_move_option:set_default_value(20)
mct_ai_move_option:set_is_global(true)

local mct_ai_fight_option = mct_mod:add_new_option("ai_fight_time", "slider")
mct_ai_fight_option:set_text("AI Fight Activation duration")
mct_ai_fight_option:slider_set_min_max(0, 300)
mct_ai_fight_option:slider_set_step_size(1)
mct_ai_fight_option:set_default_value(20)
mct_ai_fight_option:set_is_global(true)

local mct_ai_shoot_option = mct_mod:add_new_option("ai_shoot_time", "slider")
mct_ai_shoot_option:set_text("AI Shoot Activation duration")
mct_ai_shoot_option:slider_set_min_max(0, 300)
mct_ai_shoot_option:slider_set_step_size(1)
mct_ai_shoot_option:set_default_value(10)
mct_ai_shoot_option:set_is_global(true)

local mct_charge_option = mct_mod:add_new_option("charge_range", "slider")
mct_charge_option:set_text("Charge Activation range")
mct_charge_option:slider_set_min_max(30, 360)
mct_charge_option:slider_set_step_size(10)
mct_charge_option:set_default_value(120)
mct_charge_option:set_tooltip_text("The maximum distance a unit can Charge another unit. Uses beyond this range will be nullified and a new target can be chosen.");
mct_charge_option:set_is_global(true)

local mct_wom_option = mct_mod:add_new_option("wom_per_turn", "slider")
mct_wom_option:set_text("Winds of Magic per turn.")
mct_wom_option:slider_set_min_max(0, 100)
mct_wom_option:slider_set_step_size(1)
mct_wom_option:set_default_value(12)
mct_wom_option:set_tooltip_text("The number of Winds of Magic an army is giving per Wizard during the Hero Phase.");
mct_wom_option:set_is_global(true)

local mct_pile_in_option = mct_mod:add_new_option("pile_in_time", "slider")
mct_pile_in_option:set_text("Pile In move duration")
mct_pile_in_option:slider_set_min_max(0, 60)
mct_pile_in_option:slider_set_step_size(1)
mct_pile_in_option:set_default_value(5)
mct_pile_in_option:set_tooltip_text("The number of seconds a unit is given to move during a fight activation.");
mct_pile_in_option:set_is_global(true)

local mct_break_point_option = mct_mod:add_new_option("unit_break_point", "slider")
mct_break_point_option:set_text("Morale Break Point")
mct_break_point_option:slider_set_min_max(0, 100)
mct_break_point_option:slider_set_step_size(1)
mct_break_point_option:set_default_value(50)
mct_break_point_option:set_tooltip_text("The percentage of unit morale that triggers a break-check during the Hero Phase.");
mct_break_point_option:set_is_global(true)


local option_tcs = mct_mod:add_new_option("enable_damage_on_charge", "checkbox");
option_tcs:set_text("Enable Damage on Charge")
option_tcs:set_tooltip_text("If enabled, units may deal damage for the duration of their 'Overcharge'.");
option_tcs:set_default_value(true);
option_tcs:set_is_global(true)


local option_tcs = mct_mod:add_new_option("overcharge_time", "slider");
option_tcs:set_text("Overcharge max duration")
option_tcs:slider_set_min_max(0, 60)
option_tcs:slider_set_step_size(1)
option_tcs:set_default_value(10)
option_tcs:set_tooltip_text("The number of seconds a unit is given to move and optionally deal damage after reaching their charge target. This duration is calculated from the excess of their charge roll multiplied by this value.");
option_tcs:set_is_global(true)

local option_tcs_formed_attack_enabled = mct_mod:add_new_option("force_formed_attack", "checkbox");
option_tcs_formed_attack_enabled:set_text("Force Formed Attack")
option_tcs_formed_attack_enabled:set_tooltip_text("If enabled, all units will be put in Formed Attack to maintain formation during combat.");
option_tcs_formed_attack_enabled:set_default_value(false);
option_tcs_formed_attack_enabled:set_is_global(true)

local option_straight_movement = mct_mod:add_new_option("force_straight_movement", "checkbox");
option_straight_movement:set_text("Force Straight Movement")
option_straight_movement:set_tooltip_text("If enabled, units will only move in straight lines in the direction of their bearing. Turning is only possible through reforming the unit.");
option_straight_movement:set_default_value(false);
option_straight_movement:set_is_global(true)

local option_tcs_engagement_warning_enabled = mct_mod:add_new_option("warn_about_engagement_range", "checkbox");
option_tcs_engagement_warning_enabled:set_text("Engagement Range Warning")
option_tcs_engagement_warning_enabled:set_tooltip_text("If enabled, the game will slow down and get a warning about moving too close to the Engagement range of an enemy unit. This provides you time to intervene before your unit will freeze just outside engagement range.");
option_tcs_engagement_warning_enabled:set_default_value(false);
option_tcs_engagement_warning_enabled:set_is_global(true)

local mct_engagement_range_buffer_option = mct_mod:add_new_option("warn_about_engagement_range_distance", "slider")
mct_engagement_range_buffer_option:set_text("Engagement Range Buffer")
mct_engagement_range_buffer_option:slider_set_min_max(10, 60)
mct_engagement_range_buffer_option:set_tooltip_text("The distance to an opponent unit's engagement range that you want to receive a one time warning per unit at.");
mct_engagement_range_buffer_option:slider_set_step_size(1)
mct_engagement_range_buffer_option:set_default_value(15)
mct_engagement_range_buffer_option:set_is_global(true)

local option_tcs_logging_enabled = mct_mod:add_new_option("logging_enabled", "checkbox");
option_tcs_logging_enabled:set_text("Enable logging");
option_tcs_logging_enabled:set_tooltip_text("If enabled, a log will be populated as you play. Use it to report bugs!");
option_tcs_logging_enabled:set_default_value(false);
option_tcs_logging_enabled:set_is_global(true)

local mct_advise_option = mct_mod:add_new_option("introduction_tour", "checkbox")
mct_advise_option:set_text("Advise Tour")
mct_advise_option:set_tooltip_text("Shows a introductory tour the first time the game is played with the mod enabled.");
mct_advise_option:set_default_value(false);
mct_advise_option:set_is_global(true)

local mct_ai_controls_option = mct_mod:add_new_option("enable_ai_controls", "checkbox")
mct_ai_controls_option:set_text("Enable AI Controls")
mct_ai_controls_option:set_tooltip_text("Allows the player to perform Activation Phases for the AI manually.");
mct_ai_controls_option:set_default_value(false);
mct_ai_controls_option:set_is_global(true)

local mct_ai_controls_option = mct_mod:add_new_option("simultaneous_turns", "checkbox")
mct_ai_controls_option:set_text("Simultaneous Turns")
mct_ai_controls_option:set_tooltip_text("Allows the both players to perform Activations during each phase.");
mct_ai_controls_option:set_default_value(false);
mct_ai_controls_option:set_is_global(true)
