# Ghana_Mn
Ghana Mn and Child Development

## Replication Package

All Stata do-files are executed sequentially via `Codes/0_run_all.do`. Before running, update the path globals at the top of `0_run_all.do`:

- `master_loc` — path to the `Codes/` directory in this repository.
- `R_loc` — path to your `Rscript` executable. To find yours, run `file.path(R.home("bin"), "Rscript")` in R, or use `where Rscript` (Windows) / `which Rscript` (macOS/Linux) from the command line.

### Setup: Spatial Data

Before running the code, unzip the two zip files in `Original Data/Spatial_Github/`:

- `DHSBoundaries.zip` → extract into `Original Data/Spatial_Github/DHSBoundaries/`
- `GEE_HydroShed_River.zip` → extract into `Original Data/Spatial_Github/GEE_HydroShed_River/`

Retain the same folder names as the zip files.

### Software Requirements

**Stata 14 or higher** — The code uses `file` read/write operations (Stata 13+), `import excel` (Stata 12+), factor-variable notation `i.`/`c.##c.` and `margins` (Stata 11+). Stata 14 is recommended for full compatibility with all user-written packages. The following community-contributed packages must be installed before running:

```stata
ssc install estout      // esttab, eststo, estadd
ssc install grc1leg     // graph combine with shared legend
ssc install mca         // multiple correspondence analysis
ssc install iebaltab    // balance tables (World Bank ietoolkit)
ssc install coefplot    // coefficient plots
ssc install sensemakr   // sensitivity analysis (Cinelli & Hazlett)
```

**R 4.1 or higher** — Used only for `3B.Sample_Map.R` (called from `0_run_all.do` via Rscript). The following CRAN packages are required:

`sf`, `ggplot2`, `dplyr`, `patchwork`, `cowplot`, `rnaturalearth`, `rnaturalearthdata`, `geosphere`, `ggspatial`, `igraph`, `FNN`, `sfnetworks`, `viridis`, `scico`, `svglite`, `rstudioapi`

The script will attempt to install any missing packages automatically.

### Data Availability

Some scripts in the pipeline read **personally identifiable information (PII)** stored in an encrypted Cryptomator volume (`$cryptomator_loc`). These source datasets are **not included** in the replication package to protect respondent privacy. The code files are shared for transparency. All downstream analysis scripts rely only on the processed, de-identified outputs produced by the earlier steps.

### Code Pipeline

| # | Script | Description |
|---|--------|-------------|
| 0 | `0_run_all.do` | Sets global paths and runs all scripts in order. |
| 1 | `1.Sample_ID_Extraction.do` | Builds the master Sample ID Log (see details below). |
| 2 | `2.Lab_Result_Processing.do` | Reads lab results, creates WHO/EPA threshold indicators, and merges with child-level data from the FF-Pilot. |
| 3A1 | `3A1.Sachet_Water_Processing.do` | Sachet water sample ID and results processing. |
| 3A2 | `3A2.Sachet_Specifics.do` | Additional sachet-water-specific analysis. |
| 3B | `3B.Sample_Map.R` | Generates sample location maps (called from `0_run_all.do` via Rscript). |
| 4A | `4A.Evaluation_Descriptive.do` | Pre-processing, descriptive statistics, kernel-density plots, and balance tables. |
| 4B | `4B.Evaluation_Quantiative.do` | Main empirical analysis — Mn exposure and child development outcomes, including school-level exposure. |

### `1.Sample_ID_Extraction.do`

This script constructs a master **Sample ID Log** by extracting and harmonizing water sample identifiers and GPS coordinates from four separate PII survey datasets. It produces the file `Sample_ID_Log.dta`.

**Input data** (not included — sourced from encrypted PII storage via Cryptomator):

| Source | Dataset |
|---|---|
| River water | `04_River Water Sample/.../River_water_pii_data.dta` |
| School water | `02_School Water Sample/.../School_water_pii_data.dta` |
| Household water | `01_Household Water Sample/.../Household_water_pii_data.dta` |
| Sachet (vendor) water | `03_Sachet Water Sample/.../Sachet_water_pii_data.dta` |

**What the script does:**

1. **River water samples** — Extracts sample IDs and GPS coordinates for four sub-types of river collection points: access points, upstream, downstream, and field duplicates. Duplicate samples inherit GPS coordinates from their corresponding upstream/downstream location. Sample type is identified by the last two digits of the sample ID (e.g., `05`/`09` = access point, `03`/`07` = upstream, `04`/`08` = downstream).
2. **School water samples** — Extracts sample IDs and GPS for both regular school water samples and sachet water samples collected at schools. Flags each observation accordingly.
3. **Household water samples** — Extracts sample IDs, GPS coordinates, and links each sample to a household/caregiver identifier.
4. **Sachet (vendor) water samples** — Extracts sample IDs and GPS coordinates for sachet water purchased from vendors.
5. **Appends all four sources** into a single dataset, creates indicator variables for each sample type, and saves the consolidated master log.

**GPS coordinate anonymization:** The original field GPS data were recorded with 6 decimal places in latitude and longitude (~0.11 m precision; device accuracy ~10 m). To protect respondent privacy, coordinates are rounded to 2 decimal places (~1.1 km precision) before saving. Altitude is rounded from its original 1-decimal-place precision to the nearest 50 meters; altitude is not used in the analysis. These reduced-precision coordinates are sufficient for the district-level maps produced by `3B.Sample_Map.R` while preventing identification of individual sampling locations.

**Output:** `Original Data/Sample_ID_Log.dta` — a de-identified crosswalk containing sample IDs, anonymized GPS coordinates, district/village identifiers, and sample-type flags.

### `2.Lab_Result_Processing.do`

This script imports lab results for 9 heavy metals (Pb, Hg, Zn, Cd, Mn, Fe, Cr, Al, Cu), merges them with the sample ID log, generates descriptive outputs, and builds the main child-level analysis dataset.

**What the script does:**

1. **Import and clean lab results** — Reads metal concentrations from an Excel file. Values below the limit of detection (marked with `<`) are set to 0. Corrects three field-entry typos in sample IDs.
2. **Merge with Sample ID Log** — Joins lab results 1:1 on `sample_ID` with `Sample_ID_Log.dta` (from script 1).
3. **Regulatory threshold flags** — Creates binary indicators for whether each metal exceeds WHO guidelines (e.g., Mn > 80 ug/L), EPA primary standards (enforceable health-based limits), and EPA secondary standards (e.g., Mn > 50 ug/L). Also creates combined "any limit exceeded" flags.
4. **Water source classification** — Derives the water source type (borehole, river, piped, well, sachet) from the sample ID.
5. **Table 1** — Generates `Table1_Heavy_Metals_by_Sample_Water_Source.csv`: summary statistics (mean, SD) of all metal concentrations and exceedance rates, broken out by water source (borehole, river, piped water, well, sachet). Post-processes zero values to display as "Below LOD."
6. **Figure 2** — Generates `Fig2_IQR_Mn_by_Sources` (PDF + SVG): box plots of Mn concentrations by water source, with horizontal reference lines at the USEPA (50 ug/L) and WHO (80 ug/L) thresholds.
7. **Village-level aggregation** — Computes village-mean metal concentrations separately for sachet, river, and school water samples (used for imputation).
8. **Merge with child-level survey** — Keeps household samples and merges 1:m with the parent/caregiver survey, bringing in child development IRT scores, demographics, SES indicators, and treatment assignment. Also merges in village-level river, sachet, and school concentrations.
9. **Imputation** — Three caregivers missing from water sampling have their metal concentrations imputed using village-average values for their reported water source (sachet or borehole).
10. **Standardize child development scores** — Converts IRT theta scores (overall, motor, language, socio-emotional, cognitive, adaptive) to z-scores.
11. **Re-create threshold flags** — Regenerates all WHO/EPA exceedance indicators on the complete child-level dataset and creates squared metal terms for nonlinear specifications.

**Inputs:**

| File | Description |
|---|---|
| `Original Data/100925_MetalsData_GhanaWaterSampling_xfl - 10102025..xlsx` | Raw lab results |
| `Original Data/Sample_ID_Log.dta` | Sample ID log (from script 1) |
| `Original Data/Parent_Survey_isid_ChildCode.dta` | Child-level survey data |

**Outputs:**

| File | Description |
|---|---|
| `Processed Stata Dta/Lab Test Results.dta` | Sample-level lab results with threshold flags |
| `Output/Feed_into_GEE_Test_Results_with_GPS.csv` | GPS + Mn data fed into `3B.Sample_Map.R` |
| `Processed Stata Dta/Test Results Merged with EL Child Development.dta` | Main child-level analysis file (used by scripts 4A and 4B) |
| `Output/Tables/Table1_Heavy_Metals_by_Sample_Water_Source.csv` | **Table 1**: heavy metal distributions by water source |
| `Output/Figures/Fig2_IQR_Mn_by_Sources.pdf/.svg` | **Figure 2**: Mn IQR box plots by water source |

### `3B.Sample_Map.R`

This R script generates **Figure 1** — a two-panel map of the study area and manganese concentrations at sampling locations. It is called from `0_run_all.do` via `Rscript` and sets its working directory automatically to the `Codes/` folder.

**What the script does:**

1. **Load spatial data** — Reads sample coordinates with Mn concentrations from `Feed_into_GEE_Test_Results_with_GPS.csv` (produced by script 2). Loads regional and district boundary shapefiles (DHS subnational boundaries, district boundaries), West Africa and Ghana country outlines (via `rnaturalearth`), and HydroSHEDS river network lines from Google Earth Engine.
2. **Process sampling coordinates** — Filters observations with valid GPS and Mn data, converts to spatial points (WGS 84), and projects to UTM Zone 30N (EPSG:32630) for metric distance calculations. Substitutes below-LOD Mn values with batch-specific LOD/sqrt(2).
3. **Classify sample types** — Categorizes each observation as Household, School, River, or Vendor based on sample-type indicator flags.
4. **Panel A — Study area overview and sampling locations** — Combines two sub-plots: (i) a West Africa inset map highlighting Ghana with a red box around the study area, and (ii) a zoomed-in map showing sample points by type (color- and shape-coded for Household, School, River, Vendor), four study district boundaries (Sefwi-Wiawso, Bibiani-Anhwiaso-Bekwai, Sefwi Akontombra, Juaboso), regional boundaries, and HydroSHEDS river lines.
5. **Panel B — Mn concentration at sample points** — Plots individual sample points colored by Mn concentration (LOD-substituted, log-scaled YlOrRd color palette) over district and regional boundaries. River samples are highlighted with blue circle outlines.
6. **Combine and export** — Assembles both panels into a single figure using `patchwork` layout and saves as SVG.

**Inputs:**

| File | Description |
|---|---|
| `Output/Feed_into_GEE_Test_Results_with_GPS.csv` | Sample GPS coordinates and Mn concentrations (from script 2) |
| `Original Data/Spatial/dhsboundaries/shps/sdr_subnational_boundaries.*` | DHS subnational (regional) boundary shapefile |
| `Original Data/Spatial/districts_archub/...` | District boundary shapefile |
| `Original Data/Spatial/GEE_HydroShed_River/HydroSHEDS_rivers_buffer.*` | HydroSHEDS river network lines |

**Output:**

| File | Description |
|---|---|
| `Output/Figures/Mn_IQR_and_Median_Grid_Map_Africa.svg` | **Figure 1**: two-panel map — (A) study area overview with sampling locations, (B) Mn concentrations at sample points |

### `3A1.Sachet_Water_Processing.do` and `3A2.Sachet_Specifics.do`

These two scripts process sachet (bagged) water samples, check brand registration status against the Ghana FDA permit registry, and produce **Figure 3**.

**What `3A1.Sachet_Water_Processing.do` does** (not included — reads PII data from Cryptomator):

1. **Load sachet water data** — Reads vendor sachet and school sachet PII survey data from Cryptomator. Extracts sample IDs, brand names, and manufacturer names, harmonizing fields across the two sources.
2. **FDA registration lookup** — Flags each sachet sample's brand as FDA-registered or not, based on the Ghana FDA public permit registry (`verifypermit.fdaghana.gov.gh`).
3. **Merge with lab results** — Joins brand and registration information 1:1 on `sample_ID` with the sample-level lab results (`Lab Test Results.dta` from script 2).
4. **Prepare plot data** — Sorts sachet samples by Mn concentration, replaces below-LOD values with a small positive number for plotting, and marks duplicate brands with stars in the x-axis labels so readers can identify multiple samples from the same brand.
5. **Save** — Outputs `Sachet Test Results_Only.dta` for use by `3A2.Sachet_Specifics.do`.

**What `3A2.Sachet_Specifics.do` does:**

1. **Figure 3** — Generates `Fig3_Sachet_Mn_Concentration_FDARegistration` (PDF + SVG): a bar chart of Mn concentration for each sachet water sample, color-coded by FDA registration status (navy = registered, grey = not registered). Horizontal reference lines mark the USEPA (50 ug/L) and WHO (80 ug/L) thresholds. Stars on x-axis labels indicate samples from the same brand. Samples below LOD are labeled accordingly.

**Inputs:**

| File | Description |
|---|---|
| Sachet PII survey data (Cryptomator) | Brand names, manufacturer names, sample IDs (not included) |
| `Processed Stata Dta/Lab Test Results.dta` | Sample-level lab results (from script 2) |

**Outputs:**

| File | Description |
|---|---|
| `Processed Stata Dta/Sachet Test Results_Only.dta` | Sachet-only dataset with FDA registration flags and plot variables |
| `Output/Figures/Fig3_Sachet_Mn_Concentration_FDARegistration.pdf/.svg` | **Figure 3**: Mn concentration by sachet sample, colored by FDA registration status |

### `4A.Evaluation_Descriptive.do`

This script performs additional data preparation, generates descriptive figures, and produces balance tables comparing covariates across Mn exposure groups. It also prepares the variables used by the subsequent quantitative analysis in `4B.Evaluation_Quantiative.do`.

**What the script does:**

1. **Covariate dimension reduction** — Uses multiple correspondence analysis (`mca`) to construct summary indices for: household learning materials (6 items), parental involvement (4 items), and household asset ownership.
2. **Mn exposure classification** — Creates categorical Mn exposure variables: Mn below LOD vs. detected, and three-level groups (below LOD / detected but below threshold / above USEPA or WHO threshold). Also constructs analogous variables for school-level Mn exposure.
3. **Below-LOD substitution** — Replaces zero-valued Mn and Fe concentrations with LOD/sqrt(2) (batch-specific), consistent with standard practice for censored environmental data. Generates log-transformed versions for regression use.
4. **Income variable refinement** — Combines baseline and recalled income information to create finer income categories (below 5k, 5-10k, 10-20k, above 20k cedis).
5. **Figure S1** — Generates `FigS1_kdensity_z_Score_and_Mn_Limits` (PDF + SVG): kernel density plots of standardized performance z-scores, comparing children with Mn below LOD vs. Mn detected in household water.
6. **Table S1** — Generates `TableS1_iebaltab_Mn_above_LOD_ChildCov.csv`: balance table comparing child-level covariates (gender, age, parental engagement, learning materials) across Mn exposure groups, with district fixed effects and clustered standard errors.
7. **Table S2** — Generates `TableS2_iebaltab_Mn_above_LOD_Caregiver_Household_Covar.csv`: balance table comparing household and caregiver characteristics (education, employment, income, household size, language, assets) across Mn exposure groups.
8. **Table S3** — Generates `TableS3_iebaltab_Mn_above_LOD_WaterSafetyTreatment_Method.csv`: balance table comparing perceived water safety and reported treatment methods (boiling, alum, filtration, chlorine) across Mn exposure groups.
9. **Save** — Overwrites the analysis dataset with the newly created variables, ready for `4B.Evaluation_Quantiative.do`.

**Input:**

| File | Description |
|---|---|
| `Processed Stata Dta/Test Results Merged with EL Child Development.dta` | Child-level analysis file (from script 2) |

**Outputs:**

| File | Description |
|---|---|
| `Processed Stata Dta/Test Results Merged with EL Child Development.dta` | Updated with new variables (MCA indices, Mn categories, income categories, LOD-substituted values) |
| `Output/Figures/FigS1_kdensity_z_Score_and_Mn_Limits.pdf/.svg` | **Figure S1**: kernel density of child development scores by Mn detection |
| `Output/Tables/Balance_Table/TableS1_iebaltab_Mn_above_LOD_ChildCov.csv` | **Table S1**: balance table — child covariates |
| `Output/Tables/Balance_Table/TableS2_iebaltab_Mn_above_LOD_Caregiver_Household_Covar.csv` | **Table S2**: balance table — household and caregiver characteristics |
| `Output/Tables/Balance_Table/TableS3_iebaltab_Mn_above_LOD_WaterSafetyTreatment_Method.csv` | **Table S3**: balance table — perceived water safety and treatment methods |

### `4B.Evaluation_Quantiative.do`

This script runs the main quantitative analysis examining the relationship between household water manganese (Mn) exposure and child development (standardized performance z-scores). All regressions use clustered standard errors at the caregiver level and include district fixed effects.

**What the script does:**

1. **Table 2 — Continuous model** — Regresses child development scores on log(Household Mn) with three progressive specifications: (i) batch + treatment + district FE only, (ii) adding demographic controls (age, sex), (iii) adding economic controls (learning materials, parental involvement, assets, employment, education, income). Output: `Table2_Continuous_Mn_Exposure_ChildDev.rtf`.
2. **Table 3 — Categorical model** — Same three specifications using a three-level categorical Mn variable (below LOD / detected but below USEPA threshold / above USEPA 50 ug/L threshold), with "below LOD" as the reference group. Output: `Table3_EPA_LOD_Mn_Exposure_ChildDev.rtf`.
3. **Table S4 and Figure 4 — School Mn heterogeneity** — Estimates the interaction between log(Household Mn) and log(School Mn) for children enrolled in study schools. Generates a margins plot showing the average marginal effect of household Mn at varying levels of school Mn exposure. Outputs: `TableS4_Mn_plus_SchoolExposure_ChildDev.rtf` and `Fig4_MarginsPlot_AME_by_SchoolMn` (PDF + SVG).
4. **Table S5 — Gender heterogeneity** — Estimates the interaction between log(Household Mn) and child sex (boys vs. girls) across three specifications. Output: `TableS5_Mn_ChildDev_by_BoysGirls.rtf`.
5. **Table 4 and Figure S2 — Sensitivity analysis (Cinelli & Hazlett, 2020)** — Runs `sensemakr` for both the categorical (1{Mn >= 50}) and continuous (log Mn) specifications. Reports robustness values, partial R-squared measures, and benchmark bounds. Generates extreme plots for both specifications combined. Outputs: `Table4_Sensemakr_Combined_Results.rtf` and `FigS2_Sensemakr_ExtremePlot_logEPA_Combined.svg`.
6. **Figure 5 — Robustness: excluding non-Mn metals (household only)** — Re-estimates both the continuous and categorical models after sequentially dropping children whose household water contains detectable levels of other metals (Pb, Fe, Cr, Al, Cu, then all simultaneously). Coefficient plots show stability of the Mn estimate. Output: `Fig5_RobustnessChecks_RemoveNonMn_HouseholdWater_Coefplot_logMnUSEPA` (PDF + SVG).
7. **Figure S3 — Robustness: excluding non-Mn metals (household and school)** — Same exercise as above but additionally excluding children whose school water contains detectable non-Mn metals. Output: `FigS3_RobustnessChecks_RemoveNonMn_HouseholdSchoolWater_Coefplot_logMnUSEPA` (PDF + SVG).

**Input:**

| File | Description |
|---|---|
| `Processed Stata Dta/Test Results Merged with EL Child Development.dta` | Child-level analysis file (from script 4A) |

**Outputs:**

| File | Description |
|---|---|
| `Output/Tables/Table2_Continuous_Mn_Exposure_ChildDev.rtf` | **Table 2**: continuous log(Mn) regression results |
| `Output/Tables/Table3_EPA_LOD_Mn_Exposure_ChildDev.rtf` | **Table 3**: categorical Mn exposure regression results |
| `Output/Tables/Table4_Sensemakr_Combined_Results.rtf` | **Table 4**: sensitivity analysis (robustness values, partial R-squared bounds) |
| `Output/Tables/TableS4_Mn_plus_SchoolExposure_ChildDev.rtf` | **Table S4**: household x school Mn interaction |
| `Output/Tables/TableS5_Mn_ChildDev_by_BoysGirls.rtf` | **Table S5**: boys vs. girls heterogeneity |
| `Output/Figures/Fig4_MarginsPlot_AME_by_SchoolMn.pdf/.svg` | **Figure 4**: marginal effect of household Mn by school Mn level |
| `Output/Figures/FigS2_Sensemakr_ExtremePlot_logEPA_Combined.svg` | **Figure S2**: sensemakr extreme plots (continuous + categorical) |
| `Output/Figures/Fig5_RobustnessChecks_RemoveNonMn_HouseholdWater_Coefplot_logMnUSEPA.pdf/.svg` | **Figure 5**: robustness coefficient plots — excluding household non-Mn metals |
| `Output/Figures/FigS3_RobustnessChecks_RemoveNonMn_HouseholdSchoolWater_Coefplot_logMnUSEPA.pdf/.svg` | **Figure S3**: robustness coefficient plots — excluding household and school non-Mn metals |
