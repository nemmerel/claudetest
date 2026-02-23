*************************************************************
* County-to-CZ Crosswalk Construction                       **
* Builds two output files:                                   **
*   1. county_cz_crosswalk.dta — county-level crosswalk      **
*      with CZ mapping, RUCC, CBSA, share_black,            **
*      share_college (keyed on county_fips)                  **
*   2. cz_measures.dta — CZ-level urban/rural, superstar,   **
*      cz_share_black, cz_share_college, and Chetty causal  **
*      place effects (keyed on cz)                           **
*************************************************************

clear all
set more off

* Load project paths
do "/Users/jar88/Dropbox/research_projects/revision_analysis/claudetest/dofiles/paths.do"

cd "$dirdata"

* Step flags
global step_0 = 1   // Download raw data files
global step_1 = 1   // Clean county-to-CZ crosswalk
global step_2 = 1   // Clean Chetty CZ causal place effects
global step_3 = 1   // Clean demographic data (RUCC, education, race)
global step_4 = 1   // Clean CBSA crosswalk + county-level superstar coding
global step_5 = 1   // Build county_cz_crosswalk.dta
global step_6 = 1   // Build cz_measures.dta (CZ-level aggregates)


*************************************************************
* Step 0: Download raw data files
*************************************************************

if $step_0 {

di _n "*** Step 0: Downloading raw data files ***"

* Chetty et al. (2014) Online Data Table 3 (CZ-level causal place effects)
* At the CZ level 
capture confirm file "$dirdata/raw_chetty_cz_causal.dta"
if _rc != 0 {
    * Check if it was previously downloaded under the old name
    capture confirm file "$dirdata/raw_chetty_county.dta"
    if _rc == 0 {
        di "Renaming raw_chetty_county.dta -> raw_chetty_cz_causal.dta"
        copy "$dirdata/raw_chetty_county.dta" "$dirdata/raw_chetty_cz_causal.dta", replace
    }
    else {
        di "Downloading Chetty CZ causal place effects (online_table3)..."
        capture copy "https://opportunityinsights.org/wp-content/uploads/2018/04/online_table3.dta" ///
            "$dirdata/raw_chetty_cz_causal.dta", replace
        if _rc != 0 {
            di as error "Automatic download failed for Chetty CZ data."
            di as error "Please manually download from:"
            di as error "  https://opportunityinsights.org/data/"
            di as error "  (Online Data Table 3 from 'Where is the Land of Opportunity?')"
            di as error "Save as: $dirdata/raw_chetty_cz_causal.dta"
            exit 601
        }
    }
}
else {
    di "raw_chetty_cz_causal.dta already exists, skipping download."
}

* County-to-CZ crosswalk from Opportunity Insights
capture confirm file "$dirdata/raw_county_cz_xw.csv"
if _rc != 0 {
    di "Downloading county-to-CZ crosswalk from Opportunity Insights..."
    capture copy "https://raw.githubusercontent.com/OpportunityInsights/EconomicTracker/main/data/GeoIDs%20-%20County.csv" ///
        "$dirdata/raw_county_cz_xw.csv", replace
    if _rc != 0 {
        di as error "Automatic download failed for county-CZ crosswalk."
        di as error "Please manually download from:"
        di as error "  https://github.com/OpportunityInsights/EconomicTracker/blob/main/data/GeoIDs%20-%20County.csv"
        di as error "Save as: $dirdata/raw_county_cz_xw.csv"
        exit 601
    }
}
else {
    di "raw_county_cz_xw.csv already exists, skipping download."
}

* USDA Rural-Urban Continuum Codes (2013)
* At the county level 
capture confirm file "$dirdata/raw_rucc_2013.xls"
if _rc != 0 {
    di "Downloading USDA Rural-Urban Continuum Codes (2013)..."
    capture copy "https://www.ers.usda.gov/media/5769/ruralurbancodes2013.xls" ///
        "$dirdata/raw_rucc_2013.xls", replace
    if _rc != 0 {
        * Try alternate URL
        capture copy "https://www.ers.usda.gov/webdocs/DataFiles/53251/ruralurbancodes2013.xls?v=2959.5" ///
            "$dirdata/raw_rucc_2013.xls", replace
        if _rc != 0 {
            di as error "Automatic download failed for USDA RUCC data."
            di as error "Please manually download from:"
            di as error "  https://www.ers.usda.gov/data-products/rural-urban-continuum-codes/"
            di as error "  (2013 Rural-Urban Continuum Codes, XLS format)"
            di as error "Save as: $dirdata/raw_rucc_2013.xls"
            exit 601
        }
    }
}
else {
    di "raw_rucc_2013.xls already exists, skipping download."
}

* NBER CBSA-to-County Crosswalk (2020 delineation)
capture confirm file "$dirdata/raw_cbsa_county_xw.dta"
if _rc != 0 {
    di "Downloading NBER CBSA-County crosswalk..."
    capture copy "https://data.nber.org/cbsa-csa-fips-county-crosswalk/2020/cbsa2fipsxw_2020.dta" ///
        "$dirdata/raw_cbsa_county_xw.dta", replace
    if _rc != 0 {
        di as error "Automatic download failed for NBER CBSA crosswalk."
        di as error "Please manually download from:"
        di as error "  https://data.nber.org/cbsa-csa-fips-county-crosswalk/"
        di as error "  (2020 version, .dta format)"
        di as error "Save as: $dirdata/raw_cbsa_county_xw.dta"
        exit 601
    }
}
else {
    di "raw_cbsa_county_xw.dta already exists, skipping download."
}

* Census county population estimates by race (2019)
capture confirm file "$dirdata/raw_census_race_2019.csv"
if _rc != 0 {
    di "Downloading Census county population by race (2019)..."
    capture copy "https://www2.census.gov/programs-surveys/popest/datasets/2010-2019/counties/asrh/cc-est2019-alldata.csv" ///
        "$dirdata/raw_census_race_2019.csv", replace
    if _rc != 0 {
        di as error "Download failed. Please manually download from:"
        di as error "  https://www2.census.gov/programs-surveys/popest/datasets/2010-2019/counties/asrh/"
        di as error "  File: cc-est2019-alldata.csv"
        di as error "Save as: $dirdata/raw_census_race_2019.csv"
        exit 601
    }
}
else {
    di "raw_census_race_2019.csv already exists, skipping download."
}

* USDA ERS county education data
capture confirm file "$dirdata/raw_ers_education.xlsx"
if _rc != 0 {
    di "Downloading USDA ERS county education data..."
    capture copy "https://www.ers.usda.gov/webdocs/DataFiles/48747/Education.xlsx" ///
        "$dirdata/raw_ers_education.xlsx", replace
    if _rc != 0 {
        di as error "Download failed. Please manually download from:"
        di as error "  https://www.ers.usda.gov/data-products/county-level-data-sets/"
        di as error "  (Education data, .xlsx format)"
        di as error "Save as: $dirdata/raw_ers_education.xlsx"
        exit 601
    }
}
else {
    di "raw_ers_education.xlsx already exists, skipping download."
}

di _n "*** Step 0 complete ***"

}


*************************************************************
* Step 1: Clean county-to-CZ crosswalk
*************************************************************

if $step_1 {

di _n "*** Step 1: Cleaning county-to-CZ crosswalk ***"

import delimited "$dirdata/raw_county_cz_xw.csv", clear varnames(1)

describe

* Create 5-digit county FIPS string
* countyfips is the raw variable from the CSV
gen str5 county_fips = string(countyfips, "%05.0f")

* Keep relevant variables
keep county_fips cz czname countyname stateabbrev county_pop2019

* Rename for consistency
rename countyname county_name
rename stateabbrev state_abbr

* Label variables
label var county_fips    "5-digit County FIPS code"
label var cz             "Commuting Zone ID"
label var czname         "Commuting Zone name"
label var county_name    "County name"
label var state_abbr     "State abbreviation"
label var county_pop2019 "County population (2019)"

* Check uniqueness
isid county_fips
di "Unique counties in crosswalk: `=_N'"

* Order
order county_fips county_name state_abbr cz czname county_pop2019

compress
save "$dirdata/county_cz_xw_clean.dta", replace

di "*** Step 1 complete ***"

}


*************************************************************
* Step 2: Clean Chetty CZ causal place effects
*************************************************************

if $step_2 {

di _n "*** Step 2: Cleaning Chetty CZ causal place effects ***"

use "$dirdata/raw_chetty_cz_causal.dta", clear

describe, short
di "Observations: `=_N'"

* Verify keyed on CZ
isid cz
di "Unique commuting zones: `=_N'"

* Keep all variables (small file, let downstream analysis choose)
compress
save "$dirdata/chetty_cz_causal_clean.dta", replace

di "*** Step 2 complete ***"

}


*************************************************************
* Step 3: Clean demographic data (RUCC, education, race)
*************************************************************

if $step_3 {

di _n "*** Step 3: Cleaning demographic data (RUCC, education, race) ***"

*--- 3A: Clean USDA RUCC 2013 ---

* Import Excel file
* The USDA file typically has a header row with column names
import excel using "$dirdata/raw_rucc_2013.xls", firstrow clear

describe

* Standardize variable names (USDA uses varying capitalization)
capture rename FIPS fips_raw
capture rename State state_abbr
capture rename County_Name county_name_rucc
capture rename RUCC_2013 rucc_2013
capture rename Population_2010 pop_2010
capture rename Description rucc_description

* Handle alternative column names
capture rename CountyName county_name_rucc
capture rename *, lower

* Create 5-digit FIPS string
* May be imported as numeric or string
capture confirm numeric variable fips_raw
if _rc == 0 {
    gen str5 county_fips = string(fips_raw, "%05.0f")
}
else {
    gen str5 county_fips = fips_raw
    replace county_fips = "0" + county_fips if strlen(county_fips) == 4
    replace county_fips = "00" + county_fips if strlen(county_fips) == 3
}


* Ensure rucc_2013 is numeric
destring rucc_2013, replace

* Create metro indicator (RUCC 1-3 = metro, 4-9 = nonmetro)
gen metro = (rucc_2013 <= 3) if !missing(rucc_2013)
label define metro_lbl 0 "Nonmetro" 1 "Metro"
label values metro metro_lbl

* Label RUCC codes
label define rucc_lbl ///
    1 "Metro 1M+" ///
    2 "Metro 250K-1M" ///
    3 "Metro <250K" ///
    4 "Urban 20K+ adj metro" ///
    5 "Urban 20K+ nonadj" ///
    6 "Urban 2.5K-20K adj metro" ///
    7 "Urban 2.5K-20K nonadj" ///
    8 "Rural adj metro" ///
    9 "Rural nonadj"
label values rucc_2013 rucc_lbl

* Keep relevant variables
capture confirm variable pop_2010
if _rc == 0 {
    keep county_fips rucc_2013 metro pop_2010
}
else {
    di as text "Note: pop_2010 not found in RUCC data; continuing without it."
    keep county_fips rucc_2013 metro
}

* Drop rows with missing FIPS (state-level summary rows or header artifacts)
drop if missing(county_fips) | county_fips == "" | county_fips == "     "

* Check uniqueness
isid county_fips
di "Counties with RUCC codes: `=_N'"

* Summary
tab rucc_2013
tab metro

compress
save "$dirdata/rucc_2013_clean.dta", replace

di "--- 3A complete: rucc_2013_clean.dta saved ---"

*--- 3B: Clean USDA ERS education data ---

di _n "--- 3B: Cleaning USDA ERS education data ---"

import excel using "$dirdata/raw_ers_education.xlsx", ///
    sheet("Education 1970 to 2023") firstrow clear

describe

* The FIPS Code variable identifies counties
* Keep county-level rows only (5-digit FIPS, drop state summaries)
* Variable names depend on the file; inspect and rename as needed
capture rename FIPSCode fips_raw
capture rename FIPS fips_raw

* Verify that fips_raw was created by one of the renames above
capture confirm variable fips_raw
if _rc != 0 {
    di as error "Could not find FIPS variable in education data. Listing variables:"
    describe
    exit 198
}

* Convert FIPS to string if numeric
capture confirm numeric variable fips_raw
if _rc == 0 {
    gen str5 county_fips = string(fips_raw, "%05.0f")
}
else {
    gen str5 county_fips = fips_raw
    replace county_fips = "0" + county_fips if strlen(county_fips) == 4
    replace county_fips = "00" + county_fips if strlen(county_fips) == 3
}

* Drop state-level summary rows (county portion == "000")
drop if substr(county_fips, 3, 3) == "000"

* Drop rows with missing/blank FIPS
drop if missing(county_fips) | county_fips == "" | county_fips == "     "

* Find the "Percent of adults with a bachelor's degree or higher, 2017-21" column
* The variable name is typically long; capture common variants
capture rename Percentofadultswitha pct_college
capture rename Percentofadultswithab pct_college
capture rename Percentofadultscompl pct_college
* Check whether any of the above succeeded
capture confirm variable pct_college
if _rc != 0 {
    * Use a broader approach: list variables containing relevant keywords
    describe, varlist
    local allvars `r(varlist)'
    foreach v of local allvars {
        local lab : variable label `v'
        if strpos(lower("`lab'"), "bachelor") > 0 & strpos("`lab'", "2017") > 0 {
            rename `v' pct_college
            continue, break
        }
    }
}

* If still not found, try the last education column (highest education, most recent period)
capture confirm variable pct_college
if _rc != 0 {
    di as error "Could not identify bachelor's degree variable. Listing variables:"
    describe
    exit 198
}

* Ensure pct_college is numeric
destring pct_college, replace force

* Convert percentage to share (0-1)
gen share_college = pct_college / 100

* Keep relevant variables
keep county_fips share_college

* Drop missing
drop if missing(share_college)

* Check uniqueness
isid county_fips
di "Counties with education data: `=_N'"

* Summary
su share_college, detail

compress
save "$dirdata/education_clean.dta", replace

di "--- 3B complete: education_clean.dta saved ---"

*--- 3C: Clean Census county race data (2019) ---

di _n "--- 3C: Cleaning Census county race data (2019) ---"

import delimited "$dirdata/raw_census_race_2019.csv", clear

describe, short

* Variable names may be uppercase or lowercase depending on import
capture rename *, lower

* Filter to YEAR == 12 (7/1/2019 estimate) and AGEGRP == 0 (all ages)
keep if year == 12 & agegrp == 0

di "Rows after filtering to YEAR==12, AGEGRP==0: `=_N'"

* Drop state-level summary rows (county == 0)
drop if county == 0

* Create 5-digit county FIPS
gen str5 county_fips = string(state, "%02.0f") + string(county, "%03.0f")

* Compute share Black (Black alone)
gen share_black = (ba_male + ba_female) / tot_pop

* Keep relevant variables
keep county_fips share_black

* Drop missing
drop if missing(share_black)

* Check uniqueness
isid county_fips
di "Counties with race data: `=_N'"

* Summary
su share_black, detail

compress
save "$dirdata/race_clean.dta", replace

di "--- 3C complete: race_clean.dta saved ---"

di "*** Step 3 complete ***"

}


*************************************************************
* Step 4: Clean CBSA-County crosswalk + CBSA superstar coding
*************************************************************

if $step_4 {

di _n "*** Step 4: Cleaning CBSA crosswalk + coding superstars ***"

*-------------------------------------------------------
* Part A: County-level CBSA mapping
*-------------------------------------------------------

use "$dirdata/raw_cbsa_county_xw.dta", clear

describe

* Create 5-digit county FIPS from separate state and county codes
gen str5 county_fips = fipsstatecode + fipscountycode

* Clean CBSA code
destring cbsacode, gen(cbsa_code) force

* MSA indicator (vs. Micropolitan)
gen msa = (metropolitanmicropolitanstatis == "Metropolitan Statistical Area")

* Keep relevant variables
keep county_fips cbsa_code cbsatitle msa centraloutlyingcounty

* Check uniqueness (each county should appear at most once)
isid county_fips
di "Counties in CBSA areas: `=_N'"

compress
save "$dirdata/cbsa_county_clean.dta", replace

di _n "--- Part A: cbsa_county_clean.dta saved ---"

*-------------------------------------------------------
* Part B: County-level superstar coding
*-------------------------------------------------------

use "$dirdata/cbsa_county_clean.dta", clear

*************************************************************
* Define superstar cities (ad hoc)
* Based on Autor (2019) / common usage
* Tag each county based on its CBSA code
*************************************************************

* Core superstar MSAs (10 CBSAs)
gen superstar = 0
local superstar_core ///
    35620 /* New York-Newark-Jersey City, NY-NJ-PA         */ ///
    31080 /* Los Angeles-Long Beach-Anaheim, CA             */ ///
    41860 /* San Francisco-Oakland-Berkeley, CA             */ ///
    16980 /* Chicago-Naperville-Elgin, IL-IN-WI             */ ///
    14460 /* Boston-Cambridge-Newton, MA-NH                 */ ///
    42660 /* Seattle-Tacoma-Bellevue, WA                    */ ///
    47900 /* Washington-Arlington-Alexandria, DC-VA-MD-WV   */ ///
    41940 /* San Jose-Sunnyvale-Santa Clara, CA             */ ///
    41740 /* San Diego-Chula Vista-Carlsbad, CA             */ ///
    33100 /* Miami-Fort Lauderdale-Pompano Beach, FL        */

foreach c of local superstar_core {
    replace superstar = 1 if cbsa_code == `c'
}

* Broad superstar definition (adds Denver, Houston, Phoenix — 13 CBSAs)
gen superstar_broad = superstar
local superstar_additional ///
    19740 /* Denver-Aurora-Lakewood, CO                     */ ///
    26420 /* Houston-The Woodlands-Sugar Land, TX           */ ///
    38060 /* Phoenix-Mesa-Chandler, AZ                      */

foreach c of local superstar_additional {
    replace superstar_broad = 1 if cbsa_code == `c'
}

*************************************************************
* Gyourko, Mayer, Sinai (2013) superstar classification
* 22 SMSAs from Appendix Table B → 18 unique CBSAs
*************************************************************

gen gyourko_superstar = 0
local gyourko_cbsas ///
    10580 /* Albany-Schenectady-Troy, NY                    */ ///
    14460 /* Boston-Cambridge-Newton, MA-NH                 */ ///
    19820 /* Detroit-Warren-Dearborn, MI                    */ ///
    31140 /* Louisville/Jefferson County, KY-IN             */ ///
    35300 /* New Haven-Milford, CT                          */ ///
    35620 /* New York-Newark-Jersey City, NY-NJ-PA          */ ///
    35980 /* Norwich-New London, CT                         */ ///
    37980 /* Philadelphia-Camden-Wilmington, PA-NJ-DE-MD    */ ///
    38340 /* Pittsfield, MA                                 */ ///
    39100 /* Poughkeepsie-Newburgh-Middletown, NY           */ ///
    39300 /* Providence-Warwick, RI-MA                      */ ///
    41500 /* Salinas, CA                                    */ ///
    41860 /* San Francisco-Oakland-Berkeley, CA             */ ///
    41940 /* San Jose-Sunnyvale-Santa Clara, CA             */ ///
    42100 /* Santa Cruz-Watsonville, CA                     */ ///
    42200 /* Santa Maria-Santa Barbara, CA                  */ ///
    44140 /* Springfield, MA                                */ ///
    45940 /* Trenton-Princeton, NJ                          */

foreach c of local gyourko_cbsas {
    replace gyourko_superstar = 1 if cbsa_code == `c'
}

label var superstar         "County in core superstar CBSA (10 CBSAs)"
label var superstar_broad   "County in broad superstar CBSA (13 CBSAs)"
label var gyourko_superstar "County in Gyourko et al. (2013) superstar CBSA (18 CBSAs)"

* Verify CBSA-level counts using preserve/restore
preserve
    bysort cbsa_code (county_fips): keep if _n == 1
    di _n "Core superstar CBSAs:"
    tab cbsatitle if superstar == 1, sort
    di _n "Additional broad superstar CBSAs:"
    tab cbsatitle if superstar_broad == 1 & superstar == 0, sort
    di _n "Gyourko superstar CBSAs:"
    tab cbsatitle if gyourko_superstar == 1, sort

    count if superstar == 1
    assert r(N) == 10
    count if superstar_broad == 1
    assert r(N) == 13
    count if gyourko_superstar == 1
    assert r(N) == 18
restore

* County-level summary
di _n "Counties in core superstar CBSAs:"
count if superstar == 1
di _n "Counties in broad superstar CBSAs:"
count if superstar_broad == 1
di _n "Counties in Gyourko superstar CBSAs:"
count if gyourko_superstar == 1

isid county_fips
di "Counties in superstar file: `=_N'"

order county_fips cbsa_code cbsatitle msa superstar superstar_broad gyourko_superstar

compress
save "$dirdata/cbsa_county_superstar.dta", replace

di _n "--- Part B: cbsa_county_superstar.dta saved ---"

di "*** Step 4 complete ***"

}


*************************************************************
* Step 5: Build county_cz_crosswalk.dta
*************************************************************

if $step_5 {

di _n "*** Step 5: Building county_cz_crosswalk.dta ***"

* Base: county-to-CZ crosswalk (~3,142 counties)
use "$dirdata/county_cz_xw_clean.dta", clear
di "Base counties (CZ crosswalk): `=_N'"

* Merge RUCC codes
merge 1:1 county_fips using "$dirdata/rucc_2013_clean.dta", gen(_m_rucc)
di _n "RUCC merge results:"
tab _m_rucc
* Keep all base counties even if no RUCC match
drop if _m_rucc == 2

* Merge CBSA county mapping (no superstar columns — keep crosswalk clean)
merge 1:1 county_fips using "$dirdata/cbsa_county_clean.dta", gen(_m_cbsa)
di _n "CBSA merge results:"
tab _m_cbsa
* Keep all base counties even if no CBSA match
drop if _m_cbsa == 2

* Merge education data
merge 1:1 county_fips using "$dirdata/education_clean.dta", gen(_m_educ)
di _n "Education merge results:"
tab _m_educ
* Keep all base counties even if no education match
drop if _m_educ == 2

* Merge race data
merge 1:1 county_fips using "$dirdata/race_clean.dta", gen(_m_race)
di _n "Race merge results:"
tab _m_race
* Keep all base counties even if no race match
drop if _m_race == 2

* Fill missing MSA indicator for non-CBSA counties
replace msa = 0 if missing(msa)

* Drop merge indicators
drop _m_rucc _m_cbsa _m_educ _m_race

* Label variables
label var county_fips        "5-digit County FIPS code"
label var cz                 "Commuting Zone ID"
capture label var czname     "Commuting Zone name"
capture label var county_name "County name"
capture label var state_abbr "State abbreviation"
capture label var county_pop2019 "County population (2019)"
capture label var rucc_2013  "USDA Rural-Urban Continuum Code 2013 (1-9)"
capture label var metro      "Metro county (RUCC 1-3)"
capture label var pop_2010   "County population (2010 Census)"
capture label var cbsa_code  "CBSA code (2020 OMB delineation)"
capture label var cbsatitle  "CBSA name"
label var msa                "Metropolitan Statistical Area"
capture label var centraloutlyingcounty "Central/outlying county"
capture label var share_college "Share adults with bachelor's degree+ (ACS 2017-21)"
capture label var share_black   "Share Black population (2019 Census est.)"

* Order variables
capture confirm variable pop_2010
if _rc == 0 {
    order county_fips county_name state_abbr cz czname county_pop2019 ///
        rucc_2013 metro pop_2010 cbsa_code cbsatitle msa centraloutlyingcounty ///
        share_college share_black
}
else {
    order county_fips county_name state_abbr cz czname county_pop2019 ///
        rucc_2013 metro cbsa_code cbsatitle msa centraloutlyingcounty ///
        share_college share_black
}

* Final integrity check
isid county_fips
count if missing(cz)
if r(N) > 0 {
    di as error "WARNING: " r(N) " counties with missing CZ — listing and dropping:"
    list county_fips county_name state_abbr if missing(cz), noobs
    drop if missing(cz)
}
di _n "county_cz_crosswalk.dta: `=_N' counties"

* Summary statistics
describe
tab metro
tab rucc_2013

compress
save "$dirdata/county_cz_crosswalk.dta", replace

di _n "--- county_cz_crosswalk.dta saved ---"

di _n "*** Step 5 complete ***"

}

*************************************************************
* Step 6: Build cz_measures.dta (CZ-level aggregates)
*************************************************************

if $step_6 {

di _n "*** Step 6: Building cz_measures.dta ***"

*-------------------------------------------------------
* 6A: Aggregate RUCC/metro to CZ level
*-------------------------------------------------------

di _n "--- 6A: Aggregating RUCC/metro to CZ ---"

use "$dirdata/county_cz_crosswalk.dta", clear

* Population in metro counties (treat missing metro as 0)
gen pop_metro = county_pop2019 * cond(missing(metro), 0, metro)

* Pop-weighted RUCC at county level (pre-compute for collapse)
* Weight each county's RUCC by its share of CZ population
* We compute this via a separate collapse to avoid [aw] distorting sums
tempfile cz_rucc_wt
preserve
    collapse (mean) cz_rucc_popwt=rucc_2013 ///
        cz_share_black=share_black ///
        cz_share_college=share_college ///
        [aw=county_pop2019], by(cz)
    save `cz_rucc_wt'
restore

* Count variable (need numeric for collapse count)
gen one = 1

* Collapse to CZ level (sums and counts only — no weights)
collapse (sum) cz_pop=county_pop2019 cz_pop_metro=pop_metro ///
    (sum) cz_n_counties=one, ///
    by(cz czname)

* Merge back pop-weighted RUCC
merge 1:1 cz using `cz_rucc_wt', assert(match) nogen

* Derive metro share and binary indicator
gen cz_metro_share = cz_pop_metro / cz_pop
gen cz_metro = (cz_metro_share > 0.5)
label define cz_metro_lbl 0 "Nonmetro CZ" 1 "Metro CZ"
label values cz_metro cz_metro_lbl

label var cz_pop          "CZ total population (2019)"
label var cz_pop_metro    "CZ metro population (2019)"
label var cz_n_counties   "Number of counties in CZ"
label var cz_rucc_popwt    "Pop-weighted mean RUCC (2013)"
label var cz_metro_share   "Share of CZ pop in metro counties"
label var cz_metro         "Metro CZ (>50% pop in metro counties)"
label var cz_share_black   "Pop-weighted share Black (2019)"
label var cz_share_college "Pop-weighted share bachelor's degree+ (2017-21)"

* Sanity checks
assert cz_metro_share >= 0 & cz_metro_share <= 1
assert !missing(cz_metro_share)
assert cz_share_black >= 0 & cz_share_black <= 1 if !missing(cz_share_black)
assert cz_share_college >= 0 & cz_share_college <= 1 if !missing(cz_share_college)
su cz_pop, meanonly
di _n "Total CZ population: " %15.0fc r(sum)
di "(Should be ~328 million)"

isid cz
di "CZs with RUCC/metro measures: `=_N'"

tempfile cz_metro_measures
save `cz_metro_measures'

*-------------------------------------------------------
* 6B: Aggregate superstar indicators to CZ level
*-------------------------------------------------------

di _n "--- 6B: Aggregating superstar to CZ ---"

use "$dirdata/county_cz_crosswalk.dta", clear

* Merge county-level superstar indicators
merge 1:1 county_fips using "$dirdata/cbsa_county_superstar.dta", ///
    keepusing(superstar superstar_broad gyourko_superstar) gen(_m_ss)
di _n "Superstar merge results:"
tab _m_ss
* Drop counties only in the superstar file (no CZ mapping)
drop if _m_ss == 2
* Non-CBSA counties won't match — fill with 0
replace superstar = 0 if missing(superstar)
replace superstar_broad = 0 if missing(superstar_broad)
replace gyourko_superstar = 0 if missing(gyourko_superstar)
drop _m_ss

* Collapse to CZ: a CZ is superstar if ANY of its counties is
collapse (max) superstar superstar_broad gyourko_superstar, by(cz)

* Print superstar CZ lists for inspection
di _n "Core superstar CZs:"
list cz if superstar == 1, noobs
di _n "Broad superstar CZs (additional):"
list cz if superstar_broad == 1 & superstar == 0, noobs
di _n "Gyourko superstar CZs:"
list cz if gyourko_superstar == 1, noobs

* Soft range assertions
* Note: CBSAs span multiple CZs, so CZ counts exceed CBSA counts
count if superstar == 1
di "Core superstar CZs: " r(N) " (expected 15-30)"
assert r(N) >= 15 & r(N) <= 30

count if superstar_broad == 1
di "Broad superstar CZs: " r(N) " (expected 18-35)"
assert r(N) >= 18 & r(N) <= 35

count if gyourko_superstar == 1
di "Gyourko superstar CZs: " r(N) " (expected 15-30)"
assert r(N) >= 15 & r(N) <= 30

label var superstar         "Core superstar CZ (any county in 10 CBSAs)"
label var superstar_broad   "Broad superstar CZ (any county in 13 CBSAs)"
label var gyourko_superstar "Gyourko et al. (2013) superstar CZ (any county in 18 CBSAs)"

isid cz
tempfile cz_superstar
save `cz_superstar'

*-------------------------------------------------------
* 6C: Merge all CZ measures
*-------------------------------------------------------

di _n "--- 6C: Merging all CZ measures ---"

* Start with RUCC/metro measures
use `cz_metro_measures', clear

* Merge superstar indicators
merge 1:1 cz using `cz_superstar', gen(_m_ss)
di _n "Superstar CZ merge results:"
tab _m_ss
* Fill 0 for fully-rural CZs with no CBSA counties at all
replace superstar = 0 if missing(superstar)
replace superstar_broad = 0 if missing(superstar_broad)
replace gyourko_superstar = 0 if missing(gyourko_superstar)
drop _m_ss

* Merge Chetty CZ causal place effects (all variables)
merge 1:1 cz using "$dirdata/chetty_cz_causal_clean.dta", gen(_m_chetty)
di _n "Chetty CZ merge results:"
tab _m_chetty
* Accept non-matches gracefully (coverage differences)
drop _m_chetty

* Final integrity checks
isid cz
assert !missing(superstar)
assert !missing(superstar_broad)
assert !missing(gyourko_superstar)
assert !missing(cz_metro_share)

di _n "cz_measures.dta: `=_N' commuting zones"
di _n "Metro/nonmetro split:"
tab cz_metro
di _n "Core superstar:"
tab superstar
di _n "Broad superstar:"
tab superstar_broad
di _n "Gyourko superstar:"
tab gyourko_superstar

* Order variables
order cz czname cz_pop cz_n_counties ///
    cz_metro_share cz_metro cz_rucc_popwt ///
    cz_share_black cz_share_college ///
    superstar superstar_broad gyourko_superstar

describe

compress
save "$dirdata/cz_measures.dta", replace

di _n "--- cz_measures.dta saved ---"


*-------------------------------------------------------
* Print usage instructions
*-------------------------------------------------------

di _n "============================================================"
di    "  OUTPUT FILES"
di    "============================================================"
di    "  1. county_cz_crosswalk.dta   (keyed on county_fips)"
di    "     - CZ mapping, RUCC, CBSA, share_black, share_college"
di    "  2. cz_measures.dta           (keyed on cz)"
di    "     - Urban/rural, superstar, cz_share_black,"
di    "       cz_share_college, Chetty causal effects"
di    ""
di    "  USAGE:"
di    "  -------------------------------------------------------"
di    "  Step A: merge 1:1 county_fips using county_cz_crosswalk"
di    "          (county-level analysis with CZ mapping)"
di    "  Step B: merge m:1 cz using cz_measures"
di    "          (attach CZ-level measures to county data)"
di    "============================================================"

di _n "*** Step 6 complete ***"

}


di _n "*** county_crosswalk.do completed ***"
