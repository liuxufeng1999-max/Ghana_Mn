
**We want to know whether the brand is registered or not
**and then Mn/Water Quality differences by the Registered & Unregistered samples
**Ghana FDA Registry: https://verifypermit.fdaghana.gov.gh/publicsearch

// capture frame create sachet
// capture frame change sachet

 use "$cryptomator_loc\03_Sachet Water Sample\04_clean_data_pii\Sachet_water_pii_data.dta", clear
append using "$cryptomator_loc\02_School Water Sample\04_clean_data_pii\School_water_pii_data.dta"

drop if sachet_sample_id=="."
gen sample_ID = sachet_sample_id
replace sample_ID = sach_water_id if missing(sample_ID)
assert strpos(sample_ID, "_07_") != 0 //--> every sample ID here are sachet water sample

gen sachet_brand_name = rec_sach_brnd_name
replace sachet_brand_name =  brand_name_image if missing(sachet_brand_name)
gen sachet_manuf_name = rec_sach_manu_name
replace sachet_manuf_name = manu_name_image if missing(sachet_manuf_name)

replace sachet_brand_name = "A&A Mineral Water" if sachet_brand_name == "A&A mineral water"
replace sachet_brand_name = "Unique Natural Mineral Water" if sachet_brand_name == "UNIQUE"
keep sample_ID sachet_brand_name sachet_manuf_name
// 208_07_01 310_07_01 are from the company name; share similar contamination level
// 303_07_01 and 205_07_01 also from the same company name, share similar contamination level

capture drop FDA_registered
gen FDA_registered = 0
replace FDA_registered = 1 if sample_ID == "306_07_01" //FDA: Fredericko Asan Ent., GPS WQ-0020-9272, Behind the District Assembly Complex, off Antobia Road, Juaboso, WN/R	Pure Naturale Ice Natural Mineral Water - LDPE Sachet (500ml)

save "$cryptomator_loc\Processed\Sachet_Water_Brand_Manufacturer.dta", replace

//merge back to the main data file
use "$proc_dta_loc\Lab Test Results.dta", clear
capture drop _merge
merge 1:1 sample_ID using "$cryptomator_loc\Processed\Sachet_Water_Brand_Manufacturer.dta"


assert _merge !=2 //-->there will be some not matched but all of them are not sachet water
drop _merge

**Make a plot
capture drop sachet_brand_ID
egen sachet_brand_ID = group(sachet_brand_name)
egen sachet_sample_ID = group(sample_ID) if sachet_yn==1

//replace below LOD as a small value
summ Mn if sachet_yn==1 & Mn>0, meanonly
local eps = r(min)*0.01
capture drop Mn_plot
gen Mn_plot = .
replace Mn_plot = Mn if sachet_yn==1
replace Mn_plot = `eps' if sachet_yn==1 & Mn==0

* create x ONLY on sachets, sorted high -> low
capture drop x
gsort +Mn_plot +sachet_sample_ID
gen x = _n if sachet_yn==1

* how many samples per brand?
bysort sachet_brand_ID: gen nbrand = _N

* identify duplicated brands
gen dup = (nbrand>1)

* give each duplicated brand a unique group number (1,2,3...) for star assignment
egen dupgroup = group(sachet_brand_ID) if dup & sachet_yn==1

* build stars (supports up to 5 duplicates groups; extend if needed)
gen str5 stars = ""
replace stars = "*"     if dupgroup==1
replace stars = "**"    if dupgroup==2
replace stars = "***"   if dupgroup==3
replace stars = "****"  if dupgroup==4
replace stars = "*****" if dupgroup==5

* final xlabel text is sample ID + stars (stars blank for non-duplicates)
tostring sachet_sample_ID, gen(sample_str) format(%9.0g) force
gen str20 xlab = sample_str + stars if sachet_yn==1

levelsof x  if sachet_yn==1, local(xs)
capture label define Xlbl 0 ""
capture label define Xlbl 0 "", replace
foreach xi of local xs {
    quietly levelsof xlab if x==`xi' & sachet_yn==1, local(lbl) clean
    label define Xlbl `xi' "`lbl'", add
}
label values x Xlbl

* below LOD label position (if you use Mn==0 as below LOD)
summ Mn if Mn>0, meanonly
local eps = r(min)*0.01
capture drop ylab
capture drop lodlab
gen ylab = Mn_plot + `eps'*0.4
gen str20 lodlab = ""
replace lodlab = "<LOD" if Mn==0

drop sachet_brand_name sachet_manuf_name
save "../Processed Stata Dta\Sachet Test Results_Only.dta", replace
