# CLAUDE CODE INSTRUCTIONS - READ & APPLY BRAND IDENTITY

## OBJECTIVE
Read the two brand identity files from F:\SakinaAL and apply the complete brand identity across the entire Project Sakina codebase.

---

## STEP 1: READ THE BRAND IDENTITY FILES

### File 1: F:\SakinaAL\sakina-docs\BRAND-IDENTITY.md

```bash
# Read the brand identity file
cat "F:\SakinaAL\sakina-docs\BRAND-IDENTITY.md"
```

**What to extract from this file:**
- ✅ Vision statement
- ✅ Mission statement  
- ✅ Core values (5 values)
- ✅ Brand name: SAKINA
- ✅ Brand meaning: Serenity, Peace, Divine Presence
- ✅ Tagline: "Trustworthy. Private. Islamic."
- ✅ Brand promise
- ✅ Brand voice & tone
- ✅ Evolution roadmap

---

### File 2: F:\SakinaAL\sakina-docs\BRAND-ASSETS.md

```bash
# Read the brand assets file
cat "F:\SakinaAL\sakina-docs\BRAND-ASSETS.md"
```

**What to extract from this file:**
- ✅ Color palette:
  - Primary: #1B6B5E (Islamic Green)
  - Background: #F5F5F5
  - Text: #212121
  - Accent: #E8F5E9
  - Alert: #D32F2F
- ✅ Typography:
  - Arabic: Amiri
  - English: Inter
  - Code: Courier New
- ✅ Logo variations (3 designs)
- ✅ Spacing scale
- ✅ Component specifications
- ✅ Design tokens (CSS/SCSS)
- ✅ Responsive breakpoints
- ✅ Platform guidelines

---

## STEP 2: APPLY BRAND IDENTITY TO BACKEND

### Update: F:\SakinaAL\sakina-backend\src\main.rs

Add these constants at the top of the file:

```rust
// Project Sakina Brand Identity
const BRAND_NAME: &str = "SAKINA";
const BRAND_VISION: &str = "Empower Muslims with Sovereign, Intelligent, and Trustworthy Islamic Guidance";
const BRAND_MISSION: &str = "Zero-hallucination Islamic guidance with complete privacy";
const BRAND_VALUES: &[&str] = &[
    "Integrity - Never compromise on authenticity",
    "Privacy - User data is sacred",
    "Excellence - Zero tolerance for hallucinations",
    "Accessibility - Simple, works offline",
    "Community - Open source, collaborative"
];

// Brand Colors (hex values)
const COLOR_PRIMARY: &str = "#1B6B5E";      // Islamic Green
const COLOR_BACKGROUND: &str = "#F5F5F5";  // Light
const COLOR_TEXT: &str = "#212121";        // Dark
const COLOR_ACCENT: &str = "#E8F5E9";      // Soft Green
const COLOR_ERROR: &str = "#D32F2F";       // Alert Red
```

### Update: Health check response to include brand info

```rust
pub async fn health_check(pool: web::Data<PgPool>) -> HttpResponse {
    let db_status = pool.acquire().await.is_ok();
    
    HttpResponse::Ok().json(json!({
        "status": "healthy",
        "service": "Project Sakina API",
        "version": "1.0.0",
        "brand": "SAKINA",
        "tagline": "Trustworthy. Private. Islamic.",
        "database": if db_status { "ok" } else { "error" },
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "values": [
            "Integrity",
            "Privacy", 
            "Excellence",
            "Accessibility",
            "Community"
        ]
    }))
}
```

### Create: F:\SakinaAL\sakina-backend\src\brand.rs

```rust
//! Project Sakina Brand Identity Module
//! 
//! This module defines and manages the brand identity for Project Sakina.
//! All branding, messaging, and identity is centralized here.

pub struct BrandIdentity {
    pub name: &'static str,
    pub vision: &'static str,
    pub mission: &'static str,
    pub tagline: &'static str,
    pub values: &'static [&'static str],
}

pub const SAKINA: BrandIdentity = BrandIdentity {
    name: "SAKINA",
    vision: "Empower Muslims with Sovereign, Intelligent, and Trustworthy Islamic Guidance",
    mission: "Zero-hallucination Islamic guidance with complete privacy and sovereignty",
    tagline: "Trustworthy. Private. Islamic.",
    values: &[
        "Integrity - Never compromise on authenticity",
        "Privacy - User data is sacred",
        "Excellence - Zero tolerance for hallucinations",
        "Accessibility - Simple, works offline",
        "Community - Open source, collaborative"
    ],
};

pub struct Colors {
    pub primary: &'static str,
    pub background: &'static str,
    pub text: &'static str,
    pub accent: &'static str,
    pub error: &'static str,
}

pub const BRAND_COLORS: Colors = Colors {
    primary: "#1B6B5E",      // Islamic Green
    background: "#F5F5F5",   // Light
    text: "#212121",         // Dark
    accent: "#E8F5E9",       // Soft Green
    error: "#D32F2F",        // Alert Red
};

pub fn get_brand_promise() -> &'static str {
    "Authentic Islamic guidance, complete privacy, transparency in every interaction"
}

pub fn get_brand_motto() -> (&'static str, &'static str) {
    (
        "Authentic. Private. Trusted.",           // English
        "أصيل. خاص. موثوق"                       // Arabic
    )
}
```

---

## STEP 3: APPLY BRAND IDENTITY TO FRONTEND

### Update: F:\SakinaAL\sakina-frontend\lib\config\brand_config.dart

Create new file:

```dart
/// Project Sakina Brand Configuration
class SakinaBrand {
  // Brand Identity
  static const String brandName = 'SAKINA';
  static const String brandArabic = 'السَّكِينَة';
  static const String brandMeaning = 'Serenity, Peace, Divine Presence';
  
  static const String vision = 
    'Empower Muslims with Sovereign, Intelligent, and Trustworthy Islamic Guidance';
  
  static const String mission = 
    'Zero-hallucination Islamic guidance with complete privacy and sovereignty';
  
  static const String tagline = 'Trustworthy. Private. Islamic.';
  
  static const String brandPromise = 
    'Authentic Islamic guidance, complete privacy, transparency in every interaction';
  
  // Brand Values
  static const List<String> values = [
    'Integrity - Never compromise on authenticity',
    'Privacy - User data is sacred',
    'Excellence - Zero tolerance for hallucinations',
    'Accessibility - Simple, works offline',
    'Community - Open source, collaborative',
  ];
  
  // Brand Motto
  static const String mottoEnglish = 'Authentic. Private. Trusted.';
  static const String mottoArabic = 'أصيل. خاص. موثوق';
  
  // Colors
  static const String colorPrimary = '#1B6B5E';      // Islamic Green
  static const String colorBackground = '#F5F5F5';  // Light
  static const String colorText = '#212121';        // Dark
  static const String colorAccent = '#E8F5E9';      // Soft Green
  static const String colorError = '#D32F2F';       // Alert Red
  
  // Fonts
  static const String fontArabic = 'Amiri';
  static const String fontEnglish = 'Inter';
}
```

### Update: F:\SakinaAL\sakina-frontend\lib\widgets\brand_widget.dart

Create new file:

```dart
import 'package:flutter/material.dart';
import '../config/brand_config.dart';

class BrandHeader extends StatelessWidget {
  final bool isArabic;
  
  const BrandHeader({Key? key, this.isArabic = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(int.parse('0xFF1B6B5E')),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            SakinaBrand.brandName,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: isArabic ? 'Amiri' : 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          if (isArabic)
            Text(
              SakinaBrand.brandArabic,
              style: const TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontFamily: 'Amiri',
              ),
            ),
          const SizedBox(height: 12),
          Text(
            SakinaBrand.tagline,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontFamily: isArabic ? 'Amiri' : 'Inter',
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class BrandValuesList extends StatelessWidget {
  final bool isArabic;
  
  const BrandValuesList({Key? key, this.isArabic = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'قيمنا' : 'Our Values',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...SakinaBrand.values.map((value) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF1B6B5E)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}
```

---

## STEP 4: APPLY BRAND IDENTITY TO DOCUMENTATION

### Create: F:\SakinaAL\sakina-docs\BRAND-GUIDELINES.md

```markdown
# Project Sakina Brand Guidelines

## Brand Identity
- **Name**: SAKINA (السَّكِينَة)
- **Meaning**: Serenity, Peace, Divine Presence
- **Vision**: Empower Muslims with Sovereign, Intelligent, and Trustworthy Islamic Guidance
- **Mission**: Zero-hallucination Islamic guidance with complete privacy

## Brand Values
1. Integrity - Never compromise on authenticity
2. Privacy - User data is sacred
3. Excellence - Zero tolerance for hallucinations
4. Accessibility - Simple, works offline
5. Community - Open source, collaborative

## Brand Tagline
"Trustworthy. Private. Islamic."

## Brand Promise
"Authentic Islamic guidance, complete privacy, transparency in every interaction"

## Brand Colors
- Primary: #1B6B5E (Islamic Green)
- Background: #F5F5F5 (Light)
- Text: #212121 (Dark)
- Accent: #E8F5E9 (Soft Green)
- Error: #D32F2F (Alert Red)

## Typography
- Arabic: Amiri (traditional, elegant)
- English: Inter (modern, clean)
- Code: Courier New (monospace)

## Logo
Crescent + Star (minimalist geometric design)

---

See BRAND-IDENTITY.md and BRAND-ASSETS.md for complete specifications.
```

---

## STEP 5: APPLY BRAND IDENTITY TO INFRASTRUCTURE

### Update: F:\SakinaAL\sakina-infra\docker-compose.yml

Add environment variables:

```yaml
services:
  api:
    environment:
      - BRAND_NAME=SAKINA
      - BRAND_TAGLINE=Trustworthy. Private. Islamic.
      - BRAND_COLOR_PRIMARY=#1B6B5E
      - LOG_PREFIX=[SAKINA]
```

### Create: F:\SakinaAL\sakina-infra\manifests\brand-configmap.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: sakina-brand-config
  namespace: sakina-api
data:
  BRAND_NAME: "SAKINA"
  BRAND_VISION: "Empower Muslims with Sovereign, Intelligent, and Trustworthy Islamic Guidance"
  BRAND_MISSION: "Zero-hallucination Islamic guidance with complete privacy"
  BRAND_TAGLINE: "Trustworthy. Private. Islamic."
  BRAND_COLOR_PRIMARY: "#1B6B5E"
  BRAND_COLOR_ACCENT: "#E8F5E9"
```

---

## STEP 6: UPDATE README FILES

### Update: F:\SakinaAL\README.md

Add this section after introduction:

```markdown
## 🏷️ Brand Identity

**Project Sakina** is built on the following brand foundation:

### Vision
Empower Muslims with Sovereign, Intelligent, and Trustworthy Islamic Guidance

### Mission
Provide zero-hallucination Islamic guidance with complete privacy and sovereignty

### Tagline
"Trustworthy. Private. Islamic."

### Core Values
- **Integrity**: Never compromise on authenticity
- **Privacy**: User data is sacred
- **Excellence**: Zero tolerance for hallucinations
- **Accessibility**: Simple, works offline
- **Community**: Open source, collaborative

### Brand Colors
- Primary: `#1B6B5E` (Islamic Green)
- Accent: `#E8F5E9` (Soft Green)

See [Brand Identity](./sakina-docs/BRAND-IDENTITY.md) and [Brand Assets](./sakina-docs/BRAND-ASSETS.md) for complete specifications.
```

---

## STEP 7: CREATE BRAND VERIFICATION CHECKLIST

### Create: F:\SakinaAL\BRAND-IMPLEMENTATION-CHECKLIST.md

```markdown
# Brand Implementation Checklist

## Backend (Rust)
- [ ] Brand constants defined in src/brand.rs
- [ ] Brand identity exposed in health check
- [ ] Error messages use brand voice
- [ ] Logging includes brand name
- [ ] API responses branded appropriately

## Frontend (Flutter)
- [ ] Brand colors applied to theme
- [ ] Brand fonts configured (Inter/Amiri)
- [ ] Brand identity displayed in UI
- [ ] App name shows "Project Sakina"
- [ ] Brand values accessible in app

## Documentation
- [ ] README includes brand identity
- [ ] BRAND-IDENTITY.md created
- [ ] BRAND-ASSETS.md created
- [ ] BRAND-GUIDELINES.md created
- [ ] API docs mention brand

## Infrastructure
- [ ] ConfigMap with brand variables
- [ ] Docker compose includes brand env vars
- [ ] Kubernetes manifests branded
- [ ] Monitoring shows brand name

## Testing
- [ ] Health check returns brand info
- [ ] API responses branded
- [ ] UI displays brand correctly
- [ ] Documentation is consistent

## CI/CD
- [ ] GitHub Actions mention brand
- [ ] Build artifacts labeled with brand
- [ ] Releases branded appropriately
```

---

## STEP 8: VERIFY BRAND IMPLEMENTATION

Run these commands to verify:

```bash
# Check brand constants in backend
cd F:\SakinaAL\sakina-backend
grep -r "SAKINA" src/

# Check brand in documentation
cd F:\SakinaAL
grep -r "SAKINA" sakina-docs/

# Check API response includes brand
curl http://localhost:8080/v1/health | jq '.brand'

# Check Flutter has brand
cd sakina-frontend
grep -r "SAKINA" lib/
```

---

## FINAL VERIFICATION

After applying all changes, verify:

```bash
# ✅ Backend
- Health check returns brand info
- Logs show "[SAKINA]" prefix

# ✅ Frontend  
- App displays SAKINA name
- Colors match #1B6B5E
- Typography uses Inter/Amiri

# ✅ Documentation
- README mentions brand
- Brand files exist in sakina-docs/

# ✅ Infrastructure
- ConfigMap has brand variables
- Kubernetes manifests branded

# ✅ API
- All responses branded
- Error messages use brand voice
```

---

## SUMMARY

**Files Read:**
- ✅ F:\SakinaAL\sakina-docs\BRAND-IDENTITY.md
- ✅ F:\SakinaAL\sakina-docs\BRAND-ASSETS.md

**Files Updated:**
- ✅ sakina-backend/src/main.rs
- ✅ sakina-backend/src/brand.rs (new)
- ✅ sakina-frontend/lib/config/brand_config.dart (new)
- ✅ sakina-frontend/lib/widgets/brand_widget.dart (new)
- ✅ sakina-docs/BRAND-GUIDELINES.md (new)
- ✅ sakina-infra/docker-compose.yml
- ✅ sakina-infra/manifests/brand-configmap.yaml (new)
- ✅ README.md

**Brand Applied Across:**
- ✅ Backend API (Rust)
- ✅ Frontend UI (Flutter)
- ✅ Infrastructure (Kubernetes)
- ✅ Documentation
- ✅ CI/CD

**Project Sakina is now fully branded!** 🌙

---

Made with precision, intelligence, and respect for privacy. 🙏

Project Sakina: Sovereign. Intelligent. Secure. Islamic.
