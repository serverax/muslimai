enum AppLanguage { english, arabic }

class AppStrings {
  static const Map<String, Map<AppLanguage, String>> _strings = {
    'appTitle': {
      AppLanguage.english: 'Sakina AI',
      AppLanguage.arabic: 'سكينة AI',
    },
    'heroTitle': {
      AppLanguage.english: 'Sakina AI - Your AI-Powered Islamic Companion',
      AppLanguage.arabic: 'سكينة AI - رفيقك الإسلامي الذكي',
    },
    'heroSubtitle': {
      AppLanguage.english:
          'A private, trustworthy, and faith-centered companion for Muslim daily life.',
      AppLanguage.arabic:
          'رفيق خاص وموثوق يركز على الإيمان لدعم حياتك اليومية.',
    },
    'getStarted': {
      AppLanguage.english: 'Get Started',
      AppLanguage.arabic: 'ابدأ الآن',
    },
    'learnMore': {
      AppLanguage.english: 'Learn More',
      AppLanguage.arabic: 'اعرف المزيد',
    },
    'continueLimited': {
      AppLanguage.english: 'Continue with limited preview',
      AppLanguage.arabic: 'المتابعة في وضع المعاينة المحدود',
    },
    'onboardingTitle1': {
      AppLanguage.english: 'Build serenity through consistency',
      AppLanguage.arabic: 'ابنِ السكينة عبر الاستمرارية',
    },
    'onboardingBody1': {
      AppLanguage.english:
          'Track your spiritual routines with clear, calm, and respectful UX.',
      AppLanguage.arabic:
          'تابع عاداتك الروحية بتجربة واضحة وهادئة تحترم خصوصيتك.',
    },
    'onboardingTitle2': {
      AppLanguage.english: 'Verified guidance with clear confidence',
      AppLanguage.arabic: 'إرشاد موثوق بدون ثقة وهمية',
    },
    'onboardingBody2': {
      AppLanguage.english:
          'Sakina will only present features that are genuinely implemented.',
      AppLanguage.arabic:
          'سكينة تعرض فقط الميزات المنفذة فعليا بدون تمثيل مزيف.',
    },
    'onboardingTitle3': {
      AppLanguage.english: 'Start with waitlist and early access',
      AppLanguage.arabic: 'ابدأ عبر قائمة الانتظار والوصول المبكر',
    },
    'onboardingBody3': {
      AppLanguage.english:
          'Join now to receive updates as core mobile features roll out.',
      AppLanguage.arabic:
          'انضم الآن لتصلك التحديثات مع إطلاق الميزات الأساسية.',
    },
    'continue': {
      AppLanguage.english: 'Continue',
      AppLanguage.arabic: 'متابعة',
    },
    'joinWaitlist': {
      AppLanguage.english: 'Join Waitlist',
      AppLanguage.arabic: 'انضم إلى قائمة الانتظار',
    },
    'name': {
      AppLanguage.english: 'Name',
      AppLanguage.arabic: 'الاسم',
    },
    'email': {
      AppLanguage.english: 'Email',
      AppLanguage.arabic: 'البريد الإلكتروني',
    },
    'messageOptional': {
      AppLanguage.english: 'Message (optional)',
      AppLanguage.arabic: 'رسالة (اختياري)',
    },
    'submit': {
      AppLanguage.english: 'Submit',
      AppLanguage.arabic: 'إرسال',
    },
    'waitlistSuccess': {
      AppLanguage.english: 'You are on the waitlist.',
      AppLanguage.arabic: 'تم تسجيلك في قائمة الانتظار.',
    },
    'networkError': {
      AppLanguage.english:
          'Network unavailable. Please check your connection and try again.',
      AppLanguage.arabic:
          'تعذر الاتصال بالشبكة. يرجى التحقق من الاتصال والمحاولة مرة أخرى.',
    },
    'phase2Notice': {
      AppLanguage.english:
          'Create your account profile and continue into the live mobile flows.',
      AppLanguage.arabic:
          'أنشئ ملفك الشخصي ثم تابع إلى مسارات الجوال المتصلة بالخدمات الحية.',
    },
    'comingSoon': {
      AppLanguage.english: 'Coming soon',
      AppLanguage.arabic: 'قريبا',
    },
    'openPreviewShell': {
      AppLanguage.english: 'Open Mobile Workspace',
      AppLanguage.arabic: 'افتح مساحة العمل على الجوال',
    },
    'chat': {
      AppLanguage.english: 'Chat',
      AppLanguage.arabic: 'المحادثة',
    },
    'quran': {
      AppLanguage.english: 'Quran',
      AppLanguage.arabic: 'القرآن',
    },
    'prayer': {
      AppLanguage.english: 'Prayer',
      AppLanguage.arabic: 'الصلاة',
    },
    'community': {
      AppLanguage.english: 'Community',
      AppLanguage.arabic: 'المجتمع',
    },
    'knowledge': {
      AppLanguage.english: 'Knowledge',
      AppLanguage.arabic: 'المعرفة',
    },
    'featureDisabled': {
      AppLanguage.english:
          'This module is intentionally disabled until backend readiness is complete.',
      AppLanguage.arabic: 'هذه الوحدة معطلة عمدا حتى تكتمل جاهزية الخلفية.',
    },
    'enableFeatureHint': {
      AppLanguage.english:
          'Enable this module with a release flag once end-to-end APIs are production-ready.',
      AppLanguage.arabic:
          'فعّل هذه الوحدة بعلامة إصدار بعد اكتمال واجهات API بشكل إنتاجي.',
    },
    'language': {
      AppLanguage.english: 'Language',
      AppLanguage.arabic: 'اللغة',
    },
  };

  static String text(String key, AppLanguage language) {
    return _strings[key]?[language] ?? key;
  }
}
