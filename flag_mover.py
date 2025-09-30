import os
import shutil

count = 0

for folder in [x[0] for x in os.walk("ui/flags")][1:]:
    subculture = folder.split("\\")[1]

    

    if os.path.exists(f"{folder}/mon_64_glow.png"):
        count += 1
        print(count, subculture)
        shutil.move(f"ui/flags/{subculture}/mon_64.png", f"ui/flags_glowing_flat/mon_{subculture}.png")
        shutil.move(f"ui/flags/{subculture}/mon_64_glow.png", f"ui/flags_glowing_flat/mon_{subculture}_glow.png")