*==============================================================================
* mn_margin_decomposition.do
*------------------------------------------------------------------------------
* Extensive / intensive decomposition of the Mn--child-development association
* in the presence of below-LOD (undetected) manganese exposure.
*
* Motivation (Chen & Roth 2024, QJE, "Logs with Zeros?"):
*   The continuous spec that substitutes LOD/sqrt(2) for nondetects and then
*   takes log(Mn) is, algebraically, the two-margin spec with the extensive and
*   intensive loadings forced into a FIXED ratio set by the substitution
*   constant. This script frees that ratio:
*
*     Y_i = b0 + gamma*D_i + delta*[ D_i*(logMn_i - lbar) ] + X_i'b + tau_s + e_i
*           D_i = 1{Mn_i > LOD}        (extensive: any detectable Mn)
*           delta                       (intensive: dose-response | detected)
*
*   D never uses an imputed value, so gamma and delta are invariant to BOTH the
*   substitution constant and the units of Mn. The naive log slope is invariant
*   to units but NOT to the substitution constant -- that is the value-add.
*
* Deliverables: detection profile, three nested-in-spirit models, the exact
* decomposition + restriction test, and a substitution-constant sensitivity.
*
* Dependencies (uncomment to install once):
*   ssc install reghdfe, replace
*   ssc install ftools, replace
*   ssc install estout, replace
*==============================================================================

version 17
clear all
set more off
set linesize 120

*------------------------------------------------------------------------------
* 0. USER CONFIGURATION  --  EDIT THESE TO MATCH YOUR DATA, then run.
*------------------------------------------------------------------------------
global DATA     "analytic.dta"          // path to the analytic dataset
global OUTCOME  "dev_score"             // Y: standardized child development score (SD units)
global MN       "mn_ugL"                // Mn concentration in ug/L (measured value for detects)
global LOD      5                       // numeric LOD in ug/L  <-- SET THE ACTUAL VALUE
global THRESH   50                      // USEPA secondary threshold (ug/L)
global CONTROLS "i.child_sex child_age_months i.mother_edu wealth_index"  // X_i
global FE       "district"              // tau_s : fixed-effect id (district)
global CLUSTER  "district"              // cluster variable for SEs
global RESULTS  "results"               // output folder

* How are nondetects represented in $MN ?  Choose ONE and set $DETECT accordingly:
*   - If a 1=detected indicator already exists, put its name here.
*   - If left empty, the indicator is built as 1{$MN > $LOD}; this REQUIRES that
*     nondetects be stored as a value at/below LOD (e.g. 0, LOD/2, or LOD/sqrt2).
global DETECT   ""                      // existing detect indicator, or "" to build from LOD

*------------------------------------------------------------------------------
* 1. LOAD AND BUILD VARIABLES
*------------------------------------------------------------------------------
use "$DATA", clear
cap mkdir "$RESULTS"

* --- detect indicator D ---
if "$DETECT" == "" {
    gen byte D = ($MN > $LOD) if !missing($MN)
    label var D "Any detectable Mn (1{Mn>LOD})"
}
else {
    gen byte D = $DETECT
    label var D "Any detectable Mn (supplied indicator)"
}

* --- intensive margin: log dose among detected, mean-centered; zero off-detect ---
gen double logMn = log($MN) if D==1
quietly summarize logMn if D==1, meanonly
scalar lbar = r(mean)                       // mean detected log-dose (centering)
gen double lmn_c = D*(logMn - lbar)         // = 0 for nondetects by construction
replace lmn_c = 0 if D==0
label var lmn_c "Intensive: D*(logMn - mean detected logMn)"

* --- naive single-index regressor: log(Mn) with LOD/sqrt(2) substitution ---
scalar c_root2 = $LOD/sqrt(2)
gen double lmn_naive = logMn
replace    lmn_naive = log(c_root2) if D==0
label var lmn_naive "Naive log(Mn), nondetect = LOD/sqrt(2)"

* --- your existing 3-level categorical exposure (<LOD ref / detect-<thr / >=thr) ---
gen byte mn_cat = 0 if D==0
replace  mn_cat = 1 if D==1 & $MN <  $THRESH
replace  mn_cat = 2 if D==1 & $MN >= $THRESH
label define mncat 0 "<LOD (ref)" 1 "Detected, <thr" 2 ">=thr", replace
label values mn_cat mncat
label var mn_cat "Mn category"

*------------------------------------------------------------------------------
* 2. DETECTION PROFILE  (decides whether the split is even informative)
*------------------------------------------------------------------------------
di as txt _n "{hline 60}"
di as txt "Detection profile"
di as txt "{hline 60}"
tab D, missing
tab mn_cat, missing
quietly count
local N = r(N)
quietly count if D==1
di as txt "Detection rate = " %5.3f r(N)/`N' "   (N = `N')"
di as txt "Mean detected log-dose (lbar) = " %6.3f lbar
* If detection rate is ~0 or ~1, gamma is weakly identified -- stop and reconsider.

*------------------------------------------------------------------------------
* 3. MODELS
*    M0 = naive LOD/sqrt(2) log spec  (literature-comparable, the thing tested)
*    M1 = categorical spec            (your current imputation-free spec)
*    M2 = two-margin decomposition    (the proposed estimator)
*------------------------------------------------------------------------------
eststo clear

eststo M0_naive: reghdfe $OUTCOME lmn_naive $CONTROLS, ///
    absorb($FE) vce(cluster $CLUSTER)

eststo M1_cat:   reghdfe $OUTCOME ib0.mn_cat $CONTROLS, ///
    absorb($FE) vce(cluster $CLUSTER)

eststo M2_2marg: reghdfe $OUTCOME D lmn_c $CONTROLS, ///
    absorb($FE) vce(cluster $CLUSTER)
    scalar gamma = _b[D]
    scalar delta = _b[lmn_c]

*------------------------------------------------------------------------------
* 4. EXACT DECOMPOSITION + RESTRICTION TEST
*    The naive single-index forces gamma/delta = (lbar - log c). Free it and test.
*------------------------------------------------------------------------------
scalar gap = lbar - log(c_root2)            // ratio the naive spec imposes

di as txt _n "{hline 60}"
di as txt "Restriction implied by the naive LOD/sqrt(2)-log spec"
di as txt "{hline 60}"
di as txt "Implied ratio gamma/delta (= lbar - log(LOD/sqrt2)) = " %6.3f gap
di as txt "Freely estimated: gamma = " %6.3f gamma "   delta = " %6.3f delta
di as txt "Freely estimated gamma/delta = " %6.3f gamma/delta

* H0: the data are consistent with the single-index restriction gamma = gap*delta
local g = gap
test _b[D] = `g'*_b[lmn_c]

*------------------------------------------------------------------------------
* 5. SUBSTITUTION-CONSTANT SENSITIVITY (the honest analogue of CR's Table 1)
*    Naive slope moves with c; two-margin (gamma, delta) does not.
*------------------------------------------------------------------------------
di as txt _n "{hline 60}"
di as txt "Naive log slope vs substitution constant c"
di as txt "{hline 60}"
foreach denom in 1.41421356 2 1 10 {           // c = LOD/sqrt2, LOD/2, LOD, LOD/10
    local cval = $LOD/`denom'
    tempvar lnaive_k
    gen double `lnaive_k' = logMn
    replace    `lnaive_k' = log(`cval') if D==0
    quietly reghdfe $OUTCOME `lnaive_k' $CONTROLS, absorb($FE) vce(cluster $CLUSTER)
    di as txt "c = LOD/" %-4.2f `denom' "  (= " %6.3f `cval' " ug/L):  " ///
        "naive slope = " %7.4f _b[`lnaive_k'] "  (se " %6.4f _se[`lnaive_k'] ")"
}
di as txt "By contrast, two-margin: gamma = " %6.3f gamma ", delta = " %6.3f delta ///
    "  (invariant to c and to units)"

*------------------------------------------------------------------------------
* 6. EFFECT SIZES (Y is in SD units)
*------------------------------------------------------------------------------
quietly summarize logMn if D==1, detail
scalar iqr_dose = r(p75) - r(p25)
di as txt _n "Extensive (detect vs <LOD, at mean dose): " %6.3f gamma " SD"
di as txt "Intensive (per IQR of detected log-dose):   " %6.3f delta*iqr_dose " SD" ///
    "   [IQR(logMn|det) = " %5.3f iqr_dose "]"

*------------------------------------------------------------------------------
* 7. EXPORT TABLE
*------------------------------------------------------------------------------
esttab M0_naive M1_cat M2_2marg using "$RESULTS/mn_margin_decomposition.rtf", ///
    replace b(%6.3f) se(%6.3f) star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Naive log (LOD/sqrt2)" "Categorical" "Two-margin") ///
    keep(lmn_naive 1.mn_cat 2.mn_cat D lmn_c) ///
    coeflabels(lmn_naive "log Mn (LOD/sqrt2)" ///
               1.mn_cat "Detected, <thr" 2.mn_cat ">= thr" ///
               D "Any detectable Mn (extensive)" ///
               lmn_c "Dose | detected (intensive)") ///
    stats(N r2_within, fmt(%9.0f %6.3f) labels("N" "Within R-sq")) ///
    note("District FE + demographic/SES controls. SEs clustered by $CLUSTER.")

*------------------------------------------------------------------------------
* 8. VERIFICATION (fail loudly on data-prep mistakes)
*------------------------------------------------------------------------------
assert lmn_c == 0 if D==0
assert !missing(D)
quietly count if D==1 & missing(logMn)
assert r(N)==0                                  // every detect has a positive dose
di as txt _n "Verification passed."
*==============================================================================
* END
*==============================================================================
