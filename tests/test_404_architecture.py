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

    def test_local_model_and_no_scripted_actions(self):
        config = json.loads(source("config/ai_404.json"))
        # No fijar la prueba a un modelo: el usuario compara Qwen y Ministral.
        self.assertIsInstance(config["model"], str)
        self.assertTrue(config["model"].strip())
        room = source("scripts/main404.gd")
        self.assertIn('brain.call("deliberate"', room)
        self.assertIn('"iniciativa_autonoma"', room)
        self.assertIn('if action == "none":', room)
        self.assertIn('if action == "wait":', room)
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
        self.assertIn('transcript_lines[pending_reply_index] = "404: " + displayed_speech', room)
        self.assertIn('transcript_lines[pending_reply_index] = "404: " + spoken', room)
        self.assertIn('speech_preview.emit(partial)', bridge)
        self.assertNotIn("live_reply = RichTextLabel.new()", room)
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


    def test_autonomous_and_direct_speech_share_one_live_transcript(self):
        room = source("scripts/main404.gd")
        brain = source("scripts/brain404.gd")
        self.assertIn('func _render_transcript() -> void:', room)
        self.assertIn('transcript_lines.append("404: ")', room)
        self.assertIn('transcript_lines[pending_reply_index] = "404: " + displayed_speech', room)
        self.assertIn('transcript_lines[pending_reply_index] = "404: " + spoken', room)
        self.assertIn('dialogue.text = "\\n".join(PackedStringArray(transcript_lines)) + "\\n"', room)
        self.assertIn('_clear_speech_preview()\n            _event("Reflexión autónoma', room)
        self.assertNotIn('live_reply', room)
        self.assertIn('var partial: String = _extract_partial_speech(assembled_answer)', brain)
        self.assertNotIn('if active_trigger.begins_with("mensaje_del_interlocutor"):', brain)


    def test_chat_uses_real_dialogue_turns_from_autobiography(self):
        journal = source("scripts/memory_journal.gd")
        room = source("scripts/main404.gd")
        bridge = source("scripts/brain404.gd")
        self.assertIn("func recent_dialogue(limit: int = 8)", journal)
        self.assertIn('if kind == "player_utterance":', journal)
        self.assertIn('elif kind == "pomi_utterance":', journal)
        self.assertIn("recent.reverse()", journal)
        self.assertIn("journal.recent_dialogue(8)", room)
        self.assertIn('journal.recall(memory_query, 4)', room)
        self.assertIn("incoming_message: String", room)
        self.assertIn("conversation_history: Array[Dictionary]", bridge)
        self.assertIn('"messages": messages', bridge)
        self.assertIn('messages.append({"role": "user", "content": incoming_message.substr(0, 450)})', bridge)
        self.assertIn("El diario conserva más episodios", room)
        self.assertNotIn('FileAccess.open(JOURNAL_PATH, FileAccess.WRITE)', room)

    def test_opaque_panel_does_not_bleed_world_into_chat(self):
        room = source("scripts/main404.gd")
        self.assertIn("var solid_panel := StyleBoxFlat.new()", room)
        self.assertIn('solid_panel.bg_color = Color("171a29")', room)
        self.assertIn('panel.add_theme_stylebox_override("panel", solid_panel)', room)
        self.assertIn('sign_label.no_depth_test = false', room)
        self.assertIn('dialogue.add_theme_font_size_override("normal_font_size", 16)', room)



    def test_body_can_walk_with_critical_needs_but_not_zero_health(self):
        body = source("scripts/body404.gd")
        room = source("scripts/main404.gd")
        identity = source("config/identity_404_runtime.txt")
        self.assertIn("if health <= 0.0:", body)
        self.assertIn("return clampf(0.4 + 0.6", body)
        self.assertIn("movimiento_posible_ahora", room)
        self.assertIn("motivo_si_no_puede_moverse", room)
        self.assertIn("protocolo_de_accion", room)
        self.assertIn('if action == "use" and target == "center":', room)
        self.assertIn('use_after_walk = target if action == "use" else ""', room)
        self.assertIn("body.interact(should_use)", room)
        self.assertIn('action="move"', identity)
        self.assertIn('action="use"', identity)
        self.assertIn("DECIR «me muevo»", identity)
        self.assertIn("La fatiga reduce tu velocidad", identity)
        self.assertNotIn("if satiety <= 0.0:", body)
        self.assertNotIn("if bladder_relief <= 0.0:", body)



    def test_measured_movement_is_verified_evidence_not_a_scripted_belief(self):
        room = source("scripts/main404.gd")
        journal = source("scripts/memory_journal.gd")
        identity = source("config/identity_404_runtime.txt")
        self.assertIn('var walk_start_position: Vector3 = Vector3.ZERO', room)
        self.assertIn('walk_start_position = pomi.position', room)
        self.assertIn('walk_start_position.distance_to(pomi.position)', room)
        self.assertIn('actual_distance > 0.01:', room)
        self.assertIn('partial_distance > 0.01:', room)
        self.assertIn('Desplazamiento comprobado: Godot midió %.2f metros', room)
        self.assertIn('journal.record("world_event", message', room)
        self.assertIn('journal.movement_evidence(2)', room)
        self.assertIn('func movement_evidence(limit: int = 2)', journal)
        self.assertIn('if str(entry.get("kind", "")) != "world_event":', journal)
        self.assertIn('content.begins_with("Desplazamiento comprobado:")', journal)
        self.assertIn('procedencia": "observacion_confirmada"', journal)
        self.assertIn('puedes revisar tu hipótesis', identity)
        self.assertIn('no demuestra tener cuerpo biológico exterior ni conciencia', identity)
        self.assertNotIn('if action == "move":\n        _result("Desplazamiento comprobado:', room)



if __name__ == "__main__":
    unittest.main()
