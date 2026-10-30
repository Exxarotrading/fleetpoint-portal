# Fleetpoint Africa Client Portal — starter MVP

## Included
- Multi-organisation PostgreSQL schema for Supabase.
- Roles: fleetpoint_admin, client_admin, fleet_manager, finance, viewer.
- Vehicle register and central seven-category cost ledger.
- Dedicated tables for fuel, fines, insurance, maintenance, tracking, finance, compliance and documents.
- Organisation-level Row Level Security (RLS).
- Minimal React/Vite sign-in and workspace starter (see `src/App.tsx`).

## Setup
1. Create a Supabase project.
2. Run `supabase/schema.sql` in Supabase SQL Editor.
3. Create a test user in Authentication → Users.
4. Copy that user's UUID. Insert an organisation:
   `insert into public.organizations(name) values ('Demo Client') returning id;`
5. Use returned organisation UUID and auth user UUID:
   `insert into public.memberships(organization_id,user_id,role) values ('ORG_UUID','USER_UUID','client_admin');`
6. Copy `.env.example` to `.env.local`, add Supabase Project URL and publishable/anon key.
7. Run `npm install`, then `npm run dev`.

Never put the Supabase service-role key in the browser. This is a development MVP, not yet ready for paying clients. Before launch, add server-side invitations, table-specific permissions, private Storage policies, audit triggers, MFA for admins, backup/restore tests, upload validation, POPIA notices and tenant-isolation tests.

The starter UI is a first-stage shell. The database includes all required business modules; dedicated module forms, document uploads, recurring-cost schedules, alerts, exports and reporting are the next implementation milestones.
