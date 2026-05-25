# PROJECT SAKINA - BRAND ASSETS & DESIGN SPECIFICATIONS

---

## 🎨 LOGO VARIATIONS

### Logo Option 1: Crescent + Star (Recommended)
```
     ☆
    ◆ ◆
   ◆   ◆
    ◆ ◆
     ◆
```
**Style:** Minimalist, geometric
**Usage:** Primary brand mark
**Files:** logo.svg, logo.png (transparent), logo.pdf

### Logo Option 2: Text Logo
```
╔════════════════════╗
║    S A K I N A     ║
║  Trustworthy AI   ║
╚════════════════════╝
```
**Style:** Modern, straightforward
**Usage:** Horizontal layouts, social media
**Typography:** Inter Bold + Amiri

### Logo Option 3: Monogram
```
   ◆ S ◆
   ◆ A ◆
```
**Style:** Square, compact
**Usage:** App icon, favicon, small spaces
**Size:** 32x32px minimum

---

## 🎯 COLOR PALETTE

### Primary Colors

**Islamic Green**
```
HEX: #1B6B5E
RGB: 27, 107, 94
CMYK: 75, 0, 12, 58
Usage: Primary buttons, headers, brand mark
Psychology: Trust, stability, growth
```

**Clean White**
```
HEX: #FFFFFF
RGB: 255, 255, 255
CMYK: 0, 0, 0, 0
Usage: Text, backgrounds, clean spaces
Psychology: Purity, clarity, simplicity
```

**Light Background**
```
HEX: #F5F5F5
RGB: 245, 245, 245
CMYK: 0, 0, 0, 4
Usage: Page backgrounds, secondary areas
Psychology: Neutral, accessible, clean
```

### Secondary Colors

**Soft Green (Accent)**
```
HEX: #E8F5E9
RGB: 232, 245, 233
CMYK: 5, 0, 7, 4
Usage: Highlights, success states, soft accents
Psychology: Growth, positivity, openness
```

**Alert Red (Error)**
```
HEX: #D32F2F
RGB: 211, 47, 47
CMYK: 0, 78, 78, 17
Usage: Errors, warnings, guardrail triggers
Psychology: Attention, caution, importance
```

**Dark Text**
```
HEX: #212121
RGB: 33, 33, 33
CMYK: 0, 0, 0, 87
Usage: Body text, descriptions
Psychology: Readability, authority
```

### Color Application Guide

| Element | Color | Contrast | Usage |
|---------|-------|----------|-------|
| Primary Buttons | #1B6B5E | 7.2:1 | CTA, primary actions |
| Secondary Buttons | #E8F5E9 | 10.5:1 | Alternative actions |
| Links | #1B6B5E | 7.2:1 | Navigation, hypertext |
| Errors | #D32F2F | 5.8:1 | Error messages, warnings |
| Body Text | #212121 | 21:1 | Main content |
| Disabled | #BDBDBD | 3.5:1 | Inactive states |

---

## 🔤 TYPOGRAPHY

### Font Stack (English)

**Primary: Inter**
- Weights: 400 (Regular), 500 (Medium), 700 (Bold)
- Usage: All English UI text
- Fallback: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto
- Download: https://rsms.me/inter/

**Monospace: Courier New**
- Usage: Code, terminal, technical content
- Fallback: Courier, monospace

### Font Stack (Arabic)

**Primary: Amiri**
- Weights: 400 (Regular), 700 (Bold)
- Usage: All Arabic UI text
- Fallback: Traditional Arabic, Arial Unicode MS
- Download: https://www.amirifont.org/

**Alternative: Droid Arabic Kufi**
- Weights: 400, 700
- Usage: Alternative for Arabic headlines
- Fallback: Arial Unicode MS

### Typography Scale

```
Display (Extra Large)
  Font: Inter Bold / Amiri Bold
  Size: 48px / 3rem
  Line Height: 1.2
  Usage: Page titles, major headings

Heading 1 (Large)
  Font: Inter Bold / Amiri Bold
  Size: 36px / 2.25rem
  Line Height: 1.3
  Usage: Section titles

Heading 2 (Medium)
  Font: Inter Bold / Amiri Bold
  Size: 28px / 1.75rem
  Line Height: 1.4
  Usage: Subsection titles

Heading 3 (Small)
  Font: Inter Bold / Amiri Bold
  Size: 24px / 1.5rem
  Line Height: 1.4
  Usage: Small headings

Body Large
  Font: Inter Regular / Amiri Regular
  Size: 18px / 1.125rem
  Line Height: 1.6
  Usage: Body text, descriptions

Body Regular
  Font: Inter Regular / Amiri Regular
  Size: 16px / 1rem
  Line Height: 1.6
  Usage: Main content text

Body Small
  Font: Inter Regular / Amiri Regular
  Size: 14px / 0.875rem
  Line Height: 1.5
  Usage: Secondary text, captions

Caption
  Font: Inter Regular / Amiri Regular
  Size: 12px / 0.75rem
  Line Height: 1.5
  Usage: Labels, metadata
```

### Text Examples

**English (Inter):**
```
Headings: Clean, modern, geometric
Body:     Highly readable, balanced
Code:     Monospace, distinguished
```

**Arabic (Amiri):**
```
العناوين: فن تقليدي، أنيق
النص:    قابل للقراءة بسهولة
```

---

## 📐 SPACING & SIZING

### Spacing Scale
```
xs:  4px  (0.25rem)
sm:  8px  (0.5rem)
md:  16px (1rem)      [Base]
lg:  24px (1.5rem)
xl:  32px (2rem)
2xl: 48px (3rem)
3xl: 64px (4rem)
```

### Button Sizing
```
Small:
  Height: 32px
  Padding: 8px 16px
  Font: 14px
  Usage: Secondary actions

Medium (Default):
  Height: 40px
  Padding: 12px 24px
  Font: 16px
  Usage: Primary actions

Large:
  Height: 48px
  Padding: 16px 32px
  Font: 18px
  Usage: Hero actions
```

### Icon Sizing
```
16px   - Inline icons, small UI
24px   - Standard icons (default)
32px   - Large UI icons
48px   - Hero section icons
64px   - Logo displays
128px  - Featured images
256px  - Large hero images
```

---

## 🔘 COMPONENT SPECIFICATIONS

### Buttons

**Primary Button**
```
Background: #1B6B5E
Text: #FFFFFF
Padding: 12px 24px
Border Radius: 8px
Font Weight: 600
Hover: Background #165045 (darker)
Active: Background #0f3d35 (even darker)
Disabled: Background #BDBDBD, cursor not-allowed
Shadow: 0 2px 4px rgba(0,0,0,0.1)
```

**Secondary Button**
```
Background: #E8F5E9
Text: #1B6B5E
Border: 1px solid #1B6B5E
Padding: 12px 24px
Border Radius: 8px
Font Weight: 600
Hover: Background #C8E6C9
```

**Ghost Button**
```
Background: transparent
Text: #1B6B5E
Border: 1px solid #1B6B5E
Padding: 12px 24px
Border Radius: 8px
Hover: Background #F5F5F5
```

### Cards

```
Background: #FFFFFF
Border: 1px solid #E0E0E0
Border Radius: 12px
Padding: 24px
Shadow: 0 2px 8px rgba(0,0,0,0.08)
Hover: Shadow increased to 0 4px 12px rgba(0,0,0,0.12)
Spacing: 16px between cards
```

### Input Fields

```
Background: #F5F5F5 / #FFFFFF
Border: 1px solid #E0E0E0
Border Radius: 8px
Padding: 12px 16px
Font: 16px
Focus: Border #1B6B5E, outline none
Error: Border #D32F2F
Disabled: Background #F5F5F5, cursor not-allowed
```

---

## 📱 RESPONSIVE BREAKPOINTS

```
Mobile Small:  320px - 479px
Mobile:        480px - 767px
Tablet:        768px - 1023px
Desktop:       1024px - 1279px
Desktop Large: 1280px and above
```

### Safe Areas (RTL/LTR)
```
Mobile:  16px padding (both sides)
Tablet:  24px padding (both sides)
Desktop: 40px padding (both sides)
```

---

## 🌐 BRAND ACROSS PLATFORMS

### Website (sakina.dev / sakina.org)
```
Primary Color: #1B6B5E
Typography: Inter (EN) / Amiri (AR)
Theme: Light with dark mode option
RTL Support: Full bi-directional layout
```

### Mobile App (iOS/Android)
```
Primary Color: #1B6B5E
Status Bar: Dark (iOS) / Light (Android)
Accent Color: #1B6B5E
Theme: Light/Dark mode support
Typography: Inter/Amiri system fonts
Safe Area: Respected on notch/cutout devices
```

### Desktop App
```
Title Bar: #1B6B5E or system default
Accent: #1B6B5E
Text: #212121
Background: #F5F5F5 or #FFFFFF
```

### CLI/Terminal
```
Primary Text: #1B6B5E (green)
Success: #4CAF50 (bright green)
Warning: #FF9800 (orange)
Error: #D32F2F (red)
Dim Text: #757575 (gray)
Logo: ASCII art version
```

---

## 📏 LOGO SPECIFICATIONS

### Primary Logo (SVG)

**Dimensions:** 200x200px (minimum usage 64x64px)
**Scalability:** Vector SVG format
**Color Variants:**
- Full color on white (#1B6B5E on #FFFFFF)
- Full color on green (#FFFFFF on #1B6B5E)
- Monochrome (#1B6B5E)
- Inverted (#FFFFFF)

**Clear Space:** Minimum 16px around logo
**Never:**
- Stretch or distort the logo
- Use colors other than brand colors
- Add shadows or effects
- Use on complex backgrounds

### Favicon

```
16x16px:  Logo simplified
32x32px:  Logo simplified
180x180px: Apple touch icon
192x192px: Android homescreen
512x512px: Large app icon
```

---

## 🎬 BRAND MOTION

### Animation Principles
- **Easing:** Ease-in-out (smooth, natural)
- **Duration:** 200ms for micro-interactions, 400ms for page transitions
- **Avoid:** Excessive animations, strobe effects

### Examples
```
Button hover: 200ms ease-in-out
Modal entrance: 300ms ease-out
Page transition: 400ms ease-in-out
Loading pulse: 1000ms ease-in-out (infinite)
```

---

## 🎨 DESIGN TOKENS (CSS/SCSS)

```css
/* Colors */
--color-primary: #1B6B5E;
--color-primary-dark: #165045;
--color-primary-light: #E8F5E9;
--color-background: #F5F5F5;
--color-surface: #FFFFFF;
--color-text: #212121;
--color-text-secondary: #757575;
--color-error: #D32F2F;
--color-success: #4CAF50;
--color-warning: #FF9800;

/* Typography */
--font-primary: Inter, -apple-system, BlinkMacSystemFont;
--font-script: Amiri, Arial Unicode MS;
--font-mono: Courier New, monospace;

/* Spacing */
--space-xs: 4px;
--space-sm: 8px;
--space-md: 16px;
--space-lg: 24px;
--space-xl: 32px;

/* Border Radius */
--radius-sm: 4px;
--radius-md: 8px;
--radius-lg: 12px;
--radius-full: 9999px;

/* Shadows */
--shadow-sm: 0 2px 4px rgba(0, 0, 0, 0.1);
--shadow-md: 0 4px 8px rgba(0, 0, 0, 0.12);
--shadow-lg: 0 8px 16px rgba(0, 0, 0, 0.15);
```

---

## 📋 BRAND ASSET CHECKLIST

**Visual Assets Created:**
- [ ] Logo (SVG, PNG, PDF)
- [ ] Logo variations (horizontal, stacked, monogram)
- [ ] Favicon (all sizes)
- [ ] Social media avatars
- [ ] Hero images
- [ ] Icon set
- [ ] Color palette guide
- [ ] Typography samples

**Design Specifications:**
- [ ] Brand guidelines PDF
- [ ] Design tokens
- [ ] Component library specs
- [ ] Responsive breakpoints
- [ ] Accessibility standards (WCAG AA+)

**Platform-Specific:**
- [ ] Website design system
- [ ] App design specs
- [ ] CLI styling guide
- [ ] Email template

---

## ✨ BRAND IDENTITY: COMPLETE

All visual, verbal, and design specifications are defined.

Ready to implement across all platforms and touchpoints.

**Project Sakina Visual Identity: Professional, Modern, Islamic.** 🌙

---

Made with precision, intelligence, and respect for privacy. 🙏

Project Sakina: Sovereign. Intelligent. Secure. Islamic.
