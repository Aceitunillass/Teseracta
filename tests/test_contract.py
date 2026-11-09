from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

class TeseractaZeroContract(unittest.TestCase):
    def test_scene_and_modules(self):
        self.assertIn('run/main_scene="res://scenes/main.tscn"', read("project.godot"))
        for path in ("scripts/world.gd","scripts/main.gd","scripts/brain.gd","scripts/memory.gd"):
            self.assertTrue((ROOT / path).is_file(), path)
        self.assertIn("WorldScript", read("scripts/main.gd"))
        self.assertIn("func submit_action(command: Dictionary)", read("scripts/world.gd"))

    def test_eko_style_commands_are_world_validated(self):
        world = read("scripts/world.gd")
        for action in ("MoveTo","Stop","Inspect","Use","Wait"):
            self.assertIn('"' + action + '"',world)
        self.assertIn("func observe()",world)
        self.assertIn("func action_api()",world)
        self.assertIn('move_completed',world)

    def test_no_old_code_or_memories_reused(self):
        self.assertFalse((ROOT / "scripts/main404.gd").exists())
        self.assertFalse((ROOT / "scripts/brain404.gd").exists())
        self.assertFalse((ROOT / "config/identity_404.txt").exists())
        mem = read("scripts/memory.gd")
        self.assertIn('user://teseracta_zero/',mem)
        self.assertNotIn('pomi_01_memoria',mem)
        self.assertNotIn('teseracta_404_save_v2',mem)

    def test_editor_agent_memory_debug(self):
        app = read("scripts/main.gd")
        for method in ("_build_editor_tab","_build_agent_tab","_build_memory_tab","_build_debug_tab","_refresh_meshes"):
            self.assertIn("func "+method,app)
        self.assertIn("memory.replace_edited_memories",app)
        self.assertIn("memory.record_event",app)
        self.assertIn("brain.finished.connect",app)
        self.assertIn('"stream": true',read("scripts/brain.gd"))

if __name__ == "__main__":
    unittest.main()
