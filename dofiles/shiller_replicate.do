**********************************
* Estimate forward looking EPS. **
**********************************


clear all

set more off
do "/Users/jar88/Dropbox/research_projects/revision_analysis/claudetest/dofiles/paths.do"

cd "$dirdata"


set maxvar 50000

global step_0 = 1
global step_1 = 1
global step_2 = 0
global step_3 = 0
global step_4 = 0
global step_5 = 0


***************************************************
* REPLICATE ORIGINAL SHILLER                     **
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
if $step_1==1 {

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

