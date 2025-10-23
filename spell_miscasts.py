miscast_odds = {
    12 : .97,
    11 : .92,
    10 : .83,
    9 : .72,
    8 : .58,
    7 : .42,
    6 : .28,
    5: .17,
    4: .08,
    3: .03
}

def normalize_miscast_chance(mana_cost, max_cost, min_cost, range_max, range_min):
    return round(((mana_cost - min_cost) / (max_cost - min_cost)) * (range_max - range_min) + range_min)

with open("source/unit_special_abilities_spells.txt", "r") as f:
    lines = f.readlines()
    mana_costs = [float(line.split("\t")[23]) for line in lines]
    max_mana_cost = max(mana_costs)
    min_mana_cost = min(mana_costs)

    with open("output/unit_special_abilities_spells.txt", "w") as f:
        for line in lines:
            spell_info = line.split("\t")
            cost = float(spell_info[23])
            miscast_chance = miscast_odds[normalize_miscast_chance(cost, max_mana_cost, min_mana_cost, 8, 5)]
            spell_info[30] = miscast_chance.__str__()
            # Disable spell miscast effects for now?
            # spell_info[31] = ""
            f.write("\t".join(spell_info))