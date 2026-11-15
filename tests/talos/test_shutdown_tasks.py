"""Exercise shutdown ordering with an isolated inventory and a fake talosctl."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ShutdownTasksTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="talos-shutdown-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        (self.root / ".taskfiles/talos").mkdir(parents=True)
        shutil.copyfile(ROOT / ".taskfiles/talos/Taskfile.yaml", self.root / ".taskfiles/talos/Taskfile.yaml")
        (self.root / "talos/clusterconfig").mkdir(parents=True)
        (self.root / "talos/clusterconfig/talosconfig").touch()
        self.inventory = self.root / "talos/talconfig.yaml"
        self.inventory.write_text("nodes:\n" + "".join(
            f"  - ipAddress: 192.168.13.{n}\n    controlPlane: {'true' if n == 14 else 'false'}\n"
            for n in range(11, 15)
        ))
        (self.root / "Taskfile.yaml").write_text('''version: "3"
vars:
  TALOS_DIR: "{{.ROOT_DIR}}/talos"
  TALOSCONFIG: "{{.ROOT_DIR}}/talos/clusterconfig/talosconfig"
includes:
  talos: .taskfiles/talos
''')
        binary_dir = self.root / "bin"
        binary_dir.mkdir()
        stub = binary_dir / "talosctl"
        stub.write_text(f"#!{sys.executable}\n" + '''import json, os, sys
with open(os.environ["TALOS_TEST_LOG"], "a") as log:
    log.write(json.dumps(sys.argv[1:]) + "\\n")
if "shutdown" in sys.argv and "--nodes" in sys.argv:
    node = sys.argv[sys.argv.index("--nodes") + 1]
    if node == os.environ.get("TALOS_TEST_FAIL_NODE"):
        sys.exit(42)
''')
        stub.chmod(0o755)
        self.log = self.root / "calls.jsonl"
        self.env = dict(os.environ, PATH=f"{binary_dir}{os.pathsep}{os.environ['PATH']}",
                        TALOS_TEST_LOG=str(self.log))
        self.env.pop("TALOS_TEST_FAIL_NODE", None)
        self.assertEqual(shutil.which("talosctl", path=self.env["PATH"]), str(stub))

    def run_task(self, name, *args):
        return subprocess.run(["task", "--yes", name, *args], cwd=self.root,
                              env=self.env, capture_output=True, text=True, timeout=20)

    def shutdown_calls(self):
        if not self.log.exists():
            return []
        return [args for line in self.log.read_text().splitlines()
                if "shutdown" in (args := json.loads(line))]

    def test_cluster_order_wait_and_endpoints(self):
        result = self.run_task("talos:shutdown-cluster")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.shutdown_calls()
        self.assertEqual([a[a.index("--nodes") + 1] for a in calls],
                         [f"192.168.13.{n}" for n in range(11, 15)])
        for args in calls:
            self.assertIn("--wait=true", args)
            self.assertIn("--timeout=30m", args)
            self.assertEqual(args[args.index("--endpoints") + 1], "192.168.13.14")
            self.assertEqual(args[args.index("--talosconfig") + 1],
                             str(self.root / "talos/clusterconfig/talosconfig"))

    def test_worker_failure_prevents_control_plane_shutdown(self):
        self.env["TALOS_TEST_FAIL_NODE"] = "192.168.13.12"
        result = self.run_task("talos:shutdown-cluster")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([a[a.index("--nodes") + 1] for a in self.shutdown_calls()],
                         ["192.168.13.11", "192.168.13.12"])

    def test_empty_control_plane_inventory_prevents_shutdown(self):
        self.inventory.write_text(self.inventory.read_text().replace("controlPlane: true", "controlPlane: false"))
        self.assertNotEqual(self.run_task("talos:shutdown-workers").returncode, 0)
        self.assertEqual(self.shutdown_calls(), [])

    def test_timeout_override(self):
        result = self.run_task("talos:shutdown-control-plane", "SHUTDOWN_TIMEOUT=10m")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.shutdown_calls()), 1)
        self.assertIn("--timeout=10m", self.shutdown_calls()[0])


if __name__ == "__main__":
    unittest.main()
