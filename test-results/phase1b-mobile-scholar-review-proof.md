# PHASE 1B mobile scholar-review path proof (Mon Jun 22 23:35:01 UTC 2026)
```
1. mobile asks high-risk via /v1/api/sakina/ask (client path)
   safety_state=ESCALATED_TO_HUMAN trace=c6fd8445-b5e7-4304-b565-bd2649ed4875
2. user polls /v1/api/sakina/review-status BEFORE resolve (expect pending)
   status= pending_scholar_review
3. scholar resolves
   resolve -> 200
4. user polls AFTER resolve (expect scholar_answered + answer)
   status= scholar_answered | answer= Reviewed: a valid talaq requires clear intent and the c
5. user B blocked (expect 404)
   B /v1 review-status(A) -> 404
6. unauth blocked (expect 401)
   anon /v1 review-status -> 401
7. audit row persists
   audit rows: 2
```
Mobile wiring: api_service.reviewStatus -> /v1/api/sakina/review-status/{trace}; PendingReviewStore (SharedPreferences); ScholarReviewsScreen (Reviews tab); chat_screen saves trace on ESCALATED_TO_HUMAN. flutter analyze: No issues found.
