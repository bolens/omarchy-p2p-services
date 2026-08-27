import unittest

from backend.p2p_catalog import AUR_INSTALL_IDS, DOCKER_ALIASES, PACKAGE_HINTS, SERVICES
from backend.p2p_registry import normalize_custom_services, validate_registry


class RegistryTests(unittest.TestCase):
  def service(self, service_id="alpha"):
    return dict(id=service_id,name="Alpha",icon="a",category="Test",commands=["alpha"],processes=["alpha"],units=[],config="",web="")

  def test_registry_rejects_duplicate_ids(self):
    with self.assertRaises(ValueError): validate_registry([self.service(),self.service()], [], [], [])

  def test_builtin_catalog_is_self_consistent(self):
    service_ids = validate_registry(SERVICES, PACKAGE_HINTS, DOCKER_ALIASES, AUR_INSTALL_IDS)
    self.assertEqual(service_ids, frozenset(service["id"] for service in SERVICES))
    self.assertTrue(all(service["category"] for service in SERVICES))

  def test_registry_rejects_invalid_rows_and_dangling_metadata(self):
    missing = self.service(); del missing["icon"]
    with self.assertRaisesRegex(ValueError, "missing icon"):
      validate_registry([missing], [], [], [])
    invalid = self.service(); invalid["commands"] = [""]
    with self.assertRaisesRegex(TypeError, "non-empty strings"):
      validate_registry([invalid], [], [], [])
    with self.assertRaisesRegex(ValueError, "unknown ids"):
      validate_registry([self.service()], ["absent"], [], [])

  def test_custom_services_are_bounded_and_normalized(self):
    rows=[{"id":"custom-node","name":"Node","commands":["node"],"processes":[],"units":[],"web":"https://node.test"}]
    result=normalize_custom_services(rows,{"built-in"})
    self.assertEqual(result[0]["id"],"custom-node")
    self.assertEqual(result[0]["web"],"https://node.test")
    self.assertEqual(result[0]["category"],"Custom")
    self.assertTrue(result[0]["custom"])
    self.assertFalse(result[0]["controllable"])


if __name__ == "__main__": unittest.main()
