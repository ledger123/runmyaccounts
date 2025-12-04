-- last_modified column on customer
alter table public.customer
    add column if not exists last_modified timestamptz default current_timestamp;

-- last_modified column on vendor
alter table public.vendor
    add column if not exists last_modified timestamptz default current_timestamp;

-- function to maintain last_modified
create or replace function public.update_last_modified_column()
returns trigger as '
begin
    new.last_modified := now();
    return new;
end;
' language 'plpgsql';
-- end function

-- drop old customer trigger if exists
drop trigger if exists trg_set_last_modified_customer on public.customer;

-- create customer trigger
create trigger trg_set_last_modified_customer
    before update on public.customer
    for each row
    execute function public.update_last_modified_column();
-- end trigger

-- drop old vendor trigger if exists
drop trigger if exists trg_set_last_modified_vendor on public.vendor;

-- create vendor trigger
create trigger trg_set_last_modified_vendor
    before update on public.vendor
    for each row
    execute function public.update_last_modified_column();
-- end trigger


UPDATE defaults SET fldvalue = '2.8.46' WHERE fldname = 'version';