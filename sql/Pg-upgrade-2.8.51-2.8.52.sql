CREATE TABLE IF NOT EXISTS xabschluss (
    id serial NOT NULL,
    name text NOT NULL,
    period_from date NOT NULL,
    period_to date NOT NULL,
    last_updated timestamp NULL DEFAULT now(),
    last_booked timestamp NULL,
    xml text NOT NULL
);

CREATE TABLE IF NOT EXISTS xabschluss_buchungen (
    abschluss_ref int NOT NULL,
    ledger char(2) NOT NULL,
    is_rueckbuchung bool,
    reference text NOT NULL
);

CREATE TABLE IF NOT EXISTS xabschluss_history (
    abschluss_ref int NOT NULL,
    last_updated timestamp NULL DEFAULT now(),
    xml text NOT NULL
);

ALTER TABLE xabschluss
    ALTER COLUMN "xml" DROP NOT NULL,
    ADD COLUMN IF NOT EXISTS "data" jsonb,
    ADD COLUMN IF NOT EXISTS "status" TEXT DEFAULT 'NEW';

ALTER TABLE xabschluss_history
    ALTER COLUMN "xml" DROP NOT NULL,
    ADD COLUMN IF NOT EXISTS "data" jsonb;

UPDATE defaults SET fldvalue = '2.8.52' WHERE fldname = 'version';