"""Pruebas stdlib que NO requieren modelos Vosk descargados."""
from array import array
from pathlib import Path
import io
import math
import sys
import unittest
import wave

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "voice"))
from server import wav_to_pcm_16k


def make_wav(rate: int, channels: int, width: int, seconds: float = 0.16) -> bytes:
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wave_file:
        wave_file.setnchannels(channels)
        wave_file.setsampwidth(width)
        wave_file.setframerate(rate)
        n = round(rate * seconds)
        pcm = array("h", [int(13000 * math.sin(i * 2.0 * math.pi * 440 / rate)) for i in range(n) for _ in range(channels)])
        if width == 1:
            wave_file.writeframes(bytes(max(0, min(255, sample // 256 + 128)) for sample in pcm))
        else:
            wave_file.writeframes(pcm.tobytes())
    return buffer.getvalue()


class TestVoiceAudio(unittest.TestCase):
    def test_resample_44k_stereo(self):
        pcm = wav_to_pcm_16k(make_wav(44100, 2, 2))
        self.assertAlmostEqual(len(pcm), 0.16 * 16000 * 2, delta=8)

    def test_resample_16k_mono(self):
        pcm = wav_to_pcm_16k(make_wav(16000, 1, 2))
        self.assertEqual(len(pcm), int(0.16 * 16000 * 2))

    def test_resample_8bit(self):
        pcm = wav_to_pcm_16k(make_wav(22050, 1, 1))
        self.assertGreater(len(pcm), 100)

    def test_invalid_wave(self):
        with self.assertRaises((ValueError, wave.Error, EOFError)):
            wav_to_pcm_16k(b"not a wave")


if __name__ == "__main__":
    unittest.main()
