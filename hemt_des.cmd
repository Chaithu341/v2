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
   # Schottky gate. Joshi/Shrivastava (refs [7]-[9]) model the contacts as Schottky
   # with a low metal work function ~4.1 eV (TiN alloy + N vacancies). In Sentaurus
   # the Schottky 'Barrier' keyword = (metal workfunction - intrinsic reference);
   # with GaN affinity ~4.1 eV a 4.1 eV metal gives a small effective barrier. Use
   # a low Barrier here; the normally-ON Vth = -1.44 V (Shinohara D-mode) is set
   # mainly by the polarization charge / 2DEG, so tune Vth via the FixedCharge
   # below, and adjust this Barrier only for fine Vth/gate-leakage correction.
   { Name = "gate"   Voltage = 0.0  Schottky  Barrier = 0.3 }
}

#------------------------------------------------------------------------------
#  POLARIZATION as fixed interface charges (convergence-friendly route).
#  Positive sheet charge at the LOWER barrier/channel interface forms the 2DEG.
#  TARGET: Shinohara D-mode 2DEG ns = 1.2e13 cm^-2 (measured). The AlN/GaN
#  spontaneous+piezo polarization is ~5e13 cm^-2 of bound charge, but the FREE
#  2DEG (and hence Vth=-1.44 V) is set by the net charge after the surface-donor
#  and back-barrier contributions. Start here and tune so the extracted channel
#  electron sheet density integrates to ~1.2e13 cm^-2.
#  (Interface names follow Sentaurus "region1/region2" auto-naming. If a name is
#   not found, check the meshed structure and swap order, e.g. R.Channel/R.Barrier.)
#------------------------------------------------------------------------------
Physics (RegionInterface = "R.Barrier/R.Channel") {
   Traps ( ( FixedCharge Conc = 5.0e13 ) )    # +polarization -> 2DEG (tune to ns=1.2e13)
}
Physics (RegionInterface = "R.Cap/R.Barrier") {
   Traps ( ( FixedCharge Conc = -5.0e13 ) )   # -polarization (top)
}
Physics (RegionInterface = "R.Buffer/R.Nucleation") {
   Traps ( ( FixedCharge Conc = -3.0e13 ) )   # back interface compensation
}

#------------------------------------------------------------------------------
#  Surface donor states (virtual-gate physics, Sec.V-A): GaN-cap / SiN interface.
#  VERIFIED from Joshi Part I (refs [8], p.562, citing [15]): donor-type surface
#  trap at EC - 0.68 eV with constant areal density 1.6e13 cm^-2, chosen to
#  compensate surface hole density and set the required ns and gate leakage.
#------------------------------------------------------------------------------
Physics (RegionInterface = "R.Cap/R.SiN") {
   Traps (
      ( Donor Level fromCondBand EnergyMid = 0.68  Conc = 1.6e13
        eXsection = 1e-14  hXsection = 1e-14 )
   )
}

#------------------------------------------------------------------------------
#  C-doped buffer traps (Joshi Part I, refs [8]): self-compensating carbon.
#  VERIFIED energy levels:
#    deep ACCEPTOR  C_N at EV + 0.90 eV  (Lyons/Van de Walle [4] in Part I)
#    shallow DONOR  at  EC - 0.11 eV     (Part I, sec III-B / Part II sec III)
#  Concentrations follow the JEDS paper text (Na=1e18, Nd=5e17). The electron
#  capture cross section of the acceptor (8e-16 cm^2 in Part I) controls how
#  strongly avalanche electrons are captured -> affects VBD and dispersion.
#------------------------------------------------------------------------------
Physics (Region = "R.CBuffer") {
   Traps (
      ( Acceptor Level fromValBand  EnergyMid = 0.90 Conc = 1e18
        eXsection = 8e-16 hXsection = 8e-16 )
      ( Donor    Level fromCondBand EnergyMid = 0.11 Conc = 5e17
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
#  Solve sequence — produces the full Fig.1 curve FAMILIES for calibration:
#    (b) AC fT at the peak-fT bias
#    (c) TRANSFER ID-VGS (-3..+2 V) at VDS = 1,2,3,4,5 V          (5 curves)
#    (d) OUTPUT   ID-VDS ( 0..+5 V) at VGS = -2,-1,0,+1,+2 V      (5 curves)
#  Each curve is written to its own current-file prefix so the calibration
#  script can overlay every one against the digitized targets.
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

   Save ( FilePrefix = "eq_state" )    # checkpoint to restart each sweep family

   #===========================================================================
   #  (d) OUTPUT CHARACTERISTICS : ID-VDS at VGS = -2,-1,0,+1,+2 V
   #      For each VGS: set gate, reset drain to 0, sweep drain 0->5 V.
   #===========================================================================
   #--- VGS = -2 V ---
   Load ( FilePrefix = "eq_state" )
   Quasistationary ( InitialStep=0.05 MaxStep=0.1 MinStep=1e-6
      Goal { Name="gate" Voltage=-2.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }
   NewCurrentPrefix = "out_VGm2_"
   Quasistationary ( InitialStep=0.01 MaxStep=0.05 MinStep=1e-6 Increment=1.3
      Goal { Name="drain" Voltage=5.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }

   #--- VGS = -1 V ---
   Load ( FilePrefix = "eq_state" )
   Quasistationary ( InitialStep=0.05 MaxStep=0.1 MinStep=1e-6
      Goal { Name="gate" Voltage=-1.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }
   NewCurrentPrefix = "out_VGm1_"
   Quasistationary ( InitialStep=0.01 MaxStep=0.05 MinStep=1e-6 Increment=1.3
      Goal { Name="drain" Voltage=5.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }

   #--- VGS = 0 V ---
   Load ( FilePrefix = "eq_state" )
   NewCurrentPrefix = "out_VG0_"
   Quasistationary ( InitialStep=0.01 MaxStep=0.05 MinStep=1e-6 Increment=1.3
      Goal { Name="drain" Voltage=5.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }

   #--- VGS = +1 V ---
   Load ( FilePrefix = "eq_state" )
   Quasistationary ( InitialStep=0.05 MaxStep=0.1 MinStep=1e-6
      Goal { Name="gate" Voltage=1.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }
   NewCurrentPrefix = "out_VGp1_"
   Quasistationary ( InitialStep=0.01 MaxStep=0.05 MinStep=1e-6 Increment=1.3
      Goal { Name="drain" Voltage=5.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }

   #--- VGS = +2 V ---
   Load ( FilePrefix = "eq_state" )
   Quasistationary ( InitialStep=0.05 MaxStep=0.1 MinStep=1e-6
      Goal { Name="gate" Voltage=2.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }
   NewCurrentPrefix = "out_VGp2_"
   Quasistationary ( InitialStep=0.01 MaxStep=0.05 MinStep=1e-6 Increment=1.3
      Goal { Name="drain" Voltage=5.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }

   #===========================================================================
   #  (c) TRANSFER CHARACTERISTICS : ID-VGS (-3..+2 V) at VDS = 1,2,3,4,5 V
   #      For each VDS: restart, ramp drain to target, ramp gate to -3, sweep +2.
   #===========================================================================
   #--- VDS = 1 V ---
   Load ( FilePrefix = "eq_state" )
   Quasistationary ( InitialStep=0.02 MaxStep=0.1 MinStep=1e-6
      Goal { Name="drain" Voltage=1.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }
   Quasistationary ( InitialStep=0.02 MaxStep=0.05 MinStep=1e-6
      Goal { Name="gate" Voltage=-3.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }
   NewCurrentPrefix = "tr_VD1_"
   Quasistationary ( InitialStep=0.01 MaxStep=0.05 MinStep=1e-6
      Goal { Name="gate" Voltage=2.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }

   #--- VDS = 3 V ---
   Load ( FilePrefix = "eq_state" )
   Quasistationary ( InitialStep=0.02 MaxStep=0.1 MinStep=1e-6
      Goal { Name="drain" Voltage=3.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }
   Quasistationary ( InitialStep=0.02 MaxStep=0.05 MinStep=1e-6
      Goal { Name="gate" Voltage=-3.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }
   NewCurrentPrefix = "tr_VD3_"
   Quasistationary ( InitialStep=0.01 MaxStep=0.05 MinStep=1e-6
      Goal { Name="gate" Voltage=2.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }

   #--- VDS = 5 V ---
   Load ( FilePrefix = "eq_state" )
   Quasistationary ( InitialStep=0.02 MaxStep=0.1 MinStep=1e-6
      Goal { Name="drain" Voltage=5.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }
   Quasistationary ( InitialStep=0.02 MaxStep=0.05 MinStep=1e-6
      Goal { Name="gate" Voltage=-3.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }
   NewCurrentPrefix = "tr_VD5_"
   Quasistationary ( InitialStep=0.01 MaxStep=0.05 MinStep=1e-6
      Goal { Name="gate" Voltage=2.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }

   #===========================================================================
   #  (b) AC small-signal at the fT bias (peak-gm region): VGS=0, VDS=3 V.
   #      Sweep frequency; inspect_fT.tcl forms |h21|=|Y21/Y11| and finds fT.
   #===========================================================================
   Load ( FilePrefix = "eq_state" )
   Quasistationary ( InitialStep=0.02 MaxStep=0.05 MinStep=1e-6
      Goal { Name="drain" Voltage=3.0 } ){ Coupled { Poisson Electron Hole eTemperature lTemperature } }
   NewCurrentPrefix = "ac_"
   Quasistationary ( InitialStep=0.1 MaxStep=0.1 MinStep=1e-6
      Goal { Name="gate" Voltage=0.0 } ){
      ACCoupled (
         StartFrequency = 1e8  EndFrequency = 1e12
         NumberOfPoints = 61  Decade
         Node ( "gate" "drain" )
         Exclude ( "source" )
         ACCompute ( Time = (Range = (0 1) Intervals = 1) )
      ){ Poisson Electron Hole }
   }
}
