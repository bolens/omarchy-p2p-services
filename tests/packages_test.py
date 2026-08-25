import unittest

from p2p_packages import install_command, uninstall_command


class PackagePlanTests(unittest.TestCase):
  def test_install_routes_repo_and_aur_packages(self):
    self.assertEqual(install_command("/usr/bin/omarchy","sync",["syncthing"],set()),["/usr/bin/omarchy","pkg","add","syncthing"])
    self.assertEqual(install_command("/usr/bin/omarchy","veilid",["veilid"],{"veilid"}),["/usr/bin/omarchy","pkg","aur","add","veilid"])

  def test_uninstall_uses_exact_package_list(self):
    self.assertEqual(uninstall_command("/usr/bin/omarchy",["syncthing"]),["/usr/bin/omarchy","pkg","drop","syncthing"])


if __name__ == "__main__": unittest.main()
