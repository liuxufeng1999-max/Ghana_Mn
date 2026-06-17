/* 4C. Extensive / Intensive Margin Decomposition of Mn Exposure */
/* Motivation (Chen & Roth 2024, QJE): the log_Mn_LODsq2 spec is algebraically
   the two-margin spec with the extensive/intensive loadings forced into a fixed
   ratio set by the LOD/sqrt(2) substitution. Here we free that ratio:
        Y = b0 + gamma*Mn_detect + delta*logMn_c + X + e
   Mn_detect = any detectable Mn (extensive); logMn_c = log Mn | detected,
   mean-centered (intensive). Neither uses a substituted value. */

use "../Processed Stata Dta/Test Results Merged with EL Child Development.dta", clear

**# Build margin variables from existing Mn_LOD_EPA and log_Mn_LODsq2
* Mn_LOD_EPA: 1 = below LOD, 2 = detected < threshold, 3 = above USEPA threshold
capture drop Mn_detect logMn_c
gen byte Mn_detect = (Mn_LOD_EPA >= 2) if !missing(Mn_LOD_EPA)
label var Mn_detect "Any detectable Mn (extensive)"

quietly summarize log_Mn_LODsq2 if Mn_detect == 1
gen double logMn_c = Mn_detect * (log_Mn_LODsq2 - r(mean))   // = 0 for nondetects
label var logMn_c "log Mn | detected, centered (intensive)"

**# Two-margin model: Y = f(detect, dose|detect) + X + e
local if_cond "(focal_child_yn==1|focal_child_yn==0)"
local cov_always "Batch treatment i.dist_code"
local cov "age_chld_months_EL child_male "
local cov_add "hh_learn_mca1 par_involv_mca1 own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_primary_BL high_education_secondary_BL high_education_SSS_higher_BL annual_income_geq5k_BL recall_income_geq20k recall_income_geq10k recall_income_geq5k recall_income_bel5k"
local model ""
local title "GSED"
local i = 1

local outcome z_irt_all_30_48m
foreach var of varlist `outcome' {
	local est_tit : word `i' of `title'
	reg `var' Mn_detect logMn_c `cov_always' if `if_cond' , vce(cluster caregiver_id_BL)
		quietly estadd local Cov = "No"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_2marg
		local model `model' `est_tit'_2marg

	reg `var' Mn_detect logMn_c `cov_always' `cov' if `if_cond' , vce(cluster caregiver_id_BL)
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_2marg_cov
		local model `model' `est_tit'_2marg_cov

	reg `var' Mn_detect logMn_c `cov_always' `cov' `cov_add' if `if_cond' , vce(cluster caregiver_id_BL)
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `est_tit'_2marg_addcov
		local model `model' `est_tit'_2marg_addcov
	local i = `i' + 1
}

esttab `model' using "../Output/Tables/TableS6_Mn_Margin_Decomposition.rtf",  ///
    cells(b(fmt(3) star) ci(fmt(2) par) p(fmt(2) par)) ///
    stats(Cov Cov_add N r2, labels("Demographic Controls" "Economic Controls" "N (Children)" "R-squared")) ///
    mtitle("Child Development Score" "Child Development Score" "Child Development Score") ///
    star(* 0.1 ** 0.05 *** 0.01) keep(Mn_detect logMn_c) ///
    coeflabel(Mn_detect "Any detectable Mn (extensive)" logMn_c "log Mn \ensuremath{|} detected (intensive)") ///
    collabels(none) gaps replace nonote label

**# Decomposition + restriction test (full-control model)
* log_Mn_LODsq2 = log(LOD/sqrt2) for nondetects, true log(Mn) for detects.
* Naive single-index forces gamma/delta = (lbar - log(LOD/sqrt2)); free it and test.
quietly summarize log_Mn_LODsq2 if Mn_detect == 0
local lsub = r(mean)                       // = log(LOD/sqrt2)
quietly summarize log_Mn_LODsq2 if Mn_detect == 1
local lbar = r(mean)
local gap  = `lbar' - `lsub'

quietly reg `outcome' Mn_detect logMn_c `cov_always' `cov' `cov_add' if `if_cond' , vce(cluster caregiver_id_BL)
di as txt _n "Implied ratio gamma/delta under naive log spec = " %6.3f `gap'
di as txt "Freely estimated:  gamma = " %6.3f _b[Mn_detect] "   delta = " %6.3f _b[logMn_c] ///
    "   (ratio = " %6.3f _b[Mn_detect]/_b[logMn_c] ")"
* H0: data consistent with the restriction the naive log spec imposes
test Mn_detect = `gap'*logMn_c

**# Sensitivity of the naive log slope to the substitution constant c
* Two-margin (gamma, delta) is invariant to c; the naive slope is not.
local ln2 = ln(2)
local ln10 = ln(10)
foreach lab in "LODsqrt2 0" "LOD/2 -.5*`ln2'" "LOD `=.5*`ln2''" "LOD/10 `=.5*`ln2'-`ln10''" {
	gettoken cname off : lab
	tempvar lnaive
	gen double `lnaive' = log_Mn_LODsq2
	quietly replace `lnaive' = `lsub' + (`off') if Mn_detect == 0
	quietly reg `outcome' `lnaive' `cov_always' `cov' `cov_add' if `if_cond' , vce(cluster caregiver_id_BL)
	di as txt "naive log slope, c = " %-10s "`cname'" ":  b = " %7.4f _b[`lnaive'] "  (se " %6.4f _se[`lnaive'] ")"
}
