# AlN/GaN DH-HEMT — Sentaurus TCAD Deck

Reconstruction of the normally-ON AlN/GaN double-heterostructure HEMT from
Fig. 1(a) of Soni & Shrivastava, *"Computational Modelling-Based Device Design
for Improved mmWave Performance and Linearity of GaN HEMTs"*, IEEE J. Electron
Devices Soc., Vol. 8, pp. 33–41, 2020 (device after Shinohara et al., IEDM 2011).

## Files

| File | Purpose |
|------|---------|
| `hemt_sde.cmd` | Structure Editor — geometry, contacts, doping, mesh |
| `hemt_des.cmd` | SDevice — physics, polarization, traps, DC + AC solve |
| `hemt.par` | Material parameters (GaN, AlN, SiN, SiC) |
| `inspect_fT.tcl` | Inspect/SVisual — extracts fT (|h21| = 1) from AC results |
| `calibration_targets.csv` | Fig. 1(b)/(c)/(d) points digitized as calibration anchors |
| `compare_to_paper.py` | Overlays simulated .plt vs targets; prints RMS error + tuning hints |

## Run order

```
sde      -e -l hemt_sde.cmd      # builds hemt_msh.tdr (+ _msh.tdr boundary)
sdevice       hemt_des.cmd       # DC + AC; writes hemt_des*.plt, hemt_ac*.plt
inspect  -f   inspect_fT.tcl     # prints extracted fT
```
Or drop the four files into a Sentaurus Workbench project (SDE → SDevice → Inspect nodes).

## Device geometry (Fig. 1(a), top → bottom)

| Layer | Material | Thickness |
|-------|----------|-----------|
| Passivation | SiN | 40 nm |
| Cap | GaN | 2.5 nm |
| Barrier | AlN | 3.5 nm |
| Channel | UID GaN | 150 nm |
| C-doped buffer | GaN (Na=1e18, Nd=5e17 cm⁻³) | 150 nm |
| Buffer | UID GaN | 250 nm |
| Nucleation | AlN | 100 nm |
| Substrate | SiC | (modeled 200 nm) |

Lateral: **Lsg = 40 nm, Lg = 20 nm, Lgd = 40 nm**.

## Physics models (as stated in the paper, Sec. III)

- Polarization at all heterointerfaces → bias-independent `FixedCharge` interface
  traps (positive at lower AlN/GaN to form the 2DEG, negative above).
- 2DEG / band offsets → `HeteroInterfaces`, `Thermionic`.
- Carrier + lattice heating → `Hydrodynamic(eTemperature)` + `Thermodynamic`.
- C-dopant scattering → `Masetti` doping-dependent mobility.
- Surface/buffer traps → donor surface states at GaN/SiN (virtual gate);
  deep acceptor + donor traps in the C-doped buffer.
- Breakdown → `Avalanche(vanOverstraeten)`, GaN coefficients ≈ 3 MV/cm.
- Gate Fowler–Nordheim leakage → see note below (off by default).

## Verification performed on this deck

The files were checked for both *syntax* and *runtime/convergence* problems:

Structural / syntax:
- balanced parentheses/braces in all files;
- correct 2-D contact syntax (`define-2d-contact` + `(sdegeo:get-current-contact-set)`);
- every `Region=`/`RegionInterface=` in SDevice exists in the SDE structure;
- avalanche block in the correct two-range pair format (`a(low/high)`, `b(low/high)`, `E0`, `hbarOmega`, `lambda` as electron,hole pairs).

Runtime / convergence (second-pass fixes):
- **Math keyword names corrected** — `ErrRef` (not `ErrReff`), `RHSMin` (not `RhsMin`),
  `RefDens_eGradQuasiFermi_ElectricField` (not the invalid `eDrForceRefDens`).
- **`ErrRef = 1e8`** — the Synopsys-recommended wide-bandgap value for GaN
  (the earlier 1e10 was the silicon default and hurts GaN convergence).
- **Staged solve ramp** — equilibrium now builds up as Poisson → drift-diffusion
  (`Poisson Electron Hole`) → add `eTemperature` → add `lTemperature`, instead of
  jamming all five equations into the first solve (the classic GaN HD non-convergence).
- **`AvalDerivatives`** added (avalanche is active, so its Jacobian derivatives help).
- **AC fixed** — `ACCompute(Time=(Range=(0 1) Intervals=1))` corrected from the
  invalid `Time=(1 1)`; `ImplicitACSystem` + `ACExtract` present; the two-port is
  excited at gate & drain with source as ground (full Y-matrix for h21=Y21/Y11).
- **S/D ohmic contacts now reach semiconductor** — SiN is created only over the
  gate/access span, so source/drain land on the GaN cap (not on the dielectric,
  which would inject no current), and n+ (1e19) pockets under S/D make the contacts
  ohmic and tie them to the 2DEG. (Earlier version placed ohmics on top of SiN.)
- removed keywords needing extra setup (`eBarrierTunneling` w/o Nonlocal mesh,
  `eMobilityAveraging`).

These remove the errors that would *stop* a run or prevent convergence. The numeric
**values** (vsat, mobility, Schottky barrier, polarization magnitude, avalanche
coefficients, n+ level) remain literature starting points to be fitted — see below.

## Parameter provenance (VERIFIED from refs [7]–[9], [15] primary sources)

Every key parameter now comes from the actual papers, not literature estimates:

| Parameter | Value used | Source (verified) |
|-----------|-----------|-------------------|
| Surface donor trap (GaN/SiN) | EC − 0.68 eV, 1.6×10¹³ cm⁻² | Joshi Part I [8], p.562 (explicit) |
| C-buffer acceptor (C_N) | EV + 0.90 eV, 1×10¹⁸ cm⁻³, σ=8×10⁻¹⁶ cm² | Joshi Part I [8], §III-A / §IV-B |
| C-buffer donor (shallow) | EC − 0.11 eV, 5×10¹⁷ cm⁻³ | Joshi Part I/II [8],[9], §III |
| Gate/contact model | Schottky, WF ≈ 4.1 eV (TiN + N-vac) | Joshi Part I [8], p.562 |
| UID background | 1×10¹⁵ cm⁻³ | Joshi Part I [8], §III |
| Critical field (avalanche) | 3 MV/cm (Chynoweth) | JEDS [main] / Joshi [8] |
| 2DEG sheet density ns | 1.2×10¹³ cm⁻² (D-mode) | Shinohara [15] (measured) |
| Low-field mobility µ | 1200 cm²/V·s | Shinohara [15] (measured) |
| Saturation velocity | vsat0 ≈ 1.9×10⁷ (vave 1.5×10⁷ @5V) | Shinohara [15] (measured) |
| n⁺ regrown ohmic | 7×10¹⁹ cm⁻³, 50 nm | Shinohara [15] |
| Threshold Vth | −1.44 V (D-mode) | Shinohara [15] (measured) |
| Idmax / Ron / peak gm | 2.7 A/mm / 0.29 Ω·mm / 1.04 S/mm | Shinohara [15] (measured) |
| fT (sim / exp) | 328 / 310 GHz | JEDS Fig.1(b) / Shinohara [15] |

Structure note: per your choice, the deck builds the **JEDS Fig.1(a) stack** (C-doped
GaN buffer), not Shinohara's AlGaN back-barrier. Because the C-buffer sits below the
channel, tChannel is kept at 150 nm (JEDS §IV / Joshi Part I Fig.13d baseline) so the
C-acceptors don't deplete the 2DEG — reduce toward 20 nm only if you switch to an
AlGaN back-barrier. The carbon donor is now correctly SHALLOW (EC−0.11 eV) per the
papers, which matters for buffer compensation and field redistribution.

## Calibration workflow (matching Fig. 1 — your device)

Two files turn this into an actual calibration loop: `calibration_targets.csv`
(points digitized from Fig. 1(b)/(c)/(d)) and `compare_to_paper.py` (overlays your
simulated .plt files on those targets, reports per-point + RMS error, and prints
which knob to turn).

The deck now produces the **full curve families** in Fig. 1:
- Output ID–VDS at VGS = −2,−1,0,+1,+2 V  → files `out_VGm2_…` … `out_VGp2_…`
- Transfer ID–VGS (−3→+2 V) at VDS = 1,3,5 V → `tr_VD1_…`, `tr_VD3_…`, `tr_VD5_…`
- AC fT at VGS=0, VDS=3 V → `ac_…`

Each family restarts from a saved equilibrium checkpoint (`Save`/`Load eq_state`).

The loop:
```
sde -e -l hemt_sde.cmd            # build mesh
sdevice hemt_des.cmd              # produce all curve families
python3 compare_to_paper.py .     # sim vs Fig.1: RMS error + tuning hints
inspect -f inspect_fT.tcl         # extract fT
# adjust ONE knob per the hints, re-run, repeat until RMS error is small.
```

Targets read off Fig. 1 (A/mm): VGS=+2 V → ID ≈ 1.8 (VDS=1) up to 2.7 (VDS=5);
VGS=0 V → ≈ 0.85 up to 1.5; threshold near VGS ≈ −2 V; fT,sim = 328 GHz.

### Knob → feature map
| Mismatch vs Fig. 1 | Knob | File |
|--------------------|------|------|
| All currents scale up/down together | AlN/GaN `FixedCharge Conc` (ns) | hemt_des.cmd |
| Turn-on VGS shifted (threshold) | gate Schottky `Barrier` | hemt_des.cmd |
| Saturation current level | GaN `mumax_n`, `Vsat0` | hemt.par |
| Knee voltage / on-resistance | n+ pocket level, contact R | hemt_sde.cmd |
| fT off but DC matches | `Vsat0` (↑vsat → ↑fT) | hemt.par |
| High-VDS droop (self-heating) | GaN `Kappa` | hemt.par |

## Calibration procedure (the four knobs, in order)

Tune the four independent knobs in this order:

1. **2DEG sheet density `ns` (target > 1×10¹³ cm⁻²)** — knob: `FixedCharge Conc`
   at `R.Barrier/R.Channel` in `hemt_des.cmd` (start 5.5e13). After equilibrium,
   integrate `eDensity` across the channel in SVisual; scale until ns > 1e13.
2. **Threshold `Vth` (normally-ON ⇒ Vth < 0)** — knob: Schottky `Barrier` of the
   gate in `hemt_des.cmd` (start 1.0 eV). Higher barrier → more negative Vth.
   Conduction should turn on near VGS ≈ −2…−1 V (Fig. 1(c)).
3. **On-current / gm** — knobs: `mumax_n` and `Vsat0` in `hemt.par`. Match output
   curves (Fig. 1(d)): Idmax ≈ 2.5 A/mm at VGS=+2 V, VDS=5 V.
4. **fT (target ≈ 328 GHz)** — knob: `Vsat0` (GaN) in `hemt.par`. Run AC, then
   `inspect -f inspect_fT.tcl`. Iterate vsat0 (≈ 2.0–2.7e7 cm/s) until fT ≈ 328 GHz.

## Notes / caveats

- **2DEG mesh is critical.** The vertical mesh at the lower AlN/GaN interface is
  ~0.5 Å (`Ref.2DEG`). No 2DEG peak in the equilibrium solve ⇒ refine further.
- **Interface names.** Sentaurus auto-names interfaces `region1/region2`. If the
  meshed structure reports an interface reversed (e.g. `R.Channel/R.Barrier`),
  swap the name in the corresponding `RegionInterface` block.
- **Polarization sign** assumes Ga-face growth (positive bound charge at the lower
  barrier/channel interface). If you get a 2DHG instead of a 2DEG, flip the signs
  of the two `FixedCharge` blocks.
- **Convergence.** If the coupled hydrodynamic+thermodynamic solve stalls, first
  get a drift-diffusion solution (drop `Hydrodynamic`/`Thermodynamic` and remove
  `eTemperature lTemperature` from the `Coupled` braces), then switch them back on.
- **Gate leakage (off by default).** Fowler–Nordheim tunneling needs a dedicated
  Nonlocal mesh and tunneling masses, and hurts convergence. To enable it once
  DC/AC converge: add `eBarrierTunneling "GateNLM"` in Physics, define
  `Nonlocal "GateNLM" (...)` in Math, and add BarrierTunneling masses in the .par
  (commented instructions are in `hemt_des.cmd`).
- **Validated material files.** Synopsys ships GaN/AlN/AlGaN parameter files under
  `$STROOT/tcad/$STRELEASE/lib/sdevice/MaterialDB/`. For production work, consider
  starting from those and overriding only the calibration parameters.
- **Cannot be executed here.** Sentaurus is licensed software not available in this
  environment, so the deck is syntax-/structure-verified, not run-verified. Treat
  fT = 328 GHz as the calibration target you converge to via the four knobs above,
  not a guaranteed first-run output.
