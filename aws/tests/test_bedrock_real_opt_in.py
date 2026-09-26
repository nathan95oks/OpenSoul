"""Integración real opt-in; la suite ordinaria continúa usando mocks."""

import json
import os
import subprocess
import sys
import unittest

ENV_FLAG = "RUN_BEDROCK_REAL_TESTS"
TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(TESTS_DIR, "..", ".."))


@unittest.skipUnless(os.environ.get(ENV_FLAG) == "1",
                     f"requiere {ENV_FLAG}=1 y credenciales AWS")
class BedrockRealOptIn(unittest.TestCase):
    def test_conversation_router_uses_real_bedrock(self):
        completed = subprocess.run(
            [sys.executable, os.path.join(TESTS_DIR, "bedrock_real_probe.py")],
            cwd=PROJECT_ROOT,
            env=os.environ.copy(),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=120,
            check=False,
        )
        self.assertEqual(0, completed.returncode,
                         completed.stderr or completed.stdout)
        output = [line for line in completed.stdout.splitlines() if line.strip()]
        self.assertTrue(output, "El probe no devolvió resultado.")
        payload = json.loads(output[-1])
        self.assertIn("modelId", payload)
        self.assertGreaterEqual(payload["confidence"], 0)
        self.assertLessEqual(payload["confidence"], 1)


if __name__ == "__main__":
    unittest.main()
