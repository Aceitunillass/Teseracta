"""Comprobaciones estáticas de la nueva sala 404.

Estas pruebas NO sustituyen un arranque de Godot ni una prueba con Ollama.
"""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]


def source(filename: str) -> str:
    return (ROOT / filename).read_text(encoding="utf-8")


class Test404Architecture(unittest.TestCase):
    def test_main_scene_is_minimal_room(self):
        self.assertIn('run/main_scene="res://scenes/main404.tscn"', source("project.godot"))
        self.assertIn("res://scripts/main404.gd", source("scenes/main404.tscn"))
        self.assertTrue((ROOT / "scenes/main.tscn").exists(), "legacy scene must remain")

    def test_three_real_needs_and_three_resources(self):
        body = source("scripts/body404.gd")
        room = source("scripts/main404.gd")
        for concept in ("satiety", "energy", "bladder_relief"):
            self.assertIn(concept, body)
        for cube in ("Cubo_comida", "Cubo_cama", "Cubo_vater"):
            self.assertIn(cube, room)
        self.assertIn("food_units -= 1", body)
        self.assertIn("body.interact(should_use)", room)
        self.assertNotIn("propose_action(", room)
        self.assertNotIn("state.execute_action(", room)

    def test_world_controls_actions_and_discards_fiction_as_fact(self):
        bridge = source("scripts/brain404.gd")
        room = source("scripts/main404.gd")
        self.assertIn('"format": schema', bridge)
        self.assertIn('decision_ready.emit(final_decision)', bridge)
        self.assertIn("func _execute_proposal(", room)
        self.assertIn('journal.record("world_event", message', room)
        self.assertIn('journal.record("pomi_utterance", spoken', room)
        self.assertIn('journal.record("private_reflection", reflection', room)
        self.assertNotIn('journal.record("world_event", spoken', room)

    def test_saves_and_old_memories_remain_separate(self):
        room = source("scripts/main404.gd")
        self.assertIn('SAVE_V2 := "user://teseracta_404_save_v2.json"', room)
        self.assertIn('SAVE_V1 := "user://teseracta_save_v1.json"', room)
        self.assertIn("FileAccess.file_exists(SAVE_V1)", room)
        self.assertIn("journal.import_legacy_conversation(", room)
        self.assertNotIn("FileAccess.open(SAVE_V1, FileAccess.WRITE)", room)
        journal = source("scripts/memory_journal.gd")
        self.assertIn('JOURNAL_PATH := "user://pomi_01_memoria.jsonl"', journal)

    def test_local_ministral_and_no_scripted_actions(self):
        config = json.loads(source("config/ai_404.json"))
        self.assertIn(config["model"], ["ministral-3:3b", "ministral-3:8b"])
        room = source("scripts/main404.gd")
        self.assertIn('brain.call("deliberate"', room)
        self.assertIn('"iniciativa_autonoma"', room)
        self.assertIn('if action == "none" or action == "wait":', room)
        prompt = source("config/identity_404.txt")
        self.assertIn("Tu nombre actual es 404", prompt)
        self.assertIn("No confundas", prompt)

    def test_future_vision_is_documented_not_claimed(self):
        guide = source("docs/PROTOTIPO_404.md")
        self.assertIn("Visión futura", guide)
        self.assertIn("no implementada", guide.lower())


    def test_404_chat_preempts_autonomous_thought(self):
        bridge = source("scripts/brain404.gd")
        room = source("scripts/main404.gd")
        self.assertIn("func cancel_autonomous_for_chat() -> bool:", bridge)
        self.assertIn("client.close()", bridge)
        self.assertIn('brain.call("cancel_autonomous_for_chat")', room)
        self.assertIn('chat_retry_at = elapsed_real + 8.0', room)
        self.assertIn('brain.call("seconds_waiting")', room)

    def test_short_runtime_prompt_and_timeout(self):
        bridge = source("scripts/brain404.gd")
        config = json.loads(source("config/ai_404.json"))
        canonical = source("config/identity_404.txt")
        runtime = source("config/identity_404_runtime.txt")
        self.assertIn('const IDENTITY := "res://config/identity_404_runtime.txt"', bridge)
        self.assertLess(len(runtime), len(canonical))
        self.assertLessEqual(config["request_timeout_seconds"], 100)
        self.assertLessEqual(config["context_window"], 3072)

    def test_direct_chat_has_speech_and_stale_requests_cannot_override_it(self):
        brain = source("scripts/brain404.gd")
        room = source("scripts/main404.gd")
        runtime = source("config/identity_404_runtime.txt")
        self.assertIn('speech_schema["minLength"] = 1', brain)
        self.assertIn('var client: HTTPClient = HTTPClient.new()', brain)
        self.assertIn('func _consume_lines() -> void:', brain)
        self.assertIn('func _extract_partial_speech(raw_json: String) -> String:', brain)
        self.assertIn('speech_preview.emit(partial)', brain)
        self.assertIn('"_origin": "direct_message" if direct else "autonomous"', brain)
        self.assertIn("404 no ha emitido ninguna respuesta verbal", room)
        self.assertIn("interaction_type", runtime)
        self.assertIn("NO pongas toda la respuesta únicamente en reflection", runtime)
        self.assertIn("habla: %d caracteres", brain)



    def test_emergency_refill_and_critical_health_pause(self):
        room = source("scripts/main404.gd")
        self.assertIn("func _restock_food() -> void:", room)
        self.assertIn("func _restore_404_health() -> void:", room)
        self.assertIn("func _toggle_simulation_pause() -> void:", room)
        self.assertIn("if body.health <= 10.0:", room)
        self.assertIn('simulation_paused = true', room)
        self.assertIn('body.food_units += 12', room)
        self.assertIn('body.health = 100.0', room)
        self.assertIn('_write_state(false)', room)

    def test_streamed_speech_is_buffered_but_actions_stay_verified(self):
        bridge = source("scripts/brain404.gd")
        room = source("scripts/main404.gd")
        self.assertIn('"stream": true', bridge)
        self.assertIn('speech_preview.emit(partial)', bridge)
        self.assertIn('decision_ready.emit(final_decision)', bridge)
        self.assertIn("func _render_speech_preview() -> void:", room)
        self.assertIn("next_preview_at_ms = now_ms + 700", room)
        self.assertIn('live_reply.add_text("404: " + displayed_speech)', room)
        self.assertIn('journal.record("pomi_utterance", spoken', room)
        self.assertNotIn('journal.record("pomi_utterance", partial', room)



    def test_chat_input_stays_visible_when_more_controls_are_added(self):
        room = source("scripts/main404.gd")
        self.assertIn('controls_scroll.name = "ControlesDesplazables"', room)
        self.assertIn('chat_area.name = "ChatFijo"', room)
        self.assertIn('controls_scroll.add_child(upper)', room)
        self.assertIn('contents.add_child(chat_area)', room)
        self.assertIn('chat_area.add_child(chat_input)', room)
        self.assertNotIn('upper.add_child(chat_input)', room)
        self.assertLess(room.index('contents.add_child(chat_area)'), room.index('chat_area.add_child(chat_input)'))


if __name__ == "__main__":
    unittest.main()
