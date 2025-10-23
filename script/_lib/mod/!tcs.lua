local tcs = {
    config = {
        logging_enabled = false,
        min_movement_range = 30,
        max_movement_range = 120,
        max_run_distance = 60,
        max_unit_speed = 140,
        unit_reform_cost = 3,
        fight_time = 15,
        shoot_time = 15,
        retreat_time = 10,
        ai_move_time = 30,
        ai_fight_time = 20,
        ai_shoot_time = 15,
        ai_hero_time = 5,
        overcharge_time = 10,
        wom_per_turn = 12,
        enable_damage_on_charge = true,
        force_formed_attack = false,
        force_straight_movement = false,
        warn_about_engagement_range = false,
        warn_about_engagement_range_distance = 15,
        default_charge_dice = 2,
        default_dice_eyes = 6,
        default_run_dice = 1,
        pile_in_time = 5,
        break_test_dice = 2,
        unit_break_duration = 25,
        unit_break_point = 50,
        introduction_tour = false,
        enable_ai_controls = false,
        simultaneous_turns = false,
    }
};

-- GENERIC --
function tcs:log(text)
    if tcs:get_config("logging_enabled") then
        -- Code taken from Mixu's Mixer Mod

        local info = debug.getinfo(2, "Sl")

        ftext = string.format("[TCS:%s:%s]", info.short_src, info.currentline);

        if enable_logging == false then
            return
        end

        if not __write_output_to_logfile then
            return;
        end

        local logText = tostring(text)
        local logContext = tostring(ftext)
        local logTimeStamp = os.date("%d-%m-%Y %X")
        local popLog = io.open("mod_logs/tcs.log", "a")

        popLog:write(logContext .. ":  " .. logText .. "    : [" .. logTimeStamp .. "]\n")
        popLog:flush()
        popLog:close()
    end
end

function tcs:clear_log()
    if tcs:get_config("logging_enabled") then
        -- Code taken from Mixu's Mixer Mod
        ftext = "[Quinner|TCS]";

        if enable_logging == false then
            return
        end

        if not __write_output_to_logfile then
            return;
        end

        local logText = tostring(text)
        local logContext = tostring(ftext)
        local logTimeStamp = os.date("%d-%m-%Y %X")
        local popLog = io.open("mod_logs/tcs.log", "w")
        local logText = "Tabletop Combat Simulator initialized."
        popLog:write(logContext .. ":  " .. logText .. "    : [" .. logTimeStamp .. "]\n")
        popLog:flush()
        popLog:close()
    end
end

function tcs:gls(localised_string_key)
    return common.get_localised_string("tcs_" .. localised_string_key);
end

function tcs:get_config(config_key)
    if get_mct then
        local mct = get_mct();

        if mct ~= nil then
            local mod_cfg = mct:get_mod_by_key("tcs");
            if mod_cfg:get_option_by_key(config_key) then
                return mod_cfg:get_option_by_key(config_key):get_finalized_setting();
            end
        end
    end

    return self.config[config_key];
end

function tcs:set_config(config_key, config_value)
    if get_mct then
        local mct = get_mct();

        if mct ~= nil then
            local mod_cfg = mct:get_mod_by_key("tcs");
            if mod_cfg:get_option_by_key(config_key) then
                return mod_cfg:get_option_by_key(config_key):set_selected_setting(config_value, false);
            end
        end
    end

    return self.config[config_key];
end


core:add_static_object("tcs", tcs);
