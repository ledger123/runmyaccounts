ALTER TABLE address
	RENAME COLUMN country TO old_country;
ALTER TABLE address
	RENAME COLUMN city to place;
ALTER TABLE address
	ALTER COLUMN place TYPE varchar(64);
UPDATE address set place = '' where place is null;
ALTER TABLE address
	ALTER COLUMN place SET NOT NULL;
ALTER TABLE address
	RENAME COLUMN zipcode to zip;

ALTER TABLE address
	ADD COLUMN addressline varchar(128),
	ADD COLUMN additional_addressline varchar(64),
	ADD COLUMN post_office varchar(64),
	ADD COLUMN is_migrated boolean,
	ADD COLUMN country varchar(2) NOT NULL DEFAULT '.';

ALTER TABLE shipto
	RENAME COLUMN shiptocountry TO shiptoold_country;
ALTER TABLE shipto
	RENAME COLUMN shiptocity to shiptoplace;
ALTER TABLE shipto
	ALTER COLUMN shiptoplace TYPE varchar(64);
UPDATE shipto set shiptoplace = '' where shiptoplace is null;
ALTER TABLE shipto
	ALTER COLUMN shiptoplace SET NOT NULL;
ALTER TABLE shipto
	RENAME COLUMN shiptozipcode to shiptozip;

ALTER TABLE shipto
	ADD COLUMN shiptoaddressline varchar(128),
	ADD COLUMN shiptoadditional_addressline varchar(64),
	ADD COLUMN shioptopost_office varchar(64),
	ADD COLUMN shiptois_migrated boolean,
	ADD COLUMN shiptocountry varchar(2) NOT NULL;

