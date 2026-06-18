use "../Processed Stata Dta/Test Results Merged with EL Child Development.dta", clear
tab Mn_LOD_EPA
numlabel, add
**# Robustness: Categorical Model: Multiple Mn Cutoffs: 30,40,50,60,70,80

local if_cond "(focal_child_yn==1|focal_child_yn==0)"
local cov_always "Batch treatment i.dist_code"
local cov "age_chld_months_EL child_male "
local cov_add "hh_learn_mca1 par_involv_mca1 own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_primary_BL high_education_secondary_BL high_education_SSS_higher_BL annual_income_geq5k_BL recall_income_geq20k recall_income_geq10k recall_income_geq5k recall_income_bel5k"
local outcome z_irt_all_30_48m //hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
local cutoffs 30 40 50 60 70 80

tempfile mn_cutoff_results
tempname mn_results

postfile `mn_results' cutoff str20 contrast b se lb ub p N r2 ///
	using `mn_cutoff_results', replace

foreach cutoff of local cutoffs {
	capture drop Mn_LOD_cutoff
	gen byte Mn_LOD_cutoff = .
	replace Mn_LOD_cutoff = 1 if Mn == 0
	replace Mn_LOD_cutoff = 2 if Mn > 0 & Mn <= `cutoff'
	replace Mn_LOD_cutoff = 3 if Mn > `cutoff' & !missing(Mn)

	label define Mn_LOD_cutoff_lbl ///
		1 "Mn Below LOD" ///
		2 "Detected <= `cutoff' {&mu}gL{sup:-1}" ///
		3 "Above `cutoff' {&mu}gL{sup:-1}", replace
	label values Mn_LOD_cutoff Mn_LOD_cutoff_lbl
	label var Mn_LOD_cutoff "HH water Mn category by cutoff"

	foreach var of varlist `outcome' {
		reg `var' ib1.Mn_LOD_cutoff `cov_always' `cov' `cov_add' ///
			if `if_cond', vce(cluster caregiver_id_BL)
		est store GSED_Mn_cut`cutoff'_addcov

		foreach level in 2 3 {
			if `level' == 2 {
				local contrast "Detected <= cutoff"
			}
			else {
				local contrast "Above cutoff"
			}

			local b = _b[`level'.Mn_LOD_cutoff]
			local se = _se[`level'.Mn_LOD_cutoff]
			local lb = `b' - invttail(e(df_r), 0.025) * `se'
			local ub = `b' + invttail(e(df_r), 0.025) * `se'
			local p = 2 * ttail(e(df_r), abs(`b' / `se'))

			post `mn_results' (`cutoff') ("`contrast'") (`b') (`se') ///
				(`lb') (`ub') (`p') (e(N)) (e(r2))
		}
	}
}

postclose `mn_results'

preserve
	use `mn_cutoff_results', clear
	label var cutoff "Mn cutoff ({&mu}gL{sup:-1})"
	label var contrast "Mn category"
	label var b "Coefficient estimate"
	label var se "Standard error"
	label var lb "95% CI lower bound"
	label var ub "95% CI upper bound"
	label var p "P-value"
	label var N "N (Children)"
	label var r2 "R-squared"
	format b se lb ub p r2 %9.3f

	export delimited using ///
		"../Output/Tables/TableS_Mn_Cutoff_Robustness_Estimates.csv", replace

	gen cutoff_plot = cutoff
	replace cutoff_plot = cutoff - 0.8 if contrast == "Detected <= cutoff"
	replace cutoff_plot = cutoff + 0.8 if contrast == "Above cutoff"

	twoway ///
		(rcap ub lb cutoff_plot if contrast == "Detected <= cutoff" & cutoff != 50, ///
			lcolor(maroon%35)) ///
		(scatter b cutoff_plot if contrast == "Detected <= cutoff" & cutoff != 50, ///
			mcolor(maroon) msymbol(circle) msize(medium)) ///
		(rcap ub lb cutoff_plot if contrast == "Above cutoff" & cutoff != 50, ///
			lcolor(maroon%35)) ///
		(scatter b cutoff_plot if contrast == "Above cutoff" & cutoff != 50, ///
			mcolor(maroon) msymbol(square) msize(medium)) ///
		(rcap ub lb cutoff_plot if contrast == "Detected <= cutoff" & cutoff == 50, ///
			lcolor(navy%45)) ///
		(rcap ub lb cutoff_plot if contrast == "Above cutoff" & cutoff == 50, ///
			lcolor(navy%45)) ///
		(scatter b cutoff_plot if cutoff == 50 & contrast == "Detected <= cutoff", ///
			msymbol(circle) msize(medium) mcolor(navy)) ///
		(scatter b cutoff_plot if cutoff == 50 & contrast == "Above cutoff", ///
			msymbol(square) msize(medium) mcolor(navy)), ///
		xline(50, lpattern(shortdash) lcolor(gs8)) ///
		yline(0, lpattern(dash) lcolor(gs10)) ///
		xscale(range(28 82)) ///
		xlabel(30(10)80) ///
		xtitle("Mn cutoff ({&mu}gL{sup:-1})") ///
		ytitle("Estimate relative to Mn below LOD") ///
		legend(order(2 "Detected <= cutoff" 4 "Above cutoff" ///
			7 "Original cutoff = 50{&mu}gL{sup:-1} (USEPA)") pos(6) col(3)) ///
		graphregion(color(white)) plotregion(color(white)) ///
		name(Mn_cutoff_robustness, replace)
		/* note("Dashed vertical line and diamond markers identify cutoff = 50 {&mu}gL{sup:-1}.") /// */
		/* title("Mn cutoff robustness") /// */

	graph export "../Output/Figures/FigS_Mn_Cutoff_Robustness_Coefplot.pdf", ///
		name(Mn_cutoff_robustness) as(pdf) replace
	graph export "../Output/Figures/FigS_Mn_Cutoff_Robustness_Coefplot.svg", ///
		name(Mn_cutoff_robustness) as(svg) replace
restore


**# Alternative Specifications
**1. add village FEs (var: new_village_id) (replace original district FEs)
**2. add water source FEs (var: sample_water_source)
**3. add co-occuring metals (vars: Pb Fe Cr Al Cu) - all other metals have all undetected levels omitted here
**4. add all 1-3 above
**5. original estimates with full covariates.

**EPA Standard: >50 {&mu}gL{sup:-1}
local if_cond "(focal_child_yn==1|focal_child_yn==0)"
local outcome z_irt_all_30_48m //hlth_stat_chld_healthier_BL child_dev_age_advanced_BL
local cov_base "Batch treatment age_chld_months_EL child_male"
local cov_add "hh_learn_mca1 par_involv_mca1 own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_primary_BL high_education_secondary_BL high_education_SSS_higher_BL annual_income_geq5k_BL recall_income_geq20k recall_income_geq10k recall_income_geq5k recall_income_bel5k"

capture confirm variable Mn_LOD_EPA
if _rc {
	capture drop Mn_LOD_EPA
	gen byte Mn_LOD_EPA = .
	replace Mn_LOD_EPA = 1 if Mn == 0
	replace Mn_LOD_EPA = 2 if Mn > 0 & Mn <= 50
	replace Mn_LOD_EPA = 3 if Mn > 50 & !missing(Mn)
	label define Mn_aboveLOD_EPA 1 "Mn Below LOD" ///
		2 "Detected <= 50 {&mu}gL{sup:-1}" ///
		3 "Above 50 {&mu}gL{sup:-1}", replace
	label values Mn_LOD_EPA Mn_aboveLOD_EPA
}

capture confirm variable log_Mn_LODsq2
if _rc {
	capture drop MN_LODsq2 log_Mn_LODsq2
	gen MN_LODsq2 = Mn
	replace MN_LODsq2 = 2.953/sqrt(2) if Batch == 1 & Mn == 0
	replace MN_LODsq2 = 3.282/sqrt(2) if Batch == 2 & Mn == 0
	replace MN_LODsq2 = 3.282/sqrt(2) if missing(Batch) & Mn == 0
	gen log_Mn_LODsq2 = log10(MN_LODsq2)
	label var log_Mn_LODsq2 "log(Household Mn)"
}

local village_fe_var new_village_id
capture confirm string variable new_village_id
if !_rc {
	capture drop new_village_id_num
	egen new_village_id_num = group(new_village_id), label(new_village_id_num, replace)
	local village_fe_var new_village_id_num
}

local metal_cov "Pb Fe Cr Al Cu"
local full_base "`cov_base' `cov_add'"
local cov_1 "`full_base' i.`village_fe_var'"
local cov_2 "`full_base' i.dist_code i.sample_water_source"
local cov_3 "`full_base' i.dist_code `metal_cov'"
local cov_4 "`full_base' i.`village_fe_var' i.sample_water_source `metal_cov'"
local cov_5 "`full_base' i.dist_code"

local spec_label_1 "Village FEs replace district FEs"
local spec_label_2 "Add water source FEs"
local spec_label_3 "Add co-occurring metals"
local spec_label_4 "Add all robustness controls"
local spec_label_5 "Original full covariates"

tempfile alt_spec_results
tempname alt_results

postfile `alt_results' str12 model spec_order str40 spec_label b se lb ub p N r2 ///
	using `alt_spec_results', replace

foreach var of varlist `outcome' {
	forvalues spec = 1/5 {
		local rhs "`cov_`spec''"
		local spec_label "`spec_label_`spec''"

		reg `var' ib1.Mn_LOD_EPA `rhs' if `if_cond', ///
			vce(cluster caregiver_id_BL)
		est store CatMn_spec`spec'

		local b = _b[3.Mn_LOD_EPA]
		local se = _se[3.Mn_LOD_EPA]
		local lb = `b' - invttail(e(df_r), 0.025) * `se'
		local ub = `b' + invttail(e(df_r), 0.025) * `se'
		local p = 2 * ttail(e(df_r), abs(`b' / `se'))
		post `alt_results' ("Categorical") (`spec') ("`spec_label'") ///
			(`b') (`se') (`lb') (`ub') (`p') (e(N)) (e(r2))

		reg `var' log_Mn_LODsq2 `rhs' if `if_cond', ///
			vce(cluster caregiver_id_BL)
		est store LogMn_spec`spec'

		local b = _b[log_Mn_LODsq2]
		local se = _se[log_Mn_LODsq2]
		local lb = `b' - invttail(e(df_r), 0.025) * `se'
		local ub = `b' + invttail(e(df_r), 0.025) * `se'
		local p = 2 * ttail(e(df_r), abs(`b' / `se'))
		post `alt_results' ("LogMn") (`spec') ("`spec_label'") ///
			(`b') (`se') (`lb') (`ub') (`p') (e(N)) (e(r2))
	}
}

postclose `alt_results'

preserve
	use `alt_spec_results', clear
	label var model "Mn exposure model"
	label var spec_order "Alternative specification"
	label var spec_label "Alternative specification"
	label var b "Coefficient estimate"
	label var se "Standard error"
	label var lb "95% CI lower bound"
	label var ub "95% CI upper bound"
	label var p "P-value"
	label var N "N (Children)"
	label var r2 "R-squared"
	format b se lb ub p r2 %9.3f

	export delimited using ///
		"../Output/Tables/TableS_Mn_AlternativeSpecifications_Estimates.csv", ///
		replace

	local spec_ylabels ///
		1 "Village FEs" ///
		2 "Water source FEs" ///
		3 "Co-occurring metals" ///
		4 "All additions" ///
		5 "Original full covariates"

	twoway ///
		(rcap ub lb spec_order if model == "Categorical" & spec_order != 5, horizontal ///
			lcolor(maroon%45)) ///
		(scatter spec_order b if model == "Categorical" & spec_order != 5, ///
			msymbol(circle) mcolor(maroon) msize(medium)) ///
		(rcap ub lb spec_order if model == "Categorical" & spec_order == 5, horizontal ///
			lcolor(navy%45)) ///
		(scatter spec_order b if model == "Categorical" & spec_order == 5, ///
			msymbol(circle) mcolor(navy) msize(medium)), ///
		xline(0, lpattern(dash) lcolor(gs10)) ///
		ylabel(`spec_ylabels', angle(horizontal) labsize(small)) ///
		yscale(reverse range(0.2 5.4)) ///
		xlabel(-0.75(0.25)0.75, format(%4.2f) labsize(vsmall)) ///
		ytitle("") ///
		xtitle("Coefficient estimate") ///
		title("{bf:A}. Categorical Mn > 50 {&mu}gL{sup:-1}") ///
		legend(off) ///
		fxsize(58) ///
		graphregion(color(white) margin(zero)) ///
		plotregion(color(white) margin(zero)) ///
		name(Mn_alt_cat, replace)

	twoway ///
		(rcap ub lb spec_order if model == "LogMn" & spec_order != 5, horizontal ///
			lcolor(maroon%45)) ///
		(scatter spec_order b if model == "LogMn" & spec_order != 5, ///
			msymbol(circle) mcolor(maroon) msize(medium)) ///
		(rcap ub lb spec_order if model == "LogMn" & spec_order == 5, horizontal ///
			lcolor(navy%45)) ///
		(scatter spec_order b if model == "LogMn" & spec_order == 5, ///
			msymbol(circle) mcolor(navy) msize(medium)), ///
		xline(0, lpattern(dash) lcolor(gs10)) ///
		xlabel(-0.75(0.25)0.75, format(%4.2f) labsize(vsmall)) ///
		ylabel(none) ///
		yscale(reverse off range(0.6 5.4)) ///
		ytitle("") ///
		xtitle("Coefficient estimate") ///
		title("{bf:B}. log(Household Mn)") ///
		legend(off) ///
		fxsize(42) ///
		graphregion(color(white) margin(zero)) ///
		plotregion(color(white) margin(zero)) ///
		name(Mn_alt_log, replace)

	* Single twoway layout avoids graph combine's omitted-axis gutter.
	local xoffset 2
	local xr_m75 = `xoffset' - 0.75
	local xr_m50 = `xoffset' - 0.50
	local xr_m25 = `xoffset' - 0.25
	local xr_0 = `xoffset'
	local xr_25 = `xoffset' + 0.25
	local xr_50 = `xoffset' + 0.50
	local xr_75 = `xoffset' + 0.75
	local xmin = -0.90
	local xmax = `xoffset' + 0.90
	gen b_panel = b + cond(model == "LogMn", `xoffset', 0)
	gen lb_panel = lb + cond(model == "LogMn", `xoffset', 0)
	gen ub_panel = ub + cond(model == "LogMn", `xoffset', 0)

	twoway ///
		(rcap ub_panel lb_panel spec_order if model == "Categorical" & spec_order != 5, horizontal ///
			lcolor(maroon%45)) ///
		(scatter spec_order b_panel if model == "Categorical" & spec_order != 5, ///
			msymbol(circle) mcolor(maroon) msize(medium)) ///
		(rcap ub_panel lb_panel spec_order if model == "Categorical" & spec_order == 5, horizontal ///
			lcolor(navy%45)) ///
		(scatter spec_order b_panel if model == "Categorical" & spec_order == 5, ///
			msymbol(circle) mcolor(navy) msize(medium)) ///
		(rcap ub_panel lb_panel spec_order if model == "LogMn" & spec_order != 5, horizontal ///
			lcolor(maroon%45)) ///
		(scatter spec_order b_panel if model == "LogMn" & spec_order != 5, ///
			msymbol(circle) mcolor(maroon) msize(medium)) ///
		(rcap ub_panel lb_panel spec_order if model == "LogMn" & spec_order == 5, horizontal ///
			lcolor(navy%45)) ///
		(scatter spec_order b_panel if model == "LogMn" & spec_order == 5, ///
			msymbol(circle) mcolor(navy) msize(medium)) ///
		(pci 5.4 -0.75 5.4 0.75, lcolor(gs8) lwidth(thin)) ///
		(pci 5.4 `xr_m75' 5.4 `xr_75', lcolor(gs8) lwidth(thin)) ///
		(pci 0.65 0 5.4 0, lpattern(dash) lcolor(gs10)) ///
		(pci 0.65 `xoffset' 5.4 `xoffset', lpattern(dash) lcolor(gs10)) ///
		(pci 0.65 `xmin' 5.4 `xmin', lcolor(black) lwidth(thin)), ///
		xscale(range(`xmin' `xmax') noline) ///
		xlabel(-0.75 "-0.75" -0.50 "-0.50" -0.25 "-0.25" 0 "0.00" ///
			0.25 "0.25" 0.50 "0.50" 0.75 "0.75" ///
			`xr_m75' "-0.75" `xr_m50' "-0.50" `xr_m25' "-0.25" ///
			`xr_0' "0.00" `xr_25' "0.25" `xr_50' "0.50" ///
			`xr_75' "0.75", labsize(vsmall) nogrid) ///
		ylabel(`spec_ylabels', angle(horizontal) labsize(small)) ///
		yscale(reverse range(0 5.4) noline) ///
		ytitle("") ///
		xtitle("Coefficient estimate") ///
		text(0.35 0 "{bf:A}. Categorical Mn > 50 {&mu}gL{sup:-1}", ///
			place(c) size(medsmall)) ///
		text(0.35 `xoffset' "{bf:B}. log(Household Mn)", ///
			place(c) size(medsmall)) ///
		legend(off) ///
		graphregion(color(white) margin(zero)) ///
		plotregion(color(white) margin(zero)) ///
		xsize(8.5) ysize(4.5) ///
		name(Mn_alt_spec_coefplot, replace)

	graph export "../Output/Figures/FigS_Mn_AlternativeSpecifications_Coefplot.pdf", ///
		name(Mn_alt_spec_coefplot) as(pdf) replace
	graph export "../Output/Figures/FigS_Mn_AlternativeSpecifications_Coefplot.svg", ///
		name(Mn_alt_spec_coefplot) as(svg) replace
restore

codebook caregiver_id if switch_drink_wtr_dry==1
codebook caregiver_id if switch_drink_wtr_dry==0
**# Heterogeneity for switchers
**switchers during the dry season: switch_drink_wtr_dry
**see if the switchers are different given their current Mn exposure

**EPA Standard: >50 {&mu}gL{sup:-1}
local if_cond "(focal_child_yn==1|focal_child_yn==0)"
local cov_always "Batch treatment i.dist_code"
local cov "age_chld_months_EL child_male "
local cov_add "hh_learn_mca1 par_involv_mca1 own_house_BL own_land_BL nature_employ_ag_BL nature_employ_retail_BL nature_employ_service_BL high_education_primary_BL high_education_secondary_BL high_education_SSS_higher_BL annual_income_geq5k_BL recall_income_geq20k recall_income_geq10k recall_income_geq5k recall_income_bel5k"
local outcome z_irt_all_30_48m //hlth_stat_chld_healthier_BL child_dev_age_advanced_BL

capture drop switcher_dry Mn_EPA2 Mn_EPA3 Mn_EPA2_switch Mn_EPA3_switch logMn_switch
gen byte switcher_dry = switch_drink_wtr_dry == 1 if !missing(switch_drink_wtr_dry)
gen byte Mn_EPA2 = Mn_LOD_EPA == 2 if !missing(Mn_LOD_EPA)
gen byte Mn_EPA3 = Mn_LOD_EPA == 3 if !missing(Mn_LOD_EPA)
gen byte Mn_EPA2_switch = Mn_EPA2 * switcher_dry if !missing(Mn_EPA2, switcher_dry)
gen byte Mn_EPA3_switch = Mn_EPA3 * switcher_dry if !missing(Mn_EPA3, switcher_dry)
gen logMn_switch = log_Mn_LODsq2 * switcher_dry if !missing(log_Mn_LODsq2, switcher_dry)

local controls_1 "`cov_always'"
local controls_2 "`cov_always' `cov'"
local controls_3 "`cov_always' `cov' `cov_add'"

local spec_label_1 "No additional controls"
local spec_label_2 "+ Demographic controls"
local spec_label_3 "++ Economic controls"

tempfile switcher_results
tempname switcher_post

postfile `switcher_post' str12 model spec_order str30 spec_label ///
	byte switcher str15 switch_label b se lb ub p N r2 ///
	using `switcher_results', replace

foreach var of varlist `outcome' {
	forvalues spec = 1/3 {
		local rhs "`controls_`spec''"
		local spec_label "`spec_label_`spec''"

		reg `var' Mn_EPA2 Mn_EPA3 switcher_dry Mn_EPA2_switch Mn_EPA3_switch ///
			`rhs' if `if_cond', vce(cluster caregiver_id_BL)
		est store SwitchCat_spec`spec'

		quietly lincom Mn_EPA3
		local b = r(estimate)
		local se = r(se)
		local lb = `b' - invttail(e(df_r), 0.025) * `se'
		local ub = `b' + invttail(e(df_r), 0.025) * `se'
		local p = 2 * ttail(e(df_r), abs(`b' / `se'))
		post `switcher_post' ("Categorical") (`spec') ("`spec_label'") ///
			(0) ("Non-switcher") (`b') (`se') (`lb') (`ub') (`p') (e(N)) (e(r2))

		quietly lincom Mn_EPA3 + Mn_EPA3_switch
		local b = r(estimate)
		local se = r(se)
		local lb = `b' - invttail(e(df_r), 0.025) * `se'
		local ub = `b' + invttail(e(df_r), 0.025) * `se'
		local p = 2 * ttail(e(df_r), abs(`b' / `se'))
		post `switcher_post' ("Categorical") (`spec') ("`spec_label'") ///
			(1) ("Switcher") (`b') (`se') (`lb') (`ub') (`p') (e(N)) (e(r2))

		reg `var' log_Mn_LODsq2 switcher_dry logMn_switch `rhs' ///
			if `if_cond', vce(cluster caregiver_id_BL)
		est store SwitchLog_spec`spec'

		quietly lincom log_Mn_LODsq2
		local b = r(estimate)
		local se = r(se)
		local lb = `b' - invttail(e(df_r), 0.025) * `se'
		local ub = `b' + invttail(e(df_r), 0.025) * `se'
		local p = 2 * ttail(e(df_r), abs(`b' / `se'))
		post `switcher_post' ("LogMn") (`spec') ("`spec_label'") ///
			(0) ("Non-switcher") (`b') (`se') (`lb') (`ub') (`p') (e(N)) (e(r2))

		quietly lincom log_Mn_LODsq2 + logMn_switch
		local b = r(estimate)
		local se = r(se)
		local lb = `b' - invttail(e(df_r), 0.025) * `se'
		local ub = `b' + invttail(e(df_r), 0.025) * `se'
		local p = 2 * ttail(e(df_r), abs(`b' / `se'))
		post `switcher_post' ("LogMn") (`spec') ("`spec_label'") ///
			(1) ("Switcher") (`b') (`se') (`lb') (`ub') (`p') (e(N)) (e(r2))
	}
}

postclose `switcher_post'

preserve
	use `switcher_results', clear
	gen plot_y = spec_order
	replace plot_y = spec_order - 0.08 if switcher == 0
	replace plot_y = spec_order + 0.08 if switcher == 1

	label var model "Mn exposure model"
	label var spec_order "Control specification"
	label var spec_label "Control specification"
	label var switcher "Dry-season water switcher"
	label var switch_label "Dry-season water switcher"
	label var b "Total Mn effect"
	label var se "Standard error"
	label var lb "95% CI lower bound"
	label var ub "95% CI upper bound"
	label var p "P-value"
	label var N "N (Children)"
	label var r2 "R-squared"
	format b se lb ub p r2 %9.3f

	export delimited using ///
		"../Output/Tables/TableS_Mn_Switcher_Heterogeneity_Estimates.csv", ///
		replace

	local spec_ylabels ///
		1 "No additional controls" ///
		2 "+ Demographic controls" ///
		3 "++ Economic controls"

	twoway ///
		(rcap ub lb plot_y if model == "Categorical" & switcher == 0, horizontal ///
			lcolor(navy%40)) ///
		(connected plot_y b if model == "Categorical" & switcher == 0, ///
			lcolor(navy) mcolor(navy) msymbol(circle) msize(medium)) ///
		(rcap ub lb plot_y if model == "Categorical" & switcher == 1, horizontal ///
			lcolor(maroon%40)) ///
		(connected plot_y b if model == "Categorical" & switcher == 1, ///
			lcolor(maroon) mcolor(maroon) msymbol(square) msize(medium)), ///
		xline(0, lpattern(dash) lcolor(gs10)) ///
		ylabel(`spec_ylabels', angle(horizontal) labsize(small)) ///
		yscale(reverse range(0.2 3.4)) ///
		xlabel(, format(%4.2f) labsize(small)) ///
		ytitle("") ///
		xtitle("Total Mn effect") ///
		title("{bf:A}. Categorical Mn > 50 {&mu}gL{sup:-1}") ///
		legend(order(2 "Non-switcher" 4 "Switcher") pos(6) col(2)) ///
		fxsize(58) ///
		graphregion(color(white) margin(zero)) ///
		plotregion(color(white) margin(zero)) ///
		name(Mn_switch_cat, replace)

	twoway ///
		(rcap ub lb plot_y if model == "LogMn" & switcher == 0, horizontal ///
			lcolor(navy%40)) ///
		(connected plot_y b if model == "LogMn" & switcher == 0, ///
			lcolor(navy) mcolor(navy) msymbol(circle) msize(medium)) ///
		(rcap ub lb plot_y if model == "LogMn" & switcher == 1, horizontal ///
			lcolor(maroon%40)) ///
		(connected plot_y b if model == "LogMn" & switcher == 1, ///
			lcolor(maroon) mcolor(maroon) msymbol(square) msize(medium)), ///
		xline(0, lpattern(dash) lcolor(gs10)) ///
		ylabel(none) ///
		yscale(reverse off range(0.6 3.4)) ///
		xlabel(, format(%4.2f) labsize(small)) ///
		ytitle("") ///
		xtitle("Total Mn effect") ///
		title("{bf:B}. log(Household Mn)") ///
		legend(off) ///
		fxsize(42) ///
		graphregion(color(white) margin(zero)) ///
		plotregion(color(white) margin(zero)) ///
		name(Mn_switch_log, replace)

	* Single twoway layout avoids graph combine's omitted-axis gutter.
	local xoffset 2.4
	local xr_m100 = `xoffset' - 1.00
	local xr_m50 = `xoffset' - 0.50
	local xr_0 = `xoffset'
	local xr_50 = `xoffset' + 0.50
	local xr_100 = `xoffset' + 1.00
	local xmin = -1.15
	local xmax = `xoffset' + 1.15
	gen b_panel = b + cond(model == "LogMn", `xoffset', 0)
	gen lb_panel = lb + cond(model == "LogMn", `xoffset', 0)
	gen ub_panel = ub + cond(model == "LogMn", `xoffset', 0)

	twoway ///
		(rcap ub_panel lb_panel plot_y if model == "Categorical" & switcher == 0, horizontal ///
			lcolor(navy%40)) ///
		(connected plot_y b_panel if model == "Categorical" & switcher == 0, ///
			lcolor(navy) mcolor(navy) msymbol(circle) msize(medium)) ///
		(rcap ub_panel lb_panel plot_y if model == "Categorical" & switcher == 1, horizontal ///
			lcolor(maroon%40)) ///
		(connected plot_y b_panel if model == "Categorical" & switcher == 1, ///
			lcolor(maroon) mcolor(maroon) msymbol(square) msize(medium)) ///
		(rcap ub_panel lb_panel plot_y if model == "LogMn" & switcher == 0, horizontal ///
			lcolor(navy%40)) ///
		(connected plot_y b_panel if model == "LogMn" & switcher == 0, ///
			lcolor(navy) mcolor(navy) msymbol(circle) msize(medium)) ///
		(rcap ub_panel lb_panel plot_y if model == "LogMn" & switcher == 1, horizontal ///
			lcolor(maroon%40)) ///
		(connected plot_y b_panel if model == "LogMn" & switcher == 1, ///
			lcolor(maroon) mcolor(maroon) msymbol(square) msize(medium)) ///
		(pci 3.4 -1.00 3.4 1.00, lcolor(gs8) lwidth(thin)) ///
		(pci 3.4 `xr_m100' 3.4 `xr_100', lcolor(gs8) lwidth(thin)) ///
		(pci 0.65 0 3.4 0, lpattern(dash) lcolor(gs10)) ///
		(pci 0.65 `xoffset' 3.4 `xoffset', lpattern(dash) lcolor(gs10)) ///
		(pci 0.65 `xmin' 3.4 `xmin', lcolor(black) lwidth(thin)), ///
		xscale(range(`xmin' `xmax') noline) ///
		xlabel(-1.00 "-1.00" -0.50 "-0.50" 0 "0.00" 0.50 "0.50" ///
			1.00 "1.00" `xr_m100' "-1.00" `xr_m50' "-0.50" ///
			`xr_0' "0.00" `xr_50' "0.50" `xr_100' "1.00", ///
			labsize(small) nogrid) ///
		ylabel(`spec_ylabels', angle(horizontal) labsize(small)) ///
		yscale(reverse range(0 3.4) noline) ///
		ytitle("") ///
		xtitle("Total Mn effect") ///
		text(0.35 0 "{bf:A}. Categorical Mn > 50 {&mu}gL{sup:-1}", ///
			place(c) size(medsmall)) ///
		text(0.35 `xoffset' "{bf:B}. log(Household Mn)", ///
			place(c) size(medsmall)) ///
		legend(order(2 "Non-switcher" 4 "Switcher") pos(6) col(2)) ///
		graphregion(color(white) margin(zero)) ///
		plotregion(color(white) margin(zero)) ///
		xsize(8.5) ysize(4.5) ///
		name(Mn_switcher_heterogeneity, replace)

	graph export "../Output/Figures/FigS_Mn_Switcher_Heterogeneity_Coefplot.pdf", ///
		name(Mn_switcher_heterogeneity) as(pdf) replace
	graph export "../Output/Figures/FigS_Mn_Switcher_Heterogeneity_Coefplot.svg", ///
		name(Mn_switcher_heterogeneity) as(svg) replace
restore



**# Sample representativeness: ours vs. DHS (Western North, Rural, National)
**DHS: focus on households with children under 5 and alive and live with their parents - to align with our sample interests; if there are multiple living child satisfy this category within the household, then we will take the youngest one
**Household Outcome: language, household size, number of children in household, respondent age, respondent nature of employment, respondent education, land ownership
**Child outcome: child is female, child age in month

local dhs_dir "C:\Users\liu.7133\OneDrive - The Ohio State University\Nigeria Fuel Subsidy and Child Health\Data\DHS\Ghana_DHS_2022_Stata"
local western_north 7
local rural 2

tempfile study_repr dhs_kr_child_repr dhs_kr_woman_repr dhs_hr_repr dhs_hh_eligible repr_results

use "../Processed Stata Dta/Test Results Merged with EL Child Development.dta", clear

capture confirm variable child_female
if _rc {
	gen byte child_female = child_male == 0 if !missing(child_male)
}
capture destring num_chld_hsehld_17 num_chld_hsehld_5_BL, replace
capture confirm variable own_land_BL
if _rc {
	gen byte own_land_BL = own_agric_land_BL != 4 if !missing(own_agric_land_BL)
}

capture drop study_work_for_pay study_language_akan study_water_*
gen byte study_work_for_pay = nature_employ_unemp == 0 if !missing(nature_employ_unemp)
gen byte study_language_akan = main_lang_chld_comm_Twi_BL == 1 ///
	if !missing(main_lang_chld_comm_Twi_BL)
capture confirm variable main_lang_chld_comm_Sef_BL
if !_rc {
	replace study_language_akan = 1 if main_lang_chld_comm_Sef_BL == 1
}

capture drop sample_water_source_brief
recode sample_water_source ///
	(1 = 1 "Borehole") ///
	(2 = 2 "River") ///
	(3 4 8 = 3 "Piped water") ///
	(5 = 4 "Well") ///
	(6 = 6 "Rainwater") ///
	(7 = 5 "Sachet"), gen(sample_water_source_brief)
gen byte study_water_borehole = sample_water_source_brief == 1 if !missing(sample_water_source_brief)
gen byte study_water_river = sample_water_source_brief == 2 if !missing(sample_water_source_brief)
gen byte study_water_pipe = sample_water_source_brief == 3 if !missing(sample_water_source_brief)
gen byte study_water_well = sample_water_source_brief == 4 if !missing(sample_water_source_brief)
gen byte study_water_sachet = sample_water_source_brief == 5 if !missing(sample_water_source_brief)
gen byte study_water_rain = sample_water_source_brief == 6 if !missing(sample_water_source_brief)

capture confirm variable treat_drink_water_boil
if _rc {
	gen byte treat_drink_water_boil = means_treat_cook_1 == 1 if !missing(means_treat_cook_1)
}
capture confirm variable treat_drink_water_filt
if _rc {
	gen byte treat_drink_water_filt = means_treat_cook_3 == 1 if !missing(means_treat_cook_3)
}
capture confirm variable treat_drink_water_chlor
if _rc {
	gen byte treat_drink_water_chlor = means_treat_cook_4 == 1 if !missing(means_treat_cook_4)
}

save `study_repr', replace

use "`dhs_dir'\GHKR8CDT\GHKR8CFL.DTA", clear

capture confirm variable b19
if !_rc {
	gen child_age_month = b19
}
else {
	gen interview_date = mdy(v006, v016, v007)
	gen child_dob = mdy(b1, b17, b2)
	gen child_age_month = floor((interview_date - child_dob) / 30)
}

keep if b5 == 1 & b9 == 0 & child_age_month < 60

gen dhs_wt = v005 / 1000000
gen byte child_female = b4 == 2 if !missing(b4)
gen respondent_age = v012
gen byte work_for_pay_p7d = v714 == 1 & inrange(v741, 1, 3) if !missing(v714)
gen byte employ_ag = inlist(v717, 4, 5) if !missing(v717)
gen byte employ_retail = v717 == 3 if !missing(v717)
gen byte employ_service = v717 == 7 if !missing(v717)
gen byte edu_primary = v106 == 1 if !missing(v106)
gen byte edu_secondary = v106 == 2 if !missing(v106)
gen byte edu_seniorhigh = v106 == 3 if !missing(v106)

// sefwi/fanti/fante are all Akan language
gen byte language_english = v045c == 1 if !missing(v045c)
gen byte language_akan = v045c == 2 if !missing(v045c)

preserve
	keep v001 v002
	duplicates drop
	rename v001 hv001
	rename v002 hv002
	save `dhs_hh_eligible', replace
restore

save `dhs_kr_child_repr', replace

egen respondent_group = group(v001 v002 v003)
bysort respondent_group: keep if _n == 1
save `dhs_kr_woman_repr', replace

use "`dhs_dir'\GHHR8CDT\GHHR8CFL.DTA", clear
merge 1:1 hv001 hv002 using `dhs_hh_eligible', keep(match) nogen

gen dhs_wt = hv005 / 1000000
gen hh_size = hv009
gen num_under5 = hv014
gen byte own_ag_land = hv244 == 1 if !missing(hv244)

gen byte water_pipe = inlist(hv201, 11, 12, 13, 14) if !missing(hv201)
gen byte water_borehole = hv201 == 21 if !missing(hv201)
gen byte water_well = inlist(hv201, 31, 32) if !missing(hv201)
gen byte water_river = inlist(hv201, 43) if !missing(hv201)
gen byte water_rain = hv201 == 51 if !missing(hv201)
gen byte water_sachet = inlist(hv201, 71, 72) if !missing(hv201)

gen byte treat_water = hv237 == 1 if inlist(hv237, 0, 1)
gen byte treat_water_boil = hv237a == 1 if inlist(hv237a, 0, 1)
gen byte treat_water_chlorine = hv237b == 1 if inlist(hv237b, 0, 1)
gen byte treat_water_filter = .
replace treat_water_filter = 1 if hv237c == 1 | hv237d == 1
replace treat_water_filter = 0 if hv237c == 0 & hv237d == 0

save `dhs_hr_repr', replace

capture program drop repr_mean
program define repr_mean, rclass
	syntax, FRAME(name) VAR(name) [COND(string) WEIGHT(name)]

	local oldframe "`c(frame)'"
	frame change `frame'
	capture confirm variable `var'
	if _rc {
		return scalar mean = .
		return scalar N = 0
		frame change `oldframe'
		exit
	}

	if `"`cond'"' == "" {
		local cond "1"
	}

	if "`weight'" == "" {
		quietly summarize `var' if (`cond') & !missing(`var')
		return scalar mean = r(mean)
		return scalar sd = r(sd)
		return scalar N = r(N)
	}
	else {
		capture quietly summarize `var' [aw=`weight'] ///
			if (`cond') & !missing(`var')
		if _rc {
			return scalar mean = .
			return scalar sd = .
			return scalar N = 0
		}
		else {
			return scalar mean = r(mean)
			return scalar sd = r(sd)
			return scalar N = r(N)
		}
	}
	frame change `oldframe'
end

capture program drop repr_count
program define repr_count, rclass
	syntax, FRAME(name) [COND(string)]

	local oldframe "`c(frame)'"
	frame change `frame'
	if `"`cond'"' == "" {
		local cond "1"
	}
	quietly count if (`cond')
	return scalar N = r(N)
	frame change `oldframe'
end

capture program drop repr_cell
program define repr_cell, rclass
	args mean sd

	if missing(`mean') {
		return local cell ""
	}
	else {
		local mean_str : display %9.3f `mean'
		local mean_str = strtrim("`mean_str'")
		local sd_str : display %9.3f `sd'
		local sd_str = strtrim("`sd_str'")
		return local cell "`mean_str'\line (`sd_str')"
	}
end

capture program drop repr_post_row
program define repr_post_row
	syntax, POST(name) GROUP(string) ROW(string) STUDYVAR(name) ///
		DHSFRAME(name) DHSVAR(name) REGIONVAR(name) RESVAR(name) ///
		[STUDYCOND(string)]

	if `"`studycond'"' == "" {
		local studycond "focal_child_yn == 1"
	}

	repr_mean, frame(study_repr) var(`studyvar') cond(`"`studycond'"')
	repr_cell `=r(mean)' `=r(sd)'
	local ours `"`r(cell)'"'

	repr_mean, frame(`dhsframe') var(`dhsvar') ///
		cond("`regionvar' == 7") weight(dhs_wt)
	repr_cell `=r(mean)' `=r(sd)'
	local dhs_wn `"`r(cell)'"'

	repr_mean, frame(`dhsframe') var(`dhsvar') ///
		cond("`resvar' == 2") weight(dhs_wt)
	repr_cell `=r(mean)' `=r(sd)'
	local dhs_rural `"`r(cell)'"'

	repr_mean, frame(`dhsframe') var(`dhsvar') cond("1") weight(dhs_wt)
	repr_cell `=r(mean)' `=r(sd)'
	local dhs_ghana `"`r(cell)'"'

	post `post' (`"`group'"') (`"`row'"') (`"`ours'"') (`"`dhs_wn'"') ///
		(`"`dhs_rural'"') (`"`dhs_ghana'"')
end

capture frame drop study_repr
capture frame drop dhs_kr_child_repr
capture frame drop dhs_kr_woman_repr
capture frame drop dhs_hr_repr
frame create study_repr
frame study_repr: use `study_repr', clear
frame create dhs_kr_child_repr
frame dhs_kr_child_repr: use `dhs_kr_child_repr', clear
frame create dhs_kr_woman_repr
frame dhs_kr_woman_repr: use `dhs_kr_woman_repr', clear
frame create dhs_hr_repr
frame dhs_hr_repr: use `dhs_hr_repr', clear

tempname repr_post
postfile `repr_post' str20 group str70 characteristic ///
	str25 our_study str25 dhs_western_north str25 dhs_rural ///
	str25 dhs_ghana ///
	using `repr_results', replace

repr_post_row, post(`repr_post') group("Child") ///
	row("Child is female") studyvar(child_female) ///
	dhsframe(dhs_kr_child_repr) dhsvar(child_female) regionvar(v024) resvar(v025) ///
	studycond("focal_child_yn == 1 | focal_child_yn == 0")
repr_post_row, post(`repr_post') group("Child") ///
	row("Child age in months") studyvar(age_chld_months_EL) ///
	dhsframe(dhs_kr_child_repr) dhsvar(child_age_month) regionvar(v024) resvar(v025) ///
	studycond("focal_child_yn == 1 | focal_child_yn == 0")

repr_post_row, post(`repr_post') group("Woman/respondent") ///
	row("Respondent/caregiver age") studyvar(age_BL) ///
	dhsframe(dhs_kr_woman_repr) dhsvar(respondent_age) regionvar(v024) resvar(v025)
repr_post_row, post(`repr_post') group("Woman/respondent") ///
	row("Works for pay/currently employed") studyvar(study_work_for_pay) ///
	dhsframe(dhs_kr_woman_repr) dhsvar(work_for_pay_p7d) regionvar(v024) resvar(v025)
repr_post_row, post(`repr_post') group("Woman/respondent") ///
	row("Employment: agriculture") studyvar(nature_employ_ag_BL) ///
	dhsframe(dhs_kr_woman_repr) dhsvar(employ_ag) regionvar(v024) resvar(v025)
repr_post_row, post(`repr_post') group("Woman/respondent") ///
	row("Employment: retail/sales") studyvar(nature_employ_retail_BL) ///
	dhsframe(dhs_kr_woman_repr) dhsvar(employ_retail) regionvar(v024) resvar(v025)
repr_post_row, post(`repr_post') group("Woman/respondent") ///
	row("Employment: service") studyvar(nature_employ_service_BL) ///
	dhsframe(dhs_kr_woman_repr) dhsvar(employ_service) regionvar(v024) resvar(v025)
repr_post_row, post(`repr_post') group("Woman/respondent") ///
	row("Education: primary") studyvar(high_education_primary_BL) ///
	dhsframe(dhs_kr_woman_repr) dhsvar(edu_primary) regionvar(v024) resvar(v025)
repr_post_row, post(`repr_post') group("Woman/respondent") ///
	row("Education: secondary") studyvar(high_education_secondary_BL) ///
	dhsframe(dhs_kr_woman_repr) dhsvar(edu_secondary) regionvar(v024) resvar(v025)
repr_post_row, post(`repr_post') group("Woman/respondent") ///
	row("Education: SSS/higher") studyvar(high_education_SSS_higher_BL) ///
	dhsframe(dhs_kr_woman_repr) dhsvar(edu_seniorhigh) regionvar(v024) resvar(v025)
repr_post_row, post(`repr_post') group("Woman/respondent") ///
	row("Language: English") studyvar(main_lang_chld_comm_Eng_BL) ///
	dhsframe(dhs_kr_woman_repr) dhsvar(language_english) regionvar(v024) resvar(v025)
repr_post_row, post(`repr_post') group("Woman/respondent") ///
	row("Language: Akan/Twi/Sefwi") studyvar(study_language_akan) ///
	dhsframe(dhs_kr_woman_repr) dhsvar(language_akan) regionvar(v024) resvar(v025)

repr_post_row, post(`repr_post') group("Household") ///
	row("Household size") studyvar(num_pple_hsehld_BL) ///
	dhsframe(dhs_hr_repr) dhsvar(hh_size) regionvar(hv024) resvar(hv025)
repr_post_row, post(`repr_post') group("Household") ///
	row("Number of under-five children") studyvar(num_chld_hsehld_5_BL) ///
	dhsframe(dhs_hr_repr) dhsvar(num_under5) regionvar(hv024) resvar(hv025)
repr_post_row, post(`repr_post') group("Household") ///
	row("Owns land") studyvar(own_land_BL) ///
	dhsframe(dhs_hr_repr) dhsvar(own_ag_land) regionvar(hv024) resvar(hv025)
repr_post_row, post(`repr_post') group("Household") ///
	row("Drinking water source: piped water") studyvar(study_water_pipe) ///
	dhsframe(dhs_hr_repr) dhsvar(water_pipe) regionvar(hv024) resvar(hv025)
repr_post_row, post(`repr_post') group("Household") ///
	row("Drinking water source: borehole") studyvar(study_water_borehole) ///
	dhsframe(dhs_hr_repr) dhsvar(water_borehole) regionvar(hv024) resvar(hv025)
repr_post_row, post(`repr_post') group("Household") ///
	row("Drinking water source: well") studyvar(study_water_well) ///
	dhsframe(dhs_hr_repr) dhsvar(water_well) regionvar(hv024) resvar(hv025)
repr_post_row, post(`repr_post') group("Household") ///
	row("Drinking water source: river/surface water") studyvar(study_water_river) ///
	dhsframe(dhs_hr_repr) dhsvar(water_river) regionvar(hv024) resvar(hv025)
repr_post_row, post(`repr_post') group("Household") ///
	row("Drinking water source: rainwater") studyvar(study_water_rain) ///
	dhsframe(dhs_hr_repr) dhsvar(water_rain) regionvar(hv024) resvar(hv025)
repr_post_row, post(`repr_post') group("Household") ///
	row("Drinking water source: sachet") studyvar(study_water_sachet) ///
	dhsframe(dhs_hr_repr) dhsvar(water_sachet) regionvar(hv024) resvar(hv025)
repr_post_row, post(`repr_post') group("Household") ///
	row("Treats drinking water") studyvar(treat_drink_water_yn) ///
	dhsframe(dhs_hr_repr) dhsvar(treat_water) regionvar(hv024) resvar(hv025)
repr_post_row, post(`repr_post') group("Household") ///
	row("Water treatment: boiling") studyvar(treat_drink_water_boil) ///
	dhsframe(dhs_hr_repr) dhsvar(treat_water_boil) regionvar(hv024) resvar(hv025)
repr_post_row, post(`repr_post') group("Household") ///
	row("Water treatment: chlorine") studyvar(treat_drink_water_chlor) ///
	dhsframe(dhs_hr_repr) dhsvar(treat_water_chlorine) regionvar(hv024) resvar(hv025)
repr_post_row, post(`repr_post') group("Household") ///
	row("Water treatment: filter/strain") studyvar(treat_drink_water_filt) ///
	dhsframe(dhs_hr_repr) dhsvar(treat_water_filter) regionvar(hv024) resvar(hv025)

postclose `repr_post'

use `repr_results', clear
gen row_order = _n
order row_order group characteristic our_study dhs_western_north dhs_rural dhs_ghana

repr_count, frame(study_repr) cond("focal_child_yn == 1 | focal_child_yn == 0")
local N_child_ours : display %9.0f r(N)
local N_child_ours = strtrim("`N_child_ours'")
repr_count, frame(dhs_kr_child_repr) cond("v024 == 7")
local N_child_wn : display %9.0f r(N)
local N_child_wn = strtrim("`N_child_wn'")
repr_count, frame(dhs_kr_child_repr) cond("v025 == 2")
local N_child_rural : display %9.0f r(N)
local N_child_rural = strtrim("`N_child_rural'")
repr_count, frame(dhs_kr_child_repr) cond("1")
local N_child_ghana : display %9.0f r(N)
local N_child_ghana = strtrim("`N_child_ghana'")

repr_count, frame(study_repr) cond("focal_child_yn == 1")
local N_hh_ours : display %9.0f r(N)
local N_hh_ours = strtrim("`N_hh_ours'")
repr_count, frame(dhs_hr_repr) cond("hv024 == 7")
local N_hh_wn : display %9.0f r(N)
local N_hh_wn = strtrim("`N_hh_wn'")
repr_count, frame(dhs_hr_repr) cond("hv025 == 2")
local N_hh_rural : display %9.0f r(N)
local N_hh_rural = strtrim("`N_hh_rural'")
repr_count, frame(dhs_hr_repr) cond("1")
local N_hh_ghana : display %9.0f r(N)
local N_hh_ghana = strtrim("`N_hh_ghana'")

tempname rtf
file open `rtf' using "../Output/Tables/TableS_SampleRepresentativeness_DHS.rtf", ///
	write text replace
file write `rtf' "{\rtf1\ansi\deff0" _n
file write `rtf' "{\fonttbl{\f0 Times New Roman;}}" _n
file write `rtf' "\fs20" _n

local rowdef "\trowd\trgaph108\trleft0\clbrdrt\brdrs\brdrw10\clbrdrl\brdrs\brdrw10\clbrdrb\brdrs\brdrw10\clbrdrr\brdrs\brdrw10\cellx3000\clbrdrt\brdrs\brdrw10\clbrdrl\brdrs\brdrw10\clbrdrb\brdrs\brdrw10\clbrdrr\brdrs\brdrw10\cellx4500\clbrdrt\brdrs\brdrw10\clbrdrl\brdrs\brdrw10\clbrdrb\brdrs\brdrw10\clbrdrr\brdrs\brdrw10\cellx6300\clbrdrt\brdrs\brdrw10\clbrdrl\brdrs\brdrw10\clbrdrb\brdrs\brdrw10\clbrdrr\brdrs\brdrw10\cellx7900\clbrdrt\brdrs\brdrw10\clbrdrl\brdrs\brdrw10\clbrdrb\brdrs\brdrw10\clbrdrr\brdrs\brdrw10\cellx9500"

file write `rtf' "`rowdef'" _n
file write `rtf' "\intbl\qc\b \cell \intbl\qc\b (1)\cell \intbl\qc\b (2)\cell \intbl\qc\b (3)\cell \intbl\qc\b (4)\cell\row" _n

file write `rtf' "`rowdef'" _n
file write `rtf' "\intbl\ql\b Variable\b0\cell" ///
	"\intbl\qc\b Our study\b0\line Mean/(SD)\cell" ///
	"\intbl\qc\b DHS - Western North\b0\line Mean/(SD)\cell" ///
	"\intbl\qc\b DHS - rural\b0\line Mean/(SD)\cell" ///
	"\intbl\qc\b DHS - Ghana\b0\line Mean/(SD)\cell\row" _n

local last_group ""
forvalues r = 1/`=_N' {
	local group_r = group[`r']
	local char_r = characteristic[`r']
	local our_r = our_study[`r']
	local wn_r = dhs_western_north[`r']
	local rural_r = dhs_rural[`r']
	local ghana_r = dhs_ghana[`r']

	if "`group_r'" != "`last_group'" {
		file write `rtf' "`rowdef'" _n
		file write `rtf' "\intbl\ql\b `group_r'\b0\cell \intbl\qc \cell \intbl\qc \cell \intbl\qc \cell \intbl\qc \cell\row" _n
		local last_group "`group_r'"
	}

	file write `rtf' "`rowdef'" _n
	file write `rtf' "\intbl\ql `char_r'\cell" ///
		"\intbl\qc `our_r'\cell" ///
		"\intbl\qc `wn_r'\cell" ///
		"\intbl\qc `rural_r'\cell" ///
		"\intbl\qc `ghana_r'\cell\row" _n
}

file write `rtf' "`rowdef'" _n
file write `rtf' "\intbl\ql\b Number of children\b0\cell" ///
	"\intbl\qc `N_child_ours'\cell" ///
	"\intbl\qc `N_child_wn'\cell" ///
	"\intbl\qc `N_child_rural'\cell" ///
	"\intbl\qc `N_child_ghana'\cell\row" _n

file write `rtf' "`rowdef'" _n
file write `rtf' "\intbl\ql\b Number of households\b0\cell" ///
	"\intbl\qc `N_hh_ours'\cell" ///
	"\intbl\qc `N_hh_wn'\cell" ///
	"\intbl\qc `N_hh_rural'\cell" ///
	"\intbl\qc `N_hh_ghana'\cell\row" _n

file write `rtf' "}" _n
file close `rtf'
