from pathlib import Path
import importlib.util
import tempfile
import unittest
import json

spec = importlib.util.spec_from_file_location('prepare_test_android', Path(__file__).resolve().parents[1] / 'tools/prepare_test_android.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class TestAndroidIdentity(unittest.TestCase):
    def test_separate_identity_preserves_native_namespace(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture = {
                'www/goyana-v192-test-mode.js': '/* test */',
                'capacitor.config.json': json.dumps({'appId': 'id.goyana.app', 'appName': 'Goyana'}),
                'android/app/build.gradle': 'namespace "id.goyana.app"\napplicationId "id.goyana.app"',
                'android/app/src/main/res/values/strings.xml': '<resources><string name="app_name">Goyana</string><string name="package_name">id.goyana.app</string></resources>',
                'android/app/src/main/AndroidManifest.xml': '<activity android:name=".MainActivity"/>',
            }
            for name, content in fixture.items():
                p = root / name
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(content)
            module.prepare(root)
            self.assertIn('applicationId "id.goyana.app.uji"', (root / 'android/app/build.gradle').read_text())
            self.assertIn('namespace "id.goyana.app"', (root / 'android/app/build.gradle').read_text())
            self.assertIn('Goyana Uji', (root / 'android/app/src/main/res/values/strings.xml').read_text())
            self.assertIn('id.goyana.app.MainActivity', (root / 'android/app/src/main/AndroidManifest.xml').read_text())
            self.assertEqual(json.loads((root / 'capacitor.config.json').read_text())['appId'], 'id.goyana.app.uji')

if __name__ == '__main__':
    unittest.main()
