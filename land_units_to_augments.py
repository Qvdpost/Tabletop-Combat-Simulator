from source.land_units import land_units
from source.unit_augments import unit_augments

with open("output/land_units_to_augments.txt", "w") as outfile:
    for augment in unit_augments:
        for unit in land_units:
            outfile.write(f"{augment}\t{unit}\n")