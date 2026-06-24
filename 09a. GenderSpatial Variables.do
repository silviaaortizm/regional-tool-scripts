**********************************************
* STEP 1: GENDERED INDICATOR VARIABLES
**********************************************

use  "$presim/02_incomes_harmonized.dta", replace

*Definición 1: Jefe de hogar

gen g_hhhead = (rel_hhhead==1 & female==1)

*Definición 2: Fuente de ingreso

gen inclab_f = (inclab_g)*female
gen inclab_m = (inclab_g)*(1-female)

gen inctot_f = (inctot_g)*female
gen inctot_m = (inctot_g)*(1-female)

*Definición 3: Composición demográfica

gen adults_m = (female==0 & age >=18 & age <=64)
gen adults_f = (female==1 & age >=18 & age <=64)
egen adults_total = rowtotal(adults_m adults_f)
gen children = (age <=14)
gen teens = (age >=15 & age <=17)
gen oldpersons = (age >=65)

*Collapse
cap rename hhsize hhsize_old
gen hhsize = 1
collapse (sum) hhsize g_hhhead inclab_m inclab_f inctot_m inctot_f adults_m adults_f adults_total children teens oldpersons, by(hhid)


*Definición 1: Jefe de hogar
recode g_hhhead (0=2)
label define g_hhhead 1 "1=female-headed" 2 "2=male-headed"
label values g_hhhead g_hhhead

*Definición 2: Fuente de ingreso
gen g_income = 1 if inclab_f>inclab_m
replace g_income = 2 if inclab_f<inclab_m
replace g_income = 1 if inctot_f>inctot_m & g_income==.
replace g_income = 2 if inctot_f<inctot_m & g_income==.
replace g_income = g_hhhead if g_income==. // Este supuesto es lo mejor porque queda un 2% de la encuesta con ingreso igual entre hombre y mujer, muy pocos, tiene sentido asumir el dato de jefatura para no tener que reportar resultados para tan pocos hogares
label define g_income 1 "1=female earns more" 2 "2=male earns more"
label values g_income g_income

*Definición 3: Composición demográfica
gen g_demog = 1 if adults_f==1 & adults_m==0 //mujer adulta sola
replace g_demog = 2 if adults_f==0 & adults_m==1 //hombre adulto solo
replace g_demog = 3 if adults_total>=2 //más de 1 adulto
replace g_demog = g_hhhead if g_demog==. //Si no hay adultos, entonces asumiremos que igual son hogares con un sólo responsable, y tomaremos a la persona que sea jefe del hogar
replace g_demog = g_demog + 3 if (children>0 | oldpersons>0) & hhsize>1 //Dependientes son menores de 15 años y mayores de 64 años. Solo pasa si la persona no vive sola, si vive sola no se considera dependiente de si misma.
replace g_demog = 3 if adults_total==0 & children==0 & teens==0 & oldpersons>1 //Si 2 o más adultos mayores viven solos, se considera hogara  multi-adult

label define g_demog 1 "1=female adult, no dependents" 2 "2=male adult, no dependents" 3 "3=multi-adult, no dependents" 4 "4=female adult with dependents" 5 "5=male adult with dependents" 6 "6=multi-adult with dependents"
label values g_demog g_demog
drop adults_total

/*foreach var in adults_m adults_f children teens oldpersons{
	gen t`var' = (`var'>0)
}*/

merge 1:1 hhid using "$presim/01_menages.dta", nogen keepusing(region rural)

keep hhid g_hhhead g_income g_demog region rural

tempfile GenderVariables
save `GenderVariables'

use "$data_out/output",  clear
merge 1:1 hhid using `GenderVariables', nogen
save "$data_out/output",  replace
if $save_scenario == 1 {	
	save "$data_out/output_${scenario_name_save}.dta", replace
}