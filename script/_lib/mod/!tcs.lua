local tcs = {
    config = {
        logging_enabled = false,
        move_time = 30,
        fight_time = 20,
        shoot_time = 10,
        retreat_time = 10,
        ai_move_time = 30,
        ai_fight_time = 20,
        ai_shoot_time = 10,
        ai_hero_time = 5,
        force_formed_attack = false
    }
};

-- GENERIC --
function tcs:log(text)
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
        local popLog = io.open("mod_logs/tcs.log","a")

        popLog :write(logContext .. ":  "..logText .. "    : [".. logTimeStamp .. "]\n")
        popLog :flush()
        popLog :close()

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
        local popLog = io.open("mod_logs/tcs.log","w")
        local logText = "Tabletop Combat Simulator initialized."
        popLog :write(logContext .. ":  "..logText .. "    : [".. logTimeStamp .. "]\n")
        popLog :flush()
        popLog :close()

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
