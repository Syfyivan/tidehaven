"""Generate deterministic 16-bit PCM WAV sound effects and seamless ambient loops for Tidehaven."""
import hashlib
import json
import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 22050
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "audio"


def clamp_i16(val: float) -> int:
    return max(-32767, min(32767, int(round(val * 32767.0))))


def write_wav(name: str, samples: list[float], desc: str) -> dict:
    path = OUT_DIR / f"{name}.wav"
    pcm = b"".join(struct.pack("<h", clamp_i16(s)) for s in samples)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(pcm)
    raw = path.read_bytes()
    return {
        "file": f"{name}.wav",
        "description": desc,
        "sample_rate": SAMPLE_RATE,
        "frames": len(samples),
        "seconds": round(len(samples) / SAMPLE_RATE, 3),
        "bytes": len(raw),
        "sha256": hashlib.sha256(raw).hexdigest(),
    }


def env_ad(t: float, attack: float, decay: float) -> float:
    if t < 0.0:
        return 0.0
    if t < attack:
        return t / max(1e-5, attack)
    return math.exp(-(t - attack) / max(1e-4, decay))


def lowpass(samples: list[float], alpha: float) -> list[float]:
    out = []
    acc = 0.0
    for s in samples:
        acc += alpha * (s - acc)
        out.append(acc)
    return out


def gen_ui_click() -> list[float]:
    n = int(SAMPLE_RATE * 0.055)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        f = 580.0 - 180.0 * (t / 0.055)
        s = math.sin(math.tau * f * t) * 0.7 + math.sin(math.tau * f * 2.4 * t) * 0.3
        out.append(s * env_ad(t, 0.003, 0.014) * 0.36)
    return out


def gen_dialogue_open() -> list[float]:
    n = int(SAMPLE_RATE * 0.095)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        f = 440.0 if t < 0.042 else 554.37
        lt = t if t < 0.042 else t - 0.042
        s = math.sin(math.tau * f * t) * 0.8 + math.sin(math.tau * f * 2.0 * t) * 0.2
        out.append(s * env_ad(lt, 0.004, 0.026) * 0.28)
    return out


def gen_hook_cast() -> list[float]:
    rng = random.Random(101)
    n = int(SAMPLE_RATE * 0.19)
    raw = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    filt = lowpass(raw, 0.22)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        sweep = math.sin(math.tau * (260.0 + 320.0 * t) * t) * 0.35
        out.append((filt[i] * 0.85 + sweep) * env_ad(t, 0.025, 0.055) * 0.38)
    return out


def gen_splash() -> list[float]:
    rng = random.Random(202)
    n = int(SAMPLE_RATE * 0.30)
    noise = lowpass([rng.uniform(-1.0, 1.0) for _ in range(n)], 0.18)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        bubble = math.sin(math.tau * (240.0 + 480.0 * max(0.0, t - 0.05)) * t) * env_ad(t - 0.05, 0.005, 0.04) * 0.35
        body = noise[i] * env_ad(t, 0.008, 0.085)
        out.append((body + bubble) * 0.44)
    return out


def gen_pickup() -> list[float]:
    n = int(SAMPLE_RATE * 0.17)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        f = 523.25 if t < 0.065 else 783.99
        lt = t if t < 0.065 else t - 0.065
        s = math.sin(math.tau * f * t) * 0.78 + math.sin(math.tau * f * 2.0 * t) * 0.22
        out.append(s * env_ad(lt, 0.004, 0.042) * 0.34)
    return out


def gen_build() -> list[float]:
    rng = random.Random(303)
    n = int(SAMPLE_RATE * 0.23)
    noise = lowpass([rng.uniform(-1.0, 1.0) for _ in range(n)], 0.25)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        hit1 = (math.sin(math.tau * 185.0 * t) + noise[i] * 0.6) * env_ad(t, 0.002, 0.032)
        hit2 = (math.sin(math.tau * 232.0 * max(0.0, t - 0.095)) + noise[i] * 0.5) * env_ad(t - 0.095, 0.002, 0.038)
        out.append((hit1 + hit2) * 0.42)
    return out


def gen_chop_hit() -> list[float]:
    rng = random.Random(404)
    n = int(SAMPLE_RATE * 0.115)
    noise = lowpass([rng.uniform(-1.0, 1.0) for _ in range(n)], 0.30)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        thud = math.sin(math.tau * (165.0 - 55.0 * (t / 0.115)) * t) * 0.8
        crack = noise[i] * 0.75
        out.append((thud + crack) * env_ad(t, 0.002, 0.026) * 0.46)
    return out


def gen_tree_fall() -> list[float]:
    rng = random.Random(505)
    n = int(SAMPLE_RATE * 0.46)
    rustle = lowpass([rng.uniform(-1.0, 1.0) for _ in range(n)], 0.14)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        creak = math.sin(math.tau * (145.0 - 70.0 * min(1.0, t / 0.32)) * t) * env_ad(t, 0.03, 0.12) * 0.45
        thump = (math.sin(math.tau * 82.0 * max(0.0, t - 0.24)) * 0.7 + rustle[i] * 0.9) * env_ad(t - 0.24, 0.008, 0.075)
        out.append((creak + thump) * 0.45)
    return out


def gen_mine_hit() -> list[float]:
    rng = random.Random(606)
    n = int(SAMPLE_RATE * 0.13)
    grit = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        ring = math.sin(math.tau * 1180.0 * t) * 0.55 + math.sin(math.tau * 1790.0 * t) * 0.35
        out.append((ring * env_ad(t, 0.001, 0.034) + grit[i] * env_ad(t, 0.001, 0.012) * 0.35) * 0.38)
    return out


def gen_spear() -> list[float]:
    rng = random.Random(707)
    n = int(SAMPLE_RATE * 0.16)
    swish = lowpass([rng.uniform(-1.0, 1.0) for _ in range(n)], 0.16)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        tone = math.sin(math.tau * (340.0 - 150.0 * (t / 0.16)) * t) * 0.55
        out.append((tone + swish[i] * 0.7) * env_ad(t, 0.005, 0.042) * 0.40)
    return out


def gen_alert() -> list[float]:
    n = int(SAMPLE_RATE * 0.24)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        f = 392.0 if t < 0.11 else 311.13
        lt = t if t < 0.11 else t - 0.11
        s = math.sin(math.tau * f * t) * 0.75 + math.sin(math.tau * f * 2.0 * t) * 0.25
        out.append(s * env_ad(lt, 0.006, 0.05) * 0.33)
    return out


def gen_craft_ready() -> list[float]:
    n = int(SAMPLE_RATE * 0.32)
    notes = [(0.0, 523.25), (0.075, 659.25), (0.15, 783.99)]
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        acc = 0.0
        for start, freq in notes:
            if t >= start:
                lt = t - start
                acc += (math.sin(math.tau * freq * lt) * 0.8 + math.sin(math.tau * freq * 2.0 * lt) * 0.2) * env_ad(lt, 0.005, 0.075)
        out.append(acc * 0.24)
    return out


def seamless_loop(samples: list[float], fade_frames: int = 2205) -> list[float]:
    n = len(samples) - fade_frames
    out = samples[:n]
    for i in range(fade_frames):
        w = i / fade_frames
        out[i] = out[i] * w + samples[n + i] * (1.0 - w)
    return out


def gen_sea_ambient() -> list[float]:
    rng = random.Random(808)
    dur = 4.0
    fade = int(SAMPLE_RATE * 0.25)
    total = int(SAMPLE_RATE * dur) + fade
    surf = lowpass(lowpass([rng.uniform(-1.0, 1.0) for _ in range(total)], 0.045), 0.06)
    out = []
    for i in range(total):
        t = i / SAMPLE_RATE
        swell = 0.58 + 0.42 * math.sin(math.tau * (t / dur))
        out.append(surf[i] * swell * 0.28)
    return seamless_loop(out, fade)


def gen_underwater_ambient() -> list[float]:
    rng = random.Random(909)
    dur = 4.0
    fade = int(SAMPLE_RATE * 0.25)
    total = int(SAMPLE_RATE * dur) + fade
    deep = lowpass(lowpass([rng.uniform(-1.0, 1.0) for _ in range(total)], 0.018), 0.025)
    out = []
    for i in range(total):
        t = i / SAMPLE_RATE
        hum = math.sin(math.tau * 110.0 * t) * 0.018 * (0.6 + 0.4 * math.sin(math.tau * (t / dur)))
        out.append(deep[i] * 0.35 + hum)
    return seamless_loop(out, fade)


def gen_island_ambient() -> list[float]:
    rng = random.Random(1010)
    dur = 4.0
    fade = int(SAMPLE_RATE * 0.25)
    total = int(SAMPLE_RATE * dur) + fade
    breeze = lowpass([rng.uniform(-1.0, 1.0) for _ in range(total)], 0.032)
    out = []
    for i in range(total):
        t = i / SAMPLE_RATE
        leaf = breeze[i] * (0.5 + 0.35 * math.sin(math.tau * (t / dur))) * 0.18
        chirp_t = t - 1.35
        chirp = 0.0
        if 0.0 <= chirp_t <= 0.14:
            chirp = math.sin(math.tau * (1320.0 + 260.0 * math.sin(chirp_t * 45.0)) * chirp_t) * env_ad(chirp_t, 0.01, 0.04) * 0.055
        out.append(leaf + chirp)
    return seamless_loop(out, fade)


def main() -> None:
    global OUT_DIR
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", type=Path, default=OUT_DIR)
    args = parser.parse_args()
    OUT_DIR = args.out_dir
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    specs = [
        ("ui_click", gen_ui_click(), "Warm wooden tap for buttons, slots and panel toggles"),
        ("dialogue_open", gen_dialogue_open(), "Soft two-note reed chime when opening conversation"),
        ("hook_cast", gen_hook_cast(), "Rope cast whoosh for salvage hook and fishing rod"),
        ("splash", gen_splash(), "Water splash on diving, surfacing and hook contact"),
        ("pickup", gen_pickup(), "Rising wood marimba fifth on confirmed item gain"),
        ("build", gen_build(), "Double wooden mallet knock on confirmed deck/facility placement"),
        ("chop_hit", gen_chop_hit(), "Crisp timber axe impact synchronized with blade contact"),
        ("tree_fall", gen_tree_fall(), "Timber creak and soft fall on confirmed tree depletion"),
        ("mine_hit", gen_mine_hit(), "Pickaxe stone/ore clink synchronized with mining swing"),
        ("spear", gen_spear(), "Underwater harpoon thrust whoosh"),
        ("alert", gen_alert(), "Muted two-tone underwater warning for threat windup or low oxygen"),
        ("craft_ready", gen_craft_ready(), "Warm bell triad when processing finishes or new day begins"),
        ("sea_ambient", gen_sea_ambient(), "Seamless 4s ocean wave swell ambient loop"),
        ("underwater_ambient", gen_underwater_ambient(), "Seamless 4s deep underwater current loop"),
        ("island_ambient", gen_island_ambient(), "Seamless 4s coastal island breeze loop"),
    ]
    entries = [write_wav(name, data, desc) for name, data, desc in specs]
    (OUT_DIR / "manifest.json").write_text(json.dumps({"generator": "tools/generate-audio.py", "files": entries}, indent=2), encoding="utf-8")
    source_doc = [
        "# Tidehaven Original Audio Assets (0.19)",
        "",
        "Generated deterministically by `tools/generate-audio.py` using Python's standard library (`math`, `wave`, `struct`, `random` with fixed seeds).",
        "No external audio pack, commercial sample or third-party runtime dependency is used.",
        "All files are 16-bit mono PCM WAV at 22,050 Hz, loaded directly by `scripts/game_audio.gd`.",
        "",
        "| File | Duration | SHA256 | Purpose |",
        "|---|---|---|---|",
    ]
    for e in entries:
        source_doc.append(f"| `{e['file']}` | {e['seconds']}s | `{e['sha256'][:16]}…` | {e['description']} |")
    (OUT_DIR / "SOURCE.md").write_text("\n".join(source_doc) + "\n", encoding="utf-8")
    print(f"Generated {len(entries)} WAV files in {OUT_DIR}")


if __name__ == "__main__":
    main()
