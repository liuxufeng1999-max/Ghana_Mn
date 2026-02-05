/* Ghana Water Sampling Do Files

Xufeng Liu
Last Updated: Nov 7, 2025

This master do file runs all the necessary do files to process the data, generate descriptive statistics/figures, and run the main empirical analysis.
Required: Stata 14 or higher AND R 4.1 or higher

*/

**# Specify some do file locations
**Note: we will use relative file path (relative to this master do file location)

*global master_loc "C:\Users\liu.7133\Github_Repo\Ghana_Mn\Codes" //<-- Change if needed
/* global cryptomator_loc "" //<-- Change if needed * NOT USED IN THIS REPRODUCTION PACKAKGE */
global master_loc "~/Documents/GitHub/Ghana_Mn/Codes"
global proc_dta_loc "../Processed Stata Dta" //<-- Relative file path, no need to change
*global R_loc "C:/Program Files\R\R-4.5.2\bin\x64\Rscript.exe" //<-- Change if needed. Run file.path(R.home("bin"), "Rscript") in R to find yours.
global R_loac "/opt/homebrew/bin/Rscript"
global R_loc "C:/Program Files/R/R-4.5.2/bin/x64/Rscript.exe"
global master_loc "C:/Users/liu.7133/Github_Repo/Ghana_Mn/Codes"
cd "$master_loc" 
capture mkdir "../Processed Stata Dta"

**Install any needed packages
/* 
ssc install estout      // esttab, eststo, estadd
ssc install grc1leg     // graph combine with shared legend
ssc install mca         // multiple correspondence analysis
ssc install iebaltab    // balance tables (World Bank ietoolkit)
ssc install coefplot    // coefficient plots
ssc install sensemakr   // sensitivity analysis (Cinelli & Hazlett) */

**# Sample ID Extraction
**This do file extract the field-shared sample log data and generate the master sample ID files shared with Taylor for result entries
cd "$master_loc"
 /* do 1.Sample_ID_Extraction.do *<-- contain PII data to construct the sample ID logs. */


**# Lab result processing
**(i) Read the Taylor-shared lab results and create some useful dummies represent the WHO/EPA Threshold; and
**(ii) Merge with the BL+EL Child-Level Data from the FF-Pilot
cd "$master_loc"
do 2.Lab_Result_Processing.do


**#Sachet Water
/* do 3A1.Sachet_Water_Processing.do  //<-- Sachet Water Sample ID and results processing */
do 3A2.Sachet_Specifics.do

**# Sample Map
cd "$master_loc"
shell "$R_loc" "3B.Sample_Map.R"

**# Descriptive Statistics and Figures & Preparation
**Some pre-processings and descriptive statistics
**Descriptives: Kdensity Plots + Balance Tables
cd "$master_loc"
do 4A.Evaluation_Descriptives.do


**# Evaluation: Quantitative Analysis
**Run the analysis - focus on Mn
**Empiricals: Mn exposure and Child Development (with other alternative outcomes)
cd "$master_loc"
do 4B.Evaluation_Quantiative.do


