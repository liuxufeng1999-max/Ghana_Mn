/* 4.Evaluation of Results */
use "..\Processed Stata Dta\Test Results Merged with EL Child Development.dta", clear

**# some further processing
tab sample_water_source, gen( sample_water_source_)
tab dist_code, gen( dist_code_)
replace annual_income_geq5k_BL = (lyear_income_leq5k == 0) if missing(annual_income_geq5k_BL) & !missing(lyear_income_leq5k)
gen child_female = child_male == 0
label var child_female "Child is female"
label var age_BL "Caregiver age"
capture drop new_village_id_group
egen new_village_id_group = group(new_village_id), label

label var num_pple_hsehld "Household size"
label var num_chld_hsehld_5 "Number of below-five children"

	**# Covariates Dimension Reduction
**household learning materials
mca hme_made_toys_yn_BL toys_shop_yn_BL hsehld_objts_yn_BL objts_ousdie_yn_BL draw_write_materials_yn_BL puzzle_yn_BL, dim(1)
predict hh_learn_mca1 if e(sample)

**Parental involvement
mca stories_yn counted_yn played_yn taken_chld_work_yn, dim(1)
predict par_involv_mca1 if e(sample)

**Household Asset Ownership
egen own_house_land_group = group(own_othr_hse_BL own_agric_land_BL), label(own_house_land_group,replace)
tab  own_house_land_group, gen( own_house_land_group_)
mca own_house_land_group_*, dim(1)
predict asset_own_mca1 if e(sample)
drop own_house_land_group_*



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

gen schoolMn_exposure = 0
replace schoolMn_exposure = log_school_Mn_max_LODsq2 if school_respondent_BL == 1
label var schoolMn_exposure "log(School Mn)"


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
graph export "..\Output\Figures\kdensity_GSED_z_Score_and_Mn_Limits.pdf", ///
	name(z_irt_Mn) as(pdf) replace
graph export "..\Output\Figures\kdensity_GSED_z_Score_and_Mn_Limits.svg", ///
	name(z_irt_Mn) as(svg) replace


**# Balance Tables
**Compare the children (and caregivers) with Mn below LOD and Mn detected
**Ideally, we want to have no significant differnece
local chld_cov "child_female age_chld_months_EL stories_yn_BL counted_yn_BL played_yn_BL taken_chld_work_yn_BL hme_made_toys_yn_BL toys_shop_yn_BL hsehld_objts_yn_BL objts_ousdie_yn_BL draw_write_materials_yn_BL puzzle_yn_BL who_engage_acti_mother_BL who_engage_acti_father_BL who_engage_acti_AnoRel_BL"
iebaltab `chld_cov', ///
 grpvar(Mn_LOD_EPA) rowvarlabels nonote control(1) feqtest onerow ///
                         vce(cluster caregiver_id_BL_num) ///
                          fix(dist_code) ///
                          savecsv("..\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_ChildCov.csv") replace

* Replace (SD) with [SD] to prevent Excel from interpreting (numbers) as negative
tempname fh fw
local csvfile "..\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_ChildCov.csv"
local csvtemp "..\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_ChildCov_temp.csv"
file open `fh' using "`csvfile'", read text
file open `fw' using "`csvtemp'", write text
file read `fh' line
while r(eof)==0 {
    local line = subinstr(`"`line'"', "(", "[", .)
    local line = subinstr(`"`line'"', ")", "]", .)
    file write `fw' `"`line'"' _n
    file read `fh' line
}
file close `fh'
file close `fw'
erase "`csvfile'"
copy "`csvtemp'" "`csvfile'"
erase "`csvtemp'"
// iebaltab `chld_cov', ///
//  grpvar(Mn_LOD_EPA) rowvarlabels nonote control(1) feqtest onerow ///
//                          vce(cluster caregiver_id_BL_num) ///
//                           fix(dist_code) ///
//                           savecsv("$master_loc\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_ChildCov.csv") replace

capture destring num_chld_hsehld_17, replace
local caregiver_cov "prim_caregiver_female_BL age_BL nature_employ_unemp nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_primary_BL high_education_secondary_BL high_education_SSS_higher_BL school_respondent_BL"
local hh_cov "main_lang_chld_comm_Eng_BL main_lang_chld_comm_Twi_BL main_lang_chld_comm_Sef_BL num_pple_hsehld num_chld_hsehld_17 own_house_BL own_land_BL recall_income_geq20k recall_income_geq10k recall_income_geq5k recall_income_bel5k"
iebaltab `hh_cov' `caregiver_cov' if focal_child_yn==1, ///
 grpvar(Mn_LOD_EPA) rowvarlabels nonote control(1) feqtest onerow ///
                         vce(cluster caregiver_id_BL_num) ///
                          fix(dist_code) ///
                          savecsv("..\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_Caregiver_Household_Covar.csv") replace
// iebaltab `hh_cov' `caregiver_cov' if focal_child_yn==1, ///
//  grpvar(Mn_LOD_EPA) rowvarlabels nonote control(1) feqtest onerow ///
//                          vce(cluster caregiver_id_BL_num) ///
//                           fix(dist_code) ///
//                           savecsv("$master_loc\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_Caregiver_Household_Covar.csv") replace
local csvfile "..\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_Caregiver_Household_Covar.csv"
local csvtemp "..\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_Caregiver_Household_Covar_temp.csv"
file open `fh' using "`csvfile'", read text
file open `fw' using "`csvtemp'", write text
file read `fh' line
while r(eof)==0 {
    local line = subinstr(`"`line'"', "(", "[", .)
    local line = subinstr(`"`line'"', ")", "]", .)
    file write `fw' `"`line'"' _n
    file read `fh' line
}
file close `fh'
file close `fw'
erase "`csvfile'"
copy "`csvtemp'" "`csvfile'"
erase "`csvtemp'"

/* iebaltab `caregiver_cov' if focal_child_yn==1, ///
 grpvar(Mn_LOD_EPA) rowvarlabels nonote control(1) feqtest onerow ///
                         vce(cluster caregiver_id_BL_num) ///
                          fix(dist_code) ///
                          savetex("..\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_CaregiverCov.tex") replace

// local hh_cov "main_lang_chld_comm_Eng_BL main_lang_chld_comm_Twi_BL main_lang_chld_comm_Sef_BL num_pple_hsehld num_chld_hsehld_17 own_house_BL own_land_BL annual_income_geq5k_BL"
local hh_cov "main_lang_chld_comm_Eng_BL main_lang_chld_comm_Twi_BL main_lang_chld_comm_Sef_BL num_pple_hsehld num_chld_hsehld_17 own_house_BL own_land_BL recall_income_geq20k recall_income_geq10k recall_income_geq5k recall_income_bel5k"
iebaltab `hh_cov'  if focal_child_yn==1, ///
 grpvar(Mn_LOD_EPA) rowvarlabels nonote control(1) feqtest onerow ///
                         vce(cluster caregiver_id_BL_num) ///
                          fix(dist_code) ///
                          savetex("$master_loc\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_HouseholdCov.tex") replace */

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
						  savecsv("..\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_WaterSafetyTreatment_Method.csv") replace
local csvfile "..\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_WaterSafetyTreatment_Method.csv"
local csvtemp "..\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_WaterSafetyTreatment_Method_temp.csv"
file open `fh' using "`csvfile'", read text
file open `fw' using "`csvtemp'", write text
file read `fh' line
while r(eof)==0 {
    local line = subinstr(`"`line'"', "(", "[", .)
    local line = subinstr(`"`line'"', ")", "]", .)
    file write `fw' `"`line'"' _n
    file read `fh' line
}
file close `fh'
file close `fw'
erase "`csvfile'"
copy "`csvtemp'" "`csvfile'"
erase "`csvtemp'"
						  // iebaltab `water_practices'  if focal_child_yn==1, ///
//  grpvar(Mn_LOD_EPA) rowvarlabels nonote control(1) feqtest onerow ///
//                          vce(cluster caregiver_id_BL_num) ///
//                           fix(dist_code) ///
//                           savexlsx("$master_loc\Output\Tables\Balance_Table\iebaltab_Mn_above_LOD_WaterSafetyTreatment.xlsx") replace

save "..\Processed Stata Dta\Test Results Merged with EL Child Development.dta", replace
