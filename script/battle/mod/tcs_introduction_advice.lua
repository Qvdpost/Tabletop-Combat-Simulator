local tcs = core:get_static_object("tcs");

local im = get_infotext_manager();

im:set_button_state_override(
    "tcs.battle.advice.tcs_guide.info_004",
    function()
        tcs_introduction:start();
    end,
    function(uic)
        
    end,
    "ScriptEventConflictPhaseBegins"
);
do
    local am = advice_monitor:new(
        "TCS_INTRODUCTION_TOUR",
        90,
        "tcs.battle.advice.controls.001",
        {
            "tcs.battle.advice.tcs_guide.info_001",
            "tcs.battle.advice.tcs_guide.info_002",
            "tcs.battle.advice.tcs_guide.info_003",
            "tcs.battle.advice.tcs_guide.info_004"
        }
    );

    am:set_advice_level(2)
    
    local function show_condition()
        return not core:svr_load_registry_bool("tcs_introduction_tour") or tcs:get_config("introduction_tour")
    end

    local function trigger_condition()
        return (bm:battle_type() ~= "land_ambush") and show_condition();
    end;

    am:add_trigger_condition(
        trigger_condition, 
        "ScriptEventDeploymentPhaseBegins"
    );

    am:add_trigger_condition(
        function()
            return bm:is_deployment_phase() and trigger_condition();
        end,
        "ScriptEventScriptedTourCompleted"
    );
end