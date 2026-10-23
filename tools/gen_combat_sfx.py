"""Synthesizes the combat sound effects (swings, impacts, bow, spells).

Layered designs at 44.1 kHz: every sound is a transient + body + tail, run
through a short room reverb, and comes in several variants so rapid attacks
never repeat the exact same sample (Audio picks name.wav / name_2.wav / ...).
Only numpy is needed. Run from the project root:

    python3 tools/gen_combat_sfx.py
"""
import wave

import numpy as np

SR = 44100
OUT = "assets/audio"
rng = np.random.default_rng(1234)


def n_of(dur):
    return int(SR * dur)


def t_of(n):
    return np.arange(n) / SR


def noise(n):
    return rng.uniform(-1, 1, n)


def decay(n, tau, attack=0.001):
    """Exponential decay with time constant tau (seconds) and a short linear attack."""
    t = t_of(n)
    return np.clip(t / max(attack, 1e-5), 0, 1) * np.exp(-t / tau)


def bell(n, peak, sharp=2.0):
    """Swell to a peak (fraction of n) and fall away: the shape of a whoosh."""
    k = np.linspace(0, 1, n)
    rise = np.clip(k / peak, 0, 1) ** sharp
    fall = np.clip((1 - k) / (1 - peak), 0, 1) ** (sharp * 0.8)
    return np.where(k < peak, rise, fall)


def tone(freq, n, phase=0.0):
    """Sine with a fixed or per-sample frequency."""
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,))
    return np.sin(phase + 2 * np.pi * np.cumsum(f) / SR)


def sweep(f0, f1, n, curve=1.0):
    k = np.linspace(0, 1, n) ** curve
    return f0 * (f1 / f0) ** k


def svf(x, cutoff, q=0.7, mode="bp"):
    """Topology-preserving state-variable filter with per-sample cutoff."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=np.float64), x.shape)
    g = np.tan(np.pi * np.clip(cutoff, 20, SR * 0.45) / SR)
    k = 1.0 / q
    ic1 = ic2 = 0.0
    out = np.empty_like(x)
    for i in range(len(x)):
        gi = g[i]
        a1 = 1.0 / (1.0 + gi * (gi + k))
        v3 = x[i] - ic2
        v1 = a1 * ic1 + gi * a1 * v3
        v2 = ic2 + gi * v1
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        out[i] = v1 if mode == "bp" else (v2 if mode == "lp" else x[i] - k * v1 - v2)
    return out


def lp(x, cutoff, q=0.7):
    return svf(x, cutoff, q, "lp")


def hp(x, cutoff, q=0.7):
    return svf(x, cutoff, q, "hp")


def bp(x, cutoff, q=1.0):
    return svf(x, cutoff, q, "bp")


def drive(x, amount):
    return np.tanh(amount * x) / np.tanh(amount)


def pad(x, n):
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def mix(n, *layers):
    """Sums (start_seconds, signal) layers into a buffer of n samples."""
    buf = np.zeros(n)
    for start, sig in layers:
        s = int(start * SR)
        e = min(n, s + len(sig))
        if s < n:
            buf[s:e] += sig[: e - s]
    return buf


_IR = None


def room(x, wet=0.15):
    """Short dark room so effects sit in a space instead of sounding dry and cheap."""
    global _IR
    if _IR is None:
        m = n_of(0.32)
        ir = lp(lp(noise(m), 2600), 2600) * np.exp(-t_of(m) / 0.07)
        ir[: n_of(0.006)] = 0
        _IR = ir / np.sqrt(np.sum(ir ** 2))
    tail = np.convolve(x, _IR)[: len(x) + len(_IR)]
    return pad(x, len(tail)) * (1 - wet * 0.5) + tail * wet


def write(name, x, peak=0.9):
    x = np.asarray(x, dtype=np.float64)
    x -= np.mean(x)
    # Drop the silent reverb tail (below -60 dB of the peak).
    loud = np.nonzero(np.abs(x) > np.max(np.abs(x)) * 0.001)[0]
    x = x[: loud[-1] + 1] if len(loud) else x
    fade = min(len(x), n_of(0.01))
    x[-fade:] *= np.linspace(1, 0, fade)
    x = x / max(1e-9, np.max(np.abs(x))) * peak
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(f"{OUT}/{name}.wav", "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(f"{name}.wav  {len(x) / SR:.2f}s")


def variants(name, make, count, peak):
    for i in range(count):
        write(name if i == 0 else f"{name}_{i + 1}", make(i), peak)


def r(lo, hi):
    return rng.uniform(lo, hi)


# ------------------------------------------------------------------ layers
def whoosh(dur, f0, f1, q, peak):
    n = n_of(dur)
    return bp(noise(n), sweep(f0, f1, n), q) * bell(n, peak)


def blade_ring(dur, base, level):
    """Inharmonic partials of thin steel: the 'shing' of a blade."""
    n = n_of(dur)
    t = t_of(n)
    x = np.zeros(n)
    for ratio, amp, tau in [(1.0, 1.0, 0.05), (1.51, 0.7, 0.04), (2.03, 0.5, 0.03), (2.74, 0.35, 0.022)]:
        x += amp * np.sin(2 * np.pi * base * ratio * r(0.99, 1.01) * t + r(0, 6)) * decay(n, tau, 0.002)
    return level * x


def thump(dur, f0, f1, tau, amount=2.0):
    n = n_of(dur)
    return drive(tone(sweep(f0, f1, n, 0.5), n) * decay(n, tau), amount)


def click(dur, cutoff):
    n = n_of(dur)
    return hp(noise(n), cutoff) * decay(n, dur / 3)


def crunch(dur, centre, tau, q=1.4):
    n = n_of(dur)
    return bp(noise(n), centre, q) * decay(n, tau)


def sparkle(dur, count, lo, hi, level):
    """Scattered tiny high sine grains: magical glitter."""
    n = n_of(dur)
    x = np.zeros(n)
    for _ in range(count):
        g = n_of(r(0.02, 0.05))
        grain = tone(r(lo, hi), g) * np.hanning(g)
        start = int(r(0, max(1, n - g)))
        x[start:start + g] += grain * r(0.4, 1.0)
    return level * x


# ------------------------------------------------------------------ sounds
def swing(i):
    # Rogue dagger: quick, bright cut with a thin steel glint.
    dur = 0.2
    n = n_of(dur)
    hi = r(2700, 3400)
    air = whoosh(dur, hi, r(900, 1200), 1.8, r(0.3, 0.42))
    body = whoosh(dur, hi * 0.45, 500, 0.8, 0.4) * 0.35
    glint = blade_ring(0.12, r(3000, 3600), 0.16)
    return room(mix(n, (0, air + body), (dur * 0.33, glint)), 0.1)


def swing_heavy(i):
    # Knight greatsword: big low arc of air with weight behind it.
    dur = 0.42
    n = n_of(dur)
    air = whoosh(dur, r(1500, 1900), r(260, 340), 1.1, r(0.42, 0.5))
    rumble = lp(noise(n), sweep(700, 180, n)) * bell(n, 0.45) * 0.8
    sub = tone(sweep(95, 48, n), n) * bell(n, 0.5, 3.0) * 0.35
    cloth = bp(noise(n), 900, 3.0) * bell(n, 0.25, 4.0) * 0.12
    return room(lp(drive(air + rumble + sub + cloth, 1.4), 2400), 0.16)


def hit(i):
    # Weapon meets monster: snap, punch, then a short meaty crunch.
    dur = 0.22
    n = n_of(dur)
    return room(mix(
        n,
        (0, click(0.006, 2500) * 0.6),
        (0, thump(0.16, r(170, 210), r(48, 60), r(0.045, 0.06), 2.5) * 0.9),
        (0.002, crunch(0.12, r(1000, 1500), r(0.025, 0.04)) * 0.7),
        (0.004, crunch(0.15, r(320, 420), r(0.04, 0.06), 2.0) * 0.45),
    ), 0.08)


def crit(i):
    # Critical: heavier punch, sub boom and a metallic ring that rings out.
    dur = 0.55
    n = n_of(dur)
    return room(mix(
        n,
        (0, click(0.008, 2000) * 0.8),
        (0, thump(0.3, r(220, 250), 38, 0.09, 3.0) * 1.0),
        (0.002, crunch(0.18, r(1300, 1700), 0.05) * 0.75),
        (0.01, blade_ring(0.5, r(1750, 1950), 0.22)),
        (0.01, blade_ring(0.4, r(2700, 2900), 0.12)),
    ), 0.14)


def arrow(i):
    # Bow: string snap and twang, then the arrow tearing through the air.
    dur = 0.36
    n = n_of(dur)
    f = r(135, 165)
    tw_n = n_of(0.3)
    t = t_of(tw_n)
    twang = sum(np.sin(2 * np.pi * f * h * t) / h ** 1.3 for h in range(1, 7))
    twang *= decay(tw_n, 0.05, 0.001) * (1 + 0.3 * np.sin(2 * np.pi * 9 * t))
    snap = click(0.01, 1800)
    fly = whoosh(0.22, r(3600, 4200), r(1400, 1700), 2.4, 0.25)
    return room(mix(n, (0, snap * 0.7), (0, lp(twang, 2200) * 0.6), (0.03, fly * 0.8)), 0.1)


def bolt(i):
    # Mage arcane bolt cast: FM 'zhoom' with a bright crack and glitter.
    dur = 0.4
    n = n_of(dur)
    t = t_of(n)
    carrier = sweep(r(1100, 1300), r(520, 620), n, 0.6)
    index = 2.6 * np.exp(-t / 0.08) + 0.4
    mod = np.sin(2 * np.pi * np.cumsum(carrier * 1.41) / SR)
    fm = np.sin(2 * np.pi * np.cumsum(carrier) / SR + index * mod) * decay(n, 0.11, 0.004)
    air = whoosh(0.3, 3200, 1300, 1.3, 0.2) * 0.5
    crack = click(0.012, 3500) * 0.5
    sub = thump(0.12, 140, 60, 0.04, 1.5) * 0.45
    glitter = sparkle(0.3, 9, 3800, 7600, 0.18)
    return room(mix(n, (0, crack), (0, sub), (0, fm * 0.55), (0.01, air), (0.03, glitter)), 0.22)


def bolt_hit(i):
    # Arcane bolt bursting on a monster: pop, crackle and a shimmering tail.
    dur = 0.5
    n = n_of(dur)
    t = t_of(n)
    pop = thump(0.15, r(320, 380), 70, 0.035, 2.0)
    crack_n = n_of(0.2)
    impulses = (rng.random(crack_n) < np.linspace(0.04, 0.0, crack_n)) * rng.uniform(-1, 1, crack_n)
    crackle = bp(impulses, 3200, 0.8) * 3.0
    base = r(1250, 1400)
    shimmer = sum(np.sin(2 * np.pi * base * h * t + r(0, 6)) * a for h, a in [(1, 1), (1.5, 0.6), (2.01, 0.4)])
    shimmer *= decay(n, 0.14, 0.01) * 0.18 * (1 + 0.4 * np.sin(2 * np.pi * 14 * t))
    burst = lp(noise(n_of(0.2)), sweep(5000, 600, n_of(0.2))) * decay(n_of(0.2), 0.04)
    return room(mix(n, (0, pop * 0.8), (0, burst * 0.55), (0, crackle), (0.005, shimmer)), 0.24)


def magic(i):
    # Generic spell (skills, casters): fuller and darker than the basic bolt.
    dur = 0.6
    n = n_of(dur)
    t = t_of(n)
    f = sweep(420, 880, n, 0.5)
    pad_tone = (np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.5 * np.sin(2 * np.pi * np.cumsum(f * 1.5) / SR)
                + 0.3 * np.sin(2 * np.pi * np.cumsum(f * 2.01) / SR))
    pad_tone *= bell(n, 0.18, 1.5) * (1 + 0.25 * np.sin(2 * np.pi * 11 * t))
    air = whoosh(0.5, 900, 3600, 1.0, 0.35) * 0.5
    glitter = sparkle(0.5, 12, 3000, 7000, 0.15)
    return room(mix(n, (0, pad_tone * 0.5 + pad(air, n)), (0.05, glitter)), 0.25)


def enemy_die(i):
    # Monster collapses: soft body thud and crumbling debris.
    dur = 0.4
    n = n_of(dur)
    thud = thump(0.2, r(110, 140), 45, 0.06, 2.0)
    debris = lp(noise(n), sweep(2400, 400, n)) * decay(n, 0.09, 0.004)
    grains = (rng.random(n) < np.linspace(0.01, 0.0, n)) * rng.uniform(-1, 1, n)
    rattle = bp(grains, 1800, 1.2) * 2.0
    return room(mix(n, (0, thud * 0.8), (0.005, debris * 0.5), (0.005, rattle)), 0.12)


def main():
    variants("swing", swing, 3, 0.62)
    variants("swing_heavy", swing_heavy, 3, 0.72)
    variants("hit", hit, 4, 0.78)
    variants("crit", crit, 2, 0.82)
    variants("arrow", arrow, 3, 0.6)
    variants("bolt", bolt, 3, 0.6)
    variants("bolt_hit", bolt_hit, 3, 0.7)
    variants("magic", magic, 2, 0.58)
    variants("enemy_die", enemy_die, 3, 0.6)


if __name__ == "__main__":
    main()
