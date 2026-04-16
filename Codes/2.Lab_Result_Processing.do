/* Merge The Lab Results with the Main Dataset */

cd "$master_loc"
import excel "..\Original Data\100925_MetalsData_GhanaWaterSampling_xfl - 10102025..xlsx", sheet("To_be_Merged_Stata") firstrow clear

**Treat the below the detection limit as 0
foreach var of varlist Pb Hg Zn Cd Mn Fe Cr Al Cu {
	replace `var' = "0" if strpos(`var', "<")!=0
	destring `var', replace
}
sum Pb Hg Zn Cd Mn Fe Cr Al Cu
rename SAMPLEID sample_ID

**# Adjust Field Entries Typos
replace sample_ID = "016_05_01" if sample_ID == "061_05_01"
replace sample_ID = "044_01_01" if sample_ID == "004_01_01"
replace sample_ID = "083_01_01" if sample_ID == "038_01_01"
drop if sample_ID == "ACID DUPLICATE"


merge 1:1 sample_ID using "../Original Data/Sample_ID_Log.dta"
assert _merge==3 //-->all matched
drop _merge
egen sachet_yn = rowmax( vendor_sachet_yn school_sachet_yn)


**# WHO Threshold
local WHO_metals Pb Hg Cd Mn Cr Cu
local WHO_threshold 10 6 3 80 50 2000
local i = 1
foreach var of varlist `WHO_metals' {
	local threshold: word `i' of `WHO_threshold'
	gen WHO_`var'_higher = `var' > `threshold'
	local i = `i' + 1
}
egen WHO_Any_higher = rowmax(WHO_Pb_higher WHO_Hg_higher WHO_Cd_higher WHO_Mn_higher WHO_Cr_higher WHO_Cu_higher)


**# EPA Threshold

local EPA_prim_metals Pb Hg Cd Cr Cu
local EPA_prim_threshold 10 2 5 100 1300
local i = 1
foreach var of varlist `EPA_prim_metals' {
	local threshold: word `i' of `EPA_prim_threshold'
	gen EPA_prim_`var'_higher = `var' > `threshold'
	local i = `i' + 1
}

local EPA_sec_metals Zn Mn Fe Al Cu
local EPA_sec_threshold 5000 50 300 200 1000
local i = 1
 foreach var of varlist `EPA_sec_metals' {
	local threshold: word `i' of `EPA_sec_threshold'
	gen EPA_sec_`var'_higher = `var' > `threshold'
	local i = `i' + 1
}

gen EPA_PrimSec_Pb_higher = EPA_prim_Pb_higher
gen EPA_PrimSec_Hg_higher = EPA_prim_Hg_higher

egen EPA_Prim_Any_higher = rowmax(EPA_prim_Pb_higher EPA_prim_Hg_higher EPA_prim_Cd_higher EPA_prim_Cr_higher EPA_prim_Cu_higher)
egen EPA_Sec_Any_higher = rowmax(EPA_sec_Zn_higher EPA_sec_Mn_higher EPA_sec_Fe_higher EPA_sec_Al_higher EPA_sec_Cu_higher)
egen EPA_PrimSec_higher = rowmax(EPA_Prim_Any_higher EPA_Sec_Any_higher)
egen WHO_EPA_Any_higher = rowmax(EPA_PrimSec_higher WHO_Any_higher)


**# WHO & EPA: Combined (Any Higher)
local metals Pb Hg Cd Cr Cu Mn Zn Fe Al
foreach metal in `metals' {
    // Build a list of _higher variables that match this metal
    local relevant_vars
    foreach var in EPA_prim_`metal'_higher EPA_sec_`metal'_higher WHO_`metal'_higher {
        // Check if the variable exists in the dataset
        capture confirm variable `var'
        if !_rc {
            local relevant_vars `relevant_vars' `var'
        }
    }
    // If any relevant variables were found, generate the rowmax
    if "`relevant_vars'" != "" {
        egen any_limit_`metal'_higher = rowmax(`relevant_vars')
    }
}

local metals Pb Hg Cd Cr Cu Mn Zn Fe Al
foreach metal in `metals' {
    // Find all *_<metal>_higher variables
    ds *_`metal'_higher, has(type numeric)
    local matched_vars `r(varlist)'
    // Loop over the matched vars and label them
    foreach var of local matched_vars {
        label variable `var' "`metal'"
    }
}

label variable WHO_Any_higher "Any Metals: Exceed WHO Limit"
label variable EPA_Prim_Any_higher "Any Metals: Exceed EPA Primary Limit"
label variable EPA_Sec_Any_higher "Any Metals: Exceed EPA Secondary Limit"
label variable EPA_PrimSec_higher "Any Metals: Exceed EPA Primary or Secondary Limit"
label variable WHO_EPA_Any_higher "Any Metals: Exceed EPA or WHO Limit"

gen sample_water_source = substr(sample_ID,5,2)
destring sample_water_source, replace
replace sample_water_source = 7 if missing(sample_water_source) //-->these are sachet households
label define water_source_ID 1 "Borehole" 2 "River" 3 "Piped In" 4 "Piped Out" 5 "Well" 6 "Rainwater" 7 "Sachet" 8 "Public tap", replace
label values sample_water_source water_source_ID

capture drop sample_water_source_brief
recode sample_water_source (1 = 1 "Borehole") (2 = 2 "River") (3 4 = 3 "Piped Water") (5 = 4 "Well") (7 = 5 "Sachet"), gen(sample_water_source_brief) label(water_source_ID_brief) test




**# Summary Statistics
label variable hh_sample_yn "Non-Sachet Household"
label variable river_sample_yn "River Sample"
label variable sachet_yn "Sachet Water Sample"

local metals Pb Hg Cd Cr Cu Mn Zn Fe Al
foreach var of varlist `metals' {
	label var `var' "`var' ({&mu}g/L)"
}
levelsof sample_water_source_brief, local(src)
label define waterlbl, replace
foreach s of local src {

    * Count Mn observations for this source
    quietly count if sample_water_source_brief == `s' & river_duplicates_yn==0
    local N = r(N)

    * Get the original name for this category
    * (you can edit these names if needed)
    if `s' == 1 local name "Borehole"
    if `s' == 2 local name "River"
    if `s' == 3 local name "Piped Water"
    if `s' == 4 local name "Well"
    if `s' == 5 local name "Sachet"
    if `s' == 6 local name "Pooled"

    * Add to label definition
    label define waterlbl `s' "`name' (N = `N')", add
}
label values sample_water_source_brief waterlbl

	**# IQR Plot of Mn Concentrations by source
capture drop sample_water_source_plot
recode sample_water_source_brief (2 = 1) (5 = 2) (1 = 3) (3 = 4) (4 = 5), gen(sample_water_source_plot)
label define wtr_plot 1 "River (N=27)" 2 "Sachet (N = 15)" 3 "Borehole (N=69)" 5 "Well (N=8)" 4  "Piped Water (N=51)", replace
label value sample_water_source_plot wtr_plot
**With Outside Values
graph hbox Mn if river_duplicates_yn==0 & Mn<650, ///
    over(sample_water_source_plot) ///
	/// Add the USEPA & WHO Threshold ///
		yline(50,  lpattern(shortdash) lcolor(red)) ///
		yline(80,  lpattern(dash) lcolor(purple)) ///
		text(30 102  "USEPA", size(small) color(red) ) ///
		text(95 102  "WHO", size(small) color(purple)) ///
    graphregion(color(white)) ///
    plotregion(style(none)) ///
	/// adjust the looking of the box ///
		box(1, fcolor(gs12) lcolor(gs8)) ///
		box(2, fcolor(gs12) lcolor(gs8)) ///
		box(3, fcolor(gs12) lcolor(gs8)) ///
		box(4, fcolor(gs12) lcolor(gs8)) ///
		box(5, fcolor(gs12) lcolor(gs8)) ///
		box(6, fcolor(gs12) lcolor(gs8)) ///
	ylabel(0 "Below LOD" 50 80 100 200 300 400 , labsize(medsmall)) ///
    ytitle( "Mn ({&mu}g/L) ", size(medsmall)) ///
	marker(1, mfcolor(gs10) mlcolor(gs10) ) ///
	name(Mn_hbox, replace)

graph export "../Output/Figures/Fig2_IQR_Mn_by_Sources.pdf", ///
	name(Mn_hbox) as(pdf) replace
graph export "../Output/Figures/Fig2_IQR_Mn_by_Sources.svg", ///
	name(Mn_hbox) as(svg) replace


* RTF-compatible labels (no LaTeX commands)
label variable WHO_Any_higher "Any Metals: Exceed WHO Limit"
label variable EPA_Prim_Any_higher "  Exceed EPA Primary Limit"
label variable EPA_Sec_Any_higher "  Exceed EPA Secondary Limit"
label variable EPA_PrimSec_higher "  Exceed EPA Primary or Secondary Limit"
label variable WHO_EPA_Any_higher "  Exceed EPA or WHO Limit"

label variable any_limit_Pb_higher "Exceed EPA or WHO Limit: Pb"
local metals Pb Hg Cd Cr Cu Mn Zn Fe Al
foreach var of varlist `metals' {
	label var `var' "`var' (ug/L)"
}

	**Main Table: Distribution by Sample Source for ALL metals
local limit "WHO_Any_higher EPA_Prim_Any_higher EPA_Sec_Any_higher any_limit_Pb_higher any_limit_Hg_higher any_limit_Cd_higher any_limit_Cr_higher any_limit_Cu_higher any_limit_Mn_higher any_limit_Zn_higher any_limit_Fe_higher any_limit_Al_higher Pb Hg Zn Cd Mn Fe Cr Al Cu "
	qui eststo all: estpost sum `limit' if river_duplicates_yn==0
	qui eststo borehole: estpost sum `limit' if sample_water_source_brief == 1
	qui eststo river: estpost sum `limit' if sample_water_source_brief == 2 & river_duplicates_yn==0
	qui eststo pipe: estpost sum `limit' if sample_water_source_brief == 3
	qui eststo well: estpost sum `limit' if sample_water_source_brief==4
	qui eststo sachet: estpost sum `limit' if sample_water_source_brief==5
esttab all river sachet borehole  pipe well  using "../Output/Tables/Table1_Heavy_Metals_by_Sample_Water_Source.csv", label ///
	star(* 0.10 ** 0.05 *** 0.01)	///
	replace main(mean %6.2f) aux(sd) mtitle("Total" "River" "Sachet" "Borehole" "Piped Water" "Well") nonote

	* Post-process CSV: replace "0.00" with "Below LOD" only for metal rows
	tempname fh3 fw3
	local csvfile "../Output/Tables/Table1_Heavy_Metals_by_Sample_Water_Source.csv"
	local csvtemp "../Output/Tables/Table1_Heavy_Metals_by_Sample_Water_Source_temp.csv"
	file open `fh3' using "`csvfile'", read text
	file open `fw3' using "`csvtemp'", write text
	local prev_metal = 0
	file read `fh3' line
	while r(eof)==0 {
	    * Check if this line is a metal concentration row
	    local is_metal = 0
	    if strpos(`"`line'"', "(ug/L)") > 0 {
	        local is_metal = 1
	    }
	    * Replace "0.00" with "Below LOD" on metal mean rows
	    if `is_metal' {
	        local line = subinstr(`"`line'"', "0.00", "< LOD", .)
	    }
	    * Replace "(0)" on SD rows only if previous row was a metal row
	    if `prev_metal' {
	        local line = subinstr(`"`line'"', "(0)", "", .)
	    }
	    local prev_metal = `is_metal'
	    file write `fw3' `"`line'"' _n
	    file read `fh3' line
	}
	file close `fh3'
	file close `fw3'
	erase "`csvfile'"
	copy "`csvtemp'" "`csvfile'"
	erase "`csvtemp'"


save "../Processed Stata dta/Lab Test Results.dta", replace
export delimited GPS_lat GPS_long Mn Batch river_sample_yn school_sample_yn hh_sample_yn vendor_sachet_yn using "../Output/Feed_into_GEE_Test_Results_with_GPS.csv", nolab replace


	**Appendix Table: Mn statistics by Sample Source
/* local stats   min p25 p50 p75 max mean count
quietly estpost tabstat Mn if river_duplicates_yn==0, statistics(`stats')

matrix M = J(7, 1, .)

local r = 1
foreach s of local stats {
    matrix M[`r',1] = e(`s')[1,1]
    local ++r
}

local src_codes  1 2 3 4 5
local src_names  Borehole River PipedWater Well Sachet

local i = 1
foreach code of local src_codes {
    local name : word `i' of `src_names'
    quietly estpost tabstat Mn if sample_water_source_brief == `code' & river_duplicates_yn==0, statistics(`stats')
    matrix tmp = J(7, 1, .)
    local r = 1
    foreach s of local stats {
        matrix tmp[`r',1] = e(`s')[1,1]
        local ++r
    }
    matrix colnames tmp = `name'
    matrix M = M, tmp

    local ++i
}
* Rownames (these are what will show up in the table)
matrix rownames M =  "Min" "25th percentile" "Median" "75th percentile" "Max" "Mean" "N"

* Colnames (with spaces allowed)
matrix colnames M = "Total" "Borehole" "River" "Piped Water" "Well" "Sachet"

esttab matrix(M, fmt(2)) using "../Output/Tables/Mn_Distributions_by_Sample_Water_Source.csv", ///
    replace nomtitles

* Post-process CSV: replace "0.00" with "Below LOD"
tempname fh fw
local csvfile "../Output/Tables/Mn_Distributions_by_Sample_Water_Source.csv"
local csvtemp "../Output/Tables/Mn_Distributions_by_Sample_Water_Source_temp.csv"
file open `fh' using "`csvfile'", read text
file open `fw' using "`csvtemp'", write text
file read `fh' line
while r(eof)==0 {
    local line = subinstr(`"`line'"', "0.00", "Below LOD", .)
    file write `fw' `"`line'"' _n
    file read `fh' line
}
file close `fh'
file close `fw'
erase "`csvfile'"
copy "`csvtemp'" "`csvfile'"
erase "`csvtemp'" */

// esttab  matrix(M,transpose) using "..\Output\Tables\Mn_Distributions_by_Sample_Water_Source.tex" , ///
// 	coeflabels(mean "Mean" min  "Min" p25  "25th percentile" p50  "Median"  p75  "75th percentile" max  "Max" count "N") ///
// 	substitute("PipedWater" "Piped Water" " 0" "Below LOD" "Pooled" "Total" ) ///
// 	nomtitles replace  booktabs ///

	**Appendix Table: Distribution by Sample Ownership for ALL metals

/* local limit "WHO_Any_higher EPA_Prim_Any_higher EPA_Sec_Any_higher any_limit_Pb_higher any_limit_Hg_higher any_limit_Cd_higher any_limit_Cr_higher any_limit_Cu_higher any_limit_Mn_higher any_limit_Zn_higher any_limit_Fe_higher any_limit_Al_higher Pb Hg Zn Cd Mn Fe Cr Al Cu "
	qui eststo all: estpost sum `limit' if river_duplicates_yn==0
	qui eststo hh: estpost sum `limit' if hh_sample_yn == 1
	qui eststo river: estpost sum `limit' if river_sample_yn == 1 & river_duplicates_yn==0
	qui eststo school: estpost sum `limit' if school_sample_yn == 1
	qui eststo vsachet: estpost sum `limit' if vendor_sachet_yn==1
	esttab all hh river school vsachet using "..\Output\Tables\Heavy_Metals_by_Sample_Water_Ownership.csv", label ///
	star(* 0.10 ** 0.05 *** 0.01)	///
	replace main(mean %6.2f) aux(sd) onecell mtitle("Total" "Non-Sachet Household" "River Samples" "School Samples" "Sachet from Vendors")

	* Post-process CSV: replace "0.00 (0)" with "Below LOD"
	tempname fh2 fw2
	local csvfile "..\Output\Tables\Heavy_Metals_by_Sample_Water_Ownership.csv"
	local csvtemp "..\Output\Tables\Heavy_Metals_by_Sample_Water_Ownership_temp.csv"
	file open `fh2' using "`csvfile'", read text
	file open `fw2' using "`csvtemp'", write text
	file read `fh2' line
	while r(eof)==0 {
	    local line = subinstr(`"`line'"', "0.00 (0)", "Below LOD", .)
	    file write `fw2' `"`line'"' _n
	    file read `fh2' line
	}
	file close `fh2'
	file close `fw2'
	erase "`csvfile'"
	copy "`csvtemp'" "`csvfile'"
	erase "`csvtemp'" */




**# Merge with the Caregiver Survey

	**# Sachet Data Processing
preserve
collapse (mean) Pb Hg Zn Cd Mn Fe Cr Al Cu (max) Batch  if vendor_sachet_yn==1 | school_sachet_yn==1, by(village_id_BL)
local metal Pb Hg Zn Cd Mn Fe Cr Al Cu
foreach var of varlist `metal'{
	label var `var' "Village Average Sachet Concentration in `var'"
	rename `var' sachet_`var'_mean
}
rename village_id_BL new_village_id
rename Batch Batch_Sachet
tempfile village_sachet
save `village_sachet', replace
restore

	**# River Data Processing
preserve
collapse (mean) Pb Hg Zn Cd Mn Fe Cr Al Cu if river_sample_yn==1, by(village_id_BL)
local metal Pb Hg Zn Cd Mn Fe Cr Al Cu
foreach var of varlist `metal'{
	label var `var' "River Average Sachet Concentration in `var'"
	rename `var' river_`var'_mean
}
rename village_id_BL new_village_id
tempfile river_test
save `river_test', replace
restore

	**# School Data Processing
preserve
local collapse_var
local metal Pb Hg Zn Cd Mn Fe Cr Al Cu
foreach var of varlist `metal'{
	egen school_`var'_mean = mean(`var') if school_sample_yn==1 , by(village_id_BL)
	egen school_`var'_min = min(`var') if school_sample_yn==1 , by(village_id_BL)
	egen school_`var'_max = max(`var') if school_sample_yn==1 , by(village_id_BL)
	label var school_`var'_mean "School Average Water Concentration in `var'"
	label var school_`var'_min "School Minimum Water Concentration in `var'"
	label var school_`var'_max "School Maximum Water Concentration in `var'"
	local collapse_var `collapse_var' school_`var'_mean  school_`var'_min school_`var'_max
}
collapse (max) `collapse_var' if school_sample_yn==1, by(village_id_BL)
local metal Pb Hg Zn Cd Mn Fe Cr Al Cu
foreach var of local metal {
	label var school_`var'_mean "School Average Water Concentration in `var'"
	label var school_`var'_min "School Minimum Water Concentration in `var'"
	label var school_`var'_max "School Maximum Water Concentration in `var'"
}
rename village_id_BL new_village_id
tempfile school_test
save `school_test', replace
restore


keep if hh_sample_yn == 1

rename HH_full_ID caregiver_id_EL
merge 1:m caregiver_id_EL using "../Original Data/Parent_Survey_isid_ChildCode.dta", ///
	keepusing( ///
		enumerator_id caregiver_id sch_id new_village_id cgver_id_el child_code focal_child_yn child_male child_male_BL age_chld_months_EL ///
		theta_all_30_48m theta_motor_30_48m theta_language_30_48m theta_socio_30_48m theta_cognitive_30_48m theta_adaptive_30_48m ///
		caregiver_id_BL prim_caregiver_female_BL age_BL ///
		nature_employ_unemp nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL ///
		high_education_primary_BL high_education_secondary_BL high_education_SSS_higher_BL ///
		num_pple_hsehld_BL num_chld_hsehld_17 num_chld_hsehld_5_BL ///
		own_house_BL own_land_BL own_othr_hse_BL own_agric_land_BL ///
		hme_made_toys_yn_BL toys_shop_yn_BL hsehld_objts_yn_BL objts_ousdie_yn_BL draw_write_materials_yn_BL puzzle_yn_BL ///
		stories_yn stories_yn_BL counted_yn counted_yn_BL played_yn played_yn_BL taken_chld_work_yn taken_chld_work_yn_BL ///
		who_engage_acti_mother_BL who_engage_acti_father_BL who_engage_acti_AnoRel_BL ///
		annual_income_geq5k_BL lyear_income_leq5k lyear_income_geq10k lyear_income_geq15k lyear_income_geq20k ///
		main_lang_chld_comm_Eng_BL main_lang_chld_comm_Twi_BL main_lang_chld_comm_Sef_BL ///
		school_respondent_BL lost_in_EL dist_code treatment sch_id ///
		main_drink_wtr_safe treat_drink_water_yn means_treat_cook_1 means_treat_cook_2 means_treat_cook_3 means_treat_cook_4 ///
		switch_drink_wtr_dry main_drink_wtr_dry_safe ///
	) gen(merge_caregiver)
drop if lost_in_EL!=0
merge m:1 new_village_id using `river_test', gen(merge_river)
distinct new_village_id if merge_river==1
assert `r(ndistinct)'==1 //--> there is one village where river sampling is not possible
merge m:1 new_village_id using `village_sachet', gen(merge_sachet)
assert merge_sachet == 3
merge m:1 new_village_id using `school_test', gen(merge_school)
assert merge_school == 3


**# Standardized the Child Development Score
foreach s in all_30_48m motor_30_48m language_30_48m socio_30_48m cognitive_30_48m adaptive_30_48m{
	capture drop mean_irt_`s'_t
	capture drop mean_irt_`s'
	capture drop sd_irt_`s'_t
	capture drop sd_irt_`s'
	capture drop z_irt_`s'

	sum theta_`s'
	gen mean_irt_`s'_t=r(mean)
	gen sd_irt_`s'_t =r(sd)

	egen mean_irt_`s' = max(mean_irt_`s'_t)
	egen sd_irt_`s' = max(sd_irt_`s'_t)

	capture drop sd_irt_`s'_t mean_irt_`s'_t
	sum mean_irt_`s' sd_irt_`s'

	gen z_irt_`s'=(theta_`s'-mean_irt_`s')/sd_irt_`s'
 }


**sachet drinking households: we didnt have water sample for them, so we will impute the average sachet water concentration within their village
**3 caregivers are missing in the water sampling: 100110081P2 , 100151011P2 , and 110025106P1
**among them 100110081P2 report to have sachet water as their primary drinking water
**100151011P2 , and 110025106P1 report to drink borehole water

replace sample_water_source = 7 if missing(sample_water_source) & caregiver_id_EL!="100151011P2" & caregiver_id_EL != "110025106P1" & caregiver_id_EL!="100110081P2"

local metals Pb Hg Zn Cd Mn Fe Cr Al Cu
foreach var of varlist `metals' {
	replace `var' = sachet_`var'_mean if missing(`var') &  sample_water_source == 7 //<-- replace village mean sachet concentration for those sachet households
}
replace Batch = Batch_Sachet if missing(Batch) &  sample_water_source == 7

foreach var of varlist `metals' {
	replace `var' = sachet_`var'_mean if missing(`var') & caregiver_id_EL=="100110081P2"
}
replace Batch = Batch_Sachet if missing(Batch) & caregiver_id_EL=="100110081P2"



**For those two caregivers, replace them as the borehole average within the community
**100151011P2 , and 110025106P1 report to drink borehole water
local metals Pb Hg Cd Cr Cu Mn Zn Fe Al
foreach var of varlist `metals' {
	capture drop `var'_borehole_mean_t `var'_borehole_mean
	egen `var'_borehole_mean_t = mean(`var') if sample_water_source==1, by(new_village_id)
	egen `var'_borehole_mean = max(`var'_borehole_mean_t), by(new_village_id)
	replace `var' = `var'_borehole_mean if caregiver_id_EL=="100151011P2" | caregiver_id_EL=="110025106P1"
	drop `var'_borehole_mean_t `var'_borehole_mean
}
gen lost_in_watersample = caregiver_id_EL=="100151011P2" | caregiver_id_EL=="110025106P1" | caregiver_id_EL=="100110081P2"
assert new_village_id == "50D" if caregiver_id_EL=="100151011P2" | caregiver_id_EL=="110025106P1"
assert Batch==1 if new_village_id=="50D" & sample_water_source==1 //-->all borehole sample are in batch 1 for village_id=="50D"
replace Batch = 1 if missing(Batch)

**# WHO Threshold
local WHO_metals Pb Hg Cd Mn Cr Cu
local WHO_threshold 10 6 3 80 50 2000
local i = 1
foreach var of varlist `WHO_metals' {
	capture drop WHO_`var'_higher
	local threshold: word `i' of `WHO_threshold'
	gen WHO_`var'_higher = `var' > `threshold'
	local i = `i' + 1
}
capture drop WHO_Any_higher
egen WHO_Any_higher = rowmax(WHO_Pb_higher WHO_Hg_higher WHO_Cd_higher WHO_Mn_higher WHO_Cr_higher WHO_Cu_higher)


**# EPA Threshold

local EPA_prim_metals Pb Hg Cd Cr Cu
local EPA_prim_threshold 10 2 5 100 1300
local i = 1
foreach var of varlist `EPA_prim_metals' {
	capture drop EPA_prim_`var'_higher
	local threshold: word `i' of `EPA_prim_threshold'
	gen EPA_prim_`var'_higher = `var' > `threshold'
	local i = `i' + 1
}

local EPA_sec_metals Zn Mn Fe Al Cu
local EPA_sec_threshold 5000 50 300 200 1000
local i = 1
 foreach var of varlist `EPA_sec_metals' {
	capture drop EPA_sec_`var'_higher
	local threshold: word `i' of `EPA_sec_threshold'
	gen EPA_sec_`var'_higher = `var' > `threshold'
	local i = `i' + 1
}
capture drop EPA_PrimSec_Pb_higher EPA_PrimSec_Hg_higher EPA_Prim_Any_higher EPA_Sec_Any_higher EPA_PrimSec_higher WHO_EPA_Any_higher
gen EPA_PrimSec_Pb_higher = EPA_prim_Pb_higher
gen EPA_PrimSec_Hg_higher = EPA_prim_Hg_higher

egen EPA_Prim_Any_higher = rowmax(EPA_prim_Pb_higher EPA_prim_Hg_higher EPA_prim_Cd_higher EPA_prim_Cr_higher EPA_prim_Cu_higher)
egen EPA_Sec_Any_higher = rowmax(EPA_sec_Zn_higher EPA_sec_Mn_higher EPA_sec_Fe_higher EPA_sec_Al_higher EPA_sec_Cu_higher)
egen EPA_PrimSec_higher = rowmax(EPA_Prim_Any_higher EPA_Sec_Any_higher)
egen WHO_EPA_Any_higher = rowmax(EPA_PrimSec_higher WHO_Any_higher)


**# WHO & EPA: Combined (Any Higher)
local metals Pb Hg Cd Cr Cu Mn Zn Fe Al
foreach metal in `metals' {
    // Build a list of _higher variables that match this metal
    local relevant_vars
    foreach var in EPA_prim_`metal'_higher EPA_sec_`metal'_higher WHO_`metal'_higher {
        // Check if the variable exists in the dataset
        capture confirm variable `var'
        if !_rc {
            local relevant_vars `relevant_vars' `var'
        }
    }
    // If any relevant variables were found, generate the rowmax
    if "`relevant_vars'" != "" {
		capture drop any_limit_`metal'_higher
        egen any_limit_`metal'_higher = rowmax(`relevant_vars')
    }
}

local metals Pb Hg Cd Cr Cu Mn Zn Fe Al
foreach metal in `metals' {
    // Find all *_<metal>_higher variables
    ds *_`metal'_higher, has(type numeric)
    local matched_vars `r(varlist)'
    // Loop over the matched vars and label them
    foreach var of local matched_vars {
        label variable `var' "`metal'"
    }
}

label variable WHO_Any_higher "Any Metals: Exceed WHO Limit"
label variable EPA_Prim_Any_higher "Any Metals: Exceed EPA Primary Limit"
label variable EPA_Sec_Any_higher "Any Metals: Exceed EPA Secondary Limit"
label variable EPA_PrimSec_higher "Any Metals: Exceed EPA Primary or Secondary Limit"
label variable WHO_EPA_Any_higher "Any Metals: Exceed EPA or WHO Limit"
label variable EPA_sec_Mn_higher "EPA: Mn above 50 {&mu}g/L"
label variable WHO_Mn_higher "WHO: Mn above 80 {&mu}g/L"

local metals Pb Hg Cd Cr Cu Mn Zn Fe Al
foreach var of varlist `metals' {
	label var `var' "`var' ({&mu}g/L)"
	gen `var'_sq = `var'*`var'
	label var `var'_sq "`var' Squared"
}



**Drop intermediate variables before saving
/* capture drop merge_caregiver merge_river merge_sachet merge_school
capture drop mean_irt_* sd_irt_*
capture drop sample_water_source_brief sample_water_source_plot
capture drop river_duplicates_yn school_sachet_yn
capture drop sachet_*_mean river_*_mean
capture drop lost_in_watersample */

**Save the file
save "../Processed Stata Dta/Test Results Merged with EL Child Development.dta", replace
