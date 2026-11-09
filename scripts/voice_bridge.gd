extends Node
signal transcript_ready(text: String)
signal voice_error(text: String)
signal record_state_changed(active: bool)

const TRANSCRIBE_URL := "http://127.0.0.1:8765/transcribe"
var recorder: AudioEffectRecord
var microphone: AudioStreamPlayer
var http: HTTPRequest
var active: bool = false
var busy: bool = false

func _ready() -> void:
    # Bus dedicado, grabación PCM 16-bit y sin reproducción audible (sin feedback).
    var bus_name := "PomiMic"
    var bus_idx := AudioServer.get_bus_index(bus_name)
    if bus_idx == -1:
        AudioServer.add_bus()
        bus_idx = AudioServer.get_bus_count() - 1
        AudioServer.set_bus_name(bus_idx, bus_name)
    AudioServer.set_bus_volume_db(bus_idx, -80.0)
    recorder = AudioEffectRecord.new()
    recorder.format = AudioEffectRecord.FORMAT_16_BITS
    AudioServer.add_bus_effect(bus_idx, recorder)
    microphone = AudioStreamPlayer.new()
    microphone.stream = AudioStreamMicrophone.new()
    microphone.bus = bus_name
    add_child(microphone)
    http = HTTPRequest.new()
    http.timeout = 45.0
    add_child(http)
    http.request_completed.connect(_on_completed)

func toggle_recording() -> void:
    if busy:
        voice_error.emit("Todavía estoy transcribiendo.")
        return
    if active:
        stop_recording()
    else:
        start_recording()

func start_recording() -> void:
    if active:
        return
    microphone.play()
    recorder.set_recording_active(true)
    active = true
    record_state_changed.emit(true)

func stop_recording() -> void:
    if not active:
        return
    recorder.set_recording_active(false)
    microphone.stop()
    active = false
    record_state_changed.emit(false)
    var recording: AudioStreamWAV = recorder.get_recording()
    if recording == null or recording.data.size() < 500:
        voice_error.emit("La grabación está vacía. Comprueba el permiso del micrófono en Windows.")
        return
    var wav_file := "user://pomi_ultima_voz.wav"
    if recording.save_to_wav(wav_file) != OK:
        voice_error.emit("No se pudo guardar el WAV local.")
        return
    var buffer: PackedByteArray = FileAccess.get_file_as_bytes(wav_file)
    if buffer.is_empty():
        voice_error.emit("No se pudo leer el WAV.")
        return
    busy = true
    var err: Error = http.request_raw(TRANSCRIBE_URL, PackedStringArray(["Content-Type: audio/wav"]), HTTPClient.METHOD_POST, buffer)
    if err != OK:
        busy = false
        voice_error.emit("No se pudo contactar con Vosk. Inicia primero voice/server.py.")

func _on_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    busy = false
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        voice_error.emit("Voz a texto no disponible (HTTP %s / red %s)." % [response_code, result])
        return
    var payload: Variant = JSON.parse_string(body.get_string_from_utf8())
    if not (payload is Dictionary):
        voice_error.emit("Respuesta de Vosk malformada.")
        return
    var transcript := str(payload.get("text", "")).strip_edges()
    if transcript.is_empty():
        voice_error.emit("No se reconocieron palabras; prueba con una frase más larga.")
        return
    transcript_ready.emit(transcript)
