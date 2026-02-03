/* 4A. Evaluation Specific to Mn */
use "$master_loc\Processed Stata Dta\Test Results Merged with EL Child Development.dta", clear


**# Primary Results: Y = f(Mn) + X + e

**EPA Standard: >50ug/L
local if_cond "(focal_child_yn==1|focal_child_yn==0)"
local cov_always "Batch treatment i.dist_code"
local cov "age_chld_months_EL child_male "
local cov_add "hh_learn_mca1 par_involv_mca1 own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_primary_BL high_education_secondary_BL high_education_SSS_higher_BL annual_income_geq5k_BL recall_income_geq20k recall_income_geq10k recall_income_geq5k recall_income_bel5k"
local model ""
local title "GSED Hlth ChldDev"
local i = 1

local outcome  z_irt_all_30_48m //hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
foreach var of varlist `outcome' {

	local est_tit : word `i' of `title'
	reg `var'  i.Mn_LOD_EPA `cov_always' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_Mn_EPA
		quietly estadd local Cov = "No"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_Mn_EPA
		local model `model' `est_tit'_Mn_EPA

	reg `var'  i.Mn_LOD_EPA `cov_always' `cov' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_Mn_EPA_cov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_Mn_EPA_cov
		local model `model' `est_tit'_Mn_EPA_cov

	reg `var'  i.Mn_LOD_EPA `cov_always' `cov' `cov_add' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_Mn_EPA_addcov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `est_tit'_Mn_EPA_addcov
		local model `model' `est_tit'_Mn_EPA_addcov
	local i = `i' + 1
}

esttab `model' using "..\Output\Tables\EPA_LOD_Mn_Exposure_ChildDev.tex",  ///
    stats( Cov Cov_add N r2, labels( "Demographic Controls" "Economic Controls" "N (Children)" "R-squared")) ///
		mtitle("Child Development Score" "Child Development Score" "Child Development Score" "Healthier" "Healthier" "Healthier" "Advanced" "Advanced" "Advanced") ///
    b ci star(* 0.1 ** 0.05 *** 0.01) keep(2.Mn_LOD_EPA 3.Mn_LOD_EPA) ///
	coeflabel(2.Mn_LOD_EPA "Detected \ensuremath{<} Threshold" 3.Mn_LOD_EPA "Above USEPA Threshold") ///
    refcat(2.Mn_LOD_EPA "Mn Below LOD (ref.)", nolabel) ///
	replace nonote label


**Continuous log-transformed Mn
local if_cond "(focal_child_yn==1|focal_child_yn==0)"
local cov_always "Batch treatment age_chld_months_EL i.dist_code"
local cov "child_male "
local cov_add "hh_learn_mca1 par_involv_mca1 own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_primary_BL high_education_secondary_BL high_education_SSS_higher_BL recall_income_geq20k recall_income_geq10k recall_income_geq5k recall_income_bel5k"
local model ""
local title "GSED Hlth ChldDev"
local i = 1

local outcome  z_irt_all_30_48m //hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
foreach var of varlist `outcome' {
	local est_tit : word `i' of `title'
	reg `var'  log_Mn_LODsq2 `cov_always' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_Mn
		quietly estadd local Cov = "No"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_Mn
		local model `model' `est_tit'_Mn

	reg `var'  log_Mn_LODsq2 `cov_always' `cov' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_Mn_cov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_Mn_cov
		local model `model' `est_tit'_Mn_cov

	reg `var'  log_Mn_LODsq2 `cov_always' `cov' `cov_add' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_Mn_addcov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `est_tit'_Mn_addcov
		local model `model' `est_tit'_Mn_addcov
	local i = `i' + 1
}
esttab `model' using "..\Output\Tables\Continuous_Mn_Exposure_ChildDev.rtf",  ///
    stats( Cov Cov_add N r2, labels( "Demographic Controls" "Economic Controls" "N (Children)" "R-squared")) ///
	mtitle("Child Development Score" "Child Development Score" "Child Development Score") ///
    b ci star(* 0.1 ** 0.05 *** 0.01) keep(log_Mn_LODsq2) ///
	replace nonote label
//
// summ log_Mn_LODsq2 if e(sample), detail
// 	local mn_min = r(p25)
// 	local mn_max = r(max)
// 	local mn_step = (`mn_max' - `mn_min')/4
// margins, ///
//     dydx(log_Mn_LODsq2) at(log_Mn_LODsq2 = (`mn_min'(`mn_step')`mn_max')) ///
//     vce(unconditional)
// marginsplot, ///
//     xdimension(log_Mn_LODsq2) ///
//     recast(connected) recastci(rcap) ///
//     plotopts(lwidth(medthick) lcolor(blue)) ///
//     ciopts(fcolor(blue%20) lcolor(blue%40)) ///
//     yline(0, lpattern(dash) lcolor(gs10)) ///
//     xlabel(, format(%4.2f) labsize(small)) ///
//     ytitle("Effect of HH Mn") ///
//     xtitle("log(Household Mn)") ///
//     title("Marginal effect of HH Mn on child development") ///
//     graphregion(color(white)) plotregion(color(white))

**# Heterogeneity: Explore school and non-school sample
**Intuition: children in schools with higher Mn receive extra exposure

**Note: schoolMn_exposure = 0 if nonschool respondent --> positive coefficient represent school effects.
local if_cond "(school_respondent_BL==1)" //-->need to be enrolled in the study school (i.e., school respondent in the baseline)
local cov_always "Batch treatment i.dist_code"
local cov "age_chld_months_EL child_male "
local cov_add "hh_learn_mca1 par_involv_mca1 own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_primary_BL high_education_secondary_BL high_education_SSS_higher_BL recall_income_geq20k recall_income_geq10k recall_income_geq5k"
local model ""
local title "GSED Hlth ChldDev"
local i = 1

local outcome  z_irt_all_30_48m //hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
foreach var of varlist `outcome' {
	local est_tit : word `i' of `title'
	reg `var'  c.log_Mn_LODsq2##c.log_school_Mn_max_LODsq2 `cov_always' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_z_Mn_school
		quietly estadd local Cov = "No"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_z_Mn_school
		local model `model' `est_tit'_z_Mn_school

	reg `var'  c.log_Mn_LODsq2##c.log_school_Mn_max_LODsq2 `cov_always' `cov' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_z_Mn_school_cov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_z_Mn_school_cov
		local model `model' `est_tit'_z_Mn_school_cov

	reg `var'  c.log_Mn_LODsq2##c.log_school_Mn_max_LODsq2 `cov_always' `cov' `cov_add' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_z_Mn_school_addcov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `est_tit'_z_Mn_school_addcov
		local model `model' `est_tit'_z_Mn_school_addcov
	local i = `i' + 1
}
esttab `model'  using "..\Output\Tables\Mn_plus_SchoolExposure_ChildDev.rtf",  ///
    stats(Cov Cov_add N r2, labels( "Demographic Controls" "Economic Controls" "N (Children)" "R-squared")) ///
			mtitle("Child Development Score" "Child Development Score" "Child Development Score" "Healthier" "Healthier" "Healthier" "Advanced" "Advanced" "Advanced") ///
    b ci star(* 0.1 ** 0.05 *** 0.01) keep(log_Mn_LODsq2 *log_school_Mn_max_LODsq2 ) ///
	coeflabel(log_Mn_LODsq2 "log(Household Mn)" log_school_Mn_max_LODsq2 "log(School Mn)" c.log_Mn_LODsq2#c.log_school_Mn_max_LODsq2 "log(Household Mn) \ensuremath{\times} log(School Mn)" ) replace nonote label noomitted

sum log_school_Mn_max_LODsq2 if e(sample), detail
local sch_min  = r(p25)
local sch_max  = r(p99)
local sch_step = (`sch_max' - `sch_min')/4

margins, dydx(log_Mn_LODsq2) ///
    at(log_school_Mn_max_LODsq2 = (`sch_min'(`sch_step')`sch_max')) ///
    vce(unconditional)

marginsplot, ///
    xdimension(log_school_Mn_max_LODsq2) ///
    recast(connected) recastci(rcap) ///
    plotopts(lwidth(medthick) lcolor(navy)) ///
    ciopts(fcolor(navy%20) lcolor(navy%40) lwidth(thin)) ///
    yline(0, lpattern(dash)) ///
    xlabel(, format(%4.2f)) ///
    ytitle("Effect of log(Household Mn)") ///
    xtitle("log(School Mn)") ///
	title("") ///
	name(SchoolMn, replace)

graph export "..\Output\Figures\MarginsPlot_AME_by_SchoolMn.pdf", ///
	name(SchoolMn) as(pdf) replace

graph export "..\Output\Figures\MarginsPlot_AME_by_SchoolMn.svg", ///
	name(SchoolMn) as(svg) replace
**# Heterogeneity: Male vs. Female

local if_cond "(focal_child_yn==1|focal_child_yn==0)" //-->need to be focal child and not enrolled in other schools (so either not enrolled in school OR enrolled in study school)
local cov_always "Batch treatment i.dist_code"
local cov "age_chld_months_EL "
local cov_add "hh_learn_mca1 par_involv_mca1 own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_primary_BL high_education_secondary_BL high_education_SSS_higher_BL annual_income_geq5k_BL"
local model ""
local title "GSED Hlth ChldDev"
local i = 1

local outcome  z_irt_all_30_48m //hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
foreach var of varlist `outcome' {
	local est_tit : word `i' of `title'
	reg `var' c.log_Mn_LODsq2##child_male_BL `cov_always' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_z_Mn_Male
		quietly estadd local Cov = "No"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_z_Mn_Male
		local model `model' `est_tit'_z_Mn_Male

	reg `var'  c.log_Mn_LODsq2##child_male_BL `cov_always' `cov' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_z_Mn_Male_cov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_z_Mn_Male_cov
		local model `model' `est_tit'_z_Mn_Male_cov

	reg `var'  c.log_Mn_LODsq2##child_male_BL  `cov_always' `cov' `cov_add' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_z_Mn_Male_addcov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `est_tit'_z_Mn_Male_addcov
		local model `model' `est_tit'_z_Mn_Male_addcov
	local i = `i' + 1
}
esttab `model' using "..\Output\Tables\Mn_ChildDev_by_BoysGirls.rtf",  ///
    stats( Cov Cov_add N r2, labels( "Demographic Controls" "Economic Controls" "N (Children)" "R-squared")) ///
			mtitle("Child Development Score" "Child Development Score" "Child Development Score" "Healthier" "Healthier" "Healthier" "Advanced" "Advanced" "Advanced") ///
    b ci star(* 0.1 ** 0.05 *** 0.01) keep(*.child_male_BL *log_Mn_LODsq2) ///
	refcat(log_Mn_LODsq2 "Girls (ref.)", nolabel) ///
	coeflabel(1.child_male_BL#c.log_Mn_LODsq2 "Boys \ensuremath{\times} log(Household Mn)") ///
	replace nonote label noomitted nobase

margins, dydx(log_Mn_LODsq2) vce(unconditional)
	matrix M = r(b)
	local agg = M[1,1]   // overall slope
	di "`agg'"
summ log_Mn_LODsq2 if e(sample), detail
	local mn_min = r(p25)
	local mn_max = r(max)
	local mn_step = (`mn_max' - `mn_min')/4
margins , ///
    dydx(log_Mn_LODsq2) ///
    over(child_male_BL) ///
    vce(unconditional)
marginsplot, ///
    recast(connected) recastci(rcap) ///
	plot1opts(lcolor(blue) lwidth(medthick)) ///
	ci1opts(fcolor(blue%20) lcolor(blue%40)) ///
    yline(0, lpattern(dash) lcolor(gs10)) ///
    xlabel(, format(%4.2f) labsize(small)) ///
    ytitle("Effect of HH Mn") ///
    xtitle("log(Household Mn)") ///
    title("GSED vs Household Mn, by sex") ///
    legend(order(1 "Girls" 2 "Boys") pos(5) ring(0) size(small)) ///
    graphregion(color(white)) plotregion(color(white))


**# Robustness Checks: Cinelli and Hazlett (2020) Bound
capture frame create sensemakr
capture tab Mn_LOD_EPA, gen(Mn_LOD_EPA)

**Categorical Mn: LOD EPA
capture drop if missing(child_code)
local cov_always "Batch treatment i.dist_code"
local cov "age_chld_months_EL child_male "
local cov_add "hh_learn_mca1 par_involv_mca1 own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_primary_BL high_education_secondary_BL high_education_SSS_higher_BL recall_income_geq20k recall_income_geq10k recall_income_geq5k"
quietly reg z_irt_all_30_48m  Mn_LOD_EPA2 Mn_LOD_EPA3 `cov_always' `cov' `cov_add' , vce(cluster caregiver_id_BL)
cd "..\Output\Tables\"
sensemakr ///
	z_irt_all_30_48m  Mn_LOD_EPA2 Mn_LOD_EPA3 `cov_always' `cov' `cov_add', ///
	treat(Mn_LOD_EPA3) alpha(0.1) ///
	gbenchmark(hh_learn_mca1 par_involv_mca1 recall_income_geq20k recall_income_geq10k recall_income_geq5k) gname(Covariates) extremeplot elim(0 0.2) contourplot kd(0.5 1 2) clines(5) ///
	latex(Sensemakr_EPALODMn_Results) r2yz(1 0.75 0.5 0.25)
graph copy s_extremeplot Mn_EPA_extreme, replace
// graph copy s_countourplot Mn_EPA_countour, replace

* Store sensemakr results for Mn_LOD_EPA3
matrix bounds_epa = e(bounds)
local epa_treat_label "{1{Mn>=50}}"
local epa_coef = e(treat_coef)
local epa_se = e(treat_se)
local epa_r2ydx = e(r2yd_x) * 100
local epa_rv_q = e(rv_q) * 100
local epa_rv_qa = e(rv_qa) * 100
local epa_r2yzdx = bounds_epa[2,4] * 100
local epa_r2dzx = bounds_epa[2,3] * 100

**log
capture drop if missing(child_code)
local cov_always "Batch treatment i.dist_code"
local cov "age_chld_months_EL child_male "
local cov_add "hh_learn_mca1 par_involv_mca1 own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_primary_BL high_education_secondary_BL high_education_SSS_higher_BL recall_income_geq20k recall_income_geq10k recall_income_geq5k"
quietly reg z_irt_all_30_48m  log_Mn_LODsq2 `cov_always' `cov' `cov_add' , vce(cluster caregiver_id_BL)
cd "..\Output\Tables\"
sensemakr ///
	z_irt_all_30_48m  log_Mn_LODsq2 `cov_always' `cov' `cov_add', ///
	treat(log_Mn_LODsq2) alpha(0.1) ///
	gbenchmark(hh_learn_mca1 par_involv_mca1 recall_income_geq20k recall_income_geq10k recall_income_geq5k) gname(Covariates) extremeplot elim(0 0.2)  contourplot kd(0.5 1 2) clines(5) ///
	latex(Sensemakr_logMn_Results) r2yz(1 0.75 0.5 0.25)
graph copy s_extremeplot logMn_extreme, replace
// graph copy s_countourplot Mn_log_countour, replace

* Store sensemakr results for log_Mn_LODsq2
matrix bounds_log = e(bounds)
local log_treat_label "log(Mn)"
local log_coef = e(treat_coef)
local log_se = e(treat_se)
local log_r2ydx = e(r2yd_x) * 100
local log_rv_q = e(rv_q) * 100
local log_rv_qa = e(rv_qa) * 100
local log_r2yzdx = bounds_log[2,4] * 100
local log_r2dzx = bounds_log[2,3] * 100

* Export combined sensemakr table as RTF
tempname rtf
local rtffile "$master_loc\Output\Tables\Sensemakr_Combined_Results.rtf"
file open `rtf' using "`rtffile'", write replace
file write `rtf' "{\rtf1\ansi" _n
file write `rtf' "{\fonttbl{\f0 Times New Roman;}}" _n
file write `rtf' "\f0\fs20" _n

* Table header
file write `rtf' "\trowd\trgaph108" _n
file write `rtf' "\cellx1800\cellx3000\cellx4200\cellx5600\cellx6800\cellx8200\cellx9600\cellx11000" _n
file write `rtf' "\b Treatment (D)\cell Estimate\cell Standard Error\cell R{\super 2}{\sub Y~D|X} (%)\cell RV (%)\cell RV{\sub \u945?=0.1} (%)\cell R{\super 2}{\sub Y~Z|D,X} (%)\cell R{\super 2}{\sub D~Z|X} (%)\cell\b0" _n
file write `rtf' "\row" _n

* Row 1: log(Mn)
file write `rtf' "\trowd\trgaph108" _n
file write `rtf' "\cellx1800\cellx3000\cellx4200\cellx5600\cellx6800\cellx8200\cellx9600\cellx11000" _n
file write `rtf' "`log_treat_label'\cell " ///
	%6.3f (`log_coef') "\cell " ///
	%6.3f (`log_se') "\cell " ///
	%6.2f (`log_r2ydx') "\cell " ///
	%6.2f (`log_rv_q') "\cell " ///
	%6.2f (`log_rv_qa') "\cell " ///
	%6.2f (`log_r2yzdx') "\cell " ///
	%6.2f (`log_r2dzx') "\cell" _n
file write `rtf' "\row" _n

* Row 2: 1{Mn>=50}
file write `rtf' "\trowd\trgaph108" _n
file write `rtf' "\cellx1800\cellx3000\cellx4200\cellx5600\cellx6800\cellx8200\cellx9600\cellx11000" _n
file write `rtf' "`epa_treat_label'\cell " ///
	%6.3f (`epa_coef') "\cell " ///
	%6.3f (`epa_se') "\cell " ///
	%6.2f (`epa_r2ydx') "\cell " ///
	%6.2f (`epa_rv_q') "\cell " ///
	%6.2f (`epa_rv_qa') "\cell " ///
	%6.2f (`epa_r2yzdx') "\cell " ///
	%6.2f (`epa_r2dzx') "\cell" _n
file write `rtf' "\row" _n

file write `rtf' "}" _n
file close `rtf'

grc1leg Mn_EPA_extreme	logMn_extreme, name(sensemakr_EPA_Log_Extreme, replace) xcommon

// grc1leg combine Mn_EPA_countour s_countourplot, legend(off)

capture drop if missing(child_code)


**# Robustness Check: Remove non-Mn contaminations
**In this robustness checks, we routinly remove household water with contaminated non-Mn metals (e.g., Pb, Fe, ... ) including their household waters and attached school waters
**We will then visualize the result showing the change of coefficients rel. to the baseline model
**In all cases, we will include full specifications (i.e., preferred model)
**Metals: Pb Fe Cr Al Cu (Zinc is present in all water and are indeed considered beneficial for the drinking household - cite Leah's paper)

egen Household_nonMn_conc = rowmax(Pb Fe Cr Al Cu)
label var Household_nonMn_conc "rowmax(Pb Fe Cr Al Cu)"
egen School_nonMn_conc = rowmax(school_Pb_max school_Hg_max school_Cd_max school_Fe_max school_Cr_max school_Al_max school_Cu_max)
label var School_nonMn_conc "rowmax(Pb_max Fe_max Cr_max Al_max Cu_max)"

**Remove HH contamined metal ONLY


//====Categorical Specification===//
local cov_always "Batch sample_water_source_1 sample_water_source_2 sample_water_source_6 treatment i.dist_code"
local cov "age_chld_months_EL child_male prim_caregiver_female_BL"
local cov_add "own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_secondary_BL"
local title "GSED"
local nonMn Pb Fe Cr Al Cu Household_nonMn_conc
local mtitle "Pb Fe Cr Al Cu ALL"
local i = 1
foreach var of local nonMn {
	local est_tit : word `i' of `mtitle'
	reg z_irt_all_30_48m  i.Mn_LOD_EPA `cov_always' `cov' `cov_add' if `var'==0 , vce(cluster caregiver_id_BL)
		est store `title'_MnEPA_rHH`est_tit'
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `title'_MnEPA_rHH`est_tit'
		local model `model' `title'_MnEPA_rHH`est_tit'
	local i = `i' + 1
}

esttab `model' /* using "..\Output\Tables\RobustnessChecks_RemoveNonMnMetals_EPAsec.tex" */,  ///
    stats( Cov Cov_add N r2_p, labels( "Demographic Controls" "Economic Controls" "N (Children)" "Pseudo R-squared")) ///
   b ci star(* 0.1 ** 0.05 *** 0.01) keep(2.Mn_LOD_EPA 3.Mn_LOD_EPA) ///
	coeflabel(2.Mn_LOD_EPA "Detected \ensuremath{<} Threshold" 3.Mn_LOD_EPA "Above USEPA Threshold") ///
    refcat(2.Mn_LOD_EPA "Mn Below LOD (ref.)", nolabel) ///
	replace nonote label noomitted nobase

coefplot ///
    (GSED_Mn_EPA_addcov, keep(3.Mn_LOD_EPA) rename(3.Mn_LOD_EPA=Full)) ///
    (GSED_MnEPA_rHHPb, keep(3.Mn_LOD_EPA) rename(3.Mn_LOD_EPA=Pb0)) ///
    (GSED_MnEPA_rHHFe, keep(3.Mn_LOD_EPA) rename(3.Mn_LOD_EPA=Fe0)) ///
    (GSED_MnEPA_rHHCr, keep(3.Mn_LOD_EPA) rename(3.Mn_LOD_EPA=Cr0)) ///
    (GSED_MnEPA_rHHAl, keep(3.Mn_LOD_EPA) rename(3.Mn_LOD_EPA=Al0)) ///
    (GSED_MnEPA_rHHCu, keep(3.Mn_LOD_EPA) rename(3.Mn_LOD_EPA=Cu0)) ///
	(GSED_MnEPA_rHHALL, keep(3.Mn_LOD_EPA) rename(3.Mn_LOD_EPA=ALL0)), ///
    vertical nooffsets ///
    yline(0, lpattern(dash)) ///
    coeflabels( ///
		Full="Full" ///
		Pb0="Pb<LOD" ///
		Fe0="Fe<LOD" ///
		Cr0="Cr<LOD" ///
		Al0="Al<LOD" ///
		Cu0="Cu<LOD" ///
		ALL0 = "All<LOD", labsize(small)) ///
    ciopts(recast(rcap)) ///
    legend(off) ytitle("") xtitle("Restricted Sample") ///
	title("{bf: B}. Coefficient on {bf: 1}(Household Mn > USEPA)") ///
	name(coefplot_rHHnonMn, replace)

// graph export "..\Output\Figures\RobustnessChecks_RemoveNonMn_HouseholdWater_Coefplot_AboveUSEPA.pdf", ///
// 	as(pdf) name(coefplot_rHHnonMn) replace

//====log(Mn) Specification===//
local cov_always "Batch sample_water_source_1 sample_water_source_2 sample_water_source_6 treatment i.dist_code"
local cov "age_chld_months_EL child_male prim_caregiver_female_BL"
local cov_add "own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_secondary_BL"
local model ""
local title "GSED"
local nonMn Pb Fe Cr Al Cu Household_nonMn_conc
local mtitle "Pb Fe Cr Al Cu ALL"
local i = 1
foreach var of local nonMn {
	local est_tit : word `i' of `mtitle'
	reg z_irt_all_30_48m  log_Mn_LODsq2 `cov_always' `cov' `cov_add' if `var'==0 , vce(cluster caregiver_id_BL)
		est store `title'_logMn_rHH`est_tit'
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `title'_logMn_rHH`est_tit'
		local model `model' `title'_logMn_rHH`est_tit'
	local i = `i' + 1
}
esttab `model' /* using "..\Output\Tables\RobustnessChecks_RemoveNonMnMetals_EPAsec.tex" */,  ///
    stats( Cov Cov_add N r2_p, labels( "Demographic Controls" "Economic Controls" "N (Children)" "Pseudo R-squared")) ///
   b ci star(* 0.1 ** 0.05 *** 0.01) keep(log_Mn_LODsq2) ///
	coeflabel(log_Mn_LODsq2 "log(Household Mn)") ///
	replace nonote label noomitted nobase

coefplot ///
    (GSED_Mn_addcov, keep(log_Mn_LODsq2) rename(log_Mn_LODsq2=Full)) ///
    (GSED_logMn_rHHPb, keep(log_Mn_LODsq2) rename(log_Mn_LODsq2=Pb0)) ///
    (GSED_logMn_rHHFe, keep(log_Mn_LODsq2) rename(log_Mn_LODsq2=Fe0)) ///
    (GSED_logMn_rHHCr, keep(log_Mn_LODsq2) rename(log_Mn_LODsq2=Cr0)) ///
    (GSED_logMn_rHHAl, keep(log_Mn_LODsq2) rename(log_Mn_LODsq2=Al0)) ///
    (GSED_logMn_rHHCu, keep(log_Mn_LODsq2) rename(log_Mn_LODsq2=Cu0)) ///
	(GSED_logMn_rHHALL, keep(log_Mn_LODsq2) rename(log_Mn_LODsq2=ALL0)), ///
    vertical nooffsets ///
    yline(0, lpattern(dash)) ///
    coeflabels( ///
		Full="Full" ///
		Pb0="Pb<LOD" ///
		Fe0="Fe<LOD" ///
		Cr0="Cr<LOD" ///
		Al0="Al<LOD" ///
		Cu0="Cu<LOD" ///
		ALL0 = "All<LOD", labsize(small)) ///
    ciopts(recast(rcap)) ///
    legend(off) ytitle("")  xtitle("Restricted Sample") ///
	title("{bf: A}. Coefficient on log(Household Mn)") ///
	name(coefplot_rHHnonMn_log, replace)

// graph export "..\Output\Figures\RobustnessChecks_RemoveNonMn_HouseholdWater_Coefplot_logMn.pdf", ///
// 	as(pdf) name(coefplot_rHHnonMn_log) replace

graph combine ///
	coefplot_rHHnonMn_log coefplot_rHHnonMn, ///
	row(1) name(coefplot_rHHnonMn, replace)

graph export ///
	"..\Output\Figures\RobustnessChecks_RemoveNonMn_HouseholdWater_Coefplot_logMnUSEPA.pdf", ///
	as(pdf) name(coefplot_rHHnonMn) replace
graph export ///
	"..\Output\Figures\RobustnessChecks_RemoveNonMn_HouseholdWater_Coefplot_logMnUSEPA.svg", ///
	as(svg) name(coefplot_rHHnonMn) replace

**remove HH and School contaminated metal

//====Categorical Specification===//
local cov_always "Batch sample_water_source_1 sample_water_source_2 sample_water_source_6 treatment i.dist_code"
local cov "age_chld_months_EL child_male prim_caregiver_female_BL"
local cov_add "own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_secondary_BL"
local title "GSED"
local nonMn Pb Fe Cr Al Cu
local i = 1
foreach var of local nonMn {
	local est_tit : word `i' of `mtitle'
	reg z_irt_all_30_48m  i.Mn_LOD_EPA `cov_always' `cov' `cov_add' if `var'==0 & school_`var'_max==0, vce(cluster caregiver_id_BL)
		est store `title'_MnEPA_rHHSch`var'
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `title'_MnEPA_rHHSch`var'
		local model `model' `title'_MnEPA_rHHSch`var'
	local i = `i' + 1
}
reg z_irt_all_30_48m  i.Mn_LOD_EPA `cov_always' `cov' `cov_add' if School_nonMn_conc==0 & Household_nonMn_conc==0, vce(cluster caregiver_id_BL)
		est store `title'_MnEPA_rHHSchAll
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `title'_MnEPA_rHHSchAll
		local model `model' `title'_MnEPA_rHHSchAll

esttab `model' /* using "..\Output\Tables\RobustnessChecks_RemoveNonMnMetals_EPAsec.tex" */,  ///
    stats( Cov Cov_add N r2_p, labels( "Demographic Controls" "Economic Controls" "N (Children)" "Pseudo R-squared")) ///
   b ci star(* 0.1 ** 0.05 *** 0.01) keep(2.Mn_LOD_EPA 3.Mn_LOD_EPA) ///
	coeflabel(2.Mn_LOD_EPA "Detected \ensuremath{<} Threshold" 3.Mn_LOD_EPA "Above USEPA Threshold") ///
    refcat(2.Mn_LOD_EPA "Mn Below LOD (ref.)", nolabel) ///
	replace nonote label noomitted nobase

coefplot ///
    (GSED_Mn_EPA_addcov, keep(3.Mn_LOD_EPA) rename(3.Mn_LOD_EPA=Full)) ///
    (GSED_MnEPA_rHHSchPb, keep(3.Mn_LOD_EPA) rename(3.Mn_LOD_EPA=Pb0)) ///
    (GSED_MnEPA_rHHSchFe, keep(3.Mn_LOD_EPA) rename(3.Mn_LOD_EPA=Fe0)) ///
    (GSED_MnEPA_rHHSchCr, keep(3.Mn_LOD_EPA) rename(3.Mn_LOD_EPA=Cr0)) ///
    (GSED_MnEPA_rHHSchAl, keep(3.Mn_LOD_EPA) rename(3.Mn_LOD_EPA=Al0)) ///
    (GSED_MnEPA_rHHSchCu, keep(3.Mn_LOD_EPA) rename(3.Mn_LOD_EPA=Cu0)) ///
	(GSED_MnEPA_rHHSchAll, keep(3.Mn_LOD_EPA) rename(3.Mn_LOD_EPA=ALL0)), ///
    vertical nooffsets ///
    yline(0, lpattern(dash)) ///
    coeflabels( ///
		Full="Full" ///
		Pb0="Pb<LOD" ///
		Fe0="Fe<LOD" ///
		Cr0="Cr<LOD" ///
		Al0="Al<LOD" ///
		Cu0="Cu<LOD" ///
		ALL0 = "All<LOD", labsize(small)) ///
    ciopts(recast(rcap)) ///
    legend(off) ytitle("") xtitle("Restricted Sample") ///
	title("{bf: B}. Coefficient on {bf: 1}(Household Mn > USEPA)") ///
	name(coefplot_rHHSchnonMn_EPA, replace)

// graph export "..\Output\Figures\RobustnessChecks_RemoveNonMn_HouseholdSchoolWater_Coefplot_AboveUSEPA.pdf", ///
// 	as(pdf) name(coefplot_rHHSchnonMn) replace

//====log(Mn) Specification===//
local cov_always "Batch sample_water_source_1 sample_water_source_2 sample_water_source_6 treatment i.dist_code"
local cov "age_chld_months_EL child_male prim_caregiver_female_BL"
local cov_add "own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_secondary_BL"
local model ""
local title "GSED"
local nonMn Pb Fe Cr Al Cu
foreach var of local nonMn {
	reg z_irt_all_30_48m  log_Mn_LODsq2 `cov_always' `cov' `cov_add' if `var'==0 & school_`var'_max==0 , vce(cluster caregiver_id_BL)
		est store `title'_logMn_rHHSch`var'
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `title'_logMn_rHHSch`var'
		local model `model' `title'_logMn_rHHSch`var'
}
reg z_irt_all_30_48m  log_Mn_LODsq2 `cov_always' `cov' `cov_add' if School_nonMn_conc==0 & Household_nonMn_conc==0, vce(cluster caregiver_id_BL)
		est store `title'_logMn_rHHSchAll
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `title'_logMn_rHHSchAll
		local model `model' `title'_logMn_rHHSchAll
esttab `model' /* using "..\Output\Tables\RobustnessChecks_RemoveNonMnMetals_EPAsec.tex" */,  ///
    stats( Cov Cov_add N r2_p, labels( "Demographic Controls" "Economic Controls" "N (Children)" "Pseudo R-squared")) ///
   b ci star(* 0.1 ** 0.05 *** 0.01) keep(log_Mn_LODsq2) ///
	coeflabel(log_Mn_LODsq2 "log(Household Mn)") ///
	replace nonote label noomitted nobase

coefplot ///
    (GSED_Mn_addcov, keep(log_Mn_LODsq2) rename(log_Mn_LODsq2=Full)) ///
    (GSED_logMn_rHHSchPb, keep(log_Mn_LODsq2) rename(log_Mn_LODsq2=Pb0)) ///
    (GSED_logMn_rHHSchFe, keep(log_Mn_LODsq2) rename(log_Mn_LODsq2=Fe0)) ///
    (GSED_logMn_rHHSchCr, keep(log_Mn_LODsq2) rename(log_Mn_LODsq2=Cr0)) ///
    (GSED_logMn_rHHSchAl, keep(log_Mn_LODsq2) rename(log_Mn_LODsq2=Al0)) ///
    (GSED_logMn_rHHSchCu, keep(log_Mn_LODsq2) rename(log_Mn_LODsq2=Cu0)) ///
	(GSED_logMn_rHHSchAll, keep(log_Mn_LODsq2) rename(log_Mn_LODsq2=ALL0)), ///
    vertical nooffsets ///
    yline(0, lpattern(dash)) ///
    coeflabels( ///
		Full = "Full" ///
		Pb0="Pb<LOD" ///
		Fe0="Fe<LOD" ///
		Cr0="Cr<LOD" ///
		Al0="Al<LOD" ///
		Cu0="Cu<LOD" ///
		ALL0 = "All<LOD", labsize(small)) ///
    ciopts(recast(rcap)) ///
    legend(off) xtitle("Restricted Sample") ytitle("") ///
	title("{bf: A}. Coefficient on log(Household Mn)") ///
	name(coefplot_rHHSchnonMn_log, replace)

// graph export "..\Output\Figures\RobustnessChecks_RemoveNonMn_HouseholdSchoolWater_Coefplot_logMn.pdf", ///
// 	as(pdf) name(coefplot_rHHSchnonMn_log) replace

graph combine ///
	coefplot_rHHSchnonMn_log coefplot_rHHSchnonMn_EPA , ///
	row(1) name(coefplot_rHHSchnonMn, replace)

graph export "..\Output\Figures\RobustnessChecks_RemoveNonMn_HouseholdSchoolWater_Coefplot_logMnUSEPA.pdf", ///
	as(pdf) name(coefplot_rHHSchnonMn) replace

graph export "..\Output\Figures\RobustnessChecks_RemoveNonMn_HouseholdSchoolWater_Coefplot_logMnUSEPA.svg", ///
	as(svg) name(coefplot_rHHSchnonMn) replace

save "$master_loc\Processed Stata Dta\Test Results Merged with EL Child Development.dta", replace


**US EPA Secondary Standards: Mn>=50
local if_cond "focal_child_yn==1|focal_child_yn==0" //-->need to be focal child and not enrolled in other schools (so either not enrolled in school OR enrolled in study school)
local cov_always "Batch sample_water_source_1 sample_water_source_2 sample_water_source_6 treatment i.dist_code"
local cov "age_chld_months_EL child_male prim_caregiver_female_BL"
local cov_add "own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_secondary_BL"
local model ""
local title "GSED Hlth ChldDev"
local i = 1

local outcome  z_irt_all_30_48m hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
foreach var of varlist `outcome' {

	local est_tit : word `i' of `title'
	reg `var'  EPA_sec_Mn_higher i.school_respondent_BL##ib0.school_Mn_EPA_higher school_respondent_BL `cov_always' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_MnEPA_sch
		quietly estadd local Cov = "No"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_MnEPA_sch
		local model `model' `est_tit'_MnEPA_sch

	reg `var'  EPA_sec_Mn_higher i.school_respondent_BL##ib0.school_Mn_EPA_higher school_respondent_BL `cov_always' `cov' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_MnEPA_sch_cov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_MnEPA_sch_cov
		local model `model' `est_tit'_MnEPA_sch_cov

	reg `var'  EPA_sec_Mn_higher i.school_respondent_BL##ib0.school_Mn_EPA_higher school_respondent_BL `cov_always' `cov' `cov_add' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_MnEPA_sch_addcov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `est_tit'_MnEPA_sch_addcov
		local model `model' `est_tit'_MnEPA_sch_addcov
	local i = `i' + 1
}
esttab `model' using "..\Output\Tables\EPA_Mn_and_SchoolExposure.rtf",  ///
    stats( Cov Cov_add N r2_p, labels( "Demographic Controls" "Economic Controls" "N (Children)" "Pseudo R-squared")) ///
		mtitle("GSED" "GSED" "GSED" "Healthier" "Healthier" "Healthier" "Advanced" "Advanced" "Advanced") ///
    b se star(* 0.1 ** 0.05 *** 0.01) keep(EPA_sec_Mn_higher *school_Mn_EPA_higher) ///
	coeflabel(1.school_Mn_EPA_higher "School Mn Above EPA" 0.school_respondent_BL#1.school_Mn_EPA_higher "Not FF X School Mn" 1.school_respondent_BL#1.school_Mn_EPA_higher "FF X School Mn above EPA") ///
	replace nonote label noomitted nobase
