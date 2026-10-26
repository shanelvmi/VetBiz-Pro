# G4: the text of the About, How to use it and FAQs pages

Batch G4 (RUNBOOK2 ledger). Every sentence the three pages show, with the file and line that proves it. Code read at `66331ac`; the G4b rows re-read at `a44d561`. The pages are written from this table; the owner edits the English in `lib/l10n/app_en.arb` (or asks for changes). Rules: only what the repository proves; no marketing words, no claims about security, uptime or savings, no prices, no "AI". `{appName}` is `AppInfo.name`. Screen names are the sidebar's (`dashboard_screen.dart:2234-2343`: Stock, Products, Sales, Services, Clients, Payments, Debtors, Transactions, Reports, Settings).
**RW2b/RW2c must re-check** the register sentences (H1, H8, F1) when the wizard replaces the register form.

## Footer labels

| Key | English | Proof |
|---|---|---|
| authFooter_platform | Platform | heading only |
| authFooter_about | About {appName} | the About page's title too |
| authFooter_howToUse | How to use it | the How to use page's title too |
| authFooter_faq | FAQs | the FAQs page's title too |
| authFooter_helpContact (kept) | Help and contact | G3 |

## About {appName} (`lib/screens/info/about_screen.dart`)

| Key | English | Proof |
|---|---|---|
| about_intro | {appName} is an app for running an agrovet or a veterinary centre in Tanzania. | `config/app_defaults.dart:1` ("The app serves Tanzania today"); facility types `app_en.arb` facilityType_agrovet .. facilityType_ambulatoryVet (303-309); Terms 1, `terms_of_service_screen.dart:47-49` |
| about_whoFor | It is for agrovets, vet clinics, vet hospitals and ambulatory vets, and for the people who work in them. | facility types `app_en.arb:303-309`; roles Admin and Assistant, Terms 2, `terms_of_service_screen.dart:53-57` |
| about_coversTitle | What it covers | heading |
| about_coverSales | Sales, with receipts. | sidebar Sales `dashboard_screen.dart:2260`; `receipt_preview_screen.dart:427-428` |
| about_coverStock | Products and stock, from the Stock Store to the shelf. | sidebar Stock and Products `dashboard_screen.dart:2236,2248`; `release_to_shop_flow.dart:129` |
| about_coverServices | Services and visits. | sidebar Services `dashboard_screen.dart:2272`; `services_screen.dart:400` (Record Visit) |
| about_coverClients | Clients and the debts they owe. | sidebar Clients, Debtors `dashboard_screen.dart:2284,2305`; `sale_provider.dart:476-508` |
| about_coverPayments | Payments and other transactions. | sidebar Payments, Transactions `dashboard_screen.dart:2293,2317` |
| about_coverReports | Daily reports. | sidebar Reports `dashboard_screen.dart:2329`; `view_reports_screen.dart:303` |
| about_coverTeam | Your team: assistants join with an invite code and you approve them. | `manage_assistants_screen.dart:681,882`; `functions/membership.js:34` |
| ~~about_whoBuilds~~ | DELETED in G4b (circular: it named the app as its own maker). LATER (15): after the owner's legal review settles the operator's name, add a sentence naming who runs the service. | - |
| about_yourData | The records your team enters belong to your facility, as the Terms of Service say. | Terms 5, `terms_of_service_screen.dart:83-85` |
| about_questions | Questions? | lead-in to the Help and contact link (`showSupportContactDialog`, G3) |

## How to use it (`lib/screens/info/how_to_use_screen.dart`)

| Key | English | Proof |
|---|---|---|
| howToUse_ownerTitle | If you run the facility (Admin) | role_admin `app_en.arb:355` |
| howToUse_owner1 | On the sign-in page press Register, choose "I own or manage a facility", add your facility's name and type, and press Create account. | `register_screen.dart:1673` (`register_roleAdminSubtitle`), `register_screen.dart:362` (addFacility), `register_createAccount` (2883) |
| howToUse_owner2 | Your new facility starts with a trial. Settings, under Subscription, shows how long it lasts and the plans after it. | `register_benefitTrial` (2879); Terms 3 `terms_of_service_screen.dart:63-66`; `settings_screen.dart:81-82` |
| howToUse_owner3 | Open Products and press Add Product. Choose Sellable Product Catalog to sell it now, or Stock Store to keep it in storage first. | `products_screen.dart:839`; `add_edit_product_screen.dart:750-765` |
| howToUse_owner4 | To move stock to the shelf, open Stock and press Release on the product. | `stockstore_screen.dart:666` (products_release); `release_to_shop_flow.dart:129` |
| howToUse_owner5 | Open Sales and press Record Sale. If a client pays less than the total, the rest is saved as their debt. | `sales_screen.dart:599-609`; `sale_provider.dart:476-508` |
| howToUse_owner6 | Open Services and press Record Visit to record a service. | `services_screen.dart:400` |
| howToUse_owner7 | When a client pays a debt, open Debtors, find the debt and press Record Payment. | `debtors_screen.dart:436-450` |
| howToUse_owner8 | To add an assistant, tap your name in the top bar, open Team Members and press Invite Assistant. The code works for 48 hours or until it is used once. | `dashboard_screen.dart:2594-2597` (admins); `manage_assistants_screen.dart:882`; `functions/membership.js:34` |
| howToUse_owner9 | When they have registered, open Team Members and press Approve. | `manage_assistants_screen.dart:681` |
| howToUse_owner10 | Open Reports and press Generate Today's Report for the day's report. | `view_reports_screen.dart:303` |
| howToUse_assistantTitle | If you work in a facility (Assistant) | role_assistant `app_en.arb:357` |
| howToUse_assistant1 | Ask the facility's admin for an invite code. | `invite_shareHint` (1393) |
| howToUse_assistant2 | On the sign-in page press Register, choose "I have an invite code" and type the code. The facility's name appears when the code is right. | `register_screen.dart:1682` (`register_roleAssistantSubtitle`); `register_screen.dart:86` (checkInviteCode, `_foundFacility`) |
| howToUse_assistant3 | Fill in your details and press Create account. Your account then waits for the admin's approval. | `register_assistantRegistered` (2851); `auth_service.dart:144` |
| howToUse_assistant4 | Until then, signing in shows "{message}", with {message} = entry_notActiveYet: "Your account is not active yet. Please wait for admin approval." | `main.dart:404-407` shows `entry_notActiveYet` (`app_en.arb:2999`); the page passes the same key (`how_to_use_screen.dart:35`, G4b), so the quote cannot drift |
| howToUse_assistant5 | Once approved, you use the screens in the sidebar for that facility: record sales and services, add clients and record payments. | sidebar items have no admin check, `dashboard_screen.dart:2234-2343`; `sales_screen.dart:599` |
| howToUse_assistant6 | Only an admin can add or delete products, delete sales, services and transactions, edit a recorded service or transaction, or open Team Members, Subscription, Trash, Export Data and Business Hours. | G4b, each item in the app AND the rules: add product: button `products_screen.dart:831`, `stockstore_screen.dart:756`, dashboard quick action `dashboard_screen.dart:1975`; rule `firestore.rules:246` (create isAdmin). Delete product: `products_screen.dart:749,754,1257,1262`, `stockstore_screen.dart:656,685`; rule `:249`. Delete sale: `sales_screen.dart:746,970`; rule `:270`. Delete service and edit service: `services_screen.dart:703,910`; `service_provider.dart:576` (AdminOnlyException); rules `:285-289` (an assistant changes only the payment fields; delete isAdmin). Delete and edit transaction: `transactions_screen.dart:562`; `transaction_provider.dart:348,415`; rule `:298`. Team Members: `dashboard_screen.dart:2594`; memberships written only by `functions/membership.js`. Subscription, Trash, Export Data, Business Hours: `settings_screen.dart:81,112,124,136` and the wide panes `:402-412`; Trash rules `:401-415` (read, write isAdmin) |

## FAQs (`lib/screens/info/faq_screen.dart`), an expandable list

| Key | English | Proof |
|---|---|---|
| faq_startQ | How do I start? | |
| faq_startA | Press Register on the sign-in page and choose "I own or manage a facility". Your facility starts with a trial; Settings, under Subscription, shows how long it lasts. | as howToUse_owner1, owner2 |
| faq_trialQ | What happens when the trial ends? | |
| faq_trialA | You need a subscription to keep using every feature. If it lapses, there is a short grace period; then your records stay visible, but new sales, services and similar entries are paused until you renew. | Terms 3, `terms_of_service_screen.dart:63-71` |
| faq_teamQ | How do I add my team? | |
| faq_teamA | In Team Members press Invite Assistant and give the code to the person. They register with it, and you approve them in Team Members. | as howToUse_owner8, owner9 |
| faq_assistantQ | What can an assistant see and do? | |
| faq_assistantA | An assistant uses the screens in the sidebar for their facility. Only an admin can add or delete products, delete sales, services and transactions, edit a recorded service or transaction, or open Team Members, Subscription, Trash, Export Data and Business Hours. | as howToUse_assistant5 and howToUse_assistant6 (G4b) |
| faq_saleQ | How do I record a sale? | |
| faq_saleA | Open Sales and press Record Sale. If a client pays less than the total, the rest is saved as their debt under Debtors. | as howToUse_owner5 |
| faq_serviceQ | How do I record a service? | |
| faq_serviceA | Open Services and press Record Visit. | as howToUse_owner6 |
| faq_printQ | How do I print a receipt? | |
| faq_printA | In the phone app, Print Receipt sends it to a Bluetooth thermal printer, set up in Settings under Printer & Receipt Settings. In a browser the thermal printer does not work: choose A4 Format to print the receipt or save it as a PDF. | `receipt_printer_service.dart:13-22`; `receipt_preview_screen.dart:139-160,175-197,427-428,839`; `printer_title` (1421) |
| faq_deletedQ | I deleted something by mistake. What now? | |
| faq_deletedA | After deleting a sale, a service, a product, a client or a transaction, press Undo in the message that shows for a few seconds. Deleted items also go to Trash (Settings, admins only), where an admin can restore them for 30 days; after that they are deleted for good. | Undo, G4b, all five: sale `sales_screen.dart:851` and service `services_screen.dart:809` (`RestoreFeedback.offerUndo`, `restore_feedback.dart:19-25`), product `products_screen.dart:405` and `stockstore_screen.dart:350`, client `clients_screen.dart:390`, transaction `transactions_screen.dart:604` (`AppFeedback.undo`); shown `app_motion.dart:37` (6 s). Trash: `app_rules.dart:36`; `functions/index.js:590-593` (all five trash collections); `settings_screen.dart:112`; rules `firestore.rules:401-415` |
| faq_passwordQ | I forgot my password. | |
| faq_passwordA | On the sign-in page type your email and press Forgot Password?. If an account exists for that email, a reset link is sent; check your spam folder too. | `login_screen.dart:871-885`; `login_resetNeedsEmail`, `login_resetSent` (2813-2815) |
| faq_languageQ | How do I change the language? | |
| faq_languageA | Open Settings and choose Language / Lugha: English or Kiswahili. | `settings_screen.dart:231` |
| faq_themeQ | How do I change the colours or use Dark Mode? | |
| faq_themeA | Open Settings, then UI Settings. Choose a colour theme (Pasture, Clinic, Harvest or Ledger) and Dark Mode (System, Light or Dark). The choice is saved on this device. | `settings_screen.dart:217`; `ui_settings_dialog.dart`; `uiSettings_theme*`, `uiSettings_themeMode*`, `uiSettings_savedOnDevice` (1455-1491) |
| faq_supportQ | How do I contact support? | |
| faq_supportA | Press Help and contact at the bottom of the sign-in page, or Help on the dashboard. It shows the support contact details set by {appName}. | `auth_footer.dart` (G3); `dashboard_help` (3157); `support_contact_dialog.dart`; `dashboard_supportIntro` (3225) |

## Not said, on purpose

No trial length or prices (set by the platform: Terms 3). No claims about data safety, availability or savings. The Activity Log scope is not explained (the export menu entry is admin-only, `dashboard_screen.dart:2614`; the scoped view is not a sidebar screen). Customer messages (WhatsApp, SMS) are not mentioned.
