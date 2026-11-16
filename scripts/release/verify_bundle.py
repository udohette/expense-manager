#!/usr/bin/env python3
"""Audit the AAB and export a signed universal APK for internal smoke testing."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--bundletool', required=True, type=Path)
args = parser.parse_args()
jdk = Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin')
java = str(jdk/'java') if jdk.exists() else 'java'
bundle = root/'build/app/outputs/bundle/release/app-release.aab'
output = root/'build/play-store'
output.mkdir(parents=True,exist_ok=True)
def run(command):
    result = subprocess.run(command, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout.strip()
def bt(*options):
    return run([java,'-jar',str(args.bundletool),*options])
validation = bt('validate',f'--bundle={bundle}')
manifest = bt('dump','manifest',f'--bundle={bundle}','--module=base')
(output/'AndroidManifest.xml').write_text(manifest+'\n')
xml = ET.fromstring(manifest)
android = '{http://schemas.android.com/apk/res/android}'
uses = xml.find('uses-sdk')
application = xml.find('application')
permissions = sorted(e.get(android+'name') for e in xml.findall('uses-permission'))
assert xml.get('package') == 'com.eintelix.expensetracker'
assert int(uses.get(android+'targetSdkVersion')) >= 36
assert 'android.permission.INTERNET' in permissions
assert not any(p in permissions for p in ['android.permission.READ_SMS','android.permission.READ_CONTACTS','com.google.android.gms.permission.AD_ID'])
assert application.get(android+'allowBackup') == 'false'
assert application.get(android+'usesCleartextTraffic') == 'false'
libs=[]
with zipfile.ZipFile(bundle) as archive:
    for name in archive.namelist():
        if not name.endswith('.so'): continue
        data = archive.read(name)
        if data[:4] != b'\x7fELF': continue
        if data[4] != 2:
            libs.append({'path':name,'elf_class':32,'checked_16kb':False})
            continue
        endian = '<' if data[5]==1 else '>'
        offset=struct.unpack_from(endian+'Q',data,32)[0]
        entsize,count=struct.unpack_from(endian+'HH',data,54)
        alignments=[]
        for i in range(count):
            pos=offset+i*entsize
            if struct.unpack_from(endian+'I',data,pos)[0] != 1: continue
            file_offset,virtual=struct.unpack_from(endian+'QQ',data,pos+8)
            alignment=struct.unpack_from(endian+'Q',data,pos+48)[0]
            assert alignment>=16384 and file_offset%16384==virtual%16384, name
            alignments.append(alignment)
        assert alignments, name
        libs.append({'path':name,'elf_class':64,'load_segment_alignments':alignments,'checked_16kb':True})
signature=run([str(jdk/'jarsigner') if jdk.exists() else 'jarsigner','-verify',str(bundle)])
assert 'jar verified' in signature.lower()
config = json.loads(bt('dump','config',f'--bundle={bundle}'))
props={}
for line in (root/'android/key.properties').read_text().splitlines():
    if '=' in line:
        key,value=line.split('=',1)
        props[key]=value
with tempfile.TemporaryDirectory(prefix='eintelix-signing-') as temporary:
    password=Path(temporary)/'store-pass'
    keypass=Path(temporary)/'key-pass'
    for path,value in [(password,props['storePassword']),(keypass,props['keyPassword'])]:
        fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
        with os.fdopen(fd,'w') as stream: stream.write(value)
    keystore=(root/'android/app'/props['storeFile']).resolve()
    apkset=output/'internal-test.apks'
    bt('build-apks',f'--bundle={bundle}',f'--output={apkset}','--mode=universal','--overwrite',
       f'--ks={keystore}',f'--ks-key-alias={props["keyAlias"]}',f'--ks-pass=file:{password}',f'--key-pass=file:{keypass}')
with zipfile.ZipFile(apkset) as archive:
    (output/'internal-test-universal.apk').write_bytes(archive.read('universal.apk'))
sdk=Path(os.environ.get('ANDROID_HOME',Path.home()/'Library/Android/sdk'))
buildtools=sdk/'build-tools/36.0.0'
apk=str(output/'internal-test-universal.apk')
apksign=run([str(buildtools/'apksigner'),'verify','--verbose','--print-certs',apk])
zipalign=run([str(buildtools/'zipalign'),'-c','-P','16','-v','4',apk])
copy=output/'eintelix-expense-tracker-1.0.0+1.aab'
shutil.copy2(bundle,copy)
report={
 'package':xml.get('package'),'version_name':xml.get(android+'versionName'),'version_code':xml.get(android+'versionCode'),
 'target_sdk':uses.get(android+'targetSdkVersion'),'min_sdk':uses.get(android+'minSdkVersion'),
 'permissions':permissions,'allow_backup':application.get(android+'allowBackup'),'cleartext':application.get(android+'usesCleartextTraffic'),
 'bundle_bytes':bundle.stat().st_size,'bundle_sha256':hashlib.sha256(bundle.read_bytes()).hexdigest(),
 'bundle_signature_verified':True,'bundletool_validation':validation,'bundle_config':config,
 'native_libraries':libs,'universal_apk_signature':apksign,'universal_apk_zipalign':zipalign.splitlines()[-1],
 'runtime_smoke_test':'Pending; artifact checks do not prove runtime behavior.',
}
(output/'release-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ['package','version_name','version_code','target_sdk','permissions','bundle_bytes','bundle_sha256','bundle_signature_verified','universal_apk_zipalign']},indent=2))
print('Verified all 64-bit ELF LOAD segments have >=16 KB alignment.')
print(f'Release bundle and audit: {output}')
