# Parameters Needed to Detect Sleep on the Garmin Venu 3

The definitive, honest spec for a DIY Connect IQ sleep detector.

This document maps the physiological parameters that matter for sleep/wake and
sleep-stage detection onto **what the Venu 3 actually exposes through Connect IQ**,
as verified against the working reads in
`source/SensorData.mc`. Where the watch does not expose a signal, it is marked
**NOT EXPOSED ON-WATCH** with a note on what is missing.

Ground truth for "what the watch exposes" = the actual calls in `SensorData.mc`:

| Signal | API call used in `SensorData.mc` | Notes |
|---|---|---|
| Raw accel x/y/z (mg) | `Sensor.registerSensorDataListener` @ `:sampleRate => 25` | streaming, 25 Hz, `lastAccel` |
| Raw gyro / mag x/y/z | same streaming listener @ 25 Hz | `lastGyro`, `lastMag` |
| RR intervals (ms) | streaming listener `:heartBeatIntervals` -> `hr.heartBeatIntervals` | `lastRR` (beat-to-beat) |
| Instant HR | `Sensor.getInfo().heartRate` | snapshot |
| SpO2 | `Sensor.getInfo().oxygenSaturation` | snapshot, on-demand |
| Respiration rate | `ActivityMonitor.getInfo().respirationRate` | brk/min, Garmin-derived |
| HR history (+min/max) | `SensorHistory.getHeartRateHistory({})` | iterator over stored samples |
| Stress history | `SensorHistory.getStressHistory({})` | Garmin HRV-derived stress |
| Body Battery history | `SensorHistory.getBodyBatteryHistory({})` | Garmin composite |
| Skin/ambient temp (C) | `Sensor.getInfo().temperature` | device temperature, NOT skin/core |
| Steps / distance / cadence | `ActivityMonitor.getInfo()`, `Activity.getActivityInfo()` | gross activity |
| Resting HR / profile | `UserProfile.getProfile()` | baseline HR, age |

Everything below is grouped into the six parameter families requested.

---

## 1. Movement (Actigraphy)

Movement is the **primary wake detector** for any wrist device. High,
frequent, high-amplitude motion => wake. Near-zero motion => sleep (with the
well-known caveat that quiet wakefulness looks identical to sleep).

### 1.1 Gross wrist movement / activity counts
- **Sleep role:** Primary sleep-vs-wake discriminator. Sleep = sustained low
  motion; wake = bursts of motion. High sensitivity for sleep (~92-97%), poor
  specificity for wake (~33-65%) — it cannot see motionless quiet wakefulness.
- **Stage hint:** Body rolls/position changes cluster around stage transitions
  and arousals; minimal motion is consistent with deep (N3) sleep but is not
  specific to it.
- **How on Venu 3:** Stream raw tri-axial acceleration via
  `Sensor.registerSensorDataListener` at `:sampleRate => 25` (already wired in
  `SensorData.mc::startStreaming`; latest sample cached as `lastAccel = [x,y,z]` mg).
  Compute a per-epoch activity count yourself: high-pass each axis to remove
  gravity, take vector magnitude, sum/integrate over a 30 s or 60 s epoch
  (a Cole-Kripke / Sadeh-style count). This is the on-watch equivalent of
  research actigraphy.
- **Realistic cadence:** 25 Hz streaming is heavy for an all-night background
  job. Better: wake briefly each epoch, sample a short accel burst (a few
  seconds at 25 Hz), derive a movement index, then idle. Or fall back to
  `Sensor.getInfo().accel` snapshots (the file already uses this as a fallback).

### 1.2 Gyroscope / magnetometer
- **Sleep role:** Supporting/optional. Gyro adds rotational motion (wrist
  twist, rolling over) that complements linear accel; magnetometer gives crude
  arm orientation/posture. Not required for sleep/wake.
- **How on Venu 3:** Same streaming listener, `lastGyro` / `lastMag`. Realistically
  skip both overnight — they add power draw for marginal benefit. Accel alone is
  the standard actigraphy input.

### 1.3 Steps / distance / cadence (gross activity context)
- **Sleep role:** Context only — confirms the user is sedentary/in bed. A clean
  proxy for "definitely not asleep" when steps accrue.
- **How on Venu 3:** `ActivityMonitor.getInfo().steps/distance` and
  `Activity.getActivityInfo().currentCadence` (already read in `readMotion`).
  Cheap to poll once per epoch; useful as a wake gate.

---

## 2. Heart (HR + HRV)

The cardiac channel is what lets a wrist device go beyond binary sleep/wake and
attempt **rough** light/deep/REM separation. HR falls from wake -> NREM, hits
its nadir in N3, and rises/becomes variable in REM.

### 2.1 Heart rate — absolute / nocturnal trend
- **Sleep role:** Primary supporting signal. Sleep onset = HR drop (often
  20-30% toward/below resting by N3). Lowest absolute HR => deep sleep (N3).
  Elevated + variable HR => REM or wake.
- **How on Venu 3:** Instant value `Sensor.getInfo().heartRate` (read in
  `readVitals`). For trend/min-max over the night use
  `SensorHistory.getHeartRateHistory({})` with `.getMin()/.getMax()` and iterate
  stored samples. Baseline from `UserProfile.getProfile().restingHeartRate`
  (and `.averageRestingHeartRate`) for personalized thresholds.
- **Cadence:** One HR read per 30-60 s epoch is plenty.

### 2.2 R-R interval / inter-beat interval (the HRV raw input)
- **Sleep role:** Foundation for all HRV metrics. Longer, more stable RR =>
  parasympathetic dominance => deeper NREM. Shorter/variable RR => REM or wake.
- **How on Venu 3:** **Available** via the streaming listener
  `:heartBeatIntervals => { :enabled => true }`; each `SensorData` callback
  exposes `hr.heartBeatIntervals` (ms), cached as `lastRR` in `SensorData.mc`.
  This is the single most valuable read for staging on this watch.
- **Caveat:** PPG-derived RR is noisier than ECG R-R and systematically inflates
  HF power; treat HRV values as **trends, not absolutes**. You must buffer a
  window of RR intervals (e.g. 2-5 min) to compute meaningful HRV.

### 2.3 Time-domain HRV — RMSSD / SDNN
- **Sleep role:** RMSSD (vagal/parasympathetic) is high in N3/early NREM, drops
  in REM/wake — the best single HRV refinement beyond HR. SDNN is broader/overall
  variability, weaker discriminator, used for stability.
- **How on Venu 3:** **Not provided as an API** — you compute it yourself from the
  buffered `lastRR` stream. RMSSD = sqrt(mean of squared successive RR differences);
  SDNN = std dev of RR over the window. No Connect IQ HRV-metric call exists; only
  raw RR is exposed.

### 2.4 Frequency-domain HRV — LF / HF / LF:HF
- **Sleep role:** HF (0.15-0.40 Hz) tracks vagal tone (high in N3/N2). LF/HF is
  often marketed as "sympathovagal balance" but is **confounded and not a valid
  sympathovagal measure** — treat as one weak ensemble feature at most.
- **How on Venu 3:** **Not provided.** Would require FFT/Lomb-Scargle on the RR
  buffer on-watch (expensive, and RR sampling is too sparse/noisy for reliable
  spectral HRV). Practically, prefer time-domain RMSSD over spectral HRV here.

### 2.5 Garmin stress (HRV-derived) — convenient proxy
- **Sleep role:** Garmin's stress score is itself an HRV-derived autonomic index;
  low stress correlates with parasympathetic/deep sleep, higher with REM/arousal.
- **How on Venu 3:** `SensorHistory.getStressHistory({})` (read in `readVitals`).
  A cheap, pre-computed autonomic surrogate if you don't want to compute HRV
  yourself. Body Battery (`getBodyBatteryHistory`) is a related composite but is
  a recovery metric, not a per-epoch staging input.

---

## 3. Respiration

Breathing rate and especially its **regularity** is one of the more informative
non-cardiac cues for REM vs NREM: NREM breathing is slow and regular; REM is
faster and irregular with phasic bursts.

### 3.1 Respiration rate (breaths/min)
- **Sleep role:** Supporting. Slightly lower and more regular in NREM
  (~15-16 brk/min), more variable in REM, higher in wake.
- **How on Venu 3:** `ActivityMonitor.getInfo().respirationRate` (read in
  `readVitals`). This is a Garmin-derived value (PPG-based), updated at low
  cadence — you get a rate, not a raw respiration waveform. Poll once per epoch.

### 3.2 Respiration-rate variability / phasic irregularity
- **Sleep role:** The actually-useful REM cue — REM shows elevated breath-to-breath
  variability vs the steady cadence of deep NREM.
- **How on Venu 3:** **Not directly exposed.** There is no raw respiration
  waveform via Connect IQ. You can only approximate variability by buffering the
  scalar `respirationRate` over time and taking its dispersion — coarse, because
  the underlying value is already smoothed and slow. True breath-to-breath RRV
  is **NOT EXPOSED ON-WATCH**.

---

## 4. Blood Oxygen (SpO2)

SpO2 is for **breathing-disturbance** screening, not for sleep staging.

### 4.1 SpO2 / desaturation events
- **Sleep role:** Supporting/screening only. Stable 95-100% in healthy sleep;
  repetitive dips suggest disordered breathing. Cannot stage sleep.
- **How on Venu 3:** `Sensor.getInfo().oxygenSaturation` (read in `readVitals`).
  This is an **on-demand spot read**, not a continuous low-latency stream, and
  wrist reflectance SpO2 reads ~2-3% low vs a fingertip oximeter with larger error.
- **Hard limit:** **AASM-grade apnea/hypopnea scoring is NOT FEASIBLE.** It needs
  an airflow sensor (>=90% drop = apnea; >=30% drop + >=3-4% desat/arousal =
  hypopnea). The Venu 3 has **no airflow and no respiratory-effort (RIP) sensor**,
  and wrist SpO2 error breaks the >=3% desaturation criterion. Use SpO2 only for
  coarse trend/awareness, never diagnosis.

---

## 5. Temperature

### 5.1 Skin/distal temperature (circadian + sleep-onset cue)
- **Sleep role:** Distal skin warming (vasodilation) precedes and accompanies
  sleep onset; supports circadian-phase estimation. Does **not** indicate stage.
- **How on Venu 3:** **Effectively NOT EXPOSED as skin temperature.**
  `Sensor.getInfo().temperature` (read in `readEnvironment`) returns a **device/
  ambient temperature**, not calibrated skin or core temperature. There is no
  Connect IQ skin-temperature or body-temperature API on the Venu 3 (Garmin's
  own "Body Battery"/sleep temperature features are not surfaced to CIQ as a
  skin-temp read). Treat any temperature use as low-confidence ambient context,
  not a physiological sleep-onset marker.
- **Missing:** Calibrated distal/proximal skin temperature; core body temperature.

---

## 6. Temporal / Circadian Context

Context that doesn't measure the body but sharply improves any classifier
(e.g. REM is more likely in the second half of the night; bedtime gates sleep
onset).

### 6.1 Clock time / time-of-night
- **Sleep role:** Disambiguates same-looking physiology (quiet evening vs deep
  sleep) and weights stage priors (more N3 early, more REM late).
- **How on Venu 3:** `System.getClockTime()` / `Time.now()` (Toybox.Time/System,
  both imported). Free and always available.

### 6.2 Resting HR / age baseline
- **Sleep role:** Personalizes HR/HRV thresholds (a "20-30% drop" is relative to
  the individual; staging accuracy drops ~7.5% in adults >60).
- **How on Venu 3:** `UserProfile.getProfile()` -> `restingHeartRate`,
  `averageRestingHeartRate`, `birthYear` (read in `readVitals`/`readSystem`).

### 6.3 Sedentary/in-bed gating
- **Sleep role:** Confirms sleep opportunity window.
- **How on Venu 3:** Steps cessation (`ActivityMonitor.getInfo().steps`) plus low
  movement index plus night-time clock. There is **no bed-presence/pressure
  sensor**, so "time in bed" must be inferred from immobility + clock.

### 6.4 Ambient light / lux
- **Sleep role:** Would help circadian/sleep-onset detection.
- **How on Venu 3:** **NOT EXPOSED** — no ambient-light sensor read in Connect IQ.

---

## Derived Sleep Metrics (what to compute, and from what)

All of these are computed by **you** from the logged signals; the Venu 3
exposes **no live sleep-stage or sleep-metric API** to Connect IQ.

| Metric | Definition | Inputs needed (Venu 3 reads) |
|---|---|---|
| **Sleep/Wake (binary, per epoch)** | foundational classification | movement index (accel stream) + HR + RR/HRV + clock |
| **Sleep Onset Latency (SOL)** | bedtime -> first sustained sleep | bedtime (clock/immobility) + sleep/wake series. Weak: can't see quiet wake. |
| **Total Sleep Time (TST)** | sum of sleep epochs | sleep/wake series |
| **Wake After Sleep Onset (WASO)** | wake epochs after onset, before final wake | sleep/wake series. **Worst metric** — quiet wake misread as sleep. |
| **Sleep Efficiency (SE)** | TST / time-in-bed x 100 | TST + inferred in-bed window (immobility + clock) |
| **Awakenings count** | count of wake bouts after onset | sleep/wake series (motion bursts + HR jumps) |
| **Stage durations / %** (Light=N1+N2, Deep=N3, REM) | per-stage epoch sums | HR + RMSSD/HRV (RR) + respiration rate + movement + time-of-night |
| **Restlessness / fragmentation** | movement-event frequency/amplitude | accel activity counts (and optional gyro) |
| **Arousal index (AASM)** | >=3 s cortical EEG shifts/hr | **NOT COMPUTABLE** — requires EEG |

Note: N1 vs N2 separation is impossible (defined by EEG spindles/K-complexes), so
collapse them into a single **Light** class.

---

## Accuracy / Feasibility (blunt)

**What a DIY Venu 3 app can realistically do:**
- **Binary sleep vs wake:** the strong case. ~86-90% epoch accuracy is achievable
  with accel + HR, driven by high sleep sensitivity. But wake specificity is low
  (~33-65%): the app will **overestimate TST and underestimate WASO**, worst in
  fragmented sleep, insomnia, older adults, and apnea.
- **Rough 3-class (Wake / NREM / REM) and a 4-class (Wake / Light / Deep / REM):**
  attainable at roughly **fair-to-moderate agreement (Cohen's kappa ~0.4-0.6)**
  using accel + HR + RR-derived HRV (RMSSD) + respiration rate + time-of-night —
  *and that's an optimistic, single-night-lab-style ceiling.* Deep (N3) sensitivity
  will be the weakest; REM will be confused with light NREM because both show
  elevated HRV and the watch can't extract clean breath-to-breath RRV.

**What it cannot do:**
- **True PSG sleep staging.** No EEG (spindles, K-complexes, delta %, low-amplitude
  mixed-frequency REM), no EOG (rapid eye movements), no chin EMG (REM atonia).
  All four stages are *defined* by signals the wrist physically cannot see; the app
  only **infers** stages from peripheral cardiac/motion/respiration surrogates.
- **AASM cortical microarousals** (>=3 s EEG frequency shifts) — needs EEG.
- **Clinical apnea/hypopnea (AHI), central vs obstructive** — needs airflow +
  respiratory-effort (RIP) sensing the Venu 3 lacks; wrist SpO2 error breaks the
  desaturation criterion. Do not attempt diagnosis.
- **PLMD / restless-legs diagnosis** — needs leg EMG.

**Important architecture caveat:**
Garmin's own sleep tracking is **computed server-side / by the device firmware
after the fact**, and is **not exposed live to Connect IQ**. There is no CIQ call
to "ask the watch what sleep stage I'm in." A CIQ sleep app must **log raw signals
overnight and run its own classifier** — either on-watch in a background service
(power- and memory-constrained) or by exporting the log and processing off-watch.
Expect this DIY result to be a **trend/wellness tool, not a diagnostic instrument**,
and to be less accurate than Garmin's first-party sleep (which has firmware-level
access and tuned models).

---

## Recommended Minimal Parameter Set + Algorithm Sketch

### Signals to log overnight (minimal, power-aware)

| Signal | Venu 3 read | Cadence |
|---|---|---|
| Movement index | accel stream (`startStreaming` @25 Hz) -> per-epoch vector-magnitude count, OR `Sensor.getInfo().accel` burst | short burst once per 30 s epoch |
| Heart rate | `Sensor.getInfo().heartRate` | 1x / epoch |
| RR intervals | listener `heartBeatIntervals` -> `lastRR`, buffered | continuous-ish; compute RMSSD over rolling 2-5 min |
| Respiration rate | `ActivityMonitor.getInfo().respirationRate` | 1x / epoch |
| (Optional) Stress | `SensorHistory.getStressHistory({})` | every few min |
| Time of night | `System.getClockTime()` | each epoch |
| Baselines (once) | `UserProfile.getProfile()` restingHeartRate, birthYear | at start |

Skip overnight: gyro, magnetometer, SpO2 (spot-only, costly), GPS, temperature
(ambient, not skin) — they add power/memory cost for little staging value.

### Per-epoch features (30 s epochs)
- `move` = integrated accel activity count for the epoch.
- `hr` = mean HR; `dHR` = hr minus personal resting HR.
- `rmssd` = RMSSD over the trailing RR window (parasympathetic proxy).
- `rr_rate` = respiration rate; `rr_var` = dispersion of recent respiration values.
- `t` = fraction of night elapsed (REM prior rises later in night).

### Staging heuristic (simple, layered)

```
1. WAKE if move is high (above movement threshold) OR (dHR high AND move present).
   -> Apply an immobility rule for onset/offset: sleep onset = first of N
      consecutive low-move epochs (N ~10 min, allow 1 active epoch);
      final wake = last such block. Everything between bounds the sleep period.

Within the sleep period (move low):

2. DEEP (N3)  if hr near nightly nadir (dHR most negative) AND rmssd high
              (parasympathetic dominance) AND respiration slow+regular
              AND move ~ 0. Require several consecutive epochs (algorithmic
              smoothing, NOT a physiological rule) before confirming.

3. REM        if rmssd LOW relative to recent NREM AND hr elevated/variable
              AND rr_var elevated (irregular breathing) AND move ~ 0,
              weighted up in the later half of the night (t large).

4. LIGHT (N1+N2) = residual: asleep, not DEEP, not REM.
```

Then post-process: enforce minimum stage-bout lengths, smooth single-epoch
flips, and recompute TST / SE / SOL / WASO / stage % / awakenings from the
final epoch-by-epoch sleep series.

### Honest expectation
This pipeline gives a usable **sleep/wake timeline plus a coarse light/deep/REM
hypnogram trend**, on par with consumer-wearable kappa (~0.4-0.6) under good
conditions — and meaningfully worse in fragmented or disordered sleep. It is a
wellness/trend tool. It is **not** PSG, **not** an apnea screener, and cannot
match Garmin's own server-side sleep for the same night.
