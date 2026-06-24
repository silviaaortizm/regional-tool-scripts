/*--------------------------------------------------------------------------------
*--------------------------------------------------------------------------------
* Program: Program for the Impact of Fiscal Reforms - CEQ Senegal
* Author: 	JuanP. Baquero
* Date: 		11 Nov 2020
* Title: 	Generate Output for Simulation
*--------------------------------------------------------------------------------
*--------------------------------------------------------------------------------
*Note: Each output goes in long format  to a hidden sheet call all_`sheetnm'

Version 2. 
	- Change the refrence income for marginal contributions for all categories
	- Minor: commenting do-file and Making comments and Pendent
	- Added a new category for subsidies (before were together with transfers, not correct because their marginal contributions are measured differently

	
Pendent : 
_---------------------------------------------------------------------------------*/

if $save_scenario == 1 {	
	global sheetname "${scenario_name_save}"
}
if $save_scenario == 0 & $load_scenario == 1 {	
	global sheetname "${scenario_name_load}"
}
if $load_scenario == 0 & $save_scenario == 0 {	
	global sheetname "User_def_sce"
}

*---- Macros for household values 

	local Directaxes 		"${Directaxes}"
	local Contributions 	"${Contributions}" 
	local DirectTransfers   "${DirectTransfers}"
	local Subsidies         "${Subsidies}"
	local Indtaxes 			"${Indtaxes}"
	local InKindTransfers	"${InKindTransfers}" 

	local tax dirtax_total sscontribs_total `Directaxes' `Contributions' 
	local indtax indtax_total `Indtaxes' Tax_VAT
	local inkind inktransf_total `InKindTransfers' education_inKind
	local transfer dirtransf_total `DirectTransfers' 
	local Subsidies subsidy_total `Subsidies' subsidy_elec subsidy_fuel subsidy_water
	local income ymp yn yd yc yf 
	local concs `tax' `indtax' `transfer' `inkind' `income' `Subsidies'

	
*Macros at per-capita values 
	foreach x in tax indtax inkind transfer income concs Subsidies {
		local `x'_pc
		foreach y of local `x' {
			local `x'_pc ``x'_pc' `y'_pc 	
		}
	}
*Other macros 
	local pline1 zrefn line_1_17 line_2_17 line_3_17  //me tocó partirlo en 2 porque el código de sp_groupfunction se muere con el número de observaciones
	local pline2 line_1_21 line_2_21 line_3_21
	local incomes_pcdr ymp_pcdr yn_pcdr yd_pcdr yc_pcdr yf_pcdr
	local incomes_pcdi ymp_pcdi17 yn_pcdi17 yd_pcdi17 yc_pcdi17 yf_pcdi17
	
*===============================================================================
		* Save Scenario
*===============================================================================

if $save_scenario == 1 {
	global c:all globals
	macro list c

	clear
	gen globalname = ""
	gen globalcontent = ""
	local n = 1
	foreach glob of global c{
		dis `"`glob' = ${`glob'}"'
		set obs `n'
		replace globalname = "`glob'" in `n'
		replace globalcontent = `"${`glob'}"' in `n'
		local ++n
	}

	foreach gloname in c thedo_pre theado thedo xls_sn data_out tempsim presim data_dev data_sn path S_4 S_3 S_level S_ADO S_StataSE S_FLAVOR S_OS S_OSDTL S_MACH save_scenario load_scenario devmode asserts_ref2018 {
		cap drop if globalname == "`gloname'"
	}

	export excel "$xls_out", sheet("p_${scenario_name_save}") sheetreplace first(variable)
	noi dis "{opt All the parameters of scenario ${scenario_name_save} have been saved to Excel.}"
	
	*Add saved scenario to list of saved scenarios
	import excel "$xls_out", sheet("legend") first clear cellrange(AH1)
	drop if Scenario_list == ""
	expand 2 in -1
	replace Scenario_list = "${scenario_name_save}" in -1
	duplicates drop
	*gen ord = 2
	*replace ord = 1 if Scenario_list == "Ref_2018"
	*replace ord = 3 if Scenario_list == "User_def_sce"
	*sort ord, stable
	*drop ord
	
	export excel "$xls_out", sheet("legend", modify) cell(AH2)
}
*/
	
	
*===============================================================================
		*Produce Concentration by centile_pc
*===============================================================================

foreach rank in ymp yd yc {
	
	use "$data_out/output", clear

	keep hhid `concs_pc' pondih *_centile_pc *_pcdr
	
	foreach x of local concs_pc {
		covconc `x' [aw=pondih] , rank(`rank'_pcdr)	//gini and concentration coefficients
		local _`x' = r(conc)
	}
	
	groupfunction [aw=pondih], sum(`concs_pc') by(`rank'_centile_pc) norestore
	qui count
	local _1 =r(N)
	local nnn=`_1'+ 1  //add one more obs, the total obs goes from 100 to 101
	set obs `nnn'
	replace `rank'_centile_pc = 0 in `nnn'
	
	sort `rank'_centile_pc
	putmata x = (`concs_pc') if `rank'_centile_pc!=0, replace 
	mata: x = J(1,cols(x),0) \ x  //generate a constant row, add to the top
	mata: x = x:/quadcolsum(x)  //divide each element by the column total
	mata: for(i=1; i<=cols(x);i++) x[.,i] = quadrunningsum(x[.,i])  //replace exisiting matrix by new elements
	
	getmata (`concs_pc') = x, replace
	
	qui count
	local _1 =r(N)
	local nnn=`_1'+ 1 //add one more obs, the total obs goes to 102
	set obs `nnn'
	
	replace `rank'_centile_pc = 999 in `nnn'
	foreach x of local concs_pc {
		replace `x' = `_`x'' in `nnn'  //replace the last observation with gini/concentration coefficient
	}	
	order `rank'_centile_pc, first
	
	export excel using "$xls_out", sheet("conc`rank'_${sheetname}") sheetreplace first(variable) // locale(C)  nolabel
	noi dis "Exportamos la hoja conc`rank'_${sheetname}"
}
*/

*===============================================================================
		*Netcash Position
*===============================================================================


{
* net cash ymp

	use "$data_out/output", clear
	
	keep hhid `concs_pc' pondih *_centile_pc deciles_pc						// deciles_pc is already using ymp_pcdr (deflacted ym income)
	
	foreach x in `tax' `indtax'  {
		gen share_`x'_pc= -`x'_pc/ymp_pc
	}
	
	foreach x in `transfer' `inkind' `Subsidies' {
		gen share_`x'_pc= `x'_pc/ymp_pc
	}
	
	keep deciles_pc share* pondih	
	
	groupfunction [aw=pondih], mean (share*) by(deciles_pc) norestore
	
	reshape long share_, i(deciles_pc) j(variable) string
		gen measure = "netcash" 
		rename share_ value
	
	tempfile netcash_ymp
	save `netcash_ymp'

* net cash yd 	
	
	use "$data_out/output", clear
	
	foreach x in `tax' `indtax'  {
		gen share_`x'_pc= -`x'_pc/yd_pc
	}		
	
	foreach x in `transfer' `inkind' `Subsidies' {
		gen share_`x'_pc= `x'_pc/yd_pc
	}
	
	*replace share_snit_hh_ae = - share_snit_hh_ae
	keep yd_deciles_pc share* pondih										// yd_deciles_pc is already using yd_pcdr (deflacted yd income)
		
	groupfunction [aw=pondih], mean (share*) by(yd_deciles_pc) norestore
	
	reshape long share_, i(yd_deciles_pc) j(variable) string
		gen measure = "netcash" 
		rename share_ value
	
	tempfile netcash_yd
	save `netcash_yd'
}		

*===============================================================================
		*Distributional indicators Gini, Theil, and FGT measures
		*Generate Income Concepts for Marginal Contribution
*===============================================================================

*run "$theado\sp_groupfunction.ado"

use "$data_out/output",  clear
		
		*Gabriela's 2022 suggestions for marginal contribution calculations:
		// (DV) For taxes ymp_pc is the counterfactual withouth the policy
		// (DV) For indirect taxes yd_pc is the counterfactual withouth the policy
		// (DV) For direct transfers ymp_pc is the counterfactual withouth the policy 
		// (DV) For subsidies yd_pc is the counterfactual withouth the policy 
		// (DV) For in-kind yc_pc is the counterfactual withouth the policy 
		
		//(AGV) I will generate all possible combinations, and fix these suggestions in Excel (allowing us to change them easily there)

*List of all new marginal contributions store in income
local income2 ""
local income2dr ""

local aux1 `tax' `indtax'
foreach var of local aux1{
	replace `var' = -`var'
	replace `var'_pc = -`var'_pc
}

local aux2 `tax' `indtax' `transfer' `Subsidies' `inkind'
foreach inc in ymp yn yd yc {   //(AGV) I'm excluding final income because it does not make sense contributing to that
	foreach var of local aux2 {
		gen `inc'_inc_`var'=(`inc'_pc+`var'_pc)   //ahora me sirve en nominal, porque las líneas las desdeflacté
		local income2 `income2' `inc'_inc_`var'   // Store incomes to marignal contribution calculation
		gen `inc'_incd_`var'=(`inc'_pc+`var'_pc)/def_st_nat  //dejo el deflactado para marginal contrib to gini (national)
		local income2dr `income2dr' `inc'_incd_`var'   // Store incomes to marignal contribution calculation
	}
}

foreach var of local aux1{
	replace `var' = -`var'
	replace `var'_pc = -`var'_pc
}

preserve
	sp_groupfunction [aw=pondih], gini(`incomes_pcdr' `incomes_pcdi' `income2dr') theil(`incomes_pcdr' `incomes_pcdi' `income2dr') poverty(`income_pc' `income2') povertyline(`pline1')  by(all) 
	replace variable = subinstr(variable, "_incd_", "_inc_", 1)
	replace reference = "zref" if reference=="zrefn"
	replace reference = "zref" if substr(variable, -4, 5)=="pcdr"
	replace variable  = substr(variable, 1, length(variable)-2) if substr(variable, -4, 5)=="pcdr"
	replace reference = "line" if substr(variable, -4, 5)=="di17"
	replace variable  = substr(variable, 1, length(variable)-4) if substr(variable, -4, 5)=="di17"
	tempfile poverty1
	save `poverty1'
restore
	sp_groupfunction [aw=pondih], poverty(`income_pc' `income2') povertyline(`pline2')  by(all) 
	replace variable = subinstr(variable, "_incd_", "_inc_", 1)
	tempfile poverty2
	save `poverty2'
	
*===============================================================================
		*GenderSpatial Analysis (using quintiles)
*===============================================================================

* Poverties and inequalities (NO marginal contributions)
foreach segments in g_hhhead g_income g_demog region rural{
	noi dis "Now generating all statistics disaggregating by `segments'"
	use "$data_out/output",  clear
	preserve
		sp_groupfunction [aw=pondih], gini(`incomes_pcdr' `incomes_pcdi') theil(`incomes_pcdr' `incomes_pcdi') poverty(`income_pc') povertyline(`pline1')  by(`segments') 
		replace reference = "zref" if reference=="zrefn"
		replace reference = "zref" if substr(variable, -4, 5)=="pcdr"
		replace variable  = substr(variable, 1, length(variable)-2) if substr(variable, -4, 5)=="pcdr"
		replace reference = "line" if substr(variable, -4, 5)=="di17"
		replace variable  = substr(variable, 1, length(variable)-4) if substr(variable, -4, 5)=="di17"
		tempfile pov`segments'1
		save `pov`segments'1'
	restore
		sp_groupfunction [aw=pondih], poverty(`income_pc') povertyline(`pline2')  by(`segments') 
		tempfile pov`segments'2
		save `pov`segments'2'
}

* Benefits/Beneficiaries/Coverage all/ymp quintiles
foreach segments in g_hhhead g_income g_demog region rural{
	*agregado
	use "$data_out/output",  clear
	sp_groupfunction [aw=pondih], benefits(`concs_pc') mean(`concs_pc') coverage(`concs_pc') beneficiaries(`concs_pc')  by(`segments')
	gen quintiles_pc=0
	tempfile theall`segments'
	save `theall`segments''
	*por quintiles
	use "$data_out/output",  clear
	gen quintiles_pc = round(deciles_pc/2, 1)
	sp_groupfunction [aw=pondih], benefits(`concs_pc') mean(`concs_pc') coverage(`concs_pc') beneficiaries(`concs_pc')  by(quintiles_pc `segments')
	tempfile theallq`segments'
	save `theallq`segments''
}

* Netcash (Relative Incidence) all/ymp quintiles
foreach segments in g_hhhead g_income g_demog region rural{
	*agregado
	use "$data_out/output",  clear
	gen quintiles_pc = round(deciles_pc/2, 1)
	foreach x in `tax' `indtax'  {
		gen share_`x'_pc= -`x'_pc/ymp_pc
	}
	foreach x in `transfer' `inkind' `Subsidies' {
		gen share_`x'_pc= `x'_pc/ymp_pc
	}
	groupfunction [aw=pondih], mean(share*) by(`segments') norestore
	reshape long share_, i(`segments') j(variable) string
	gen measure = "netcash"
	rename share_ value
	tempfile netcash`segments'
	save `netcash`segments''
	*por quintiles
	use "$data_out/output",  clear
	gen quintiles_pc = round(deciles_pc/2, 1)
	foreach x in `tax' `indtax'  {
		gen share_`x'_pc= -`x'_pc/ymp_pc
	}
	foreach x in `transfer' `inkind' `Subsidies' {
		gen share_`x'_pc= `x'_pc/ymp_pc
	}
	groupfunction [aw=pondih], mean(share*) by(quintiles_pc `segments') norestore
	reshape long share_, i(quintiles_pc `segments') j(variable) string
	gen measure = "netcash"
	rename share_ value
	tempfile netcashq`segments'
	save `netcashq`segments''
}

foreach segments in g_hhhead g_income g_demog region rural {
	use `pov`segments'1'
	append using `pov`segments'2'
	append using `theall`segments''
	append using `theallq`segments''
	append using `netcash`segments''
	append using `netcashq`segments''
	if "`segments'" == "g_hhhead" {
		gen group = "g1"
	}
	if "`segments'" == "g_income" {
		gen group = "g2"
	}
	if "`segments'" == "g_demog" {
		gen group = "g3"
	}
	if "`segments'" == "region" {
		gen group = "reg"
	}
	if "`segments'" == "rural" {
		gen group = "ur"
	}
	gen grouping="q"+string(quintiles_pc)+group+string(`segments')
	replace grouping=group+string(`segments') if quintiles_pc==.
	gen concat = variable +"_"+ measure+"_" +reference+"_ymp_"+grouping
	keep concat measure value _population variable
	order concat measure value _population variable
	tempfile all`segments'
	save `all`segments''
}

*===============================================================================
		*SP Indicators 
*===============================================================================

	
	* All 
* benefits, coverage beneficiaries by all	
	use "$data_out/output",  clear	

	sp_groupfunction [aw=pondih], benefits(`concs_pc') mean(`concs_pc') coverage(`concs_pc') beneficiaries(`concs_pc')  by(all)
	gen deciles_pc=0
	tempfile theall
	save `theall'

* benefits, coverage beneficiaries by deciles (ymp)	
	use "$data_out/output",  clear
	
	sp_groupfunction [aw=pondih], benefits(`concs_pc') mean(`concs_pc') coverage(`concs_pc') beneficiaries(`concs_pc')  by(deciles_pc)
*adding previous ones 	
	append using `poverty1'
	append using `poverty2'
	append using `netcash_ymp'
	append using `theall'	
		
	gen concat = variable +"_"+ measure+"_" +reference+"_ymp_"+string(deciles_pc)
	order concat, first
	
	tempfile aux1
	save `aux1'
	
* benefits, coverage beneficiaries by yd
	use "$data_out/output",  clear	
	
	
	sp_groupfunction [aw=pondih], benefits(`concs_pc') mean(`concs_pc') coverage(`concs_pc') beneficiaries(`concs_pc')  by(yd_deciles_pc)
	
	
	append using `netcash_yd'
	
	gen concat = variable +"_"+ measure+"_"+"_yd_"+string(yd_deciles_pc)
	order concat, first
	
	append using `aux1'
	
	append using `allg_hhhead'    
	append using `allg_income'
	append using `allg_demog'
	append using `allregion'
	append using `allrural'
	
	duplicates drop
	
	export excel "$xls_out", sheet("all${sheetname}") sheetreplace first(variable)


