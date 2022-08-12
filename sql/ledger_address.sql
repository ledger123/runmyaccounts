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
	ADD COLUMN country varchar(2) NOT NULL;