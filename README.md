# Book Store Mobile Application

**Aptech eProject, Semester 5 · Aptech Scheme 33 · Batch 2407D**

Book Store is a Flutter application for browsing books, saving a wishlist, managing a shopping cart and placing orders. Customers manage their own profiles, delivery addresses, saved payment methods, reviews and order history. Administrators maintain the catalog, upload book pictures, manage bookstore access and update delivery stages.

The application uses **Firebase Authentication**, **Firebase Realtime Database**, and **Supabase Storage with an Edge Function** for book covers. The configured services use Firebase **Spark** and Supabase **Free**. Firebase Cloud Functions and a billing upgrade are not required by this implementation; provider quotas still apply.

**Repository:** [hasnaintanoli/BookStore](https://github.com/hasnaintanoli/BookStore)

**Documented Android assessment build:** **1.0.5**, version code **6**

**README updated:** 14 October 2026

## Contents

- [Start here: checker instructions](#start-here-checker-instructions)
- [Features](#features)
- [Requirements and platforms](#requirements-and-platforms)
- [Clone and run](#clone-and-run)
- [Accounts and administrator access](#accounts-and-administrator-access)
- [Customer walkthrough](#customer-walkthrough)
- [Administrator walkthrough](#administrator-walkthrough)
- [Checkout and order behavior](#checkout-and-order-behavior)
- [Architecture and source structure](#architecture-and-source-structure)
- [Database structure](#database-structure)
- [Firebase setup](#firebase-setup)
- [Supabase cover storage setup](#supabase-cover-storage-setup)
- [Android APK build and installation](#android-apk-build-and-installation)
- [Testing and verification](#testing-and-verification)
- [Troubleshooting](#troubleshooting)
- [Current scope](#current-scope)
- [Submission files](#submission-files)
- [Team](#team)
- [Official references](#official-references)

## Start here: checker instructions

1. Use an **Android device or emulator with internet access**. Android is the platform with a recorded release build.
2. Install the APK supplied separately with the submission, or follow [Clone and run](#clone-and-run) to run the source. APKs are not stored in this repository.
3. For customer evaluation, choose **Create Account**, use an accessible email inbox, open the verification link and then sign in. Registration requires email verification before access.
4. For administrator evaluation, use a verified admin account supplied privately by the team, or ask an existing administrator to grant access to your registered account. The selected owner email is `aptechschemework@gmail.com`; its password is not published here.
5. Follow the customer/admin walkthroughs below. Checkout writes orders and admin edits change the shared online catalog. Use clearly named evaluation records and keep the existing project data in mind.

The included client configuration connects to the existing project. **A checker does not need cloud dashboard access, service credentials or a new deployment to run the app.** Cloud owner access is needed only for deployment, initial admin provisioning or configuring a separate environment.

## Features

### Customer

| Area | Implemented behavior |
| --- | --- |
| Authentication | Email/password registration, verification, sign-in/out, session restoration and password recovery. |
| Discovery | Home sections, title/author/category search, category/author filters, popularity/price/newest sorting and book details. |
| Wishlist and cart | Account-owned saved books, quantities, removal and missing-catalog-item handling. |
| Checkout | Delivery contact, order review, `SAVE10`, Cash on Delivery or selected saved card, and a saved-order receipt. |
| Payment methods | Create from Profile or checkout; save brand, last four digits and expiry. |
| Profile and addresses | Edit name/phone, request verified email changes, create/edit/remove delivery addresses. |
| Orders | Owned history, preserved purchase/delivery/card details, totals and current delivery stages. |
| Reviews | One editable 1–5 star review per account/book, comments and user-owned review likes. |
| Notifications | In-app order inbox, read acknowledgements and new unread updates after stage changes. |
| Settings and help | Persistent preferences, shared light/dark styling across customer/admin screens and sheets, Help & FAQ. |

### Administrator

| Area | Implemented behavior |
| --- | --- |
| Dashboard | Catalog/profile/order counts, aggregate order value and recent orders. |
| Catalog | Search, add, edit and delete books; maintain title, author, price, genre, description and release date. |
| Book pictures | Gallery selection, preview and upload on Save book, or an existing HTTPS cover URL. |
| User management | Search profiles, grant/revoke bookstore admin access, block/unblock and remove/restore membership. |
| Order management | Inspect orders and advance their stages through the permitted sequence. |
| Own account | Shared profile editing, settings and sign-out. |

Card checkout records a selected payment-method reference and order snapshot. **A payment gateway or real bank charge is not integrated.** The receipt confirms that the order was saved. Dashboard order value sums recorded order totals; it is not a settlement ledger.

## Requirements and platforms

| Requirement | Details |
| --- | --- |
| Flutter/Dart | Flutter with Dart compatible with `^3.12.2` (`>=3.12.2 <4.0.0`). The recorded build used Flutter 3.47.5 / Dart 3.13.4. |
| Android tools | Android SDK/platform-tools and a Java 17-compatible build environment. Inspect `flutter doctor -v`. |
| Device | Android phone with USB debugging or an emulator. The recorded APK requires Android 7.0 / API 24 or newer. |
| Network | Required for authentication, live records, checkout and uploads; also for initial dependency/build downloads. |
| Editor | Android Studio or VS Code is convenient but optional if the SDK/CLI is configured. |
| Cloud CLIs | Firebase, FlutterFire and Supabase CLIs are for maintenance/separate deployment, not ordinary app evaluation. |

The included Gradle wrapper uses Gradle 9.3.1. Android SDK levels come from the installed Flutter SDK; the recorded APK used compile/target API 36 and minimum API 24.

Android and iOS Firebase options are included. iOS needs macOS/Xcode and separate build/device evaluation. Web, Windows, macOS and Linux are not configured in `DefaultFirebaseOptions.currentPlatform`; their scaffold folders do not make those targets ready to run.

## Clone and run

Run from a terminal with Git and Flutter available:

```powershell
git clone https://github.com/hasnaintanoli/BookStore.git
cd BookStore
flutter --version
flutter doctor -v
flutter pub get
flutter devices
```

If `flutter doctor` reports unaccepted Android SDK licenses, run `flutter doctor --android-licenses`, read/accept the required licenses, then run `flutter doctor -v` again. Use Android Studio's SDK Manager to install any missing SDK/platform-tools version it reports.

Connect a phone or start an Android emulator, then use its ID from `flutter devices`:

```powershell
flutter run -d DEVICE_ID
```

Replace `DEVICE_ID` with the actual ID. With one Android target, `flutter run` can select it. With multiple targets, select Android explicitly rather than Chrome or Windows.

Keep `pubspec.lock` for consistent dependency resolution. No app `.env` file is required for the included configuration. Books, covers and user records load from the hosted services; the fresh-clone run does not depend on ignored fixtures or helper scripts.

## Accounts and administrator access

### Customer sign-in

Registration creates a Firebase Email/Password identity and `/users/{uid}` profile, sends verification and signs out. Verify the email before signing in. **Forgot Password** sends a password-reset email; the login flow also supports resending verification.

A verified customer enters the customer shell. A verified effective administrator enters the dashboard. The app restores eligible saved sessions at startup. No hardcoded admin password is required.

### Admin permission and the Firebase profile role

`/users/{uid}/role` is registration metadata. It can remain `Customer` while the account has effective administrator permission. Editing this string does not grant access.

Actual authority uses protected `/accountAccess/{uid}` flags (`admin`, `disabled`, `removed`) or the exact bootstrap owner's server-issued `admin` claim. Verified email and active membership are also required.

An existing admin grants another active registered account access through **Manage users**. Refresh the session after access/token changes if necessary. The acting admin and configured bootstrap owner are protected against in-app self-demotion, blocking and removal.

### Blocking and removal

- Blocking revokes bookstore access until unblocked.
- Removing membership revokes access and clears owned saved app data: cart, wishlist, addresses, cards, preferences and read markers.
- Registration profiles, Firebase Authentication identities and historical orders remain.
- Restoring membership grants customer access; it does not recreate cleared data.
- Permanent Auth deletion is an authorized owner operation in Firebase Console.

## Customer walkthrough

1. **Sign in:** verify your email. The bottom bar contains Home, Browse, Saved and Profile.
2. **Find a book:** search/filter/sort, open its details and inspect description/reviews.
3. **Save and add:** use the heart to save, add to cart and adjust quantity.
4. **Manage account data:** edit name/phone, save an address and inspect Settings. An email change requires the current password, new-email verification and a later sign-in to synchronize the profile email.
5. **Create a payment method:** open Profile → Payment Methods, or choose online/card payment at checkout. Without an eligible method, checkout offers **Create payment method**. Select Visa, Mastercard or American Express; enter exactly four ending digits and a non-expired `MM/YY` expiry. A full card number/CVV is not requested.
6. **Checkout:** complete delivery name/phone/address/area/city, select Cash on Delivery or an eligible saved card, review totals and submit. `SAVE10` is the supported 10% promotion; other codes are rejected.
7. **Inspect the receipt:** wait for the saved-order acknowledgement. Open Profile → Your Orders for purchase details and stage.
8. **Read updates:** after an admin advances the stage, open Order notifications and acknowledge it. A subsequent stage change can create another unread update.
9. **Review:** create/update a review and like a review. Records persist under the signed-in account.
10. **Check persistence:** change dark mode, restart/sign in and inspect saved data/settings. Sign out before evaluating another customer's isolated data.

## Administrator walkthrough

1. Sign in with verified admin access. Open **Books**, **Users**, **Orders** or **My profile** from the dashboard.
2. In Books, choose **Add**, enter required fields/release date and choose **Pick book picture**. Inspect the preview and press **Save book**. An HTTPS image URL is also supported.
3. View the book as a customer; inspect its cover/details. Search/edit the record. For deletion evaluation, delete a record created for that purpose.
4. In Users, search a registered evaluation account. Inspect role/access, then evaluate changes with an account whose data may be changed or cleared.
5. In Orders, inspect an order's snapshots/totals and use **Change status** to advance one permitted stage. Check customer history/notifications afterward.
6. Edit your own profile/settings and sign out.

Images accept **JPEG, PNG or WebP**, up to **20 MiB (20 × 1024 × 1024 bytes)** per file. The picker requests a maximum 1600 × 1600 size and quality 85 where supported. Upload starts on **Save book**. If upload succeeds but the Firebase save fails, the editor retains the URL for a retry. Android picker recovery can recover a picture after process loss; unsaved book fields may need re-entry.

## Checkout and order behavior

- Orders support **1–20 distinct books**, with **1–99 copies** per line. Remove missing/deleted catalog books before checkout.
- Totals use integer cents. `SAVE10` has a fixed discount/rounding rule validated by database rules.
- Cart epoch/revision and account UID produce a stable order ID so retries can return the existing receipt.
- One atomic database update creates the order, removes purchased cart entries and advances the revision. Rules validate current cart/catalog, snapshots, totals and the owned selected card.
- Purchased book, delivery and selected-card values are copied to the order. Later source changes do not rewrite history.
- Stages move forward only: **Ordered → Processing → Shipped → Out for delivery → Delivered**. Customers read owned orders; admins advance stages.
- The inbox derives from live orders/read markers. Preferences control in-app alerts; background push/email sending and courier tracking are separate future integrations.

Home popularity/bestseller ranking uses stored book ratings; Newest uses `releaseDate`. Detail review averages derive from submitted reviews and do not automatically replace catalog ratings. There is no inventory/stock ledger or book availability-status field.

## Architecture and source structure

```text
Flutter screens/widgets → Services/StoreController → Firebase Auth + Realtime Database

Admin picture + Firebase token → upload-book-cover → Supabase image URL → Firebase book
```

Controllers bind records to the current account; repositories/services perform persistence. Account changes clear old state/subscriptions. Database rules and the upload function enforce permissions independently of visible UI controls.

| Source | Responsibility |
| --- | --- |
| `lib/main.dart` | Initialization, routing, themes, sessions and alert integration. |
| `lib/firebase_options.dart`, `lib/supabase_config.dart` | Generated Firebase options and public Supabase configuration. |
| `lib/models/book.dart`, `lib/models/checkout.dart` | Serializable records, reviewed quotes, validation and snapshots. |
| `lib/screens/` | Login/auth gate, home/browse, wishlist/cart/checkout, profile and inbox. |
| `lib/screens/admin/` | Dashboard and book/user/order management. |
| `lib/services/auth_service.dart`, `account_policy.dart` | Identity, registration and protected owner policy. |
| `lib/services/store_controller.dart`, `store_repository.dart` | Account-bound shopping state, streams and atomic/transactional writes. |
| `lib/services/user_data_service.dart`, `review_service.dart` | Profiles/saved data/preferences, reviews and voter-owned likes. |
| `lib/services/admin_service.dart` | Spark-compatible bookstore membership operations. |
| `lib/services/book_cover_service.dart` | Gallery input and authenticated upload. |
| `lib/widgets/`, `lib/theme/book_theme.dart` | Reusable forms/details/editor sheets and semantic light/dark colors. |
| `database.rules.json` | Database authorization, schema/totals and stage validation. |
| `firebase.json`, `.firebaserc` | Project mapping and rule deployment configuration. |
| `supabase/config.toml`, `supabase/storage.sql` | Function verification setting, public cover bucket and upload design. |
| `supabase/functions/upload-book-cover/index.ts` | Firebase-token/admin verification and privileged server upload. |
| `test/` | Flutter unit/controller/widget tests. |
| `android/`, `ios/`, `pubspec.yaml`, `pubspec.lock` | Mobile platform sources and dependencies. |

Realtime Database is the active bookstore database. Firestore, Firebase Storage and Messaging packages remain in the manifest, but persistence, gallery covers and order alerts use the services described above.

## Database structure

Firebase is a JSON tree. Path keys form logical identities, not SQL primary/foreign-key constraints.

| Location | Contents |
| --- | --- |
| Firebase Authentication | Managed identities, verified emails, passwords and tokens; passwords are not in Realtime Database. |
| `/users/{uid}` | UID, name, email, phone, role metadata and creation date. |
| `/accountAccess/{uid}` | Protected admin/disabled/removed flags. |
| `/books/{bookId}` | Title, author, price, rating, category, image URL, description and release date. |
| `/customerData/{uid}/cart` | Book ID → quantity, `_epoch`, `_version`. |
| `/customerData/{uid}/wishlist/{bookId}` | Saved-book `true` marker. |
| `/customerData/{uid}/addresses/{id}` | Name, phone, address, area and city. |
| `/customerData/{uid}/paymentMethods/{id}` | Brand, last four digits and expiry. |
| `/customerData/{uid}/preferences` | `darkMode`, `pushNotifications`, `emailOffers`. |
| `/customerData/{uid}/orderReadStatus/{orderId}` | Last acknowledged stage string. |
| `/orders/{orderId}` | Owner, stage/date, totals, payment selection, cart identity, items and preserved book/delivery/card snapshots. |
| `/bookReviews/{bookId}/{uid}` | One review per user/book: user, rating, comment and update date. |
| `/reviewLikes/{bookId}/{reviewId}/{uid}` | Voter-owned `true` marker. |
| Supabase `book-covers/{uid}/{hash}.{ext}` | Public file, uploader prefix and content-addressed filename. |

Old orders retain read compatibility; new checkout saves the current schema. Counts, review averages and the inbox are calculated from records, rather than additional stored entities.

## Firebase setup

### Included environment

| Setting | Value |
| --- | --- |
| Project | `bookstore-fe6f2` |
| Database URL | `https://bookstore-fe6f2-default-rtdb.firebaseio.com` |
| Authentication / plan | Email/Password / Spark |
| Android application ID | `com.example.bookstore` |

Public client settings identify the service; they do not grant Console or admin access. An authorized owner maintaining this environment can install the [Firebase CLI](https://firebase.google.com/docs/cli), sign in and deploy checked-in rules:

```powershell
firebase login
firebase deploy --only database --project bookstore-fe6f2
```

Check the target project before deployment. A shutdown error after a deployment message requires an independent comparison of published rules with `database.rules.json`; the message alone does not establish deployment state.

### Optional: separately owned Firebase project

1. Create/select a Spark project, enable Email/Password Authentication and create Realtime Database with protected rules.
2. Follow [FlutterFire setup](https://firebase.google.com/docs/flutter/setup), then configure the project from the repository root:

   ```powershell
   dart pub global activate flutterfire_cli
   flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID --platforms=android,ios
   ```

3. Change `AuthService.databaseUrl` in `lib/services/auth_service.dart` to your exact Console database URL. Check generated/platform configuration, `.firebaserc` and `firebase.json` for the same project.
4. Register/verify the first admin through the app. Get its UID from Firebase Authentication. Using trusted project-owner Console access, create `/accountAccess/{thatUid}` with `admin: true`, `disabled: false`, `removed: false`. The account needs its app-created `/users/{uid}` profile. No Firebase Cloud Function is needed for this initial provisioning.
5. If transferring the protected bootstrap-owner identity, replace its UID consistently in `lib/services/account_policy.dart`, every owner comparison in `database.rules.json`, and `OWNER_UID` in the upload function. The claim fallback additionally needs a server-issued `admin: true` claim; other admins use protected flags.
6. Deploy matching rules using your actual project ID. Set the Supabase function's `FIREBASE_PROJECT` and `DATABASE_URL` to this same Firebase environment before testing uploads.

An app account cannot grant itself admin flags. Initial provisioning needs trusted cloud-owner access; subsequent in-app grants need an existing administrator.

## Supabase cover storage setup

| Setting | Included environment |
| --- | --- |
| Project reference / URL | `nnnjkuicwevpwmokwwzn` / `https://nnnjkuicwevpwmokwwzn.supabase.co` |
| Bucket | `book-covers`, public reads, 20 MiB JPEG/PNG/WebP limit |
| Function / client configuration | `upload-book-cover` / `lib/supabase_config.dart` |

Login uses Firebase, not Supabase Auth. The function verifies Firebase RS256 signature, issuer/audience, expiry, verified email and live access flags before privileged upload. Only active bookstore admins can upload.

`supabase/config.toml` intentionally sets `verify_jwt = false`: Supabase's platform verifier does not validate this Firebase token; the function performs its own checks. Direct anonymous/client Storage writes are not granted by the upload design. Immutable UID/hash paths make matching-content retries safe. Previous cover files remain because order snapshots can retain their URLs.

### Optional: separately owned Supabase deployment

1. Create/select a Free project. Apply `supabase/storage.sql` in its SQL Editor to configure the bucket/MIME types/file limit. In an existing project, inspect policies for unintended client write grants; the script does not erase unrelated policies.
2. Update the public URL/publishable key in `lib/supabase_config.dart`. Set the function's `FIREBASE_PROJECT`, `DATABASE_URL` and, if changed, `OWNER_UID` to match Firebase.
3. Install the [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started). From the repository root, inspect supported options and deploy to your actual reference:

   ```powershell
   supabase --version
   supabase functions deploy --help
   supabase login
   $bookstoreSupabaseRef = 'YOUR_SUPABASE_PROJECT_REF'
   supabase functions deploy upload-book-cover --project-ref $bookstoreSupabaseRef
   ```

4. Confirm provider-injected `SUPABASE_URL` and either `SUPABASE_SECRET_KEYS` with a `default` privileged key or the supported `SUPABASE_SERVICE_ROLE_KEY` fallback exist in the hosted function. These are reserved server-side variables; do not create them as ordinary custom secrets or put them in Flutter/Git. See [function environment variables](https://supabase.com/docs/guides/functions/secrets).
5. Sign in as a verified Firebase admin, save a gallery cover and check the resulting book/image. Also confirm unauthenticated uploads and direct anonymous Storage writes are rejected.

Hosted app evaluation needs no Docker/local Supabase stack. The per-file limit does not increase total free storage quota.

## Android APK build and installation

Build the documented assessment version:

```powershell
flutter pub get
flutter build apk --release --no-pub --build-name=1.0.5 --build-number=6
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

`pubspec.yaml` declares `1.0.0+1`; these flags override it for `1.0.5+6`. A release build without overrides uses the manifest version.

Install on an attached Android device using SDK platform-tools:

```powershell
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Alternatively transfer the supplied APK to the phone and allow installation from that source when Android requests it.

| Recorded build attribute | Value |
| --- | --- |
| Date / version / package | 14 October 2026 / 1.0.5, code 6 / `com.example.bookstore` |
| Size / architectures | 56,937,803 bytes (~54.3 MiB) / `arm64-v8a`, `armeabi-v7a`, `x86_64` |
| Signature | APK v2 verified; Android Debug certificate; APK not marked debuggable. |
| SHA-256 | `3719c2f7cad2c3bcbf193873895c649381c8a01ad4bba722c5efeb1c972d8408` |

The hash identifies the supplied build; another build can differ. `android/app/build.gradle.kts` uses local debug signing for release. Another machine can have a different certificate and fail to update an installed APK. Production store publishing needs separate signing/release preparation.

## Testing and verification

### Included tests

| File | Coverage represented by test source |
| --- | --- |
| `test/widget_test.dart` | Login-screen launch smoke test. |
| `test/store_controller_test.dart` | Account-bound state, repository failures, cart/order handling, snapshots and retries. |
| `test/checkout_quote_test.dart` | Integer rounding, promotion, immutable quotes, cart epochs, limits and delivery values. |
| `test/checkout_test.dart` | Checkout UI, acknowledgements, duplicate taps, failures/stale state and saved-card selection/creation prompt. |

Commands for the combined verification pass:

```powershell
flutter analyze
flutter test
```

Checked-in Flutter tests use local models, injected repositories/callbacks and widget state. They require no deployed account, private fixtures or Firebase emulator. They do not replace live database-rule or phone upload evaluation.

### Recorded evidence

| Check | Status |
| --- | --- |
| Android 1.0.5 release build | Completed successfully. |
| APK identity/signature | Package/version/SDKs checked; signature verified. |
| Targeted changed theme/UI analysis | No errors; existing informational style lint items reported. |
| Firebase rules read-back | Published rules matched local saved-card rules on 13 October 2026. |
| Missing/invalid/forged Firebase upload authentication | Rejected with HTTP 401. |
| Direct anonymous Supabase Storage write | Rejected; no probe object created. |
| Full current analyzer/tests/emulator/device pass | Deferred for one combined evaluation; not claimed as passed. |
| Authenticated gallery upload on a physical phone | Part of the remaining device evaluation. |

This README update did not run the full app suite or change cloud configuration. Builds and negative probes are separate from complete end-to-end results.

For device evaluation, record device/Android version and results for registration/verification/recovery, two-customer isolation, search/saved/cart persistence, both checkout selections, gallery uploads, admin access changes, order stages/notifications and dark mode. Use two devices where available to inspect stale/duplicate checkout behavior.

## Troubleshooting

| Symptom | Check/action |
| --- | --- |
| Flutter unavailable / Dart incompatible | Install compatible Flutter, add `bin` to PATH, restart terminal and inspect `flutter --version` / `flutter doctor -v`. |
| No device | Start an emulator or enable USB debugging, accept phone authorization and inspect `flutter devices`. |
| Unsupported Firebase platform | Select Android; web/desktop options are not configured. |
| Dependency/Gradle failure | Check internet/proxy, Android tools and `flutter doctor -v`; retry after resolving the reported cause. |
| Email unverified | Open latest verification email, inspect spam/resend and sign in again. |
| Admin enters customer side | Check verified email, active access flags/owner claim and session refresh; profile role metadata is insufficient. |
| Permission denied / records fail to load | Check verification/block/removal, network, matching Firebase URL/project and deployed rules. Keep protected rules. |
| Empty catalog | Check connectivity/catalog; on a new environment, a verified admin adds books. An ignored seed file is not required. |
| Checkout rejected | Complete delivery/payment selection, use a non-expired owned card, remove missing books and reload changed cart values. Internet is required. |
| Card creation offered | Create a valid method under this account or replace expired metadata. |
| Upload 401 / 403 | Refresh verified Firebase login for 401; check active admin authority/rules and matching project/database for 403. |
| Upload 413 / 415 | Use <=20 MiB actual JPEG/PNG/WebP bytes. Renaming the extension does not convert a file. |
| Storage unavailable | Check hosted project/function/bucket and server credentials. Existing HTTPS cover URLs are also supported. |
| Android recovered picture | Unsaved book fields may need re-entry after picker process loss. |
| No background push/bank charge | Alerts are in-app; card checkout records metadata. Those external integrations are outside current scope. |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Use the same signing certificate. Another machine's debug key can differ; uninstall/reinstall only if clearing local app state is acceptable. |
| Firebase CLI shutdown error | Independently compare published/local rules before deciding whether redeployment is needed. |

## Current scope

Saved-card selection, gallery covers and shared dark mode are implemented. Remaining evaluation is recorded above. Future additions could include payment settlement, background push/offer sending, courier APIs, inventory, ISBN scanning, curated release dates, sales-based recommendations and separately configured/evaluated platforms.

Sample catalog release dates contain placeholders and need curation before Newest is treated as an accurate publication-date ranking. Free services remain subject to quotas/availability. The APK is an installable assessment release; public-store distribution needs its own preparation.

## Submission files

The repository contains app/platform source, dependencies/lockfile, database rules, deployable Supabase sources, Flutter tests and this README.

Supply the full Word documentation, ERD/DFD and APK separately with the eProject submission. They remain local and intentionally excluded from Git. Local `docs/`, `plans/`, `fixtures/`, `tools/`, `firebase.emulators.json`, `.firebase/`, build/cache output and private environment/signing files are ignored. None is needed for the fresh-clone run above.

Passwords, service-account JSON, privileged Supabase keys and signing keys belong in private channels. Public Firebase configuration and the Supabase publishable key are distinct from those credentials.

## Team

| Student ID | Student name | Contribution |
| --- | --- | --- |
| Student1588538 | Hasnain Ali | User and administrator backend development |
| Student1588413 | Muhammad Siraj | Frontend development |
| Student1595091 | Areeb Javed | Authentication development |
| Student1588631 | AbdulMoiz | Frontend development |
| Student1588756 | Muhammad Asim | Frontend development |
| Student1602534 | Meer Muhammad | Presentation and frontend development |

## Official references

- [Flutter installation](https://docs.flutter.dev/install)
- [Flutter Android build/release](https://docs.flutter.dev/deployment/android)
- [Firebase Flutter setup](https://firebase.google.com/docs/flutter/setup)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- [Email/Password Authentication](https://firebase.google.com/docs/auth/flutter/password-auth)
- [Realtime Database rules](https://firebase.google.com/docs/database/security)
- [Firebase token verification](https://firebase.google.com/docs/auth/admin/verify-id-tokens)
- [Supabase CLI setup](https://supabase.com/docs/guides/local-development/cli/getting-started)
- [Supabase function deployment](https://supabase.com/docs/guides/functions/deploy)
- [Supabase function environment variables](https://supabase.com/docs/guides/functions/secrets)
- [Supabase Storage access control](https://supabase.com/docs/guides/storage/security/access-control)
- [Flutter image picker](https://pub.dev/packages/image_picker)
