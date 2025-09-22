from source.land_units import land_units
from source.unit_abilities import abilities

with open("output/land_units_to_abilities.txt", "w") as outfile:
    for ability in abilities:
        for unit in land_units:
            outfile.write(f"{ability}\t{unit}\n")