# Sakina Mobile Wireframe Plan (Phase 24E)

This plan defines 20 required wireframes for Phase 25 implementation readiness. Status values are evidence-based against current code.

Status legend: `BUILT` / `PARTIAL` / `PLACEHOLDER` / `NOT STARTED`.

## Wireframe Inventory (20)

1. **WF-01 Welcome and language selector**  
   - Target route: `/welcome`  
   - Status: `BUILT`  
   - Evidence: `sakina-frontend/lib/screens/welcome_screen.dart`

2. **WF-02 Onboarding slide 1..3 progression**  
   - Target route: `/onboarding`  
   - Status: `BUILT`  
   - Evidence: `sakina-frontend/lib/screens/onboarding_screen.dart`

3. **WF-03 Account intro and waitlist form**  
   - Target route: `/account-intro`  
   - Status: `BUILT`  
   - Evidence: `sakina-frontend/lib/screens/account_intro_screen.dart`

4. **WF-04 Home shell with bottom navigation**  
   - Target route: `/home`  
   - Status: `PARTIAL`  
   - Evidence: `sakina-frontend/lib/screens/home_shell_screen.dart`

5. **WF-05 Chat conversation view with citations**  
   - Target route: `/chat`  
   - Status: `PARTIAL`  
   - Evidence: `sakina-frontend/lib/screens/chat_screen.dart`

6. **WF-06 Chat feedback/report action strip**  
   - Target route: `/chat/feedback`  
   - Status: `PARTIAL`  
   - Evidence: `sakina-frontend/lib/screens/chat_screen.dart`

7. **WF-07 Islamic Q&A result with verified evidence + fallback**  
   - Target route: `/islamic-qa/result`  
   - Status: `PARTIAL`  
   - Evidence: `sakina-frontend/lib/screens/chat_screen.dart`, `sakina-frontend/lib/screens/iman_journey_screen.dart`

8. **WF-08 Quran module overview state**  
   - Target route: `/modules/quran`  
   - Status: `PLACEHOLDER`  
   - Evidence: `sakina-frontend/lib/screens/module_read_only_state_screen.dart`, `sakina-frontend/lib/services/module_service.dart`

9. **WF-09 Prayer module overview state**  
   - Target route: `/modules/prayer`  
   - Status: `PLACEHOLDER`  
   - Evidence: `sakina-frontend/lib/screens/module_read_only_state_screen.dart`, `sakina-frontend/lib/services/module_service.dart`

10. **WF-10 Knowledge/Community module overview state**  
    - Target route: `/modules/knowledge-community`  
    - Status: `PLACEHOLDER`  
    - Evidence: `sakina-frontend/lib/screens/module_read_only_state_screen.dart`

11. **WF-11 Islamic library source list (Quran/Hadith/Dua sources)**  
    - Target route: `/library/sources`  
    - Status: `NOT STARTED`  
    - Evidence gap: APIs exist in `sakina-frontend/lib/services/api_service.dart`, no connected screen file found.

12. **WF-12 Islamic library documents list**  
    - Target route: `/library/documents`  
    - Status: `NOT STARTED`  
    - Evidence gap: `getIslamicDocuments` exists, no UI route/screen.

13. **WF-13 Islamic chunk/detail reader**  
    - Target route: `/library/document/:id/chunks`  
    - Status: `NOT STARTED`  
    - Evidence gap: `getIslamicChunks` exists, no UI route/screen.

14. **WF-14 Iman journey dashboard**  
    - Target route: `/iman-journey`  
    - Status: `PARTIAL`  
    - Evidence: `sakina-frontend/lib/screens/iman_journey_screen.dart`

15. **WF-15 Personal dua list manager**  
    - Target route: `/iman-journey/dua`  
    - Status: `PARTIAL`  
    - Evidence: `sakina-frontend/lib/screens/iman_journey_screen.dart`

16. **WF-16 Privacy and reminder settings panel**  
    - Target route: `/privacy`  
    - Status: `PARTIAL`  
    - Evidence: switches embedded in `sakina-frontend/lib/screens/iman_journey_screen.dart`; no dedicated settings route.

17. **WF-17 Family profile and consent manager**  
    - Target route: `/family`  
    - Status: `NOT STARTED`  
    - Evidence gap: family APIs exist in `sakina-frontend/lib/services/api_service.dart`; no dedicated screen.

18. **WF-18 Subscription/paywall and entitlements**  
    - Target route: `/subscription`  
    - Status: `NOT STARTED`  
    - Evidence gap: entitlement checks exist in services; no subscription UI screen.

19. **WF-19 Prayer times + Hijri/Gregorian calendar + qibla**  
    - Target route: `/prayer-tools`  
    - Status: `NOT STARTED`  
    - Evidence gap: no qibla/calendar screen files or route references in `sakina-frontend/lib`.

20. **WF-20 Offline/sync/data controls (export/restore/delete)**  
    - Target route: `/settings/data`  
    - Status: `NOT STARTED`  
    - Evidence gap: local DB/sync services exist (`local_db_service.dart`, `sync_service.dart`) but no settings/offline UI.

## Wireframe Deliverable Notes

- Wireframes must include state variants for loading, empty, error, gated/subscription-required, and disabled.
- For religious guidance screens, include explicit provenance and fallback blocks.
- Arabic versions must be mirrored RTL for all high-priority wireframes (WF-01..WF-08 and WF-14..WF-16).
