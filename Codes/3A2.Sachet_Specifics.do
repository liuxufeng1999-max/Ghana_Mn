/* Sachet Water Specifics */

use "../Processed Stata Dta\Sachet Test Results_Only.dta", clear
twoway ///
    (bar Mn_plot x if FDA_registered==0, color(gs12)) ///
    (bar Mn_plot x if FDA_registered==1, color(navy)) ///
    (scatter ylab x if Mn==0, msymbol(none) mlabel(lodlab) mlabpos(12) mlabsize(vsmall)), ///
    legend(order(2 1) label(1 "Not registered") label(2 "FDA registered") pos(6) col(2)) ///
    xlabel(1(1)15, valuelabel angle(30)) ///
	 yline(50, lcolor(red)) yline(80, lcolor(navy) lpattern(dash_dot)) ///
	ylabel(0 50 "USEPA" 80 "WHO" 100 150 200 250 300) ///
    xtitle("Sachet sample ID (stars indicate same brand)") ///
    ytitle("Mn concentration ({&mu}g/L)") ///
	name(Sachet_Mn, replace)

graph export "..\Output\Figures\Sachet_Mn_Concentration_FDARegistration.pdf", ///
	as(pdf) name(Sachet_Mn) replace
graph export "..\Output\Figures\Sachet_Mn_Concentration_FDARegistration.svg", ///
	as(svg) name(Sachet_Mn) replace
/*
capture drop ylab
capture drop lodlab
gen ylab = Mn_plot + `eps'*0.4
gen str20 lodlab = ""
replace lodlab = "<LOD" if Mn==0

//there are two brands that are sampled twice
bysort sachet_brand_ID: gen rep = _n if sachet_yn==1
bysort sachet_brand_ID: gen nbrand = _N if sachet_yn==1
egen x = group(sachet_brand_ID rep), label
gen str80 xlab = sachet_brand_name


levelsof x, local(xs)
tempname lbl
capture label define Xlbl 0 ""
capture label define Xlbl 0 "", replace
foreach xi of local xs {
    quietly  summarize sachet_brand_ID if x==`xi', meanonly
    local b = r(mean)
    local nm : label (sachet_brand_ID) `b'
    label define Xlbl `xi' "`nm'", add
}
label values x Xlbl

twoway ///
    (bar Mn_plot x if FDA_registered==0, color(gs12)) ///
    (bar Mn_plot x if FDA_registered==1, color(navy)  ) ///
    (scatter ylab x if Mn==0, msymbol(none) ///
        mlabel(lodlab) mlabpos(12) mlabsize(vsmall)), ///
    legend(order(2 "FDA registered" 1 "Not registered") pos(6) col(2)) ///
    yline(50, lcolor(red)) yline(80, lcolor(navy) lpattern(dash_dot)) ///
	ylabel(0 50 "USEPA" 80 "WHO" 100 150 200 250 300) ///
	xlabel(1(1)15, angle(45)) ///
    xtitle("Brand (each sample shown separately)") ///
    ytitle("Mn concentration")









twoway ///
    (bar Mn_plot sachet_brand_ID if FDA_registered==0, color(gs12)) ///
    (bar Mn_plot sachet_brand_ID if FDA_registered==1, color(navy)) ///
    (scatter ylab sachet_brand_ID if Mn==0, msymbol(none) ///
        mlabel(lodlab) mlabpos(12) mlabsize(vsmall)), ///
    legend(order(2 "FDA registered" 1 "Not registered")) ///
    xlabel(1(1)13, angle(45)) ///
    ytitle("Mn concentration") ///
    xtitle("Sample ID")

twoway ///
	(bar Mn sachet_brand_ID if FDA_registered==0, color(gs12)) ///
	(bar Mn sachet_brand_ID if FDA_registered==1, color(navy)), ///
	legend(order(2 "FDA registered" 1 "Not registered")) ///
	xlabel(, angle(45)) ///
	ytitle("Mn concentration") ///
	xtitle("Sample ID")

