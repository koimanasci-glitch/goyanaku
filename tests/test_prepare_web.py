"""Prevent patch tags from corrupting the JavaScript used to print receipts."""
from pathlib import Path
import importlib.util
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('prepare_web', ROOT / 'tools/prepare_web.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class PrepareWebTests(unittest.TestCase):
    def test_receipt_body_string_is_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); source = root / 'source'; source.mkdir()
            receipt = "<script>const receipt='<body>receipt</body></html>';</script>"
            original = '<html><body>' + receipt + '</body></html>'
            (source / 'index.html').write_text(original)
            for name in module.PATCHES:
                (source / name).write_text('/* test */')
            result = module.prepare(source, root / 'output')
            self.assertIn(receipt, result)
            self.assertGreater(result.index('<script src='), result.index(receipt) + len(receipt) - 1)
            # Preparing an already prepared input must not duplicate the loaders.
            again = module.prepare(root / 'output', root / 'second')
            for name in module.PATCHES:
                self.assertEqual(again.count(f'<script src="{name}"></script>'), 1)

    def test_real_app_has_all_patches_at_document_end(self):
        with tempfile.TemporaryDirectory() as directory:
            result = module.prepare(ROOT, Path(directory))
            tail = result[result.rfind('<script src='):]
            self.assertIn('</body>', tail)
            self.assertTrue(result.strip().endswith('</html>'))

    def test_test_mode_is_excluded_from_standard_and_removed_on_rebuild(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            normal = module.prepare(ROOT, target)
            self.assertNotIn(module.TEST_PATCH, normal)
            self.assertFalse((target / module.TEST_PATCH).exists())
            test = module.prepare(ROOT, target, test_mode=True)
            self.assertEqual(test.count(f'<script src="{module.TEST_PATCH}"></script>'), 1)
            self.assertTrue((target / module.TEST_PATCH).exists())
            normal = module.prepare(ROOT, target)
            self.assertNotIn(module.TEST_PATCH, normal)
            self.assertFalse((target / module.TEST_PATCH).exists())

if __name__ == '__main__':
    unittest.main()
