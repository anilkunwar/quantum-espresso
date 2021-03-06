set pp_module_dir  [file join $env(PWGUI) modules pp]
set pp_module_file [file join $pp_module_dir pp.tcl]
set input_pp_file  [file join $env(PWGUI) .. .. Doc INPUT_PP]
set input_pp_file  [file join /home/tone/NEW_HOME/prog/O-sesame/Doc INPUT_PP]

puts ""
puts "**************************************************************************"
puts "Checking the consistency of variables between pw.tcl and INPUT_PW files !!!"
puts "***************************************************************************"
puts ""
puts "pp_module = $pp_module_file"
puts "input_pp  = $input_pp_file"

global pp_module_var input_pp_var


# initialization
lappend auto_path [file join $env(GUIB) lib]
package require tclu

# disable the source command
rename source tcl_source
proc source {args} { return 1}

########################################################################
# the GUIB keywords
########################################################################

#      1.1 object keywords:
#--------------------------
set this dummy
proc module {args} { global this; eval [lindex $args end] }
proc page {args} { global this; eval [lindex $args end] }
proc namelist {args} { global this; eval [lindex $args end] }
proc group {args} { global this; eval [lindex $args end] }
proc optional {args} { global this; eval [lindex $args end] }
proc required {args} { global this; eval [lindex $args end] }
proc line {args} { global this; eval [lindex $args end] }
 
#      1.2 item keywords:
#------------------------
proc var {ident args} { global pp_module_var; set pp_module_var([string tolower $ident]) 1 }
proc auxilvar {args} { return 1 }
proc dimension {ident args} { global pp_module_var; set pp_module_var([string tolower $ident]) 1 }
proc text {ident args} { global pp_module_var; set pp_module_var([string tolower $ident]) 1 }
proc table {ident args} { global pp_module_var; set pp_module_var([string tolower $ident]) 1 }
proc keyword {ident args} { return 1; # nothing so far }
proc help {ident args} { return 1; # nothing so far }     
 
#      1.3 event-driven keywords:
#--------------------------------
proc tracevar         {args} { return 1 }
proc widget           {args} { return 1 }
proc groupwidget      {args} { return 1 }
proc widgetconfigure  {args} { return 1 }
proc widgetcget	      {args} { return 1 }
proc keywordconfigure {args} { return 1 }
 
#      1.4 getsets keywords, i.e. keyword associated with the variables:
#------------------------------------------------------------------------
proc varvalue        {args} { return 1 }
proc vartextvalue    {args} { return 1 }
proc varref    	     {args} { return 1 }
proc varset          {args} { return 1 }
proc dimvalue        {args} { return 1 }
proc dimtextvalue    {args} { return 1 }
proc dimref    	     {args} { return 1 }
proc dimset          {args} { return 1 }
proc tablevalue      {args} { return 1 }
proc tabletextvalue  {args} { return 1 }
proc tableref  	     {args} { return 1 }
proc tableset        {args} { return 1 }
 
#      1.5 special keywords:
#---------------------------
proc readfilter        {args} { return 1 }
proc writefilter       {args} { return 1 }
proc postprocess       {args} { return 1 }
proc this              {args} { return 1 }
proc loaddata          {args} { return 1 }
proc valueToTextvalue  {args} { return 1 }
proc textvalueToValue  {args} { return 1 }
proc scriptvar         {args} { return 1 }
        
#      1.6 decoration keywords:
#------------------------------
proc packwidgets {args} { return 1 }
proc separator   {args} { return 1 }
 
#
# parse the pp.tcl
#
tcl_source $pp_module_file

#
# parse the INPUT_PP file and Chek the INPUT_PP against the pw.tcl
#

puts "----------------------------"
puts "Checking INPUT_PP vs. pp.tcl"
puts "----------------------------"

set in_nl 0
foreach line [split [tclu::readFile $input_pp_file] \n] {
    if { [regexp  -- {\-&} $line] } {
	# beginning of namelist; go to next line
	set in_nl 1
	continue
    }
    
    if { [regexp -- {\-/} $line] } {
	# end of this namelist; go to next line
	set in_nl 0
	continue
    }
    
    if { $in_nl } {
	if { [regexp -- {^  ! [a-z]+} $line] } {
	    set var [string tolower [lindex $line 1]]
	    puts "var=$var"
	    # check if there is more then var on the line
	    # rule for qualification: var1, var2
	    if { [string trim $var ,] != $var } {
		set var [string trim $var ,]
		puts "   WARNING: (variable ${var}) line may containg more then one variable"
	    }
	    #puts "variable: $var"
	    set input_pp_var($var) 1

	    if { ! [info exists pp_module_var($var)] } {
		puts "MESSAGE: variable $var is defined in INPUT_PP but not in pp.tcl"
	    }
	    
	}
    }
}

#
# Cheking pp.tcl vs. INPUT_PP
#

puts ""
puts "----------------------------"
puts "Checking pp.tcl vs. INPUT_PP"
puts "----------------------------"

foreach elem [array names pp_module_var] {
    if { ! [info exists input_pp_var([string tolower $elem])] } {
	# do not diaplay the warning for atomic_coordinates_*
	if { ! [string match atomic_coordinates_* $elem] } {
	    puts "WARNING: variable $elem is defined in pp.tcl but not in INPUT_PP"
	}
    }
}