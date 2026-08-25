import unittest

from p2p_actions import container_action_commands, systemd_action_command


class ActionPlanTests(unittest.TestCase):
  def test_container_commands_group_runtime_and_exclude_init(self):
    items=[
      {"Name":"/sync","_runtime":"docker","_runtime_cmd":"/usr/bin/docker","State":{"Running":True}},
      {"Name":"/sync-init","_runtime":"docker","_runtime_cmd":"/usr/bin/docker","State":{"Running":True}},
    ]
    self.assertEqual(container_action_commands(items,"restart"),[["/usr/bin/docker","restart","sync"]])

  def test_start_and_stop_plans_skip_containers_already_in_target_state(self):
    running = {"Name":"/running","_runtime":"docker","_runtime_cmd":"/usr/bin/docker","State":{"Running":True}}
    stopped = {"Name":"/stopped","_runtime":"docker","_runtime_cmd":"/usr/bin/docker","State":{"Running":False}}
    self.assertEqual(container_action_commands([running, stopped], "start"), [["/usr/bin/docker", "start", "stopped"]])
    self.assertEqual(container_action_commands([running, stopped], "stop"), [["/usr/bin/docker", "stop", "running"]])

  def test_systemd_command_preserves_scope(self):
    self.assertEqual(systemd_action_command("/usr/bin/systemctl","sync.service",True,"stop"),["/usr/bin/systemctl","--user","stop","sync.service"])
    self.assertEqual(systemd_action_command("/usr/bin/systemctl","sync.service",False,"open"),[])


if __name__ == "__main__": unittest.main()
