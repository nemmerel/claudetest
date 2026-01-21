*************************************************************
* Master Replication File                                   **
* Calls all analysis sub-files in sequence                  **
*************************************************************

clear all
set more off

* Load project paths
do "/Users/jar88/Dropbox/research_projects/revision_analysis/claudetest/dofiles/paths.do"

* Display paths for verification
di "Project root: $lochead"
di "Data directory: $dirdata"
di "Graphs directory: $dirgraphs"
di "Do-files directory: $dirdofiles"

*************************************************************
* 1. Shiller Replication and Extension
*************************************************************
di _n "Running shiller_replicate.do..."
do "$dirdofiles/shiller_replicate.do"

*************************************************************
* 2. Interest Rate Analysis
*************************************************************
di _n "Running interest_rates.do..."
do "$dirdofiles/interest_rates.do"

*************************************************************
* 3. House Price Analysis
*************************************************************
di _n "Running hp_analysis.do..."
do "$dirdofiles/hp_analysis.do"

*************************************************************
di _n "Master file completed successfully."
