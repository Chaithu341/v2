#==============================================================================
#  SDevice command file  -- AlN/GaN DH-HEMT (Soni & Shrivastava, JEDS 2020, Fig.1)
#
#  Sequence:
#    (0) DRIFT-DIFFUSION equilibrium  (robust initial guess)
#    (0b) introduce carrier temperature (Hydrodynamic), then lattice (Thermo)
#    (1) ramp VDS = 1 V
#    (2) TRANSFER : VGS  -3 -> +2 V at VDS = 1 V   (calibrate gm, Vth)
#    (3) OUTPUT   : VDS   0 -> +5 V at VGS = 0      (calibrate Idsat)
#    (4) AC small-signal sweep at VGS=0, VDS=3V -> extract fT (|h21| = 1)
#
#  Calibration targets:  fT(sim) ~ 328 GHz ; Imax ~ 2.5-3 A/mm ; Ecrit(GaN)=3MV/cm
#==============================================================================

#------------------------------------------------------------------------------
File {
   Grid      = "hemt_msh.tdr"
   Plot      = "hemt_des.tdr"
   Current   = "hemt_des.plt"
   Output    = "hemt_des.log"
   Parameter = "hemt.par"
   ACExtract = "hemt_ac"        # required for AC small-signal output
}

#------------------------------------------------------------------------------
Electrode {
   { Name = "source" Voltage = 0.0 }
   { Name = "drain"  Voltage = 0.0 }
   # Schottky gate (Ni-like). Barrier tuned so Vth < 0 (normally-ON, as in paper).
   { Name = "gate"   Voltage = 0.0  Schottky  Barrier = 1.0 }
}

#------------------------------------------------------------------------------
#  POLARIZATION as fixed interface charges (convergence-friendly route).
#  Positive sheet charge at the LOWER barrier/channel interface forms the 2DEG;
#  negative above for charge neutrality. Magnitudes (cm^-2) give ns > 1e13.
#  (Interface names follow Sentaurus "region1/region2" auto-naming. If a name is
#   not found, check the meshed structure and swap order, e.g. R.Channel/R.Barrier.)
#------------------------------------------------------------------------------
Physics (RegionInterface = "R.Barrier/R.Channel") {
   Traps ( ( FixedCharge Conc = 5.5e13 ) )    # +polarization -> 2DEG
}
Physics (RegionInterface = "R.Cap/R.Barrier") {
   Traps ( ( FixedCharge Conc = -5.5e13 ) )   # -polarization (top)
}
Physics (RegionInterface = "R.Buffer/R.Nucleation") {
   Traps ( ( FixedCharge Conc = -3.0e13 ) )   # back interface compensation
}

#------------------------------------------------------------------------------
#  Surface donor states (virtual-gate physics, Sec.V-A): GaN-cap / SiN interface.
#  Values from the Joshi/Shrivastava framework lineage (refs [7]-[9]):
#    donor-type surface trap at EC - 0.5 eV, areal density 3e13 cm^-2.
#  (Some works use the older Ibbetson/Vetury value EC-1.42 eV, 1.35e13 cm^-2;
#   to switch, set EnergyMid = 1.42 and Conc = 1.35e13.)
#------------------------------------------------------------------------------
Physics (RegionInterface = "R.Cap/R.SiN") {
   Traps (
      ( Donor Level fromCondBand EnergyMid = 0.50  Conc = 3e13
        eXsection = 1e-14  hXsection = 1e-14 )
   )
}

#------------------------------------------------------------------------------
#  C-doped buffer traps (Joshi/Shrivastava, refs [8]/[9]): self-compensating
#  carbon = deep ACCEPTOR (C_N, ~0.9 eV ABOVE valence band) + compensating
#  DONOR (~0.4 eV below conduction band). Concentrations follow the paper
#  (Na=1e18, Nd=5e17) with the framework's standard energy levels.
#------------------------------------------------------------------------------
Physics (Region = "R.CBuffer") {
   Traps (
      ( Acceptor Level fromValBand  EnergyMid = 0.90 Conc = 1e18
        eXsection = 1e-15 hXsection = 1e-15 )
      ( Donor    Level fromCondBand EnergyMid = 0.40 Conc = 5e17
        eXsection = 1e-15 hXsection = 1e-15 )
   )
}

#------------------------------------------------------------------------------
#  Global physical models
#------------------------------------------------------------------------------
Physics {
   AreaFactor = 1.0

   Hydrodynamic ( eTemperature )       # carrier heating / velocity overshoot
   Thermodynamic                       # lattice self-heating

   Mobility (
      DopingDependence ( Masetti )     # C-dopant scattering
      HighFieldSaturation ( CarrierTempDrive )
      Enormal                          # 2DEG / interface mobility
   )

   EffectiveIntrinsicDensity ( OldSlotboom )

   Recombination (
      SRH ( DopingDependence )
      Auger
      Avalanche ( vanOverstraeten Eparallel )   # impact ionization (VBD);
                                                 # reads "vanOverstraetendeMan"
                                                 # block in hemt.par
   )

   Thermionic                          # thermionic emission at heterojunctions
   HeteroInterfaces

   Temperature = 300

   # Gate Fowler-Nordheim leakage (eBarrierTunneling) intentionally OFF in the
   # baseline (needs a Nonlocal mesh + tunneling masses; hurts convergence).
   # To enable once DC/AC converge:
   #   Physics{}: eBarrierTunneling "GateNLM"
   #   Math{}:    Nonlocal "GateNLM" ( RegionInterface="R.Cap/R.SiN"
   #                                   Length=5e-7 Permeation=1e-7 )
   #   hemt.par:  BarrierTunneling mass parameters per material.
}

#------------------------------------------------------------------------------
Plot {
   eDensity hDensity eCurrent hCurrent
   ElectricField/Vector Potential SpaceCharge
   eMobility hMobility eVelocity
   eTemperature lTemperature
   ConductionBandEnergy ValenceBandEnergy eQuasiFermiEnergy
   SRHRecombination Auger AvalancheGeneration
   eTrappedCharge hTrappedCharge
}

#------------------------------------------------------------------------------
Math {
   Extrapolate
   Derivatives
   RelErrControl
   Digits = 5
   # Wide-bandgap (GaN): tighten density reference from default 1e10 to 1e8.
   # (Synopsys AlGaN-HEMT guidance; smaller values do not help convergence.)
   ErrRef(electron) = 1e8
   ErrRef(hole)     = 1e8
   RefDens_eGradQuasiFermi_ElectricField = 1e8
   RefDens_hGradQuasiFermi_ElectricField = 1e8
   Iterations = 20
   Notdamped  = 100
   Method = Blocked
   SubMethod = Super
   AvalDerivatives             # include avalanche-rate derivatives in Jacobian
                               # (improves robustness; Avalanche IS active)
   ExitOnFailure
   CNormPrint
   DirectCurrent
   RHSMin = 1e-10

   # AC small-signal: implicit single-device circuit (no System section needed)
   ImplicitACSystem
   ACMethod    = Blocked
   ACSubMethod = Super
}

#------------------------------------------------------------------------------
Solve {
   #--- (0) DRIFT-DIFFUSION equilibrium (robust initial guess) ----------------
   NewCurrentPrefix = "init_"
   Coupled ( Iterations = 200 LineSearchDamping = 1e-2 ) { Poisson }
   Coupled ( Iterations = 100 ) { Poisson Electron Hole }

   #--- (0b) bring in carrier temperature, then lattice temperature -----------
   Coupled ( Iterations = 100 ) { Poisson Electron Hole eTemperature }
   Coupled ( Iterations = 100 ) { Poisson Electron Hole eTemperature lTemperature }

   Plot ( FilePrefix = "equilibrium" )

   #--- (1) ramp drain to 1 V -------------------------------------------------
   Quasistationary (
      InitialStep = 0.01 MaxStep = 0.1 MinStep = 1e-6 Increment = 1.3
      Goal { Name = "drain" Voltage = 1.0 }
   ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }

   #--- (2) TRANSFER : VGS -3 -> +2 V at VDS=1V -------------------------------
   NewCurrentPrefix = "transfer_VD1_"
   Quasistationary (
      InitialStep = 0.02 MaxStep = 0.05 MinStep = 1e-6
      Goal { Name = "gate" Voltage = -3.0 }
   ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }
   Quasistationary (
      InitialStep = 0.01 MaxStep = 0.05 MinStep = 1e-6
      Goal { Name = "gate" Voltage = 2.0 }
   ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }

   #--- (3) set VGS=0, reset VDS=0, then OUTPUT sweep VDS 0->5 V --------------
   NewCurrentPrefix = "setVG_"
   Quasistationary (
      InitialStep = 0.02 MaxStep = 0.05 MinStep = 1e-6
      Goal { Name = "gate" Voltage = 0.0 }
   ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }
   NewCurrentPrefix = "resetVD_"
   Quasistationary (
      InitialStep = 0.05 MaxStep = 0.1 MinStep = 1e-6
      Goal { Name = "drain" Voltage = 0.0 }
   ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }
   NewCurrentPrefix = "output_VG0_"
   Quasistationary (
      InitialStep = 0.01 MaxStep = 0.05 MinStep = 1e-6
      Goal { Name = "drain" Voltage = 5.0 }
   ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }

   #--- (4) AC small-signal at fT bias (VGS=0, VDS=3V) -> extract fT ----------
   #     Re-establish VDS=3V from the converged DC state, then sweep frequency.
   #     For h21 = Y21/Y11 we need the full two-port admittance matrix, so all
   #     active nodes (gate, drain) are stimulated and NONE are excluded.
   #     (source is the common/ground reference.) The post-processing script
   #     inspect_fT.tcl forms |h21| and locates the |h21|=1 crossing.
   NewCurrentPrefix = "ac_"
   Quasistationary (
      InitialStep = 0.02 MaxStep = 0.05 MinStep = 1e-6
      Goal { Name = "drain" Voltage = 3.0 }
   ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }

   Quasistationary (
      InitialStep = 0.1 MaxStep = 0.1 MinStep = 1e-6
      Goal { Name = "gate" Voltage = 0.0 }
   ){
      ACCoupled (
         StartFrequency = 1e8  EndFrequency = 1e12
         NumberOfPoints = 61  Decade
         Node ( "gate" "drain" )
         Exclude ( "source" )
         ACCompute ( Time = (Range = (0 1) Intervals = 1) )
      ){ Poisson Electron Hole }
   }
}
