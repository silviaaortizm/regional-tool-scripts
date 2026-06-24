/*============================================================================== =====================================================
  AFW Regional Microsimulation Tool; Indirect taxes - Excises
  Author		: Madi Mangan
  Date			: July, 2025
  Version		: 1.0
  last update	: 29 July, 2025

 Notes: 
	*

	Extra Note: To run this tool, the following datasets are needed. 
		1. 
*======================================================================================== ============================================ */


********************************************************* ********************************************************* ***************************************************
*** 00. load datasets
********************************************************* ********************************************************* ***************************************************

use "$presim/06_excises.dta", clear
format codpr %14.0f

********************************************************* ********************************************************* ***************************************************
*** 01. Set necessary globals
********************************************************* ********************************************************* ***************************************************

global goods alco alco2 alco3 alco4 alco5 nalco cafe sugar cig cig2 fats dairy cos textiles vehic1 vehic2 cons broths gasoline diesel kerosene other
global sin_list alco alco2 alco3 alco4 alco5 cig cig2 sugar fats // Non-alcoholic sugary beverages should be here???

foreach p in $goods {
	cap gen exp_`p' = 0
	if "${elas_ex_`p'}"=="" {
		global elas_ex_`p' 0
	}
	if "${ref_ex_`p'}"=="" {
		global ref_ex_`p' 0
	}
	if "${sin_ex_`p'}"=="" {
		global sin_ex_`p' 0
	}
}


keep hhid codpr informal_purchase exp*


********************************************************* ********************************************************* ***************************************************		
*** 02. Merge with the rest of the products
********************************************************* ********************************************************* ***************************************************
	
if $devmode== 1 {
	merge 1:m hhid codpr informal_purchase using "$tempsim/Subsidies_verylong.dta", nogen
}
else{
	merge 1:m hhid codpr informal_purchase using `Subsidies_verylong', nogen
}


********************************************************* ********************************************************* ***************************************************		
*** 03. Compute excise taxes
********************************************************* ********************************************************* ***************************************************

*If the excise is ad valorem, then excises should be affected by the price effects from customs duties and subsidies
gen double ratio = achats_sans_subs/achats_net_excise
replace ratio = 1 if ratio==. | ratio==0

foreach p in $goods {
	if ("${unit_ex_`p'}"!="Ad valorem") gen double exc_`p' = exp_`p' * ${sin_ex_`p'} + exp_`p' * (${sin_ex_`p'} - ${ref_ex_`p'})*${elas_ex_`p'}
	if ("${unit_ex_`p'}"=="Ad valorem") gen double exc_`p' = exp_`p' * ${sin_ex_`p'} + exp_`p' * (${sin_ex_`p'} - ${ref_ex_`p'})*${elas_ex_`p'}*ratio
}

*sum excises
egen double excise_taxes = rowtotal(exc_*)
recode excise_taxes (.=0)

bys hhid codpr informal_purchase: egen double denom = total(achats_sans_subs)
gen double pourcentage2 = achats_sans_subs/denom

replace excise_taxes = excise_taxes*pourcentage2  //*pondera_informal

drop pourcentage2 denom

egen double achats_avec_excises = rowtotal(achats_sans_subs excise_taxes)

*Assert:
gen dif3 = abs(achats_net_VAT - achats_net_excise - excise_taxes)*100/max( abs(achats_net_VAT - achats_net_excise), excise_taxes)
sum dif3
if  `r(max)'<0.001{
	noi dis "{opt Excises match presim: }" "(%dif <" %10.6g r(max)*1 "%)"
}
else {
	noi dis as error "Excises do NOT match presim (max dif =" %10.6g r(max)*1 "%). Verify if this is an error or just a change in policies."
	unique codpr if dif3>0.001 & dif3 !=.
	if `r(unique)'<200{
		noi tabstat dif3 if dif3>0.001 & dif3 !=., by(codpr) stat(mean sd n)
	}
}
drop dif3


*We are interested in the detailed long version, to continue the confirmation process with VAT
compress
if $devmode== 1 {
	save "$tempsim/Excises_verylong.dta", replace
}
tempfile Excises_verylong
save `Excises_verylong'

		
********************************************************* ********************************************************* ***************************************************	
*** 04. Finally, we are only interested in the per-household amounts, so we will collapse the database:
********************************************************* ********************************************************* ***************************************************

collapse (sum) excise_taxes, by(hhid)
label var excise_taxes "Excise Taxes all"
cap destring hhid, replace
if $devmode== 1 {
	save "${tempsim}/Excise_taxes.dta", replace
}
tempfile Excise_taxes
save `Excise_taxes'

********************************************************* ********************************************************* *******************************************************
*																			THE END
********************************************************* ********************************************************* *******************************************************
			
			