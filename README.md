# rentdone

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Production WhatsApp Rent Reminders

Monthly rent reminders to tenants are sent from Cloud Functions based on each
payment due date.

- Function: `sendRentDueWhatsAppReminders`
- Schedule: `09:00, 12:00, 15:00, 18:00, 21:00` (Asia/Kolkata)
- Idempotent: only one successful reminder is stored per payment due day
- Retry: automatic retry for temporary WhatsApp API failures (429/5xx)

### Required Firebase Runtime Config

Set these before deploying:

```bash
firebase functions:config:set whatsapp.token="<META_TOKEN>" whatsapp.phone_number_id="<PHONE_NUMBER_ID>" whatsapp.business_name="RentDone"
```

Optional production settings:

```bash
firebase functions:config:set whatsapp.enabled="true" whatsapp.api_version="v21.0" whatsapp.max_retries="3" whatsapp.template_name="<TEMPLATE_NAME>" whatsapp.template_language="en"
```

If `whatsapp.template_name` is set, reminders use WhatsApp Template messages
(recommended for production). Otherwise, plain text messages are sent.
