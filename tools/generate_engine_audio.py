"""Generate an original, seamless 1-second propeller-loop WAV (no third-party audio)."""
import math
import struct
import wave
from pathlib import Path

rate = 22050
out = Path(__file__).resolve().parents[1] / "assets" / "propeller.wav"
with wave.open(str(out), "wb") as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(rate)
    samples = []
    for i in range(rate):
        phase = i / rate * math.tau
        sample = 0.47 * math.sin(phase * 64) + 0.23 * math.sin(phase * 128)
        sample += 0.08 * math.sin(phase * 320) + 0.045 * math.sin(phase * 384)
        sample *= 0.88 + 0.12 * math.sin(phase * 8)
        samples.append(struct.pack("<h", int(sample * 21000)))
    wav.writeframes(b"".join(samples))
print(out)
