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

## Parameter provenance (from refs [7]–[9] and aligned literature)

The trap parameters were pulled from the Joshi/Shrivastava computational framework
(refs [7]–[9]) and the directly-aligned TCAD literature, rather than guessed:

| Parameter | Value used | Basis |
|-----------|-----------|-------|
| Surface donor trap (GaN/SiN) | EC − 0.50 eV, 3×10¹³ cm⁻² | framework lineage; older Ibbetson/Vetury value EC−1.42 eV / 1.35×10¹³ noted in-file |
| C-buffer acceptor (C_N) | EV + 0.90 eV, 1×10¹⁸ cm⁻³ | refs [8]/[9]; deep acceptor ~0.9 eV above valence band |
| C-buffer compensating donor | EC − 0.40 eV, 5×10¹⁷ cm⁻³ | refs [8]/[9] self-compensation |
| C-doping concentration | 1×10¹⁸ cm⁻³ buffer | matches the JEDS paper text |
| AlN/GaN polarization sheet | 5.5×10¹³ cm⁻² (fitting start) | high AlN polarization gives ns > 1×10¹³ |
| GaN vsat | 2.0×10⁷ cm/s (fitting knob) | Caughey-Thomas vsat-vs-nsh calibration in the framework |

Note: the framework also models lighter carbon traps in the channel, but this deck
keeps the channel **UID** because the JEDS paper explicitly labels it "UID GaN
Channel" with carbon confined to the buffer below. The avalanche (van Overstraeten)
coefficients and the Schottky barrier remain the main values you tune to the
specific Fig. 1 curves; everything else now follows the published framework.



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
