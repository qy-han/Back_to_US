**** sibling correlation
	*qui count
	*local obs = r(N)
	
* demean edu
	*quietly sum edu_year
	*local var = r(Var)
	
	* calculate household size
	gen one = 1
	preserve
		collapse (sum) one, by(psu_nr hh_number)
		rename one hhsize
		tempfile hhsize
		save `hhsize', replace
	restore
	
	merge m:1 psu_nr hh_number using `hhsize', nogen
	
	drop if hhsize == 1
	qui sum edu_year
	local var = r(Var)
	local obs = r(N)
	gen demean_edu = edu_year - r(mean)
	
	* prepare temp data to use joinby function
	rename demean_edu demean_edu1
	*rename hh_number hh_number1
	rename hh_member hh_member1 
	rename age age1 
	
	tempfile sample1 
	save `sample1', replace
	
	rename demean_edu1 demean_edu2
	*rename hh_number1 hh_number2
	rename hh_member1 hh_member2 
	rename age1 age2 
	
	tempfile sample2
	save `sample2', replace
	
	* joinby: computes cross products of children in the same neighborhood
	use `sample1', clear
	joinby psu_nr hh_number using `sample2'
	gen prod = demean_edu1 * demean_edu2
	keep if (hh_member1 < hh_member2)
	
	* calculate hh-specific weight W_cf
	merge m:1 psu_nr hh_number using `hhsize', nogen
	gen hh_weight = sqrt(hhsize*(hhsize-1)/2) // W_cf 
	order psu_nr hh_number hh_member1 hh_member2 hh_weight demean_edu1 demean_edu2 
	drop if hhsize == 1
	collapse (sum) prod (min) hh_weight , by(psu_nr hh_number) // inner loop summation
	
	gen weighted_prod = prod/(hh_weight)^2
	
	preserve 
		collapse (sum) nr_weight = hh_weight, by(psu_nr) // calculate neighborhood weight W_c = Sum_(f) W_cf
		tempfile nr_weight
		save `nr_weight', replace
	restore
	
	collapse (mean) weighted_prod [iw=hh_weight], by(psu_nr) // middle loop summation
	
	merge 1:1 psu_nr using `nr_weight', nogen
	quietly sum weighted_prod [iw=nr_weight] // outer loop summation
	local sib_cov = r(mean)
	
	clear 
	set obs 1
	gen corr = `sib_cov'/`var'
	gen obs = `obs'
	
	di `var'
	di `sib_cov'
