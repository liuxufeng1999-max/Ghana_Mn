/* Sachet Water Specifics */

use "../Original Data/Sachet Test Results_Only.dta", clear
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

graph export "../Output/Figures/Fig3_Sachet_Mn_Concentration_FDARegistration.pdf", ///
	as(pdf) name(Sachet_Mn) replace
graph export "../Output/Figures/Fig3_Sachet_Mn_Concentration_FDARegistration.svg", ///
	as(svg) name(Sachet_Mn) replace

* Cleveland dot plot: sample IDs on y-axis, Mn concentration on x-axis
sum Mn_plot if FDA_registered==0, meanonly
local mean_x_not_registered = r(mean)
sum Mn_plot if FDA_registered==1, meanonly
local mean_x_registered = r(mean)
twoway ///
    (scatter x Mn_plot if FDA_registered==0, ///
        msymbol(circle) mcolor(gs12) msize(medium)) ///
    (scatter x Mn_plot if FDA_registered==1, ///
        msymbol(circle) mcolor(navy) msize(medium)) ///
    (scatter x Mn_plot if Mn==0, ///
        msymbol(none) mlabel(lodlab) mlabpos(3) mlabsize(vsmall)) ///
    (function y=., range(0 0) lcolor(gs12) lpattern(dash)) ///
    (function y=., range(0 0) lcolor(navy) lpattern(dash)), ///
    legend(order(1 2 4 5) ///
        label(1 "Not registered") ///
        label(2 "FDA registered") ///
        label(4 "Mean: Not registered") ///
        label(5 "Mean: FDA registered") ///
        ring(0) pos(4) row(4)) ///
    ylabel(1(1)15, valuelabel angle(0) labsize(small) nolabel) ///
    xline(`mean_x_not_registered', lcolor(gs12) lpattern(dash)) ///
    xline(`mean_x_registered', lcolor(navy) lpattern(dash)) ///
    xline(50, lcolor(red)) ///
    xline(80, lcolor(navy) lpattern(dash_dot)) ///
    xlabel(0 50 "USEPA" 80 "WHO" 100 150 200 250 300, angle(30) labsize(small)) ///
    ytitle("Sachet water sample") ///
    xtitle("") ///
    ysize(5.5) ///
    name(Sachet_Mn_cleveland, replace)
graph export "../Output/Figures/Fig3_Sachet_Mn_Concentration_FDARegistration_Cleveland.pdf", ///
	as(pdf) name(Sachet_Mn_cleveland) replace
graph export "../Output/Figures/Fig3_Sachet_Mn_Concentration_FDARegistration_Cleveland.svg", ///
	as(svg) name(Sachet_Mn_cleveland) replace

    /*
* ── Horizontal box plot: FDA registered (n=1) vs. unregistered (n=14) ───────
* Note: graph hbox makes Mn concentration the x-axis, matching Cleveland above.
* Note: with n=1 in registered group, Wilcoxon min. achievable p ≈ 0.13 —
*       significance is structurally unattainable; stars shown for reference.

* Wilcoxon rank-sum (ttest undefined when one group has n=1)
ranksum Mn_plot, by(FDA_registered)
local pval = r(p)

if      `pval' < 0.001  local stars "***"
else if `pval' < 0.01   local stars "**"
else if `pval' < 0.05   local stars "*"
else                     local stars "n.s."

* Mean difference: registered minus unregistered
qui sum Mn_plot if FDA_registered == 0
local mean0 = r(mean)
qui sum Mn_plot if FDA_registered == 1
local mean1 = r(mean)
local diff_fmt : display %4.1f (`mean1' - `mean0')

graph hbox Mn_plot, ///
    over(FDA_registered, ///
         relabel(1 "Not registered (n=14)" 2 "FDA registered (n=1)")) ///
    yline(50, lcolor(red) lwidth(thin)) ///
    yline(80, lcolor(navy) lpattern(dash_dot) lwidth(thin)) ///
    ylabel(0 50 "USEPA" 80 "WHO" 100 150 200 250 300, angle(30) labsize(small)) ///
    ytitle("Mn concentration ({&mu}g/L)") ///
    subtitle("{&Delta} = `diff_fmt' `stars'  (Wilcoxon rank-sum)", ///
             size(small) pos(12)) ///
    note("Min. achievable p {&asymp} 0.13 with n=1 vs. n=14", size(vsmall)) ///
    ysize(2.5) ///
    name(Sachet_hbox, replace)

graph export "../Output/Figures/Fig3c_Sachet_Mn_FDABox.pdf", ///
    as(pdf) name(Sachet_hbox) replace
graph export "../Output/Figures/Fig3c_Sachet_Mn_FDABox.svg", ///
    as(svg) name(Sachet_hbox) replace

* ── Combined figure: Cleveland (top) + horizontal box (bottom) ───────────────
graph combine Sachet_Mn_cleveland Sachet_hbox, ///
    rows(2) ///
    xsize(6) ysize(8) ///
    name(Sachet_combined, replace)

graph export "../Output/Figures/Fig3_Sachet_Combined.pdf", ///
    as(pdf) name(Sachet_combined) replace
graph export "../Output/Figures/Fig3_Sachet_Combined.svg", ///
    as(svg) name(Sachet_combined) replace

