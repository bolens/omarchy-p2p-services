import unittest

from backend.p2p_lifecycle import classify_systemd_restart_log, normalize_container_event, select_restart_kind


class LifecycleEventTests(unittest.TestCase):
  def service(self):
    return [{"id": "syncthing", "units": [], "commands": [], "processes": []}]

  def test_docker_exit_and_oom_events_keep_only_safe_service_evidence(self):
    crash = normalize_container_event("docker", {
      "Action": "die", "time": 100,
      "Actor": {"Attributes": {"name": "sync", "image": "syncthing/syncthing:latest", "exitCode": "7"}},
    }, self.service(), {"syncthing": ["syncthing", "sync"]})
    oom = normalize_container_event("docker", {
      "Action": "oom", "time": 101,
      "Actor": {"Attributes": {"name": "sync", "image": "syncthing/syncthing:latest"}},
    }, self.service(), {"syncthing": ["syncthing", "sync"]})
    self.assertEqual(crash, {"serviceId": "syncthing", "kind": "crash", "cause": "exit-code", "at": 100})
    self.assertEqual(oom, {"serviceId": "syncthing", "kind": "oom", "cause": "oom", "at": 101})

  def test_container_health_and_replacement_events_are_not_called_crashes(self):
    unhealthy = normalize_container_event("podman", {
      "Status": "health_status: unhealthy", "Time": 200,
      "Attributes": {"name": "sync", "image": "syncthing/syncthing"},
    }, self.service(), {"syncthing": ["syncthing", "sync"]})
    replaced = normalize_container_event("docker", {
      "Action": "create", "time": 201,
      "Actor": {"Attributes": {"name": "sync", "image": "syncthing/syncthing"}},
    }, self.service(), {"syncthing": ["syncthing", "sync"]})
    self.assertEqual(unhealthy["kind"], "unhealthy")
    self.assertEqual(replaced["kind"], "replaced")

  def test_unknown_or_sensitive_container_events_are_discarded(self):
    event = {"Action": "die", "Actor": {"Attributes": {"name": "private-name", "image": "private/image", "exitCode": "1"}}}
    self.assertIsNone(normalize_container_event("docker", event, self.service(), {"syncthing": ["syncthing"]}))

  def test_latest_restart_sequence_owns_container_classification(self):
    self.assertEqual(select_restart_kind(["crash","restart","clean-exit","restart"]), "restart")
    self.assertEqual(select_restart_kind(["restart","oom","crash","restart"]), "crash")
    self.assertEqual(select_restart_kind(["updated","restart"]), "update")

  def test_systemd_restart_log_classification_is_owned_by_lifecycle_module(self):
    self.assertEqual(classify_systemd_restart_log("Update needed, exiting\nScheduled restart job"), "update")
    self.assertEqual(classify_systemd_restart_log("Main process exited\nScheduled restart job"), "crash")
    self.assertEqual(classify_systemd_restart_log("Scheduled restart job"), "restart")
