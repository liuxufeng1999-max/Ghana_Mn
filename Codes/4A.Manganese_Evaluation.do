/* 4A. Evaluation Specific to Mn */ 
use "$master_loc\Processed Stata Dta\Test Results Merged with EL Child Development.dta", clear 


label define child_male 0 "Girls" 1 "Boys", replace
label values child_male_BL child_male
label var prim_caregiver_female_BL "Primary Caregiver is female"
capture drop caregiver_id_BL_num
capture egen caregiver_id_BL_num = group( caregiver_id_BL)


**Some further Mn-specific processing
gen Mn_above_LOD =  Mn > 0
label define Mn_aboveLOD 0 "Mn Below LOD" 1 "Mn Detected" , replace
label values Mn_above_LOD Mn_aboveLOD
label var Mn_above_LOD "HH Water Mn Above LOD"

egen Mn_LOD_EPA = group(Mn_above_LOD any_limit_Mn_higher), label
label define Mn_aboveLOD_EPA 1 "Mn Below LOD" 2 "Detected \ensuremath{<} Threshold" 3 "Above USEPA" , replace
label values Mn_LOD_EPA Mn_aboveLOD_EPA

egen Mn_LOD_WHO = group(Mn_above_LOD WHO_Mn_higher), label
label define Mn_aboveLOD_WHO 1 "Mn Below LOD" 2 "Detected \ensuremath{<} Threshold" 3 "Above WHO" , replace
label values Mn_LOD_WHO Mn_aboveLOD_WHO

gen school_Mn_max_LOD_EPA = 0 if school_Mn_max ==0
replace school_Mn_max_LOD_EPA = 1 if school_Mn_max >0 & school_Mn_max<50
replace school_Mn_max_LOD_EPA = 2 if school_Mn_max>50
label values Mn_LOD_WHO school_Mn_max_LOD_EPA
gen Fe_above_LOD =  Fe > 0
label define Fe_aboveLOD 0 "Fe Below LOD" 1 "Fe Detected" , replace
label values Fe_above_LOD Fe_aboveLOD
label var Fe_above_LOD "HH Water Fe Above LOD"	

**School Mn Preparation
gen school_Mn_max_sq = school_Mn_max * school_Mn_max
gen school_Mn_EPA_higher = school_Mn_max>=50
gen school_Mn_WHO_higher = school_Mn_max>=80

gen schoolMn_exposure = 0
replace schoolMn_exposure = log_school_Mn_max_LODsq2 if school_respondent_BL == 1
label var schoolMn_exposure "log(School Mn)"


**LOD (or MDL) for Mn: 2.953 in batch 1;  3.282 in batch 2 (all in ug/L); all sachets in batch 2
gen MN_LODsq2 = Mn
replace MN_LODsq2 = 2.953/sqrt(2) if Batch==1 & Mn==0
replace MN_LODsq2 = 3.282/sqrt(2) if Batch==2 & Mn==0
assert Batch_Sachet==2
replace MN_LODsq2 = 3.282/sqrt(2) if missing(Batch) & Mn==0 //--> all sachets in batch 2
gen log_Mn_LODsq2 = log10(MN_LODsq2)
label var log_Mn_LODsq2 "log(Household Mn)"

gen Fe_LODsq2 = Fe
replace  Fe_LODsq2 = 31.369/sqrt(2) if Batch==1 & Fe==0
replace  Fe_LODsq2 = 28.317/sqrt(2) if Batch==2 & Fe==0
replace Fe_LODsq2 = 28.317/sqrt(2) if missing(Batch) & Fe==0
gen log_Fe_LODsq2 = log10(Fe_LODsq2)
label var log_Fe_LODsq2 "log(Household Fe)"

gen school_Mn_max_LODsq2 = school_Mn_max
replace school_Mn_max_LODsq2 = 3.282/sqrt(2) if school_Mn_max==0 //-->all school samples in batch 2
gen log_school_Mn_max_LODsq2 = log10(school_Mn_max_LODsq2)
label var log_school_Mn_max_LODsq2 "log(School Mn)"

gen log_Mn = log(Mn + 1)
egen caregiver_id_BL_num = group( caregiver_id_BL)


**Further income processing 
//previously, we have a wide category on income above 5k and want to refine it based on the recalled information 
//DECISION: we prioritize the baseline information. if in the baseline, caregiver believe they are above/below 5k, then it is the true case
//so, we will only create category above 5k based on the recalled information when the caregiver also mention they are above 5k in the BL 
local catg geq20k geq15k geq10k
foreach cat in  `catg' {
	gen recall_income_`cat' = lyear_income_`cat'==1 & annual_income_geq5k_BL==1 
}
egen recall_income_1020k = rowmax(recall_income_geq20k recall_income_geq15k recall_income_geq10k)
gen recall_income_geq5k = annual_income_geq5k_BL==1 & recall_income_1020k == 0
replace recall_income_geq10k = 1 if recall_income_geq15k == 1 
egen recall_income_bel5k = rowmax(recall_income_geq20k recall_income_geq10k recall_income_geq5k)
replace recall_income_bel5k = recall_income_bel5k == 0
label var recall_income_geq20k "Annual income: \\ \hspace{20pt} Greater than 20,000 cedis"
label var recall_income_geq10k "\hspace{20pt} 10,000 to 19,999 cedis"
label var recall_income_geq5k "\hspace{20pt} 5,000 to 9,999 cedis"
label var recall_income_bel5k "\hspace{20pt} Below 4,999 cedis"
capture drop recall_income_geq15k recall_income_1020k 

**# Descriptive Plots
local cov "age_chld_months_EL treatment Batch i.sample_water_source"
local fe "dist_code sch_id"
capture drop z_irt_all_3048m_res
reghdfe  z_irt_all_30_48m `cov', absorb( dist_code ) residual(z_irt_all_3048m_res)
twoway /// 
	(kdensity z_irt_all_30_48m if Mn == 0 ) /// 
	(kdensity z_irt_all_30_48m if Mn_above_LOD == 1 ), /// 
	legend(pos(6) col(2) order(1 "Mn below LOD" 2 "Mn detected")) /// 
	xtitle("Standardized Child Development Score") ytitle("") name(z_irt_Mn, replace)
graph export "$master_loc\Output\Figures\kdensity_GSED_z_Score_and_Mn_Limits.pdf", /// 
	name(z_irt_Mn) as(pdf) replace
graph export "$master_loc\Output\Figures\kdensity_GSED_z_Score_and_Mn_Limits.svg", /// 
	name(z_irt_Mn) as(svg) replace
	
	
**# Balance Tables
**Compare the children (and caregivers) with Mn below LOD and Mn detected
**Ideally, we want to have no significant differnece 
local chld_cov "child_female age_chld_months_EL stories_yn_BL counted_yn_BL played_yn_BL taken_chld_work_yn_BL hme_made_toys_yn_BL toys_shop_yn_BL hsehld_objts_yn_BL objts_ousdie_yn_BL draw_write_materials_yn_BL puzzle_yn_BL who_engage_acti_mother_BL who_engage_acti_father_BL who_engage_acti_AnoRel_BL"
iebaltab `chld_cov', /// 
 grpvar(Mn_LOD_EPA) rowvarlabels nonote control(1) feqtest onerow ///
                         vce(cluster caregiver_id_BL_num) ///
                          fix(dist_code) ///
                          savetex("$master_loc\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_ChildCov.tex") replace 
// iebaltab `chld_cov', /// 
//  grpvar(Mn_LOD_EPA) rowvarlabels nonote control(1) feqtest onerow ///
//                          vce(cluster caregiver_id_BL_num) ///
//                           fix(dist_code) ///
//                           savecsv("$master_loc\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_ChildCov.csv") replace 
	  
	  
local caregiver_cov "prim_caregiver_female_BL age_BL nature_employ_unemp nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_primary_BL high_education_secondary_BL high_education_SSS_higher_BL school_respondent_BL"
local hh_cov "main_lang_chld_comm_Eng_BL main_lang_chld_comm_Twi_BL main_lang_chld_comm_Sef_BL num_pple_hsehld num_chld_hsehld_17 own_house_BL own_land_BL recall_income_geq20k recall_income_geq10k recall_income_geq5k recall_income_bel5k"	
iebaltab `hh_cov' `caregiver_cov' if focal_child_yn==1, /// 
 grpvar(Mn_LOD_EPA) rowvarlabels nonote control(1) feqtest onerow ///
                         vce(cluster caregiver_id_BL_num) ///
                          fix(dist_code) ///
                          savetex("$master_loc\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_Caregiver_Household_Covar.tex") replace 
// iebaltab `hh_cov' `caregiver_cov' if focal_child_yn==1, /// 
//  grpvar(Mn_LOD_EPA) rowvarlabels nonote control(1) feqtest onerow ///
//                          vce(cluster caregiver_id_BL_num) ///
//                           fix(dist_code) ///
//                           savecsv("$master_loc\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_Caregiver_Household_Covar.csv") replace 
						  
iebaltab `caregiver_cov' if focal_child_yn==1, /// 
 grpvar(Mn_LOD_EPA) rowvarlabels nonote control(1) feqtest onerow ///
                         vce(cluster caregiver_id_BL_num) ///
                          fix(dist_code) ///
                          savetex("$master_loc\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_CaregiverCov.tex") replace 

// local hh_cov "main_lang_chld_comm_Eng_BL main_lang_chld_comm_Twi_BL main_lang_chld_comm_Sef_BL num_pple_hsehld num_chld_hsehld_17 own_house_BL own_land_BL annual_income_geq5k_BL"	
local hh_cov "main_lang_chld_comm_Eng_BL main_lang_chld_comm_Twi_BL main_lang_chld_comm_Sef_BL num_pple_hsehld num_chld_hsehld_17 own_house_BL own_land_BL recall_income_geq20k recall_income_geq10k recall_income_geq5k recall_income_bel5k"	
iebaltab `hh_cov'  if focal_child_yn==1, /// 
 grpvar(Mn_LOD_EPA) rowvarlabels nonote control(1) feqtest onerow ///
                         vce(cluster caregiver_id_BL_num) ///
                          fix(dist_code) ///
                          savetex("$master_loc\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_HouseholdCov.tex") replace 

gen treat_drink_water_boil = means_treat_cook_1 == 1
gen treat_drink_water_alum = means_treat_cook_2 == 1
gen treat_drink_water_filt = means_treat_cook_3 == 1
gen treat_drink_water_chlor = means_treat_cook_4 == 1
label var treat_drink_water_boil "Water Treatment Method: \\ \hspace{20pt} Boiling"
label var treat_drink_water_alum "\hspace{20pt} Aluminum sulfate"						  
label var treat_drink_water_filt "\hspace{20pt} Filtraiton"
label var treat_drink_water_chlor "\hspace{20pt} Chlorine"
						  
						  
local water_practices "main_drink_wtr_safe treat_drink_water_yn treat_drink_water_boil treat_drink_water_alum treat_drink_water_chlor switch_drink_wtr_dry main_drink_wtr_dry_safe"
iebaltab `water_practices'  if focal_child_yn==1, /// 
 grpvar(Mn_LOD_EPA) rowvarlabels nonote control(1) feqtest  ///
                         vce(cluster caregiver_id_BL_num) ///
                          fix(dist_code) /// 
						  savetex("$master_loc\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_WaterSafetyTreatment_Method.tex") replace 	
// iebaltab `water_practices'  if focal_child_yn==1, /// 
//  grpvar(Mn_LOD_EPA) rowvarlabels nonote control(1) feqtest onerow ///
//                          vce(cluster caregiver_id_BL_num) ///
//                           fix(dist_code) ///
//                           savexlsx("$master_loc\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_WaterSafetyTreatment.xlsx") replace 		

**# Primary Results: Y = f(Mn) + X + e

**EPA Standard: >50ug/L 
local if_cond "(focal_child_yn==1|focal_child_yn==0)"
local cov_always "Batch treatment i.dist_code"
local cov "age_chld_months_EL child_male "
local cov_add "hh_learn_mca1 par_involv_mca1 own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_primary_BL high_education_secondary_BL high_education_SSS_higher_BL annual_income_geq5k_BL recall_income_geq20k recall_income_geq10k recall_income_geq5k recall_income_bel5k"
local model ""
local title "GSED Hlth ChldDev"
local i = 1
local bin_out  hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
local outcome  z_irt_all_30_48m //hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
foreach var of varlist `outcome' {
	 local is_bin = strpos(" `bin_out' "," `var' ")>0
    local basecmd = cond(`is_bin',"logit","reg")
	local est_tit : word `i' of `title'
	`basecmd' `var'  i.Mn_LOD_EPA `cov_always' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_Mn_EPA
		quietly estadd local Cov = "No"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_Mn_EPA
		local model `model' `est_tit'_Mn_EPA

	`basecmd' `var'  i.Mn_LOD_EPA `cov_always' `cov' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_Mn_EPA_cov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_Mn_EPA_cov
		local model `model' `est_tit'_Mn_EPA_cov

	`basecmd' `var'  i.Mn_LOD_EPA `cov_always' `cov' `cov_add' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_Mn_EPA_addcov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `est_tit'_Mn_EPA_addcov
		local model `model' `est_tit'_Mn_EPA_addcov
	local i = `i' + 1
}

esttab `model' using "$master_loc\Output\Tables\EPA_LOD_Mn_Exposure_ChildDev.tex",  ///
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
local bin_out  hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
local outcome  z_irt_all_30_48m //hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
foreach var of varlist `outcome' {
	 local is_bin = strpos(" `bin_out' "," `var' ")>0
    local basecmd = cond(`is_bin',"logit","reg")
	local est_tit : word `i' of `title'
	`basecmd' `var'  log_Mn_LODsq2 `cov_always' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_Mn
		quietly estadd local Cov = "No"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_Mn
		local model `model' `est_tit'_Mn

	`basecmd' `var'  log_Mn_LODsq2 `cov_always' `cov' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_Mn_cov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_Mn_cov
		local model `model' `est_tit'_Mn_cov

	`basecmd' `var'  log_Mn_LODsq2 `cov_always' `cov' `cov_add' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_Mn_addcov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `est_tit'_Mn_addcov
		local model `model' `est_tit'_Mn_addcov
	local i = `i' + 1
}
esttab `model' using "$master_loc\Output\Tables\Continuous_Mn_Exposure_ChildDev.tex",  ///
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
local bin_out  hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
local outcome  z_irt_all_30_48m //hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
foreach var of varlist `outcome' {
	 local is_bin = strpos(" `bin_out' "," `var' ")>0
    local basecmd = cond(`is_bin',"logit","reg")
	local est_tit : word `i' of `title'
	`basecmd' `var'  c.log_Mn_LODsq2##c.log_school_Mn_max_LODsq2 `cov_always' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_z_Mn_school
		quietly estadd local Cov = "No"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_z_Mn_school
		local model `model' `est_tit'_z_Mn_school

	`basecmd' `var'  c.log_Mn_LODsq2##c.log_school_Mn_max_LODsq2 `cov_always' `cov' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_z_Mn_school_cov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_z_Mn_school_cov
		local model `model' `est_tit'_z_Mn_school_cov

	`basecmd' `var'  c.log_Mn_LODsq2##c.log_school_Mn_max_LODsq2 `cov_always' `cov' `cov_add' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_z_Mn_school_addcov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `est_tit'_z_Mn_school_addcov
		local model `model' `est_tit'_z_Mn_school_addcov
	local i = `i' + 1
}
esttab `model'  using "$master_loc\Output\Tables\Mn_plus_SchoolExposure_ChildDev.tex",  ///
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

graph export "$master_loc\Output\Figures\MarginsPlot_AME_by_SchoolMn.pdf", ///
	name(SchoolMn) as(pdf) replace 

graph export "$master_loc\Output\Figures\MarginsPlot_AME_by_SchoolMn.svg", ///
	name(SchoolMn) as(svg) replace
**# Heterogeneity: Male vs. Female 

local if_cond "(focal_child_yn==1|focal_child_yn==0)" //-->need to be focal child and not enrolled in other schools (so either not enrolled in school OR enrolled in study school)
local cov_always "Batch treatment i.dist_code"
local cov "age_chld_months_EL "
local cov_add "hh_learn_mca1 par_involv_mca1 own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_primary_BL high_education_secondary_BL high_education_SSS_higher_BL annual_income_geq5k_BL"
local model ""
local title "GSED Hlth ChldDev"
local i = 1
local bin_out  hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
local outcome  z_irt_all_30_48m //hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
foreach var of varlist `outcome' {
	 local is_bin = strpos(" `bin_out' "," `var' ")>0
    local basecmd = cond(`is_bin',"logit","reg")
	local est_tit : word `i' of `title'
	`basecmd' `var' c.log_Mn_LODsq2##child_male_BL `cov_always' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_z_Mn_Male
		quietly estadd local Cov = "No"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_z_Mn_Male
		local model `model' `est_tit'_z_Mn_Male

	`basecmd' `var'  c.log_Mn_LODsq2##child_male_BL `cov_always' `cov' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_z_Mn_Male_cov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_z_Mn_Male_cov
		local model `model' `est_tit'_z_Mn_Male_cov

	`basecmd' `var'  c.log_Mn_LODsq2##child_male_BL  `cov_always' `cov' `cov_add' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_z_Mn_Male_addcov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `est_tit'_z_Mn_Male_addcov
		local model `model' `est_tit'_z_Mn_Male_addcov
	local i = `i' + 1
}
esttab `model' using "$master_loc\Output\Tables\Mn_ChildDev_by_BoysGirls.tex",  ///
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
	
	
// **# Heterogeneity: Presence of Iron in Water 
//	
// local if_cond "(focal_child_yn==1|focal_child_yn==0)" //-->need to be focal child and not enrolled in other schools (so either not enrolled in school OR enrolled in study school)
// local cov_always "Batch sample_water_source_1 sample_water_source_2 sample_water_source_6 treatment i.dist_code"
// local cov "age_chld_months_EL child_male prim_caregiver_female_BL"
// local cov_add "own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_secondary_BL annual_income_geq5k_BL"
// local model ""
// local title "GSED Hlth ChldDev"
// local i = 1
// local bin_out  hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
// local outcome  z_irt_all_30_48m //hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
// foreach var of varlist `outcome' {
// 	 local is_bin = strpos(" `bin_out' "," `var' ")>0
//     local basecmd = cond(`is_bin',"logit","reg")
// 	local est_tit : word `i' of `title'
// 	`basecmd' `var'  Mn_above_LOD##Fe_above_LOD `cov_always' if `if_cond' , vce(cluster caregiver_id_BL)
// 		est store `est_tit'_z_Mn_school
// 		quietly estadd local Cov = "No"
// 		quietly estadd local Cov_add = "No"
// 		est store `est_tit'_z_Mn_school
// 		local model `model' `est_tit'_z_Mn_school
//
// 	`basecmd' `var'  Mn_above_LOD##Fe_above_LOD `cov_always' `cov' if `if_cond' , vce(cluster caregiver_id_BL)
// 		est store `est_tit'_z_Mn_school_cov
// 		quietly estadd local Cov = "Yes"
// 		quietly estadd local Cov_add = "No"
// 		est store `est_tit'_z_Mn_school_cov
// 		local model `model' `est_tit'_z_Mn_school_cov
//
// 	`basecmd' `var'  Mn_above_LOD##Fe_above_LOD `cov_always' `cov' `cov_add' if `if_cond' , vce(cluster caregiver_id_BL)
// 		est store `est_tit'_z_Mn_school_addcov
// 		quietly estadd local Cov = "Yes"
// 		quietly estadd local Cov_add = "Yes"
// 		est store `est_tit'_z_Mn_school_addcov
// 		local model `model' `est_tit'_z_Mn_school_addcov
// 	local i = `i' + 1
// }
// esttab `model' /*using "$master_loc\Output\Tables\Continuous_Mn_and_SchoolExposure.tex"*/,  ///
//     stats( Cov Cov_add N r2_p, labels( "Demographic Controls" "Economic Controls" "N (Children)" "Pseudo R-squared")) ///
// 			mtitle("Child Development Score" "Child Development Score" "Child Development Score" "Healthier" "Healthier" "Healthier" "Advanced" "Advanced" "Advanced") ///
//     b se star(* 0.1 ** 0.05 *** 0.01) keep(Mn_above_LOD *log_school_Mn_max ) /// 
// 	coeflabel(0.school_respondent_BL#c.school_Mn_max "Not FF X School Mn" 1.school_respondent_BL#c.school_Mn_max "FF X School Mn" 0.school_respondent_BL#c.school_Mn_max_sq "Not FF X School Mn Sq" 1.school_respondent_BL#c.school_Mn_max_sq "FF X School Mn Sq" ) replace nonote label noomitted
	
**# Robustness Checks: Cinelli and Hazlett (2020) Bound 
capture frame create sensemakr
capture tab Mn_LOD_EPA, gen(Mn_LOD_EPA)

**Categorical Mn: LOD EPA 
capture drop if missing(child_code)
local cov_always "Batch treatment i.dist_code"
local cov "age_chld_months_EL child_male "
local cov_add "hh_learn_mca1 par_involv_mca1 own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_primary_BL high_education_secondary_BL high_education_SSS_higher_BL recall_income_geq20k recall_income_geq10k recall_income_geq5k"
quietly reg z_irt_all_30_48m  Mn_LOD_EPA2 Mn_LOD_EPA3 `cov_always' `cov' `cov_add' , vce(cluster caregiver_id_BL)
cd "$master_loc\Output\Tables\"
sensemakr /// 
	z_irt_all_30_48m  Mn_LOD_EPA2 Mn_LOD_EPA3 `cov_always' `cov' `cov_add', ///
	treat(Mn_LOD_EPA3) alpha(0.1) /// 
	gbenchmark(hh_learn_mca1 par_involv_mca1 recall_income_geq20k recall_income_geq10k recall_income_geq5k) gname(Covariates) extremeplot elim(0 0.2) contourplot kd(0.5 1 2) clines(5) ///
	latex(Sensemakr_EPALODMn_Results) r2yz(1 0.75 0.5 0.25)
graph copy s_extremeplot Mn_EPA_extreme, replace  
// graph copy s_countourplot Mn_EPA_countour, replace  


**log 
capture drop if missing(child_code)
local cov_always "Batch treatment i.dist_code"
local cov "age_chld_months_EL child_male "
local cov_add "hh_learn_mca1 par_involv_mca1 own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_primary_BL high_education_secondary_BL high_education_SSS_higher_BL recall_income_geq20k recall_income_geq10k recall_income_geq5k"
quietly reg z_irt_all_30_48m  log_Mn_LODsq2 `cov_always' `cov' `cov_add' , vce(cluster caregiver_id_BL)
cd "$master_loc\Output\Tables\"
sensemakr /// 
	z_irt_all_30_48m  log_Mn_LODsq2 `cov_always' `cov' `cov_add', ///
	treat(log_Mn_LODsq2) alpha(0.1) /// 
	gbenchmark(hh_learn_mca1 par_involv_mca1 recall_income_geq20k recall_income_geq10k recall_income_geq5k) gname(Covariates) extremeplot elim(0 0.2)  contourplot kd(0.5 1 2) clines(5) ///
	latex(Sensemakr_logMn_Results) r2yz(1 0.75 0.5 0.25)
graph copy s_extremeplot logMn_extreme, replace  
// graph copy s_countourplot Mn_log_countour, replace  

grc1leg Mn_EPA_extreme	logMn_extreme, name(sensemakr_EPA_Log_Extreme, replace) xcommon

// grc1leg combine Mn_EPA_countour s_countourplot, legend(off)
	
capture drop if missing(child_code)
STOP	
graph export "$master_loc\Output\Figures\Sensemakr_EPA_LogMn_ExtremePlot.pdf", ///
	as(pdf) name(sensemakr_EPA_Log_Extreme) replace

graph export "$master_loc\Output\Figures\Sensemakr_EPA_LogMn_ExtremePlot.svg", ///
	as(svg) name(sensemakr_EPA_Log_Extreme) replace
	
	
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
		
esttab `model' /* using "$master_loc\Output\Tables\RobustnessChecks_RemoveNonMnMetals_EPAsec.tex" */,  ///
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
	
// graph export "$master_loc\Output\Figures\RobustnessChecks_RemoveNonMn_HouseholdWater_Coefplot_AboveUSEPA.pdf", ///
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
esttab `model' /* using "$master_loc\Output\Tables\RobustnessChecks_RemoveNonMnMetals_EPAsec.tex" */,  ///
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
	
// graph export "$master_loc\Output\Figures\RobustnessChecks_RemoveNonMn_HouseholdWater_Coefplot_logMn.pdf", ///
// 	as(pdf) name(coefplot_rHHnonMn_log) replace

graph combine /// 
	coefplot_rHHnonMn_log coefplot_rHHnonMn, /// 
	row(1) name(coefplot_rHHnonMn, replace)

graph export ///
	"$master_loc\Output\Figures\RobustnessChecks_RemoveNonMn_HouseholdWater_Coefplot_logMnUSEPA.pdf", ///
	as(pdf) name(coefplot_rHHnonMn) replace
graph export ///
	"$master_loc\Output\Figures\RobustnessChecks_RemoveNonMn_HouseholdWater_Coefplot_logMnUSEPA.svg", ///
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
		
esttab `model' /* using "$master_loc\Output\Tables\RobustnessChecks_RemoveNonMnMetals_EPAsec.tex" */,  ///
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
	
// graph export "$master_loc\Output\Figures\RobustnessChecks_RemoveNonMn_HouseholdSchoolWater_Coefplot_AboveUSEPA.pdf", ///
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
esttab `model' /* using "$master_loc\Output\Tables\RobustnessChecks_RemoveNonMnMetals_EPAsec.tex" */,  ///
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
	
// graph export "$master_loc\Output\Figures\RobustnessChecks_RemoveNonMn_HouseholdSchoolWater_Coefplot_logMn.pdf", ///
// 	as(pdf) name(coefplot_rHHSchnonMn_log) replace	

graph combine /// 
	coefplot_rHHSchnonMn_log coefplot_rHHSchnonMn_EPA , ///
	row(1) name(coefplot_rHHSchnonMn, replace)

graph export "$master_loc\Output\Figures\RobustnessChecks_RemoveNonMn_HouseholdSchoolWater_Coefplot_logMnUSEPA.pdf", ///
	as(pdf) name(coefplot_rHHSchnonMn) replace	

graph export "$master_loc\Output\Figures\RobustnessChecks_RemoveNonMn_HouseholdSchoolWater_Coefplot_logMnUSEPA.svg", ///
	as(svg) name(coefplot_rHHSchnonMn) replace	
	
save "$master_loc\Processed Stata Dta\Test Results Merged with EL Child Development.dta", replace 


STOP 

**US EPA Secondary Standards: Mn>=50
local if_cond "focal_child_yn==1|focal_child_yn==0" //-->need to be focal child and not enrolled in other schools (so either not enrolled in school OR enrolled in study school)
local cov_always "Batch sample_water_source_1 sample_water_source_2 sample_water_source_6 treatment i.dist_code"
local cov "age_chld_months_EL child_male prim_caregiver_female_BL"
local cov_add "own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_secondary_BL"
local model ""
local title "GSED Hlth ChldDev"
local i = 1
local bin_out  hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
local outcome  z_irt_all_30_48m hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
foreach var of varlist `outcome' {
	 local is_bin = strpos(" `bin_out' "," `var' ")>0
    local basecmd = cond(`is_bin',"logit","reg")
	local est_tit : word `i' of `title'
	`basecmd' `var'  EPA_sec_Mn_higher i.school_respondent_BL##ib0.school_Mn_EPA_higher school_respondent_BL `cov_always' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_MnEPA_sch
		quietly estadd local Cov = "No"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_MnEPA_sch
		local model `model' `est_tit'_MnEPA_sch

	`basecmd' `var'  EPA_sec_Mn_higher i.school_respondent_BL##ib0.school_Mn_EPA_higher school_respondent_BL `cov_always' `cov' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_MnEPA_sch_cov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_MnEPA_sch_cov
		local model `model' `est_tit'_MnEPA_sch_cov

	`basecmd' `var'  EPA_sec_Mn_higher i.school_respondent_BL##ib0.school_Mn_EPA_higher school_respondent_BL `cov_always' `cov' `cov_add' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_MnEPA_sch_addcov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `est_tit'_MnEPA_sch_addcov
		local model `model' `est_tit'_MnEPA_sch_addcov
	local i = `i' + 1
}
esttab `model' using "$master_loc\Output\Tables\EPA_Mn_and_SchoolExposure.tex",  ///
    stats( Cov Cov_add N r2_p, labels( "Demographic Controls" "Economic Controls" "N (Children)" "Pseudo R-squared")) ///
		mtitle("GSED" "GSED" "GSED" "Healthier" "Healthier" "Healthier" "Advanced" "Advanced" "Advanced") ///
    b se star(* 0.1 ** 0.05 *** 0.01) keep(EPA_sec_Mn_higher *school_Mn_EPA_higher) /// 
	coeflabel(1.school_Mn_EPA_higher "School Mn Above EPA" 0.school_respondent_BL#1.school_Mn_EPA_higher "Not FF X School Mn" 1.school_respondent_BL#1.school_Mn_EPA_higher "FF X School Mn above EPA") /// 
	replace nonote label noomitted nobase

	
/*
**# Explore Presence of Iron and Mn
// **Continuous Mn with squared term 
// local if_cond "(focal_child_yn==1|focal_child_yn==0)"
// local cov_always "Batch sample_water_source_1 sample_water_source_2 sample_water_source_6 treatment i.dist_code"
// local cov "age_chld_months_EL child_male "
// local cov_add "own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_secondary_BL"
// local model ""
// local title "GSED Hlth ChldDev"
// local i = 1
// local bin_out  hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
// local outcome  z_irt_all_30_48m hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
// foreach var of varlist `outcome' {
// 	 local is_bin = strpos(" `bin_out' "," `var' ")>0
//     local basecmd = cond(`is_bin',"logit","reg")
// 	local est_tit : word `i' of `title'
// 	`basecmd' `var'  Mn Mn_sq `cov_always' if `if_cond' , vce(cluster caregiver_id_BL)
// 		est store `est_tit'_Mn
// 		quietly estadd local Cov = "No"
// 		quietly estadd local Cov_add = "No"
// 		est store `est_tit'_Mn
// 		local model `model' `est_tit'_Mn
//
// 	`basecmd' `var'  Mn Mn_sq `cov_always' `cov' if `if_cond' , vce(cluster caregiver_id_BL)
// 		est store `est_tit'_Mn_cov
// 		quietly estadd local Cov = "Yes"
// 		quietly estadd local Cov_add = "No"
// 		est store `est_tit'_Mn_cov
// 		local model `model' `est_tit'_Mn_cov
//
// 	`basecmd' `var'  Mn Mn_sq `cov_always' `cov' `cov_add' if `if_cond' , vce(cluster caregiver_id_BL)
// 		est store `est_tit'_Mn_addcov
// 		quietly estadd local Cov = "Yes"
// 		quietly estadd local Cov_add = "Yes"
// 		est store `est_tit'_Mn_addcov
// 		local model `model' `est_tit'_Mn_addcov
// 	local i = `i' + 1
// }
// esttab `model' using "$master_loc\Output\Tables\Continuous_Mn_Exposure_ChildDev.tex",  ///
//     stats( Cov Cov_add N r2_p, labels( "Demographic Controls" "Economic Controls" "N (Children)" "Pseudo R-squared")) ///
// 	mtitle("GSED" "GSED" "GSED" "Healthier" "Healthier" "Healthier" "Advanced" "Advanced" "Advanced") ///
//     b se star(* 0.1 ** 0.05 *** 0.01) keep(Mn  Mn_sq) /// 
// 	replace nonote label 


	**WHO Standard: >80ug/L 
local if_cond "(focal_child_yn==1|focal_child_yn==0)"
local cov_always "Batch treatment i.dist_code"
local cov "age_chld_months_EL child_male "
local cov_add "hh_learn_mca1 par_involv_mca1 own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_primary_BL high_education_secondary_BL high_education_SSS_higher_BL annual_income_geq5k_BL"
local model ""
local title "GSED Hlth ChldDev"
local i = 1
local bin_out  hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
local outcome  z_irt_all_30_48m hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
foreach var of varlist `outcome' {
	 local is_bin = strpos(" `bin_out' "," `var' ")>0
    local basecmd = cond(`is_bin',"logit","reg")
	local est_tit : word `i' of `title'
	`basecmd' `var'  WHO_Mn_higher `cov_always' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_Mn_WHO
		quietly estadd local Cov = "No"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_Mn_WHO
		local model `model' `est_tit'_Mn_WHO

	`basecmd' `var'  WHO_Mn_higher `cov_always' `cov' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_Mn_WHO_cov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_Mn_WHO_cov
		local model `model' `est_tit'_Mn_WHO_cov

	`basecmd' `var'  WHO_Mn_higher `cov_always' `cov' `cov_add' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'__Mn_WHO_addcov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `est_tit'_Mn_WHO_addcov
		local model `model' `est_tit'_Mn_WHO_addcov
	local i = `i' + 1
}
esttab `model' /*using "$master_loc\Output\Tables\WHO_Mn_Exposure_ChildDev.tex" */,  ///
    stats( Cov Cov_add N r2_p, labels( "Demographic Controls" "Economic Controls" "N (Children)" "Pseudo R-squared")) ///
		mtitle("GSED" "GSED" "GSED" "Healthier" "Healthier" "Healthier" "Advanced" "Advanced" "Advanced") ///
    b se star(* 0.1 ** 0.05 *** 0.01) keep(WHO_Mn_higher) /// 
	replace nonote label 
	
**Now for school respondent 
local if_cond "(focal_child_yn==1|focal_child_yn==0)" //-->need to be focal child and not enrolled in other schools (so either not enrolled in school OR enrolled in study school)
local cov_always "Batch sample_water_source_1 sample_water_source_2 sample_water_source_6 treatment i.dist_code"
local cov "age_chld_months_EL child_male prim_caregiver_female_BL"
local cov_add "own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_secondary_BL annual_income_geq5k_BL"
local model ""
local title "GSED Hlth ChldDev"
local i = 1
local bin_out  hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
local outcome  z_irt_all_30_48m hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
foreach var of varlist `outcome' {
	 local is_bin = strpos(" `bin_out' "," `var' ")>0
    local basecmd = cond(`is_bin',"logit","reg")
	local est_tit : word `i' of `title'
	`basecmd' `var'  Mn Mn_sq school_respondent_BL#c.school_Mn_max school_respondent_BL#c.school_Mn_max_sq school_respondent_BL `cov_always' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_z_Mn_school
		quietly estadd local Cov = "No"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_z_Mn_school
		local model `model' `est_tit'_z_Mn_school

	`basecmd' `var'  Mn Mn_sq school_respondent_BL#c.school_Mn_max school_respondent_BL#c.school_Mn_max_sq school_respondent_BL `cov_always' `cov' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_z_Mn_school_cov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_z_Mn_school_cov
		local model `model' `est_tit'_z_Mn_school_cov

	`basecmd' `var'  Mn Mn_sq school_respondent_BL#c.school_Mn_max school_respondent_BL#c.school_Mn_max_sq school_respondent_BL `cov_always' `cov' `cov_add' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_z_Mn_school_addcov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `est_tit'_z_Mn_school_addcov
		local model `model' `est_tit'_z_Mn_school_addcov
	local i = `i' + 1
}
esttab `model' using "$master_loc\Output\Tables\Continuous_Mn_and_SchoolExposure.tex",  ///
    stats( Cov Cov_add N r2_p, labels( "Demographic Controls" "Economic Controls" "N (Children)" "Pseudo R-squared")) ///
			mtitle("GSED" "GSED" "GSED" "Healthier" "Healthier" "Healthier" "Advanced" "Advanced" "Advanced") ///
    b se star(* 0.1 ** 0.05 *** 0.01) keep(Mn  Mn_sq *school_Mn_max *school_Mn_max_sq) /// 
	coeflabel(0.school_respondent_BL#c.school_Mn_max "Not FF X School Mn" 1.school_respondent_BL#c.school_Mn_max "FF X School Mn" 0.school_respondent_BL#c.school_Mn_max_sq "Not FF X School Mn Sq" 1.school_respondent_BL#c.school_Mn_max_sq "FF X School Mn Sq" ) replace nonote label 
	

**Some further Fe-specific Processing 



local if_cond "focal_child_yn==1|focal_child_yn==0" //-->need to be focal child and not enrolled in other schools (so either not enrolled in school OR enrolled in study school)
local cov_always "Batch sample_water_source_1 sample_water_source_2 sample_water_source_6 treatment i.dist_code"
local cov "age_chld_months_EL child_male prim_caregiver_female_BL"
local cov_add "own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_secondary_BL"
local model ""
local title "GSED Hlth ChldDev"
local i = 1
local bin_out  hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
local outcome  z_irt_all_30_48m hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
foreach var of varlist `outcome' {
	 local is_bin = strpos(" `bin_out' "," `var' ")>0
    local basecmd = cond(`is_bin',"logit","reg")
	local est_tit : word `i' of `title'
	`basecmd' `var'   Fe_above_LOD##Mn_above_LOD  `cov_always' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_MnEPA_sch
		quietly estadd local Cov = "No"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_MnEPA_sch
		local model `model' `est_tit'_MnEPA_sch

	`basecmd' `var'   Fe_above_LOD##Mn_above_LOD  `cov_always' `cov' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_MnEPA_sch_cov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "No"
		est store `est_tit'_MnEPA_sch_cov
		local model `model' `est_tit'_MnEPA_sch_cov

	`basecmd' `var'   Fe_above_LOD##Mn_above_LOD  `cov_always' `cov' `cov_add' if `if_cond' , vce(cluster caregiver_id_BL)
		est store `est_tit'_MnEPA_sch_addcov
		quietly estadd local Cov = "Yes"
		quietly estadd local Cov_add = "Yes"
		est store `est_tit'_MnEPA_sch_addcov
		local model `model' `est_tit'_MnEPA_sch_addcov
	local i = `i' + 1
}  	
	
	
	
	
	
	
	
	
save "$master_loc\Processed Stata Dta\Test Results Merged with EL Child Development.dta", replace 
	

/* 
**# Dose-Response 
sum Mn
local Mn_max = r(max)
capture gen Mn_ct = Mn/`Mn_max' * 100
local s = 50 / `Mn_max'*100
local delta = 10/ `Mn_max'*100
di "`s'"  
di "`delta'"

local cov "age_chld_months_EL Batch sample_water_source_1 sample_water_source_2 sample_water_source_3 sample_water_source_4 sample_water_source_6 dist_code_1 dist_code_2 dist_code_3 child_male prim_caregiver_female_BL"
local cov_add "own_house_BL own_land_BL prim_cgver_emplyd_BL high_education_secondary_BL"
ctreatreg z_irt_all_30_48m any_limit_Mn_higher `cov', model("ct-ols") ct(Mn_ct) m(3) s(`s') vce(robust) graphdrf ci(10) delta(`delta')
	//
// reghdfe  z_irt_all_30_48m EPA_sec_Mn_higher `cov_always' , vce(cluster caregiver_id_BL) absorb( dist_code )
// 	est store Mn_EPA_limit
// reghdfe z_irt_all_30_48m WHO_Mn_higher `cov_always', vce(cluster caregiver_id_BL) absorb( dist_code )
// 	est store Mn_WHO_limit
// reghdfe z_irt_all_30_48m Mn Mn_sq `cov_always' ,  vce(cluster caregiver_id_BL) absorb( dist_code )
// 	est store Mn_Square_conc
//
// reghdfe  z_irt_all_30_48m EPA_sec_Mn_higher `cov_always' `cov', vce(cluster caregiver_id_BL) absorb( dist_code )
// 	est store Mn_EPA_limit_cov
// reghdfe z_irt_all_30_48m WHO_Mn_higher `cov_always', vce(cluster caregiver_id_BL) absorb( dist_code )
// 	est store Mn_WHO_limit_cov
// reghdfe z_irt_all_30_48m Mn Mn_sq `cov_always' ,  vce(cluster caregiver_id_BL) absorb( dist_code )
// 	est store Mn_Square_conc_cov
//	
// esttab Mn_EPA_limit Mn_WHO_limit Mn_Square_conc using "$master_loc\Output\Tables\Mn_and_ChildDevelopment.tex",  ///
//     stats(N r2, labels("N (Children)" "R-squared")) ///
//     b se star(* 0.1 ** 0.05 *** 0.01) keep(EPA_sec_Mn_higher WHO_Mn_higher Mn Mn_sq ) /// 
// 	mtitle("GSED Z Score" "GSED Z Score" "GSED Z Score") /// 
// 	replace nonote label 


	**# Alternative outcome 
local cov_always "Batch sample_water_source_1 sample_water_source_2 sample_water_source_6 i.dist_code treatment"
local cov "age_chld_months_EL child_male prim_caregiver_female_BL"
local cov_add "own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_secondary_BL annual_income_geq5k_BL"

local model ""
**Perceived BL Health Status
quietly logit hlth_stat_chld_healthier_BL  Mn  Mn_sq `cov_always' , vce(cluster new_village_id)
est store BLhlth_Mn
	quietly sum hlth_stat_chld_healthier_BL
		local Y_mean = trim("`: display %5.2f r(mean)'")
		local Y_sd   = trim("`: display %5.2f r(sd)'")
		quietly estadd local Y_mean_sd = "`Y_mean' (`Y_sd')" 
	quietly estadd local Cov = "No"
	quietly estadd local Cov_add = "No"
	est store BLhlth_Mn
	local model `model' BLhlth_Mn

quietly logit hlth_stat_chld_healthier_BL  Mn  Mn_sq `cov_always' `cov'  , vce(cluster new_village_id)
est store BLhlth_Mn_cov
	quietly estadd local Y_mean_sd = "`Y_mean' (`Y_sd')" 
	quietly estadd local Cov = "Yes"
	quietly estadd local Cov_add = "No"
	est store BLhlth_Mn_cov
	local model `model' BLhlth_Mn_cov

quietly logit hlth_stat_chld_healthier_BL  Mn  Mn_sq `cov_always' `cov' `cov_add'  , vce(cluster new_village_id)
est store BLhlth_Mn_addcov
	quietly estadd local Y_mean_sd = "`Y_mean' (`Y_sd')" 
	quietly estadd local Cov = "Yes"
	quietly estadd local Cov_add = "Yes"
	est store BLhlth_Mn_addcov
	local model `model' BLhlth_Mn_addcov

**Perceived Child Development Age
quietly logit child_dev_age_advanced_BL  Mn  Mn_sq `cov_always' , vce(cluster new_village_id)
est store BLdevAge_Mn
	quietly sum child_dev_age_advanced_BL
		local Y_mean = trim("`: display %5.2f r(mean)'")
		local Y_sd   = trim("`: display %5.2f r(sd)'")
		quietly estadd local Y_mean_sd = "`Y_mean' (`Y_sd')" 
	quietly estadd local Cov = "No"
	quietly estadd local Cov_add = "No"
	est store BLdevAge_Mn
	local model `model' BLdevAge_Mn
	
quietly logit child_dev_age_advanced_BL  Mn  Mn_sq `cov_always' `cov'  , vce(cluster new_village_id)
est store BLdevAge_Mn_cov
	quietly estadd local Y_mean_sd = "`Y_mean' (`Y_sd')" 
	quietly estadd local Cov = "Yes"
	quietly estadd local Cov_add = "No"
	est store BLdevAge_Mn_cov
	local model `model' BLdevAge_Mn_cov

quietly logit child_dev_age_advanced_BL  Mn  Mn_sq `cov_always' `cov' `cov_add'  , vce(cluster new_village_id)
est store BLdevAge_Mn_addcov
	quietly estadd local Y_mean_sd = "`Y_mean' (`Y_sd')" 
	quietly estadd local Cov = "Yes"
	quietly estadd local Cov_add = "Yes"
	est store BLdevAge_Mn_addcov
	local model `model' BLdevAge_Mn_addcov

esttab `model' using "$master_loc\Output\Tables\Mn_and_Alternative_Perceived_Outcomes.tex",  ///
    stats(Y_mean_sd Cov Cov_add N r2_p, labels("Dep. Var Mean (SD)" "Demographic Controls" "Economic Controls" "N (Children)" "Pseudo R-squared")) ///
    b se star(* 0.1 ** 0.05 *** 0.01) keep(Mn  Mn_sq) /// 
	replace nonote label 

	
	