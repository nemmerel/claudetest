
clear all
set more off

* Load project paths
do "/Users/jar88/Dropbox/research_projects/revision_analysis/claudetest/dofiles/paths.do"
cd "$dirdata"

set maxvar 50000

global step_0 = 1
global step_1 = 1
global step_2 = 0

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
