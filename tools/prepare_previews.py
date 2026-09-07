from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
for file in (root/'test_output').glob('*.png'):
    im=Image.open(file)
    # Full UI review retains legible CJK text; output stays below the 1568px detail budget.
    im.thumbnail((1280,720))
    im.save(file.with_suffix('.webp'),quality=85)
