;;==============================================================================
;;  SDE (Sentaurus Structure Editor) script
;;  Device : 20-nm gate D-mode AlN/GaN/AlGaN DH-HEMT (self-aligned gate)
;;           K. Shinohara et al., IEDM 2011, "Deeply-Scaled Self-Aligned-Gate
;;           GaN DH-HEMTs with Ultrahigh Cutoff Frequency", Fig.1 & Fig.2(a).
;;
;;  D-mode epi stack (top -> bottom), Fig.2(a):
;;     n+-GaN regrown ohmic   : 50  nm , 7e19 cm^-3   (SOURCE & DRAIN only)
;;     GaN Cap                : 2.5 nm
;;     AlN Top Barrier        : 3.5 nm
;;     GaN Channel            : 20  nm
;;     Al0.08Ga0.92N Back Barr: 50  nm  (thickness not given -> 50nm assumed)
;;     (buffer) GaN           : 300 nm  (not given -> assumed for confinement)
;;     S.I. SiC substrate     : 200 nm  (modeled portion)
;;     SiN passivation on the top surface (over the gate/access region)
;;
;;  Lateral (Fig.1 TEM):  Lg = 20 nm, Lsd = 100 nm, Lsw = 40 nm
;;     => Lsg = Lgd = 40 nm ; Lsd = Lsg + Lg + Lgd = 40+20+40 = 100 nm  (checks)
;;     SOURCE & DRAIN n+ region length = 100 nm each (per instruction).
;;
;;  Coordinates: x lateral (source left -> drain right), y vertical DOWNWARD,
;;               y = 0 at the top surface of the n+/cap.
;;==============================================================================

(sde:clear)
(sdegeo:set-default-boolean "ABA")        ; later region overrides earlier on overlap

;;------------------------------------------------------------------------------
;; 1. PARAMETERS  (micrometers)
;;------------------------------------------------------------------------------
;; lateral
(define Lsrc  0.100)        ; source n+ length (instruction)
(define Lsg   0.040)        ; source-to-gate (Lsw)
(define Lg    0.020)        ; gate length
(define Lgd   0.040)        ; gate-to-drain (Lsw)
(define Ldrn  0.100)        ; drain n+ length (instruction)

;; vertical layer thicknesses
(define t_nplus 0.050)      ; n+-GaN regrown ohmic (source/drain caps)
(define t_cap   0.0025)     ; GaN cap
(define t_barr  0.0035)     ; AlN top barrier
(define t_chan  0.020)      ; GaN channel
(define t_back  0.050)      ; Al0.08Ga0.92N back barrier (assumed thickness)
(define t_buf   0.300)      ; GaN buffer (assumed)
(define t_sub   0.200)      ; SiC substrate (modeled portion)
(define t_SiN   0.040)      ; SiN passivation (above access/gate region)

(define Wdev (+ Lsrc Lsg Lg Lgd Ldrn))     ; = 0.300 um total width

;; lateral landmark x-coordinates
(define x0       0.0)
(define x_src_r  Lsrc)                       ; 0.100  source n+ right edge
(define x_gate_l (+ Lsrc Lsg))               ; 0.140  gate left edge
(define x_gate_r (+ x_gate_l Lg))            ; 0.160  gate right edge
(define x_drn_l  (+ x_gate_r Lgd))           ; 0.200  drain n+ left edge
(define x_drn_r  Wdev)                        ; 0.300  drain n+ right edge

;; vertical landmark y-coordinates (downward positive). y=0 at top surface.
;; The n+ caps sit on top of the GaN cap in the S/D regions; in the gate/access
;; region the top layer is the GaN cap (covered by SiN). We use a common y-datum
;; at the top of the GaN cap so the epi below is continuous across the device.
(define y_top     0.0)                         ; top of GaN cap (= top of epi)
(define y_cap_b   t_cap)                        ; 0.0025  cap bottom
(define y_barr_b  (+ y_cap_b t_barr))           ; 0.0060  AlN barrier bottom
(define y_chan_b  (+ y_barr_b t_chan))          ; 0.0260  channel bottom
(define y_back_b  (+ y_chan_b t_back))          ; 0.0760  back-barrier bottom
(define y_buf_b   (+ y_back_b t_buf))           ; 0.3760  buffer bottom
(define y_sub_b   (+ y_buf_b  t_sub))           ; 0.5760  substrate bottom

;; n+ caps extend ABOVE y=0 (toward negative y) by t_nplus, only in S/D regions.
(define y_nplus_top (- 0 t_nplus))             ; -0.050  top of n+ regrown ohmic
;; SiN passivation also sits above y=0 in the gate/access region.
(define y_SiN_top   (- 0 t_SiN))               ; -0.040  top of SiN

;;------------------------------------------------------------------------------
;; 2. EPITAXIAL REGIONS (full-width layers below the top surface y=0)
;;------------------------------------------------------------------------------
(sdegeo:create-rectangle (position x0 y_buf_b 0)  (position Wdev y_sub_b 0)  "SiC"  "R.Substrate")
(sdegeo:create-rectangle (position x0 y_back_b 0) (position Wdev y_buf_b 0)  "GaN"  "R.Buffer")
;; Al0.08Ga0.92N back barrier (use AlGaN material; mole fraction set in SDevice/par)
(sdegeo:create-rectangle (position x0 y_chan_b 0) (position Wdev y_back_b 0) "AlGaN" "R.BackBarrier")
(sdegeo:create-rectangle (position x0 y_barr_b 0) (position Wdev y_chan_b 0) "GaN"  "R.Channel")
(sdegeo:create-rectangle (position x0 y_cap_b 0)  (position Wdev y_barr_b 0) "AlN"  "R.Barrier")
(sdegeo:create-rectangle (position x0 y_top 0)    (position Wdev y_cap_b 0)  "GaN"  "R.Cap")

;;------------------------------------------------------------------------------
;; 3. n+ REGROWN OHMIC CAPS (above the surface, only in SOURCE and DRAIN spans)
;;    These are the self-aligned regrown n+-GaN contacts that define Lsd.
;;------------------------------------------------------------------------------
(sdegeo:create-rectangle (position x0 y_nplus_top 0)      (position x_src_r y_top 0) "GaN" "R.NplusSrc")
(sdegeo:create-rectangle (position x_drn_l y_nplus_top 0) (position x_drn_r y_top 0) "GaN" "R.NplusDrn")

;;------------------------------------------------------------------------------
;; 4. SiN PASSIVATION (above the surface, ONLY over the access/gate span)
;;    Spans from source-n+ right edge to drain-n+ left edge (x_src_r .. x_drn_l).
;;------------------------------------------------------------------------------
(sdegeo:create-rectangle (position x_src_r y_SiN_top 0) (position x_drn_l y_top 0) "Si3N4" "R.SiN")

;;------------------------------------------------------------------------------
;; 5. CONTACTS  (2D: define-contact-set -> set-current -> define-2d-contact)
;;    Source / Drain : ohmic, on TOP of the n+ caps (y = y_nplus_top).
;;    Gate           : Schottky (Pt/Au), on TOP of the SiN, over the channel
;;                     (T-gate; modeled here as a contact on the SiN surface).
;;------------------------------------------------------------------------------
;; --- Source : top edge of source n+ cap ---
(sdegeo:define-contact-set "source" 4.0 (color:rgb 1 0 0) "##")
(sdegeo:set-current-contact-set "source")
(sdegeo:define-2d-contact
  (find-edge-id (position (* 0.5 x_src_r) y_nplus_top 0))
  (sdegeo:get-current-contact-set))

;; --- Drain : top edge of drain n+ cap ---
(sdegeo:define-contact-set "drain" 4.0 (color:rgb 0 0 1) "##")
(sdegeo:set-current-contact-set "drain")
(sdegeo:define-2d-contact
  (find-edge-id (position (* 0.5 (+ x_drn_l x_drn_r)) y_nplus_top 0))
  (sdegeo:get-current-contact-set))

;; --- Gate : top edge of the SiN over the channel ---
(sdegeo:define-contact-set "gate" 4.0 (color:rgb 0 1 0) "##")
(sdegeo:set-current-contact-set "gate")
(sdegeo:define-2d-contact
  (find-edge-id (position (* 0.5 (+ x_gate_l x_gate_r)) y_SiN_top 0))
  (sdegeo:get-current-contact-set))

;;------------------------------------------------------------------------------
;; 6. DOPING
;;------------------------------------------------------------------------------
;; --- n+ regrown ohmic : 7e19 cm^-3 (Shinohara) ---
(sdedr:define-constant-profile "Prof.Nplus" "ArsenicActiveConcentration" 7e19)
(sdedr:define-refeval-window "W.Nsrc" "Rectangle"
  (position x0 y_nplus_top 0) (position x_src_r y_top 0))
(sdedr:define-constant-profile-placement "Pl.Nsrc" "Prof.Nplus" "W.Nsrc")
(sdedr:define-refeval-window "W.Ndrn" "Rectangle"
  (position x_drn_l y_nplus_top 0) (position x_drn_r y_top 0))
(sdedr:define-constant-profile-placement "Pl.Ndrn" "Prof.Nplus" "W.Ndrn")

;; --- light UID n-type background in channel / buffer (1e15 cm^-3) ---
(sdedr:define-constant-profile "Prof.UID" "ArsenicActiveConcentration" 1e15)
(sdedr:define-constant-profile-region "Pl.UID.Chan" "Prof.UID" "R.Channel")
(sdedr:define-constant-profile-region "Pl.UID.Buf"  "Prof.UID" "R.Buffer")

;;------------------------------------------------------------------------------
;; 7. MESH REFINEMENT
;;------------------------------------------------------------------------------
;; global coarse (applied on the thick layers)
(sdedr:define-refinement-size "Ref.Glob" 0.020 0.020 0.005 0.005)
(sdedr:define-refinement-region "RR.Buf" "Ref.Glob" "R.Buffer")
(sdedr:define-refinement-region "RR.Sub" "Ref.Glob" "R.Substrate")

;; 2DEG / AlN-barrier-to-channel interface : very fine vertically
(sdedr:define-refinement-window "W.2DEG" "Rectangle"
  (position x0 (- y_barr_b 0.003) 0) (position Wdev (+ y_barr_b 0.010) 0))
(sdedr:define-refinement-size "Ref.2DEG" 0.005 0.0005 0.001 0.00005)
(sdedr:define-refinement-placement "RP.2DEG" "Ref.2DEG" "W.2DEG")

;; thin top layers (cap 2.5nm + AlN 3.5nm + 20nm channel) : resolve finely
(sdedr:define-refinement-window "W.Top" "Rectangle"
  (position x0 y_top 0) (position Wdev y_chan_b 0))
(sdedr:define-refinement-size "Ref.Top" 0.005 0.0005 0.001 0.00002)
(sdedr:define-refinement-placement "RP.Top" "Ref.Top" "W.Top")

;; gate region (channel electrostatics under the 20nm gate)
(sdedr:define-refinement-window "W.Gate" "Rectangle"
  (position (- x_gate_l 0.015) y_SiN_top 0) (position (+ x_gate_r 0.015) y_back_b 0))
(sdedr:define-refinement-size "Ref.Gate" 0.002 0.002 0.0004 0.0002)
(sdedr:define-refinement-placement "RP.Gate" "Ref.Gate" "W.Gate")

;;------------------------------------------------------------------------------
;; 8. BUILD MESH & SAVE
;;------------------------------------------------------------------------------
(sde:build-mesh "snmesh" "-a -c boxmethod" "dhhemt_msh")
(sde:save-model "dhhemt_sde")
