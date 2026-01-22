/* TEST STRIP SAMPLE ANALYSIS */ 
cd "$master_loc"

use "$master_loc\Original Data\Test_strip_no_pii_data.dta", clear

gen source_code = substr(final_test_id, 5, 2)
destring source_code, replace
label define source 1 "Borehole" 2 "River" 3 "Piped inside" 4 "Piped outside" 5 "Well" 6 "Rainwater" 7 "Sachet" 8 "Public Tap"
label values source_code source

recode source_code (1 = 1 "Borehole") (2 = 2 "River") (3 4 8 = 3 "Piped") (5 = 5 "Well") (6 = 6 "Rainwater") (7 = 7 "Sachet"), gen(source_code_brief) 


gen BL_short_code = substr(final_test_id, 1, 3)
destring BL_short_code, replace
recode BL_short_code (1/199 = 1 "Non-sahcet Household") (200/299 = 2 "School") (300/399 = 3 "Village River/Sachet"), gen(water_owner_type)
replace water_owner_type = 4 if water_owner_type==3 & source_code==2
label define water_owner_type 1 "Non-sahcet Household" 2 "School" 3 "Village Sachet" 4 "Village River", replace

tab water_owner_type source_code_brief

preserve
local i = 1
foreach var of varlist ph_sele_one_round alkaline_sel hardness_sel sulfur_hydro_sele iron_sele copper_sel lead_sel mangan_sel_round chlorine_sel mercury_sel nitrate_sel nitrite_sel sulfate_sel zinc_sel sodium_chl_sel flouride_sel {
	destring `var', replace 
 	tab `var'
	rename `var' test_`i'
	local i = `i' + 1
}
 
reshape long test_, i(final_test_id) j(test_num)
rename test_ test_value
drop if missing(test_value)


gen test_var_name = ""

replace test_var_name = "PH"       if test_num == 1
replace test_var_name = "Total Alkalinity (ppm)"            if test_num == 2
replace test_var_name = "Hardness (mg/L)"            if test_num == 3
replace test_var_name = "Sulfuretted Hydrogen (mg/L)"       if test_num == 4
replace test_var_name = "Iron (mg/L)"               if test_num == 5
replace test_var_name = "Copper (mg/L)"              if test_num == 6
replace test_var_name = "Lead (ug/L)"                if test_num == 7
replace test_var_name = "Manganese (mg/L)"        if test_num == 8
replace test_var_name = "Total Chlorine (mg/L)"            if test_num == 9
replace test_var_name = "Mercury (ug/L)"             if test_num == 10
replace test_var_name = "Nitrate (mg/L)"             if test_num == 11
replace test_var_name = "Nitrite (mg/L)"             if test_num == 12
replace test_var_name = "Sulfate (mg/L)"             if test_num == 13
replace test_var_name = "Zinc (mg/L)"                if test_num == 14
replace test_var_name = "Sodium Chloride (mg/L)"          if test_num == 15
replace test_var_name = "Fluoride (mg/L)"            if test_num == 16

contract test_var_name test_value
label values test_value .

levelsof test_value if !missing(test_value), local(vals)
cap label drop tvlbl
label define tvlbl 9999 ""
gen int test_value_cat = .

local i = 1
foreach v of local vals {
    replace test_value_cat = `i' if test_value == `v'
    // control the display; pick one format
    local lab = string(`v', "%9.3g")     // or "%9.2f" if you want 2 decimals
    label define tvlbl `i' "`lab'", add
    local ++i
}
label values test_value_cat tvlbl

gen red_flag = 0 
replace red_flag = 1 if test_var_name == "PH"  & test_value<6.8
replace red_flag = 1 if test_var_name == "Total Alkalinity (ppm)"  & (test_value<40|test_value>120)
//hardness has no recomended value 
replace red_flag = 1 if test_var_name == "Sulfuretted Hydrogen (mg/L)"  & test_value!=0
replace red_flag = 1 if test_var_name == "Iron (mg/L)"  & test_value!=0
replace red_flag = 1 if test_var_name == "Copper (mg/L)"  & test_value>1
replace red_flag = 1 if test_var_name == "Lead (ug/L)"  & test_value!=0
replace red_flag = 1 if test_var_name == "Manganese (mg/L)"  & test_value>0.5
replace red_flag = 1 if test_var_name == "Total Chlorine (mg/L)"  & test_value>1
replace red_flag = 1 if test_var_name == "Mercury (ug/L)"  & test_value>2
replace red_flag = 1 if test_var_name == "Nitrate (mg/L)"  & test_value>10
replace red_flag = 1 if test_var_name == "Nitrite (mg/L)"  & test_value>1
replace red_flag = 1 if test_var_name == "Sulfate (mg/L)"  & test_value>200
replace red_flag = 1 if test_var_name == "Zinc (mg/L)"  & test_value>5
replace red_flag = 1 if test_var_name == "Sodium Chloride (mg/L)"  & test_value>250
replace red_flag = 1 if test_var_name == "Fluoride (mg/L)"  & test_value>4

bys test_var_name test_value_cat: egen byte red_cat = max(red_flag)

* Split counts so one of them is zero per category
gen double freq_ok  = cond(red_cat==0, _freq, 0)
gen double freq_red = cond(red_cat==1, _freq, 0)
label var freq_ok  "≤ WHO/guide"
label var freq_red "> WHO/guide"
replace freq_ok = . if freq_ok == 0
replace freq_red = . if freq_red == 0
	
levelsof test_var_name, local(testvars)
local name "ph_sele_one_round alkaline_sel hardness_sel sulfur_hydro_sele iron_sele copper_sel lead_sel mangan_sel_round chlorine_sel mercury_sel nitrate_sel nitrite_sel sulfate_sel zinc_sel sodium_chl_sel flouride_sel"
local i = 1
foreach var of local testvars {
    local lbl : word `i' of `name'
	graph bar freq_ok freq_red if test_var_name == "`var'", ///
		over(test_value_cat, label(labsize(small))) ///        
		bar(1, color(navy)) blabel(bar, size(small)) ///
        title("`var'") ///
        ytitle("") ///
		legend(order(1 "Within Recommended Range" 2 "Outside Recommended Range") pos(6) ring(1) col(2)) ///
        name(g_`lbl', replace)
	local glist "`glist' g_`lbl'"
	local i = `i'+1
}
grc1leg `glist', col(4) title("Test Strip Sample Result") name(test_agg, replace)
graph export "$master_loc/Output/Test Strip Results.png",  name(test_agg) as(png) replace 
graph drop `glist'
