*************************************************************
* State Estate & Inheritance Tax Panel Dataset (2002-2021)  **
* Creates state-by-year panel of binary indicators for      **
* estate tax and inheritance tax for all 50 states + DC     **
*                                                           **
* Output: state_estate_tax.dta (keyed on state_abbr year)   **
*************************************************************
*
* CODING RULE: has_estate_tax = 1 if and only if an
* INDEPENDENT or DECOUPLED state estate tax applied to
* deaths occurring in that calendar year. Pick-up-only
* taxes tied to the current federal state death tax credit
* are coded as 0. This matters for 2002-2005: EGTRRA (2001)
* phased out the federal credit (reduced 25%/yr 2002-2004,
* eliminated 2005). States that froze their IRC reference
* date ("decoupled") before 2003 are coded as having estate
* taxes from 2002; states that decoupled later are coded
* from their effective year.
*
* SOURCES:
*   Tax Foundation annual reports
*   McGuireWoods/ACTEC State Death Tax Chart
*   Moretti & Wilson (AEJ: Economic Policy, 2023)
*   Individual state statutes and legislative histories
*   CBPP, "Many States Are Decoupling from the Federal
*     Estate Tax Cut" (various years)
*
* VERIFIED: Each state's coding was individually verified
* against web sources including state revenue department
* publications, legislative histories, and legal analyses.
* See accompanying session log for full source citations.
*************************************************************

clear all
set more off

* Load project paths
do "/Users/jar88/Dropbox/research_projects/revision_analysis/claudetest/dofiles/paths.do"

cd "$dirdata"

* Step flags
global step_0 = 1   // Build panel skeleton
global step_1 = 1   // Code estate tax indicator
global step_2 = 1   // Code inheritance tax indicator
global step_3 = 1   // Finalize, validate, and save
global step_4 = 1   // Merge with state_tax_rates to create combined panel


*************************************************************
* Step 0: Build 51 x 20 state-year panel skeleton
*************************************************************

if $step_0 {

di _n "*** Step 0: Building state-year panel skeleton ***"

* Create one observation per state (51 = 50 states + DC)
clear
set obs 51

gen state_name = ""
gen state_abbr = ""
gen state_fips = .

* State crosswalk (same as state_tax_rates.do)
local snames `" "Alabama" "Alaska" "Arizona" "Arkansas" "California" "Colorado" "Connecticut" "Delaware" "District Of Columbia" "Florida" "Georgia" "Hawaii" "Idaho" "Illinois" "Indiana" "Iowa" "Kansas" "Kentucky" "Louisiana" "Maine" "Maryland" "Massachusetts" "Michigan" "Minnesota" "Mississippi" "Missouri" "Montana" "Nebraska" "Nevada" "New Hampshire" "New Jersey" "New Mexico" "New York" "North Carolina" "North Dakota" "Ohio" "Oklahoma" "Oregon" "Pennsylvania" "Rhode Island" "South Carolina" "South Dakota" "Tennessee" "Texas" "Utah" "Vermont" "Virginia" "Washington" "West Virginia" "Wisconsin" "Wyoming" "'

tokenize `"`snames'"'

local sabbrs "AL AK AZ AR CA CO CT DE DC FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY"

local sfips "01 02 04 05 06 08 09 10 11 12 13 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 44 45 46 47 48 49 50 51 53 54 55 56"

local n_states : word count `sabbrs'
forvalues i = 1/`n_states' {
    local sn "``i''"
    local sa : word `i' of `sabbrs'
    local sf : word `i' of `sfips'
    replace state_name = "`sn'" in `i'
    replace state_abbr = "`sa'" in `i'
    replace state_fips = `sf'   in `i'
}

assert _N == 51

* Expand to 20 years (2002-2021)
expand 20
bysort state_abbr: gen year = 2001 + _n

assert _N == 51 * 20

order state_abbr state_name state_fips year
sort state_abbr year

compress
save "$dirdata/state_estate_tax_skeleton.dta", replace

di _n "*** Step 0 complete ***"

}


*************************************************************
* Step 1: Code binary estate tax indicator
*************************************************************

if $step_1 {

di _n "*** Step 1: Coding estate tax indicator ***"

use "$dirdata/state_estate_tax_skeleton.dta", clear

gen has_estate_tax = 0

*-------------------------------------------------------
* A. States with independent estate tax throughout
*    2002-2021 (6 jurisdictions)
*    All decoupled in 2002 or earlier by freezing their
*    IRC reference date to a pre-EGTRRA date.
*-------------------------------------------------------

* DC: D.C. Code § 47-3701 et seq.; Inheritance and Estate Tax Act of 2002
replace has_estate_tax = 1 if state_abbr == "DC"

* Maryland: Md. Tax-Gen. Code Ann. § 7-309; Budget Reconciliation Act of 2002 (Ch. 440)
replace has_estate_tax = 1 if state_abbr == "MD"

* Minnesota: Minn. Stat. § 291.005; decoupled May 2002 via conformity package
replace has_estate_tax = 1 if state_abbr == "MN"

* New York: N.Y. Tax Law § 951; already frozen at IRC as of July 22, 1998
* (1997 reform; no separate decoupling needed after EGTRRA)
replace has_estate_tax = 1 if state_abbr == "NY"

* Rhode Island: R.I. Gen. Laws § 44-22-1.1; decoupled 2002 (P.L. 2002, ch. 65)
* effective for deaths on or after Jan 1, 2002
replace has_estate_tax = 1 if state_abbr == "RI"

* Vermont: 32 V.S.A. § 7402; decoupled June 21, 2002 (Act 140, 2001 Adj. Sess.)
replace has_estate_tax = 1 if state_abbr == "VT"

*-------------------------------------------------------
* B. States with independent estate tax from 2003
*    (3 states: decoupled in 2002-2003, effective for
*    deaths in 2003+; in 2002 they had pick-up tax only)
*-------------------------------------------------------

* Maine: 36 M.R.S. § 4062; L.D. 1319 enacted March 27, 2003,
* retroactive to deaths after 12/31/2002 (i.e., 2003 deaths onward)
replace has_estate_tax = 1 if state_abbr == "ME" & year >= 2003

* Massachusetts: M.G.L. ch. 65C; Ch. 186 of Acts of 2002 enacted July 25, 2002,
* effective for deaths from Jan 1, 2003 onward
replace has_estate_tax = 1 if state_abbr == "MA" & year >= 2003

* Oregon: ORS § 118.005 et seq.; HB 3072 signed Sept 24, 2003,
* decoupled to IRC as of 12/31/2000; amnesty for 2002 estates under $1M
replace has_estate_tax = 1 if state_abbr == "OR" & year >= 2003

*-------------------------------------------------------
* C. States with independent estate tax from 2005
*    (2 states: did not decouple until 2005; had only
*    diminishing pick-up tax in 2002-2004)
*-------------------------------------------------------

* Connecticut: Conn. Gen. Stat. § 12-391; PA 05-251 created standalone
* estate/gift tax effective Jan 1, 2005 (pick-up only through 2004;
* temporary quasi-independent tax July-Dec 2004 under PA 03-1)
replace has_estate_tax = 1 if state_abbr == "CT" & year >= 2005

* Washington: RCW 83.100; ESB 6096 enacted May 17, 2005
* (WA Supreme Court ruled in Estate of Hemphill that WA had only
* a pick-up tax in 2002-2004, not an independent tax)
replace has_estate_tax = 1 if state_abbr == "WA" & year >= 2005

*-------------------------------------------------------
* D. States with estate tax ending before 2022
*    (started at or after 2002, ended by 2017)
*-------------------------------------------------------

* Kansas: K.S.A. § 79-15,203; froze IRC at 12/31/1997;
* transitioned to standalone tax 2007-2009 (SB 365); repealed Jan 1, 2010
replace has_estate_tax = 1 if state_abbr == "KS" & inrange(year, 2002, 2009)

* New Jersey: N.J.S.A. § 54:38-1; decoupled Jan 1, 2002 (Ch. 31);
* estate tax repealed Jan 1, 2018 (inheritance tax remains)
replace has_estate_tax = 1 if state_abbr == "NJ" & inrange(year, 2002, 2017)

* North Carolina: N.C.G.S. § 105-32.2; decoupled May 2002 (SB 1115);
* repealed retroactive to Jan 1, 2013 (HB 998, signed July 23, 2013)
replace has_estate_tax = 1 if state_abbr == "NC" & inrange(year, 2002, 2012)

* Ohio: ORC § 5731; standalone estate tax since 1968 (never a pick-up tax);
* repealed Jan 1, 2013 (HB 153, signed Sept 29, 2011)
replace has_estate_tax = 1 if state_abbr == "OH" & inrange(year, 2002, 2012)

* Wisconsin: Wis. Stat. § 72; 2001 Act 16 created temporary decoupled tax
* Oct 1, 2002 through Dec 31, 2007 (built-in sunset); no tax after 2007
replace has_estate_tax = 1 if state_abbr == "WI" & inrange(year, 2002, 2007)

*-------------------------------------------------------
* E. States that re-enacted estate tax after a gap
*-------------------------------------------------------

* Delaware: 30 Del. C. ch. 15; pick-up tax lapsed with federal credit;
* NO independent tax 2002-2008; re-enacted July 1, 2009 (HB 291,
* $3.5M exemption); repealed Jan 1, 2018
replace has_estate_tax = 1 if state_abbr == "DE" & inrange(year, 2009, 2017)

* Hawaii: HRS § 236E; no estate tax 2005-April 2010 (pick-up tax lapsed);
* Act 74 enacted estate tax effective May 1, 2010 (not retroactive to Jan 1)
replace has_estate_tax = 1 if state_abbr == "HI" & inrange(year, 2010, 2021)

*-------------------------------------------------------
* F. Split period: Illinois
*    Decoupled June 2003 (P.A. 93-30); continuous 2003-2009;
*    lapsed 2010 (paralleled EGTRRA's federal repeal year);
*    reinstated Jan 1, 2011 (SB 2505, signed Jan 13, 2011)
*-------------------------------------------------------

* Illinois: 35 ILCS 405
replace has_estate_tax = 1 if state_abbr == "IL" & inrange(year, 2003, 2009)
replace has_estate_tax = 1 if state_abbr == "IL" & inrange(year, 2011, 2021)

sort state_abbr year
compress
save "$dirdata/state_estate_tax_step1.dta", replace

di _n "*** Step 1 complete ***"

}


*************************************************************
* Step 2: Code binary inheritance tax indicator
*************************************************************

if $step_2 {

di _n "*** Step 2: Coding inheritance tax indicator ***"

use "$dirdata/state_estate_tax_step1.dta", clear

gen has_inheritance_tax = 0

*-------------------------------------------------------
* Six states with inheritance tax during 2002-2021.
* Inheritance taxes are levied on beneficiaries (not the
* estate); rates vary by relationship to decedent.
*-------------------------------------------------------

* Iowa: Iowa Code ch. 450; continuous 2002-2021
* SF 619 (signed 2021) began phase-out at 20%/yr retroactive to Jan 1, 2021;
* tax still applied in 2021 at 80% of original rates. Full repeal Jan 1, 2025.
* Coded as 1 through 2021 because the tax was reduced, not eliminated.
replace has_inheritance_tax = 1 if state_abbr == "IA"

* Kentucky: KRS ch. 140; continuous since 1906; no changes 2002-2021
replace has_inheritance_tax = 1 if state_abbr == "KY"

* Maryland: Md. Tax-Gen. Code Ann. § 7-201; continuous 2002-2021
* (Only jurisdiction with BOTH estate and inheritance tax)
replace has_inheritance_tax = 1 if state_abbr == "MD"

* Nebraska: Neb. Rev. Stat. §§ 77-2001 to 77-2040; continuous since 1901
replace has_inheritance_tax = 1 if state_abbr == "NE"

* New Jersey: N.J.S.A. § 54:34-1; continuous since 1892
* (Estate tax repealed 2018, but inheritance tax continues)
replace has_inheritance_tax = 1 if state_abbr == "NJ"

* Pennsylvania: 72 P.S. § 9101 et seq.; continuous since 1826
replace has_inheritance_tax = 1 if state_abbr == "PA"

sort state_abbr year
compress
save "$dirdata/state_estate_tax_step2.dta", replace

di _n "*** Step 2 complete ***"

}


*************************************************************
* Step 3: Finalize, validate, and save
*************************************************************

if $step_3 {

di _n "*** Step 3: Finalizing, validating, and saving ***"

use "$dirdata/state_estate_tax_step2.dta", clear

*-------------------------------------------------------
* Integrity checks
*-------------------------------------------------------
isid state_abbr year
assert _N == 51 * 20

*-------------------------------------------------------
* Validate estate tax counts by year
*-------------------------------------------------------
di _n "--- Estate tax states by year ---"
forvalues y = 2002/2021 {
    quietly count if has_estate_tax == 1 & year == `y'
    di "  `y': `r(N)' states"
}

* Key year assertions with expected counts
* 2002: 11 (DC KS MD MN NC NJ NY OH RI VT WI)
quietly count if has_estate_tax == 1 & year == 2002
assert r(N) == 11

* 2003: 15 (+IL +MA +ME +OR)
quietly count if has_estate_tax == 1 & year == 2003
assert r(N) == 15

* 2005: 17 (+CT +WA)
quietly count if has_estate_tax == 1 & year == 2005
assert r(N) == 17

* 2008: 16 (-WI after 2007)
quietly count if has_estate_tax == 1 & year == 2008
assert r(N) == 16

* 2009: 17 (+DE re-enacted July 2009)
quietly count if has_estate_tax == 1 & year == 2009
assert r(N) == 17

* 2010: 16 (-KS -IL +HI)
quietly count if has_estate_tax == 1 & year == 2010
assert r(N) == 16

* 2011: 17 (+IL reinstated)
quietly count if has_estate_tax == 1 & year == 2011
assert r(N) == 17

* 2013: 15 (-NC -OH)
quietly count if has_estate_tax == 1 & year == 2013
assert r(N) == 15

* 2018: 13 (-DE -NJ)
quietly count if has_estate_tax == 1 & year == 2018
assert r(N) == 13

* 2021: 13 (CT DC HI IL MA MD ME MN NY OR RI VT WA)
quietly count if has_estate_tax == 1 & year == 2021
assert r(N) == 13

*-------------------------------------------------------
* Validate inheritance tax counts
*-------------------------------------------------------
di _n "--- Inheritance tax states by year ---"
forvalues y = 2002/2021 {
    quietly count if has_inheritance_tax == 1 & year == `y'
    di "  `y': `r(N)' states"
}

* All years 2002-2021: 6 states (IA KY MD NE NJ PA)
quietly count if has_inheritance_tax == 1 & year == 2002
assert r(N) == 6
quietly count if has_inheritance_tax == 1 & year == 2021
assert r(N) == 6

*-------------------------------------------------------
* List estate tax states for selected years
*-------------------------------------------------------
di _n "--- Estate tax states in 2002 (11 states) ---"
list state_abbr state_name if has_estate_tax == 1 & year == 2002, noobs clean

di _n "--- Estate tax states in 2021 (13 states) ---"
list state_abbr state_name if has_estate_tax == 1 & year == 2021, noobs clean

di _n "--- Inheritance tax states in 2021 (6 states) ---"
list state_abbr state_name if has_inheritance_tax == 1 & year == 2021, noobs clean

*-------------------------------------------------------
* Labels, ordering, save
*-------------------------------------------------------
label var state_abbr         "State abbreviation"
label var state_name         "State name"
label var state_fips         "State FIPS code"
label var year               "Year"
label var has_estate_tax     "State has independent estate tax (1=yes)"
label var has_inheritance_tax "State has inheritance tax (1=yes)"

order state_abbr state_name state_fips year has_estate_tax has_inheritance_tax
sort state_abbr year

compress
save "$dirdata/state_estate_tax.dta", replace

*-------------------------------------------------------
* Summary output
*-------------------------------------------------------
di _n "============================================================"
di    "  STATE ESTATE & INHERITANCE TAX PANEL: SUMMARY"
di    "============================================================"
di _n "--- Observations ---"
di "Total: `=_N' (51 states x 20 years)"
di _n "--- Estate tax states over time ---"
di "  2002: 11 (DC KS MD MN NC NJ NY OH RI VT WI)"
di "  2003: 15 (+IL MA ME OR decoupled)"
di "  2005: 17 (+CT WA decoupled)"
di "  2008: 16 (WI expired)"
di "  2009: 17 (DE re-enacted; KS still in effect)"
di "  2010: 16 (KS repealed, IL lapsed, HI enacted)"
di "  2011: 17 (IL reinstated)"
di "  2013: 15 (NC OH repealed)"
di "  2018: 13 (DE NJ repealed)"
di "  2021: 13 (CT DC HI IL MA MD ME MN NY OR RI VT WA)"
di _n "--- Inheritance tax states ---"
di "  2002-2021: 6 states (IA KY MD NE NJ PA)"
di "  Iowa: phase-out began 2021 (80% of original rate); full repeal Jan 1, 2025"
di _n "--- States with BOTH estate and inheritance tax (2021) ---"
list state_abbr state_name if has_estate_tax == 1 & has_inheritance_tax == 1 & year == 2021, noobs clean
di _n "============================================================"
di    "  OUTPUT: $dirdata/state_estate_tax.dta"
di    "  Keyed on: state_abbr year"
di    "  Years: 2002-2021  |  States: 50 + DC = 51"
di    "============================================================"

* Clean up intermediate files
capture erase "$dirdata/state_estate_tax_skeleton.dta"
capture erase "$dirdata/state_estate_tax_step1.dta"
capture erase "$dirdata/state_estate_tax_step2.dta"

di _n "*** Step 3 complete ***"

}


*************************************************************
* Step 4: Merge with state_tax_rates to create combined panel
*************************************************************

if $step_4 {

di _n "*** Step 4: Merging estate/inheritance tax with state tax rates ***"

use "$dirdata/state_estate_tax.dta", clear

merge 1:1 state_abbr year using "$dirdata/state_tax_rates.dta"

* Assert perfect match: every obs should match
assert _merge == 3
drop _merge

* Order variables logically: identifiers, tax rates, estate/inheritance flags
order state_abbr state_name state_fips year ///
      top_income_rate top_cg_rate no_income_tax cg_exclusion_state ///
      has_estate_tax has_inheritance_tax
sort state_abbr year

compress
save "$dirdata/state_tax_panel.dta", replace

di _n "============================================================"
di    "  COMBINED STATE TAX PANEL: SUMMARY"
di    "============================================================"
di _n "Observations: `=_N' (51 states x 20 years)"
di    "Variables: " _col(15) "state_abbr state_name state_fips year"
di    "           " _col(15) "top_income_rate top_cg_rate no_income_tax cg_exclusion_state"
di    "           " _col(15) "has_estate_tax has_inheritance_tax"
di _n "Source files merged:"
di    "  state_tax_rates.dta  (income/CG tax rates)"
di    "  state_estate_tax.dta (estate/inheritance tax indicators)"
di _n "Output: $dirdata/state_tax_panel.dta"
di    "============================================================"

di _n "*** Step 4 complete ***"

}

di _n "*** state_estate_tax.do completed ***"
