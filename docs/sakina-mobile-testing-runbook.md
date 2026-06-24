# Sakina Mobile Testing Runbook

Phase 6H — test the **Android APK** as the real product. Web at `:8090` is diagnostic only.

**Status target:** `MOBILE_OWNER_TEST_READY` (not `APP_STORE_READY`).

---

## 1. Start backend

```bash
cd sakina-infra
cat > .env <<'EOF'
POSTGRES_PASSWORD=sakina_local_pw
JWT_SECRET=local-dev-jwt-secret-change-me-32chars
ENCRYPTION_KEY=local-dev-encryption-key-change-32
EOF

docker compose -f docker-compose.qa.yml up -d --build
docker compose -f docker-compose.qa.yml run --rm api sakina-migrate
curl http://localhost:28080/health
curl http://localhost:28080/v1/features
```

Expected: HTTP 200; `/v1/features` returns 25 feature gates.

### Owner one-command scripts
```bash
./scripts/sakina-owner-local-test.sh
BUILD_APK=1 ./scripts/sakina-owner-local-test.sh
```
```powershell
pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk
```

Phone API URL must use a detected LAN IP or the placeholder `YOUR_LAN_IP` with instructions — never `http://:28080/v1`.

---

## 2. Build APK

### Emulator (`10.0.2.2`)
```bash
cd sakina-frontend
flutter pub get
flutter analyze
flutter build apk --debug \
  --dart-define=SAKINA_API_BASE_URL=http://10.0.2.2:28080/v1 \
  --dart-define=SAKINA_LOCAL_TEST=true \
  --dart-define=SAKINA_FEATURE_QURAN=true \
  --dart-define=SAKINA_FEATURE_PRAYER=true \
  --dart-define=SAKINA_FEATURE_KNOWLEDGE=true \
  --dart-define=SAKINA_FEATURE_COMMUNITY=true \
  --dart-define=SAKINA_SUBSCRIPTION_TIER=founding
```

### Physical phone (same Wi‑Fi)
Replace `<LAN-IP>` with your machine IP (e.g. `192.168.0.51`):
```bash
flutter build apk --debug \
  --dart-define=SAKINA_API_BASE_URL=http://<LAN-IP>:28080/v1 \
  --dart-define=SAKINA_LOCAL_TEST=true \
  --dart-define=SAKINA_FEATURE_QURAN=true \
  --dart-define=SAKINA_FEATURE_PRAYER=true \
  --dart-define=SAKINA_FEATURE_KNOWLEDGE=true \
  --dart-define=SAKINA_FEATURE_COMMUNITY=true \
  --dart-define=SAKINA_SUBSCRIPTION_TIER=founding
```

APK path: `sakina-frontend/build/app/outputs/flutter-apk/app-debug.apk`

### Windows owner script
```powershell
pwsh ./scripts/sakina-owner-local-test.ps1 -BuildApk
```

---

## 3. Install APK

```bash
adb install -r sakina-frontend/build/app/outputs/flutter-apk/app-debug.apk
```

---

## 4. Journey test checklist

## 8. Admin feature control (Phase 6H)

| Action | Who | API / UI |
|--------|-----|----------|
| View public gates | Anyone | `GET /v1/features` — mobile reads on dashboard load |
| List all 25 features | Admin JWT | Admin Tools screen or `GET /v1/admin/features` |
| Toggle enabled/login/premium/soon/maintenance | Admin JWT | Admin Tools → edit feature |
| Reset defaults | Admin JWT | Admin Tools → Reset |
| App status summary | Admin JWT | `GET /v1/admin/app-status` |

Without admin JWT: Admin Tools shows honest permission-required state (403 on admin APIs).

**Local test only:** dart-defines, HTTP API, Stripe not configured, no store signing.

**Not production yet:** HTTPS release API, privacy policy URL, release keystore, store screenshots.

See [sakina-app-store-readiness-checklist.md](./sakina-app-store-readiness-checklist.md).

| Journey | Steps | Expected |
|---------|-------|----------|
| Guest | Open app → guest home → Quran Study | Surah list loads |
| Guest protected | Tap Bookmarks | Login Required screen |
| Register | Register → dashboard | 12 cards, email shown |
| Ask AI safe | Ask tab → "How do I make wudu?" | Answer + citations |
| Ask AI risk | "How do I divorce my wife?" | Escalation + review link |
| Study | Quran search, tafsir 1:1, hadith search | API data (not placeholder) |
| Prayer | Daily tab → refresh London times | Fajr–Isha shown |
| Dua | Search duas | List loads |
| Bookmarks | Add dua bookmark (logged in) | Appears in list |
| Zakat | Enter values → Calculate | Amount or below-nisab |
| Kids | Start quiz | Questions load |
| Subscription | View plans | Honest payment status |
| Scholar | After escalation → Scholar Review | Pending status |
| Admin | Admin Tools → health refresh | Status cards |
| Feature flags | Open Quran/Prayer from home | **No** "disabled by feature flag" |

---

## 5. What is NOT production/live

- Live payment checkout (provider not configured locally)
- Masjid map / GPS provider
- Scholar resolve (needs scholar-seeded account)
- Admin grant/revoke (needs admin JWT)
- Full Ollama answers if model not pulled in Docker

---

## 6. Settings / API URL

In the APK: **Settings** → choose Emulator, Localhost, or enter custom `http://<IP>:28080/v1`.

---

## 7. Web diagnostic (optional)

```powershell
pwsh ./scripts/sakina-owner-local-test.ps1
```

Opens `http://localhost:8090` — **not** the production UI.
