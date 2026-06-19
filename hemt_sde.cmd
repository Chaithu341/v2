;;==============================================================================
;;  SDE (Sentaurus Structure Editor) script
;;  Device : Normally-ON AlN/GaN DH-HEMT  (Fig. 1(a), Soni & Shrivastava,
;;           IEEE J. Electron Devices Soc., Vol. 8, pp. 33-41, 2020)
;;
;;  Epi stack (top -> bottom), per Fig. 1(a):
;;     T-Gate metal (Lg = 20 nm)
;;     SiN passivation        : 40   nm
;;     GaN Cap                : 2.5  nm
;;     AlN Barrier            : 3.5  nm
;;     UID GaN Channel        : 150  nm   (tChannel baseline, Sec. IV)
;;     C-doped GaN Buffer     : 150  nm   (Na=1e18, Nd=5e17 cm^-3 traps)
;;     GaN Buffer (UID)       : 250  nm
;;     AlN Nucleation layer   : 100  nm
;;     SiC substrate          : 200  nm (modeled portion)
;;
;;  Lateral : Lsg = 40 nm, Lg = 20 nm, Lgd = 40 nm
;;
;;  Coordinates: x lateral (source left -> drain right), y vertical DOWNWARD,
;;               y = 0 at top SiN surface.
;;==============================================================================

(sde:clear)
(sdegeo:set-default-boolean "ABA")        ; new region replaces old on overlap

;;------------------------------------------------------------------------------
;; 1. PARAMETERS  (micrometers)
;;------------------------------------------------------------------------------
(define Lsg   0.040)
(define Lg    0.020)
(define Lgd   0.040)
(define Lsrc  0.050)
(define Ldrn  0.050)

(define t_SiN   0.040)
(define t_cap   0.0025)
(define t_barr  0.0035)
(define t_chan  0.150)
(define t_cbuf  0.150)
(define t_buf   0.250)
(define t_nuc   0.100)
(define t_sub   0.200)

(define Wdev (+ Lsrc Lsg Lg Lgd Ldrn))     ; 0.200 um

;; lateral landmarks
(define x0 0.0)
(define x_src_r  Lsrc)                       ; 0.050
(define x_gate_l (+ Lsrc Lsg))               ; 0.090
(define x_gate_r (+ x_gate_l Lg))            ; 0.110
(define x_drn_l  (+ x_gate_r Lgd))           ; 0.150
(define x_drn_r  Wdev)                        ; 0.200

;; vertical landmarks (downward positive)
(define y_top    0.0)
(define y_SiN_b  t_SiN)                        ; 0.040
(define y_cap_b  (+ y_SiN_b t_cap))            ; 0.0425
(define y_barr_b (+ y_cap_b t_barr))           ; 0.0460
(define y_chan_b (+ y_barr_b t_chan))          ; 0.1960
(define y_cbuf_b (+ y_chan_b t_cbuf))          ; 0.3460
(define y_buf_b  (+ y_cbuf_b t_buf))           ; 0.5960
(define y_nuc_b  (+ y_buf_b  t_nuc))           ; 0.6960
(define y_sub_b  (+ y_nuc_b  t_sub))           ; 0.8960

;;------------------------------------------------------------------------------
;; 2. SEMICONDUCTOR / DIELECTRIC REGIONS
;;------------------------------------------------------------------------------
(sdegeo:create-rectangle (position x0 y_nuc_b 0)  (position Wdev y_sub_b 0)  "SiC"   "R.Substrate")
(sdegeo:create-rectangle (position x0 y_buf_b 0)  (position Wdev y_nuc_b 0)  "AlN"   "R.Nucleation")
(sdegeo:create-rectangle (position x0 y_cbuf_b 0) (position Wdev y_buf_b 0)  "GaN"   "R.Buffer")
(sdegeo:create-rectangle (position x0 y_chan_b 0) (position Wdev y_cbuf_b 0) "GaN"   "R.CBuffer")
(sdegeo:create-rectangle (position x0 y_barr_b 0) (position Wdev y_chan_b 0) "GaN"   "R.Channel")
(sdegeo:create-rectangle (position x0 y_cap_b 0)  (position Wdev y_barr_b 0) "AlN"   "R.Barrier")
(sdegeo:create-rectangle (position x0 y_SiN_b 0)  (position Wdev y_cap_b 0)  "GaN"   "R.Cap")
;; SiN passivation is created ONLY over the gate/access span (x_src_r .. x_drn_l),
;; NOT over the source/drain spans.  This lets the S/D ohmic contacts sit directly
;; on the GaN cap (semiconductor) instead of on a dielectric, which would inject
;; no current.  (Real HEMT S/D ohmics penetrate the passivation to the cap/2DEG.)
(sdegeo:create-rectangle (position x_src_r y_top 0) (position x_drn_l y_SiN_b 0) "Si3N4" "R.SiN")

;;------------------------------------------------------------------------------
;; 3. CONTACTS  (2D: contacts placed on top-surface edges)
;;    define-contact-set -> set-current -> define-2d-contact with
;;    (sdegeo:get-current-contact-set) as 2nd arg  (verified syntax).
;;    Source/Drain land on the GaN cap top (y = y_SiN_b) where SiN is absent;
;;    n+ pockets (Section 4) make these contacts ohmic and tie them to the 2DEG.
;;    Gate sits on the SiN top (y = y_top) over the channel (Schottky in SDevice).
;;------------------------------------------------------------------------------
;; --- Source : on cap top, at y = y_SiN_b ---
(sdegeo:define-contact-set "source" 4.0 (color:rgb 1 0 0) "##")
(sdegeo:set-current-contact-set "source")
(sdegeo:define-2d-contact
  (find-edge-id (position (* 0.5 x_src_r) y_SiN_b 0))
  (sdegeo:get-current-contact-set))

;; --- Drain : on cap top, at y = y_SiN_b ---
(sdegeo:define-contact-set "drain" 4.0 (color:rgb 0 0 1) "##")
(sdegeo:set-current-contact-set "drain")
(sdegeo:define-2d-contact
  (find-edge-id (position (* 0.5 (+ x_drn_l x_drn_r)) y_SiN_b 0))
  (sdegeo:get-current-contact-set))

;; --- Gate : on SiN top, at y = y_top, over the channel ---
(sdegeo:define-contact-set "gate" 4.0 (color:rgb 0 1 0) "##")
(sdegeo:set-current-contact-set "gate")
(sdegeo:define-2d-contact
  (find-edge-id (position (* 0.5 (+ x_gate_l x_gate_r)) y_top 0))
  (sdegeo:get-current-contact-set))

;;------------------------------------------------------------------------------
;; 4. DOPING
;;------------------------------------------------------------------------------
;; light n-type UID background
(sdedr:define-constant-profile "Prof.UID" "ArsenicActiveConcentration" 1e15)
(sdedr:define-constant-profile-region "Pl.UID.Chan" "Prof.UID" "R.Channel")
(sdedr:define-constant-profile-region "Pl.UID.Buf"  "Prof.UID" "R.Buffer")
(sdedr:define-constant-profile-region "Pl.UID.Cap"  "Prof.UID" "R.Cap")

;; n+ ohmic pockets under source and drain (1e19) so S/D contacts are ohmic and
;; connect down to the 2DEG.  Use refeval-windows (required for profile placement).
(sdedr:define-constant-profile "Prof.Nplus" "ArsenicActiveConcentration" 1e19)

(sdedr:define-refeval-window "W.Nsrc" "Rectangle"
  (position x0 y_SiN_b 0) (position x_src_r (+ y_barr_b 0.010) 0))
(sdedr:define-constant-profile-placement "Pl.Nsrc" "Prof.Nplus" "W.Nsrc")

(sdedr:define-refeval-window "W.Ndrn" "Rectangle"
  (position x_drn_l y_SiN_b 0) (position x_drn_r (+ y_barr_b 0.010) 0))
(sdedr:define-constant-profile-placement "Pl.Ndrn" "Prof.Nplus" "W.Ndrn")

;;------------------------------------------------------------------------------
;; 5. MESH REFINEMENT
;;------------------------------------------------------------------------------
;; global (applied via large windows so it does not depend on a single region)
(sdedr:define-refinement-size "Ref.Glob" 0.020 0.020 0.005 0.005)
(sdedr:define-refinement-region "RR.Glob"  "Ref.Glob" "R.Buffer")
(sdedr:define-refinement-region "RR.Glob2" "Ref.Glob" "R.Substrate")

;; 2DEG / lower-barrier interface (must be VERY fine vertically)
(sdedr:define-refinement-window "W.2DEG" "Rectangle"
  (position x0 (- y_barr_b 0.004) 0) (position Wdev (+ y_barr_b 0.012) 0))
(sdedr:define-refinement-size "Ref.2DEG" 0.005 0.0005 0.001 0.00005)
(sdedr:define-refinement-placement "RP.2DEG" "Ref.2DEG" "W.2DEG")

;; thin barrier + cap (resolve 2.5 nm + 3.5 nm layers)
(sdedr:define-refinement-window "W.Barr" "Rectangle"
  (position x0 y_SiN_b 0) (position Wdev y_barr_b 0))
(sdedr:define-refinement-size "Ref.Barr" 0.005 0.0005 0.001 0.00002)
(sdedr:define-refinement-placement "RP.Barr" "Ref.Barr" "W.Barr")

;; gate region (channel electrostatics)
(sdedr:define-refinement-window "W.Gate" "Rectangle"
  (position (- x_gate_l 0.015) y_SiN_b 0) (position (+ x_gate_r 0.015) y_chan_b 0))
(sdedr:define-refinement-size "Ref.Gate" 0.002 0.002 0.0004 0.0002)
(sdedr:define-refinement-placement "RP.Gate" "Ref.Gate" "W.Gate")

;;------------------------------------------------------------------------------
;; 6. BUILD MESH & SAVE
;;------------------------------------------------------------------------------
(sde:build-mesh "snmesh" "-a -c boxmethod" "hemt_msh")
(sde:save-model "hemt_sde")
