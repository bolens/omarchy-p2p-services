import hashlib
import importlib.util
from importlib.machinery import SourceFileLoader
import pathlib
import struct
import tempfile
import unittest


ROOT = pathlib.Path(__file__).parents[1]
SCRIPT = ROOT/"scripts/update-screenshot-metadata"
SPEC = importlib.util.spec_from_loader("screenshot_metadata", SourceFileLoader("screenshot_metadata", str(SCRIPT)))
METADATA = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(METADATA)


def png_header(width, height):
  return METADATA.PNG_SIGNATURE + b"\0\0\0\rIHDR" + struct.pack(">II", width, height)


class ScreenshotMetadataTests(unittest.TestCase):
  def test_html_dimensions_and_readme_digests_are_updated_idempotently(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory); assets = root/"docs"; assets.mkdir()
      image = assets/"main.png"; image.write_bytes(png_header(812, 643))
      html = assets/"index.html"; html.write_text('<img src="main.png" width="1" height="2">\n')
      readme = root/"README.md"; readme.write_text('![Main](docs/main.png?v=deadbeef)\n')

      METADATA.update_html(html, assets)
      METADATA.update_readme(readme)
      first_html, first_readme = html.read_text(), readme.read_text()
      METADATA.update_html(html, assets)
      METADATA.update_readme(readme)

      self.assertIn('width="812" height="643"', first_html)
      digest = hashlib.sha256(image.read_bytes()).hexdigest()[:12]
      self.assertIn(f"docs/main.png?v={digest}", first_readme)
      self.assertEqual((html.read_text(), readme.read_text()), (first_html, first_readme))

  def test_invalid_or_ambiguous_html_does_not_modify_the_document(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory); image = root/"main.png"; image.write_bytes(png_header(20, 30))
      html = root/"index.html"
      original = '<img src="main.png" width="1" height="2"><img src="main.png" width="3" height="4">'
      html.write_text(original)
      with self.assertRaisesRegex(ValueError, "expected one"):
        METADATA.update_html(html, root)
      self.assertEqual(html.read_text(), original)

      image.write_bytes(b"not a png")
      with self.assertRaisesRegex(ValueError, "not a PNG"):
        METADATA.update_html(html, root)
      self.assertEqual(html.read_text(), original)


if __name__ == "__main__": unittest.main()
