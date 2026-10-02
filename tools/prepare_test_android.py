"""Give the test APK its own installation identity after the standard APK is built."""
from pathlib import Path
import json
import re

def prepare(root):
    root = Path(root)
    assert (root / 'www/goyana-v192-test-mode.js').is_file(), 'Test-mode assets are required'
    config_path = root / 'capacitor.config.json'
    config = json.loads(config_path.read_text())
    assert config['appId'] == 'id.goyana.app'
    config.update(appId='id.goyana.app.uji', appName='Goyana Uji')
    config_path.write_text(json.dumps(config, indent=2) + '\n')
    gradle = root / 'android/app/build.gradle'
    text, count = re.subn(r'applicationId\s+"id\.goyana\.app"', 'applicationId "id.goyana.app.uji"', gradle.read_text())
    assert count == 1, 'Expected one applicationId'
    gradle.write_text(text)
    strings = root / 'android/app/src/main/res/values/strings.xml'
    text = strings.read_text().replace('id.goyana.app', 'id.goyana.app.uji')
    text = re.sub(r'(<string name="(?:app_name|title_activity_main)">)[^<]*(</string>)', r'\1Goyana Uji\2', text)
    strings.write_text(text)
    manifest = root / 'android/app/src/main/AndroidManifest.xml'
    manifest.write_text(manifest.read_text().replace('android:name=".MainActivity"', 'android:name="id.goyana.app.MainActivity"'))

if __name__ == '__main__':
    import sys
    prepare(sys.argv[1] if len(sys.argv) > 1 else 'app')
