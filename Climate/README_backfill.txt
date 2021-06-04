
 git clone https://github.com/genophenoenvo/NPN-Data.git

 8.7M Apr 23 12:48 individual_phenometrics_data2008_2020trim.csv
  12K Apr 23 12:48 individual_phenometrics_datafield_descriptions.xlsx
 1.1K Apr 23 12:48 search_parameters.csv
  11M Apr 23 12:48 individual_phenometrics_data1957_2007noWeather.csv


head -1 individual_phenometrics_data2008_2020trim.csv | tr \, '\n' | grep . -n
1:Site_ID
2:Site_Name
3:Latitude
4:Longitude
5:Elevation_in_Meters
6:Species_ID
7:Genus
8:Species
9:Common_Name
10:USDA_PLANTS_Symbol
11:Individual_ID
12:Phenophase_ID
13:Phenophase_Description
14:First_Yes_Year
15:First_Yes_Month
16:First_Yes_Day
17:First_Yes_DOY
18:First_Yes_Julian_Date
19:NumDays_Since_Prior_No
20:Last_Yes_Year
21:Last_Yes_Month
22:Last_Yes_Day
23:Last_Yes_DOY
24:Last_Yes_Julian_Date
25:NumDays_Until_Next_No
26:AGDD
27:AGDD_in_F
28:Tmax_Winter
29:Tmax_Spring
30:Tmax_Summer
31:Tmax_Fall
32:Tmin_Winter
33:Tmin_Spring
34:Tmin_Summer
35:Tmin_Fall
36:Prcp_Winter
37:Prcp_Spring
38:Prcp_Summer
39:Prcp_Fall
40:Accum_Prcp

,,,

wondering about finding weather data for the early 57-07 dataset


xsv select 3,4 ./individual_phenometrics_data1957_2007noWeather.csv | xsv stats | cut -f 1,4,5 -d','
field,min,max
Latitude,29.879999,60.171356
Longitude,-149.39119,-52.779999

need weather for 1,330 points within a 30-deg by 100-deg bounding box

perhaps some more points  may be clustered. (visually, does not appear worth it)
note 
the weather is aggregated into avg min/max for three month blocks of time 
so a high precision location is kind of moot

DayMet will likely cover it.. seems to only go back to 1980

make a script to fetch a file from their single pixel API for each location
with the 1980 thru 2007 daily weather data.

averaging temps & percip to seasons should be straight forward
generating growing degree days a little bit more. ..not really, they use (max+min)/2 - base

the four seasons will be partitioned on days of the year 62, 152, 243, 335

growing degree days and accumulated precipitation are counted from the new year

AGDD,AGDD_in_F, 
Tmax_Winter,Tmax_Spring,Tmax_Summer,Tmax_Fall,
Tmin_Winter,Tmin_Spring,Tmin_Summer,Tmin_Fall,
Prcp_Winter,Prcp_Spring,Prcp_Summer,Prcp_Fall,
Accum_Prcp,


##########################################################


testing my results ...

can get locations from the 2008-2020 file

GitHub/NPN-Data

xsv select 3,4 individual_phenometrics_data2008_2020trim.csv |
	sed '1,1d' |sort -u  > latlon_test_2008_2020.csv

wc -l < latlon_test_2008_2020.csv 
2107  

hmmm. a third more distinct points in the shorter but newer datasets 
 than the longer but older ranges  (not shocking)

# fetch the pixel stacks for the locations
time \
./daymet-single-pixel-batch/bash/daymet_spt_range.sh \
	-s 2008-01-01 -d NPN_locations_Test -i ../GitHub/NPN-Data/latlon_test_2008_2020.csv

real	327m30.674s

yep. almost six hours to fetch the pixel stacks.


cat /dev/null > NPN_season_test.tsv

for f in NPN_locations_Test/lat_*.out; do 
	./reduce_daymet_pixlestack_to_seasonal.awk $f >> NPN_season_test.tsv; 
done

(less than a minute to process them)

then we need to compare & contrast with the values from 
 individual_phenometrics_data2008_2020trim.csv


xsv headers ../GitHub/NPN-Data/individual_phenometrics_data2008_2020trim.csv
1   Site_ID
2   Site_Name
3   Latitude
4   Longitude
5   Elevation_in_Meters
6   Species_ID
7   Genus
8   Species
9   Common_Name
10  USDA_PLANTS_Symbol
11  Individual_ID
12  Phenophase_ID
13  Phenophase_Description
14  First_Yes_Year
15  First_Yes_Month
16  First_Yes_Day
17  First_Yes_DOY
18  First_Yes_Julian_Date
19  NumDays_Since_Prior_No
20  Last_Yes_Year
21  Last_Yes_Month
22  Last_Yes_Day
23  Last_Yes_DOY
24  Last_Yes_Julian_Date
25  NumDays_Until_Next_No
26  AGDD
27  AGDD_in_F
28  Tmax_Winter
29  Tmax_Spring
30  Tmax_Summer
31  Tmax_Fall
32  Tmin_Winter
33  Tmin_Spring
34  Tmin_Summer
35  Tmin_Fall
36  Prcp_Winter
37  Prcp_Spring
38  Prcp_Summer
39  Prcp_Fall
40  Accum_Prcp
41  Daylength

xsv select 3,4,14,20,26-40 ../GitHub/NPN-Data/individual_phenometrics_data2008_2020trim.csv

xsv select 3,4,14,20,26-40 ../GitHub/NPN-Data/individual_phenometrics_data2008_2020trim.csv |
	sort -ur > NPN_originals_test.tsv

wc -l < NPN_originals_test.tsv
17,140

hmmm noting there are allot of -9999 values  in the dataset with values.

grep -c '\-9999' NPN_originals_test.tsv
488

# exclude them
xsv select 3,4,14,20,26-40 ../GitHub/NPN-Data/individual_phenometrics_data2008_2020trim.csv |
	sort -ur | grep -v "\-9999" | tr ',' '\t' > NPN_originals_test.tsv

wc -l < NPN_originals_test.tsv
16,652

wc -l < NPN_season_test.tsv 
27,053

my generated set has 11k more.  
most likely because it generates weather for every year in the range
whether there is an observation that year or not. 

the test will have to be: 
if there is (valid) original data; 
then how do my derived values compare.

all keyed off of  lat,lon,year  should get about 16.6k instances

AGDD	AGDD_in_F	
Tmax_Winter	Tmax_Spring	Tmax_Summer	Tmax_Fall	
Tmin_Winter	Tmin_Spring	Tmin_Summer	Tmin_Fall	
Prcp_Winter	Prcp_Spring	Prcp_Summer	Prcp_Fall	
Accum_Prcp

grep -e "2019.64.925751.\-147.880295" NPN_season_test.tsv 
64.925751	-147.880295	2019	
	2017.24	3663.03	
	-12.0213	 10.1818	20.8267	2.65978	
	-20.8948	-2.45078	8.64626	-5.79228
	
	59.07	916.36	218.02	153.82	
	494.28

head -2  NPN_originals_test.tsv
64.925751	-147.880295	2019	2019
	
	439.75	791.55	

	-12.28	9.71    20.72	3.44	
	-20.96	-3.09	8.65	-5.44	

	56		46	218	111	
	105


temps are ballpark but my gdd are way high (wrong units?)
and prcp erratic, range from okay to wtf ... always high ...

okay maybe the precp inconsistency is ...
theirs are only accumulated up to the day of a particular observation (within that season)
mine are for the whole year or season every time
they do however report previous (and later?) seasons in full 

which if so means I can't just generate a single row per year 
but also need to accumulate up to each observation's day.
maybe still useful to keep. 
ML could try crude linear interpolate on "percent of season total to date" 

Checking if Bryan can get NPN's daymet scripts. having the exact method they used to 
roll up seasons is better than me guessing 
(note my zeroth approximation just pretended "seasons" are all 91.25 days long).

-------------------------------------------------------------------------------

putting back filling on hold till after leaves are sampled from currently existing trees.



