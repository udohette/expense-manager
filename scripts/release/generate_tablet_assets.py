#!/usr/bin/env python3
"""Capture actual tablet-sized Flutter layouts; no phone screenshot resizing."""
import html
import json
from pathlib import Path
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFont

root=Path(__file__).resolve().parents[2]
store=root/'store/google-play'
flutter=Path(shutil.which('flutter')).resolve()
sdk=flutter.parents[1]
shots=[('00-bank-alert-import','00-bank-alert-preview'),('01-overview','01-overview'),('02-transactions','02-transactions'),('03-budgets','03-budgets'),('04-goals','04-goals'),('05-debts','05-debts'),('06-wallets','06-wallets')]
for form_factor,expected in [('tablet-7-inch',(1080,1920)),('tablet-10-inch',(1920,1080))]:
    subprocess.run([str(flutter),'test','tool/capture_play_store.dart',f'--dart-define=FLUTTER_SDK={sdk}',f'--dart-define=STORE_FORM_FACTOR={form_factor}','--reporter','expanded'],cwd=root,check=True)
    target=store/form_factor
    target.mkdir(exist_ok=True)
    for name,source in shots:
        with Image.open(store/f'raw/{form_factor}/{source}.png') as im:
            assert im.size==expected,(form_factor,source,im.size)
            im.convert('RGB').save(target/f'{name}.png')
        assert (target/f'{name}.png').stat().st_size<8*1024*1024
    figures=''.join(f'<figure><img src="{name}.png" alt="{html.escape(name)}"><figcaption>{html.escape(name)}</figcaption></figure>' for name,_ in shots)
    (target/'preview.html').write_text(f'<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{form_factor} screenshots</title><style>body{{font:16px system-ui;background:#eef3f9;color:#233d61;padding:24px}}main{{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:24px}}figure{{margin:0}}img{{width:100%;border:1px solid #dce4ee}}figcaption{{padding:12px}}</style><h1>{form_factor} screenshots</h1><p>Actual tablet-sized app layouts with fictional records. Upload PNGs in numbered order.</p><main>{figures}</main></html>')
# Small contact sheets for visual inspection. Source upload files stay full size.
for factor in ['tablet-7-inch','tablet-10-inch']:
    thumb_size=(216,384) if factor=='tablet-7-inch' else (384,216)
    w,h=thumb_size
    sheet=Image.new('RGB',((w+24)*4+24,(h+54)*2+24),'#eef3f9')
    d=ImageDraw.Draw(sheet)
    f=ImageFont.truetype(str(sdk/'bin/cache/artifacts/material_fonts/Roboto-Regular.ttf'),16)
    for i,(name,_) in enumerate(shots):
        with Image.open(store/f'{factor}/{name}.png') as source:
            sheet.paste(source.resize(thumb_size,Image.Resampling.LANCZOS),(24+(i%4)*(w+24),24+(i//4)*(h+54)))
        d.text((24+(i%4)*(w+24),30+(i//4)*(h+54)+h),name,font=f,fill='#233d61')
    sheet.save(store/f'{factor}/preview-grid.jpg',quality=90)
manifest={str(p.relative_to(store)):{'width':Image.open(p).width,'height':Image.open(p).height,'mode':Image.open(p).mode} for p in sorted(store.rglob('*.png'))}
(store/'assets-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Generated and validated seven screenshots for each tablet size.')
