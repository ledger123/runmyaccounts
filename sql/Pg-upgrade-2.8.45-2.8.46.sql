ALTER TABLE public.customer
    ADD COLUMN IF NOT EXISTS last_modified TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE public.vendor
    ADD COLUMN IF NOT EXISTS last_modified TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;

CREATE OR REPLACE FUNCTION public.update_last_modified_column()
    RETURNS TRIGGER AS $$
BEGIN
    NEW.last_modified := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_last_modified_customer ON public.customer;

CREATE TRIGGER trg_set_last_modified_customer
    BEFORE UPDATE ON public.customer
    FOR EACH ROW
EXECUTE FUNCTION public.update_last_modified_column();

DROP TRIGGER IF EXISTS trg_set_last_modified_vendor ON public.vendor;

CREATE TRIGGER trg_set_last_modified_vendor
    BEFORE UPDATE ON public.vendor
    FOR EACH ROW
EXECUTE FUNCTION public.update_last_modified_column();
