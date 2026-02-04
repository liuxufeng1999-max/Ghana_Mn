/* Ghana Water Sampling Do Files

Xufeng Liu
Last Updated: Nov 7, 2025

Special Notes:
1. Field entries typo noted on sample ID : see the correspondence with IPA: "Dropbox\Ghana Illegal Mining\04_Data\Water_Sampling\Field Entries Typo on Sample IDs.pdf"
2A. Manganese (Mn) and Magnesium (Mg) are two DIFFERENT metals!
2B. Manganese (Mn) and Magnesium (Mg) are two DIFFERENT metals!!
2C. Manganese (Mn) and Magnesium (Mg) are two DIFFERENT metals!!!


*/

**# Specify some do file locations
**Note: we will use relative file path (relative to this master do file location)

global master_loc "C:\Users\liu.7133\Github_Repo\Ghana_Mn\Codes" //<-- Change if needed
global cryptomator_loc "D:\Foundation First Pilot\05_Water Sampling" //<-- Change if needed
global proc_dta_loc "..\Processed Stata Dta" //<-- Relative file path, no need to change
capture mkdir "..\Processed Stata Dta"

cd "$master_loc"
ls

**# Sample ID Extraction
**This do file extract the IPA-shared sample log data and generate the master sample ID files shared with Taylor for result entries
cd "$master_loc"
do 1.Sample_ID_Extraction.do


**# Lab result processing
**(i) Read the Taylor-shared lab results and create some useful dummies represent the WHO/EPA Threshold; and
**(ii) Merge with the BL+EL Child-Level Data from the FF-Pilot
cd "$master_loc"
do 3.Lab_Result_Processing.do

**# Sample Map
cd "$master_loc"
shell "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" "Sample_Map.R"


**#Sachet Water
/* do 3A1.Sachet_Water_Processing.do  *<-- Sachet Water Sample ID and results processing */
do 3A2.Sachet_Specifics.do

**# Evaluation
**Some pre-processings and descriptive statistics
**Descriptives: Kdensity Plots + Balance Tables
cd "$master_loc"
do 4.Evaluation.do


**# Evaluation: Mn Specific
**Run the analysis - focus on Mn
**Empiricals: Mn exposure and Child Development (with other alternative outcomes)
**Specials: Extra exposure by school kids
cd "$master_loc"
do 4A.Manganese_Evaluation.do
**Note: Manganese (Mn) and Magnesium (Mg) are two DIFFERENT metals!!!


