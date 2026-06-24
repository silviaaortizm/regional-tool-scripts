/*==============================================================================
	To do:			Read Parameters

	Editted by:		Madi Mangan
	Laste Updated:	June, 2025
===============================================================================*/


*===============================================================================
// Set globals in this do-file
*===============================================================================

*----- Sheet names
global sheet1 "AFW_Policy" 
global sheet2 "AFW_Parameters"
global sheet3 "AFW_Targeting"
global sheet4 "Products_${country}"

*===============================================================================
// Read Parameters
*===============================================================================

/*-------------------------------------------------------/
	1. Policy Names
/-------------------------------------------------------*/

*------ Policy
import excel "$xls_sn", sheet("$sheet1") firstrow clear

keep category varname varlabel
keep if varname != "."

* Policy names
levelsof varname, local(params)
foreach z of local params {
	levelsof varlabel if varname=="`z'", local(val)
	global `z'_lab `val'
}
	
* Policy categories
gen order = _n
bysort category (order): gen count = _n

keep category varname count
ren varname v_	
	
reshape wide v_, i(category) j(count)
		
egen v = concat(v_*), punct(" ")
gen globalvalue = strltrim(v)
		
levelsof category, local(params)
foreach z of local params {
	levelsof globalvalue if category=="`z'", local(val)
	global `z'_A `val'
}
	
drop v_1 v globalvalue
	
egen v = concat(v_*), punct(" ")	
gen globalvalue = strltrim(v)
		
levelsof category, local(params)
foreach z of local params {
	levelsof globalvalue if category=="`z'", local(val)
	global `z' `val'
}


/*-------------------------------------------------------/
	2. Parameters
/-------------------------------------------------------*/

*------ Settings
import excel "$xls_sn", sheet("$sheet2") first clear

keep  globalname globalvalue_${country}

isid globalname

levelsof globalname, local(params)
foreach z of local params {
	levelsof globalvalue if globalname == "`z'", local(val)
	global `z' `val'
}

/*-------------------------------------------------------/
	3. Targeting
/-------------------------------------------------------*/

*------ Import parameters and save them as a file to make merges
import excel "$xls_sn", sheet("$sheet3") first clear

keep  policy segment *_${country}
tempfile dirtrans_labels
save `dirtrans_labels'
drop lab_${country}

ren * (policy segment ben_target amount)

drop if ben_target == . 

reshape wide ben_target amount, i(segment) j(policy, string)

save "$tempsim/params_Direct_transfers.dta", replace


/*---- Save them as parameters */

reshape long ben_target amount, i(segment) j(policy, string)
rename  (ben_target amount)  (varben_target varamount)
reshape long var, i(segment policy) j(measure, string)
drop if var==.
tostring var, replace
preserve
	use `dirtrans_labels', clear
	drop ben_* mont_*
	drop if lab_==""
	rename lab_* var
	gen measure = "label"
	tempfile dirtrans_labels
	save `dirtrans_labels'
restore
append using `dirtrans_labels'
tostring segment, replace
gen name = policy + "_" + measure + "_s" + segment
sort policy segment, stable
keep var name

levelsof name, local(params)
foreach z of local params {
	levelsof var if name == "`z'", local(val)
	global `z' `val'
}

/*-------------------------------------------------------/
	4. Parameters by product
/-------------------------------------------------------*/

import excel "$xls_sn", sheet("${sheet4}") first clear
keep codpr vatrate_ vatexem_ cdimp_ vatelas_ sector vatform_ cdrate_ percent_
 
* 	if ("$country" == "SEN") collapse (mean) vatrate_ vatexem_ cdimp_ vatelas_ sector vatform_ cdrate_ percent_ , by(codpr)
*if ("$country" == "SEN") duplicates drop codpr, force 
*dis as error "OJOOOO!!! SENEGAL ESTÁ BORRANDO DUPLICADOS A LA FUERZA Y HAY QUE CORREGIRLO POR LO DE SECTOR Y POURCENTAGE"

save "$tempsim/params_Products.dta", replace

 
levelsof codpr, local(products)
global products "`products'"

* Organise a table of parameters
ren * value_*
ren (value_codpr value_sector_) (codpr sector)
bys codpr: gen orden = _n
reshape wide sector, i(codpr value_*) j(orden)
foreach var of varlist sector* {
	rename `var' value_`var'_
}
 
reshape long value_, i(codpr) j(var_, string)
drop if value_==.

tostring codpr, replace
gen globalname = var_ + codpr
ren value_ globalvalue

* Store as parameters
keep globalname globalvalue

levelsof globalname, local(params)
foreach z of local params {
	levelsof globalvalue if globalname == "`z'", local(val)
	global `z' `val'
}			



/*-------------------------------------------------------/
	0000. Correct parameters - Madi 
/-------------------------------------------------------*/


if $save_scenario ==1 {
	global c:all globals

	macro list c

	clear
	gen globalname=""
	gen globalcontent=""
	local n=1
	foreach glob of global c{
		dis `"`glob' = ${`glob'}"'
		set obs `n'
		replace globalname="`glob'" in `n'
		replace globalcontent=`"${`glob'}"' in `n'
		local ++n
	}

	foreach gloname in c thedo_pre theado thedo xls_sn data_out tempsim presim data_dev data_sn path S_2 S_1 S_4 S_3 S_level S_ADO S_StataSE S_FLAVOR S_OS S_OSDTL S_MACH save_scenario load_scenario scenario_name_load scenario_name_save devmode asserts_ref2021 pathdata rawdata S_PUTEXCEL_FILE_MODE S_PUTEXCEL_OPEN_FHANDLE S_PUTEXCEL_LOCALE S_PUTEXCEL_SHEET_NAME S_PUTEXCEL_FILE_TYPE S_PUTEXCEL_FILE_NAME {
		cap drop if globalname=="`gloname'"
	}

	if $save_Excel ==1 {	
		export excel "$xls_sn", sheet("p_${scenario_name_save}") sheetreplace first(variable)
		noi dis "{opt All the parameters of scenario ${scenario_name_save} have been saved to Excel.}"
	}
	if $save_dtas ==1 {	
		save "$param_out/params_${scenario_name_save}.dta", replace
	}
	if $save_csvs ==1 {	
		export delimited using "$param_out/params_${scenario_name_save}.csv", replace
	}
}


	



