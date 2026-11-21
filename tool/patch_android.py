"""Patches the generated Android project for Smart Track (run after `flutter create`)."""
import re
import sys

path = 'android/app/src/main/AndroidManifest.xml'
xml = open(path, encoding='utf-8').read()

perms = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.POST_NOTIFICATIONS',
]
add = ''.join(
    f'    <uses-permission android:name="{p}"/>\n'
    for p in perms if p not in xml
)
if add:
    xml = re.sub(r'(<manifest[^>]*>\s*)', lambda m: m.group(1) + '\n' + add, xml, count=1)

# The ESP32 speaks plain HTTP on the local network.
if 'usesCleartextTraffic' not in xml:
    xml = xml.replace('<application', '<application android:usesCleartextTraffic="true"', 1)

xml = re.sub(r'android:label="[^"]*"', 'android:label="Smart Track"', xml, count=1)
open(path, 'w', encoding='utf-8').write(xml)
print('Patched', path)
if 'usesCleartextTraffic' not in xml or 'INTERNET' not in xml:
    sys.exit('Manifest patch failed')
