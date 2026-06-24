/*============================================================================== =====================================================
  AFW Regional Microsimulation Tool; Indirect taxes - Custom Duties - CD
  Author: Madi Mangan
  Date: July, 2025
  Version: 1.0

 Notes: 
	*

	Extra Note: To run this tool, the following datasets are needed. 
		1. 
		2. Our model safely assumes that local produces does not pay custom duties. 
		3. All imported products payes their respective rates.  
*======================================================================================== ============================================ */


********************************************************* ********************************************************* ***************************************************
* 00.		Create the duty rates by product.
********************************************************* ********************************************************* ***************************************************

		use "$tempsim/params_Products.dta", replace
		keep codpr cdrate_ cdimp_
		duplicates drop
		isid codpr
		rename cdrate_ CD
		rename cdimp_ imported
		tempfile cd_info
		save `cd_info', replace

********************************************************* ********************************************************* ***************************************************
* 01.		Load data
********************************************************* ********************************************************* ***************************************************		
		
		use "$presim/05_expenses_verylong.dta", clear 
		
		merge m:1 codpr using `cd_info', nogen keep(1 3)
		recode CD imported (.=0)
		
		gen double CD_direct = achats_net*CD*imported //  * (1 - informal_purchase) NOTE!! we can later adjust this for a simulation with reduction in informality. 

********************************************************* ********************************************************* ***************************************************
* 02.		Income definition
********************************************************* ********************************************************* ***************************************************

		gen double achats_avec_CD = (achats_net + CD_direct)
		
		*Assert:
		gen dif0 = abs(achats_net_subs - achats_avec_CD)*100/max( achats_net_subs, achats_avec_CD )
		sum dif0
		if  `r(max)'<0.001{
			noi dis "{opt Custom duties match presim: }" "(%dif <" %10.6g r(max)*1 "%)"
		}
		else {
			noi noi dis as error "Custom duties do NOT match presim (max dif =" %10.6g r(max)*1 "%). Verify if this is an error or just a change in policies."
			unique codpr if dif0>0.001 & dif0 !=.
			if `r(unique)'<200{
				noi tabstat dif0 if dif0>0.001 & dif0 !=., by(codpr) stat(mean sd n)
			}
		}
		drop dif0
	
		if $devmode== 1 {
			save "$tempsim/Tariffs_verylong.dta", replace
		}
		tempfile Tariffs_verylong
			save `Tariffs_verylong'
		
********************************************************* ********************************************************* ***************************************************
* 03.		Data by household
********************************************************* ********************************************************* ***************************************************

		collapse (sum) CD_direct achats_net achats_avec_CD /*achats_avec_excises achats_sans_subs achats_sans_subs_dir*/, by(hhid)
		label var achats_avec_CD "Purchases after custom duties"
		destring hhid, replace

		if $devmode== 1 {
			save "${tempsim}/CustomDuties_taxes.dta", replace
		}
		else {
			save `CustomDuties_taxes', replace 
		}
********************************************************* ********************************************************* ***************************************************
*																			THE END
********************************************************* ********************************************************* ***************************************************		
		