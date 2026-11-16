#!/usr/bin/env python3
"""Reproducible store exports from the real Flutter UI and existing brand mark."""
import argparse
import html
import json
from pathlib import Path
import re
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageFilter

root = Path(__file__).resolve().parents[2]
store = root / 'store/google-play'
flutter = Path(shutil.which('flutter')).resolve()
sdk = flutter.parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--skip-capture', action='store_true')
args = parser.parse_args()
if not args.skip_capture:
    subprocess.run([str(flutter), 'test', 'tool/capture_play_store.dart',
                    f'--dart-define=FLUTTER_SDK={sdk}', '--reporter', 'expanded'], cwd=root, check=True)
for name in ['graphics', 'screenshots', 'raw']:
    (store / name).mkdir(parents=True, exist_ok=True)
fonts = sdk / 'bin/cache/artifacts/material_fonts'
def font(size, bold=False):
    return ImageFont.truetype(str(fonts / ('Roboto-Bold.ttf' if bold else 'Roboto-Regular.ttf')), size)
navy = '#233D61'
ink = '#182B43'
muted = '#5A6E87'
background = '#EEF3F9'
logo = Image.open(root / 'assets/images/eintelix_logo.png').convert('RGB')
box = ImageChops.difference(logo, Image.new('RGB', logo.size, 'white')).getbbox()
logo = logo.crop(box)

def paste_logo(canvas, xy, width):
    mark = logo.resize((width, round(width * logo.height / logo.width)), Image.Resampling.LANCZOS)
    canvas.paste(mark, xy)

icon = Image.new('RGB', (512, 512), 'white')
paste_logo(icon, (80, round((512 - 352 * logo.height / logo.width) / 2)), 352)
icon.save(store / 'graphics/app-icon-512.png')
# Legacy launcher images and the adaptive-icon foreground preserve the same brand mark.
res = root / 'android/app/src/main/res'
for density, size in [('mdpi',48), ('hdpi',72), ('xhdpi',96), ('xxhdpi',144), ('xxxhdpi',192)]:
    folder = res / f'mipmap-{density}'
    folder.mkdir(exist_ok=True)
    icon.resize((size,size), Image.Resampling.LANCZOS).save(folder / 'ic_launcher.png')
    foreground = Image.new('RGBA', (432,432), (255,255,255,0))
    mark = logo.resize((216,round(216*logo.height/logo.width)), Image.Resampling.LANCZOS)
    foreground.paste(mark, ((432-mark.width)//2, (432-mark.height)//2))
    foreground.resize((round(size*2.25),round(size*2.25)), Image.Resampling.LANCZOS).save(folder / 'ic_launcher_foreground.png')
(res / 'mipmap-anydpi-v26').mkdir(exist_ok=True)
(res / 'mipmap-anydpi-v26/ic_launcher.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/ic_launcher_background" />
  <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
''')
(res / 'values/launcher_colors.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<resources><color name="ic_launcher_background">#FFFFFF</color></resources>
''')
slides = [
 ('01-overview', 'OVERVIEW', ['Your money.', 'A clearer picture.'], 'See your balance and progress at a glance.'),
 ('02-transactions', 'TRANSACTIONS', ['Know where', 'your money goes.'], 'Record income. Organise everyday spending.'),
 ('03-budgets', 'BUDGETS', ['Make a plan.', 'Stay on track.'], 'Set spending limits for the things that matter.'),
 ('04-goals', 'SAVINGS GOALS', ['Small steps.', 'Bigger possibilities.'], 'Watch your savings goals take shape.'),
 ('05-debts', 'DEBT TRACKING', ['Keep every', 'repayment clear.'], 'Track what you owe and what you are owed.'),
 ('06-wallets', 'WALLETS', ['Every account.', 'One clear view.'], 'Organise your cash, bank and savings records.'),
]
for stem, label, title, subtitle in slides:
    canvas = Image.new('RGB', (1080,1920), background)
    d = ImageDraw.Draw(canvas)
    d.ellipse((760,-180,1240,300), fill='#E1EAF5')
    d.ellipse((-280,1450,380,2110), fill='#DEEAE7')
    d.text((72,58), f'EINTELIX  /  {label}', font=font(26,True), fill=navy)
    for i, line in enumerate(title):
        size = 82 if len(line) < 20 else 76
        d.text((72,118+i*94), line, font=font(size,True), fill=ink)
    d.text((74,326), subtitle, font=font(29), fill=muted)
    shot = Image.open(store / f'raw/{stem}.png').convert('RGB').resize((800,1422), Image.Resampling.LANCZOS)
    shadow = Image.new('RGBA', canvas.size)
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((126,408,954,1858), radius=40, fill=(20,42,74,55))
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    canvas = Image.alpha_composite(canvas.convert('RGBA'), shadow)
    frame = ImageDraw.Draw(canvas)
    frame.rounded_rectangle((128,394,952,1840), radius=36, fill='white', outline='#CED8E6', width=2)
    mask = Image.new('L', shot.size,0)
    ImageDraw.Draw(mask).rounded_rectangle((0,0,799,1421), radius=24, fill=255)
    canvas.paste(shot,(140,406),mask)
    ImageDraw.Draw(canvas).text((72,1870), 'Eintelix Expense Tracker  •  Illustrative sample records', font=font(23), fill=muted)
    canvas.convert('RGB').save(store / f'screenshots/{stem}.png')

feature = Image.new('RGB',(1024,500),navy)
d = ImageDraw.Draw(feature)
d.ellipse((650,-270,1200,280), fill='#2E4D75')
d.ellipse((770,270,1130,630), fill='#385B80')
d.text((62,58),'EINTELIX EXPENSE TRACKER',font=font(22,True),fill='#CCDBED')
d.text((60,126),'Your money.',font=font(59,True),fill='white')
d.text((60,198),'A clearer picture.',font=font(52,True),fill='white')
d.text((63,299),'Expenses. Budgets. Goals.',font=font(26),fill='#E0EAF7')
d.text((63,339),'Bring your everyday finances together.',font=font(21),fill='#CCDBED')
shot = Image.open(store/'raw/01-overview.png').convert('RGB').resize((246,437), Image.Resampling.LANCZOS)
d.rounded_rectangle((705,35,975,496),radius=25,fill='white')
feature.paste(shot,(717,47))
feature.save(store/'graphics/feature-graphic-1024x500.png')

# A local review gallery keeps exact upload assets easy to inspect.
cards = ''.join(f'<figure><img src="screenshots/{s[0]}.png" alt="{html.escape(s[1])}"><figcaption>{html.escape(s[1])}</figcaption></figure>' for s in slides)
(store/'preview.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Eintelix Play Store assets</title><style>body{font:16px system-ui;background:#eef3f9;color:#233d61;margin:40px}header{max-width:1024px}header img{max-width:100%;border-radius:18px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:22px}figure{margin:0}figure img{width:100%;border-radius:18px}figcaption{padding:12px 0;font-weight:600}</style><header><h1>Eintelix Expense Tracker</h1><p>Google Play asset review · Actual app UI with fictional records</p><img src="graphics/feature-graphic-1024x500.png" alt="Feature graphic"></header><h2>Phone screenshots</h2><div class="grid">'''+cards+'</div></html>')
thumbs = Image.new('RGB',(1080,1120),background)
for i, slide in enumerate(slides):
    im = Image.open(store/f'screenshots/{slide[0]}.png').resize((270,480),Image.Resampling.LANCZOS)
    thumbs.paste(im,(90+(i%3)*315,50+(i//3)*540))
thumbs.save(store/'preview-grid.jpg',quality=90)
manifest = {str(p.relative_to(store)): {'width':Image.open(p).width,'height':Image.open(p).height,'mode':Image.open(p).mode} for p in sorted(store.rglob('*.png'))}
(store/'assets-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Exported six phone screenshots, raw captures, feature graphic, store icon, launcher icons and preview gallery.')
