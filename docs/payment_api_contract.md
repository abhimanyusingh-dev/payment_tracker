# Payment API Contract

This project normalizes payment notifications into a single payment event shape that both the mobile app and the React web app can use.

## Write Path

`POST /payments`

Request body:

```json
{
  "source_id": "9af3adcc10cd2",
  "package_name": "com.phonepe.app",
  "app_name": "PhonePe",
  "amount": 1,
  "received": true,
  "payee_name": "ABHIMANYU SINGH",
  "timestamp": "2026-07-17T08:33:48.083Z",
  "status": "success",
  "transaction_id": "12345",
  "reference_id": "12345",
  "upi_id": "raju@upi",
  "currency": "INR",
  "raw_title": "Payment received",
  "raw_body": "ABHIMANYU SINGH has sent ₹1 to your bank account...",
  "raw_text": "Payment received | ...",
  "note": "Tea order",
  "masked_account": "HDFC Bank-8039"
}
```

Behavior:
- `received` is `true` when the payment was credited
- `source_id` must be unique and is used for deduplication
- The backend should accept repeated inserts for the same `source_id` and ignore duplicates

## Read Path

`GET /payments`

Optional query params:
- `from=2026-07-01T00:00:00Z`
- `to=2026-07-31T23:59:59Z`
- `app_name=PhonePe`
- `received=true`

Response body:

```json
[
  {
    "source_id": "9af3adcc10cd2",
    "package_name": "com.phonepe.app",
    "app_name": "PhonePe",
    "amount": 1,
    "received": true,
    "payee_name": "ABHIMANYU SINGH",
    "timestamp": "2026-07-17T08:33:48.083Z",
    "status": "success"
  }
]
```

## Recommended Table Fields

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
- `created_at`

## Environment Variables For Flutter

You can configure the app with either of these modes:

- Generic API:
  - `PAYMENT_API_BASE_URL`
  - `PAYMENT_API_TOKEN` optional
- Supabase REST:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`

Example:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```
