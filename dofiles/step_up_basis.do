*************************************************************
* Step-Up in Basis Estimation: Capital Gains Eliminated     **
* at Death Through Stepped-Up Basis                         **
*                                                           **
* Purpose: Estimate the share of total capital gains that   **
*   are never taxed because the holder dies and the basis   **
*   is stepped up to fair market value. Constructs a        **
*   cumulative stock of unrealized gains by single-year     **
*   age and applies CDC 2021 mortality rates to estimate    **
*   gains stepped up at each age.                           **
*                                                           **
* Output files:                                             **
*   $dirdata/step_up_basis.dta                              **
*   $dirgraphs/step_up_unrealized_stock.png                 **
*   $dirgraphs/step_up_gains_by_age.png                     **
*   $dirgraphs/step_up_cumulative_share.png                 **
*   $dirgraphs/step_up_sensitivity.png                      **
*                                                           **
* Sources:                                                  **
*   CDC National Vital Statistics Reports, Vol. 72, No. 12  **
*     "United States Life Tables, 2021" (Table 1, both      **
*     sexes combined, single-year ages)                     **
*   Capital gains profiles from IRS SOI tabulations         **
*                                                           **
* Mathematical model:                                       **
*   U(a) = U(a-1)*(1-m(a-1)) + G(a)*(1-rr(a))             **
*   S(a) = U(a) * m(a)                                     **
*   where U = unrealized stock, G = total gains,            **
*         rr = realization rate, m = mortality rate (qx)    **
*                                                           **
* Required variables (if use_dummy == 0):                   **
*   age        - single-year age (20-100)                   **
*   total_kg   - total capital gains per capita at age      **
*   real_rate  - realization rate at age (0 to 1)           **
*   pop_weight - population weight (optional)               **
*                                                           **
* If real data is in 5-year brackets, set expand_brackets=1 **
* to interpolate to single-year ages.                       **
*************************************************************

clear all
set more off

* Load project paths
do "/Users/jar88/Dropbox/research_projects/revision_analysis/claudetest/dofiles/paths.do"

cd "$dirdata"

* Step flags
global step_0 = 1   // Generate dummy data (or load real data)
global step_1 = 1   // Hard-code CDC 2021 life table mortality rates
global step_2 = 1   // Compute unrealized stock and stepped-up gains
global step_3 = 1   // Aggregate statistics
global step_4 = 1   // Sensitivity analysis
global step_5 = 1   // Graphs
global step_6 = 1   // Save and summarize

* Toggle: set to 0 to use real data instead of dummy data
global use_dummy = 1

* Toggle: set to 1 if real data is in 5-year age brackets
global expand_brackets = 0


*************************************************************
* Step 0: Generate dummy data (or load real data)
*************************************************************

if $step_0 {

di _n "*** Step 0: Generating capital gains data ***"

if $use_dummy {

    di "  Using dummy data..."

    clear
    set obs 81
    gen age = _n + 19

    * Dummy capital gains profile (per capita, in dollars)
    * Ages 20-65: linear rise from $1,000 to $50,000
    * Ages 65-80: plateau at $50,000
    * Ages 80-100: gentle decline to $40,000
    gen total_kg = .
    replace total_kg = 1000 + (50000 - 1000) * (age - 20) / (65 - 20) if age <= 65
    replace total_kg = 50000                                            if age > 65 & age <= 80
    replace total_kg = 50000 - (50000 - 40000) * (age - 80) / (100 - 80) if age > 80

    * Dummy realization rates
    * Ages 20-65: linear rise from 10% to 65%
    * Ages 65+: plateau at 65%
    gen real_rate = .
    replace real_rate = 0.10 + (0.65 - 0.10) * (age - 20) / (65 - 20) if age <= 65
    replace real_rate = 0.65                                            if age > 65

    * Population weights (approximate 2021 US adult distribution)
    * Flat to age 60, exponential decline after
    gen pop_weight = .
    replace pop_weight = 1       if age <= 60
    replace pop_weight = exp(-0.05 * (age - 60)) if age > 60

    * Normalize pop_weight to sum to 1
    quietly sum pop_weight
    replace pop_weight = pop_weight / r(sum)

}
else {

    * -------------------------------------------------------
    * USER: Load your real data here.
    * The dataset must contain:
    *   age        - single-year age (20-100)
    *   total_kg   - total capital gains per capita at age
    *   real_rate  - realization rate at age (0 to 1)
    *   pop_weight - population weight (optional; will be
    *                set to uniform if missing)
    *
    * Example:
    *   use "$sharedata/capital_gains_by_age.dta", clear
    * -------------------------------------------------------

    di as error "ERROR: use_dummy == 0 but no real data load command specified."
    di as error "Edit Step 0 to load your real data."
    error 198

}

* If real data is in 5-year brackets, expand to single-year ages
if $expand_brackets {
    di "  Expanding 5-year brackets to single-year ages..."
    rename age age_bracket
    gen age_lower = age_bracket
    gen age_upper = age_bracket + 4
    expand 5
    bysort age_bracket: gen age = age_lower + _n - 1
    drop age_bracket age_lower age_upper
    sort age
    * Interpolate values
    ipolate total_kg age, gen(total_kg_i)
    replace total_kg = total_kg_i
    drop total_kg_i
    ipolate real_rate age, gen(real_rate_i)
    replace real_rate = real_rate_i
    drop real_rate_i
}

* Create pop_weight if it doesn't exist
capture confirm variable pop_weight
if _rc {
    gen pop_weight = 1 / _N
}

* Validation
assert age >= 20 & age <= 100
assert total_kg >= 0 & !missing(total_kg)
assert real_rate >= 0 & real_rate <= 1 & !missing(real_rate)
assert pop_weight >= 0 & !missing(pop_weight)

sort age
save "$dirdata/step_up_basis_gains.dta", replace

di _n "*** Step 0 complete ***"

}


*************************************************************
* Step 1: Hard-code CDC 2021 life table mortality rates
*************************************************************

if $step_1 {

di _n "*** Step 1: Loading CDC 2021 life table (qx, both sexes) ***"

* Source: CDC NVSR Vol. 72, No. 12, Table 1
* "United States Life Tables, 2021"
* https://www.cdc.gov/nchs/data/nvsr/nvsr72/nvsr72-12.pdf
* https://ftp.cdc.gov/pub/Health_Statistics/NCHS/Publications/NVSR/72-12/Table01.xlsx
*
* qx = probability of dying between exact age x and age x+1
* Both sexes combined, all races
* Age 100 is terminal: qx = 1.000000 (all remaining survivors die)

clear
input age double qx
20  0.000949
21  0.001065
22  0.001170
23  0.001259
24  0.001335
25  0.001406
26  0.001480
27  0.001560
28  0.001651
29  0.001749
30  0.001849
31  0.001947
32  0.002040
33  0.002128
34  0.002216
35  0.002308
36  0.002409
37  0.002519
38  0.002638
39  0.002768
40  0.002916
41  0.003078
42  0.003244
43  0.003410
44  0.003587
45  0.003792
46  0.004036
47  0.004315
48  0.004625
49  0.004959
50  0.005308
51  0.005686
52  0.006118
53  0.006620
54  0.007184
55  0.007766
56  0.008369
57  0.009042
58  0.009795
59  0.010606
60  0.011467
61  0.012333
62  0.013173
63  0.013981
64  0.014798
65  0.015666
66  0.016726
67  0.017853
68  0.019122
69  0.020526
70  0.021919
71  0.023536
72  0.025372
73  0.027616
74  0.029889
75  0.033726
76  0.036933
77  0.041016
78  0.044758
79  0.049530
80  0.054120
81  0.059483
82  0.065401
83  0.072224
84  0.080609
85  0.089139
86  0.099586
87  0.111021
88  0.123484
89  0.137001
90  0.151584
91  0.167229
92  0.183913
93  0.201590
94  0.220190
95  0.239623
96  0.259772
97  0.280504
98  0.301662
99  0.323082
100 1.000000
end

* Validation
assert _N == 81
assert age >= 20 & age <= 100
assert qx > 0 & qx <= 1
* Mortality should be monotonically non-decreasing
sort age
gen qx_lag = qx[_n-1] if _n > 1
assert qx >= qx_lag if _n > 1
drop qx_lag

label var age "Age (single year)"
label var qx  "Probability of dying within 1 year (CDC 2021, both sexes)"

sort age
save "$dirdata/step_up_basis_mortality.dta", replace

di _n "*** Step 1 complete ***"

}


*************************************************************
* Step 2: Compute unrealized stock and stepped-up gains
*************************************************************

if $step_2 {

di _n "*** Step 2: Computing unrealized stock and stepped-up gains ***"

use "$dirdata/step_up_basis_gains.dta", clear
sort age
merge 1:1 age using "$dirdata/step_up_basis_mortality.dta"
assert _merge == 3
drop _merge

sort age

* Unrealized stock: U(a) = U(a-1)*(1-m(a-1)) + G(a)*(1-rr(a))
* Initial condition: U(20) = G(20)*(1-rr(20))
gen double unrealized_stock = total_kg * (1 - real_rate) if _n == 1
replace unrealized_stock = unrealized_stock[_n-1] * (1 - qx[_n-1]) ///
    + total_kg * (1 - real_rate) if _n > 1

* Stepped-up gains per capita at each age
gen double stepped_up = unrealized_stock * qx

* Aggregate stepped-up gains (population-weighted)
gen double stepped_up_agg = stepped_up * pop_weight
gen double total_kg_agg   = total_kg * pop_weight

* Cumulative share of stepped-up gains
quietly sum stepped_up_agg
local total_stepped = r(sum)
gen double cum_stepped = sum(stepped_up_agg)
gen double cum_stepped_share = cum_stepped / `total_stepped'

label var unrealized_stock   "Cumulative unrealized gains per capita ($)"
label var stepped_up         "Stepped-up gains per capita ($)"
label var stepped_up_agg     "Stepped-up gains (pop-weighted)"
label var total_kg_agg       "Total gains (pop-weighted)"
label var cum_stepped_share  "Cumulative share of stepped-up gains"

sort age
save "$dirdata/step_up_basis_results.dta", replace

di _n "*** Step 2 complete ***"

}


*************************************************************
* Step 3: Aggregate statistics
*************************************************************

if $step_3 {

di _n "*** Step 3: Computing aggregate statistics ***"

use "$dirdata/step_up_basis_results.dta", clear

* Total stepped-up gains as share of total gains
quietly sum stepped_up_agg
local total_stepped = r(sum)
quietly sum total_kg_agg
local total_gains = r(sum)
local share_stepped = `total_stepped' / `total_gains'

di _n "============================================================"
di    "  HEADLINE: Stepped-up gains as share of total gains"
di    "============================================================"
di    "  Total stepped-up (weighted): " %12.2f `total_stepped'
di    "  Total gains (weighted):      " %12.2f `total_gains'
di    "  Share stepped up:            " %6.1f (`share_stepped' * 100) "%"
di    "============================================================"

* Stepped-up gains by age bracket
di _n "--- Stepped-up gains by age bracket ---"

foreach bracket in "20-44" "45-64" "65+" {
    if "`bracket'" == "20-44" {
        quietly sum stepped_up_agg if age >= 20 & age <= 44
    }
    else if "`bracket'" == "45-64" {
        quietly sum stepped_up_agg if age >= 45 & age <= 64
    }
    else {
        quietly sum stepped_up_agg if age >= 65
    }
    local bracket_total = r(sum)
    local bracket_share = `bracket_total' / `total_stepped'
    di "  Age `bracket': " %6.1f (`bracket_share' * 100) "% of stepped-up gains"
}

* Median age of stepped-up gains (age where cum share crosses 50%)
quietly gen byte above_median = (cum_stepped_share >= 0.50)
quietly sum age if above_median == 1
local median_age = r(min)
drop above_median

di _n "  Median age of stepped-up gains: `median_age'"

* Peak age of stepped-up gains
quietly sum stepped_up
quietly gen byte is_peak = (stepped_up == r(max))
quietly sum age if is_peak == 1
local peak_age = r(min)
drop is_peak

di "  Peak age of stepped-up gains:   `peak_age'"
di    "============================================================"

di _n "*** Step 3 complete ***"

}


*************************************************************
* Step 4: Sensitivity analysis
*************************************************************

if $step_4 {

di _n "*** Step 4: Sensitivity analysis (stock realization rate) ***"

use "$dirdata/step_up_basis_gains.dta", clear
sort age
merge 1:1 age using "$dirdata/step_up_basis_mortality.dta"
assert _merge == 3
drop _merge
sort age

* Test sensitivity to stock realization rate (lambda)
* U(a) = U(a-1)*(1-m(a-1))*(1-lambda) + G(a)*(1-rr(a))

di _n "============================================================"
di    "  SENSITIVITY: Varying stock realization rate (lambda)"
di    "============================================================"

local lambdas "0 0.01 0.03 0.05"
local i = 0

foreach lam of local lambdas {
    local i = `i' + 1

    gen double unrealized_`i' = total_kg * (1 - real_rate) if _n == 1
    replace unrealized_`i' = unrealized_`i'[_n-1] * (1 - qx[_n-1]) * (1 - `lam') ///
        + total_kg * (1 - real_rate) if _n > 1

    gen double stepped_`i' = unrealized_`i' * qx
    gen double stepped_agg_`i' = stepped_`i' * pop_weight

    quietly sum stepped_agg_`i'
    local total_s_`i' = r(sum)
    quietly sum total_kg_agg if _n == 1
    * Recompute total gains
    gen double tkg_`i' = total_kg * pop_weight
    quietly sum tkg_`i'
    local total_g_`i' = r(sum)
    local share_`i' = `total_s_`i'' / `total_g_`i''

    local lam_pct = `lam' * 100
    di "  lambda = `lam_pct'%: stepped-up share = " %5.1f (`share_`i'' * 100) "%"

    drop tkg_`i'
}

di "============================================================"

* Label sensitivity variables for graphing
label var stepped_1 "lambda = 0%"
label var stepped_2 "lambda = 1%"
label var stepped_3 "lambda = 3%"
label var stepped_4 "lambda = 5%"

sort age
save "$dirdata/step_up_basis_sensitivity.dta", replace

di _n "*** Step 4 complete ***"

}


*************************************************************
* Step 5: Graphs
*************************************************************

if $step_5 {

di _n "*** Step 5: Generating graphs ***"

* Load graphing preferences
do "$dirdofiles/graphing_preferences.do"

*-------------------------------------------------------
* Graph 1: Unrealized stock by age
*-------------------------------------------------------

use "$dirdata/step_up_basis_results.dta", clear

twoway (line unrealized_stock age, lwidth(medthick)), ///
    title("Cumulative Unrealized Capital Gains by Age") ///
    subtitle("Per capita, dummy data") ///
    ytitle("Unrealized gains ($)") ///
    xtitle("Age") ///
    ylabel(, format(%12.0fc)) ///
    xlabel(20(10)100)

graph export "$dirgraphs/step_up_unrealized_stock.png", replace width(2400)

*-------------------------------------------------------
* Graph 2: Stepped-up gains by age (area plot)
*-------------------------------------------------------

twoway (area stepped_up age, color(%50)), ///
    title("Capital Gains Stepped Up at Death by Age") ///
    subtitle("Per capita, dummy data") ///
    ytitle("Stepped-up gains ($)") ///
    xtitle("Age") ///
    ylabel(, format(%12.0fc)) ///
    xlabel(20(10)100)

graph export "$dirgraphs/step_up_gains_by_age.png", replace width(2400)

*-------------------------------------------------------
* Graph 3: Cumulative share of stepped-up gains
*-------------------------------------------------------

twoway (line cum_stepped_share age, lwidth(medthick)), ///
    title("Cumulative Share of Stepped-Up Capital Gains") ///
    subtitle("Fraction of total stepped-up gains by age, dummy data") ///
    ytitle("Cumulative share") ///
    xtitle("Age") ///
    ylabel(0(0.2)1, format(%3.1f)) ///
    xlabel(20(10)100) ///
    yline(0.5, lpattern(dash) lcolor(gs8))

graph export "$dirgraphs/step_up_cumulative_share.png", replace width(2400)

*-------------------------------------------------------
* Graph 4: Sensitivity plot
*-------------------------------------------------------

use "$dirdata/step_up_basis_sensitivity.dta", clear

twoway (line stepped_1 age, lwidth(medthick)) ///
       (line stepped_2 age, lwidth(medthick) lpattern(dash)) ///
       (line stepped_3 age, lwidth(medthick) lpattern(shortdash)) ///
       (line stepped_4 age, lwidth(medthick) lpattern(longdash_dot)), ///
    title("Stepped-Up Gains: Sensitivity to Stock Realization Rate") ///
    subtitle("Per capita, dummy data") ///
    ytitle("Stepped-up gains ($)") ///
    xtitle("Age") ///
    ylabel(, format(%12.0fc)) ///
    xlabel(20(10)100) ///
    legend(order(1 "{&lambda} = 0%" 2 "{&lambda} = 1%" ///
                 3 "{&lambda} = 3%" 4 "{&lambda} = 5%") ///
           rows(1) position(6))

graph export "$dirgraphs/step_up_sensitivity.png", replace width(2400)

di _n "*** Step 5 complete ***"

}


*************************************************************
* Step 6: Save final dataset and summarize
*************************************************************

if $step_6 {

di _n "*** Step 6: Saving final dataset ***"

use "$dirdata/step_up_basis_results.dta", clear

* Keep essential variables
keep age total_kg real_rate pop_weight qx unrealized_stock stepped_up ///
     stepped_up_agg total_kg_agg cum_stepped_share

order age total_kg real_rate pop_weight qx unrealized_stock stepped_up ///
      stepped_up_agg total_kg_agg cum_stepped_share

label var age              "Age (single year, 20-100)"
label var total_kg         "Total capital gains per capita ($)"
label var real_rate        "Realization rate (0-1)"
label var pop_weight       "Population weight"
label var qx               "Probability of death within 1 year (CDC 2021)"

sort age
compress
save "$dirdata/step_up_basis.dta", replace

* Print summary table
di _n "============================================================"
di    "  STEP-UP IN BASIS ESTIMATION: FINAL SUMMARY"
di    "============================================================"

quietly sum stepped_up_agg
local total_stepped = r(sum)
quietly sum total_kg_agg
local total_gains = r(sum)
local share_stepped = `total_stepped' / `total_gains'

di _n "  Share of gains stepped up at death: " %5.1f (`share_stepped' * 100) "%"
di    ""
di    "  --- By age bracket ---"

foreach bracket in "20-44" "45-64" "65+" {
    if "`bracket'" == "20-44" {
        quietly sum stepped_up_agg if age >= 20 & age <= 44
    }
    else if "`bracket'" == "45-64" {
        quietly sum stepped_up_agg if age >= 45 & age <= 64
    }
    else {
        quietly sum stepped_up_agg if age >= 65
    }
    local b_share = r(sum) / `total_stepped'
    di "    Age `bracket': " %5.1f (`b_share' * 100) "% of stepped-up gains"
}

di _n "  --- Key age points ---"
quietly gen byte above50 = (cum_stepped_share >= 0.50)
quietly sum age if above50 == 1
di "    Median age of stepped-up gains: " r(min)
drop above50

quietly sum stepped_up
quietly gen byte peak = (stepped_up == r(max))
quietly sum age if peak == 1
di "    Peak age of stepped-up gains:   " r(min)
drop peak

di _n "  Observations: " _N " (ages 20-100)"
di    "  Output: $dirdata/step_up_basis.dta"
di    "  Graphs: $dirgraphs/step_up_*.png"
di    "============================================================"

* Clean up intermediate files
capture erase "$dirdata/step_up_basis_gains.dta"
capture erase "$dirdata/step_up_basis_mortality.dta"
capture erase "$dirdata/step_up_basis_results.dta"
capture erase "$dirdata/step_up_basis_sensitivity.dta"

di _n "*** Step 6 complete ***"

}

di _n "*** step_up_basis.do completed ***"
