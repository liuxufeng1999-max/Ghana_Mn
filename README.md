# Ghana_Mn
Ghana Mn and Child Development

## Replication Package

All Stata do-files are executed sequentially via `Codes/MASTER.do`. Before running, update the two path globals at the top of `MASTER.do`:

- `master_loc` — path to the `Codes/` directory in this repository.
- `cryptomator_loc` — path to the encrypted PII data volume (see note below).

### Data Availability

Some scripts in the pipeline read **personally identifiable information (PII)** stored in an encrypted Cryptomator volume (`$cryptomator_loc`). These source datasets are **not included** in the replication package to protect respondent privacy. The code files are shared for transparency. All downstream analysis scripts rely only on the processed, de-identified outputs produced by the earlier steps.

### Code Pipeline

| # | Script | Description |
|---|--------|-------------|
| 0 | `MASTER.do` | Sets global paths and runs all scripts in order. |
| 1 | `1.Sample_ID_Extraction.do` | Builds the master Sample ID Log (see details below). |
| 2 | `2.Test_Strip_Samples.do` | Processes field test-strip sample data. |
| 3 | `3.Lab_Result_Processing.do` | Reads lab results, creates WHO/EPA threshold indicators, and merges with child-level data from the FF-Pilot. |
| 3A1 | `3A1.Sachet_Water_Processing.do` | Sachet water sample ID and results processing. |
| 3A2 | `3A2.Sachet_Specifics.do` | Additional sachet-water-specific analysis. |
| — | `Sample_Map.R` | Generates sample location maps (called from `MASTER.do` via Rscript). |
| 4 | `4.Evaluation.do` | Pre-processing, descriptive statistics, kernel-density plots, and balance tables. |
| 4A | `4A.Manganese_Evaluation.do` | Main empirical analysis — Mn exposure and child development outcomes, including school-level exposure. |

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

**Output:** `Processed Stata Dta/Sample_ID_Log.dta` — a de-identified crosswalk containing sample IDs, GPS coordinates, district/village identifiers, and sample-type flags.
