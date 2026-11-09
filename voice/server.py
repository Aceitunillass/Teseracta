"""Servidor local de voz a texto de Teseracta. Solo escucha 127.0.0.1:8765.
No envía grabaciones a Internet. Requiere vosk y el modelo español descargado.
"""
from __future__ import annotations

from array import array
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import io
import json
import os
import sys
import wave

SAMPLE_RATE = 16000
MAX_WAV_BYTES = 10 * 1024 * 1024
MODEL_DIR = Path(os.environ.get("TESERACTA_VOSK_MODEL", str(Path(__file__).parent / "models" / "vosk-model-small-es-0.42")))


def wav_to_pcm_16k(wav_bytes: bytes) -> bytes:
    """PCM mono 16 kHz int16 (resampling lineal), sin dependencias externas.

    Esto es suficiente para el prototipo; puede sustituirse por un resampler
    de banda limitada en versiones posteriores.
    """
    with wave.open(io.BytesIO(wav_bytes), "rb") as audio:
        if audio.getcomptype() != "NONE":
            raise ValueError("Solo se admite WAV PCM sin compresión")
        channels = audio.getnchannels()
        sample_width = audio.getsampwidth()
        rate = audio.getframerate()
        if channels not in (1, 2) or sample_width not in (1, 2):
            raise ValueError("El WAV debe ser mono o estéreo, 8 o 16 bits")
        if not 8000 <= rate <= 96000:
            raise ValueError("Frecuencia WAV fuera de rango")
        if audio.getnframes() > rate * 35:
            raise ValueError("El audio supera los 35 segundos")
        raw = audio.readframes(audio.getnframes())

    if sample_width == 1:
        samples = [(byte - 128) * 256 for byte in raw]
    else:
        buf = array("h")
        buf.frombytes(raw)
        if sys.byteorder != "little":
            buf.byteswap()
        samples = buf.tolist()
    if channels == 2:
        mono = [(samples[i] + samples[i + 1]) // 2 for i in range(0, len(samples) - 1, 2)]
    else:
        mono = samples
    if not mono:
        raise ValueError("Audio vacío")
    out_count = max(1, round(len(mono) * SAMPLE_RATE / rate))
    result = array("h")
    for i in range(out_count):
        source = min((i * rate / SAMPLE_RATE), len(mono) - 1)
        low = int(source)
        high = min(low + 1, len(mono) - 1)
        t = source - low
        result.append(max(-32768, min(32767, round(mono[low] * (1 - t) + mono[high] * t))))
    if sys.byteorder != "little":
        result.byteswap()
    return result.tobytes()


def create_handler(model):
    from vosk import KaldiRecognizer

    class Handler(BaseHTTPRequestHandler):
        def _json(self, status: int, body: dict) -> None:
            raw = json.dumps(body, ensure_ascii=False).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

        def do_GET(self) -> None:
            if self.path == "/health":
                self._json(200, {"ok": True, "model": MODEL_DIR.name, "offline": True})
            else:
                self._json(404, {"error": "Not found"})

        def do_POST(self) -> None:
            if self.path != "/transcribe":
                return self._json(404, {"error": "Not found"})
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if length < 44 or length > MAX_WAV_BYTES:
                    return self._json(413, {"error": "Tamaño de WAV inválido"})
                sound = self.rfile.read(length)
                pcm = wav_to_pcm_16k(sound)
                recognizer = KaldiRecognizer(model, SAMPLE_RATE)
                recognizer.SetWords(False)
                for offset in range(0, len(pcm), 4000):
                    recognizer.AcceptWaveform(pcm[offset : offset + 4000])
                result = json.loads(recognizer.FinalResult())
                self._json(200, {"text": result.get("text", "")})
            except (ValueError, wave.Error, EOFError) as exc:
                self._json(400, {"error": str(exc)})
            except Exception:
                self._json(500, {"error": "Error de transcripción; revisa la consola"})
                raise

    return Handler


def main() -> None:
    try:
        from vosk import Model, SetLogLevel
    except ImportError as exc:
        raise SystemExit("Instala la dependencia: py -m pip install -r voice/requirements.txt") from exc
    if not MODEL_DIR.exists():
        raise SystemExit(f"Falta el modelo {MODEL_DIR}. Ejecuta: py voice/download_model.py")
    SetLogLevel(-1)
    print("Cargando modelo de voz desde", MODEL_DIR)
    model = Model(str(MODEL_DIR))
    server = ThreadingHTTPServer(("127.0.0.1", 8765), create_handler(model))
    print("Vosk listo en http://127.0.0.1:8765/health (solo local). Ctrl+C para salir.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
