# Multi-tenant rollout roadmap

This project is being upgraded from single-store to multi-store (SaaS-ready).

## ✅ Done (Phase 1 foundation)

- Added `stores` table
- Added `store_members` table
- Added `store_id` to core business tables
- Added helper SQL functions:
  - `get_default_store_id()`
  - `is_member_of_store(target_store uuid)`

Migration file:
- `database/migrations/001_multi_tenant_foundation.sql`

## Next (Phase 2)

1. Backfill existing data into a default store
2. Set `store_id NOT NULL` where appropriate
3. Update RLS policies to tenant scope:
   - read/write only rows in stores the user is member of
4. Update API/UI to always pass store context

## Next (Phase 3)

- Add owner/manager/staff permissions per store
- Add onboarding flow: create store + invite members
- Add billing plan limits by store
