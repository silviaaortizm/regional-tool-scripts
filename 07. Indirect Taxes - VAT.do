/*============================================================================== =====================================================
  AFW Regional Microsimulation Tool; Indirect taxes - Value Added Taxes - VAT
  Author: Madi Mangan
  Date: July, 2025
  Version: 1.0

 Notes: 
	*

	Extra Note: To run this tool, the following datasets are needed. 
		1. 
*======================================================================================== ============================================ */


/* --------------------------------------------------------------- -------------------------------------------------------------------
1.1  Creating the database for vatmat, with %exempted by Sector
 ----------------------------------------------------------------- ------------------------------------------------------------------- */
	*use "$presim/05_purchases_hhid_codpr.dta", clear
	use "$presim/05_expenses_verylong.dta", clear
	destring hhid, replace 
		merge m:1 hhid using "$presim/01_menages.dta" , nogen keepusing(hhweight)
		cap gen double depan = achat_gross
		collapse (sum) depan [iw=hhweight], by(codpr) 
	tempfile prod_weights
	save `prod_weights'

		use `prod_weights', clear
		gen double VAT=.
		gen double exempted=.
		levelsof codpr, local(produits)
		foreach prod of local produits {
			replace VAT      = ${vatrate_`prod'} if codpr==`prod'
			replace exempted = ${vatexem_`prod'} if codpr==`prod'
		}
		
		preserve
			use "$tempsim/params_Products.dta", clear
			keep codpr sector percent_
			ren sector_ sector
			drop if codpr==.
			tempfile VAT_original
			save `VAT_original'
		restore
		
		merge 1:m codpr using `VAT_original', keepusing(sector percent_) nogen
		replace depan      = 0 if depan==.
		replace depan      = depan*percent_

********************************************************* ********************************************************* ***************************************************
*** 1.2. Product data --> Sector data

		gen all=1
		collapse (mean) VAT (sum) all [iw=depan], by(sector exempted)
		ren all depan // this was to make VAT a weighted average but not depan
	tempfile VAT_sectors_exempted
	save `VAT_sectors_exempted', replace

		collapse (mean) VAT exempted [iw=depan], by(sector)
	tempfile sectors
	save `sectors', replace

*1.3. Sector data --> IO matrix y vatmat

	use "$presim/IO_Matrix.dta", clear	
	drop if sector==.
	merge 1:1 sector using `sectors', nogen
	
	rename exempted VAT_exempt_share
	gen VAT_exempt=0 if VAT_exempt_share==0
	replace VAT_exempt=1 if VAT_exempt_share>0 & VAT_exempt_share<.
	assert  VAT_exempt_share>0   if VAT_exempt==1 // all exempted sector should have a exemption share 
	assert  VAT_exempt_share==0  if VAT_exempt==0 // all non exempted sector should have either zero or missing  

*What to do with sectors with no VAT information? Assume they are no exempted & avg. rate
	count if VAT_exempt_share==.
	if `r(N)'>0{
		local numsect `r(N)'
		sum VAT
		local avgrate = round(`r(mean)'*100,0.01)
		dis as error "`numsect' sectors have no VAT information, we just assumed they are not exempted and assume the average VAT rate of `avgrate'%."
	}

	replace VAT_exempt_share=0 if VAT_exempt_share==.
	replace VAT_exempt      =0 if VAT_exempt      ==.
	sum VAT
	if "$country"=="GNQ"{
		replace VAT=.15 if VAT==.
		noi dis as error "OJOOOO!!!! EN GNQ SE ASUME IVA DE 15% A SECTORES SIN INFORMACIÓN. CUANDO ESTEMOS LISTOS, IR AL DO FILE 07 Y BORRAR ESTE CONDICIONAL. "
	}
	else {
		replace VAT=`r(mean)' if VAT==.
	}
	
	tempfile io_original_SY 
	save `io_original_SY', replace 

	des sect_*, varlist  
	local list "`r(varlist)'"
	vatmat `list' , exempt(VAT_exempt) pexempt(VAT_exempt_share) sector(sector) 
	
********************************************************* ********************************************************* ***************************************************
*** 02.  Estimating indirect effects of VAT
********************************************************* ********************************************************* ***************************************************
	noi dis as result " 1. Indirect effect of Value Added Taxes - VAT"
	
	merge m:1 sector using "$presim/IO_Matrix.dta", assert(master matched) keepusing(fixed) nogen 

	merge m:1 sector using `io_original_SY', assert(master matched) keepusing(VAT) nogen

	*No price control sectors 
	gen double cp=1-fixed

	*vatable sectors 
	gen double vatable=1-fixed-exempted
	replace vatable = 0 if vatable==-1 //Sectors that are fixed and exempted are not VATable

	*Indirect effects 
	des sector_*, varlist 
	local list "`r(varlist)'"
	vatpush `list' , exempt(exempted) costpush(cp) shock(VAT) vatable(vatable) gen(VAT_indirect)

	keep sector VAT VAT_indirect fixed exempted
	rename VAT VAT_mean_sector

	tempfile ind_effect_VAT
	save `ind_effect_VAT'

********************************************************* ********************************************************* ***************************************************
***  03. Computing direct price effects of VAT
********************************************************* ********************************************************* ***************************************************
noi dis as result " 2. Direct effect of VAT policy"

		clear
		gen long codpr=.
		gen VAT=.
		gen exempted=.
		local i=1
		foreach prod of global products {
			set obs `i'
			qui replace codpr	 = `prod' in `i'
			qui replace VAT      = ${vatrate_`prod'} if codpr==`prod' in `i'
			qui replace exempted = ${vatexem_`prod'} if codpr==`prod' in `i'
			local i=`i'+1
		}
		tempfile VATrates
		save `VATrates'

		if $devmode== 1 {
			use "$tempsim/Excises_verylong.dta", clear	
		}
		else{
			use `Excises_verylong', clear
		}
		
		merge m:1 codpr using `VATrates', nogen keep(1 3)
		
		if "$country"=="MRT" | "$country"=="GMB" {
			replace achats_avec_excises = achats_net_VAT	
			noi dis as error "Temporal fix for MRT and GMB, this should be deleted later"
		}		

* Informality simulation assumption
		noi dis as result "Simulation with the assumption that informality decrease in ${informal_reduc_rate} %"

		egen double aux = max(informal_purchase * achats_avec_excises * $informal_reduc_rate ), by(hhid codpr)
		gen double aux_f = (1 - informal_purchase) * (achats_avec_excises + aux) 
		gen double aux_i = informal_purchase * (achats_avec_excises - aux)

		bysort hhid codpr: egen double x_bef = total(achats_avec_excises)

		replace aux_f = 0 if aux_f == .
		replace aux_i = 0 if aux_i == .
		replace achats_avec_excises = aux_f + aux_i

		bysort hhid codpr: egen double x_aft = total(achats_avec_excises)

		* Check
		*assert inrange(x_bef,x_aft*0.9999, x_aft*1.0001)
		drop aux aux_f aux_i x_bef x_aft 
		gen double VAT_direct = achats_avec_excises * VAT * (1 - informal_purchase)
		
		if "$country"=="GMB" {
			replace VAT_direct = achats_avec_excises*VAT if import ==1
			noi dis as error "GMB only applies VAT to imports?? This should be reviewed and deleted later"
		}

* Include VAT exemptions to water and electricity
		noi dis as result "Now, we will take into account the VAT exemptions of water and electricity — Tranche Sociale "
		
		cap gen fixedcost_elec_wat=0 //if it does not exist
		
		sum consumption_electricite
		if `r(mean)'>0{
			gen double VAT_elec = (VATable_spend_elec + fixedcost_elec_wat)* codpr_elec * VAT * (1 - informal_purchase)
			replace VAT_direct = VAT_elec if codpr_elec>0
		}
		sum q_water
		if `r(mean)'>0{
			gen double VAT_water = (VATable_spend_water + fixedcost_elec_wat) * codpr_water * VAT * (1 - informal_purchase) 
			replace VAT_direct = VAT_water if codpr_water>0
		}
		
		
		*drop exempted_cons_elec exempted_cons_water VAT_exemption_elec VAT_exemption_water //To make the database a little bit softer
		
*-------------------------------------------------------------------*
*		Merging direct and indirect VAT, and confirmation
*-------------------------------------------------------------------*

		merge m:1 sector exempted using `ind_effect_VAT', nogen  /*assert(match using)*/ keep(match)

		rename VAT_indirect VAT_indirect_shock
		gen double VAT_indirect = VAT_indirect_shock * achats_avec_excise

		*Confirmation that the calculation is correct for the survey year policies:
		gen double achats_avec_VAT = (achats_avec_excise + VAT_direct) * (1 + VAT_indirect_shock)
		gen double achats_avec_VAT2 = achats_avec_excise + VAT_direct + VAT_indirect
		gen double interaction_VATs = achats_avec_VAT-achats_avec_VAT2
		sum interaction_VATs, deta
		
		*Correction: We will count the interaction as further indirect effects
		replace VAT_indirect = VAT_indirect + interaction_VATs
		drop interaction_VATs
		egen double Tax_VAT = rowtotal(VAT_direct VAT_indirect)
		
		*Assert:
		gen dif4 = abs(achat_gross - achats_net_VAT - Tax_VAT)*100/max(abs(achat_gross - achats_net_VAT), Tax_VAT)
		sum dif4
		if  `r(max)'<0.01{
			noi dis "{opt VAT matches presim: }" "(%dif <" %10.6g r(max)*1 "%)"
		}
		else {
			noi dis as error "VAT does NOT match presim (max dif =" %10.6g r(max)*1 "%). Verify if this is an error or just a change in policies."
			unique codpr if dif4>0.01 & dif4 !=.
			if `r(unique)'<200{
				noi tabstat dif4 if dif4>0.01 & dif4 !=., by(codpr) stat(mean sd n)
			}
		}
		drop dif4
		
		
		if $devmode== 1 {
			save "$tempsim/FinalConsumption_verylong.dta", replace
		}
		else{
			save `FinalConsumption_verylong', replace
		}

		*Finally, we are only interested in the per-household amounts, so we will collapse the database:

		collapse (sum) VAT_indirect VAT_direct achats_avec_VAT achats_net, by(hhid)

		label var achats_net "Purchases before any policy"
		label var achats_avec_VAT "Purchases - All Subs. + Excises + VAT"
		
		destring hhid, replace
		if $devmode== 1 {
			save "${tempsim}/VAT_taxes.dta", replace
		}

		tempfile VAT_taxes
		save `VAT_taxes'				
********************************************************* ********************************************************* ***************************************************
*																			THE END
********************************************************* ********************************************************* ***************************************************	
