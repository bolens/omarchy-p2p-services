import importlib.machinery
import importlib.util
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader("p2p_control_test", str(ROOT / "p2p-control"))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
CONTROL = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(CONTROL)


class ControlTestCase(unittest.TestCase):
  def setUp(self):
    # Production deliberately shares a short-lived on-disk inventory cache.
    # Give every test its own cache root so a live plugin run—or an earlier
    # test—cannot bypass the probe being exercised by the current fixture.
    cache_directory = tempfile.TemporaryDirectory()
    original_cache_root = CONTROL.STATUS_CACHE_ROOT
    CONTROL.STATUS_CACHE_ROOT = pathlib.Path(cache_directory.name)
    self.addCleanup(setattr, CONTROL, "STATUS_CACHE_ROOT", original_cache_root)
    self.addCleanup(cache_directory.cleanup)
    CONTROL.reset_discovery()

  def service(self, service_id):
    return next(service for service in CONTROL.SERVICES if service["id"] == service_id)

  def item(self, name, image="", service="", project="", workdir="", config_files=""):
    return {
      "Name": "/" + name,
      "Config": {
        "Image": image,
        "Labels": {
          "com.docker.compose.service": service,
          "com.docker.compose.project": project,
          "com.docker.compose.project.working_dir": workdir,
          "com.docker.compose.project.config_files": config_files,
        },
      },
      "State": {"Running": True},
    }
