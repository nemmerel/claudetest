/*
Title: graphing_preferences.do
Purpose: Sets the graphing preferences.
*/

* set graphing preferences
	graph set window fontface "Times"
	set scheme plottigblind
	grstyle init
	grstyle color background white
	grstyle color plotregion white
	grstyle color major_grid gs8
	grstyle linewidth major_grid thin
	grstyle linepattern major_grid dot
	grstyle yesno draw_major_hgrid yes
	grstyle yesno grid_draw_min yes
	grstyle yesno grid_draw_max yes
	grstyle anglestyle vertical_tick horizontal
	grstyle gsize axis_title_gap tiny
	grstyle yesno axisline no
	grstyle set size 11pt: tick_label key_label
	grstyle set size 13pt: axis_title 
	grstyle set symbolsize 6pt 
