#!/usr/bin/env python3
"""Generate a private upload key for a FIRST release. Never overwrites a key."""
import os
from pathlib import Path
import secrets
import shutil
import subprocess

root = Path(__file__).resolve().parents[2]
properties = root / 'android/key.properties'
keystore = root / 'android/keystore/upload-keystore.jks'
if properties.exists() or keystore.exists():
    raise SystemExit('Signing files already exist. Keep the existing key; refusing to overwrite.')
keytool = shutil.which('keytool')
studio_keytool = Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool')
if studio_keytool.exists():
    keytool = str(studio_keytool)
if not keytool:
    raise SystemExit('Install a JDK with keytool first.')
keystore.parent.mkdir(parents=True, exist_ok=True)
os.chmod(keystore.parent, 0o700)
password = secrets.token_urlsafe(36)
env = dict(os.environ, EINTELIX_UPLOAD_PASSWORD=password)
subprocess.run([
    keytool, '-genkeypair', '-v', '-keystore', str(keystore),
    '-storetype', 'JKS', '-keyalg', 'RSA', '-keysize', '4096', '-validity', '10000',
    '-alias', 'upload', '-storepass:env', 'EINTELIX_UPLOAD_PASSWORD',
    '-keypass:env', 'EINTELIX_UPLOAD_PASSWORD',
    '-dname', 'CN=Eintelix Expense Tracker, O=Eintelix Innovations Limited, C=NG',
], check=True, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
os.chmod(keystore, 0o600)
fd = os.open(properties, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, 'w') as output:
    output.write(f'storePassword={password}\nkeyPassword={password}\nkeyAlias=upload\nstoreFile=../keystore/upload-keystore.jks\n')
certificate = root / 'store/google-play/upload-certificate.pem'
subprocess.run([
    keytool, '-exportcert', '-rfc', '-keystore', str(keystore), '-alias', 'upload',
    '-storepass:env', 'EINTELIX_UPLOAD_PASSWORD', '-file', str(certificate),
], check=True, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
certificate.write_text(certificate.read_text())  # Normalize keytool's PEM line endings.
print('Created private android/keystore/upload-keystore.jks and android/key.properties (mode 0600).')
print('Public certificate: store/google-play/upload-certificate.pem')
print('Back up BOTH private files in your password manager / encrypted offline storage. Never commit or share them.')
