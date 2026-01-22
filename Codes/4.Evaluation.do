/* 4.Evaluation of Results */ 
use "$master_loc\Processed Stata Dta\Test Results Merged with EL Child Development.dta", clear 

**# some further processing 
tab sample_water_source, gen( sample_water_source_)
tab dist_code, gen( dist_code_)
replace annual_income_geq5k_BL = (lyear_income_leq5k == 0) if missing(annual_income_geq5k_BL) & !missing(lyear_income_leq5k)
gen child_female = child_male == 0
label var child_female "Child is female"
label var age_BL "Caregiver age"
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

**BL Messed-Up Child Development - recovered through PCA 
// 24-29 months
local GSED_24_29m "GSED_chld_run_well_BL GSED_chld_climb_furnitre_BL GSED_chld_kick_ball_BL GSED_chld_follw_direc_BL GSED_chld_corrc_nme_fam_mem_BL GSED_chld_ask_hlp_BL GSED_chd_try_things_themslves_BL GSED_chld_stack_objcts_BL GSED_chld_walk_uneven_surf_BL GSED_chld_comm_words_BL GSED_chld_say_more_wrds_BL GSED_chld_play_imitate_BL GSED_chld_wash_hands_BL"
foreach var of varlist `GSED_24_29m' {
	replace `var' = 0 if missing(`var') & age_month_child_BL<30
}
mca `GSED_24_29m' if age_month_child_BL<30, dim(1)
capture drop GSED_BL_age2429_mca1
predict GSED_BL_age2429_mca1 if e(sample) 

// 30-41 months
local GSED_30_41m "GSED_chld_unscrew_lid_BL GSED_chld_remove_item_BL GSED_chld_jump_both_feet_BL GSED_chld_speak_short_sent_BL GSED_chld_name_body_parts_BL GSED_chld_tell_name_BL GSED_chld_play_othr_chld_BL GSED_chld_away_parent_BL"
foreach var of varlist `GSED_30_41m' {
	replace `var' = 0 if missing(`var') & age_month_child_BL>=30&age_month_child_BL<=41
}
mca `GSED_30_41m' if age_month_child_BL>=30&age_month_child_BL<=41, dim(1)
predict GSED_BL_age3041m_mca1 if e(sample)

// 42-48 months
local GSED_42_48m "GSED_chld_sing_shrt_songs_BL GSED_chld_draw_stght_line_BL  GSED_chld_knw_quiet_BL GSED_chld_stnd_one_foot_BL GSED_chld_tell_story_corc_BL GSED_chld_tell_emotion_BL GSED_chld_tell_othr_emotion_BL GSED_chld_name_color_BL GSED_chld_count_five_BL GSED_chld_fast_button_BL GSED_chld_dress_self_BL GSED_chld_say_othr_like_dis_BL GSED_chld_ask_more_BL GSED_chld_count_ten_BL GSED_chld_write_letters_BL GSED_chld_write_name_BL"
foreach var of varlist `GSED_42_48m' {
	replace `var' = 0 if missing(`var') & age_month_child_BL>=42&age_month_child_BL<=48
}
mca `GSED_42_48m' if age_month_child_BL>=42&age_month_child_BL<=48, dim(1)
predict GSED_BL_age4248m_mca1 if e(sample)

//pooling them together 
gen age_group = 1 if age_month_child_BL<30
replace  age_group = 2 if age_month_child_BL>=30&age_month_child_BL<=41
replace age_group = 3 if age_month_child_BL>=42&age_month_child_BL<=48

gen age_group_24_29m_BL = age_month_child_BL<30
gen age_group_30_41m_BL = age_month_child_BL>=30&age_month_child_BL<=41
gen age_group_42_48m_BL = age_month_child_BL>=42&age_month_child_BL<=48

capture drop GSED_BL_mca1
gen GSED_BL_mca1 = GSED_BL_age2429_mca1 
replace GSED_BL_mca1 = GSED_BL_age3041m_mca1 if missing(GSED_BL_mca1)
replace GSED_BL_mca1 = GSED_BL_age4248m_mca1 if missing(GSED_BL_mca1)
egen GSED_BL_mca1_z = std(GSED_BL_mca1), by(age_group)

gen GSED_z_mca_24_29m_BL = GSED_BL_mca1_z * age_group_24_29m_BL
gen GSED_z_mca_30_41m_BL = GSED_BL_mca1_z * age_group_30_41m_BL
gen GSED_z_mca_42_48m_BL = GSED_BL_mca1_z * age_group_42_48m_BL


**# Evaluation 
reghdfe  z_irt_all_30_48m any_limit_Pb_higher any_limit_Mn_higher any_limit_Fe_higher any_limit_Al_higher age_chld_months_EL treatment Batch, vce(cluster new_village_id ) absorb( dist_code )
	est store Pooled_any_limit
reghdfe  z_irt_all_30_48m WHO_EPA_Any_higher treatment Batch, vce(cluster new_village_id ) absorb( dist_code )
	est store AnyLimit_Higher
	
reghdfe z_irt_all_30_48m Pb Zn Mn Fe Cr Al Cu age_chld_months_EL treatment Batch, vce(cluster new_village_id ) absorb( dist_code )
	est store Pooled_Concentration
	
esttab AnyLimit_Higher Pooled_any_limit Pooled_Concentration using "$master_loc\Output\Tables\Heavy_Metal_ChildDevelopment_Pooled.tex",  ///
    stats(N r2, labels("N (Children)" "R-squared")) ///
    b se star(* 0.1 ** 0.05 *** 0.01)  /// 
	mtitle("Pooled" "Disaggregated Binary" "Continuous Concentration" ) /// 
	replace nonote label drop(age_chld_months_EL treatment Batch)

local cov "age_chld_months_EL treatment Batch i.sample_water_source"
local fe "dist_code sch_id"
local metals "Pb Zn Mn Fe Cr Al Cu"
local model ""
local keep_var ""
local mtitle 
foreach var of varlist `metals' {
	reghdfe z_irt_all_30_48m `var' `var'_sq `cov', vce(cluster new_village_id) absorb( dist_code )
	est store `var'_conc_sq
		quietly sum `var' if treatment==0
			local C_mean = trim("`: display %5.2f r(mean)'")
			local C_sd   = trim("`: display %5.2f r(sd)'")
			quietly estadd local C_mean_sd = "`C_mean' (`C_sd')" 
		quietly sum `var' if treatment==1
			local T_mean = trim("`: display %5.2f r(mean)'")
			local T_sd   = trim("`: display %5.2f r(sd)'")
			quietly estadd local T_mean_sd = "`T_mean' (`T_sd')" 
		est store `var'_conc_sq
	local model `model' `var'_conc_sq
	local keep_var `keep_var' `var' `var'_sq
    local mtitle `"`mtitle' "GSED Z Score""'
}
esttab `model' using "$master_loc\Output\Tables\HH_Metals_and_ChildDevelopment.tex",  ///
    stats(C_mean_sd T_mean_sd N r2, labels("Control: Mean Conc. (SD)" "Treatment: Mean Conc. (SD)" "N (Children)" "R-squared")) ///
    b se star(* 0.1 ** 0.05 *** 0.01) keep(`keep_var') /// 
	mtitle(`mtitle') /// 
	replace nonote label 

local cov "age_chld_months_EL treatment Batch i.sample_water_source"
local fe "dist_code sch_id"
local metals "Pb Mn Fe Al"
local model ""
local keep_var ""
local mtitle 

foreach var of varlist `metals' {
	reghdfe z_irt_all_30_48m any_limit_`var'_higher `cov', vce(cluster new_village_id) absorb( dist_code )
	est store `var'_binary
		quietly sum any_limit_`var'_higher if treatment==0
			local C_mean = trim("`: display %5.2f r(mean)'")
			local C_sd   = trim("`: display %5.2f r(sd)'")
			quietly estadd local C_mean_sd = "`C_mean' (`C_sd')" 
		quietly sum any_limit_`var'_higher if treatment==1
			local T_mean = trim("`: display %5.2f r(mean)'")
			local T_sd   = trim("`: display %5.2f r(sd)'")
			quietly estadd local T_mean_sd = "`T_mean' (`T_sd')" 
		est store `var'_binary
	local model `model' `var'_binary
	local keep_var `keep_var' any_limit_`var'_higher
    local mtitle `"`mtitle' "GSED Z Score""'

}
esttab `model' using "$master_loc\Output\Tables\HH_Metals_AnyLimit_and_ChildDevelopment.tex",  ///
    stats(C_mean_sd T_mean_sd N r2, labels("Control: Exceeding Limit Mean (SD)" "Treatment: Exceeding Limit Mean (SD)" "N (Children)" "R-squared")) ///
    b se star(* 0.1 ** 0.05 *** 0.01) keep(`keep_var') /// 
	mtitle(`mtitle') /// 
	replace nonote label 	
	
**Include School Water Sources	
local cov "age_chld_months_EL treatment Batch i.sample_water_source"
local fe "dist_code sch_id"
local metals "Pb Zn Mn Fe Cr Al Cu"
local model ""
local keep_var ""
local mtitle 

foreach var of varlist `metals' {
	reghdfe z_irt_all_30_48m `var' school_`var'_max `cov' if  foc_child_in_sch_study==1, vce(cluster new_village_id) absorb( dist_code )
	est store `var'_conc
		quietly sum `var' if treatment==0
			local C_mean = trim("`: display %5.2f r(mean)'")
			local C_sd   = trim("`: display %5.2f r(sd)'")
			quietly estadd local C_mean_sd = "`C_mean' (`C_sd')" 
		quietly sum `var' if treatment==1
			local T_mean = trim("`: display %5.2f r(mean)'")
			local T_sd   = trim("`: display %5.2f r(sd)'")
			quietly estadd local T_mean_sd = "`T_mean' (`T_sd')" 
		est store `var'_conc
	local model `model' `var'_conc
    local mtitle `"`mtitle' "GSED Z Score""'
	local keep_var `keep_var' `var' school_`var'_max
}
esttab `model' using "$master_loc\Output\Tables\HH_and_School_Metals_Concentration_and_ChildDevelopment.tex",  ///
    stats(C_mean_sd T_mean_sd N r2, labels("Control: Mean Conc. (SD)" "Treatment: Mean Conc. (SD)" "N (Children)" "R-squared")) ///
    b se star(* 0.1 ** 0.05 *** 0.01) keep(`keep_var') /// 
	mtitle("`mtitle'") /// 
	replace nonote label 	

local cov "age_chld_months_EL treatment Batch i.sample_water_source"
local fe "dist_code sch_id"
local metals "Pb Zn Mn Fe Cr Al Cu"
local model ""
local keep_var ""
local mtitle 
foreach var of varlist `metals' {
	reghdfe main_drink_wtr_safe `var' `cov', vce(cluster new_village_id) absorb( dist_code )
	est store `var'_conc_safe
		quietly sum `var' if treatment==0
			local C_mean = trim("`: display %5.2f r(mean)'")
			local C_sd   = trim("`: display %5.2f r(sd)'")
			quietly estadd local C_mean_sd = "`C_mean' (`C_sd')" 
		quietly sum `var' if treatment==1
			local T_mean = trim("`: display %5.2f r(mean)'")
			local T_sd   = trim("`: display %5.2f r(sd)'")
			quietly estadd local T_mean_sd = "`T_mean' (`T_sd')" 
		est store `var'_conc_safe
	local model `model' `var'_conc_safe
	local keep_var `keep_var' `var'
    local mtitle `"`mtitle' "Safe to drink""'
}
macro list _all 
esttab `model' using "$master_loc\Output\Tables\Metals_and_PerceivedSafety.tex",  ///
    stats(C_mean_sd T_mean_sd N r2, labels("Control: Mean Conc. (SD)" "Treatment: Mean Conc. (SD)" "N (Children)" "R-squared")) ///
    b se star(* 0.1 ** 0.05 *** 0.01) keep(`keep_var') /// 
	mtitle(`mtitle') /// 
	replace nonote label 	
	
	
	
save "$master_loc\Processed Stata Dta\Test Results Merged with EL Child Development.dta", replace 
	