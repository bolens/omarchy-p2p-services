import unittest

from p2p_metrics import parse_netio, parse_size


class MetricsTests(unittest.TestCase):
  def test_decimal_and_binary_sizes(self):
    self.assertEqual(parse_size("1.5MB"), 1_500_000)
    self.assertEqual(parse_size("2MiB"), 2 * 1024 * 1024)

  def test_netio_requires_receive_and_transmit_values(self):
    self.assertEqual(parse_netio("1.5MB / 2MiB"), (1_500_000, 2 * 1024 * 1024))
    self.assertEqual(parse_netio("n/a"), (0, 0))


if __name__ == "__main__": unittest.main()
