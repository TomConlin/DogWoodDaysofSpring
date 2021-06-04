
The first soil set I went after ultimately could not get 
without sending them a hard drive and cash. ($280 I think it was)

Fetched multipart zip from  ... frickin box ...
https://nrcs.app.box.com/v/soils/folder/125622952915

Lost a day figuring out the vector section is just dummy files.


The raster files, geotiffs, load into QGIS and are viewable just fine.


 ls -lh Soil/CONUS_GeoTiff/*.tif
-rw-rw-r-- 1 tomc tomc 73M May  9  2018 CONUS_GeoTiff/CONUS_005cm.tif
-rw-rw-r-- 1 tomc tomc 76M May  9  2018 CONUS_GeoTiff/CONUS_010cm.tif
-rw-rw-r-- 1 tomc tomc 80M May  9  2018 CONUS_GeoTiff/CONUS_015cm.tif
-rw-rw-r-- 1 tomc tomc 87M May  9  2018 CONUS_GeoTiff/CONUS_025cm.tif
-rw-rw-r-- 1 tomc tomc 91M May  9  2018 CONUS_GeoTiff/CONUS_050cm.tif
-rw-rw-r-- 1 tomc tomc 93M May  9  2018 CONUS_GeoTiff/CONUS_075cm.tif
-rw-rw-r-- 1 tomc tomc 93M May  9  2018 CONUS_GeoTiff/CONUS_100cm.tif
-rw-rw-r-- 1 tomc tomc 94M Oct 24  2018 CONUS_GeoTiff/CONUS_125cm.tif
-rw-rw-r-- 1 tomc tomc 90M May  9  2018 CONUS_GeoTiff/CONUS_brigh.tif


loading the geotifs into QGIS directly I came up with SRID 5072
as alternatives looked worse, but that is hardily definitive


There is a `metadata.xml` file alongside the geotifs 

get an overview.

```
xmlstarlet el -u  Soil/CONUS_GeoTiff/metadata.xml
```

"metadata/spref" looks promising

```
xmlstarlet sel -t -v ./metadata/spref  Soil/CONUS_GeoTiff/metadata.xml

    
      
        
			Albers Conical Equal Area
				
					29.5
					45.5
					-96.0
					23.0
					0.0
					0.0
				
        
203.948243779212		meters
      
      
        North American Datum of 1983
        Geodetic Reference System 80
        6378137.0
        298.257222101
```

searching on:

SRID "Albers Conical Equal Area" "North American Datum of 1983" "Geodetic Reference System 8"

gets (as first hit):
http://epsg.io/102008   
	ESRI:102008
	North America Albers Equal Area Conic
 

plugging that into  https://spatialreference.org

... does not return a srid.

see if it exists in postgis

```
select * 
from spatial_ref_sys
 where auth_name =  'esri' 
   and auth_srid = 102008
;
```
nothing, seems like a pretty major omission

```
select * 
from spatial_ref_sys
 where auth_name ilike  'esri' 
   and auth_srid = 102008
;
```

there it is,  hmmm. srid 102008 


see: https://spatialreference.org/ref/esri/102008/postgis/
note-well: 
	it is builtin to postgis with the a different srid number  
	than spatialreference.org is reporting wanting to give it (9102008)
    luckily ref-constraints prevented inserting the second.


pixels are just over 200m square, 
if we wanted to do tiling (ala cloud optimized geotif)
we would need to determine a size  `-t 20x20` or something  ...
and we do anyway because:
```
	WARNING: The size of each output tile may exceed 1 GB
```

What is a good tile size for getting them in?

```
file Soil/CONUS_GeoTiff/CONUS_125cm.tif
Soil/CONUS_GeoTiff/CONUS_125cm.tif: TIFF image data, little-endian, direntries=21, 
	height=14732, bps=266, compression=LZW, PhotometricIntepretation=RGB, 
	width=24182

factor 24182
24182: 2 107 113

factor 14732
14732: 2 2 29 127

```

... and people wonder why I use the shell



```
time \
for gtf in Soil/CONUS_GeoTiff/*.tif ; do
	bn=$(basename $gtf .tif);
    raster2pgsql -I -M -C -s 102008 $gtf soil_${bn##*_} -t 113x127 > Soil/gNATSGO/soil_${bn##*_}.sql
done

```
converting takes about ...six minutes

load into gpe db

```
\time
for f in Soil/gNATSGO/*.sql ; do
    psql -d gpe -f $f
done

```

ERROR:  type "raster" does not exist

apparently it is a separate postgis extension

```
echo "CREATE EXTENSION postgis_raster;" | sudo -u postgres psql gpe
```

try again: ... about 7.5 minutes to load & index


there is a table for each depth,
tables have two columns a serial PK 'rid' and an opaque 'raster' blob 
which must be where the magic happens.

```
select count(rid) from soil_050cm;

 count 
-------
 13,720
```

about 14k tiles to cover contus.



what do the soil values at our locations look like

```
select distinct site_id, ST_Value(rast, ST_SetSRID(location,102008)) five_cm
  from soil_005cm, dogwood_spp
;
```

hmmm. every tile, that a point is not in, complains if you look.


select  distinct site_id, ST_Value(rast, ST_SetSRID(location,102008)) five_cm
 from soil_005cm, dogwood_spp 
 where ST_Intersects(ST_SetSRID(location,102008), rast)
;

-- it is not a fast query. must be doing a full cross join for each point ... kill

-- make an intersection table so we only need to do it once.

```
select site_id, rid as tile_rid
 into  int_npn_soil
from dogwood_spp join soil_005cm on ST_Intersects(ST_SetSRID(location,102008), rast);

```

21 minutes ... zero rows, not good. a point with the same SRID is still not a raster


select site_id, rid as tile_rid
 into  int_npn_soil
from dogwood_spp join soil_005cm on ST_Intersects(rast, ST_SetSRID(location,102008));


select site_id, rid as tile_rid
into  int_npn_soil
from dogwood_spp join soil_005cm on 
	not ST_Disjoint(rast, ST_AsRaster(ST_SetSRID(location,102008),0.1,0.1))
;



the 0.1 is chosen on the guesstimation gps coords are good to  ~70 feet 
(from back in geocaching days)  so call it 20-meters which is about 1/10th of 
a 200m pixel in the raster

wonder if the rasters tiles for each of the depths will have the same rid pks 
for the same locations  ('rid' look plausible)

