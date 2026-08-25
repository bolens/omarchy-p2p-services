import unittest

from p2p_validation import safe_console_host, safe_http_url


class ValidationTests(unittest.TestCase):
  def test_http_urls_reject_credentials_controls_and_non_http_schemes(self):
    self.assertEqual(safe_http_url("https://node.example.test:8443/path"), "https://node.example.test:8443/path")
    for value in ("javascript:alert(1)", "https://user:pass@example.test/", "https://example.test:\u0001/", "https://example.test:99999/", "http://[::1"):
      self.assertEqual(safe_http_url(value), "")

  def test_console_hosts_accept_addresses_and_dns_without_paths(self):
    for value in ("node.home.arpa", "192.168.1.10", "[::1]"):
      self.assertEqual(safe_console_host(value), value)
    for value in ("node.home/path", "user@node.home", "-bad.home", "node.home:8080"):
      self.assertEqual(safe_console_host(value), "")


if __name__ == "__main__": unittest.main()
