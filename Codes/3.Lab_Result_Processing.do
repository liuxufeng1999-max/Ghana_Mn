/* Merge The Lab Results with the Main Dataset */ 

cd "$master_loc"

use "D:\Foundation First Pilot\02_Follow-up Survey\01_Parent Survey\04_clean_data_pii\FF_PARENT_EL_SURVEY_clean_pii_data.dta", clear
keep village new_village_id 
duplicates drop
rename new_village_id village_id_BL
rename village village_name
tempfile village_name_id
save `village_name_id', replace 

import excel "$master_loc\Original Data\100925_MetalsData_GhanaWaterSampling_xfl - 10102025..xlsx", sheet("To_be_Merged_Stata") firstrow clear

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


merge 1:1 sample_ID using "$master_loc/Processed Stata Dta/Sample_ID_Log.dta"
assert _merge==3 //-->all matched 
drop _merge 
egen sachet_yn = rowmax( vendor_sachet_yn school_sachet_yn)
merge m:1 village_name using `village_name_id'


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


save "$master_loc\Processed Stata dta\Lab Test Results.dta", replace


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
**With Outside Values
graph hbox Fe if river_duplicates_yn==0, ///
    over(sample_water_source_brief, total relabel(6 "Total (N=170)") sort(1)) ///
	/// Add the USEPA & WHO Threshold ///
		yline(300,  lpattern(shortdash) lcolor(red)) ///
		yline(80,  lpattern(dash) lcolor(purple)) ///
		text(270 102  "USEPA", size(small) color(red) ) /// 
		text(110 102  "WHO", size(small) color(purple)) /// 
    graphregion(color(white)) ///
    plotregion(style(none)) ///
	/// adjust the looking of the box ///
		box(1, fcolor(gs12) lcolor(gs8)) ///
		box(3, fcolor(gs12) lcolor(gs8)) ///
		box(5, fcolor(gs12) lcolor(gs8)) ///
		box(7, fcolor(gs12) lcolor(gs8)) ///
		box(9, fcolor(gs12) lcolor(gs8)) ///
		box(11, fcolor(gs12) lcolor(gs8)) ///
	ylabel(0 "Below LOD" 400 800 1200 1600 2000 2400 2800, labsize(medsmall)) /// 
    ytitle( "Mn ({&mu}g/L) ", size(medsmall)) ///
	marker(1, mfcolor(gs10) mlcolor(gs10) ) /// 
	name(Fe_hbox, replace)

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
	
graph export "$master_loc\Output\Figures\IQR_Mn_by_Sources.pdf", /// 
	name(Mn_hbox) as(pdf) replace
graph export "$master_loc\Output\Figures\IQR_Mn_by_Sources.svg", /// 
	name(Mn_hbox) as(svg) replace
	
	
**No Outside Values
graph hbox Mn if river_duplicates_yn==0, ///
    over(sample_water_source_plot, total relabel(6 "Total (N=170)") sort(1)) ///
	/// Add the USEPA & WHO Threshold ///
		yline(50,  lpattern(shortdash) lcolor(red)) ///
		yline(80,  lpattern(dash) lcolor(purple)) ///
		text(40 102  "USEPA", size(small) color(red) ) /// 
		text(88 102  "WHO", size(small) color(purple)) /// 
    graphregion(color(white)) ///
    plotregion(style(none)) ///
	/// adjust the looking of the box ///
		box(1, fcolor(gs12) lcolor(gs8)) ///
		box(2, fcolor(gs12) lcolor(gs8)) ///
		box(3, fcolor(gs12) lcolor(gs8)) ///
		box(4, fcolor(gs12) lcolor(gs8)) ///
		box(5, fcolor(gs12) lcolor(gs8)) ///
		box(6, fcolor(gs12) lcolor(gs8)) ///
    ytitle( "Mn ({&mu}g/L) ", size(medsmall)) ///
	marker(1, mfcolor(gs10) mlcolor(gs10) ) /// 
	nooutsides ///    marker(1, msymbol(i)) hide markers for outside values 
    ylabel(0 "Below LOD" 50 "USEPA" 80 "WHO" 100 150 200, labsize(medsmall)) /// 
	name(Mn_hbox_nout, replace) note("")
	
graph export "$master_loc\Output\Figures\IQR_Mn_by_Sources_NoOutsideValues.pdf", /// 
	name(Mn_hbox_nout) as(pdf) replace
	

	
// 	///
//     title("Manganese concentrations by water source", size(medium)) ///
//     note("Boxes show 25th–75th percentiles; whiskers show min–max. Reference lines at 50 and 80 µg/L.", size(vsmall))


	**Main Table: Mn statistics by Sample Source 
local stats   min p25 p50 p75 max mean count 
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
matrix colnames M = "Pooled" "Borehole" "River" "Piped Water" "Well" "Sachet"

esttab matrix(M, fmt(2)) using "$master_loc/Output/Tables/Mn_Distributions_by_Sample_Water_Source.tex", ///
    replace nomtitles /// 
	substitute("PipedWater" "Piped Water" " 0.00" "Below LOD" "Pooled" "Total" )
	
// esttab  matrix(M,transpose) using "$master_loc\Output\Tables\Mn_Distributions_by_Sample_Water_Source.tex" , ///
// 	coeflabels(mean "Mean" min  "Min" p25  "25th percentile" p50  "Median"  p75  "75th percentile" max  "Max" count "N") ///
// 	substitute("PipedWater" "Piped Water" " 0" "Below LOD" "Pooled" "Total" ) ///
// 	nomtitles replace  booktabs ///      
	
	**Appendix Table: Distribution by Sample Ownership for ALL metals
label variable WHO_Any_higher "Any Metals: \\ \hspace{20pt} Exceed WHO Limit"
label variable EPA_Prim_Any_higher "\hspace{20pt} Exceed EPA Primary Limit"
label variable EPA_Sec_Any_higher "\hspace{20pt} Exceed EPA Secondary Limit"
label variable EPA_PrimSec_higher "\hspace{20pt} Exceed EPA Primary or Secondary Limit"
label variable WHO_EPA_Any_higher "\hspace{20pt} Exceed EPA or WHO Limit"

label variable any_limit_Pb_higher "Exceed EPA or WHO Limit: \\ \hspace{20pt} Pb"
local metals Pb Hg Cd Cr Cu Mn Zn Fe Al
foreach var of varlist `metals' {
	label var `var' "`var' ({\ensuremath{\mu g/L})"
}

local limit "WHO_Any_higher EPA_Prim_Any_higher EPA_Sec_Any_higher any_limit_Pb_higher any_limit_Hg_higher any_limit_Cd_higher any_limit_Cr_higher any_limit_Cu_higher any_limit_Mn_higher any_limit_Zn_higher any_limit_Fe_higher any_limit_Al_higher Pb Hg Zn Cd Mn Fe Cr Al Cu "
	qui eststo all: estpost sum `limit' if river_duplicates_yn==0
	qui eststo hh: estpost sum `limit' if hh_sample_yn == 1
	qui eststo river: estpost sum `limit' if river_sample_yn == 1 & river_duplicates_yn==0
	qui eststo school: estpost sum `limit' if school_sample_yn == 1
	qui eststo vsachet: estpost sum `limit' if vendor_sachet_yn==1
	esttab all hh river school vsachet using "$master_loc\Output\Tables\Heavy_Metals_by_Sample_Water_Ownership.tex", label ///
	star(* 0.10 ** 0.05 *** 0.01)	///
	replace main(mean %6.2f) aux(sd) onecell mtitle("Pooled" "Non-Sachet Household" "River Samples" "School Samples" "Sachet from Vendors") substitute( "0.00 (0)" "Below LOD" "Pooled" "Total" )


	**Appendix Table: Distribution by Sample Source for ALL metals
local limit "WHO_Any_higher EPA_Prim_Any_higher EPA_Sec_Any_higher any_limit_Pb_higher any_limit_Hg_higher any_limit_Cd_higher any_limit_Cr_higher any_limit_Cu_higher any_limit_Mn_higher any_limit_Zn_higher any_limit_Fe_higher any_limit_Al_higher Pb Hg Zn Cd Mn Fe Cr Al Cu "
	qui eststo all: estpost sum `limit' if river_duplicates_yn==0
	qui eststo borehole: estpost sum `limit' if sample_water_source_brief == 1
	qui eststo river: estpost sum `limit' if sample_water_source_brief == 2 & river_duplicates_yn==0
	qui eststo pipe: estpost sum `limit' if sample_water_source_brief == 3
	qui eststo well: estpost sum `limit' if sample_water_source_brief==4
	qui eststo sachet: estpost sum `limit' if sample_water_source_brief==5
esttab all borehole river pipe well sachet using "$master_loc\Output\Tables\Heavy_Metals_by_Sample_Water_Source.tex", label ///
	star(* 0.10 ** 0.05 *** 0.01)	///
	replace main(mean %6.2f) aux(sd) onecell mtitle("Total" "Borehole" "River" "Piped Water" "Well" "Sachet") nonote
	
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
merge 1:m caregiver_id_EL using "C:\Users\liu.7133\Dropbox\Foundation First Evaluation\05_Data_Analysis\1. Pilot\Processed Data\Endline\Parent_Survey_isid_ChildCode.dta", gen(merge_caregiver)
drop if lost_in_EL!=0
merge m:1 new_village_id using `river_test', gen(merge_river)
distinct new_village_id if merge_river==1
assert `r(ndistinct)'==1 //--> there is one village where river sampling is not possible
merge m:1 new_village_id using `village_sachet', gen(merge_sachet)
assert merge_sachet == 3
merge m:1 new_village_id using `school_test', gen(merge_school)
assert merge_school == 3


**# Re-Standardized the Child Development Score 
**DECISION: in the pilot, we standardized relative to the EL Control Group. But in this study, it is more appropriate to standardized to the entire sample 
foreach s in all_30_48m motor_30_48m language_30_48m socio_30_48m cognitive_30_48m adaptive_30_48m{
	capture drop mean_irt_`s'_t 
	capture drop mean_irt_`s' 
	capture drop sd_irt_`s'_t 
	capture drop sd_irt_`s'
	capture drop z_irt_`s'
	
	sum theta_`s' //-->remove the previous if condition:  if treatment == 0
	gen mean_irt_`s'_t=r(mean)
	gen sd_irt_`s'_t =r(sd)

	egen mean_irt_`s' = max(mean_irt_`s'_t)
	egen sd_irt_`s' = max(sd_irt_`s'_t)
	
	capture drop sd_irt_`s'_t mean_irt_`s'_t
	sum mean_irt_`s' sd_irt_`s'
	
	gen z_irt_`s'=(theta_`s'-mean_irt_`s')/sd_irt_`s'
 }
 




local metals Pb Hg Zn Cd Mn Fe Cr Al Cu 
**3 caregivers are missing in the water sampling: 100110081P2 , 100151011P2 , and 110025106P1
**among them 100110081P2 report to have sachet water as their primary drinking water 
**100151011P2 , and 110025106P1 report to drink borehole water 
foreach var of varlist `metals' {
	replace `var' = sachet_`var'_mean if missing(`var') & caregiver_id_EL!="100151011P2" & caregiver_id_EL != "110025106P1"
}
replace Batch = Batch_Sachet if missing(Batch) & caregiver_id_EL!="100151011P2" & caregiver_id_EL != "110025106P1"



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

drop WHO_Pb_higher WHO_Hg_higher WHO_Cd_higher WHO_Mn_higher WHO_Cr_higher WHO_Cu_higher WHO_Any_higher EPA_prim_Pb_higher EPA_prim_Hg_higher EPA_prim_Cd_higher EPA_prim_Cr_higher EPA_prim_Cu_higher EPA_sec_Zn_higher EPA_sec_Mn_higher EPA_sec_Fe_higher EPA_sec_Al_higher EPA_sec_Cu_higher EPA_PrimSec_Pb_higher EPA_PrimSec_Hg_higher EPA_Prim_Any_higher EPA_Sec_Any_higher EPA_PrimSec_higher WHO_EPA_Any_higher any_limit_Pb_higher any_limit_Hg_higher any_limit_Cd_higher any_limit_Cr_higher any_limit_Cu_higher any_limit_Mn_higher any_limit_Zn_higher any_limit_Fe_higher any_limit_Al_higher

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
label variable EPA_sec_Mn_higher "EPA: Mn above 50 {&mu}g/L"
label variable WHO_Mn_higher "WHO: Mn above 80 {&mu}g/L"

local metals Pb Hg Cd Cr Cu Mn Zn Fe Al
foreach var of varlist `metals' {
	label var `var' "`var' ({&mu}g/L)"
	gen `var'_sq = `var'*`var'
	label var `var'_sq "`var' Squared"
}



**Save the file 
save "$master_loc\Processed Stata Dta\Test Results Merged with EL Child Development.dta", replace 

local stats "mean min p25 p50 p75 max"
local var "Mn"
// Run estpost tabstat for each source, including pooled (all)
eststo clear
eststo pooled:    estpost tabstat `var', statistics(`stats') columns(statistics)
eststo borehole:  estpost tabstat `var' if sample_water_source_brief == 1, statistics(`stats') columns(statistics)
eststo river:     estpost tabstat `var' if sample_water_source_brief == 2, statistics(`stats') columns(statistics)
eststo pipe:      estpost tabstat `var' if sample_water_source_brief == 3, statistics(`stats') columns(statistics)
eststo well:      estpost tabstat `var' if sample_water_source_brief == 4, statistics(`stats') columns(statistics)
eststo sachet:    estpost tabstat `var' if sample_water_source_brief == 5, statistics(`stats') columns(statistics)

// Export to LaTeX: each row is a stat, each column is a group
esttab pooled borehole river pipe well sachet ///
/*using "$master_loc/Output/Tables/Mn_Distribution_by_Sample_Water_Source.tex"*/, ///
replace ///
cells("mean(fmt(2)) min(fmt(2)) p25(fmt(2)) p50(fmt(2)) p75(fmt(2)) max(fmt(2))") ///
coeflabel(mean "Mean" min "Min" p25 "25th Percentile" ///
          p50 "Median" p75 "75th Percentile" max "Max") ///
mtitle("Pooled" "Borehole" "River" "Piped Water" "Well" "Sachet") ///
nonumber label transpose
	

// 	 eststo all: estpost tabstat `limit', statistics(`stats')
// 	 eststo borehole: estpost tabstat `limit' if sample_water_source_brief == 1, statistics(`stats') columns(variables)
// 	 eststo river: estpost tabstat `limit' if sample_water_source_brief == 2, statistics(`stats') columns(variables)
// 	 eststo pipe: estpost tabstat `limit' if sample_water_source_brief == 3, statistics(`stats') columns(variables)
// 	 eststo well: estpost tabstat `limit' if sample_water_source_brief==4, statistics(`stats')
// 	 eststo sachet: estpost tabstat `limit' if sample_water_source_brief==5, statistics(`stats') columns(variables)
// foreach x in all borehole river pipe well sachet {
// 	est restore `x'
// 	estadd local WHO = "80{&mu}g/L"
// 	estadd local EPA = "50{&mu}g/L"
// 	est store `x'
// }
// esttab all borehole river pipe well sachet using "$master_loc\Output\Tables\Mn_Distribution_by_Sample_Water_Source.tex", label ///
//     cells("mean(fmt(2)) min(fmt(2)) p25(fmt(2)) p50(fmt(2)) p75(fmt(2)) max(fmt(2))") ///
// 	coeflabel(mean "Mean" min "Min" p25 "25th Percentile" p50 "50th Percentile" p75 "75th Percentile" max "Max") ///
// 	replace  mtitle("Pooled" "Borehole" "River" "Piped Water" "Well" "Sachet") 