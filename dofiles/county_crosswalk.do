*************************************************************
* County-to-CZ Crosswalk Construction                       **
* Builds three output files:                                 **
*   1. county_crosswalk.dta — county-level crosswalk         **
*      with CZ mapping, RUCC, CBSA (no superstars)          **
*      (keyed on county_fips)                                **
*   2. cbsa_superstar.dta — CBSA-level superstar indicators  **
*      (keyed on cbsa_code)                                  **
*   3. cz_measures.dta — Chetty CZ causal place effects only **
*      (keyed on cz)                                         **
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
global step_3 = 1   // Clean USDA RUCC 2013
global step_4 = 1   // Clean CBSA crosswalk + superstar coding
global step_5 = 1   // Merge into final output files


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
* Step 3: Clean USDA Rural-Urban Continuum Codes (2013)
*************************************************************

if $step_3 {

di _n "*** Step 3: Cleaning USDA RUCC 2013 ***"

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

    * Already string -- pad to 5 digits
    gen str5 county_fips = fips_raw
    replace county_fips = "0" + county_fips if strlen(county_fips) == 4
    replace county_fips = "00" + county_fips if strlen(county_fips) == 3


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
keep county_fips rucc_2013 metro pop_2010

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
* Part B: CBSA-level superstar file
*-------------------------------------------------------

* Collapse to one row per CBSA
use "$dirdata/cbsa_county_clean.dta", clear
bysort cbsa_code (county_fips): keep if _n == 1
keep cbsa_code cbsatitle msa

*************************************************************
* Define superstar cities (ad hoc)
* Based on Autor (2019) / common usage
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

label var superstar         "Superstar city, core (10 CBSAs)"
label var superstar_broad   "Superstar city, broad (13 CBSAs)"
label var gyourko_superstar "Superstar city (Gyourko, Mayer, Sinai 2013, 18 CBSAs)"
label var msa               "Metropolitan Statistical Area"

* Check coding
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

isid cbsa_code
di "CBSAs in superstar file: `=_N'"

order cbsa_code cbsatitle msa superstar superstar_broad gyourko_superstar

compress
save "$dirdata/cbsa_superstar.dta", replace

di _n "--- Part B: cbsa_superstar.dta saved ---"

di "*** Step 4 complete ***"

}


*************************************************************
* Step 5: Merge into final output files
*************************************************************

if $step_5 {

di _n "*** Step 5: Building final output files ***"

*-------------------------------------------------------
* File 1: county_crosswalk.dta (keyed on county_fips)
*   Geography only — no superstar columns
*-------------------------------------------------------

di _n "--- Building county_crosswalk.dta ---"

* Base: county-to-CZ crosswalk (~3,142 counties)
use "$dirdata/county_cz_xw_clean.dta", clear
di "Base counties (CZ crosswalk): `=_N'"

* Merge RUCC codes
merge 1:1 county_fips using "$dirdata/rucc_2013_clean.dta", gen(_m_rucc)
di _n "RUCC merge results:"
tab _m_rucc
* Keep all base counties even if no RUCC match
drop if _m_rucc == 2

* Merge CBSA county mapping (no superstar columns)
merge 1:1 county_fips using "$dirdata/cbsa_county_clean.dta", gen(_m_cbsa)
di _n "CBSA merge results:"
tab _m_cbsa
* Keep all base counties even if no CBSA match
drop if _m_cbsa == 2

* Fill missing MSA indicator for non-CBSA counties
replace msa = 0 if missing(msa)

* Drop merge indicators
drop _m_rucc _m_cbsa

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

* Order variables
order county_fips county_name state_abbr cz czname county_pop2019 ///
    cbsa_code cbsatitle rucc_2013 metro pop_2010 msa centraloutlyingcounty

* Final integrity check
isid county_fips
di _n "county_crosswalk.dta: `=_N' counties"

* Summary statistics
describe
tab metro
tab rucc_2013

compress
save "$dirdata/county_crosswalk.dta", replace

di _n "--- county_crosswalk.dta saved ---"


*-------------------------------------------------------
* File 2: cbsa_superstar.dta — already saved in Step 4B
*-------------------------------------------------------

di _n "--- cbsa_superstar.dta already saved in Step 4 ---"


*-------------------------------------------------------
* File 3: cz_measures.dta (keyed on cz)
*   Chetty CZ causal place effects only
*-------------------------------------------------------

di _n "--- Building cz_measures.dta ---"

use "$dirdata/chetty_cz_causal_clean.dta", clear

isid cz
di "cz_measures.dta: `=_N' commuting zones"
describe, short

compress
save "$dirdata/cz_measures.dta", replace

di _n "--- cz_measures.dta saved ---"


*-------------------------------------------------------
* Print usage instructions
*-------------------------------------------------------

di _n "============================================================"
di    "  OUTPUT FILES"
di    "============================================================"
di    "  1. county_crosswalk.dta   (keyed on county_fips)"
di    "     - CZ mapping, RUCC, CBSA code (no superstars)"
di    "  2. cbsa_superstar.dta     (keyed on cbsa_code)"
di    "     - superstar + gyourko_superstar indicators"
di    "  3. cz_measures.dta        (keyed on cz)"
di    "     - Chetty CZ causal place effects only"
di    ""
di    "  USAGE:"
di    "  -------------------------------------------------------"
di    "  Step A: merge 1:1 county_fips using county_crosswalk.dta"
di    "  Step B: merge m:1 cbsa_code  using cbsa_superstar.dta"
di    "          (for superstar analysis)"
di    "  Step C: collapse ... , by(cz)"
di    "          (for CZ analysis)"
di    "  Step D: merge 1:1 cz using cz_measures.dta"
di    "          (for Chetty variables)"
di    "============================================================"

di _n "*** Step 5 complete ***"

}

di _n "*** county_crosswalk.do completed ***"
