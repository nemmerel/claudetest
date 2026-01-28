*************************************************************
* Estimate Interest Rate Effects on Stock Price Valuations **
*************************************************************


clear all
set more off

* Load project paths
do "/Users/jar88/Dropbox/research_projects/revision_analysis/claudetest/dofiles/paths.do"
cd "$dirdata"

set maxvar 50000


global step_0 = 1
global step_1 = 1
global step_2 = 0

*****************************************
* IMPORT S&P 500 Constituent Data      **
*****************************************

if $step_0==1 {

	clear

	insheet using "$dirdata/sp500_ticker_start_end.csv", names

	gen sdate  = date(start_date,"YMD")
	format sdate %td

	gen edate  = date(end_date,"YMD")
	format edate %td

	drop start_date end_date


	* Generate the multiple spans
	sort ticker sdate

	bys ticker: gen span = _n

	foreach var in sdate edate {

		forvalues j=1/3 {

			gen `var'_`j' = `var' if span==`j'

			format `var'_`j' %td
		}
	}

	collapse (mean) sdate_* edate_*, by(ticker)

	rename ticker oftic

	save "$dirdata/sp500_dates", replace

}
*****************************************
* IMPORT r data                        **
*****************************************
if $step_0==1 {

	clear

	import excel using "$dirdata/r_data.xlsx", first


	* Graph interest rates
	* Replicate Shiller Graph 
	twoway (connected laubach_williams_rstar year if year>=1980) (connected r_real_cf year if year>=1980), legend( label(1 "Laubach & Williams") label(2 "Cleveland Fed") position(6) )
	
	graph export "$dirgraphs/r_star.png" , replace 
	


	save "$dirdata/r_data", replace

}



**************************
* IMPORT CRSP           **
**************************

if $step_1==1 {

	use "$dirdata/dpmlqc5odw3ktraf.dta", replace

	foreach var of varlist _all {
		local newname = lower("`var'")
		rename `var' `newname'
	}

	gen mdate = mofd(date)

	gen oftic = ticker

	drop if ticker==""

	duplicates tag oftic mdate, gen(dup)

	save "$dirdata/crsp_clean", replace


}
**************************
* CRSP IBES LINK        **
**************************

if $step_1==1 {

	use "$dirdata/s6g31vudtfgffgj1.dta", replace
	foreach var of varlist _all {
		local newname = lower("`var'")
		rename `var' `newname'
	}


	save "$dirdata/crsp_ibes", replace

}

**************************
* Analysis              **
**************************

if $step_1==1 {

	use "$dirdata/qukzpspg8a9iqv0i.dta", replace

	foreach var of varlist _all {
		local newname = lower("`var'")
		rename `var' `newname'
	}

	* I believe statpers is when the forecast is made, fpedats is the ending period of the forecast

	sort cusip statpers fpi

	*browse  cusip statpers fpi fpedats numest

	gen m_forecast = month(statpers)
	gen y_forecast = year(statpers)

	* Keep May

	keep if m_forecast==6

	* Collapse to firm - year level
	foreach var in medest meanest stdev highest lowest actual {
		gen `var'_fy1 = `var' if fpi=="1"
		gen `var'_fy2 = `var' if fpi=="2"
		gen `var'_fy3 = `var' if fpi=="3"
		gen `var'_fy4 = `var' if fpi=="4"
		gen `var'_fy5 = `var' if fpi=="5"

	}

	collapse (mean) medest_* meanest_* stdev_* highest_* lowest_* actual_* (first) m_forecast y_forecast ticker oftic, by(cusip statpers)

	gen year = yofd(statpers)

	* Get the permno for CRSP match

	joinby ticker using "$dirdata/crsp_ibes",  unmatched(master)

	gen testy = 1 if (statpers>=sdate & statpers < edate)

	sort ticker statpers
	*browse ticker statpers sdate edate testy

	* Generate a variable that says there is no match within the date
	bys ticker statpers: egen nonmatch = max(testy)

	bys ticker statpers: gen nonmatch_num = _n

	keep if _merge==1 | (statpers>=sdate & statpers < edate) | (nonmatch==. & nonmatch_num==1)

		drop _merge nonmatch nonmatch_num sdate edate

		gen mdate = mofd(statpers)

		merge m:1 mdate permno using "$dirdata/crsp_clean", keep(master match)

	* Get S&P 500 constituents

		merge m:1 oftic using "$dirdata/sp500_dates", keep(master match) nogen

		gen sp500 = .
		forvalues j=1/3 {

			replace sp500 = 1 if statpers>=sdate_`j' & statpers < edate_`j'

		}

		keep if sp500==1

		gen mv = prc*shrout

		sum mv if year==2021
		di r(sum)/1000000000

		forvalues j=1/5 {

			gen earn_fy`j' = meanest_fy`j'*shrout
		}

		gen earn = meanest_fy1*shrout

		sum earn if year==2024
		di (r(sum)/1000)/8395.39

		* Collapse to yearly level to create estimates of FMV

		collapse (sum) earn_fy*, by(year)

		merge 1:1 year using "$dirdata/r_data", keep(master match)

		save "$dirdata/val_est", replace

		use "$dirdata/val_est", replace

		* Generate smoothed cleveland fed
			sum r_real_cf if year==2002
			local t1 = r(mean)

			sum r_real_cf if year==2021
			local t2 = r(mean)

			gen r_cf_smooth = `t1' + ((`t2'-`t1')/19)*(year-2002)

			sum pi_cf if year>=2002 & year<=2021
			local t3 = r(mean)

			replace r_cf_smooth = r_cf_smooth + `t3'

		* Generate Laubach & Williams
			sum laubach_williams_rstar if year==2002
			local t1 = r(mean)

			sum laubach_williams_rstar if year==2021
			local t2 = r(mean)

			gen r_lw_smooth = `t1' + ((`t2'-`t1')/19)*(year-2002)
			sum pi_cf if year>=2002 & year<=2021
			local t3 = r(mean)

			replace r_lw_smooth = r_lw_smooth + `t3'

		tsset year

		* Common parameters
			gen st_payout = .8914    // Short-term payout rate
			gen roe = .175           // Return on equity

		save "$dirdata/val_est_with_rates", replace

		*************************************************************
		* LOOP THROUGH 6 SCENARIOS                                 **
		* Rate series: cf (Cleveland Fed), lw (Laubach-Williams)   **
		* Growth adjustment: 0 (none), 0.5 (half), 1 (full)        **
		*************************************************************

		foreach rate_series in cf lw {
			foreach g_adj in 0 0.5 1 {

				use "$dirdata/val_est_with_rates", replace

				* Set up file suffix for saving
				if `g_adj' == 0 {
					local g_suffix "nogch"
				}
				else if `g_adj' == 0.5 {
					local g_suffix "halfgch"
				}
				else {
					local g_suffix "fullgch"
				}

				di _n "=============================================="
				di "Running: `rate_series' rate series, `g_suffix' growth adjustment"
				di "=============================================="

				* Set interest rates based on series
				if "`rate_series'" == "cf" {
					gen ra = r_cf_smooth * .01
					gen rb = F.r_cf_smooth * .01
				}
				else {
					gen ra = r_lw_smooth * .01
					gen rb = F.r_lw_smooth * .01
				}

				* Set long-term growth rates
				gen ltga = ra
				gen ltgb = ltga + `g_adj' * (rb - ra)

				* Equity risk premium (same for both scenarios)
				gen erpa = damo_erp
				gen erpb = damo_erp

				* Run valuation for scenarios a (current rate) and b (forward rate)
				foreach j in a b {

					* Required return
					gen req_ret`j' = r`j' + erp`j'

					* Earnings growth transition (3 years to converge to long-term)
					gen eg1 = earn_fy2/earn_fy1 - 1
					gen eg2 = ltg`j' + (2*(eg1-ltg`j'))/3
					gen eg3 = ltg`j' + 1*(eg1-ltg`j')/3
					gen eg4 = ltg`j'

					* Payout ratio transition (5 years to converge to long-term)
					gen lt_payout = 1 - ltg`j'/roe
					gen p1 = st_payout
					gen p2 = st_payout - (st_payout-lt_payout)/4
					gen p3 = p2 - (st_payout-lt_payout)/4
					gen p4 = p3 - (st_payout-lt_payout)/4
					gen p5 = p4 - (st_payout-lt_payout)/4

					* Earnings projections
					gen e1 = earn_fy1
					gen e2 = earn_fy2
					gen e3 = e2*(1+eg2)
					gen e4 = e3*(1+eg3)
					gen e5 = e4*(1+eg4)

					* Cash flows
					gen cf1 = e1*p1
					gen cf2 = e2*p2
					gen cf3 = e3*p3
					gen cf4 = e4*p4
					gen cf5 = e5*p5

					* Terminal value (Gordon Growth Model)
					gen eterm = (e5*(1+eg4)*lt_payout)/(req_ret`j'-ltg`j')

					* Present value
					gen val`j' = cf1/(1+req_ret`j') + cf2/((1+req_ret`j')^2) + cf3/((1+req_ret`j')^3) + cf4/((1+req_ret`j')^4) + cf5/((1+req_ret`j')^5) + eterm/((1+req_ret`j')^5)

					* Clean up intermediate variables
					drop eg1 eg2 eg3 eg4 e1 e2 e3 e4 e5 lt_payout req_ret`j' eterm p1 p2 p3 p4 p5 cf1 cf2 cf3 cf4 cf5

				}

				* Calculate return from interest rate change
				gen ret_int = valb/vala - 1
				li year ret_int vala valb ra rb

				ameans ret_int if year>=2002 & year<=2020, add(1)

				* Build cumulative index
				gen ret_int_index = 1 if year==2002
				replace ret_int_index = (L.ret_int_index)*(1 + L.ret_int) if year>=2003 & year<=2021

				* Save results

				rename ret_int ret_int`rate_series'_`g_suffix'
				rename ret_int_index ret_int_index`rate_series'_`g_suffix'

				keep year ret_int`rate_series'_`g_suffix' ret_int_index`rate_series'_`g_suffix'

				save "$dirdata/r_save_`rate_series'_`g_suffix'", replace

			}
		}

		di _n "=============================================="
		di "All 6 scenarios completed"
		di "=============================================="

}

* Combine together the two preferred series 
if $step2==1 {

	use "$dirdata/r_save_lw_halfgch", replace

	merge 1:1 year using  "$dirdata/r_save_cf_halfgch", nogen 

	* Final Equity R-Return 
	gen equ_rret = (ret_intcf_halfgch + ret_intlw_halfgch)/2

	* Create different moving averages

	ma_gen equ_rret, timevar(year) periods(5)

	ma_gen equ_rret, timevar(year) periods(10)

	rename equ_rret equ_rret1 

	rename equ_rret_5ma equ_rret5

	rename equ_rret_10ma equ_rret10

	keep year equ_rret* 

	* Replace the 10ma with leads and lags 

	sort year 
	tsset year 
	replace equ_rret10 = f.equ_rret10 if equ_rret10==.
	replace equ_rret10 = f.equ_rret10 if equ_rret10==.
	replace equ_rret10 = L.equ_rret10 if equ_rret10==.
	replace equ_rret10 = L.equ_rret10 if equ_rret10==.

	save "$dirdata/ret_export", replace 

}
