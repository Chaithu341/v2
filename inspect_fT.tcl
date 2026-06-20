#==============================================================================
#  inspect_fT.tcl  --  Extract cut-off frequency fT from SDevice AC results
#                      using the built-in RF-extraction (rfx) toolkit.
#
#  fT = frequency where the small-signal current gain |h21| = 1 (0 dB).
#  This mirrors the Synopsys "DC and RF Characterization of HEMTs" template.
#
#  Run:  inspect -f inspect_fT.tcl
#  (or load in Sentaurus Visual; the rfx_* commands are available in both.)
#==============================================================================

# --- 1. Locate the AC plot file produced by ACExtract = "hemt_ac" ----------
#     SDevice writes "<ACExtract>_ac.plt" (a small-signal/Y-parameter file).
set acfile "hemt_ac_ac.plt"
if { ![file exists $acfile] } { set acfile "hemt_ac.plt" }

# --- 2. Load it into the RF-extraction system ------------------------------
#     rfx_load builds the bias-point list (rfx_BiasPoints) and frequency list
#     (rfx_Frequencies) and sets up two-port network analysis automatically.
rfx_load $acfile

# Define the two-port: input = gate, output = drain, common = source.
rfx_set -port1 gate -port2 drain -ground source

# --- 3. Extract fT --------------------------------------------------------
#  Method A: direct unity-gain search on |h21|.
#  Method B: extrapolation assuming -20 dB/decade from the 10 dB point
#            (robust when the curve does not reach 0 dB within the sweep).
set ft_direct [rfx_extractFt -Method extract-at-unitygain]
set ft_extrap [rfx_extractFt -Method extract-at-dBPoint -dB 10]

puts "================================================================"
puts " Cut-off frequency extraction (AlN/GaN HEMT)"
puts "----------------------------------------------------------------"
puts [format "  fT (unity-gain, |h21|=1)        = %8.2f GHz" [expr {$ft_direct/1e9}]]
puts [format "  fT (-20 dB/dec extrapolation)   = %8.2f GHz" [expr {$ft_extrap/1e9}]]
puts "  Paper simulated target          ~  328.00 GHz"
puts "================================================================"

# --- 4. Plot |h21| in dB vs frequency for visual confirmation -------------
set h21 [rfx_h21]                      ;# magnitude of h21 vs frequency
cv_createWithFormula h21dB "20*log10(<$h21>)" A A
cv_display h21dB
cv_setCurveAttr h21dB "|h21| (dB)" blue solid 2 none 0 0

#==============================================================================
#  FALLBACK (if your Sentaurus release lacks some rfx_* helpers):
#  Build |h21| = |Y21/Y11| by hand from the AC Y-parameters in the .plt header.
#  Inspect the .plt column names first, then map them below.
#
#  proj_load $acfile AC
#  set ReY11 "AC Intr Y(gate,gate) real" ; set ImY11 "AC Intr Y(gate,gate) imag"
#  set ReY21 "AC Intr Y(drain,gate) real"; set ImY21 "AC Intr Y(drain,gate) imag"
#  cv_createWithFormula magY11 "sqrt(<$ReY11>^2+<$ImY11>^2)" A A
#  cv_createWithFormula magY21 "sqrt(<$ReY21>^2+<$ImY21>^2)" A A
#  cv_createWithFormula h21m   "<magY21>/<magY11>"           A A
#  set fT [cv_compute "vecvalx(<h21m>,1.0)" A A A A]
#  puts [format "fallback fT = %.2f GHz" [expr {$fT/1e9}]]
#==============================================================================
