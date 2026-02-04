/* Sachet Water Specifics */

use "../Original Data\Sachet Test Results_Only.dta", clear
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

graph export "..\Output\Figures\Fig3_Sachet_Mn_Concentration_FDARegistration.pdf", ///
	as(pdf) name(Sachet_Mn) replace
graph export "..\Output\Figures\Fig3_Sachet_Mn_Concentration_FDARegistration.svg", ///
	as(svg) name(Sachet_Mn) replace

