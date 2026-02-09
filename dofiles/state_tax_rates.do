*************************************************************
* State Tax Rates Panel Dataset (2002-2021)                **
* Creates state-by-year panel of top marginal income tax   **
* rates and capital gains tax rates for all 50 states + DC **
*                                                          **
* Output: state_tax_rates.dta (keyed on state_abbr year)   **
*************************************************************

clear all
set more off

* Load project paths
do "/Users/jar88/Dropbox/research_projects/revision_analysis/claudetest/dofiles/paths.do"

cd "$dirdata"

* Step flags
global step_0 = 1   // Download ITEP data
global step_1 = 1   // Import and clean ITEP data
global step_2 = 1   // Create capital gains rate variable
global step_3 = 1   // Finalize and save


*************************************************************
* Step 0: Download ITEP Historical State Tax Rate Data
*************************************************************

if $step_0 {

di _n "*** Step 0: Downloading ITEP Historical State Tax Rate Data ***"

* Source: Institute on Taxation and Economic Policy (ITEP)
* URL: https://itep.org/historical-state-tax-rate-data/
* File: ITEP-State-Tax-Rate-Historical-Data.xlsx

capture confirm file "$dirdata/ITEP-State-Tax-Rate-Historical-Data.xlsx"
if _rc != 0 {
    di "Downloading ITEP Historical State Tax Rate Data..."
    capture copy "https://itep.sfo2.digitaloceanspaces.com/ITEP-State-Tax-Rate-Historical-Data.xlsx" ///
        "$dirdata/ITEP-State-Tax-Rate-Historical-Data.xlsx", replace
    if _rc != 0 {
        * Try alternate URL
        capture copy "https://itep.org/wp-content/uploads/ITEP-State-Tax-Rate-Historical-Data.xlsx" ///
            "$dirdata/ITEP-State-Tax-Rate-Historical-Data.xlsx", replace
        if _rc != 0 {
            di as error "============================================================"
            di as error "Automatic download failed for ITEP data."
            di as error "Please manually download from:"
            di as error "  https://itep.org/historical-state-tax-rate-data/"
            di as error "  (Click the download link for the Excel file)"
            di as error "Save as: $dirdata/ITEP-State-Tax-Rate-Historical-Data.xlsx"
            di as error "============================================================"
            exit 601
        }
    }
}
else {
    di "ITEP-State-Tax-Rate-Historical-Data.xlsx already exists, skipping download."
}

di _n "*** Step 0 complete ***"

}


*************************************************************
* Step 1: Import and clean ITEP data
*************************************************************

if $step_1 {

di _n "*** Step 1: Importing and cleaning ITEP data ***"

* ITEP file structure (verified):
*   Sheet: "PIT_history"
*   Column A (TopStatePITRate): state names, rows 2-52 = 51 states
*   Columns CZ-DS: years 2002-2021 (numeric, decimal form e.g. 0.05 = 5%)
*   Rows 53+: blank rows, "Top Federal PIT Rate", notes, summary stats

import excel using "$dirdata/ITEP-State-Tax-Rate-Historical-Data.xlsx", ///
    sheet("PIT_history") firstrow clear

* Rename known columns: TopStatePITRate = state, CZ..DS = 2002..2021
rename TopStatePITRate state_name
rename (CZ DA DB DC DD DE DF DG DH DI DJ DK DL DM DN DO DP DQ DR DS) ///
    (v2002 v2003 v2004 v2005 v2006 v2007 v2008 v2009 v2010 v2011 ///
     v2012 v2013 v2014 v2015 v2016 v2017 v2018 v2019 v2020 v2021)

keep state_name v2002-v2021

* Drop non-state rows (blank, federal rate, notes, summary stats)
drop if state_name == "" | missing(state_name)
drop if regexm(state_name, "^(Top |Note|Source|Summary|#|Median)")
assert _N == 51

* Reshape to long
reshape long v, i(state_name) j(year)
rename v top_income_rate

* Standardize state names (proper() handles "District of Columbia" → "District Of Columbia")
replace state_name = proper(state_name)

* Map state names to abbreviations and FIPS codes (50 states + DC)
gen state_abbr = ""
gen state_fips = .

local snames `" "Alabama" "Alaska" "Arizona" "Arkansas" "California" "Colorado" "Connecticut" "Delaware" "District Of Columbia" "Florida" "Georgia" "Hawaii" "Idaho" "Illinois" "Indiana" "Iowa" "Kansas" "Kentucky" "Louisiana" "Maine" "Maryland" "Massachusetts" "Michigan" "Minnesota" "Mississippi" "Missouri" "Montana" "Nebraska" "Nevada" "New Hampshire" "New Jersey" "New Mexico" "New York" "North Carolina" "North Dakota" "Ohio" "Oklahoma" "Oregon" "Pennsylvania" "Rhode Island" "South Carolina" "South Dakota" "Tennessee" "Texas" "Utah" "Vermont" "Virginia" "Washington" "West Virginia" "Wisconsin" "Wyoming" "'

tokenize `"`snames'"'

local sabbrs "AL AK AZ AR CA CO CT DE DC FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY"

local sfips "01 02 04 05 06 08 09 10 11 12 13 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 44 45 46 47 48 49 50 51 53 54 55 56"

local n_states : word count `sabbrs'
forvalues i = 1/`n_states' {
    local sn "``i''"
    local sa : word `i' of `sabbrs'
    local sf : word `i' of `sfips'
    replace state_abbr = "`sa'" if state_name == "`sn'"
    replace state_fips = `sf'   if state_name == "`sn'"
}

assert _N == 51 * 20

* Rates are in DECIMAL form (e.g., 0.05 for 5%, 0.133 for 13.3%)
* Convert to percentage points
replace top_income_rate = top_income_rate * 100

* Replace missing rates with 0 for no-income-tax states
* (ITEP already codes these as 0, but ensure consistency)
foreach st in AK FL NV SD TX WY WA {
    replace top_income_rate = 0 if state_abbr == "`st'"
}
replace top_income_rate = 0 if state_abbr == "NH"
replace top_income_rate = 0 if state_abbr == "TN"

label var state_name     "State name"
label var state_abbr     "State abbreviation"
label var state_fips     "State FIPS code"
label var year           "Year"
label var top_income_rate "Top marginal personal income tax rate (%)"

order state_abbr state_name state_fips year top_income_rate
sort state_abbr year

compress
save "$dirdata/state_tax_rates_raw.dta", replace

di _n "*** Step 1 complete ***"

}


*************************************************************
* Step 2: Create capital gains rate variable
*************************************************************

if $step_2 {

di _n "*** Step 2: Creating capital gains rate variable ***"

use "$dirdata/state_tax_rates_raw.dta", clear

*-------------------------------------------------------
* Start: CG rate = income tax rate for all states
*-------------------------------------------------------
gen top_cg_rate = top_income_rate

*-------------------------------------------------------
* No-income-tax states: CG rate = 0
* AK, FL, NV, SD, TX, WY have no income tax at all
* WA has no income tax (capital gains tax enacted 2022, outside our window)
*-------------------------------------------------------
foreach st in AK FL NV SD TX WY WA {
    replace top_cg_rate = 0 if state_abbr == "`st'"
}

*-------------------------------------------------------
* Special cases: NH and TN
* NH: taxes interest/dividends only, not capital gains
* TN: taxed interest/dividends only (Hall Tax), repealed by 2021
*   - TN began phasing out in 2016 (6% -> 5% -> 4% -> ... -> 0% in 2021)
*   - Neither state taxes capital gains
*-------------------------------------------------------
replace top_cg_rate = 0 if state_abbr == "NH"
replace top_cg_rate = 0 if state_abbr == "TN"

*-------------------------------------------------------
* Flag for states with CG preferences
*-------------------------------------------------------
gen cg_exclusion_state = 0

*-------------------------------------------------------
* Capital gains exclusion/preference states
* Most apply current rules; known historical changes documented below.
*-------------------------------------------------------

* 1. Arizona: CG subtraction phased in starting 2013 (Laws 2012, Ch. 343)
*    No exclusion 2002-2012. Phase-in: 10% (2013), 20% (2014), 25% (2015+).
*    Only applies to assets acquired after 12/31/2011.
replace top_cg_rate = top_income_rate * 0.90 if state_abbr == "AZ" & year == 2013
replace top_cg_rate = top_income_rate * 0.80 if state_abbr == "AZ" & year == 2014
replace top_cg_rate = top_income_rate * 0.75 if state_abbr == "AZ" & year >= 2015
replace cg_exclusion_state = 1 if state_abbr == "AZ" & year >= 2013

* 2. Arkansas: CG exclusion (Act 1005 of 1999; expanded by Act 1488 of 2013)
*    2002-2014: 30% exclusion of net CG
*    2015: increased to 45% (Feb 2015 phase-in)
*    2016+: increased to 50% (Jul 2016). Gains >$10M fully exempt from 2014+.
replace top_cg_rate = top_income_rate * 0.70 if state_abbr == "AR" & year <= 2014
replace top_cg_rate = top_income_rate * 0.55 if state_abbr == "AR" & year == 2015
replace top_cg_rate = top_income_rate * 0.50 if state_abbr == "AR" & year >= 2016
replace cg_exclusion_state = 1 if state_abbr == "AR"

* 3. Hawaii: Alternative CG tax rate of 7.25% (HRS 235-51(f), since 1987)
*    Flat 7.25% on all capital gains, stable throughout 2002-2021.
*    Benefit vs ordinary rate varies: 1pp savings at 8.25% top rate (2002-08, 2016),
*    3.75pp savings at 11% top rate (2009-15, 2017-21).
replace top_cg_rate = 7.25 if state_abbr == "HI"
replace cg_exclusion_state = 1 if state_abbr == "HI"

* 4. Montana: Capital gains TAX CREDIT (not exclusion) (SB 407, 2003; MCA 15-30-2301)
*    2002-2004: no CG preference (pre-SB 407 reform)
*    2005-2006: 1% nonrefundable credit on net CG (effective rate = top_rate - 1pp)
*    2007-2021: 2% nonrefundable credit on net CG (effective rate = top_rate - 2pp)
*    At 6.9% top rate, 2% credit yields effective CG rate of 4.9%.
replace top_cg_rate = top_income_rate - 1 if state_abbr == "MT" & inrange(year, 2005, 2006)
replace top_cg_rate = top_income_rate - 2 if state_abbr == "MT" & year >= 2007
replace cg_exclusion_state = 1 if state_abbr == "MT" & year >= 2005

* 5. New Mexico: CG deduction phased in 2003-2007 (Laws 2003, ch. 2; HB 6, 2019)
*    2002: only $1,000 flat deduction (negligible, treat as no preference)
*    2003: 10% deduction. 2004: 20%. 2005: 30%. 2006: 40%.
*    2007-2018: 50% deduction
*    2019-2021: reduced to 40% (HB 6 / ch. 270)
replace top_cg_rate = top_income_rate * 0.90 if state_abbr == "NM" & year == 2003
replace top_cg_rate = top_income_rate * 0.80 if state_abbr == "NM" & year == 2004
replace top_cg_rate = top_income_rate * 0.70 if state_abbr == "NM" & year == 2005
replace top_cg_rate = top_income_rate * 0.60 if state_abbr == "NM" & year == 2006
replace top_cg_rate = top_income_rate * 0.50 if state_abbr == "NM" & inrange(year, 2007, 2018)
replace top_cg_rate = top_income_rate * 0.60 if state_abbr == "NM" & year >= 2019
replace cg_exclusion_state = 1 if state_abbr == "NM" & year >= 2003

* 6. North Dakota: CG exclusion (restructured 2001; increased 2009; scope limited 2013)
*    2002-2008: ~30% exclusion of LTCG and qualified dividends
*    2009+: increased to 40% exclusion (2009 legislative session)
*    From 2013: limited to gains allocable to North Dakota only
replace top_cg_rate = top_income_rate * 0.70 if state_abbr == "ND" & year <= 2008
replace top_cg_rate = top_income_rate * 0.60 if state_abbr == "ND" & year >= 2009
replace cg_exclusion_state = 1 if state_abbr == "ND"

* 7. South Carolina: 44% deduction of net CG (2000 Act No. 387, since TY 2001)
*    Stable at 44% throughout 2002-2021. No changes.
replace top_cg_rate = top_income_rate * 0.56 if state_abbr == "SC"
replace cg_exclusion_state = 1 if state_abbr == "SC"

* 8. Vermont: CG exclusion — complex history
*    2002-2009: broad 40% exclusion on all LTCG including publicly traded securities
*    2010: exclusion suspended (Act 68, 2009); only $2,500 flat exclusion remains
*    2011-2018: restructured (Act 45, 2011) — 40% exclusion restored but ONLY for
*       business real estate, farm property, goodwill, and standing timber (3+ yr hold).
*       Does NOT apply to publicly traded stocks/bonds or residential real estate.
*       Alternative flat $5,000 exclusion available for all CG types.
*    2019-2021: 40% exclusion (on qualifying assets) capped at $350K (Act 71, 2019)
*    For general/portfolio capital gains: effective exclusion applies only 2002-2009.
replace top_cg_rate = top_income_rate * 0.60 if state_abbr == "VT" & year <= 2009
replace cg_exclusion_state = 1 if state_abbr == "VT" & year <= 2009

* 9. Wisconsin: CG exclusion reduced in 2009 (1987 Act 27; 2009 Act 28)
*    2002-2008: 60% exclusion of net LTCG (assets held >1 year)
*    2009-2021: reduced to 30% exclusion (2009 Act 28). 60% preserved for farm assets only.
replace top_cg_rate = top_income_rate * 0.40 if state_abbr == "WI" & year <= 2008
replace top_cg_rate = top_income_rate * 0.70 if state_abbr == "WI" & year >= 2009
replace cg_exclusion_state = 1 if state_abbr == "WI"

*-------------------------------------------------------
* Flag no-income-tax states
*-------------------------------------------------------
gen no_income_tax = 0
foreach st in AK FL NV SD TX WY WA {
    replace no_income_tax = 1 if state_abbr == "`st'"
}
* NH and TN have limited income taxes but not on CG
replace no_income_tax = 1 if state_abbr == "NH"
replace no_income_tax = 1 if state_abbr == "TN"

*-------------------------------------------------------
* Labels
*-------------------------------------------------------
label var top_cg_rate       "Top effective capital gains tax rate (%)"
label var cg_exclusion_state "State has CG exclusion/preference (1=yes)"
label var no_income_tax     "No broad-based income tax (1=yes)"

* Round rates for cleanliness
replace top_cg_rate = round(top_cg_rate, 0.01)
replace top_income_rate = round(top_income_rate, 0.01)

order state_abbr state_name state_fips year top_income_rate top_cg_rate ///
    no_income_tax cg_exclusion_state
sort state_abbr year

compress
save "$dirdata/state_tax_rates_step2.dta", replace

di _n "*** Step 2 complete ***"

}


*************************************************************
* Step 3: Finalize and save
*************************************************************

if $step_3 {

di _n "*** Step 3: Finalizing and saving ***"

use "$dirdata/state_tax_rates_step2.dta", clear

*-------------------------------------------------------
* Integrity checks
*-------------------------------------------------------

* Unique on state_abbr × year
isid state_abbr year

* Count
di "Total observations: `=_N'"
local expected_obs = 51 * 20
di "Expected observations (51 x 20): `expected_obs'"
assert _N == `expected_obs'

* No-income-tax states should have rates of 0
count if no_income_tax == 1 & top_income_rate != 0
if r(N) > 0 {
    di as error "WARNING: `r(N)' no-income-tax state-years have nonzero income rate"
    list state_abbr year top_income_rate if no_income_tax == 1 & top_income_rate != 0
}

count if no_income_tax == 1 & top_cg_rate != 0
if r(N) > 0 {
    di as error "WARNING: `r(N)' no-income-tax state-years have nonzero CG rate"
    list state_abbr year top_cg_rate if no_income_tax == 1 & top_cg_rate != 0
}

* CG exclusion states should have CG rate < income rate (when income rate > 0)
count if cg_exclusion_state == 1 & top_cg_rate >= top_income_rate & top_income_rate > 0
if r(N) > 0 {
    di as error "WARNING: `r(N)' CG exclusion state-years have CG rate >= income rate"
    list state_abbr year top_income_rate top_cg_rate if cg_exclusion_state == 1 & top_cg_rate >= top_income_rate & top_income_rate > 0
}

*-------------------------------------------------------
* Variable labels
*-------------------------------------------------------
label var state_abbr         "State abbreviation"
label var state_name         "State name"
label var state_fips         "State FIPS code"
label var year               "Year"
label var top_income_rate    "Top marginal personal income tax rate (%)"
label var top_cg_rate        "Top effective capital gains tax rate (%)"
label var no_income_tax      "No broad-based income tax (1=yes)"
label var cg_exclusion_state "State has CG exclusion/preference (1=yes)"

*-------------------------------------------------------
* Final ordering and save
*-------------------------------------------------------
order state_abbr state_name state_fips year top_income_rate top_cg_rate ///
    no_income_tax cg_exclusion_state
sort state_abbr year

compress
save "$dirdata/state_tax_rates.dta", replace

*-------------------------------------------------------
* Summary output
*-------------------------------------------------------
di _n "============================================================"
di    "  STATE TAX RATES PANEL: SUMMARY"
di    "============================================================"

di _n "--- Observations ---"
di "Total: `=_N' (51 states x 20 years)"

di _n "--- Income tax rate distribution (selected years) ---"
foreach y in 2002 2010 2015 2021 {
    di _n "Year `y':"
    sum top_income_rate if year == `y', detail
}

di _n "--- No-income-tax states ---"
tab state_abbr if no_income_tax == 1 & year == 2021

di _n "--- CG exclusion/preference states ---"
list state_abbr state_name top_income_rate top_cg_rate if cg_exclusion_state == 1 & year == 2021, ///
    noobs clean

di _n "--- Top 5 highest income tax states (2021) ---"
preserve
keep if year == 2021
gsort -top_income_rate +state_abbr
list state_abbr state_name top_income_rate top_cg_rate in 1/5, noobs clean
restore

di _n "--- Top 5 highest CG tax states (2021) ---"
preserve
keep if year == 2021
gsort -top_cg_rate +state_abbr
list state_abbr state_name top_income_rate top_cg_rate in 1/5, noobs clean
restore

di _n "============================================================"
di    "  OUTPUT: $dirdata/state_tax_rates.dta"
di    "  Keyed on: state_abbr year"
di    "  Years: 2002-2021"
di    "  States: 50 + DC = 51"
di    "============================================================"
di    ""
di    "  USAGE: merge with other project data"
di    "  -------------------------------------------------"
di    "  Example: merge m:1 state_abbr year using state_tax_rates.dta"
di    "  Or:      merge m:1 state_fips year using state_tax_rates.dta"
di    "============================================================"

* Clean up intermediate files
capture erase "$dirdata/state_tax_rates_raw.dta"
capture erase "$dirdata/state_tax_rates_step2.dta"

di _n "*** Step 3 complete ***"

}

di _n "*** state_tax_rates.do completed ***"
