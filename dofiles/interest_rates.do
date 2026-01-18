**********************************
* Estimate forward looking EPS. **
**********************************


clear all

set more off

global lochead "/Users/jar88/Downloads/newtest/claudetest"
global dirdata "$lochead/data"
global dirgraphs "$lochead/graphs"


cd "$dirdata"


set maxvar 50000

global step_00 = 0
global step_0 = 1
global step_1 = 1
global step_2 = 0
global step_3 = 0
global step_4 = 0
global step_5 = 0
global step_6 = 0
global step_7 = 0
global step_8 = 0


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

if $step_0==1 {

	clear

	import excel using "$dirdata/r_data.xlsx", first


	* Graph Interest Rates Over Time

	save "$dirdata/r_data", replace

}


***************************************************
* REPLICATE SHILLER                              **
***************************************************
if $step_0==1 {

	clear

	import excel using "$dirdata/shiller_import.xls", first

	tostring date, replace
	replace date = date + "0" if substr(date,-2,2)==".1"

	gen mdate = monthly(date,"YM")
	format mdate %tm

	gen month = month(dofm(mdate))
	gen year = year(dofm(mdate))

	* Keep only january
	keep if month==1

		* Get some numbers for returns
		sort year
		tsset year

		gen retp_real = F.index_real/index_real
		gen totp_real = F.tr_real/tr_real

		sum retp_real totp_real if year>=2002 & year<=2021

	* Put everything in 1979 terms
		sum cpi_index if year==1979
		local base = r(mean)

		gen rp = (sp_index / cpi_index) * `base'
		gen rd = (div_index / cpi_index) * `base'

		sum rp if year<=1979

	* Log
	gen lrp = log(rp)

	reg lrp year if year<=1979

	local growth_rate = _b[year]
	gen growth_rate = exp(`growth_rate')

	* Detrended values
	gen dp = rp / ((growth_rate)^(year-1979))
	gen dd = rd / ((growth_rate)^(year-1979))

	* Get Shiller gamma
	sum dp if year<=1979
	local t1 = r(mean)
	sum dd if year<=1979
	local t2 = r(mean)

	gen rbar = `t2'/`t1'
	gen gbar = 1/(1+rbar)

	line dp year if year<=1979

	* generate pstar
	gen pstar = `t1' if year==1979
	gsort - year
	replace pstar = gbar*(pstar[_n-1] + dd) if year<1979

	sort year

	* Replicate Shiller Graph
	twoway (line dp year if year<=1979) (line pstar year if year<=1979), legend( label(1 "P") label(2 "P*")    )
	graph export "$dirgraphs/shiller_replicate.png" , replace

	* Get undetrended
	gen udp = dp * ((growth_rate)^(year-1979))
	gen udps = pstar * ((growth_rate)^(year-1979))

	* Undetrended Shiller
	twoway (line udp year if year<=1979) (line udps year if year<=1979), legend( label(1 "P") label(2 "P*")    )
	graph export "$dirgraphs/shiller_undetrend.png" , replace


}


***************************************************
* EXTEND SHILLER TO 2021                         **
***************************************************
if $step_0==1 {

	clear

	import excel using "$dirdata/shiller_import.xls", first

	tostring date, replace
	replace date = date + "0" if substr(date,-2,2)==".1"

	gen mdate = monthly(date,"YM")
	format mdate %tm

	gen month = month(dofm(mdate))
	gen year = year(dofm(mdate))

	* Keep only january
	keep if month==1

	keep if  year<=2021

	* Put everything in 2021
		sum cpi_index if year==2021
		local base = r(mean)

		gen rp = (sp_index / cpi_index) * `base'
		gen rd = (div_index / cpi_index) * `base'
		gen re = (earn_index/cpi_index) * `base'

		sum rp if year<=2021

	* Log
	gen lrp = log(rp)
	reg lrp year if year<=2021

	local growth_rate = _b[year]
	gen growth_rate = exp(`growth_rate')

	* Detrended values
	gen dp = rp / ((growth_rate)^(year-2021))
	gen dd = rd / ((growth_rate)^(year-2021))
	gen de = re / ((growth_rate)^(year-2021))

	* Get Shiller gamma
		sum dp if year<=2021
		local t1 = r(mean)
		sum dd if year<=2021
		local t2 = r(mean)

		gen rbar = `t2'/`t1'
		gen gbar = 1/(1+rbar)


	* generate pstar
	gen pstar = `t1' if year==2021
	gsort - year
	replace pstar = gbar*(pstar[_n-1] + dd) if year<2021



	* Do the same for earnings

			* Get Shiller gamma
			sum dp if year<=2021
			local t1 = r(mean)
			sum de if year<=2021
			local t2 = r(mean)

			gen erbar = `t2'/`t1'
			gen egbar = 1/(1+erbar)


		* generate pstar
		gen epstar = `t1' if year==2021
		gsort - year
		replace epstar = egbar*(epstar[_n-1] + de) if year<2021

	sort year

	* Replicate Shiller Graph
	twoway (line dp year if year<=2021) (line pstar year if year<=2021), legend( label(1 "P") label(2 "P*")    )
	graph export "$dirgraphs/shiller_2021.png" , replace


	twoway (line dp year if year<=2021) (line epstar year if year<=2021), legend( label(1 "P") label(2 "P*")    )
	graph export "$dirgraphs/eshiller_2021.png" , replace

	* Get undetrended
	gen udp = dp * ((growth_rate)^(year-2021))
	gen udps = pstar * ((growth_rate)^(year-2021))

	gen udeps = epstar * ((growth_rate)^(year-2021))

	* Undetrended Shiller
	twoway (line udp year if year<=2021) (line udps year if year<=2021), legend( label(1 "P") label(2 "P*")    )
	graph export "$dirgraphs/shiller_undetrend_2021.png" , replace

	twoway (line udp year if year<=2021) (line udeps year if year<=2021), legend( label(1 "P") label(2 "P*")    )
	graph export "$dirgraphs/shiller_eundetrend_2021.png" , replace


	gen ludp = log(udp)

	gen ludps = log(udps)

	gen ludeps = log(udeps)

	twoway (line ludp year if year<=2021) (line ludps year if year<=2021), legend( label(1 "P") label(2 "P*")    )
	graph export "$dirgraphs/shiller_lundetrend_2021.png" , replace

	twoway (line ludp year if year<=2021) (line ludeps year if year<=2021), legend( label(1 "P") label(2 "P*")    )
	graph export "$dirgraphs/shiller_elundetrend_2021.png" , replace


}


**************************
* CRSP DATA.            **
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
* Import IBES data.     **
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

		* LOOK THROUGH DIFFERENT INTEREST RATES

		tsset year

			* Payout rate, short term, based on average payouts
			gen st_payout = .8914

			* Return on equity = long term average
			gen roe = .175

			* Actual interest rate
			gen ra = r_cf_smooth*.01

			* Change in valuation due to change in interest rate
			gen rb = F.r_cf_smooth*.01

			* LONG RUN GROWTH RATE
				* In damodaran, equal to tbond rate
				* May want to think about changing this
				* For now, we will assume the growth rate smoothly declines by 1 percentage point over the time period

				*gen ltga = ra
				*gen ltgb = rb
				gen ltga = r_cf_smooth*.01
				gen ltgb = r_cf_smooth*.01
				* Long term growth declines by half the decline of the interest rate
				*replace ltgb = ltga + .5*(rb-ra)

			* Equity risk premium
				gen erpa = damo_erp
				gen erpb = damo_erp

		foreach j in a b  {



			* Generate required return
			gen req_ret`j' = r`j' + erp`j'

			* Earnings growth first year -- from year t to t+1
			gen eg1 = earn_fy2/earn_fy1 - 1

			* From t+1 to t+2
			gen eg2 = ltg`j' + (2*(eg1-ltg`j'))/3

			* From t+2 to t+3
			gen eg3 = ltg`j' + 1*(eg1-ltg`j')/3

			* From t+3 to t+4
			gen eg4 = ltg`j'

			* Payouts
			* Long Term Cash payout = 1 - long run growth rate / return on equity
			gen lt_payout = 1 - ltg`j'/roe

			gen p1 = st_payout
			gen p2 = st_payout - (st_payout-lt_payout)/4
			gen p3 = p2 - (st_payout-lt_payout)/4
			gen p4 = p3 - (st_payout-lt_payout)/4
			gen p5 = p4 - (st_payout-lt_payout)/4

			gen e1 = earn_fy1
			gen e2 = earn_fy2
			gen e3 = e2*(1+eg2)
			gen e4 = e3*(1+eg3)
			gen e5 = e4*(1+eg4)

			gen cf1 = e1*p1
			gen cf2 = e2*p2
			gen cf3 = e3*p3
			gen cf4 = e4*p4
			gen cf5 = e5*p5

			* Valuation of terminal value
			* Implicitly assuming long run growth equal to interest rate
			gen eterm = (e5*(1+eg4)*lt_payout)/(req_ret`j'-ltg`j')
			* Value 1 - earnings divided by

			gen val`j' = cf1/(1+req_ret`j') + cf2/((1+req_ret`j')^2) + cf3/((1+req_ret`j')^3) + cf4/((1+req_ret`j')^4) + cf5/((1+req_ret`j')^5) + eterm/((1+req_ret`j')^5)

			drop eg1 eg2 eg3 eg4 e1 e2 e3 e4 e5 lt_payout req_ret`j' eterm p1 p2 p3 p4 p5 cf1 cf2 cf3 cf4 cf5

		}


		* Generate interest rate return
		gen ret_int = valb/vala - 1
		li year ret_int vala valb ra rb

		ameans ret_int if year>=2002 & year<=2020, add(1)

		gen ret_int_index = 1 if year==2002
		replace ret_int_index = (L.ret_int_index)*(1 + L.ret_int) if year>=2003 & year<=2021

		browse year ret_int ret_int_index damo_tbond

	* Collapse
}



***************************************************
* House price analysis                         **
***************************************************
if $step_0==1 {


	* This section estimates house price changes that are due to discount rate changes

	clear

	import excel using "$dirdata/hp_data.xlsx", first

	gen year = year(date)
	gen quarter = quarter(date)

	* Keep only final quarter
	keep if quarter==4

	tsset year

	* gen price rent ratio
	gen prr = hp_real / rent_real

	gen hpg = hp_real / L.hp_real - 1

	gen rentg = rent_real / L.rent_real - 1

	gen prrg = prr / L.prr - 1


	sum hpg rentg prrg

	sum hpg rentg prrg if year>=2002 & year<=2021


	* So, what I will do is simply subtract the rent growth from the aggregates for housing

}
