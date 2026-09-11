ALTER TABLE xabschluss
    ALTER COLUMN "xml" DROP NOT NULL,
    ADD COLUMN IF NOT EXISTS "data" jsonb,
    ADD COLUMN IF NOT EXISTS "status" TEXT DEFAULT 'NEW';

ALTER TABLE xabschluss_history
    ALTER COLUMN "xml" DROP NOT NULL,
    ADD COLUMN IF NOT EXISTS "data" jsonb;

UPDATE defaults SET fldvalue = '2.8.52' WHERE fldname = 'version';