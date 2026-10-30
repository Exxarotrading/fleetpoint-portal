create extension if not exists pgcrypto;
create type public.member_role as enum ('fleetpoint_admin','client_admin','fleet_manager','finance','viewer');
create type public.cost_category as enum ('fuel','fines','insurance','maintenance','tracking','licensing','installments');
create type public.vehicle_status as enum ('active','maintenance','inactive');

create table public.organizations (
 id uuid primary key default gen_random_uuid(), name text not null,
 legal_name text, contact_email text, contact_phone text, created_at timestamptz default now()
);
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text, phone text, created_at timestamptz default now()
);
create table public.memberships (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role public.member_role not null default 'viewer', is_active boolean not null default true,
 unique(organization_id,user_id)
);
create table public.vehicles (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 registration text not null, make text not null, model text not null, year int,
 vin text, engine_number text, asset_number text, department text, project text,
 assigned_driver text, odometer_km numeric(12,1),
 status public.vehicle_status not null default 'active',
 created_at timestamptz default now(), updated_at timestamptz default now(),
 unique(organization_id,registration)
);
create table public.cost_entries (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 vehicle_id uuid references public.vehicles(id) on delete set null,
 category public.cost_category not null, amount numeric(14,2) not null check(amount>=0),
 transaction_date date not null, description text, reference text, supplier text,
 created_by uuid references auth.users(id), created_at timestamptz default now()
);
create table public.fuel_transactions (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 vehicle_id uuid not null references public.vehicles(id) on delete cascade,
 transaction_date date not null, litres numeric(12,2) not null check(litres>0),
 price_per_litre numeric(12,3) not null check(price_per_litre>=0),
 total_amount numeric(14,2) not null check(total_amount>=0),
 odometer_km numeric(12,1), fuel_station text, fuel_card_last4 text, receipt_path text,
 created_at timestamptz default now()
);
create table public.fines (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 vehicle_id uuid references public.vehicles(id) on delete set null,
 driver_name text, infringement_number text, infringement_date date not null,
 due_date date, amount numeric(14,2) not null check(amount>=0),
 status text not null default 'outstanding' check(status in ('outstanding','disputed','paid','deducted')),
 payroll_reference text, proof_path text, created_at timestamptz default now()
);
create table public.insurance_policies (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 vehicle_id uuid references public.vehicles(id) on delete cascade,
 insurer text not null, policy_number text, monthly_premium numeric(14,2) not null default 0,
 excess_amount numeric(14,2), start_date date, renewal_date date, policy_document_path text,
 created_at timestamptz default now()
);
create table public.maintenance_records (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 vehicle_id uuid not null references public.vehicles(id) on delete cascade,
 record_type text not null default 'repair', service_date date not null, odometer_km numeric(12,1),
 supplier text, description text, parts_cost numeric(14,2) default 0, labour_cost numeric(14,2) default 0,
 next_service_date date, invoice_path text, created_at timestamptz default now()
);
create table public.tracking_contracts (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 vehicle_id uuid references public.vehicles(id) on delete cascade,
 provider text not null, device_reference text, monthly_fee numeric(14,2) not null default 0,
 contract_start date, contract_end date, created_at timestamptz default now()
);
create table public.vehicle_finance (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 vehicle_id uuid not null references public.vehicles(id) on delete cascade,
 finance_provider text not null, agreement_number text,
 monthly_installment numeric(14,2) not null default 0, settlement_balance numeric(14,2),
 start_date date, end_date date, is_paid_off boolean default false, created_at timestamptz default now()
);
create table public.compliance_records (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 vehicle_id uuid not null references public.vehicles(id) on delete cascade,
 record_type text not null check(record_type in ('licence_disc','cof','permit','roadworthiness','other')),
 reference text, expiry_date date, document_path text, notes text, created_at timestamptz default now()
);
create table public.documents (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 vehicle_id uuid references public.vehicles(id) on delete set null,
 category text not null, file_name text not null, storage_path text not null,
 uploaded_by uuid references auth.users(id), created_at timestamptz default now()
);

create or replace function public.is_org_member(org_id uuid) returns boolean
language sql stable security definer set search_path=public
as $$ select exists(select 1 from memberships where organization_id=org_id and user_id=auth.uid() and is_active); $$;
create or replace function public.has_org_role(org_id uuid, allowed public.member_role[]) returns boolean
language sql stable security definer set search_path=public
as $$ select exists(select 1 from memberships where organization_id=org_id and user_id=auth.uid() and is_active and role=any(allowed)); $$;
create or replace function public.can_edit_org(org_id uuid) returns boolean
language sql stable security definer set search_path=public
as $$ select public.has_org_role(org_id,array['fleetpoint_admin','client_admin','fleet_manager','finance']::public.member_role[]); $$;

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.memberships enable row level security;
create policy "read own orgs" on public.organizations for select using(public.is_org_member(id));
create policy "read memberships" on public.memberships for select using(user_id=auth.uid() or public.is_org_member(organization_id));
create policy "read own profile" on public.profiles for select using(id=auth.uid());
create policy "update own profile" on public.profiles for update using(id=auth.uid()) with check(id=auth.uid());

do $$
declare t text;
begin
 foreach t in array array['vehicles','cost_entries','fuel_transactions','fines','insurance_policies','maintenance_records','tracking_contracts','vehicle_finance','compliance_records','documents'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('create policy "tenant read" on public.%I for select using(public.is_org_member(organization_id))',t);
  execute format('create policy "tenant insert" on public.%I for insert with check(public.can_edit_org(organization_id))',t);
  execute format('create policy "tenant update" on public.%I for update using(public.can_edit_org(organization_id)) with check(public.can_edit_org(organization_id))',t);
  execute format('create policy "tenant delete" on public.%I for delete using(public.has_org_role(organization_id,array[''fleetpoint_admin'',''client_admin'']::public.member_role[]))',t);
 end loop;
end $$;

-- Prevent linking a record to another organisation's vehicle.
create or replace function public.check_vehicle_org() returns trigger language plpgsql set search_path=public as $$
begin
 if new.vehicle_id is not null and not exists(select 1 from public.vehicles where id=new.vehicle_id and organization_id=new.organization_id)
 then raise exception 'Vehicle does not belong to this organisation'; end if;
 return new;
end $$;
do $$ declare t text; begin
 foreach t in array array['cost_entries','fuel_transactions','fines','insurance_policies','maintenance_records','tracking_contracts','vehicle_finance','compliance_records','documents'] loop
 execute format('create trigger %I before insert or update on public.%I for each row execute function public.check_vehicle_org()', 'check_vehicle_org_'||t,t);
 end loop;
end $$;

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name','')); return new; end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
