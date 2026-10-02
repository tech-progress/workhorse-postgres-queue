import copy
import contextlib
import io
import importlib.util
import json
import os
import pathlib
import stat
import tempfile
import unittest
from unittest.mock import patch

root = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("draft_tools", root / "scripts/draft_tools.py")
tools = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tools)


class DraftTests(unittest.TestCase):
    def setUp(self):
        self.expected = tools.contract(root, os.environ["VERIFY_GRAPH"])
        self.seed = {"services": {}}
        for index, name in enumerate(self.expected[0]):
            service = {"name": name, "source": {"image": "obsolete-seed"}, "volumeMounts": {}}
            if name in self.expected[4]:
                service["volumeMounts"]["local-fixture-volume-" + str(index)] = {"mountPath": "/wrong", "sizeMB": 1}
            self.seed["services"]["local-fixture-service-" + str(index)] = service

    def test_roundtrip_repairs_seed_sources_and_preserves_ids(self):
        restored = tools.restore(self.seed, self.expected)
        tools.audit(restored, self.expected)
        self.assertEqual(set(restored["services"]), set(self.seed["services"]))
        for service in restored["services"].values():
            self.assertFalse(service["source"].get("image") and service["source"].get("repo"))

    def test_cli_output_is_exclusive_and_private(self):
        with tempfile.TemporaryDirectory() as temporary:
            input_path = pathlib.Path(temporary) / "seed.json"
            output_path = pathlib.Path(temporary) / "draft.json"
            input_path.write_text(json.dumps(self.seed))
            arguments = ["draft-tools", "restore", str(input_path), os.environ["VERIFY_GRAPH"], str(output_path)]
            with patch("sys.argv", arguments), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(tools.main(), 0)
            self.assertEqual(stat.S_IMODE(output_path.stat().st_mode), 0o600)
            tools.audit(json.loads(output_path.read_text()), self.expected)
            with patch("sys.argv", arguments), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(tools.main(), 1)

    def test_roundtrip_repeated_is_idempotent(self):
        restored = tools.restore(self.seed, self.expected)
        self.assertEqual(tools.restore(restored, self.expected), restored)
        tools.audit(restored, self.expected)
        self.assertEqual(set(restored["services"]), set(self.seed["services"]))
        for service in restored["services"].values():
            self.assertFalse(service["source"].get("image") and service["source"].get("repo"))

    def test_rejects_extra_service_and_missing_durable_volume(self):
        wrong = copy.deepcopy(self.seed)
        wrong["services"]["extra"] = {"name": "Extra"}
        with self.assertRaises(tools.ContractError):
            tools.restore(wrong, self.expected)
        service = next(value for value in self.seed["services"].values() if value["name"] in self.expected[4])
        service["volumeMounts"] = {}
        with self.assertRaises(tools.ContractError):
            tools.restore(self.seed, self.expected)

    def test_rejects_public_tcp_and_secret_leaks(self):
        restored = tools.restore(self.seed, self.expected)
        service = next(iter(restored["services"].values()))
        service["networking"]["tcpProxies"] = {"5432": {}}
        with self.assertRaises(tools.ContractError):
            tools.audit(restored, self.expected)
        service["networking"]["tcpProxies"] = {}
        next(iter(service["variables"].values()))["value"] = "must-not-be-printed"
        with self.assertRaises(tools.ContractError) as failure:
            tools.audit(restored, self.expected)
        self.assertNotIn("must-not-be-printed", str(failure.exception))

    def test_rejects_source_command_and_volume_drift(self):
        for field in ["source", "deploy"]:
            restored = tools.restore(self.seed, self.expected)
            next(iter(restored["services"].values()))[field] = {}
            with self.assertRaises(tools.ContractError):
                tools.audit(restored, self.expected)
        restored = tools.restore(self.seed, self.expected)
        durable = next(value for value in restored["services"].values() if value["name"] in self.expected[4])
        next(iter(durable["volumeMounts"].values()))["mountPath"] = "/wrong"
        with self.assertRaises(tools.ContractError):
            tools.audit(restored, self.expected)


if __name__ == "__main__":
    unittest.main()
