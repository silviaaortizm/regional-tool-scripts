
/*============================================================================*\
 Direct Taxes simulation
 Authors: Julieth Pico based on Disposable Income by Mayor Cabrera
 Start Date: June 2020
 Update Date: May 2026, Andres Gallegos-Vargas
 
 Modifications: 
 			- Regional Tool! 
			- Deflacted and nominal incomes!
			- Intl poverty lines!
\*============================================================================*/

use "$presim/01_menages.dta", clear

keep hhid hhsize hhweight dtot zref def* ymp*

foreach var in ceros_dirtr ceros_dirt ceros_ssc ceros_indt ceros_sub ceros_inkt {
	cap gen `var' = 0
} 

*-------------------------------------
// Generate all baseline welfare definitions
*-------------------------------------

gen double yd_pre  = dtot / (hhsize)
gen double pcc     = dtot / (hhsize*def_st_nat)
gen double ipcc_17 = dtot / (hhsize*365*${cpi2017}*${icp2017}*def_st_int)
gen double ipcc_21 = dtot / (hhsize*365*${cpi2021}*${icp2021}*def_st_int)
label var dtot    "Nominal annual consumption"
label var yd_pre  "Nominal annual consumption per capita"
label var pcc     "Deflacted annual cons. per capita - National Welfare Agg."
label var ipcc_17 "Welfare aggregate for intl poverty, day per capita consumption in 2017 PPP"
label var ipcc_21 "Welfare aggregate for intl poverty, day per capita consumption in 2021 PPP"

*-------------------------------------
// Generate all lines in nominal terms to compare with yd_pc
*-------------------------------------

gen zrefn     = zref*def_st_nat
gen line_1_17 = 2.15*365*${cpi2017}*${icp2017}*def_st_int
gen line_2_17 = 3.65*365*${cpi2017}*${icp2017}*def_st_int
gen line_3_17 = 6.85*365*${cpi2017}*${icp2017}*def_st_int
gen line_1_21 = 3.0*365*${cpi2021}*${icp2021}*def_st_int
gen line_2_21 = 4.2*365*${cpi2021}*${icp2021}*def_st_int
gen line_3_21 = 8.3*365*${cpi2021}*${icp2021}*def_st_int

*-------------------------------------
// Merge all policies at the household level
*-------------------------------------

if $devmode== 1 {
	merge 1:1 hhid using "${tempsim}/social_security_contribs.dta", nogen
	merge 1:1 hhid using "${tempsim}/income_tax_collapse.dta", nogen
	merge 1:1 hhid using "${tempsim}/Direct_transfers.dta", nogen
	merge 1:1 hhid using "${tempsim}/CustomDuties_taxes", nogen
	merge 1:1 hhid using "${tempsim}/Subsidies", nogen
	merge 1:1 hhid using "${tempsim}/Excise_taxes.dta", nogen
	merge 1:1 hhid using "${tempsim}/VAT_taxes.dta", nogen
	merge 1:1 hhid using "${tempsim}/Transfers_InKind.dta", nogen
}
else {
	merge 1:1 hhid using `social_security_contribs' , nogen
	merge 1:1 hhid using `income_tax_collapse' , nogen
	merge 1:1 hhid using `Direct_transfers'  , nogen
	merge 1:1 hhid using `Subsidies' , nogen
	merge 1:1 hhid using `Excise_taxes' , nogen
	merge 1:1 hhid using `VAT_taxes' , nogen
	merge 1:1 hhid using `Transfers_InKind' , nogen
}

* All policies, regardless of them being taxes or subsidies, should be positive 
* Nominal gross market income (ymp_pc) that is going to be used as basis of all calculations:

	local Directaxes 		"${Directaxes}"
	local Contributions 	"${Contributions}" 
	local DirectTransfers   "${DirectTransfers}"
	local Subsidies         "${Subsidies}"
	local Indtaxes 			"${Indtaxes}"
	local InKindTransfers	"${InKindTransfers}" 
		
	local taxcs 			`Directaxes' `Indtaxes' `Contributions'
	local transfers         `DirectTransfers' `Subsidies' `InKindTransfers'
	
	di "`Directaxes' /// `Contributions' /// `DirectTransfers' /// `Subsidies' /// `Indtaxes' /// `InKindTransfers'"

*-------------------------------------
// Per cápita variables
*-------------------------------------
	
	foreach var in `Directaxes' `Contributions' `DirectTransfers'  `Indtaxes' `Subsidies' `InKindTransfers' {
		di "`var'"
		cap gen `var' = 0   // temporal fix. This should be deleted in the final model.  - by Madi 
		gen `var'_pc = `var'/hhsize
	}
	
	foreach listvar in Directaxes Indtaxes InKindTransfers Contributions DirectTransfers Subsidies taxcs transfers {
		local `listvar'_pc ""
		foreach var of local `listvar' {
			local `listvar'_pc "``listvar'_pc' `var'_pc"
			di "`listvar'_pc"
		}
	}
	
*change taxes and contributions to negatives (only _pc to calculate income definitions)

	foreach i in `Indtaxes_pc' `Directaxes_pc' `Contributions_pc' {
		replace `i'=-`i'
	}
	
	
***************************************   NET MARKET INCOME  ---STARTING POINT:  MARKET INCOME CALCULATED IN THE GROSSING UP

egen  double aux = rowtotal(`Directaxes_pc' `Contributions_pc' ) // Income before tax minus taxes and contributions
egen  double yn_pc = rowtotal(ymp_pc aux) 
replace yn_pc = 0 if yn_pc == .
replace yn_pc = 0 if yn_pc < 0
label var yn_pc "Net Market Income per capita" 

			
***************************************   DISPOSABLE INCOME --ASSERT THAT WE ARRIVE TO THE SAME PER CAPITA CONSUMPTION

egen  double yd_pc = rowtotal(yn_pc `DirectTransfers_pc') 
replace yd_pc=0 if yd_pc==.
label var yd_pc "Disposable Income per capita"

gen double dif_grossupp = (yd_pc-yd_pre)/yd_pre

count if abs(dif_grossupp) >0.0001
if `r(N)'>0{
	noi dis as error "The disposable income obtained is different than the per capita consumption that we assumed in the grossing up."
	noi dis as error "This happened because you changed policies that affected direct transfers, income tax, or SS contributions."
	noi sum dif_grossupp if abs(dif_grossupp) >0.0001
}
else {
	noi dis "{opt The disposable income obtained is equal to the per capita consumption that we assumed in the grossing up.}"
	noi dis "{opt This means that you have not changed any policies related with direct transfers, income tax, or SS contributions.}"
}
drop dif_grossupp

***************************************   CONSUMABLE INCOME ---MOVING FORWARD : adding indirect taxes and subsidies

egen  double yc_pc = rowtotal(yd_pc `Subsidies_pc' `Indtaxes_pc' )
replace yc_pc=0 if yc_pc==.
replace yc_pc=0 if yc_pc<0
label var yc_pc "Consumable Income per capita"


***************************************   FINAL INCOME

egen  double yf_pc= rowtotal(yc_pc `InKindTransfers_pc' )
replace yf_pc=0 if yf_pc==.
replace yf_pc=0 if yf_pc<0
label var yf_pc "Final Income per capita"


* Some extra useful variables 
gen all = 1
gen pondih= hhweight*hhsize


**************** Deflate all income definitions

foreach var in ymp_pc yn_pc yd_pc yc_pc yf_pc {
	gen `var'dr = `var'/def_st_nat
	gen `var'di17 = `var'/(365*${cpi2017}*${icp2017}*def_st_int)
	gen `var'di21 = `var'/(365*${cpi2021}*${icp2021}*def_st_int)
}

**************** All deciles and centiles will be defined using national deflacted income definitions
_ebin ymp_pcdr [aw=pondih], nq(100) gen(ymp_centile_pc)
_ebin yn_pcdr [aw=pondih], nq(100) gen(yn_centile_pc)
_ebin yd_pcdr [aw=pondih], nq(100) gen(yd_centile_pc)
_ebin yc_pcdr [aw=pondih], nq(100) gen(yc_centile_pc)
_ebin yf_pcdr [aw=pondih], nq(100) gen(yf_centile_pc)

_ebin ymp_pcdr [aw=pondih], nq(10) gen(deciles_pc)
_ebin yd_pcdr [aw=pondih], nq(10) gen(yd_deciles_pc)
_ebin yc_pcdr [aw=pondih], nq(10) gen(yc_deciles_pc)



gen poor=1 if yc_pcdr<=zref
recode poor .= 0
tab poor [iw=pondih]


*change taxes and contributions back to positives

foreach i in `Indtaxes_pc' `Directaxes_pc' `Contributions_pc' {
		replace `i' = -`i'
}

save "$data_out/output.dta", replace


if substr("$scenario_name_save", 1, 7) == "Ref_AFW" & $save_scenario ==1 {
	save "$data_out/output_ref_${country}.dta", replace
}

** New poor and old poor using _ref and selected scenario 

use "$data_out/output.dta" , clear


rename poor poor_simu

merge 1:1 hhid using "$data_out/output_ref_${country}"  , keepusing(poor) nogen keep(1 3)

rename poor poor_ref 

gen new_poor_pc=  poor_simu==1 & poor_ref==0

gen old_poor_pc=  poor_simu==0 & poor_ref==1
sort hhid




*----- Generate policy aggregations


* Main 6 general policy groups 

egen dirtax_total = rowtotal(`Directaxes')
egen dirtax_total_pc = rowtotal(`Directaxes_pc')

egen dirtransf_total = rowtotal(`DirectTransfers')
egen dirtransf_total_pc = rowtotal(`DirectTransfers_pc')

egen sscontribs_total = rowtotal(`Contributions')
egen sscontribs_total_pc = rowtotal(`Contributions_pc')

egen subsidy_total = rowtotal(`Subsidies')
egen subsidy_total_pc = rowtotal(`Subsidies_pc')

egen indtax_total = rowtotal(`Indtaxes')
egen indtax_total_pc = rowtotal(`Indtaxes_pc')

egen inktransf_total = rowtotal(`InKindTransfers')
egen inktransf_total_pc = rowtotal(`InKindTransfers_pc')


*gen subsidy_elec = subsidy_elec_direct + subsidy_elec_indirect
gen subsidy_elec_pc = subsidy_elec_direct_pc + subsidy_elec_indirect_pc

*gen subsidy_fuel = subsidy_fuel_direct + subsidy_fuel_indirect
gen subsidy_fuel_pc = subsidy_fuel_direct_pc + subsidy_fuel_indirect_pc

*gen subsidy_water = subsidy_water_direct + subsidy_water_indirect
gen subsidy_water_pc = subsidy_water_direct_pc + subsidy_water_indirect_pc

*gen Tax_VAT = VAT_direct + VAT_indirect
gen Tax_VAT_pc = VAT_direct_pc + VAT_indirect_pc

*gen education_inKind = am_educ_1 + am_educ_2 + am_educ_3 + am_educ_4 + am_educ_7
gen education_inKind_pc = am_educ_1_pc + am_educ_2_pc + am_educ_3_pc + am_educ_4_pc + am_educ_5_pc + am_educ_6_pc



*------- Labels	Policy 
foreach i in `Directaxes' `Contributions' `DirectTransfers'  `Indtaxes' `Subsidies' `InKindTransfers' {
	local var `i'
	label var `var' "$`var'_lab"
	label var `var'_pc "${`var'_lab} per capita"
	
}

local policylist `Directaxes' dirtax_total `Contributions' sscontribs_total `DirectTransfers' dirtransf_total `Subsidies' subsidy_total `Indtaxes' indtax_total `InKindTransfers' inktransf_total

foreach var of local policylist {
	local labelle : variable label `var'
	*label var `var'_pc "`labelle'" // CHANGED
}

save "$data_out/output.dta", replace

if $save_scenario == 1 {	
	save "$data_out/output_${scenario_name_save}.dta", replace
}








