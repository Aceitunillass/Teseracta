"""Comprobaciones estructurales sin ejecutar Godot."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class TestStructure(unittest.TestCase):
    def test_core_files_exist(self):
        for path in ["project.godot", "scenes/main.tscn", "scripts/main.gd", "scripts/house.gd", "scripts/pomi_agent.gd", "scripts/sim_state.gd", "scripts/ollama_bridge.gd", "scripts/voice_bridge.gd"]:
            self.assertTrue((ROOT / path).is_file(), path)

    def test_canonical_avatar_present(self):
        self.assertTrue((ROOT / "assets/characters/Pomi_Base_V05_Canonico.glb").is_file())

    def test_local_only_services(self):
        self.assertIn("127.0.0.1", (ROOT / "scripts/ollama_bridge.gd").read_text())
        self.assertIn("127.0.0.1", (ROOT / "voice/server.py").read_text())

    def test_resources_not_committed(self):
        ignore = (ROOT / ".gitignore").read_text()
        self.assertIn("voice/models/", ignore)
        self.assertIn(".venv/", ignore)


if __name__ == "__main__":
    unittest.main()
