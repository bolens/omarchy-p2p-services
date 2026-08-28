import unittest

from backend.p2p_packages import install_command, uninstall_command
from backend.p2p_catalog import AUR_INSTALL_IDS, PACKAGE_HINTS, SERVICES


class PackagePlanTests(unittest.TestCase):
  EXPECTED = {
    "yggdrasil": (["yggdrasil"], False),
    "tailscale": (["tailscale"], False),
    "zerotier": (["zerotier-one"], False),
    "nebula": (["nebula"], False),
    "headscale": (["headscale"], False),
    "netbird": (["netbird"], True),
    "i2pd": (["i2pd", "i2pd-git"], False),
    "i2p": (["i2p"], False),
    "airdcpp": (["airdcpp-webclient"], True),
    "eiskaltdcpp": (["eiskaltdcpp-qt"], True),
    "nicotine": (["nicotine+"], False),
    "deluge": (["deluge"], False),
    "qbittorrent": (["qbittorrent"], False),
    "transmission": (["transmission-gtk", "transmission-cli"], False),
    "aria2": (["aria2"], False),
    "ipfs": (["kubo", "ipfs"], False),
    "syncthing": (["syncthing", "syncthing-git"], False),
    "zeronet": (["zeronet", "zeronet-git"], True),
    "gnunet": (["gnunet"], True),
    "retroshare": (["retroshare-git", "retroshare"], True),
    "cjdns": (["cjdns"], False),
    "lokinet": (["lokinet"], True),
    "veilid": (["veilid", "veilid-server"], True),
    "amule": (["amule", "amuled"], False),
    "slskd": (["slskd-bin"], True),
    "soulseekqt": (["soulseekqt"], True),
    "rtorrent": (["rtorrent"], False),
    "tribler": (["tribler-bin"], True),
    "fragments": (["fragments"], False),
    "webtorrent": (["webtorrent-cli", "webtorrent-desktop"], True),
    "opentracker": (["opentracker"], True),
    "lnd": (["lnd"], True),
    "monerod": (["monero", "monero-git"], False),
  }
  EXTERNAL_ONLY = {
    "netbird-server", "netmaker", "netclient", "freenet", "hyphanet",
    "linuxdcpp", "tahoe", "btfs", "nym", "resilio",
  }

  def test_install_routes_repo_and_aur_packages(self):
    self.assertEqual(install_command("/usr/bin/omarchy","sync",["syncthing"],set()),["/usr/bin/omarchy","pkg","add","syncthing"])
    self.assertEqual(install_command("/usr/bin/omarchy","veilid",["veilid"],{"veilid"}),["/usr/bin/omarchy","pkg","aur","add","veilid"])

  def test_uninstall_uses_exact_package_list(self):
    self.assertEqual(uninstall_command("/usr/bin/omarchy",["syncthing"]),["/usr/bin/omarchy","pkg","drop","syncthing"])

  def test_every_builtin_has_an_explicit_installation_contract(self):
    service_ids = {service["id"] for service in SERVICES}
    self.assertEqual(service_ids, set(self.EXPECTED) | self.EXTERNAL_ONLY)
    self.assertEqual(AUR_INSTALL_IDS, frozenset(service_id for service_id, (_packages, aur) in self.EXPECTED.items() if aur))
    for service_id, (packages, aur) in self.EXPECTED.items():
      with self.subTest(service=service_id):
        self.assertEqual(PACKAGE_HINTS[service_id], packages)
        route = ["/usr/bin/omarchy", "pkg"] + (["aur", "add"] if aur else ["add"])
        self.assertEqual(install_command("/usr/bin/omarchy", service_id, packages, AUR_INSTALL_IDS), route + [packages[0]])
        self.assertEqual(uninstall_command("/usr/bin/omarchy", packages), ["/usr/bin/omarchy", "pkg", "drop"] + packages)
    for service_id in self.EXTERNAL_ONLY:
      with self.subTest(external=service_id):
        self.assertEqual(PACKAGE_HINTS[service_id], [])
        with self.assertRaisesRegex(RuntimeError, "no installation package"):
          install_command("/usr/bin/omarchy", service_id, [], AUR_INSTALL_IDS)


if __name__ == "__main__": unittest.main()
