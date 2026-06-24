

***Test for SEN
/*
use  "$presim/07_dir_trans_PMT_1.dta", clear 
merge 1:1 hhid using "$presim/07_dir_trans_PMT_other.dta", nogen
gen s01q02 = 1
tempfile progs_hhheads
save `progs_hhheads'

foreach prog_indiv in 2 3 {
	use  "$presim/07_dir_trans_PMT_`prog_indiv'.dta", clear 
	sort hhid, stable
	by hhid: gen s01q00a = _n
	tempfile prog_indid
	save `prog_indid'
	merge 1:1 hhid s01q00a using "$presim/02_incomes_harmonized.dta", keep(1 2)
	sort hhid s01q00a, stable
	bys hhid _merge: gen orden = _n
	keep hhid _merge s01q00a orden
	mi unset, asis
	reshape wide s01q00a, i(hhid orden) j(_merge)
	rename s01q00a1 s01q00a
	merge 1:1 hhid s01q00a using `prog_indid', nogen
	replace s01q00a=s01q00a2 if s01q00a2!=.
	drop s01q00a2 orden
	merge 1:1 hhid s01q00a using "$presim/02_incomes_harmonized.dta", nogen keepusing(s01q02 hhweight hhsize /*all_incomes*/)
	tempfile prog_ind`prog_indiv'
	save `prog_ind`prog_indiv''
}
use `prog_ind2'
merge 1:1 hhid s01q00a using `prog_ind3', nogen
merge m:1 hhid s01q02 using `progs_hhheads', nogen

forval i=1/3{
	gen amount_`i' = .
}
gen departement_4 = 1 //departement_2
//label values departement_4 s00q01
gen eleg_4 = (s01q02==1)
gen pmt_seed_4 = pmt_seed_3*pmt_seed_2 if s01q02==1
rename am_prog_other amount_4
gen PMT = PMT_3
gen PMT_4 = PMT_3

order hhid s01q00a hhweight departement_1 eleg_1 PMT_1 pmt_seed_1 amount_1 departement_2 eleg_2 PMT_2 pmt_seed_2 amount_2 departement_3 eleg_3 PMT_3 pmt_seed_3 amount_3 departement_4 eleg_4 PMT_4 pmt_seed_4 amount_4

forval i=1/7{
	cap gen departement_`i' = 1
	cap gen eleg_`i' = 1
	cap gen PMT_`i' = PMT
	cap gen pmt_seed_`i' = runiform() if eleg_`i'==1
	cap gen amount_`i' = .
	rename departement_`i' segment_`i'
	rename pmt_seed_`i' random_`i'
	rename PMT_`i' progsort_`i'
}
*/


***Test for GNQ

use "$presim/Transfers_Targeting.dta", clear

cap rename interview__key hhid
cap rename ID_miembro indid

*Step 1: Bring parameters for each policy

forvalues i = 1/12 {
	rename segment_`i' segment
	merge m:1 segment using "$tempsim/params_Direct_transfers.dta", nogen keepusing(*P4_`i') keep(1 3)
	rename segment segment_`i'
}


*Step 2: Identify beneficiaries for each transfer program

forvalues i = 1/12 {
	dis `i'
	if "${P4_`i'_seedtype}"=="0" {
		sort segment_`i' eleg_`i' random_`i' hhid indid, stable		//Random assignment (ids included to ensure reproducibility)
	}
	if "${P4_`i'_seedtype}"=="1" {
		sort segment_`i' eleg_`i' PMT hhid indid, stable			//PMT assignment
	}
	if "${P4_`i'_seedtype}"=="2" {
		sort segment_`i' eleg_`i' progsort_`i' hhid indid, stable	//Program-specific seed propensity assignment
	}
	
	by segment_`i': gen pop_acum = sum(hhweight) if eleg_`i'==1
	by segment_`i': gen dist = abs(pop_acum-ben_targetP4_`i' ) if eleg_`i'==1
	by segment_`i': gen asig = (dist[_n]<dist[_n-1]) if eleg_`i'==1
	by segment_`i': gen orden = _n if eleg_`i'==1
	levelsof segment_`i', local(segs)
	foreach seg in `segs'{
		sum orden if segment_`i'==`seg'
		replace orden = orden+1-`r(min)' if segment_`i'==`seg'
		*replace asig = 0 if eleg_`i'==1 & dist[_n]<=dist[_n+1] & orden==1 & segment_`i'==`seg'
		replace asig = 0 if eleg_`i'==1 & dist[_n]>pop_acum[_n]/2 & orden==1 & asig[_n+1]==0 & segment_`i'==`seg'
	}
	
	rename asig asig_`i'
	drop pop_acum dist orden
}

*Step 3: Establish transfer amounts to beneficiaries

forvalues i = 1/12 {
	if "${P4_`i'_surveydata}"=="0"{
		gen am_prog_`i' = amountP4_`i'
		replace am_prog_`i'=0 if asig_`i'!=1
		recode am_prog_`i' (.=0)
	}
	if "${P4_`i'_surveydata}"=="1"{
		gen am_prog_`i' = amount_`i'
		replace am_prog_`i' = amountP4_`i' if am_prog_`i'==.
		replace am_prog_`i'=0 if asig_`i'!=1
		recode am_prog_`i' (.=0)
	}
	
	levelsof segment_`i', local(segs)
	local realbenefs=0
	foreach seg in `segs'{
		sum ben_targetP4_`i' if segment_`i'==`seg'
		local realbenefs=`realbenefs'+`r(max)'
	}
	
	sum hhweight if eleg_`i'==1
	local potential = r(sum)
	sum asig_`i' [iw=hhweight]
	nois dis as text "Excel requested " round(`realbenefs',1) " beneficiaries of program ${P4_`i'_label}, and we assigned " round(`r(sum)',1) " of the potential " round(`potential',1)
	if `potential'<=`r(sum)'{
		nois dis as error "Potential beneficiaries are less than total beneficiaries. Check if assigning every potential beneficiary makes sense."
	}
}

collapse (sum) am_prog_*, by(hhid)
forvalues i = 1/12 {
	label var am_prog_`i' "${P4_`i'_label}"
}




if $devmode== 1 {
    save "$tempsim/Direct_transfers.dta", replace
}
tempfile Direct_transfers
save `Direct_transfers'
























































