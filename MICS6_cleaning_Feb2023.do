*Last Updated: 28 Feb 2023

******************************************************************************************
*1. Setup
******************************************************************************************

clear all
set more off
*File directory for umbrella data folder
gl masterfolder "/Users/J/Dropbox (Personal)/RISE-ThemeTeam 3.0/2-Products Tools Training/1-Learning Trajectories/MICS6/Data Work/Data"
*File directory for raw data
gl raw "/Users/J/Dropbox (Personal)/RISE-ThemeTeam 3.0/2-Products Tools Training/1-Learning Trajectories/MICS6/Data Work/Data/Raw"
*File directory for cleaned data
gl cleaned "/Users/J/Dropbox (Personal)/RISE-ThemeTeam 3.0/2-Products Tools Training/1-Learning Trajectories/MICS6/Data Work/Data/Cleaned"
*File directory to store dataset of means
gl means "/Users/J/Dropbox (Personal)/RISE-ThemeTeam 3.0/2-Products Tools Training/1-Learning Trajectories/MICS6/Data Work/Data/Means"
*File directory for intermediate data processing for attainment profiles
gl datafolder "/Users/J/Dropbox (Personal)/RISE-ThemeTeam 3.0/2-Products Tools Training/1-Learning Trajectories/MICS6/Data Work/Data/Attainmentprofiles"
*File directory to store final datasets
gl outputs "/Users/J/Dropbox (Personal)/RISE-ThemeTeam 3.0/2-Products Tools Training/1-Learning Trajectories/MICS6/Data Work/Data/Finaldatasets"
*Globals to call all cleaned country data files ("countryfiles") and all country names ("countrynames"). The lists between the two globals must be synced. 
gl countryfiles "clean_fs_bangladesh clean_fs_belarus clean_fs_CAR clean_fs_chad clean_fs_DRC clean_fs_ghana clean_fs_guineabissau clean_fs_kiribati clean_fs_mongolia clean_fs_nepal clean_fs_palestine clean_fs_punjab clean_fs_saotome_principe clean_fs_sierraleone clean_fs_sindh clean_fs_suriname clean_fs_thailand clean_fs_thegambia clean_fs_togo clean_fs_tunisia clean_fs_turks clean_fs_kosovo clean_fs_turkmenistan clean_fs_northmacedonia clean_fs_kyrgyzstan clean_fs_zimbabwe clean_fs_samoa clean_fs_tonga clean_fs_tuvalu clean_fs_lesotho clean_fs_madagascar clean_fs_vietnam	clean_fs_malawi clean_fs_kp clean_fs_balochistan" 
gl countrynames "Bangladesh 			Belarus 		CAR 			Chad 		DRC 			Ghana 		GuineaBissau 			Kiribati 		Mongolia 			Nepal 		Palestine 			Punjab			SaoTome 				  SierraLeone 			Sindh 			Suriname 		Thailand 			TheGambia 			Togo 		Tunisia 		Turks 			Kosovo 			Turkmenistan 		 NorthMacedonia			 Kyrgyzstan			Zimbabwe			Samoa		  Tonga			 Tuvalu			 Lesotho			Madagascar 			Vietnam			Malawi			KP		Balochistan"

*Create cleaned data files

cd "$raw"
local files : dir "$raw" files "*.dta"
foreach file in `files' {
use `file',clear
save "$cleaned/clean_`file'", replace
}

*Correct idiosyncratic coding in Sierra Leone (which needs to be done first before we can loop over all datasets in subsequent steps)
use "$cleaned/clean_fs_sierraleone",clear
*FL28 doesn't exist, and is instead named FL29
rename FL29 FL28
*FL19W* variables are coded as string, with "!" instead of missing
forvalues i = 1/72 {
replace FL19W`i' = "" if FL19W`i'=="!"
} 
destring FL19W*, replace
save "$cleaned/clean_fs_sierraleone", replace

*Correct idiosyncratic coding in Balochistan relating to lower vs. uppercase variable names
use "$cleaned/clean_fs_balochistan",clear
local uppervars fl* fs* hh* cb* hl*
rename `uppervars', upper
rename FSWEIGHT, lower
save "$cleaned/clean_fs_balochistan", replace

*Label key variables
cd "$cleaned"
local files : dir "$cleaned" files "*.dta"
foreach file in `files' {
use `file',clear
la var FS17 "Interview completed"
label define intlabel 1 "Completed" 2 "Not at home" 3 "Refused" 4 "Partially completed" 5 "Incapacitated" 6 "No adult consent"
label values FS17 intlabel
la var FL28 "Foundational skills interview with child completed"
label define FSlabel 1 "Completed" 2 "Not at home" 3 "Caretaker refused" 4 "Child Refused" 5 "Partly completed" 6 "Incapacitated"
label values FL28 FSlabel
la var FL10 "Child took reading test"
save "`file'", replace
}

******************************************************************************************
*2A. Begin creating variables to measure foundational reading by calculating the number of words read correctly in the story
******************************************************************************************

cd "$cleaned"
local files : dir "$cleaned" files "*.dta"
foreach file in `files' {
use `file',clear

*Create and label variables**
foreach var in target target1 target2 read_corr alit alnfe readskill {
gen `var'=0 if FL28==1
}
	la var target "total number of words read correctly"
	la var read_corr "read 90% of text correctly"
	la var alit "response to 3 literal questions correct"
	la var alnfe "response to 2 inferential questions correct"
	la var readskill "foundational literacy" 

save "`file'", replace
}	
*Create key variables for number of words in story read correctly per student and whether this met the threshold target set by UNICEF

/* 
We have 4 groups of countries: 
-Group A recorded the results of the reading test under a single variable.  We assume the story had the same number of words in all languages assessed.  Consistent coding.
-Groub B recorded the results of the reading test under a single variable, but the story length varied by language. Brute force coding idiosyncrasies.
-Group C recorded the results of the reading test under different variables, but each child only took the test once.  Brute force coding idiosyncrasies.
-Group D recorded the results of the reading test under different variables, and each child took the test twice. Brute force coding idiosyncrasies.
*/ 

***Group A 
*Loop through two parallel lists of country name and the number of words in the story (which varied per country). For explanation of syntax see: www.stata.com/support/faqs/programming/looping-over-parallel-lists/#:~:text=You%20can%20loop%20over%20parallel,be%20dog%20and%20woof%2C%20etc.   
cd "$cleaned"
local country 	bangladesh belarus CAR chad DRC ghana guineabissau kiribati mongolia nepal palestine punjab saotome_principe sierraleone sindh suriname thailand thegambia togo tunisia turks vietnam kp balochistan
local wordcount 72 		   72 	   87  81   85  69    69		   78  	 	67 		 72 	76 		 72 	   76 				72 		  72	79 		 72 	  72 	 	81 	 72		 73	  72	  72 72
local n: word count `country'
forvalues i = 1/`n' {
  local a : word `i' of `country'
  local b : word `i' of `wordcount'

use clean_fs_`a', clear
*Each FL19W* variable represents a word in the story, and whether it was read correctly. FL19W* are coded 0,1,2. 0=correct, 1=incorrect, 2=did not attempt.
foreach num of numlist 1/`b' {
replace target=target+1 if FL19W`num'==0
}

*UNICEF set the threshold for success on the reading exercise as reading 90% of the words in the story correctly.
replace read_corr=1 if target>=(`b'*.9)&target!=.
save clean_fs_`a', replace  
}

***Group B: Kyrgyzstan
*Kyrgyzstan
use clean_fs_kyrgyzstan, clear
*Kyrgyz
foreach num of numlist 1/59 {
replace target = target+1 if FL19W`num'==0 & FL9==1 | (FL7==1 & CB4==2)
}
*Russian
foreach num of numlist 1/71 {
replace target = target+1 if FL19W`num'==0 & FL9==2 | (FL7==2 & CB4==2)
}
*Uzbek
foreach num of numlist 1/72 {
replace target = target+1 if FL19W`num'==0 & FL9==3 | (FL7==3 & CB4==2)
}
replace read_corr=1 if target>=(59*.9)& FL9==1 &target!=.
replace read_corr=1 if target>=(71*.9)& FL9==2 &target!=.
replace read_corr=1 if target>=(72*.9)& FL9==3 &target!=.
save clean_fs_kyrgyzstan, replace 

***Group C: kosovo turkmenistan northmacedonia malawi

*Kosovo
use clean_fs_kosovo, clear
*Albanian
foreach num of numlist 1/78 {
replace target = target+1 if FL19WA`num'==0
}
*Serbian
foreach num of numlist 1/72 {
replace target = target+1 if FL19WS`num'==0
}
*Turkish
foreach num of numlist 1/53 {
replace target = target+1 if FL19WT`num'==0
}
*Bosnian
foreach num of numlist 1/72 {
replace target = target+1 if FL19WB`num'==0
}
replace read_corr=1 if target>=(78*.9)& FL19WA1!=.&target!=.
replace read_corr=1 if target>=(72*.9)&FL19WS1!=.&target!=.
replace read_corr=1 if target>=(53*.9)&FL19WT1!=.&target!=.
replace read_corr=1 if target>=(72*.9)&FL19WB1!=.&target!=.
save clean_fs_kosovo, replace  

*Turkmenistan
use clean_fs_turkmenistan, clear
*Turkmen
foreach num of numlist 1/69 {
replace target = target+1 if FL19W`num'==0
}
*Russian
foreach num of numlist 1/60 {
replace target = target+1 if FL19WA`num'==0
}
replace read_corr=1 if target>=(69*.9)& FL19W1!=. &target!=.
replace read_corr=1 if target>=(60*.9)& FL19WA1!=.&target!=.
save clean_fs_turkmenistan, replace  

*North Macedonia
use clean_fs_northmacedonia, clear
*Macedonian
foreach num of numlist 1/69 {
replace target = target+1 if FL19W`num'==0 & FL9==1 | (FL7==1 & CB4==2)
}
*Albanian
foreach num of numlist 1/77 {
replace target = target+1 if FL19WA`num'==0 & FL9==2 | (FL7==2 & CB4==2)
}
replace read_corr=1 if target>=(69*.9)& FL9==1 &target!=.
replace read_corr=1 if target>=(77*.9)& FL9==2 &target!=.
save clean_fs_northmacedonia, replace  
 
*Malawi
use clean_fs_malawi, clear
*English
foreach num of numlist 1/61 {
replace target = target+1 if FL19W`num'==0
}
*Chichewa
foreach num of numlist 1/74 {
replace target = target+1 if FLB19W`num'==0
}
replace read_corr=1 if target>=(61*.9)& FL19W1!=. &target!=.
replace read_corr=1 if target>=(74*.9)& FLB19W1!=.&target!=.
save clean_fs_malawi, replace  

***Group D: zimbabwe samoa tonga tuvalu lesotho madagascar

*Zimbabwe (modelled on code from UNICEF)
use clean_fs_zimbabwe, clear

*a) Language of test (English=1, Shona=2, Ndebele=3)
*Those who never attended school, for whom the test wasn't available in the language spoken at home, selected one of the available languages
gen test=FL10C if FL10C<=3
*Attending or attended school, language used at school
replace test=FL9 if test==.&FL9<=3
*Never attended school, language used at home
replace test=FL7 if test==.&FL7<=3

*b) Generate the number of correct words per language of the test
foreach num of numlist 1/72 {
replace target1 = target1+1 if FL19W`num'==0 & test==1
}
foreach num of numlist 1/46 {
replace target1 = target1+1 if FL19W`num'==0 & test==2
}
foreach num of numlist 1/50 {
replace target1 = target1+1 if FL19W`num'==0 & test==3
}

foreach num of numlist 1/62 {
replace target2 = target2+1 if FL21W`num'==0 & FL21D==1
}
foreach num of numlist 1/41 {
replace target2 = target2+1 if FL21W`num'==0 & FL21D==2
}
foreach num of numlist 1/38 {
replace target2 = target2+1 if FL21W`num'==0 & FL21D==3
}

*c) Calculate if reading target was reached
replace read_corr=1 if target1>=(72*.9) & target1!=. & test==1
replace read_corr=1 if target1>=(46*.9) & target1!=. & test==2
replace read_corr=1 if target1>=(50*.9) & target1!=. & test==3
replace read_corr=1 if target2>=(62*.9) & target2!=. & FL21D==1
replace read_corr=1 if target2>=(41*.9) & target2!=.& FL21D==2
replace read_corr=1 if target2>=(38*.9) & target2!=. & FL21D==3
save clean_fs_zimbabwe, replace  

* Step (a) above from Zimbabwe for Samoa, Tonga, Tuvalu 
foreach file in clean_fs_samoa clean_fs_tonga clean_fs_tuvalu {
use `file',clear
gen test=FL10C if FL10C<=2
replace test=FL9 if test==.&FL9<=2
replace test=FL7 if test==.&FL7<=2
save "`file'", replace
}

*Samoa
use clean_fs_samoa, clear
*b) Generate the number of correct words per language of the test
foreach num of numlist 1/72 {
replace target1 = target1+1 if FL19W`num'==0 & test==1
}
foreach num of numlist 1/76 {
replace target1 = target1+1 if FL19W`num'==0 & test==2
}
foreach num of numlist 1/62 {
replace target2 = target2+1 if FL21OW`num'==0 & FL21D==11
}
foreach num of numlist 1/66 {
replace target2 = target2+1 if FL21OW`num'==0 & FL21D==12
}
*c) Calculate if reading target was reached
replace read_corr=1 if target1>=(72*.9) & target1!=. & test==1
replace read_corr=1 if target1>=(76*.9) & target1!=. & test==2
replace read_corr=1 if target2>=(62*.9) & target2!=. & FL21D==11
replace read_corr=1 if target2>=(66*.9) & target2!=.& FL21D==12
save clean_fs_samoa, replace  

*Tonga
use clean_fs_tonga, clear
*b) Generate the number of correct words per language of the test
foreach num of numlist 1/72 {
replace target1 = target1+1 if FL19W`num'==0 & test==1
}
foreach num of numlist 1/72 {
replace target1 = target1+1 if FL19W`num'==0 & test==2
}
foreach num of numlist 1/62 {
replace target2 = target2+1 if FL21OW`num'==0 & FL21D==11
}
foreach num of numlist 1/62 {
replace target2 = target2+1 if FL21OW`num'==0 & FL21D==12
}
*c) Calculate if reading target was reached
replace read_corr=1 if target1>=(72*.9) & target1!=. & test==1
replace read_corr=1 if target1>=(72*.9) & target1!=. & test==2
replace read_corr=1 if target2>=(62*.9) & target2!=. & FL21D==11
replace read_corr=1 if target2>=(62*.9) & target2!=.& FL21D==12
save clean_fs_tonga, replace  

*Tuvalu
use clean_fs_tuvalu, clear
*b) Generate the number of correct words per language of the test
foreach num of numlist 1/72 {
replace target1 = target1+1 if FL19W`num'==0 & test==1
}
foreach num of numlist 1/96 {
replace target1 = target1+1 if FL19W`num'==0 & test==2
}
foreach num of numlist 1/62 {
replace target2 = target2+1 if FL21W`num'==0 & FL21D==11
}
foreach num of numlist 1/86 {
replace target2 = target2+1 if FL21W`num'==0 & FL21D==12
}
*c) Calculate if reading target was reached
replace read_corr=1 if target1>=(72*.9) & target1!=. & test==1
replace read_corr=1 if target1>=(96*.9) & target1!=. & test==2
replace read_corr=1 if target2>=(62*.9) & target2!=. & FL21D==11
replace read_corr=1 if target2>=(86*.9) & target2!=.& FL21D==12
save clean_fs_tuvalu, replace 

*Lesotho
use clean_fs_lesotho, clear
*a)
*If attending or attended school, language used at school
gen test=FL9 if FL9<=2
*If never attended school, language used at home
replace test=FL7 if test==.&FL7<=2

*b) Generate the number of correct words per language of the test
foreach num of numlist 1/64 {
replace target1 = target1+1 if FL19W`num'==0 & test==1
}
foreach num of numlist 1/71 {
replace target1 = target1+1 if FL19WS`num'==0 & test==2
}
foreach num of numlist 1/64 {
replace target2 = target2+1 if FL119W`num'==0 & FL100==2
}
foreach num of numlist 1/71 {
replace target2 = target2+1 if FL219W`num'==0 & FL100==1
}
*c) Calculate if reading target was reached
replace read_corr=1 if target1>=(64*.9) & target1!=. & test==1
replace read_corr=1 if target1>=(71*.9) & target1!=. & test==2
replace read_corr=1 if target2>=(64*.9) & target2!=. & FL100==2
replace read_corr=1 if target2>=(71*.9) & target2!=.& FL100==1
save clean_fs_lesotho, replace 

*Madagascar
use clean_fs_madagascar, clear
*a)
*If attending or attended school, language used at school
gen test=FL9 if FL9<=2
*If never attended school, language used at home
replace test=FL7 if test==.&FL7<=2

*b) Generate the number of correct words per language of the test
foreach num of numlist 1/84 {
replace target1 = target1+1 if FL19W`num'==0 & test==1
}
foreach num of numlist 1/64 {
replace target1 = target1+1 if FL19WS`num'==0 & test==2
}
foreach num of numlist 1/84 {
replace target2 = target2+1 if FL119W`num'==0 & FL100==2
}
foreach num of numlist 1/64 {
replace target2 = target2+1 if FL219W`num'==0 & FL100==1
}
*c) Calculate if reading target was reached
replace read_corr=1 if target1>=(84*.9) & target1!=. & test==1
replace read_corr=1 if target1>=(64*.9) & target1!=. & test==2
replace read_corr=1 if target2>=(84*.9) & target2!=. & FL100==2
replace read_corr=1 if target2>=(64*.9) & target2!=.& FL100==1
save clean_fs_madagascar, replace 

******************************************************************************************
*2B. Finish creating all variables to measure foundational reading skills
******************************************************************************************

***Continue looping over each country dataset to finish creating literacy variables

*One set of variables for Groups A,B, and C
local files : dir "$cleaned" files "*.dta"
foreach file in clean_fs_bangladesh clean_fs_belarus clean_fs_CAR clean_fs_chad clean_fs_DRC clean_fs_ghana clean_fs_guineabissau clean_fs_kiribati clean_fs_mongolia clean_fs_nepal clean_fs_palestine clean_fs_punjab clean_fs_saotome_principe clean_fs_sierraleone clean_fs_sindh clean_fs_suriname clean_fs_thailand clean_fs_thegambia clean_fs_togo clean_fs_tunisia clean_fs_turks clean_fs_vietnam clean_fs_kosovo clean_fs_turkmenistan clean_fs_northmacedonia clean_fs_kyrgyzstan clean_fs_kp clean_fs_balochistan {
use `file',clear
*These variables correspond to the 3 literal questions about the story
replace alit=1 if FL22A==1&FL22B==1&FL22C==1
*These variables correspond to the 2 inferential questions about the story
replace alnfe=1 if FL22D==1&FL22E==1
*Passing the foundational reading skills threshold required mastery (>90 percent) of words in the story pronounced correctly, and correct answers to all 5 questions about the story
replace readskill=1 if alit==1&read_corr==1&alnfe==1
save "`file'", replace
}

*Malawi was an exception and recorded the questions asked about the story in two different sets of variables (depending on the language)
local files : dir "$cleaned" files "*.dta"
foreach file in clean_fs_malawi {
use `file',clear
*Literal questions all languages
replace alit=1 if (FL22A==1&FL22B==1&FL22C==1)|(FLB22A==1&FLB22B==1&FLB22C==1)
*Inferential questions all languages
replace alnfe=1 if (FL22D==1&FL22E==1)|(FLB22D==1&FLB22E==1)
*Calculate if passed foundational reading skills threshold
replace readskill=1 if alit==1&read_corr==1&alnfe==1
save "`file'", replace
}

*4 countries in Group D recorded the questions asked about the story in the same set of variable names
local files : dir "$cleaned" files "*.dta"
foreach file in clean_fs_zimbabwe clean_fs_samoa clean_fs_tonga clean_fs_tuvalu {
use `file',clear
*Literal questions all languages
replace alit=1 if (FL21BA==1 & FL21BB==1 &FL21BC==1)|(FL22A==1 & FL22B==1 & FL22C==1)
*Inferential questions all languages
replace alnfe=1 if (FL21BE==1 & FL21BF==1)|(FL22E==1 & FL22F==1)
*Calculate if passed foundational reading skills threshold
replace readskill=1 if alit==1&read_corr==1&alnfe==1
save "`file'", replace
}

*2 countries in Group D used a different set of variables (one set for the first assessment, another for the second assessment in one language, another for the second assessment in another language)
local files : dir "$cleaned" files "*.dta"
foreach file in clean_fs_lesotho clean_fs_madagascar {
use `file',clear
*Literal questions all languages
replace alit=1 if (FL22A==1&FL22B==1&FL22C==1)|(FL122A==1&FL122B==1&FL122C==1)|(FL222A==1&FL222B==1&FL222C==1)
*Inferential questions all languages
replace alnfe=1 if (FL22D==1&FL22E==1)|(FL122D==1&FL122E==1)|(FL222D==1&FL222E==1)
*Calculate if passed foundational reading skills threshold
replace readskill=1 if alit==1&read_corr==1&alnfe==1
save "`file'", replace
}

******************************************************************************************
*3. Creating variables to measure foundational numeracy
******************************************************************************************

*Preliminary cleaning of KYRGYZSTAN dataset (they coded the answers to the questions, rather than whethers the answers were right or wrong). Correct answers follow the survey on pp.451-3 in the Kyrgyzstan MICS6 Report

use clean_fs_kyrgyzstan, clear 

*FL24*
foreach i in A B C D E {
replace FL24`i'="" if FL24`i'=="0"
replace FL24`i'="3" if FL24`i'=="Z"
destring FL24`i', replace
}

replace FL24A=1 if FL24A==7 
replace FL24A=2 if FL24A==5

replace FL24B=1 if FL24B==24
replace FL24B=2 if FL24B==11

replace FL24C=1 if FL24C==58
replace FL24C=2 if FL24C==49

replace FL24D=1 if FL24D==67
replace FL24D=2 if FL24D==65

replace FL24E=1 if FL24E==154
replace FL24E=2 if FL24E==146

*FL25*
replace FL25A=2 if FL25A!=5 & FL25A!=.
replace FL25A=1 if FL25A==5

replace FL25B=2 if FL25B!=14 & FL25A!=.
replace FL25B=1 if FL25B==14

replace FL25C=2 if FL25C!=10 & FL25A!=.
replace FL25C=1 if FL25C==10

replace FL25D=2 if FL25D!=19 & FL25A!=.
replace FL25D=1 if FL25D==19

replace FL25E=2 if FL25E!=36 & FL25A!=.
replace FL25E=1 if FL25E==36

*FL27*
replace FL27A=2 if FL27A!=8 & FL27A!=.
replace FL27A=1 if FL27A==8

replace FL27B=2 if FL27B!=16& FL27A!=.
replace FL27B=1 if FL27B==16

replace FL27C=2 if FL27C!=30& FL27A!=.
replace FL27C=1 if FL27C==30

replace FL27D=2 if FL27D!=8& FL27A!=.
replace FL27D=1 if FL27D==8

replace FL27E=2 if FL27E!=14& FL27A!=.
replace FL27E=1 if FL27E==14

save clean_fs_kyrgyzstan, replace

*Create and label variables, also label correct/incorrect/no attempt	
local files : dir "$cleaned" files "*.dta"
foreach file in `files' {
use `file', clear

foreach var in target_num number_read target_dis number_dis target_add number_add target_patt number_patt numbskill {
gen `var'=0 if FL28==1
}
	la var target_num "how many of 6 number ID tasks correct" 
	la var number_read "all numbers identified correctly"
	la var target_dis "how many of 5 number discrimination tasks correct"
	la var number_dis "all number discrimination tasks correct"
	la var target_add "how many of 5 addition tasks correct"
	la var number_add "response all addition tasks correct"
	la var target_patt "how many of 5 number pattern tasks correct"
	la var number_patt "reponse all number pattern tasks correct"
	la var numbskill "foundational numeracy" 
	label define numlabel 1 "Correct" 2 "Incorrect" 3 "No attempt"
	label values FL23A FL23B FL23C FL23D FL23E FL23F FL24A FL24B FL24C FL24D FL24E FL25A FL25B FL25C FL25D FL25E FL27A FL27B FL27C FL27D FL27E numlabel

**For number_read: First figure out whether number reading target was met or not. To do this, replace value for target_num base on correctly reading numbers. FL23A-F==1 represents correctly reading a number.
foreach var in FL23A FL23B FL23C FL23D FL23E FL23F {
replace target_num=target_num+1 if `var'==1
}

*A child has mastery of this sub-skill if all questions were correct
replace number_read=1 if FL23A==1&FL23B==1&FL23C==1&FL23D==1&FL23E==1&FL23F==1

*For number_dis: replace values if all number discrimination questions were correct. FL24A-E==1 means all correct*
foreach var in FL24A FL24B FL24C FL24D FL24E {
replace target_dis=target_dis+1 if `var'==1
}
*A child has mastery of this sub-skill if all questions were correct
replace number_dis=1 if FL24A==1&FL24B==1&FL24C==1&FL24D==1&FL24E==1

*for number_add: replace values if number addition questions were correct. FL25A-E==1 means correct*
foreach var in FL25A FL25B FL25C FL25D FL25E {
replace target_add=target_add+1 if `var'==1
}
*A child has mastery of this sub-skill if all questions were correct
replace number_add=1 if FL25A==1&FL25B==1&FL25C==1&FL25D==1&FL25E==1

*for each number_patt: replace values if number pattern questions were answered correctly. FL27A-E==1 means correct* 
foreach var in FL27A FL27B FL27C FL27D FL27E {
replace target_patt=target_patt+1 if `var'==1
}
*A child has mastery of this sub-skill if all questions were correct
replace number_patt=1 if FL27A==1&FL27B==1&FL27C==1&FL27D==1&FL27E==1

*Children pass the threshold for mastery of foundational numeracy only if all questions on all subskills were answered correctly
replace numbskill=1 if number_read==1&number_dis==1&number_add==1&number_patt==1

save "`file'", replace
}

*SierraLeone dropped FL27D&E due to a systematic data entry error.  This error affected multiple countries (see MICS6 reports), but in communication with UNICEF this was the only known country that dropped these questions to response to the error.   
use clean_fs_sierraleone, clear
replace number_patt=0 if FL28==1
replace number_patt=1 if FL27A==1&FL27B==1&FL27C==1

replace numbskill=0 if FL28==1
replace numbskill=1 if number_read==1&number_dis==1&number_add==1&number_patt==1
save clean_fs_sierraleone, replace

*The age conditions ensure we're just looking at children in the 7-14 sampling frame - some interviews were (mistakenly) completed with other ages 
cd "$cleaned"
local files : dir "$cleaned" files "*.dta"
foreach file in `files' {
use `file',clear
foreach var in read_corr alit alnfe readskill number_read number_dis number_add number_patt numbskill {
replace `var'=. if CB3>14 | CB3<7
}
save "`file'", replace
}

******************************************************************************************
*4. Creating variables for Age and Grade
******************************************************************************************

*Cleaning DRC
use clean_fs_DRC, clear
rename fsSchage schage
save clean_fs_DRC, replace

*Labelling age variable -- could use either age (CB3) or schage variable.  UNICEF argues that schage - age at the start of the school year - is a better variable to use to account for timing differences in survey completion and start of school year across countries
local files : dir "$cleaned" files "*.dta"
foreach file in `files' {
use `file', clear
la var schage "Age at start of school year"

*Label grade-related variables**
la var CB4 "Ever attend school including ECE"
la var CB5B "Highest grade within level attended"
la var CB6 "Completed highest grade attended"
la var CB7 "Attend school current school year"
save "`file'", replace
}

/*
*Optional code to seperately label CB5A, the highest level of school attended, because Nepal did not have it as a variable. You will have to add the new country names to this list.
foreach country in bangladesh belarus CAR chad DRC ghana guineabissau kiribati mongolia palestine punjab saotome_principe sierraleone sindh suriname thailand thegambia togo tunisia turks kosovo turkmenistan northmacedonia kyrgyzstan zimbabwe samoa tonga tuvalu lesotho madagascar {
use clean_fs_`country', clear
la var CB5A "highest level school attended"
save "clean_fs_`country'", replace
*/

*Create a variable for highest grade attended -- one country at a time due to inconsistent coding across countries

*Bangladesh*
local country bangladesh
use clean_fs_`country', clear
tab CB5A CB5B

/*
  highest |
     level |
    school |                                                            Highest grade within level attended
  attended |         1          2          3          4          5          6          7          8          9         10         11         12         13         14 |     Total
-----------+----------------------------------------------------------------------------------------------------------------------------------------------------------+----------
         1 |     3,613      3,757      3,870      3,414      3,810          0          0          0          0          0          0          0          0          0 |    18,464 
         2 |         0          0          0          0          0      3,039      2,849      3,284          0          0          0          0          0          0 |     9,172 
         3 |         0          0          0          0          0          0          0          0      2,424      3,431        607        410          0          0 |     6,872 
         4 |         0          0          0          0          0          0          0          0          0          0          0          0         16          5 |        21 
         9 |         0          0          0          0          0          0          0          1          0          0          0          0          0          0 |         1 
-----------+----------------------------------------------------------------------------------------------------------------------------------------------------------+----------
     Total |     3,613      3,757      3,870      3,414      3,810      3,039      2,849      3,285      2,424      3,431        607        410         16          5 |    34,530 

*/
gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A>=1 & grade!=-1
save clean_fs_`country', replace


*CAR*
local country CAR
use clean_fs_`country', clear
tab CB5A CB5B
/* CAR Tab Results
highest |
     level |
    school |                     Highest grade within level attended
  attended |         1          2          3          4          5          6         99 |     Total
-----------+-----------------------------------------------------------------------------+----------
         1 |       972        906        857        552        400        345          1 |     4,033 
         2 |       191        106         46         32          0          0          0 |       375 
         3 |        17          5          2          0          0          0          0 |        24 
-----------+-----------------------------------------------------------------------------+----------
     Total |     1,180      1,017        905        584        400        345          1 |     4,432 
*/	 
gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B+6 if CB5A==2
replace grade=CB5B+10 if CB5A==3
save clean_fs_`country', replace


*Chad*
local country chad
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==10
replace grade=CB5B+6 if CB5A==20 | CB5A==21
replace grade=CB5B+10 if CB5A==30 | CB5A==31
save clean_fs_`country', replace


*DRC*
local country DRC
use clean_fs_`country', clear
tab CB5A CB5B
/* DRC Tab Results*

   highest |
     level |
    school |                Highest grade within level attended
  attended |         1          2          3          4          5          6 |     Total
-----------+------------------------------------------------------------------+----------
        10 |     2,078      1,573      1,402      1,203      1,064        938 |     8,258 
        20 |       701        540          0          0          0          0 |     1,241 
        31 |       257        153         75         45          0          0 |       530 
        32 |        86         55         40         16          0          0 |       197 
        33 |         5          5          3          0          0          0 |        13 
        34 |         5          3          0          0          0          0 |         8 
        40 |         3          0          0          0          0          0 |         3 
-----------+------------------------------------------------------------------+----------
     Total |     3,135      2,329      1,520      1,264      1,064        938 |    10,250 
PRESCHOOL 0
PRIMARY 10
SECONDARY 1 20
SECONDARY 2 GENERAL 31
SECONDARY 2 TECHNIQUE 32
SECONDARY 2 PROFESSIONAL 33
SECONDARY 2 ART & TRADE 34
SUPERIOR 40
 */
gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==10
replace grade=CB5B+6 if CB5A==20
replace grade=CB5B+8 if CB5A==31 | CB5A==32 | CB5A==33 | CB5A==34
replace grade=CB5B+12 if CB5A==40
save clean_fs_`country', replace


*Ghana*
local country ghana
use clean_fs_`country', clear
tab CB5A CB5B

*Never attended any school
gen grade=-1 if CB4==2
*ECE only*
replace grade=0 if CB5A==0
*Primary*
replace grade=CB5B if CB5A==1
*Junior secondary/middle*
replace grade=CB5B+6 if CB5A==3
*Senior secondary*
replace grade=CB5B+9 if CB5A==5
*Tertiary*
replace grade=CB5B+13 if CB5A==6
save clean_fs_`country', replace


*GuineaBissau*
local country guineabissau
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B+9 if CB5A==2
replace grade=CB5B+12 if CB5A==5
save clean_fs_`country', replace


*Kiribati*
local country kiribati
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B+6 if CB5A==2
replace grade=CB5B+6 if CB5A==3
save clean_fs_`country', replace

*Kosovo*
local country kosovo
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5B==0
replace grade=CB5B if CB5A>=1 & grade!=-1
save clean_fs_`country', replace

*Kyrgyzstan*
local country kyrgyzstan
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1 | CB5A==2 | CB5A==3 
replace grade=CB5B+9 if CB5A==4
replace grade=CB5B+11 if CB5A==5
save clean_fs_`country', replace

*Lesotho*
local country lesotho
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B+7 if CB5A==2 
replace grade=CB5B+12 if CB5A==3 | CB5A==4
save clean_fs_`country', replace

*Madagascar*
local country madagascar
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B+5 if CB5A==2
replace grade=CB5B+9 if CB5A==3
replace grade=CB5B+12 if CB5A==4
save clean_fs_`country', replace


*Mongolia*
local country mongolia
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B+9 if CB5A==3
replace grade=CB5B+12 if CB5A==4
save clean_fs_`country', replace


*Nepal*
local country nepal
use clean_fs_`country', clear
tab CB5B

gen grade=-1 if CB4==2
replace grade=CB5B if CB4!=2
save clean_fs_`country', replace


*NorthMacedonia*
local country northmacedonia
use clean_fs_`country', clear
tab CB5A CB5B
/*NorthMacedonia Tab Results*

 highest |
     level |
    school |                                Highest grade within level attended
  attended |         1          2          3          4          5          6          7          8          9 |     Total
-----------+---------------------------------------------------------------------------------------------------+----------
         1 |       160        131        137        107        103          0          0          0          0 |       638 
         2 |         0          0          0          0          0         95         81         78         92 |       346 
         3 |         6          3          2          0          0          0          0          0          0 |        11 
         4 |        91         74         72         21          0          0          0          0          0 |       258 
-----------+---------------------------------------------------------------------------------------------------+----------
     Total |       257        208        211        128        103         95         81         78         92 |     1,253 


Primary (1-5) = 1
Primary (6 - 9) = 2
Occupational Seconary (3 years) = 3
Secondary (4 years) = 4
*/
gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B if CB5A==2
replace grade=CB5B+9 if CB5A==3 | CB5A==4
save clean_fs_`country', replace


*Palestine*
local country palestine
use clean_fs_`country', clear
tab CB5B CB5A

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B+10 if CB5A==2
replace grade=CB5B+12 if CB5A==3
save clean_fs_`country', replace


*Punjab*
local country punjab
use clean_fs_`country', clear
tab CB5B CB5A

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1 & CB5B<6
replace grade=CB5B+5 if CB5A==2 & CB5B<4
replace grade=CB5B+8 if CB5A==3 & CB5B<3
replace grade=CB5B+10 if CB5A==4
save clean_fs_`country', replace


*SaoTomePrincipe*
local country saotome_principe
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B+6 if CB5A==2
save clean_fs_`country', replace	 


*SierraLeone*
local country sierraleone
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B+6 if CB5A==2
replace grade=CB5B+9 if CB5A==3
save clean_fs_`country', replace


*Suriname*
local country suriname
use clean_fs_`country', clear
tab CB5B CB5A

gen grade=-1 if CB4==2
replace grade=0 if CB5A==1 & CB5B<3
replace grade=CB5B-2 if CB5A==2 & CB5B<9
replace grade=CB5B+6 if CB5A==3 & CB5B<5
replace grade=CB5B+10 if CB5A==4 & CB5B<3
save clean_fs_`country', replace

	 
*Thailand*
local country thailand
use clean_fs_`country', clear
tab CB5B CB5A

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1 & CB5B<7
replace grade=CB5B+6 if CB5A==2 & CB5B<4
replace grade=CB5B+6 if CB5A==3 & CB5B<5
save clean_fs_`country', replace


*TheGambia*
local country thegambia
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B+6 if CB5A==2
replace grade=CB5B+9 if CB5A==3
save clean_fs_`country', replace


*Togo*
local country togo
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B+6 if CB5A==2
replace grade=CB5B+10 if CB5A==3
save clean_fs_`country', replace


*Tonga*
local country tonga
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B+6 if CB5A==2 | CB5A==3
replace grade=CB5B+10 if CB5A==4
replace grade=CB5B+13 if CB5A==5
save clean_fs_`country', replace


*Tunisia*
local country tunisia
use clean_fs_`country', clear
tab CB5B CB5A

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B if CB5A==2
replace grade=CB5B+9 if CB5A==3
save clean_fs_`country', replace


*Turkmenistan*
local country turkmenistan
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B+11 if CB5A==2 | CB5A==4
save clean_fs_`country', replace

	 
*Zimbabwe*
local country zimbabwe
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B+7 if CB5A==3
replace grade=CB5B+11 if CB5A==4
replace grade=CB5B+13 if CB5A==5 | CB5A==7
save clean_fs_`country', replace

*Belarus*
local country belarus
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B if CB5A==2
replace grade=CB5B if CB5A==3
replace grade=CB5B+9 if CB5A==4 | CB5A==5
replace grade=CB5B+11 if CB5A==6
save clean_fs_`country', replace

*Sindh*
local country sindh
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B+5 if CB5A==2
replace grade=CB5B+8 if CB5A==3
replace grade=CB5B+10 if CB5A==4
save clean_fs_`country', replace

*Samoa*
local country samoa
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1 | CB5A==2
replace grade=CB5B+13 if CB5A==4
save clean_fs_`country', replace

*Turks*
local country turks
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==11
replace grade=CB5B+6 if CB5A==12
replace grade=CB5B+9 if CB5A==13
replace grade=CB5B+11 if CB5A==15
save clean_fs_`country', replace

*Tuvalu*
local country tuvalu
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1 | CB5A==2
save clean_fs_`country', replace

*Vietnam*
local country vietnam
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1 | CB5A==2 | CB5A==3
save clean_fs_`country', replace

*KP - Pakistan
local country kp
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B+5 if CB5A==2
replace grade=CB5B+8 if CB5A==3
replace grade=CB5B+10 if CB5A==4
save clean_fs_`country', replace

*Malawi
local country malawi
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B+8 if CB5A==2
replace grade=CB5B+8 if CB5A==3
save clean_fs_`country', replace

*Balochistan
local country balochistan
use clean_fs_`country', clear
tab CB5A CB5B

gen grade=-1 if CB4==2
replace grade=0 if CB5A==0
replace grade=CB5B if CB5A==1
replace grade=CB5B+5 if CB5A==2
replace grade=CB5B+8 if CB5A==3
replace grade=CB5B+10 if CB5A==4
save clean_fs_`country', replace

*Labelling highest grade attended variable over each country dataset*
local files : dir "$cleaned" files "*.dta"
foreach file in `files' {
use `file', clear
label define gradelabel -1 "No school" 0 "ECE" 1 "Grade 1" 2 "Grade 2" 3 "Grade 3" 4 "Grade 4" 5 "Grade 5" 6 "Grade 6" 7 "Grade 7" 8 "Grade 8" 9 "Grade 9" 10 "Grade 10" 11 "Grade 11" 12 "Grade 12"
label values grade gradelabel

*Dummy variable for kids who have never been to school*
gen noschool=1 if CB4==2 & FL28==1
replace noschool=0 if CB4==1 & FL28==1
*Dummy variable for kids in school at the time of the survey*
gen inschool=1 if CB7==1 & FL28==1
replace inschool=0 if inschool!=1 & FL28==1
save "`file'", replace
}

******************************************************************************************
*5. Creating datasets of country learning profiles, by age and grade 
******************************************************************************************
/*The loop below creates 2 datasets of means (by grade and age) that contains the following variables for each of the available countries: 
-Overall numeracy skills (following UNICEF's definition), disaggregated by 3 subgroups (male vs. female; top quintile by wealth vs. bottom quintile of wealth; urban vs. rural) and for in-school children.  The unweighted sample size used to estimate the mean for each subgroup is also calculated.  
-Overall reading skills (following UNICEF's definition), disaggregated by the same subgroups.  The unweighted sample size used to estimate the mean for each subgroup is also calculated.
*/

*NUMERACY
cd "$cleaned"

*Create the 2 new datasets, so that we can then loop over them
use clean_fs_bangladesh,clear
preserve
collapse (mean) numbskill [pw=fsweight], by (grade)
rename numbskill num_all_Bangladesh
save "$means/grade", replace
restore 

preserve
collapse (mean) numbskill [pw=fsweight], by (schage)
rename numbskill num_all_Bangladesh
save "$means/schage", replace
restore 

foreach x in grade schage {

local n : word count $countryfiles
forvalues i = 1/`n' {
	local a : word `i' of $countryfiles
	local b : word `i' of $countrynames
use `a', clear

*Average numeracy (by highest grade attended and age)*
preserve
collapse (mean) numbskill [pw=fsweight], by (`x')
rename numbskill num_all_`b'
la var num_all_`b' "`b'"
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore 

*Count unweighted sample size for grade/age buckets
preserve
gen count_all_`b' = 1
collapse (count) count_all_`b' if FL28==1, by(`x')
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore 

*Male numeracy (by highest grade attended and age)*
preserve
collapse (mean) numbskill [pw=fsweight] if HL4==1, by (`x')
rename numbskill num_m_`b'
la var num_m_`b' "Boys in `b'"
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore 

*Count unweighted sample size for (grade/age * BOYS) buckets
preserve
gen count_m_`b' = 1
collapse (count) count_m_`b' if FL28==1 & HL4==1, by(`x')
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore 

*Female numeracy (by highest grade attended and age)*
preserve
collapse (mean) numbskill [pw=fsweight] if HL4==2, by (`x')
rename numbskill  num_f_`b'
la var num_f_`b' "Girls in `b'"
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore 

*Count unweighted sample size for (grade/age * GIRLS) buckets
preserve
gen count_f_`b' = 1
collapse (count) count_f_`b' if FL28==1 & HL4==2, by(`x')
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore

*Urban numeracy (by highest grade attended and age)*
preserve
collapse (mean) numbskill [pw=fsweight] if HH6==1, by (`x')
rename numbskill  num_urban_`b'
la var num_urban_`b' "Urban `b'"
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore 

*Count unweighted sample size for (grade/age * URBAN) buckets
preserve
gen count_urban_`b' = 1
collapse (count) count_urban_`b' if FL28==1 & HH6==1, by(`x')
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore

*Rural numeracy (by highest grade attended and age)*
preserve
collapse (mean) numbskill [pw=fsweight] if HH6==2, by (`x')
rename numbskill  num_rural_`b'
la var num_rural_`b' "Rural `b'"
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore 

*Count unweighted sample size for (grade/age * RURAL) buckets
preserve
gen count_rural_`b' = 1
collapse (count) count_rural_`b' if FL28==1 & HH6==2, by(`x')
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore

*Rich (top 20%) numeracy (by highest grade attended and age)*
preserve
collapse (mean) numbskill [pw=fsweight] if windex5==5, by (`x')
rename numbskill  num_top20_`b'
la var num_top20_`b' "Richest 20% in `b'"
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore 

*Count unweighted sample size for (grade/age * RICH) buckets
preserve
gen count_top20_`b' = 1
collapse (count) count_top20_`b' if FL28==1 & windex5==5, by(`x')
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore

*Poor (bottom 20%) numeracy (by highest grade attended and age)*
preserve
collapse (mean) numbskill [pw=fsweight] if windex5==1, by (`x')
rename numbskill  num_bottom20_`b'
la var num_bottom20_`b' "Poorest 20% in `b'"
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore 

*Count unweighted sample size for (grade/age * POOR) buckets
preserve
gen count_bottom20_`b' = 1
collapse (count) count_bottom20_`b' if FL28==1 & windex5==1, by(`x')
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore

*In school numeracy (by highest grade attended and age) (in school = attending school this year)*
preserve
collapse (mean) numbskill [pw=fsweight] if CB7==1, by (`x')
rename numbskill num_inschool_`b'
la var num_inschool_`b' "In-school `b'"
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore 

*Count unweighted sample size for (grade/age * inschool) buckets
preserve
gen count_inschool_`b' = 1
collapse (count) count_inschool_`b' if FL28==1 & CB7==1, by(`x')
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore

}
}

*READING 
foreach x in grade schage {
local n: word count $countryfiles
forvalues i = 1/`n' {
  local a : word `i' of $countryfiles
  local b : word `i' of $countrynames
use `a', clear

*Reading by highest grade attended
preserve
collapse (mean) readskill [pw=fsweight], by (`x')
rename readskill lit_all_`b'
la var lit_all_`b' "`b'"
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore 

*Male reading by highest grade attended
preserve
collapse (mean) readskill [pw=fsweight] if HL4==1, by (`x')
rename readskill lit_m_`b'
la var lit_m_`b' "Boys in `b'"
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore 

*Female reading by highest grade attended
preserve
collapse (mean) readskill [pw=fsweight] if HL4==2, by (`x')
rename readskill  lit_f_`b'
la var lit_f_`b' "Girls in `b'"
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore 

*Urban reading by highest grade attended
preserve
collapse (mean) readskill [pw=fsweight] if HH6==1, by (`x')
rename readskill  lit_urban_`b'
la var lit_urban_`b' "Urban `b'"
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore 

*Rural reading by highest grade attended
preserve
collapse (mean) readskill [pw=fsweight] if HH6==2, by (`x')
rename readskill  lit_rural_`b'
la var lit_rural_`b' "Rural `b'"
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore 

*Rich (top 20%) reading by highest grade attended
preserve
collapse (mean) readskill [pw=fsweight] if windex5==5, by (`x')
rename readskill lit_top20_`b'
la var lit_top20_`b' "Richest 20% in `b'"
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore 

*Poor (bottom 20%) reading by highest grade attended
preserve
collapse (mean) readskill [pw=fsweight] if windex5==1, by (`x')
rename readskill  lit_bottom20_`b'
la var lit_bottom20_`b' "Poorest 20% in `b'"
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore 

*In school reading by highest grade attended (in school = attending school this year) 
preserve
collapse (mean) readskill [pw=fsweight] if CB7==1, by (`x')
rename readskill lit_inschool_`b'
la var lit_inschool_`b' "In-school `b'"
merge 1:1 `x' using "$means/`x'"
drop _merge
save "$means/`x'", replace
restore 
}
}

******************************************************************************************
*6. Cleaning means datasets
******************************************************************************************

*Remove all learning means based on 25 or less unweighted observations
foreach x in grade schage {
use "$means/`x'", clear
foreach name in $countrynames {
foreach var in all m f urban rural top20 bottom20 inschool {
replace lit_`var'_`name'=. if count_`var'_`name'<26
replace num_`var'_`name'=. if count_`var'_`name'<26
}
}
save "$means/`x'", replace
}

*Replace all missing learning means for the groups of children with no school and in ECE with 0. This is a reasonable estimate that allows for coverage of more age cohorts in the simulations.
use "$means/grade", clear
foreach name in $countrynames {
foreach var in all m f urban rural top20 bottom20 inschool {
replace lit_`var'_`name'=0 if lit_`var'_`name'==. & (grade==-1|grade==0)
replace num_`var'_`name'=0 if num_`var'_`name'==. & (grade==-1|grade==0)
}
save "$means/grade", replace
}

******************************************************************************************
*7a. Create attainment profiles by age (for the access vs. learning simulations)
******************************************************************************************

*Create a dataset of the attainment profile per age per country 
*Note: The results of svy: tab for each country can't be directly exported into the same excel file / dataset because it proved infuriatingly hard to preserve grades with zero children in them.  For example, the command tabcount adds zeroes, but can't be used with weights.  What's here is a clunky but automated workaround.

*Loop through ages
foreach num of numlist 7/14 {

*Loop through countries except Tuvalu (see below for why)
gl omitfile clean_fs_tuvalu
gl omitname Tuvalu
local files: list global(countryfiles) - global(omitfile)
local names: list global(countrynames) - global(omitname)
 
local n : word count `files'
forvalues i = 1/`n' {
	local a : word `i' of `files'
	local b : word `i' of `names'

cd "$cleaned"
use `a', clear
putexcel set "$datafolder/attainment/`b'`num'", modify 
putexcel A1=("grade") B1=("ap`num'_`b'") C1=("obs_`num'_`b'")
*This returns the proportion of __-year-olds in each grade - the attainment profile for the cohort of __-year-olds
svyset [pw=fsweight]
svy: tab grade if schage==`num' & FL28==1
*matrix list e(Row) returns a 1-by-X matrix with grades.  
*We want to transpose it into an X-by-1 matrix.
matrix z = e(Row)'
putexcel A2 = matrix (z)
*matrix list e(Prop) returns an X-by-1 matrix with the proportion of __-yr-olds per grade
putexcel B2 = matrix (e(Prop))
*Export unweighted num of obs
tab grade if schage==`num' & FL28==1, matcell(x)
putexcel C2 = matrix (x)
*Convert the excel into dta file
clear
cd "$datafolder/attainment"
import excel using "`b'`num'", firstrow sheet(Sheet1)
save "`b'`num'", replace
}
}

*Special loop for Tuvalu since no sampled 14-year-olds.  tab schage if FL28==1 reveals that they sampled 6-13-year-olds.
*Loop through ages
foreach num of numlist 7/13 {
*Loop through countries
cd "$cleaned"
use clean_fs_tuvalu, clear
putexcel set "$datafolder/attainment/Tuvalu`num'", modify 
putexcel A1=("grade") B1=("ap`num'_Tuvalu") C1=("obs_`num'_Tuvalu")
*This returns the proportion of 14-year-olds in each grade - the attainment profile for the cohort of 14-year-olds
svyset [pw=fsweight]
svy: tab grade if schage==`num' & FL28==1
*matrix list e(Row) returns a 1-by-X matrix with grades.  
*We want to transpose it into an X-by-1 matrix.
matrix z = e(Row)'
putexcel A2 = matrix (z)
*matrix list e(Prop) returns an X-by-1 matrix with the proportion of 14-yr-olds per grade
putexcel B2 = matrix (e(Prop))
*Export unweighted num of obs
tab grade if schage==`num' & FL28==1, matcell(x)
putexcel C2 = matrix (x)
*Convert the excel into dta file
clear
cd "$datafolder/attainment"
import excel using "Tuvalu`num'", firstrow sheet(Sheet1)
save "Tuvalu`num'", replace
}

*Merge country attainment profiles into main dataset
use "$means/grade", clear
cd "$datafolder/attainment"
local files : dir "$datafolder/attainment" files "*.dta"
foreach file in `files' {
merge 1:1 grade using "`file'"
drop _merge
save "$means/grade", replace
}

*Add missing values for 14-year-olds in Tuvalu
gen ap14_Tuvalu=.
save "$means/grade", replace

*Replace missing values in attainment profiles with "0"
foreach num of numlist 7/14 {
foreach name in $countrynames {
replace ap`num'_`name'=0 if ap`num'_`name'==.
}
}
save "$means/grade", replace

******************************************************************************************
*7b. Create attainment profiles by age*group (for equality simulations)
******************************************************************************************
*These locals are looping through parallel lists to create datasets grade2 with age*wealth attainment profiles; grade3 with age*gender attainment profiles; grade4 with age*geography attainment profiles
*Separate datasets proved necessary because of limits on the number of variables in the less expensive version of Stata

use "$means/grade", clear 
keep grade lit_bottom20_* lit_top20_* lit_m_* lit_f_* lit_rural_* lit_urban_*
save "$means/grade2", replace

use "$means/grade", clear 
keep grade lit_bottom20_* lit_top20_* lit_m_* lit_f_* lit_rural_* lit_urban_*
save "$means/grade3", replace

use "$means/grade", clear 
keep grade lit_bottom20_* lit_top20_* lit_m_* lit_f_* lit_rural_* lit_urban_*
save "$means/grade4", replace

local dataset 2 2 3 3 4 4
local group poor rich girls boys rural urban 
local label bottom20 top20 f m rural urban
local variable windex5==1 windex5==5 HL4==2 HL4==1 HH6==2 HH6==1
local m : word count `dataset'
forvalues i = 1/`m' {
	local c : word `i' of `dataset'
	local d : word `i' of `group'
	local e : word `i' of `label'
	local f : word `i' of `variable'
	
*Loop through ages
foreach num of numlist 7/14 {
*Loop through countries (except Tuvalu)
gl omitfile clean_fs_tuvalu
gl omitname Tuvalu
local files: list global(countryfiles) - global(omitfile)
local names: list global(countrynames) - global(omitname)
local n : word count `files'
forvalues i = 1/`n' {
	local a : word `i' of `files'
	local b : word `i' of `names'
cd "$cleaned"
use `a', clear
putexcel set "$datafolder/attainment`d'/`b'`num'", modify 
putexcel A1=("grade") B1=("`e'_ap`num'_`b'") C1=("obs_`e'_`num'_`b'")
*This returns the proportion of 14-year-olds in each grade - the attainment profile for the cohort of 14-year-olds
svyset [pw=fsweight]
svy: tab grade if schage==`num' & (`f') & FL28==1
*matrix list e(Row) returns a 1-by-X matrix with grades.  
*We want to transpose it into an X-by-1 matrix.
matrix z = e(Row)'
putexcel A2 = matrix (z)
*matrix list e(Prop) returns an X-by-1 matrix with the proportion of 14-yr-olds per grade
putexcel B2 = matrix (e(Prop))
*Export unweighted num of obs
tab grade if schage==`num' & (`f') & FL28==1, matcell(x)
putexcel C2 = matrix (x)
*Convert the excel into dta file
clear
cd "$datafolder/attainment`d'"
import excel using "`b'`num'", firstrow sheet(Sheet1)
save "`b'`num'", replace
}
}

*Special loop for Tuvalu since no sampled 14-year-olds
*Loop through ages
foreach num of numlist 7/13 {
*Loop through countries
cd "$cleaned"
use clean_fs_tuvalu, clear
putexcel set "$datafolder/attainment`d'/Tuvalu`num'", modify 
putexcel A1=("grade") B1=("`e'_ap`num'_Tuvalu") C1=("obs_`e'_`num'_Tuvalu")
*This returns the proportion of 14-year-olds in each grade - the attainment profile for the cohort of 14-year-olds
svyset [pw=fsweight]    
svy: tab grade if schage==`num' & (`f') & FL28==1
*matrix list e(Row) returns a 1-by-X matrix with grades.  
*We want to transpose it into an X-by-1 matrix.
matrix z = e(Row)'
putexcel A2 = matrix (z)
*matrix list e(Prop) returns an X-by-1 matrix with the proportion of 14-yr-olds per grade
putexcel B2 = matrix (e(Prop))
*Export unweighted num of obs
tab grade if schage==`num' & (`f') & FL28==1, matcell(x)
putexcel C2 = matrix (x)
*Convert the excel into dta file
clear
cd "$datafolder/attainment`d'"
import excel using "Tuvalu`num'", firstrow sheet(Sheet1)
save "Tuvalu`num'", replace
}

*Merge country attainment profiles into main dataset
use "$means/grade`c'", clear
cd "$datafolder/attainment`d'"
local files : dir "$datafolder/attainment`d'" files "*.dta"
foreach file in `files' {
merge 1:1 grade using "`file'"
drop _merge
save "$means/grade`c'", replace
}

*Add missing values for 14-year-olds in Tuvalu
use "$means/grade`c'", clear
gen `e'_ap14_Tuvalu=.
save "$means/grade`c'", replace
}

*Replace missing values in attainment profiles with "0"
use "$means/grade2", clear 
foreach num of numlist 7/14 {
foreach name in $countrynames {
replace bottom20_ap`num'_`name'=0 if bottom20_ap`num'_`name'==.
replace top20_ap`num'_`name'=0 if top20_ap`num'_`name'==.
}
}
save "$means/grade2", replace

use "$means/grade3", clear 
foreach num of numlist 7/14 {
foreach name in $countrynames {
replace m_ap`num'_`name'=0 if m_ap`num'_`name'==.
replace f_ap`num'_`name'=0 if f_ap`num'_`name'==.
}
}
save "$means/grade3", replace

use "$means/grade4", clear 
foreach num of numlist 7/14 {
foreach name in $countrynames {
replace urban_ap`num'_`name'=0 if urban_ap`num'_`name'==.
replace rural_ap`num'_`name'=0 if rural_ap`num'_`name'==.
}
}
save "$means/grade4", replace

******************************************************************************************
*8. Combine 4 Pakistani provinces into a single population-weighted national estimate (for all means datasets) 
******************************************************************************************

*Proportions come from the latest Pakistan census in 2017: https://www.pbs.gov.pk/sites/default/files/population/2017/national.pdf
*Note that FATAÕs population was added to Khyber Pakhtunkhwa since the MICS6 survey was administered in 2019 following the merger of the two provinces
*The combined provinces represent over 99% of the population

*For grade dataset replace all vars with a weighted var of the 4 provinces
use "$means/grade", clear
foreach var in lit_inschool_ lit_bottom20_ lit_top20_ lit_rural_ lit_urban_ lit_f_ lit_m_ lit_all_ num_inschool_ num_bottom20_ num_top20_ num_rural_ num_urban_ num_f_ num_m_ num_all_ ap14_ ap9_ ap8_ ap11_ ap10_ ap12_ ap13_ ap7_ {
gen `var'Pakistan = (`var'Punjab*.5348)+(`var'KP*.1726)+(`var'Sindh*.2327)+(`var'Balochistan*.0600)
}

*Drop all vars related to the 4 provinces
foreach var in Punjab Sindh KP Balochistan {
ds, has(varlabel "*`var'*")
drop `r(varlist)'
}
save "$means/grade", replace

*For the grade2 dataset with rich/poor attainment profiles
use "$means/grade2", clear
foreach var in lit_bottom20_ lit_top20_ lit_rural_ lit_urban_ lit_f_ lit_m_ bottom20_ap14_ bottom20_ap9_ bottom20_ap8_ bottom20_ap11_ bottom20_ap10_ bottom20_ap12_ bottom20_ap13_ bottom20_ap7_ top20_ap14_ top20_ap9_ top20_ap8_ top20_ap11_ top20_ap10_ top20_ap12_ top20_ap13_ top20_ap7_ {
gen `var'Pakistan = (`var'Punjab*.5348)+(`var'KP*.1726)+(`var'Sindh*.2327)+(`var'Balochistan*.0600)
}

foreach var in Punjab Sindh KP Balochistan {
ds, has(varlabel "*`var'*")
drop `r(varlist)'
}
save "$means/grade2", replace

*For the grade3 dataset with boy/girl attainment profiles
use "$means/grade3", clear
foreach var in lit_bottom20_ lit_top20_ lit_rural_ lit_urban_ lit_f_ lit_m_ f_ap14_ f_ap9_ f_ap8_ f_ap11_ f_ap10_ f_ap12_ f_ap13_ f_ap7_ m_ap14_ m_ap9_ m_ap8_ m_ap11_ m_ap10_ m_ap12_ m_ap13_ m_ap7_ {
gen `var'Pakistan = (`var'Punjab*.5348)+(`var'KP*.1726)+(`var'Sindh*.2327)+(`var'Balochistan*.0600)
}

foreach var in Punjab Sindh KP Balochistan {
ds, has(varlabel "*`var'*")
drop `r(varlist)'
}
save "$means/grade3", replace

*For the grade4 dataset with rural/urban attainment profiles
use "$means/grade4", clear
foreach var in lit_bottom20_ lit_top20_ lit_rural_ lit_urban_ lit_f_ lit_m_ rural_ap14_ rural_ap9_ rural_ap8_ rural_ap11_ rural_ap10_ rural_ap12_ rural_ap13_ rural_ap7_ urban_ap14_ urban_ap9_ urban_ap8_ urban_ap11_ urban_ap10_ urban_ap12_ urban_ap13_ urban_ap7_ {
gen `var'Pakistan = (`var'Punjab*.5348)+(`var'KP*.1726)+(`var'Sindh*.2327)+(`var'Balochistan*.0600)
}

foreach var in Punjab Sindh KP Balochistan {
ds, has(varlabel "*`var'*")
drop `r(varlist)'
}
save "$means/grade4", replace

*For the schage dataset
use "$means/schage", clear
foreach var in lit_inschool_ lit_bottom20_ lit_top20_ lit_rural_ lit_urban_ lit_f_ lit_m_ lit_all_ num_inschool_ num_bottom20_ num_top20_ num_rural_ num_urban_ num_f_ num_m_ num_all_ {
gen `var'Pakistan = (`var'Punjab*.5348)+(`var'KP*.1726)+(`var'Sindh*.2327)+(`var'Balochistan*.0600)
}

foreach var in Punjab Sindh KP Balochistan {
ds, has(varlabel "*`var'*")
drop `r(varlist)'
}
save "$means/schage", replace

******************************************************************************************
*9. Create variables for different country groups: low+lower-middle income countries, 5 high performing countries, 5 low performing countries
******************************************************************************************

/* Country income classification (from World Bank): https://datahelpdesk.worldbank.org/knowledgebase/articles/906519-world-bank-country-and-lending-groups
Low income countries (LICs): Madagascar	Togo TheGambia SierraLeone GuineaBissau	DRC Chad CAR Malawi
Lower-middle income countries (LMICs): Lesotho Samoa Zimbabwe Kyrgyzstan Tunisia SaoTome Palestine Nepal Mongolia Kiribati Ghana Bangladesh Vietnam Pakistan
Upper middle income countries (UMICs): Belarus Kosovo NorthMacedonia Suriname Thailand Tonga Turkmenistan Tuvalu
High income countries: Turks and Caicos Islands
*/

foreach dataset in grade schage {
use "$means/`dataset'", clear
*Count the number of countries missing from the low+lower-middle income country average (23 countries), for all demographic groups
egen rowmiss_all_lmic=rowmiss(lit_all_Madagascar	lit_all_Togo lit_all_TheGambia lit_all_SierraLeone lit_all_GuineaBissau lit_all_DRC lit_all_Chad lit_all_CAR lit_all_Malawi lit_all_Lesotho lit_all_Samoa lit_all_Zimbabwe lit_all_Kyrgyzstan	lit_all_Tunisia	lit_all_SaoTome lit_all_Palestine	lit_all_Nepal lit_all_Mongolia lit_all_Kiribati lit_all_Ghana lit_all_Bangladesh lit_all_Vietnam lit_all_Pakistan)

egen rowmiss_f_lmic=rowmiss(lit_f_Madagascar	lit_f_Togo lit_f_TheGambia lit_f_SierraLeone lit_f_GuineaBissau lit_f_DRC lit_f_Chad lit_f_CAR lit_f_Malawi lit_f_Lesotho lit_f_Samoa lit_f_Zimbabwe lit_f_Kyrgyzstan	lit_f_Tunisia	lit_f_SaoTome lit_f_Palestine	lit_f_Nepal lit_f_Mongolia lit_f_Kiribati lit_f_Ghana lit_f_Bangladesh lit_f_Vietnam lit_f_Pakistan)
egen rowmiss_m_lmic=rowmiss(lit_m_Madagascar	lit_m_Togo lit_m_TheGambia lit_m_SierraLeone lit_m_GuineaBissau lit_m_DRC lit_m_Chad lit_m_CAR lit_m_Malawi lit_m_Lesotho lit_m_Samoa lit_m_Zimbabwe lit_m_Kyrgyzstan	lit_m_Tunisia	lit_m_SaoTome lit_m_Palestine	lit_m_Nepal lit_m_Mongolia lit_m_Kiribati lit_m_Ghana lit_m_Bangladesh lit_m_Vietnam lit_m_Pakistan)

egen rowmiss_bottom20_lmic=rowmiss(lit_bottom20_Madagascar	lit_bottom20_Togo lit_bottom20_TheGambia lit_bottom20_SierraLeone lit_bottom20_GuineaBissau lit_bottom20_DRC lit_bottom20_Chad lit_bottom20_CAR lit_bottom20_Malawi lit_bottom20_Lesotho lit_bottom20_Samoa lit_bottom20_Zimbabwe lit_bottom20_Kyrgyzstan	lit_bottom20_Tunisia	lit_bottom20_SaoTome lit_bottom20_Palestine	lit_bottom20_Nepal lit_bottom20_Mongolia lit_bottom20_Kiribati lit_bottom20_Ghana lit_bottom20_Bangladesh lit_bottom20_Vietnam lit_bottom20_Pakistan)
egen rowmiss_top20_lmic=rowmiss(lit_top20_Madagascar	lit_top20_Togo lit_top20_TheGambia lit_top20_SierraLeone lit_top20_GuineaBissau lit_top20_DRC lit_top20_Chad lit_top20_CAR lit_top20_Malawi lit_top20_Lesotho lit_top20_Samoa lit_top20_Zimbabwe lit_top20_Kyrgyzstan	lit_top20_Tunisia	lit_top20_SaoTome lit_top20_Palestine	lit_top20_Nepal lit_top20_Mongolia lit_top20_Kiribati lit_top20_Ghana lit_top20_Bangladesh lit_top20_Vietnam lit_top20_Pakistan)

egen rowmiss_urban_lmic=rowmiss(lit_urban_Madagascar	lit_urban_Togo lit_urban_TheGambia lit_urban_SierraLeone lit_urban_GuineaBissau lit_urban_DRC lit_urban_Chad lit_urban_CAR lit_urban_Malawi lit_urban_Lesotho lit_urban_Samoa lit_urban_Zimbabwe lit_urban_Kyrgyzstan	lit_urban_Tunisia	lit_urban_SaoTome lit_urban_Palestine	lit_urban_Nepal lit_urban_Mongolia lit_urban_Kiribati lit_urban_Ghana lit_urban_Bangladesh lit_urban_Vietnam lit_urban_Pakistan)
egen rowmiss_rural_lmic=rowmiss(lit_rural_Madagascar	lit_rural_Togo lit_rural_TheGambia lit_rural_SierraLeone lit_rural_GuineaBissau lit_rural_DRC lit_rural_Chad lit_rural_CAR lit_rural_Malawi lit_rural_Lesotho lit_rural_Samoa lit_rural_Zimbabwe lit_rural_Kyrgyzstan	lit_rural_Tunisia	lit_rural_SaoTome lit_rural_Palestine	lit_rural_Nepal lit_rural_Mongolia lit_rural_Kiribati lit_rural_Ghana lit_rural_Bangladesh lit_rural_Vietnam lit_rural_Pakistan)

*Generate low+lower-middle income country average (23 countries) for reading, and remove averages based on less than half of the group
local varlist all_ f_ m_ top20_ bottom20_ urban_ rural_
foreach var in `varlist' {
egen lit_`var'lmic=rmean(lit_`var'Madagascar lit_`var'Togo lit_`var'TheGambia lit_`var'SierraLeone lit_`var'GuineaBissau lit_`var'DRC lit_`var'Chad lit_`var'CAR lit_`var'Malawi lit_`var'Lesotho lit_`var'Samoa lit_`var'Zimbabwe lit_`var'Kyrgyzstan	lit_`var'Tunisia	lit_`var'SaoTome lit_`var'Palestine	lit_`var'Nepal lit_`var'Mongolia lit_`var'Kiribati lit_`var'Ghana lit_`var'Bangladesh lit_`var'Vietnam lit_`var'Pakistan)
replace lit_`var'lmic=. if rowmiss_`var'lmic>(23*.5)
}

*Generate low+lower-middle income country average (23 countries) for math, and remove averages based on less than half of the group
local varlist all_ f_ m_ top20_ bottom20_ urban_ rural_
foreach var in `varlist' {
egen num_`var'lmic=rmean(num_`var'Madagascar num_`var'Togo num_`var'TheGambia num_`var'SierraLeone num_`var'GuineaBissau num_`var'DRC num_`var'Chad num_`var'CAR num_`var'Malawi num_`var'Lesotho num_`var'Samoa num_`var'Zimbabwe num_`var'Kyrgyzstan	num_`var'Tunisia	num_`var'SaoTome num_`var'Palestine	num_`var'Nepal num_`var'Mongolia num_`var'Kiribati num_`var'Ghana num_`var'Bangladesh num_`var'Vietnam num_`var'Pakistan)
replace num_`var'lmic=. if rowmiss_`var'lmic>(23*.5)
}
save "$means/`dataset'", replace
}

*Create average attainment profiles for low+lower-middle income country group
use "$means/grade", clear
foreach num of numlist 7/14 {
egen ap`num'_lmic=rmean(ap`num'_Madagascar	ap`num'_Togo ap`num'_TheGambia ap`num'_SierraLeone ap`num'_GuineaBissau ap`num'_DRC ap`num'_Chad ap`num'_CAR ap`num'_Malawi ap`num'_Lesotho ap`num'_Samoa ap`num'_Zimbabwe ap`num'_Kyrgyzstan	ap`num'_Tunisia	ap`num'_SaoTome ap`num'_Palestine	ap`num'_Nepal ap`num'_Mongolia ap`num'_Kiribati ap`num'_Ghana ap`num'_Bangladesh ap`num'_Vietnam ap`num'_Pakistan)
}
save "$means/grade", replace

local dataset 2 2 3 3 4 4
local label bottom20 top20 f m rural urban
local m : word count `dataset'
forvalues i = 1/`m' {
	local c : word `i' of `dataset'
	local e : word `i' of `label'
use "$means/grade`c'", clear
foreach num of numlist 7/14 {
egen `e'_ap`num'_lmic=rmean(`e'_ap`num'_Madagascar	`e'_ap`num'_Togo `e'_ap`num'_TheGambia `e'_ap`num'_SierraLeone `e'_ap`num'_GuineaBissau `e'_ap`num'_DRC `e'_ap`num'_Chad `e'_ap`num'_CAR `e'_ap`num'_Malawi `e'_ap`num'_Lesotho `e'_ap`num'_Samoa `e'_ap`num'_Zimbabwe `e'_ap`num'_Kyrgyzstan	`e'_ap`num'_Tunisia	`e'_ap`num'_SaoTome `e'_ap`num'_Palestine	`e'_ap`num'_Nepal `e'_ap`num'_Mongolia `e'_ap`num'_Kiribati `e'_ap`num'_Ghana `e'_ap`num'_Bangladesh `e'_ap`num'_Vietnam `e'_ap`num'_Pakistan)
}
save "$means/grade`c'", replace
}

*Create average variables for the 5 highest performing, and 5 lowest performing, low+lower-middle income countries (ranked by reading proficiency at Grade 3)
use "$means/grade", clear
*Average learning trajectory for top 5
egen lit_lp_topfive=rmean(lit_all_Vietnam lit_all_Mongolia lit_all_Tunisia lit_all_Kyrgyzstan lit_all_Kiribati)

*Average attainment profiles per age cohort for bottom 5
foreach num of numlist 7/14 {
egen ap`num'_bottomfive=rmean(ap`num'_Chad ap`num'_CAR ap`num'_DRC ap`num'_Togo ap`num'_Ghana)
}
save "$means/grade", replace

use "$means/schage", clear
*Generate average trajectories for top 5 and bottom 5
egen lit_all_topfive=rmean(lit_all_Vietnam lit_all_Mongolia lit_all_Tunisia lit_all_Kyrgyzstan lit_all_Kiribati)
egen lit_all_bottomfive=rmean(lit_all_Chad lit_all_CAR lit_all_DRC lit_all_Togo lit_all_Ghana)

*Access counterfactual: Average trajectories for in-school children for top 5 and bottom 5
egen lit_inschool_topfive=rmean(lit_inschool_Tunisia lit_inschool_Samoa lit_inschool_Kyrgyzstan lit_inschool_Lesotho lit_inschool_Mongolia)
egen lit_inschool_bottomfive=rmean(lit_inschool_Chad lit_inschool_CAR lit_inschool_DRC lit_inschool_Togo lit_inschool_Ghana)
save "$means/schage", replace

******************************************************************************************
*10. Final cleaning
******************************************************************************************

*For grade dataset replace all country names with ISO names
use "$means/grade", clear
foreach var in lit_inschool_ lit_bottom20_ lit_top20_ lit_rural_ lit_urban_ lit_f_ lit_m_ lit_all_ num_inschool_ num_bottom20_ num_top20_ num_rural_ num_urban_ num_f_ num_m_ num_all_ ap14_ ap9_ ap8_ ap11_ ap10_ ap12_ ap13_ ap7_ {
rename `var'Bangladesh	`var'BGD
rename `var'Belarus	`var'BLR
rename `var'CAR `var'CAF
rename `var'Chad `var'TCD
rename `var'DRC `var'COD
rename `var'Ghana	`var'GHA
rename `var'GuineaBissau	`var'GNB
rename `var'Kiribati	`var'KIR
rename `var'Kosovo	`var'KOS
rename `var'Kyrgyzstan	`var'KGZ
rename `var'Lesotho	`var'LSO
rename `var'Madagascar	`var'MDG
rename `var'Malawi	`var'MWI
rename `var'Mongolia	`var'MNG
rename `var'Nepal	`var'NPL
rename `var'NorthMacedonia	`var'MKD
rename `var'Pakistan	`var'PAK
rename `var'Palestine	`var'PSE
rename `var'Samoa	`var'WSM
rename `var'SaoTome `var'STP
rename `var'SierraLeone	`var'SLE
rename `var'Suriname	`var'SUR
rename `var'Thailand	`var'THA
rename `var'TheGambia	`var'GMB
rename `var'Togo	`var'TGO
rename `var'Tonga	`var'TON
rename `var'Tunisia	`var'TUN
rename `var'Turkmenistan	`var'TKM
rename `var'Turks `var'TCA
rename `var'Tuvalu	`var'TUV
rename `var'Vietnam	`var'VNM
rename `var'Zimbabwe `var'ZWE
}
save "$means/grade", replace

*For the grade2 dataset
use "$means/grade2", clear
foreach var in lit_bottom20_ lit_top20_ lit_rural_ lit_urban_ lit_f_ lit_m_ bottom20_ap14_ bottom20_ap9_ bottom20_ap8_ bottom20_ap11_ bottom20_ap10_ bottom20_ap12_ bottom20_ap13_ bottom20_ap7_ top20_ap14_ top20_ap9_ top20_ap8_ top20_ap11_ top20_ap10_ top20_ap12_ top20_ap13_ top20_ap7_ {
rename `var'Bangladesh	`var'BGD
rename `var'Belarus	`var'BLR
rename `var'CAR `var'CAF
rename `var'Chad `var'TCD
rename `var'DRC `var'COD
rename `var'Ghana	`var'GHA
rename `var'GuineaBissau	`var'GNB
rename `var'Kiribati	`var'KIR
rename `var'Kosovo	`var'KOS
rename `var'Kyrgyzstan	`var'KGZ
rename `var'Lesotho	`var'LSO
rename `var'Madagascar	`var'MDG
rename `var'Malawi	`var'MWI
rename `var'Mongolia	`var'MNG
rename `var'Nepal	`var'NPL
rename `var'NorthMacedonia	`var'MKD
rename `var'Pakistan	`var'PAK
rename `var'Palestine	`var'PSE
rename `var'Samoa	`var'WSM
rename `var'SaoTome `var'STP
rename `var'SierraLeone	`var'SLE
rename `var'Suriname	`var'SUR
rename `var'Thailand	`var'THA
rename `var'TheGambia	`var'GMB
rename `var'Togo	`var'TGO
rename `var'Tonga	`var'TON
rename `var'Tunisia	`var'TUN
rename `var'Turkmenistan	`var'TKM
rename `var'Turks `var'TCA
rename `var'Tuvalu	`var'TUV
rename `var'Vietnam	`var'VNM
rename `var'Zimbabwe `var'ZWE
}
save "$means/grade2", replace

*For the grade3 dataset
use "$means/grade3", clear
foreach var in lit_bottom20_ lit_top20_ lit_rural_ lit_urban_ lit_f_ lit_m_ f_ap14_ f_ap9_ f_ap8_ f_ap11_ f_ap10_ f_ap12_ f_ap13_ f_ap7_ m_ap14_ m_ap9_ m_ap8_ m_ap11_ m_ap10_ m_ap12_ m_ap13_ m_ap7_ {
rename `var'Bangladesh	`var'BGD
rename `var'Belarus	`var'BLR
rename `var'CAR `var'CAF
rename `var'Chad `var'TCD
rename `var'DRC `var'COD
rename `var'Ghana	`var'GHA
rename `var'GuineaBissau	`var'GNB
rename `var'Kiribati	`var'KIR
rename `var'Kosovo	`var'KOS
rename `var'Kyrgyzstan	`var'KGZ
rename `var'Lesotho	`var'LSO
rename `var'Madagascar	`var'MDG
rename `var'Malawi	`var'MWI
rename `var'Mongolia	`var'MNG
rename `var'Nepal	`var'NPL
rename `var'NorthMacedonia	`var'MKD
rename `var'Pakistan	`var'PAK
rename `var'Palestine	`var'PSE
rename `var'Samoa	`var'WSM
rename `var'SaoTome `var'STP
rename `var'SierraLeone	`var'SLE
rename `var'Suriname	`var'SUR
rename `var'Thailand	`var'THA
rename `var'TheGambia	`var'GMB
rename `var'Togo	`var'TGO
rename `var'Tonga	`var'TON
rename `var'Tunisia	`var'TUN
rename `var'Turkmenistan	`var'TKM
rename `var'Turks `var'TCA
rename `var'Tuvalu	`var'TUV
rename `var'Vietnam	`var'VNM
rename `var'Zimbabwe `var'ZWE
}
save "$means/grade3", replace

*For the grade4 dataset with rural/urban attainment profiles
use "$means/grade4", clear
foreach var in lit_bottom20_ lit_top20_ lit_rural_ lit_urban_ lit_f_ lit_m_ rural_ap14_ rural_ap9_ rural_ap8_ rural_ap11_ rural_ap10_ rural_ap12_ rural_ap13_ rural_ap7_ urban_ap14_ urban_ap9_ urban_ap8_ urban_ap11_ urban_ap10_ urban_ap12_ urban_ap13_ urban_ap7_ {
rename `var'Bangladesh	`var'BGD
rename `var'Belarus	`var'BLR
rename `var'CAR `var'CAF
rename `var'Chad `var'TCD
rename `var'DRC `var'COD
rename `var'Ghana	`var'GHA
rename `var'GuineaBissau	`var'GNB
rename `var'Kiribati	`var'KIR
rename `var'Kosovo	`var'KOS
rename `var'Kyrgyzstan	`var'KGZ
rename `var'Lesotho	`var'LSO
rename `var'Madagascar	`var'MDG
rename `var'Malawi	`var'MWI
rename `var'Mongolia	`var'MNG
rename `var'Nepal	`var'NPL
rename `var'NorthMacedonia	`var'MKD
rename `var'Pakistan	`var'PAK
rename `var'Palestine	`var'PSE
rename `var'Samoa	`var'WSM
rename `var'SaoTome `var'STP
rename `var'SierraLeone	`var'SLE
rename `var'Suriname	`var'SUR
rename `var'Thailand	`var'THA
rename `var'TheGambia	`var'GMB
rename `var'Togo	`var'TGO
rename `var'Tonga	`var'TON
rename `var'Tunisia	`var'TUN
rename `var'Turkmenistan	`var'TKM
rename `var'Turks `var'TCA
rename `var'Tuvalu	`var'TUV
rename `var'Vietnam	`var'VNM
rename `var'Zimbabwe `var'ZWE
}
save "$means/grade4", replace

*For the schage dataset
use "$means/schage", clear
foreach var in lit_inschool_ lit_bottom20_ lit_top20_ lit_rural_ lit_urban_ lit_f_ lit_m_ lit_all_ num_inschool_ num_bottom20_ num_top20_ num_rural_ num_urban_ num_f_ num_m_ num_all_ {
rename `var'Bangladesh	`var'BGD
rename `var'Belarus	`var'BLR
rename `var'CAR `var'CAF
rename `var'Chad `var'TCD
rename `var'DRC `var'COD
rename `var'Ghana	`var'GHA
rename `var'GuineaBissau	`var'GNB
rename `var'Kiribati	`var'KIR
rename `var'Kosovo	`var'KOS
rename `var'Kyrgyzstan	`var'KGZ
rename `var'Lesotho	`var'LSO
rename `var'Madagascar	`var'MDG
rename `var'Malawi	`var'MWI
rename `var'Mongolia	`var'MNG
rename `var'Nepal	`var'NPL
rename `var'NorthMacedonia	`var'MKD
rename `var'Pakistan	`var'PAK
rename `var'Palestine	`var'PSE
rename `var'Samoa	`var'WSM
rename `var'SaoTome `var'STP
rename `var'SierraLeone	`var'SLE
rename `var'Suriname	`var'SUR
rename `var'Thailand	`var'THA
rename `var'TheGambia	`var'GMB
rename `var'Togo	`var'TGO
rename `var'Tonga	`var'TON
rename `var'Tunisia	`var'TUN
rename `var'Turkmenistan	`var'TKM
rename `var'Turks `var'TCA
rename `var'Tuvalu	`var'TUV
rename `var'Vietnam	`var'VNM
rename `var'Zimbabwe `var'ZWE
}
save "$means/schage", replace

********Change missing to -99

foreach x in grade grade2 grade3 grade4 schage {
use "$means/`x'", clear
foreach var of varlist _all {
replace `var'=-99 if `var'==.
}
save "$means/`x'", replace
}

*******Narrow dataset to Grades 10 and below, and ages 7-14; drop unused vars (obs* count* rowmiss*); and drop Kosovo
foreach x in grade grade2 grade3 grade4 {
use "$means/`x'", clear
drop if grade>10 | grade<-1
drop obs*
drop *KOS*
save "$means/`x'", replace
}

use "$means/schage", clear
drop if schage<7 | schage>14
drop *KOS*
save "$means/schage", replace

foreach x in grade schage {
use "$means/`x'", clear
drop count* rowmiss*
save "$means/`x'", replace
}

*Export to excel
cd "$outputs"
use "$means/grade", clear
export excel grade.xlsx, firstrow(var) nolabel replace
*776 unique variables (with 23 countries)

use "$means/grade2", clear
drop lit*
cd "$outputs"
export excel ap_wealth.xlsx, firstrow(var) nolabel replace
*512 unique variables (with 23 countries)

use "$means/grade3", clear
drop lit*
cd "$outputs"
export excel ap_gender.xlsx, firstrow(var) nolabel replace
*512 unique variables (with 23 countries)

use "$means/grade4", clear
drop lit*
cd "$outputs"
export excel ap_geography.xlsx, firstrow(var) nolabel replace
*512 unique variables (with 23 countries)

use "$means/schage", clear
cd "$outputs"
export excel age.xlsx, firstrow(var) nolabel replace
*515 unique variables (with 23 countries)
