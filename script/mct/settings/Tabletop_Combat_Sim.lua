if not get_mct then return end
local mct = get_mct();

if not mct then return end
local mct_mod = mct:register_mod("tcs")

mct_mod:set_title("Tabletop Combat Simulator")
mct_mod:set_author("Quinner")
mct_mod:set_description("A simulation of tabletop mechanics for Total War: Warhammer III.")

mct_mod:set_log_file_path("mod_logs/tcs.log")

-- Move Timer
local mct_move_option = mct_mod:add_new_option("move_time", "slider")
mct_move_option:set_text("Move Activation duration")
mct_move_option:slider_set_min_max(0, 300)
mct_move_option:slider_set_step_size(1)
mct_move_option:set_default_value(20)
mct_move_option:set_tooltip_text("The number of seconds a unit is given to move during a Move Activation.");


local mct_fight_option = mct_mod:add_new_option("fight_time", "slider")
mct_fight_option:set_text("Fight Activation duration")
mct_fight_option:slider_set_min_max(0, 300)
mct_fight_option:slider_set_step_size(1)
mct_fight_option:set_default_value(20)
mct_fight_option:set_tooltip_text("The number of seconds a unit is given to fight during a Fight Activation.");


local mct_shoot_option = mct_mod:add_new_option("shoot_time", "slider")
mct_shoot_option:set_text("Shoot Activation duration")
mct_shoot_option:slider_set_min_max(0, 300)
mct_shoot_option:slider_set_step_size(1)
mct_shoot_option:set_default_value(10)
mct_shoot_option:set_tooltip_text("The number of seconds a unit is given to shoot during a Shoot Activation.");

local mct_retreat_option = mct_mod:add_new_option("retreat_time", "slider")
mct_retreat_option:set_text("Retreat Activation duration")
mct_retreat_option:slider_set_min_max(0, 300)
mct_retreat_option:slider_set_step_size(1)
mct_retreat_option:set_default_value(10)
mct_retreat_option:set_tooltip_text("The number of seconds a unit is given to move during a Retreat Activation. Note that units keep retreating whilst in engagement range of an enemy unit if their initial time does not move them far away enough.");


local mct_ai_move_option = mct_mod:add_new_option("ai_move_time", "slider")
mct_ai_move_option:set_text("AI Move Activation duration")
mct_ai_move_option:slider_set_min_max(0, 300)
mct_ai_move_option:slider_set_step_size(1)
mct_ai_move_option:set_default_value(30)

local mct_ai_fight_option = mct_mod:add_new_option("ai_fight_time", "slider")
mct_ai_fight_option:set_text("AI Fight Activation duration")
mct_ai_fight_option:slider_set_min_max(0, 300)
mct_ai_fight_option:slider_set_step_size(1)
mct_ai_fight_option:set_default_value(20)

local mct_ai_shoot_option = mct_mod:add_new_option("ai_shoot_time", "slider")
mct_ai_shoot_option:set_text("AI Shoot Activation duration")
mct_ai_shoot_option:slider_set_min_max(0, 300)
mct_ai_shoot_option:slider_set_step_size(1)
mct_ai_shoot_option:set_default_value(10)

local mct_charge_option = mct_mod:add_new_option("charge_range", "slider")
mct_charge_option:set_text("Charge Activation range")
mct_charge_option:slider_set_min_max(30, 360)
mct_charge_option:slider_set_step_size(10)
mct_charge_option:set_default_value(120)
mct_charge_option:set_tooltip_text("The range at which a target is considered to roll for a Charge Activation. Uses beyond this range will be nullified and a new target can be chosen.");

local mct_pile_in_option = mct_mod:add_new_option("pile_in_time", "slider")
mct_pile_in_option:set_text("Pile In move duration")
mct_pile_in_option:slider_set_min_max(0, 60)
mct_pile_in_option:slider_set_step_size(1)
mct_pile_in_option:set_default_value(5)
mct_pile_in_option:set_tooltip_text("The amount of seconds a unit is given to move during a fight activation.");


local option_tcs_formed_attack_enabled = mct_mod:add_new_option("force_formed_attack", "checkbox");
option_tcs_formed_attack_enabled:set_text("Force Formed Attack")
option_tcs_formed_attack_enabled:set_tooltip_text("If enabled, all units will be put in Formed Attack to maintain formation, similar to Warhammer Fantasy battle formations.");
option_tcs_formed_attack_enabled:set_default_value(false);

local option_tcs_engagement_warning_enabled = mct_mod:add_new_option("warn_about_engagement_range", "checkbox");
option_tcs_engagement_warning_enabled:set_text("Engagement Range Warning")
option_tcs_engagement_warning_enabled:set_tooltip_text("If enabled, the game will slow down and get a warning about moving too close to the Engagement range of an enemy unit. This provides you time to intervene before your unit will freeze just outside engagement range.");
option_tcs_engagement_warning_enabled:set_default_value(false);

local mct_engagement_range_buffer_option = mct_mod:add_new_option("warn_about_engagement_range_distance", "slider")
mct_engagement_range_buffer_option:set_text("Engagement Range Buffer")
mct_engagement_range_buffer_option:slider_set_min_max(10, 60)
mct_engagement_range_buffer_option:set_tooltip_text("The distance to an opponent unit's engagement range that you want to receive an intervention at.");
mct_engagement_range_buffer_option:slider_set_step_size(1)
mct_engagement_range_buffer_option:set_default_value(15)

local option_tcs_logging_enabled = mct_mod:add_new_option("logging_enabled", "checkbox");
option_tcs_logging_enabled:set_text("Enable logging");
option_tcs_logging_enabled:set_tooltip_text("If enabled, a log will be populated as you play. Use it to report bugs!");
option_tcs_logging_enabled:set_default_value(false);
