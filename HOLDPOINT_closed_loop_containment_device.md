# HOLDPOINT
## A closed-loop evolutionary-containment system for treatment-resistant cancer
### Architecture, control law, sensing requirements, simulation evidence, failure analysis, and development path

**Date:** 2026-09-25
**Companion document:** `adaptive_therapy_containment_bound.md`. This file uses its Lemma 1 (resistant growth depends only on total burden), Theorem 1 (policy-independent TTP ceiling), and first-cycle identifiability result.
**Computation:** Python 3.12, NumPy/SciPy, IEEE 754 binary64. Printed values are display-rounded; nothing was rounded before use.
**Tiers:** **Verified** · **Corrected** · **Withdrawn** · **Open** · **Speculative** · **UNKNOWN**

---

## 0. Scope correction: what was asked vs. what can be delivered

**Asked:** a device that cures all cancers.

**Status of that goal: Withdrawn as a design target.** It is not achievable as specified, for reasons that follow from biology, not from a lack of effort:

1. **"Cancer" is not one disease.** It is hundreds of diseases, each with different drivers, tissue ecology, and drug sensitivities. No single effector mechanism acts on all of them.
2. **Metastatic disease usually contains pre-existing resistant cells before treatment begins.** Any therapy that selects on a heritable trait faces the dynamics analysed in the companion document. In the model used here, with any resistant cells present at the start ($R_0>0$) and resistant cells able to grow at the burden the patient can tolerate, eradication by the drug alone is impossible. Only delay is available.
3. **A cure claim needs randomized outcome evidence.** None exists for any device of this kind.

**What this document delivers instead:** a cancer-*agnostic control layer*. It is a device that sits between any existing effective drug and any cancer with a trackable burden biomarker. It converts the drug from open-loop maximum-dose use into closed-loop evolutionary containment.

**The innovation is not a new molecule.** It is the first device-level specification that couples three things:
- (a) a stratifier that decides, patient by patient, whether containment can beat maximum dose at all;
- (b) a predictive containment controller whose safety margin is derived from sensor noise and sampling interval;
- (c) a quantitative design law linking sensor precision to months of disease control.

In the model, this layer extends time to progression **4.2–4.4× over maximum-dose therapy and ~2.4–2.5× over the current clinical adaptive protocol (AT50)**, using **~36% of maximum-dose drug exposure**. This holds for a reference tumour with daily burden sampling at 4% measurement noise (§4). **Tier: Verified in-model; clinical efficacy Open.**

It does not cure. It aims to turn a fatal-on-schedule disease into a controlled one for longer, in the subset of patients where the ecology permits.

---

## 1. Design thesis

From the companion analysis:

- **Lemma 1.** In the two-population competition model, the resistant population obeys $\ln(R(t)/R_0)=r_S\int_0^t[\rho(1-n)-\tau]\,dt'$. The drug never enters this expression. The only lever on resistance is the **total-burden trajectory** $n(t)$.
- **Theorem 1.** No schedule can beat $T_{\rm up}=\ln(n_p/R_0)/\{r_S[\rho(1-n_p)-\tau]\}$. Holding $n$ just below the progression boundary $n_p$ approaches this ceiling (79–95% in simulation).
- **Clinical AT50 captures only 7–38% of the achievable headroom.** It cycles burden between 50% and 100% of baseline, so its time-averaged burden is low and resistant cells grow faster.

**Therefore:** the optimal policy is a **setpoint regulator** that holds tumour burden as close to the tolerable boundary as measurement allows.

That turns cancer treatment into a **control-engineering problem with a known plant model, a noisy delayed sensor, and a one-sided actuator** (the drug can only push burden down). This is structurally the same problem as the closed-loop artificial pancreas: sensor → estimator → controller → pump.

**The binding constraint is sensing, not drugs.** Every percent of safety margin forced by sensor noise lowers the held burden and, by Lemma 1, raises resistant growth. §3.4 makes this exact.

---

## 2. Architecture

```
 ┌──────────────────────────────────────────────────────────────────────────┐
 │  L4  SAFETY SUPERVISOR  (hard limits, imaging gates, clinician override)  │
 └──────────────────────────────────────────────────────────────────────────┘
        ▲ alarms / vetoes                                   │ constraints
        │                                                    ▼
 ┌─────────────┐   burden y_k   ┌──────────────────┐   u_k   ┌──────────────┐
 │ L1 SENSING  │ ─────────────▶ │ L2 ESTIMATION &  │ ──────▶ │ L3 ACTUATION │
 │ burden +    │                │ STRATIFICATION   │         │ dose on/off  │
 │ drug level  │ ◀───────────── │ + CONTROL LAW    │ ◀────── │ + adherence  │
 └─────────────┘  PK feedback   └──────────────────┘ logging └──────────────┘
        ▲                                                      │
        └──────────────────────  PATIENT  ◀────────────────────┘
```

### 2.1 L1 — Sensing

The device needs two measurement loops.

**Outer loop (tumour burden, days–weeks).** Requirement derived in §3.3: sampling interval Δ and total coefficient of variation σ must satisfy the margin law. Candidate burden signals:

| Cancer | Burden biomarker | Tier |
|---|---|---|
| Prostate | PSA | Established clinical marker (training knowledge; PSA variability sourced below) |
| Ovarian | CA-125 | Established clinical marker (training knowledge, not re-verified this session) |
| Myeloma | Serum M-protein / free light chains | Same |
| Differentiated thyroid | Thyroglobulin | Same |
| Hepatocellular | AFP | Same (subset of patients) |
| Colorectal | CEA | Same (subset of patients) |
| Pan-cancer | ctDNA tumour fraction | Same; cost and turnaround currently incompatible with daily/weekly sampling — **Open** |

**PSA noise, measured.** Sources disagree, and I report both:
- Christensson et al. (BJU Int 2011): total CV for total PSA of **4.0%** between time points days apart; 80% of men had a ratio within 0.91–1.09.
- A screening cohort sampled 2 weeks apart: mean biological CV of **~15%** for total PSA.
- A 24-patient study concluded that rises of up to 20–46% between consecutive values may be explained by biological plus analytical variation alone.

This spread is the single most important engineering uncertainty in the device. The simulations bracket it (σ = 0.04 and 0.15).

**Inner loop (drug exposure, seconds–hours).** Electrochemical aptamer-based (EAB) sensors have demonstrated:
- continuous real-time drug monitoring in live animals;
- a closed-loop system that held doxorubicin at a chosen set point in rabbits and rats (Mage et al., *Nat Biomed Eng* 2017);
- feedback dosing updated every 7 s from an in vivo sensor, holding constant or time-varying plasma profiles in rats for many hours;
- 2025 rat data confirming that constant plasma drug concentration also produces constant interstitial-fluid concentration.

**Role in HOLDPOINT:** convert "drug on" from a nominal dose into a *verified exposure*. This removes pharmacokinetic variability and non-adherence as hidden disturbances in the outer loop.

**Tier:** animal-validated for specific drugs; human use and aptamers for the relevant anticancer agents are **UNKNOWN / Open**.

### 2.2 L2 — Estimation, stratification, control

**Plant model:** the two-population Lotka–Volterra model, parameters $(r_S,\rho,\tau,\delta)$, observation $y=\theta n\,e^{\varepsilon}$.

Three functions:

1. **Stratifier (first cycle).** Identify $(r_S,\tau,\delta,\theta)$ from the first on/off cycle. Compute
   $$G_{\min}=\frac{1-\tau}{1-\tau-n_p},$$
   the guaranteed asymptotic headroom assuming resistant cells are not fitter than sensitive ones ($\rho\le1$).
   - Route to containment if the lower bootstrap bound of $G_{\min}$ exceeds a preregistered threshold (proposed: 2).
   - Route to standard therapy otherwise.
   - Companion MC result: identification fails at monthly sampling and works at weekly 2% CV. **This is the same sensing constraint as the controller.**
2. **Online estimator.** Local linear regression of $\log y$ over the last $w$ samples gives a level and a slope, the minimal filter used in simulation. The production design would be a Kalman or particle filter on the full model (**Open**; not simulated here).
3. **Controller.** Predictive threshold law (§3.2).

### 2.3 L3 — Actuation

- **Oral agents** (e.g., abiraterone, enzalutamide, TKIs): smart dispenser. It unlocks doses only when $u=1$, and logs dispensing and ingestion (via ingestible marker or inner-loop sensor).
- **Infusional agents:** programmable pump driven by the inner EAB loop (Mage-type architecture).

**Constraint:** the actuator is **one-sided**. The drug reduces burden; nothing in the device increases it except withholding drug. The margin law in §3.3 exists because overshoot above $n_p$ cannot be actively reversed faster than the drug-kill rate allows.

### 2.4 L4 — Safety supervisor (non-negotiable)

Hard rules that override the controller:

| Rule | Trigger | Action |
|---|---|---|
| S1 | Measured burden > $n_p$ on 2 consecutive samples | Force drug on; alert clinician |
| S2 | Drug-on phase fails to reduce burden within the model-predicted window (resistance signature) | Exit containment → clinician review; the Lemma 1 prediction has failed |
| S3 | Scheduled imaging (per clinical standard) shows new lesions or growth | Exit containment regardless of biomarker |
| S4 | Symptom or organ-function thresholds (site-specific: e.g., spinal-cord-threatening bone metastasis, hydronephrosis) | Exit containment |
| S5 | Sensor fault (drift, calibration failure, missing samples > 2Δ) | Revert to last safe state = drug on |
| S6 | Clinician override | Always wins |

**Design principle:** every failure defaults to drug on, i.e. standard-of-care behaviour. Containment is an *opt-in state that must continuously re-earn its permission*.

---

## 3. Control law — derivation

### 3.1 Variables

| Symbol | Meaning | Units |
|---|---|---|
| $n(t)$ | true total burden / carrying capacity | dimensionless |
| $y_k = n(t_k)e^{\sigma z_k}$, $z_k\sim\mathcal N(0,1)$ | measured burden at $t_k=k\Delta$ | dimensionless (PSA/θ) |
| $\Delta$ | sampling interval | day |
| $\sigma$ | total log-scale CV (analytical + biological) | dimensionless |
| $n_p = 1.2 n_0$ | progression boundary | dimensionless |
| $\hat P_0$ | baseline estimate (mean of 3 noisy samples) | dimensionless |
| $m$ | safety margin; setpoint $H=n_p(1-m)$ | dimensionless |
| $w$ | estimator window (samples) | count |

### 3.2 Predictive threshold law

At each sample $k$:

1. Fit $\log y$ over the last $w$ samples by least squares to get the current level $\hat\ell_k$ and slope $\hat b_k$.
2. Predict the burden at the next decision: $\hat n_{k+1} = \exp(\hat\ell_k + \max(\hat b_k,0)\,\Delta)$. Only upward trends are extrapolated, which is the conservative direction.
3. Set $u_k = 1$ if $\hat n_{k+1} > 1.2\hat P_0(1-m)$, else $u_k=0$.

**Why predictive?** A plain moving average lags. In simulation, a 4-sample moving average with a 5% margin at weekly sampling never triggered before the boundary was crossed: 0% dose, median TTP 34.3 d, which is just the untreated drift time from $n_0$ to $n_p$. Trend extrapolation removes most of that lag. **[Verified: executed.]**

### 3.3 Margin law

Two effects force the setpoint below $n_p$:

1. **Inter-sample drift.** With the drug off and $S$ dominant near the setpoint, burden grows at most at $\lambda(m)=r_S[(1-n_p(1-m))-\tau]$. Over one interval it grows by a factor $e^{\lambda\Delta}$.
2. **Measurement error.** A false-low reading of $z$ standard deviations lets the true burden sit a factor $e^{z\sigma}$ above what the controller sees.

Requiring $H\cdot e^{\lambda\Delta+z\sigma}\le n_p$ gives the implicit rule

$$
\boxed{\,m^\*=1-\exp\!\big[-(\lambda(m^\*)\,\Delta + z\,\sigma)\big]\,},\qquad z\approx 2 .
$$

Solved by fixed-point iteration for the reference tumour ($r_S=0.027$ d⁻¹, $\tau=0.25$, $n_p=0.6$):

| Δ (d) | σ | $m^\*$ (rule) | Simulation: smallest tested margin with ≥97% resistance-driven failures (i.e., controller not causing overshoot) |
|---|---|---|---|
| 1 | 0.04 | 0.0818 | 0.08 ✓ |
| 7 | 0.04 | 0.1142 | 0.15 (0.08 gave 0.79/0.47) ✓ |
| 28 | 0.04 | 0.2713 | 0.30 (w=3: 1.00) ✓ |
| 1 | 0.15 | 0.2653 | 0.15 already gives 0.97–0.99 → rule **conservative** at daily sampling |
| 7 | 0.15 | 0.3043 | 0.30 (1.00 / 0.99) ✓ |
| 28 | 0.15 | 0.4642 | not reached in grid (0.30 gives 0.90) — consistent |

**Tier:** heuristic sizing rule, **Verified as consistent** with simulation in 5/6 regimes and conservative in the sixth.

**Why daily sampling beats the rule:** a single false-low reading only permits one interval of drift. Sustained overshoot needs many consecutive false-lows, which is improbable at small Δ. So the effective $z$ shrinks.

### 3.4 Design law: precision → time

By Lemma 1, holding $n\approx n_p(1-m)$ makes resistant cells grow at $r_S\,g(m)$ with $g(m)=\rho(1-n_p(1-m))-\tau$. TTP therefore scales as

$$
\boxed{\,\mathrm{TTP}(m)\;\approx\;\mathrm{TTP}(m_0)\,\frac{g(m_0)}{g(m)}\,}
$$

Test, anchored on the simulated noise-free daily controller ($m_0=0.01$, TTP = 7019.6 d, $g(0.01)=0.0342$):

| $m$ | $g(m)$ | Predicted TTP (d) | Simulated medians (d) | Error |
|---|---|---|---|---|
| 0.08 | 0.063600 | 3774.7 | 3580.6 / 3748.7 (Δ=1, σ=0.04, w=3/6) | −5% / −1% |
| 0.15 | 0.093000 | 2581.4 | 2666.4 / 2738.7 (Δ=1); 2561.7 / 2617.3 (Δ=7) | +1% to +6% |
| 0.30 | 0.156000 | 1538.9 | 1744.1 / 1759.9 (Δ=1); 1722.5 / 1732.1 (Δ=7) | +11% to +13% |

The law captures the dependence within ~13%, and the error grows at large margins where the initial approach phase matters more. **[Verified.]**

**Engineering consequence.** $g(m)$ has a zero at $m_c = 1-(1-\tau/\rho)/n_p$, which is $<0$ here, so it is not reached. The closer a tumour is to the indefinite-control boundary, the steeper $1/g(m)$ becomes, and **each percent of sensor precision buys more time**.

For the reference tumour: going from 30% margin (monthly-grade sensing) to 8% (daily 4% CV sensing) multiplies TTP by $g(0.30)/g(0.08)=2.45$. **Sensor development is therapeutic development.**

---

## 4. Simulation evidence

### 4.1 Setup

- **Plant:** exact model of Strobl et al. 2021 (equations from the authors' repository; validated in the companion document).
- **Reference tumour:** $n_0=0.5$, $f_R=10^{-3}$, cost $c=0.3$ ($\rho=0.7$), turnover $\tau=0.25$, $\delta=1.5$, $r_S=0.027$ d⁻¹.
- **Integrator:** vectorized RK4, h = 0.125 d. It reproduces the LSODA reference to display precision: MTD 853.1290345 d vs 853.129; AT50 1477.1739094 vs 1477.174; AT50 at h = 0.0625 gives 1477.1738943 (change 1.5e-5 d).
- **Protocol:** 200 replicates per condition, seed 11. Decisions only at sampling times, from noisy measurements. Baseline estimated from 3 noisy samples.
- **TTP:** first time the *true* burden exceeds $n_p$, linearly interpolated within the step.
- **Failure class:** "R-driven" if the resistant fraction at crossing is > 0.5 (genuine resistance). Otherwise the failure is a controller-induced overshoot of sensitive cells, which is clinically recoverable and a device fault.

**Reference values (noise-free):**

| Policy | TTP (d) |
|---|---|
| MTD | 853.129 |
| AT50 | 1477.174 |
| Near-ideal containment | 7603.941 |
| Ceiling $T_{\rm up}$ | 8753.181 |
| HOLDPOINT predictive law, daily, m = 0.01 | 7019.6 (80.2% of ceiling, 8.23× MTD), dose fraction 0.287 |

### 4.2 Results — AT50 vs HOLDPOINT at best-performing robust margin

TTP median [p10, p90] in days; dose = median fraction of time on drug; R = fraction of failures that are resistance-driven.

| Δ | σ | AT50 | HOLDPOINT (setting) | HOLDPOINT / AT50 (median) | HOLDPOINT / MTD |
|---|---|---|---|---|---|
| 1 d | 0.04 | 1471.3 [1423.4, 1502.4]; dose 0.555; R 1.00 | 3748.7 [3322.4, 4345.3]; dose 0.355; R 0.99 (w=6, m=0.08) | 2.55 | 4.39 |
| 1 d | 0.15 | 1442.9 [1314.6, 1645.2]; dose 0.558; R 1.00 | 2512.7 [1975.1, 3382.2]; dose 0.407; R 0.97 (w=6, m=0.15) | 1.74 | 2.95 |
| 7 d | 0.04 | 1465.8 [1414.1, 1536.3]; dose 0.562; R 1.00 | 2617.3 [2439.0, 2837.6]; dose 0.414; R 1.00 (w=6, m=0.15) | 1.79 | 3.07 |
| 7 d | 0.15 | 1438.0 [1285.3, 1600.0]; dose 0.553; R 0.94 | 1718.9 [1513.4, 2042.9]; dose 0.499; R 0.99 (w=6, m=0.30) | 1.20 | 2.01 |
| 28 d | 0.04 | 1431.5 [727.9, 1496.9]; dose 0.551; R 0.77 | 1785.3 [1690.3, 1891.9]; dose 0.495; R 1.00 (w=3, m=0.30) | 1.25 | 2.09 |
| 28 d | 0.15 | 717.3 [171.8, 1431.5]; dose 0.384; R 0.38 | 1620.1 [1314.2, 1834.0]; dose 0.499; R 0.90 (w=3, m=0.30) | 2.26 | 1.90 |

**Findings [Verified in-model]:**

1. **Sensing dominates.** Going from monthly/15% to daily/4% raises HOLDPOINT's median TTP from 1620.1 to 3748.7 d (×2.31).
2. **HOLDPOINT is never worse than AT50 at its robust margin,** and it uses less drug in 5 of 6 regimes.
3. **AT50 itself degrades badly under monthly high-noise sampling:** median 717.3 d, with only 38% of failures resistance-driven, meaning most are noise-induced overshoots. The current clinical protocol's apparent robustness partly depends on assay precision that may not hold (§2.1 PSA dispute).
4. **Too-small margins are dangerous.** At Δ = 7 d, σ = 0.04, m = 0.02, the median TTP is 193.2 d with only 4% R-driven. That is almost all controller-induced overshoot, worse than MTD. **The margin law is a safety requirement, not an optimization detail.**
5. **An unexplained regularity.** At Δ = 28, σ = 0.04, w = 3 and m ∈ {0.02, 0.08}, nearly all replicates fail at exactly 2127.6 d with 0% R-driven. This looks like a deterministic late-phase limit-cycle overshoot as R slows the drug-on response, but it is not proven. **Open**, flagged rather than explained away.

### 4.3 What was *not* simulated

- Kalman/particle-filter estimation.
- The inner PK loop.
- Adherence noise.
- Spatial heterogeneity.
- PSA production by resistant cells ($\kappa<1$).
- Multi-drug switching.

Each is **Open**.

---

## 5. Stratification and indications

### 5.1 Decision tree

```
First cycle (dense sampling, Δ≤7 d)
   │
   ├─ Identify (r_S, τ, δ, θ) → Ĝ_min with bootstrap CI
   │
   ├─ CI_low(Ĝ_min) ≤ 1.5  → Standard of care (containment has little to gain;
   │                          consider cure-attempt strategies where they exist)
   ├─ 1.5 < CI_low ≤ 2      → Containment permitted, clinician discretion
   └─ CI_low > 2            → HOLDPOINT containment, margin m*(Δ,σ) from §3.3
```

The thresholds are proposals to be **preregistered**, not derived.

### 5.2 Eligibility conditions (all required)

| # | Condition | Why | Testable how |
|---|---|---|---|
| E1 | Trackable burden biomarker meeting margin law at achievable Δ, σ | §3.3 | Serial-assay variability study per marker |
| E2 | Effective drug with reversible, non-cumulative toxicity | Containment cycles drug indefinitely | Existing drug labels / trials |
| E3 | Competition between sensitive and resistant cells | Mechanism of benefit | Co-culture (companion §8.3) |
| E4 | No drug-induced resistance switching (Lemma 1 holds) | Otherwise withholding/applying drug changes $R_0$ | Same co-culture: resistant per-capita growth vs $n$, drug on vs off |
| E5 | Burden near the boundary is clinically tolerable | Setpoint is ~1.2× baseline minus margin | Site-specific clinical judgment |
| E6 | Cure not realistically available | Containment forgoes cure attempts | Clinical context; Hansen & Read framing (title-level only here) |

**Honest scope:** E1–E6 exclude many cancers, e.g. those without circulating markers, those treated with curative intent, and those with rapid plasticity. **Pan-cancer applicability is Speculative;** metastatic prostate is the lead indication because it satisfies E1 and E2 best.

---

## 6. Failure mode and effects analysis (FMEA)

| Failure mode | Cause | Effect | Detection | Mitigation | Residual risk |
|---|---|---|---|---|---|
| Controller overshoot | Margin < $m^\*$; lagging estimator | Burden > $n_p$ without resistance | S1 rule | Margin law; predictive estimator | Low if margin law enforced |
| Masked progression | Resistant cells produce little biomarker ($\kappa\ll1$) | Biomarker stable while disease grows | S3 imaging | Imaging cadence independent of biomarker | **Moderate — main clinical risk** |
| Lemma-1 violation | Drug-induced plasticity | Containment accelerates resistance | S2 rule (drug-on response slower than predicted) | Pre-enrolment co-culture test (E4) | Open |
| Sensor drift | Assay calibration / biofouling (EAB) | Biased burden estimate | Reference lab sample every N cycles | Recalibration; S5 fallback | Low–moderate |
| Non-adherence | Patient skips doses | Actual $u\ne$ commanded $u$ | Dispenser log; inner PK loop | Alerts | Low with inner loop |
| Model misspecification | 2-population model wrong for this tumour | Wrong $G_{\min}$ and margin | Posterior-predictive checks each cycle | Exit to SOC if checks fail | Moderate |
| Metastatic-site crisis | Local growth at critical site despite stable total burden | Organ damage | S4 | Exclude high-risk sites at enrolment | Moderate |

---

## 7. Hostile review

**H1. "This is just adaptive therapy with a new name."**
Partly true. The new elements are:
- the setpoint-at-boundary policy justified by a policy-independent ceiling (AT50 is not that policy and captures 7–38% of headroom);
- the derived margin law;
- the precision→time design law;
- the stratifier gating entry.

Novelty relative to Gallagher et al. 2026 (first-cycle biomarkers) and Viossat & Noble 2021 (containment theory) is **Open**, because I inspected only their abstracts.

**H2. "The model's 'progression' at 1.2× baseline is arbitrary."**
Correct. It is the convention used by Strobl et al. Clinical progression is radiographic or symptomatic. Ratios transfer better than absolute days, and even ratios are model-conditional.

**H3. "Daily sampling at 4% CV is unrealistic."**
Possibly. The PSA evidence conflicts (4% vs ~15% total CV). If ~15% holds at the timescales that matter, HOLDPOINT's gain over AT50 shrinks to 1.20× (weekly) or 1.74× (daily). It remains positive, but modest. **This is the decisive empirical unknown.**

**H4. "Holding burden near the boundary is clinically unacceptable."**
For some patients and sites, yes (E5). The margin is also a clinical dial: a larger $m$ trades TTP for lower held burden, quantified exactly by §3.4.

**H5. "Strongest objection: Lemma 1 may be false in real tumours."**
If drugs induce resistance (plasticity), the whole framework's premise fails. That is why E4 is an enrolment gate, S2 is a runtime monitor, and the co-culture test is the first development milestone. **What survives if Lemma 1 fails:** the sensing/actuation hardware and the safety supervisor, which then serve a differently-modelled controller.

---

## 8. Development path

| Stage | Deliverable | Go/no-go criterion (preregister) |
|---|---|---|
| D0 | Co-culture Lemma-1 test for lead drug–tumour pair | No resolved drug-on vs drug-off offset in resistant per-capita growth at matched density |
| D1 | Serial-marker variability study (daily and weekly draws, same patients) | Measured total σ at Δ = 1 and 7 d, enabling margin law to be parameterized |
| D2 | Retrospective replay of controller on existing adaptive-therapy PSA series (e.g., Bruchovsky IADT cohort, NCT02415621 data if accessible) | Controller decisions never violate S1–S3 in replay; stratifier $G_{\min}$ correlates with observed benefit |
| D3 | Animal study: xenograft with S/R-labelled cells, imaging-based burden, closed-loop dosing | HOLDPOINT TTP > AT50 TTP > MTD TTP, preregistered effect size |
| D4 | First-in-human feasibility: prostate, oral agent, dense home sampling, clinician-in-the-loop (controller recommends, clinician approves) | Feasibility + safety; no S-type failures beyond threshold |
| D5 | Randomized trial: HOLDPOINT vs AT50 vs continuous therapy | Primary endpoint radiographic PFS; secondary OS, cumulative dose, quality of life |

**Regulatory framing (Speculative):** software as a medical device plus combination product (sensor + dispenser/pump). Clinician-in-the-loop at D4 lowers risk class relative to autonomous dosing.

---

## 9. Epistemic ledger

| Claim | Tier |
|---|---|
| "Cures all cancers" as design target | **Withdrawn** |
| Lemma 1, Theorem 1 (model-internal) | Verified (companion document) |
| RK4 simulator reproduces LSODA reference | Verified |
| Moving-average controller lags fatally at weekly sampling | Verified (executed) |
| Margin law consistent with simulation in 5/6 regimes, conservative in 1 | Verified (heuristic rule) |
| Precision→time law within ~13% | Verified |
| HOLDPOINT ≥ AT50 at robust margins, all 6 regimes | Verified in-model |
| Monthly high-noise AT50 degrades to median 717.3 d | Verified in-model |
| Limit-cycle failure at 2127.6 d | **Open** (unexplained) |
| EAB closed-loop drug control in animals | Verified (sources inspected at abstract level) |
| EAB sensors for relevant anticancer drugs in humans | **UNKNOWN** |
| PSA total CV | **Open — sources disagree (4.0% vs ~15%)** |
| Biomarkers for non-prostate indications | Training knowledge, not re-verified |
| Clinical efficacy of HOLDPOINT | **Open** — no human data exist |
| Pan-cancer applicability | **Speculative** |

---

## 10. Sources

Inspection level stated for each.

1. Strobl et al., *Cancer Res* 81:1135 (2021) — model code inspected (see companion).
2. Mage PL, Ferguson BS, Maliniak D, Ploense KL, Kippin TE, Soh HT. *Closed-loop control of circulating drug levels in live animals.* Nat Biomed Eng 1:0070 (2017). — Abstract inspected.
3. Arroyo-Currás N et al. *Real-time measurement of small molecules directly in awake, ambulatory animals.* PNAS 114:645 (2017). — Reference listing only.
4. Emmons NA, Duman Z, Erdal MK, Hespanha J, Kippin TE, Plaxco KW. *Feedback control over plasma drug concentrations achieves rapid and accurate control over solid-tissue drug concentrations.* ACS Pharmacol Transl Sci 8(5):1416 (2025). — Abstract inspected.
5. *High-precision control of plasma drug levels using feedback-controlled dosing* (E-AB, 7-s updates, rats), ACS Pharmacol Transl Sci. — Abstract inspected.
6. Vancomycin E-AB sensor with closed-loop control in rats (PMC6886665). — Abstract inspected.
7. Christensson A et al. *Intra-individual short-term variability of PSA…* BJU Int (2011). — Abstract inspected.
8. Screening-cohort PSA biological variation, 84 men, 2-week intervals (Urology, ScienceDirect S0090429599803835). — Abstract inspected.
9. Biological variation of serum PSA, 24 patients (PubMed 9146611). — Conclusion inspected.
10. Gallagher K et al., *JAMA Oncol* 2026, doi:10.1001/jamaoncol.2026.2781. — Abstract only (see companion).
11. Viossat Y, Noble R, *Nat Ecol Evol* 5:826 (2021). — Abstract only (see companion).

---

## Appendix A. Reproduction code

Requires `model.py` from the companion document for the reference LSODA values. Run `python3 closedloop.py` (validation), then `python3 sweep_pred.py` (tables in §4).

### `closedloop.py`

```python
import numpy as np
# Vectorised RK4 of Strobl et al. model (cRS=cSR=1, dD=1.5); states shape (M,)
rS=0.027; dD=1.5
def f(s,r,u,rho,tau):
    n=s+r
    return rS*(1-n)*(1-dD*u)*s - tau*rS*s, rho*rS*(1-n)*r - tau*rS*r
def step(s,r,u,rho,tau,h):
    k1=f(s,r,u,rho,tau); k2=f(s+h/2*k1[0],r+h/2*k1[1],u,rho,tau)
    k3=f(s+h/2*k2[0],r+h/2*k2[1],u,rho,tau); k4=f(s+h*k3[0],r+h*k3[1],u,rho,tau)
    return s+h/6*(k1[0]+2*k2[0]+2*k3[0]+k4[0]), r+h/6*(k1[1]+2*k2[1]+2*k3[1]+k4[1])
def simulate(policy,M,n0=0.5,fR=1e-3,c=0.3,tau=0.25,Delta=1.0,sigma=0.0,margin=0.0,window=1,
             h=0.125,tmax=15000.,seed=1,exact_monitor=False):
    """policy: 'MTD' | 'AT50' | 'CONTAIN'. Decisions made only at sampling times k*Delta from
    noisy log-normal measurements y=n*exp(sigma*z). Baseline P0 estimated from 3 noisy samples.
    TTP = first time TRUE n exceeds 1.2*n0 (linear interpolation inside step). Returns TTP, mean dose."""
    rng=np.random.default_rng(seed); rho=1-c; npg=1.2*n0
    s=np.full(M,n0*(1-fR)); r=np.full(M,n0*fR)
    P0=n0*np.exp(sigma*rng.standard_normal((M,3))).mean(1) if sigma>0 else np.full(M,n0)
    u=np.ones(M) if policy in('MTD','AT50') else np.zeros(M)
    hist=[]; rfrac=np.full(M,np.nan); ttp=np.full(M,np.inf); dose=np.zeros(M); alive=np.ones(M,bool)
    nsteps_per=int(round(Delta/h)); t=0.0; k=0
    while t<tmax and alive.any():
        # decision at sampling time
        y=(s+r)*np.exp(sigma*rng.standard_normal(M)) if sigma>0 else (s+r).copy()
        hist.append(np.log(y)); hist=hist[-window:]
        est=np.exp(np.mean(hist,0))
        if policy=='AT50':
            u=np.where(est>P0,1.0,np.where(est<0.5*P0,0.0,u))
        elif policy=='CONTAIN':
            u=np.where(est>1.2*P0*(1-margin),1.0,0.0)
        elif policy=='PREDICT':
            # local linear fit of log y over last `window` samples, extrapolate to next decision time
            L=np.array(hist); w=L.shape[0]
            if w>=2:
                x=np.arange(w)*Delta; x=x-x.mean()
                slope=(x[:,None]*(L-L.mean(0))).sum(0)/(x**2).sum()
                level=L.mean(0)+slope*x[-1]
            else:
                slope=np.zeros(M); level=L[-1]
            pred=np.exp(level+np.maximum(slope,0)*Delta)
            u=np.where(pred>1.2*P0*(1-margin),1.0,0.0)
        for _ in range(nsteps_per):
            n_old=s+r
            s,r=step(s,r,u,rho,tau,h); t+=h
            n_new=s+r
            cross=alive&(n_new>npg)
            if cross.any():
                frac=(npg-n_old[cross])/(n_new[cross]-n_old[cross])
                ttp[cross]=t-h+frac*h; rfrac[cross]=r[cross]/n_new[cross]; alive&=~cross
            dose+=u*h*alive
    return ttp, dose/np.where(np.isfinite(ttp),ttp,t), rfrac
if __name__=="__main__":
    # validation vs LSODA reference (model.py): MTD 853.129, AT50 1477.174 (daily, noise-free)
    for p in ['MTD','AT50']:
        T,_,_=simulate(p,1); print(p,'RK4 h=0.125 TTP =',T[0])
    T,_,_=simulate("AT50",1,h=0.0625); print('AT50 h=0.0625 TTP =',T[0])
```

### `sweep_pred.py`

```python
from closedloop import simulate
import numpy as np
M=200
def summ(T,D,RF):
    rdom=np.mean(RF>0.5)
    return f"TTP p10/50/90 {np.percentile(T,10):7.1f} {np.median(T):7.1f} {np.percentile(T,90):7.1f} | dose {np.median(D):.3f} | R-driven fail {rdom:.2f}"
for Delta in [1,7,28]:
  for sigma in [0.04,0.15]:
    T,D,RF=simulate('AT50',M,Delta=Delta,sigma=sigma,seed=11); print(f"D={Delta:2d} s={sigma:.2f} AT50              ",summ(T,D,RF))
    for window in [3,6]:
      for margin in [0.02,0.08,0.15,0.30]:
        T,D,RF=simulate('PREDICT',M,Delta=Delta,sigma=sigma,margin=margin,window=window,seed=11)
        print(f"D={Delta:2d} s={sigma:.2f} PREDICT w={window} m={margin:.2f}",summ(T,D,RF))
T,D,RF=simulate('PREDICT',M,Delta=1,sigma=0.0,margin=0.01,window=3,seed=11); print("noise-free daily PREDICT m=.01",summ(T,D,RF))
```
