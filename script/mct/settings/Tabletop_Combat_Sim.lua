if not get_mct then return end
local mct = get_mct();

if not mct then return end
local mct_mod = mct:register_mod("tcs")

mct_mod:set_title("Tabletop Combat Simulator")
mct_mod:set_author("Quinner")
mct_mod:set_description("A simulation of tabletop mechanics for Total War: Warhammer III.")

mct_mod:set_log_file_path("mod_logs/tcs.log")

-- Move Timer
local mct_option = mct_mod:add_new_option("move_time", "slider")
mct_option:slider_set_min_max(0, 300)
mct_option:slider_set_step_size(1)
mct_option:set_default_value(30)

local mct_option = mct_mod:add_new_option("fight_time", "slider")
mct_option:slider_set_min_max(0, 300)
mct_option:slider_set_step_size(1)
mct_option:set_default_value(20)

local mct_option = mct_mod:add_new_option("shoot_time", "slider")
mct_option:slider_set_min_max(0, 300)
mct_option:slider_set_step_size(1)
mct_option:set_default_value(10)

local mct_option = mct_mod:add_new_option("retreat_time", "slider")
mct_option:slider_set_min_max(0, 300)
mct_option:slider_set_step_size(1)
mct_option:set_default_value(10)


local mct_option = mct_mod:add_new_option("ai_move_time", "slider")
mct_option:slider_set_min_max(0, 300)
mct_option:slider_set_step_size(1)
mct_option:set_default_value(30)

local mct_option = mct_mod:add_new_option("ai_fight_time", "slider")
mct_option:slider_set_min_max(0, 300)
mct_option:slider_set_step_size(1)
mct_option:set_default_value(20)

local mct_option = mct_mod:add_new_option("ai_shoot_time", "slider")
mct_option:slider_set_min_max(0, 300)
mct_option:slider_set_step_size(1)
mct_option:set_default_value(10)

local mct_option = mct_mod:add_new_option("charge_range", "slider")
mct_option:slider_set_min_max(60, 360)
mct_option:slider_set_step_size(10)
mct_option:set_default_value(120)

local option_tcs_formed_attack_enabled = mct_mod:add_new_option("force_formed_attack", "checkbox");
option_tcs_formed_attack_enabled:set_text("Force Formed Attack")
option_tcs_formed_attack_enabled:set_tooltip_text("If enabled, AI units will be put in Formed Attack to maintain formation.");
option_tcs_formed_attack_enabled:set_default_value(false);

local option_pttg_logging_enabled = mct_mod:add_new_option("logging_enabled", "checkbox");
option_pttg_logging_enabled:set_text("Enable logging");
option_pttg_logging_enabled:set_tooltip_text("If enabled, a log will be populated as you play. Use it to report bugs!");
option_pttg_logging_enabled:set_default_value(false);
