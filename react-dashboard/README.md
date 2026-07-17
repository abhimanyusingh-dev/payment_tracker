# Payment Tracker Dashboard

React + Vite dashboard that reads payment rows from Supabase.

## Setup

Copy `.env.local.example` to `.env.local` in this folder and keep your values there:

```bash
cp .env.local.example .env.local
```

Then install and run:

```bash
npm install
npm run dev
```

## Data Source

The dashboard reads from the `public.payment_events` table.

Required columns used by the app:

- `source_id`
- `package_name`
- `app_name`
- `amount`
- `received`
- `payee_name`
- `timestamp`
- `status`
- `transaction_id`
- `reference_id`
- `upi_id`
- `currency`
- `raw_title`
- `raw_body`
- `raw_text`
- `note`
- `masked_account`

## Notes

- This is a personal project setup with direct Supabase reads.
- The dashboard only needs the anon/publishable key because the table has public select policy enabled.
