"""Mutable probe state with one explicit reset boundary."""


class SnapshotContext:
  def __init__(self):
    self.diagnostics = []
    self.reset()

  def reset(self, *, all_containers=True):
    self.services = None
    self.packages = None
    self.containers = None
    self.container_stats = None
    self.container_matches = {}
    self.process_rows = None
    self.socket_lines = None
    self.unit_snapshots = {}
    self.proxy_files = {}
    self.all_containers = all_containers

  def warning(self, code, **details):
    self.diagnostics.append({"code": code, **details})
