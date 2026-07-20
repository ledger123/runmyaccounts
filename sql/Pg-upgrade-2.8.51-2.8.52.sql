ALTER TABLE xabschluss
    ALTER COLUMN "xml" DROP NOT NULL,
    ADD COLUMN "data" jsonb,
    ADD COLUMN "status" TEXT DEFAULT 'NEW';

ALTER TABLE xabschluss_history
    ALTER COLUMN "xml" DROP NOT NULL,
    ADD COLUMN "data" jsonb;

UPDATE defaults SET fldvalue = '2.8.52' WHERE fldname = 'version';