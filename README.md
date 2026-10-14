# Book Store eProject

Flutter book shopping application with customer and administrator screens,
Firebase Authentication and Firebase Realtime Database.

## Implementation status

Implementation currently covers the first three phases.
Phase 1 adds persistent catalog, per-account cart/wishlist, owned order history,
atomic Cash on Delivery checkout and protected administrator access.
Phase 2 adds persistent profiles/addresses/preferences/payment methods/reviews,
full catalog editing, forward order status updates and Spark-compatible account
management. The project stays on free services with no billing upgrade.
Combined verification is deferred until implementation is complete.
Phase 3 adds reviewed Cash on Delivery checkout, delivery contact snapshots,
database-validated integer-cent totals, versioned carts, stable order retries and
in-app order notifications.
Checkout selects saved cards and offers **Create payment method** when needed.
Only the card brand, last four digits and expiry are saved. Bank charges are not integrated.
Administrators can pick a book cover from the gallery and preview it before saving.
Covers are stored in the BookStore Supabase project's `book-covers` bucket, with
a 20 MB limit per JPG, PNG or WebP image. The upload function verifies the current
Firebase account and bookstore admin access; image URLs are saved with books in
Firebase. Existing HTTPS cover URLs can also be used.
Live Firebase setup is applied; device verification is tracked separately from
local checks.

## Run locally

Requires Flutter with Dart 3.12.2 or newer and Android SDK (for Android).
Firebase configuration is included for the existing `bookstore-fe6f2` project.
Email/Password Authentication and Realtime Database are used on the Spark plan.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Android and iOS Firebase options are supplied. Web and desktop require their
own Firebase configuration before launching. The old hardcoded administrator
credentials have been removed: use the selected verified owner account, or a
verified account granted a bookstore admin role through protected database flags.

Database rules can be deployed with the Firebase CLI after signing in to an
account with access to the project:

```powershell
firebase deploy --only database --project bookstore-fe6f2
```

## Structure

- `lib/models`: serializable catalog, order and review models.
- `lib/services/auth_service.dart`: authentication and registration profiles.
- `lib/services/store_repository.dart`: Realtime Database reads and writes.
- `lib/services/store_controller.dart`: current account subscriptions and state.
- `lib/services/user_data_service.dart`: per-account profile, addresses and preferences.
- `lib/services/review_service.dart`: persistent reviews and voter-owned likes.
- `lib/services/admin_service.dart`: Spark bookstore membership management.
- `lib/services/account_policy.dart`: protected bootstrap owner identity.
- `lib/widgets/payment_method_editor.dart`: shared saved-card creation from profile and checkout.
- `lib/models/checkout.dart`: immutable checkout quote and delivery request.
- `lib/screens/notifications.dart`: live order inbox with read acknowledgements.
- `lib/screens`: customer flows and admin screens.
- `database.rules.json`: owner isolation and administrator permissions.
- `supabase/functions/upload-book-cover`: Firebase-admin-verified cover uploads.
- `supabase/storage.sql`: public cover bucket configuration with uploads restricted to the server.
- `test`: controller, account isolation, order and login UI tests.

## Outstanding work

Theme finishing, combined verification and final report/video remain in later
phases. Checkout supports Cash on Delivery and saved cards,
with up to 20 different books per order. No live bank/provider payment is processed.
In-app removal blocks bookstore access and clears saved customer data; Firebase
Authentication identities, registration profiles and orders remain. Permanent
Auth deletion is an owner action in Firebase Console. Phases 2/3 have not been tested;
the user requested a single combined verification after implementation.

Detailed documentation, planning notes, sample catalog, setup/verification scripts
and the original requirements brief are
kept locally and excluded from version control. Automated tests use a local
demo emulator. The
owner-authorized live setup deployed database rules, populated the catalog and
promoted the selected existing account on 13 October 2026.
