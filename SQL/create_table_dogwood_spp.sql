drop table if exists dogwood_spp;

create table dogwood_spp (
	site_id integer ,
	latitude float NOT NULL,
	longitude float NOT NULL, -- defer casting as geom/geog Point for now
	elevation_in_meters integer ,
	state text ,

	species_id integer ,
	genus text ,
	species text ,
	common_name text ,
	kingdom text ,
	individual_id integer ,

	phenophase_id integer ,
	phenophase_description text ,
	first_yes_year integer ,
	first_yes_month integer ,
	first_yes_day integer ,
	first_yes_doy integer ,
	first_yes_julian_date integer ,
	numdays_since_prior_no integer ,
	last_yes_year integer ,
	last_yes_month integer ,
	last_yes_day integer ,
	last_yes_doy integer ,
	last_yes_julian_date integer ,
	numdays_until_next_no integer
);

\copy dogwood_spp from '/home/tomc/Projects/GenoPhenoEnvo/GitHub/NPN-Data/dogwood_spp_4-27-21.csv' DELIMITER ',' QUOTE '"' CSV HEADER

alter table dogwood_spp add column location geometry(Point,4326);

update dogwood_spp set location = ST_SetSRID(ST_MakePoint(longitude,latitude),4326);


create index dogwood_spp_location_gidx on dogwood_spp using gist(location);
create index dogwood_spp_site_id_idx on dogwood_spp using btree(site_id);
create index dogwood_spp_common_name_idx on dogwood_spp using btree(common_name);
create index dogwood_spp_phenophase_id_idx on dogwood_spp using btree(phenophase_id);


