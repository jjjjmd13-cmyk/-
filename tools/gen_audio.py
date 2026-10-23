"""Synthesizes every sound effect and music loop used by the game.

Combat effects come from tools/gen_combat_sfx.py. All audio is generated from scratch (no samples), so there are no licensing
concerns. Re-run from the project root to regenerate assets/audio/:

    python3 tools/gen_audio.py
"""
import wave

import numpy as np

SR = 22050
OUT = "assets/audio"
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.005, release=None, curve=4.0):
    """Fast attack, exponential decay envelope of n samples."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    dur = n / SR
    d = np.exp(-curve * t / dur)
    if release:
        tail = np.clip((dur - t) / release, 0, 1)
        d *= tail
    return a * d


def lowpass(x, cutoff):
    """One-pole low-pass; cutoff may be a scalar or per-sample array."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=np.float64), x.shape)
    alpha = 1 - np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def noise(n):
    return rng.uniform(-1, 1, n)


def sine(freq, t):
    if np.ndim(freq):
        return np.sin(2 * np.pi * np.cumsum(freq) / SR)
    return np.sin(2 * np.pi * freq * t)


def saw(freq, t):
    ph = (freq * t) % 1.0
    return 2 * ph - 1


def square(freq, t, duty=0.5):
    return np.where((freq * t) % 1.0 < duty, 1.0, -1.0)


def tri(freq, t):
    return 2 * np.abs(2 * ((freq * t) % 1.0) - 1) - 1


def pluck(freq, dur, damp=0.996):
    """Karplus-Strong plucked string."""
    n = int(SR * dur)
    p = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, p)
    out = np.empty(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = damp * 0.5 * (buf[i % p] + buf[(i + 1) % p])
    return out


def norm(x, peak=0.9):
    m = np.max(np.abs(x))
    return x if m < 1e-9 else x / m * peak


def write(name, x, peak=0.9):
    x = norm(np.asarray(x, dtype=np.float64), peak)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(f"{OUT}/{name}.wav", "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(f"{name}.wav  {len(x) / SR:.2f}s")


def mix_at(buf, x, start):
    s = int(start * SR)
    e = min(len(buf), s + len(x))
    if s < len(buf):
        buf[s:e] += x[: e - s]


# --------------------------------------------------------------- SFX
def sfx():
    # Explosion.
    n = int(SR * 0.9)
    x = lowpass(noise(n), np.linspace(3000, 120, n)) * env(n, 0.002, curve=5)
    x += 0.7 * sine(np.linspace(120, 30, n), None) * env(n, 0.002, curve=6)
    write("explosion", x, 0.85)

    # Player hurt.
    n = int(SR * 0.28)
    t = t_axis(0.28)
    x = np.tanh(3 * square(np.linspace(160, 80, n), t, 0.3)) * env(n, 0.002, curve=7)
    x = lowpass(x, 1800) + 0.4 * lowpass(noise(n), 900) * env(n, 0.001, curve=10)
    write("hurt", x, 0.7)

    # XP pickup.
    n = int(SR * 0.09)
    t = t_axis(0.09)
    x = (sine(1320, t) * (t < 0.04) + sine(1980, t) * (t >= 0.04)) * env(n, 0.002, curve=3)
    write("pickup", x, 0.35)

    # Level up fanfare arpeggio.
    buf = np.zeros(int(SR * 1.1))
    for i, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        n = int(SR * 0.6)
        t = t_axis(0.6)
        note = (sine(f, t) + 0.4 * sine(2 * f, t) + 0.2 * tri(3 * f, t)) * env(n, 0.005, curve=5)
        mix_at(buf, note, i * 0.09)
    write("levelup", buf, 0.65)

    # Dash whoosh.
    n = int(SR * 0.22)
    x = highpass(lowpass(noise(n), np.linspace(1200, 6000, n)), 600)
    x *= np.sin(np.linspace(0, np.pi, n)) ** 2
    write("dash", x, 0.5)

    # Boss roar.
    n = int(SR * 1.6)
    t = t_axis(1.6)
    f = 55 + 12 * np.sin(2 * np.pi * 5 * t)
    x = np.tanh(2.5 * (saw(f, t) + 0.5 * saw(f * 1.01, t)))
    x = lowpass(x, 900) + 0.4 * lowpass(noise(n), 500)
    x *= np.clip(t / 0.25, 0, 1) * np.clip((1.6 - t) / 0.6, 0, 1)
    write("boss_roar", x, 0.85)

    # Enemy shot.
    n = int(SR * 0.16)
    t = t_axis(0.16)
    x = sine(np.linspace(900, 300, n), None) * env(n, 0.001, curve=5)
    write("enemy_shot", x, 0.35)

    # UI.
    n = int(SR * 0.05)
    t = t_axis(0.05)
    write("ui_move", sine(880, t) * env(n, 0.001, curve=6), 0.3)
    n = int(SR * 0.12)
    t = t_axis(0.12)
    write("ui_click", (sine(660, t) * (t < 0.05) + sine(990, t) * (t >= 0.05)) * env(n, 0.001, curve=4), 0.4)

    # Skill activations.
    n = int(SR * 0.6)
    t = t_axis(0.6)
    x = lowpass(noise(n), 700) * env(n, 0.005, curve=4)
    x += 0.8 * np.tanh(2 * saw(np.linspace(110, 40, n), t)) * env(n, 0.005, curve=4)
    write("roar", lowpass(x, 1400), 0.85)

    n = int(SR * 0.5)
    x = np.zeros(n)
    for k in range(10):
        mix_at(x, highpass(lowpass(noise(int(SR * 0.08)), 5000), 1200) * env(int(SR * 0.08), 0.002, curve=6), k * 0.035)
    write("knives", x, 0.6)

    # Wave start horn.
    n = int(SR * 1.4)
    t = t_axis(1.4)
    f = 110
    x = sum(saw(f * r, t) / (i + 1) for i, r in enumerate([1, 1.5, 2, 3]))
    x = lowpass(x, 1100) * np.clip(t / 0.15, 0, 1) * np.clip((1.4 - t) / 0.7, 0, 1)
    write("wave_horn", x, 0.6)

    # Victory / defeat stingers.
    buf = np.zeros(int(SR * 2.6))
    for i, (f, d) in enumerate([(392, 0.25), (523.25, 0.25), (659.25, 0.25), (783.99, 1.6)]):
        n = int(SR * d * 1.6)
        t = t_axis(d * 1.6)
        mix_at(buf, (saw(f, t) * 0.4 + sine(f, t)) * env(n, 0.01, curve=3), [0, 0.22, 0.44, 0.7][i])
    write("victory", lowpass(buf, 3000), 0.7)

    buf = np.zeros(int(SR * 2.6))
    for i, f in enumerate([392, 369.99, 349.23, 293.66]):
        n = int(SR * 1.2)
        t = t_axis(1.2)
        mix_at(buf, (saw(f / 2, t) * 0.5 + sine(f / 2, t)) * env(n, 0.02, curve=3), i * 0.45)
    write("defeat", lowpass(buf, 1500), 0.7)


# --------------------------------------------------------------- MUSIC
A = 440.0


def midi(m):
    return A * 2 ** ((m - 69) / 12)


def pad_note(f, dur):
    t = t_axis(dur)
    x = saw(f, t) + saw(f * 1.006, t) + 0.5 * saw(f * 0.5, t)
    x = lowpass(x, 900)
    n = len(t)
    a = np.clip(t / 0.6, 0, 1) * np.clip((dur - t) / 0.8, 0, 1)
    return x * a[:n]


def bell(f, dur):
    t = t_axis(dur)
    x = sine(f, t) + 0.3 * sine(f * 2.76, t) + 0.15 * sine(f * 5.4, t)
    return x * env(len(t), 0.003, curve=4)


def kick(dur=0.35):
    n = int(SR * dur)
    return sine(np.linspace(140, 40, n), None) * env(n, 0.001, curve=8)


def snare(dur=0.25):
    n = int(SR * dur)
    t = t_axis(dur)
    return (0.7 * highpass(noise(n), 1500) + 0.3 * sine(190, t)) * env(n, 0.001, curve=10)


def hat(dur=0.06):
    n = int(SR * dur)
    return highpass(noise(n), 7000) * env(n, 0.001, curve=8)


def tom(f, dur=0.4):
    n = int(SR * dur)
    return sine(np.linspace(f * 1.6, f, n), None) * env(n, 0.001, curve=6)


def make_loop(length):
    return np.zeros(int(SR * length) + SR * 3)


def fold_loop(buf, length):
    """Wraps the tail past the loop point back to the start for a seamless loop."""
    n = int(SR * length)
    out = buf[:n].copy()
    tail = buf[n:]
    out[: len(tail)] += tail
    return out


def menu_theme():
    bpm = 70
    beat = 60 / bpm
    bars = 8
    length = bars * 4 * beat
    buf = make_loop(length)
    # D minor progression: Dm - Bb - Gm - A
    chords = [[50, 53, 57], [46, 50, 53], [43, 46, 50], [45, 49, 52]]
    for bar in range(bars):
        ch = chords[bar % 4]
        for m in ch:
            mix_at(buf, 0.18 * pad_note(midi(m), 4 * beat + 0.8), bar * 4 * beat)
        mix_at(buf, 0.35 * pad_note(midi(ch[0] - 12), 4 * beat + 0.8), bar * 4 * beat)
    melody = [62, 65, 69, 67, 65, 64, 62, 61, 62, 65, 70, 69, 67, 65, 64, 69]
    for i, m in enumerate(melody):
        mix_at(buf, 0.22 * bell(midi(m + 12), 2.5), i * 2 * beat)
    return fold_loop(buf, length)


def battle_theme(boss=False):
    bpm = 150 if boss else 132
    beat = 60 / bpm
    bars = 16
    length = bars * 4 * beat
    buf = make_loop(length)
    if boss:
        prog = [38, 38, 41, 40, 38, 38, 36, 37]  # D D F E D D C C#
    else:
        prog = [38, 34, 36, 33, 38, 34, 36, 37]  # Dm Bb C A ...
    for bar in range(bars):
        root = prog[bar % 8]
        t0 = bar * 4 * beat
        # Driving eighth-note bass.
        for k in range(8):
            f = midi(root if k % 4 != 3 else root + 12)
            n = int(SR * beat * 0.48)
            t = t_axis(beat * 0.48)
            note = lowpass(saw(f, t) + 0.5 * square(f / 2, t), 700) * env(n, 0.003, curve=3)
            mix_at(buf, 0.3 * note, t0 + k * beat / 2)
        # Drums.
        for k in range(4):
            mix_at(buf, 0.75 * kick(), t0 + k * beat)
            if boss:
                mix_at(buf, 0.45 * kick(), t0 + k * beat + beat / 2)
            if k in (1, 3):
                mix_at(buf, 0.45 * snare(), t0 + k * beat)
            for h in range(2):
                mix_at(buf, 0.12 * hat(), t0 + k * beat + h * beat / 2)
        if bar % 2 == 1:
            for k, f in enumerate([110, 98, 87]):
                mix_at(buf, 0.35 * tom(f), t0 + 3 * beat + k * beat / 3)
        # Pads.
        third = 3 if (bar % 4) in (0, 2) or boss else 4
        for m in (root + 12, root + 12 + third, root + 19):
            mix_at(buf, 0.07 * pad_note(midi(m), 4 * beat + 0.5), t0)
    # Lead melody over the second half.
    if boss:
        lead = [74, 77, 76, 74, 73, 74, 76, 77, 79, 77, 76, 74, 73, 70, 73, 76]
    else:
        lead = [62, 65, 67, 69, 70, 69, 67, 65, 64, 65, 67, 64, 62, 61, 62, 64]
    for i, m in enumerate(lead):
        dur = beat * 3.6
        t = t_axis(dur)
        n = len(t)
        f = midi(m + 12) * (1 + 0.004 * np.sin(2 * np.pi * 5.5 * t))
        note = lowpass(square(f, t, 0.3) * 0.5 + saw(f, t) * 0.5, 2400)
        note *= np.clip(t / 0.02, 0, 1) * np.exp(-1.5 * t / dur)
        mix_at(buf, 0.09 * note, length / 2 + i * 2 * beat)
    return fold_loop(buf, length)


def soft_clip(x):
    return np.tanh(1.2 * norm(x, 1.0)) / np.tanh(1.2)


if __name__ == "__main__":
    sfx()
    # Swings, impacts, bow and spells live in their own 44.1 kHz generator.
    import gen_combat_sfx
    gen_combat_sfx.main()
    write("music_menu", soft_clip(menu_theme()), 0.7)
    write("music_battle", soft_clip(battle_theme()), 0.7)
    write("music_boss", soft_clip(battle_theme(boss=True)), 0.7)
