cm:add_post_first_tick_callback(function()
    local bundle_key = "tcs_army_controls";
    local faction_names = cm:get_human_factions()

    for k, faction_name in pairs(faction_names) do
        local faction = cm:get_faction(faction_name);
        if faction:has_effect_bundle(bundle_key) then
            return
        end

        local bundle = cm:apply_effect_bundle(bundle_key, faction_name, -1);
    end
end)