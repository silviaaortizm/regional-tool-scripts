/*===========================================================================
Project:            Regional Tool
Authors:            Andrés Gallegos, Gabriel Lombo, Madi Mangan, w/ Moritz Meyer & Daniel Valderrama 
Program Name:       02. Income Tax.do
---------------------------------------------------------------------------
Comments:           WE MOVED PRESIM TO ANOTHER DOFILE, IN _presim.
===========================================================================*/


use  "$presim/02_incomes_harmonized.dta", replace

foreach varoblig in inclab_ssc_family inclab_ssc_risk inclab_ssc_health {
	cap gen `varoblig' = 0
}

/**********************************************************************************/
noi dis as result " Social Security Contributions"
/**********************************************************************************/

foreach var of varlist inclab_ssc*{
	replace `var'=0 if `var'>=.
}


foreach group in P2_1 P2_2 P2_3 P2_4_l1 P2_4_l2 P2_4_l3 P2_5_pub P2_6_pub P2_5_priv P2_6_priv P2_7 P2_8  P2_9_l1  P2_10_l1  P2_9_l2  P2_10_l2  P2_9_l3  P2_10_l3 {
		if "${`group'_rate}"==""{
			global `group'_rate "0"
		}
		if "${`group'_max_base}"==""{
			global `group'_max_base "."
		}
}

gen ssc_risk = 0

forval risks=1/3{
	dis "${P2_4_l`risks'_rate}" "-" "${P2_4_l`risks'_max_base}"
	replace ssc_risk = inclab_ssc_risk*${P2_4_l`risks'_rate} if risk_level==`risks' & inclab_ssc_risk<${P2_4_l`risks'_max_base}
	replace ssc_risk = ${P2_4_l`risks'_max_base}*${P2_4_l`risks'_rate} if risk_level==`risks' & inclab_ssc_risk>=${P2_4_l`risks'_max_base}
}

gen ssc_risk_9 = 0
gen ssc_risk_10 = 0

forval risks=1/3{
	*employer
	replace ssc_risk_9 = inclab_ssc_risk*${P2_9_l`risks'_rate} if risk_level==`risks' & inclab_ssc_risk<${P2_4_l`risks'_max_base}
		replace ssc_risk_9 = ${P2_4_l`risks'_max_base}*${P2_9_l`risks'_rate} if risk_level==`risks' & inclab_ssc_risk>=${P2_4_l`risks'_max_base}
		
	*employee
	replace ssc_risk_10 = inclab_ssc_risk*${P2_10_l`risks'_rate} if risk_level==`risks' & inclab_ssc_risk<${P2_4_l`risks'_max_base}
		replace ssc_risk_10 = ${P2_4_l`risks'_max_base}*${P2_10_l`risks'_rate} if risk_level==`risks' & inclab_ssc_risk>=${P2_4_l`risks'_max_base}	
}



gen ssc_family = 0

replace ssc_family = inclab_ssc_family*${P2_3_rate} if inclab_ssc_family<${P2_3_max_base}
replace ssc_family = ${P2_3_max_base}*${P2_3_rate} if inclab_ssc_family>=${P2_3_max_base}


gen ssc_family_7 = 0
gen ssc_family_8 = 0
	
	*Employer
	replace ssc_family_7 = inclab_ssc_family*${P2_7_rate} if inclab_ssc_family<${P2_3_max_base}
	replace ssc_family_7 = ${P2_3_max_base}*${P2_7_rate} if inclab_ssc_family>=${P2_3_max_base}
	
	*Employee
	replace ssc_family_8 = inclab_ssc_family*${P2_8_rate} if inclab_ssc_family<${P2_3_max_base}
	replace ssc_family_8 = ${P2_3_max_base}*${P2_8_rate} if inclab_ssc_family>=${P2_3_max_base}


gen ssc_health_1 = 0
gen ssc_health_2 = 0

forval regime=1/2{
	replace ssc_health_`regime' = inclab_ssc_health*${P2_`regime'_rate} if public_private==`regime' & inclab_ssc_health<${P2_`regime'_max_base}
	replace ssc_health_`regime' = ${P2_`regime'_max_base}*${P2_`regime'_rate} if public_private==`regime' & inclab_ssc_health>=${P2_`regime'_max_base}
}

gen ssc_health_5 = 0
gen ssc_health_6 = 0

*employer
	*public
	replace ssc_health_5 = inclab_ssc_health*${P2_5_pub_rate} if public_private==1 & inclab_ssc_health<${P2_1_max_base}
	replace ssc_health_5 = ${P2_1_max_base}*${P2_5_pub_rate} if public_private==1 & inclab_ssc_health>=${P2_1_max_base}
	*private
	replace ssc_health_5 = inclab_ssc_health*${P2_5_priv_rate} if public_private==2 & inclab_ssc_health<${P2_2_max_base}
	replace ssc_health_5 = ${P2_2_max_base}*${P2_5_priv_rate} if public_private==2 & inclab_ssc_health>=${P2_2_max_base}
	
*employee
	*public
	replace ssc_health_6 = inclab_ssc_health*${P2_6_pub_rate} if public_private==1 & inclab_ssc_health<${P2_1_max_base}
	replace ssc_health_6 = ${P2_1_max_base}*${P2_6_pub_rate} if public_private==1 & inclab_ssc_health>=${P2_1_max_base}
	*private
	replace ssc_health_6 = inclab_ssc_health*${P2_6_priv_rate} if public_private==2 & inclab_ssc_health<${P2_2_max_base}
	replace ssc_health_6 = ${P2_2_max_base}*${P2_6_priv_rate} if public_private==2 & inclab_ssc_health>=${P2_2_max_base}



collapse (sum) ssc_risk ssc_risk_9 ssc_risk_10 ssc_family ssc_family_7 ssc_family_8 ssc_health_1 ssc_health_2 ssc_health_5 ssc_health_6, by(hhid)

if $devmode== 1 {
    save "$tempsim/social_security_contribs.dta", replace
}

tempfile social_security_contribs
save `social_security_contribs'





