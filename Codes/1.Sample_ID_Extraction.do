/* Water Sample */
cd "$master_loc"
 **TestTestTest

**# Sample ID Extraction

	**# River
use "$cryptomator_loc/04_River Water Sample/04_clean_data_pii/River_water_pii_data.dta", clear

**Access point ID & GPS
preserve
local id_var gps_riverlatitude gps_riverlongitude gps_riveraltitude gps_riveraccuracy water_sample_id
local name "GPS_lat GPS_long GPS_altit GPS_accuracy sample_ID"
local i = 1
foreach var of varlist `id_var' {
	local lbl : word `i' of `name'
	rename `var' `lbl'
	local i = `i'+1
}
keep village_name district_name village_id GPS_lat GPS_long GPS_altit GPS_accuracy sample_ID
tempfile accesspoint
save `accesspoint', replace
restore

**Stream Point 1 ID  & GPS
preserve
gen sample_ID_b27 = stream_type_id if type_stream=="Upstream"
replace sample_ID_b27 = stream_type_id_sec if type_stream=="Downstream"
local id_var geopoint_b27latitude geopoint_b27longitude geopoint_b27altitude geopoint_b27accuracy sample_ID_b27
local name "GPS_lat GPS_long GPS_altit GPS_accuracy sample_ID"
local i = 1
foreach var of varlist `id_var' {
	local lbl : word `i' of `name'
	rename `var' `lbl'
	local i = `i'+1
}
keep village_name district_name village_id GPS_lat GPS_long GPS_altit GPS_accuracy sample_ID
tempfile stream1
save `stream1', replace
restore

**Stream Point 2 ID & GPS
preserve
gen sample_ID_b36 = stream_type_id if stream_calcul=="Upstream"
replace sample_ID_b36 = stream_type_id_sec if stream_calcul=="Downstream"
local id_var geopoint_b36latitude geopoint_b36longitude geopoint_b36altitude geopoint_b36accuracy sample_ID_b36
local name "GPS_lat GPS_long GPS_altit GPS_accuracy sample_ID"
local i = 1
foreach var of varlist `id_var' {
	local lbl : word `i' of `name'
	rename `var' `lbl'
	local i = `i'+1
}
keep village_name district_name village_id GPS_lat GPS_long GPS_altit GPS_accuracy sample_ID

tempfile stream2
save `stream2', replace
restore

**Duplicates: share the same GPS Coordinates with the original
gen dup_sample_type = "Upstream" if substr(duplicate_test_id, -2, 2) == "07"
replace dup_sample_type = "Downstream" if substr(duplicate_test_id, -2, 2) == "08"
gen GPS_lat = .
gen GPS_long = .
gen GPS_altit = .
gen GPS_accuracy = .

replace GPS_lat = geopoint_b27latitude if dup_sample_type == type_stream
replace GPS_long = geopoint_b27longitude if dup_sample_type == type_stream
replace GPS_altit = geopoint_b27altitude if dup_sample_type == type_stream
replace GPS_accuracy = geopoint_b27accuracy if dup_sample_type == type_stream

replace GPS_lat = geopoint_b36latitude if dup_sample_type == stream_calcul
replace GPS_long = geopoint_b36longitude if dup_sample_type == stream_calcul
replace GPS_altit = geopoint_b36altitude if dup_sample_type == stream_calcul
replace GPS_accuracy = geopoint_b36accuracy if dup_sample_type == stream_calcul

rename duplicate_test_id sample_ID

keep village_name district_name village_id GPS_lat GPS_long GPS_altit GPS_accuracy sample_ID

append using  `accesspoint' `stream1'  `stream2'
gen river_accesspoint = substr(sample_ID, -2, 2) == "05" | substr(sample_ID, -2, 2) == "09"
gen river_upstream = substr(sample_ID, -2, 2) == "03" | substr(sample_ID, -2, 2) == "07"
gen river_downstream = substr(sample_ID, -2, 2) == "04" | substr(sample_ID, -2, 2) == "08"
gen river_duplicates = substr(sample_ID, -2, 2) == "07" | substr(sample_ID, -2, 2) == "08" | substr(sample_ID, -2, 2) == "09"
drop if missing(sample_ID)
drop if sample_ID=="."
tempfile river_sample_ID
save `river_sample_ID'

	**# School Water
use "$cryptomator_loc/02_School Water Sample/04_clean_data_pii/School_water_pii_data.dta", clear
gen school_sample = 1
gen school_sachet = 0
preserve
	keep village_name gps_employeelatitude gps_employeelongitude gps_employeealtitude gps_employeeaccuracy sch_samp_id school_sample school_sachet sch_id_old district_name district_id
	rename sch_id_old sch_full_ID
	rename sch_samp_id sample_ID
	tempfile sch_nonsachet
	save `sch_nonsachet', replace
restore
keep village_name gps_employeelatitude gps_employeelongitude gps_employeealtitude gps_employeeaccuracy sachet_sample_id school_sample school_sachet sch_id_old district_name district_id
rename sachet_sample_id sample_ID
rename sch_id_old sch_full_ID

replace school_sachet = 1
append using `sch_nonsachet'
local id_var gps_employeelatitude gps_employeelongitude gps_employeealtitude gps_employeeaccuracy sample_ID
local name "GPS_lat GPS_long GPS_altit GPS_accuracy sample_ID"
local i = 1
foreach var of varlist `id_var' {
	local lbl : word `i' of `name'
	rename `var' `lbl'
	local i = `i'+1
}

label variable sample_ID "Water Sample ID (###-##-## as BL_ID-SOURCE-LOCATION)"
**Derrick: school 208 only drink sachet water
drop if school_sachet==0 & sample_ID=="208_07_01"
drop if sample_ID=="."
isid sample_ID
tempfile school_sample_ID
save `school_sample_ID', replace


	**# Household Water
use "$cryptomator_loc/01_Household Water Sample/04_clean_data_pii/Household_water_pii_data.dta", clear
gen hh_sample = 1
local id_var gps_employeelatitude gps_employeelongitude gps_employeealtitude gps_employeeaccuracy household_sample_id
local name "GPS_lat GPS_long GPS_altit GPS_accuracy sample_ID"
local i = 1
foreach var of varlist `id_var' {
	local lbl : word `i' of `name'
	rename `var' `lbl'
	local i = `i'+1
}

keep GPS_lat GPS_long GPS_altit GPS_accuracy sample_ID hh_sample caregiver_id_old village_id village_name district_name district_id
rename caregiver_id_old HH_full_ID
label variable sample_ID "Water Sample ID (###-##-## as BL_ID-SOURCE-LOCATION)"
tempfile HH_sample_ID
save `HH_sample_ID', replace


	**# Sachet Water
use "$cryptomator_loc/03_Sachet Water Sample/04_clean_data_pii/Sachet_water_pii_data.dta", clear
gen vendor_sachet_sample = 1
local id_var geo_samp_pointlatitude geo_samp_pointlongitude geo_samp_pointaltitude geo_samp_pointaccuracy sach_water_id
local name "GPS_lat GPS_long GPS_altit GPS_accuracy sample_ID"
local i = 1
foreach var of varlist `id_var' {
	local lbl : word `i' of `name'
	rename `var' `lbl'
	local i = `i'+1
}
keep district_name village_id village_name GPS_lat GPS_long GPS_altit GPS_accuracy sample_ID
gen vendor_sachet = 1
label variable sample_ID "Water Sample ID (###-##-## as BL_ID-SOURCE-LOCATION)"
tempfile vendor_sachet_sample_ID
save `vendor_sachet_sample_ID', replace

append using `HH_sample_ID' `school_sample_ID' `river_sample_ID'
foreach var of varlist hh_sample vendor_sachet school_sample school_sachet river_accesspoint river_upstream river_downstream river_duplicates {
	rename `var' `var'_yn
	replace `var'_yn = 0 if missing(`var'_yn)
}
egen river_sample_yn = rowmax(river_accesspoint_yn river_upstream_yn river_downstream_yn river_duplicates_yn)

order district_name district_id village_name village_id sample_ID GPS_lat GPS_long GPS_altit GPS_accuracy  HH_full_ID sch_full_ID hh_sample_yn vendor_sachet_yn school_sample_yn school_sachet_yn river_accesspoint_yn river_sample_yn river_upstream_yn river_downstream_yn river_duplicates_yn
drop if missing(sample_ID)
drop if sample_ID=="."
replace village_id = substr(sample_ID, 1, 3) if missing(village_id)



save "../Original Data/Sample_ID_Log.dta", replace
preserve
	use "D:/Foundation First Pilot/02_Follow-up Survey/01_Parent Survey/04_clean_data_pii/FF_PARENT_EL_SURVEY_clean_pii_data.dta", clear
	keep village new_village_id
	duplicates drop
	rename new_village_id village_id_BL
	rename village village_name
	tempfile village_name_id
	save `village_name_id', replace
restore
merge m:1 village_name using `village_name_id'
drop village_name
assert _merge==3
drop _merge
**GPS: round to 2 decimal places to avoid PII concern (precision = ~1.1 km)
replace GPS_lat = round(GPS_lat, 0.01)
replace GPS_long = round(GPS_long, 0.01)
replace GPS_altit = round(GPS_altit, 50)
save "../Original Data/Sample_ID_Log.dta", replace




