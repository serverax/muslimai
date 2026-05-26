import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
    Locale('ur'),
    Locale('tr'),
    Locale('id'),
  ];

  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const rtlLanguages = <String>{'ar', 'ur'};

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static Locale resolve(Locale? locale, Iterable<Locale> supportedLocales) {
    if (locale == null) return const Locale('en');

    for (final supported in supportedLocales) {
      if (supported.languageCode == locale.languageCode) {
        return supported;
      }
    }
    return const Locale('en');
  }

  bool get isRtl => rtlLanguages.contains(locale.languageCode);

  String get appTitle => _t('appTitle');
  String get home => _t('home');
  String get tutoring => _t('tutoring');
  String get quran => _t('quran');
  String get prayer => _t('prayer');
  String get parent => _t('parent');
  String get homeSummary => _t('homeSummary');
  String get askSakina => _t('askSakina');
  String get openCompanionChat => _t('openCompanionChat');
  String get continueLearning => _t('continueLearning');
  String get continueLearningSummary => _t('continueLearningSummary');
  String get quranFocus => _t('quranFocus');
  String get quranFocusSummary => _t('quranFocusSummary');
  String get prayerRhythm => _t('prayerRhythm');
  String get prayerRhythmSummary => _t('prayerRhythmSummary');
  String get tutoringSummary => _t('tutoringSummary');
  String get quranSummary => _t('quranSummary');
  String get prayerSummary => _t('prayerSummary');
  String get parentSummary => _t('parentSummary');

  String _t(String key) {
    final language = _strings[locale.languageCode] ?? _strings['en']!;
    return language[key] ?? _strings['en']![key]!;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
        (supported) => supported.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

const _strings = <String, Map<String, String>>{
  'en': {
    'appTitle': 'Project Sakina',
    'home': 'Home',
    'tutoring': 'Tutoring',
    'quran': 'Quran',
    'prayer': 'Prayer',
    'parent': 'Parent',
    'homeSummary':
        'A calm starting point for guidance, learning, Quran, prayer, and family care.',
    'askSakina': 'Ask Sakina',
    'openCompanionChat': 'Open the companion chat',
    'continueLearning': 'Continue Learning',
    'continueLearningSummary':
        'Resume tutoring sessions from the Tutoring tab.',
    'quranFocus': 'Quran Focus',
    'quranFocusSummary': 'Jump into recitation, memorization, and tafsir work.',
    'prayerRhythm': 'Prayer Rhythm',
    'prayerRhythmSummary': 'Keep daily worship visible from the Prayer tab.',
    'tutoringSummary': 'Personalized lessons and study support.',
    'quranSummary': 'Reading, memorization, and reflection tools.',
    'prayerSummary': 'Prayer times, qibla, and worship routines.',
    'parentSummary': 'Guardian view for progress and settings.',
  },
  'ar': {
    'appTitle': 'مشروع سكينة',
    'home': 'الرئيسية',
    'tutoring': 'التعليم',
    'quran': 'القرآن',
    'prayer': 'الصلاة',
    'parent': 'ولي الأمر',
    'homeSummary':
        'نقطة بداية هادئة للإرشاد والتعلم والقرآن والصلاة ورعاية الأسرة.',
    'askSakina': 'اسأل سكينة',
    'openCompanionChat': 'افتح محادثة المرافق',
    'continueLearning': 'تابع التعلم',
    'continueLearningSummary': 'استأنف جلسات التعليم من تبويب التعليم.',
    'quranFocus': 'تركيز القرآن',
    'quranFocusSummary': 'انتقل إلى التلاوة والحفظ والتفسير.',
    'prayerRhythm': 'إيقاع الصلاة',
    'prayerRhythmSummary': 'اجعل العبادة اليومية ظاهرة من تبويب الصلاة.',
    'tutoringSummary': 'دروس مخصصة ودعم للدراسة.',
    'quranSummary': 'أدوات للقراءة والحفظ والتدبر.',
    'prayerSummary': 'أوقات الصلاة والقبلة وروتين العبادة.',
    'parentSummary': 'واجهة ولي الأمر للمتابعة والإعدادات.',
  },
  'ur': {
    'appTitle': 'پروجیکٹ سکینہ',
    'home': 'ہوم',
    'tutoring': 'تعلیم',
    'quran': 'قرآن',
    'prayer': 'نماز',
    'parent': 'والدین',
    'homeSummary':
        'رہنمائی، تعلیم، قرآن، نماز، اور خاندانی دیکھ بھال کے لیے پرسکون آغاز۔',
    'askSakina': 'سکینہ سے پوچھیں',
    'openCompanionChat': 'ساتھی چیٹ کھولیں',
    'continueLearning': 'تعلیم جاری رکھیں',
    'continueLearningSummary': 'تعلیم کے ٹیب سے اسباق دوبارہ شروع کریں۔',
    'quranFocus': 'قرآن پر توجہ',
    'quranFocusSummary': 'تلاوت، حفظ، اور تفسیر کے کام میں جائیں۔',
    'prayerRhythm': 'نماز کا معمول',
    'prayerRhythmSummary': 'روزانہ عبادت کو نماز کے ٹیب میں نمایاں رکھیں۔',
    'tutoringSummary': 'ذاتی اسباق اور مطالعہ کی مدد۔',
    'quranSummary': 'پڑھنے، حفظ، اور غور و فکر کے اوزار۔',
    'prayerSummary': 'نماز کے اوقات، قبلہ، اور عبادت کے معمولات۔',
    'parentSummary': 'پیش رفت اور ترتیبات کے لیے والدین کا منظر۔',
  },
  'tr': {
    'appTitle': 'Project Sakina',
    'home': 'Ana Sayfa',
    'tutoring': 'Egitim',
    'quran': 'Kuran',
    'prayer': 'Namaz',
    'parent': 'Veli',
    'homeSummary':
        'Rehberlik, ogrenme, Kuran, namaz ve aile bakimi icin sakin bir baslangic.',
    'askSakina': 'Sakina’ya Sor',
    'openCompanionChat': 'Yardimci sohbeti ac',
    'continueLearning': 'Ogrenmeye Devam Et',
    'continueLearningSummary': 'Egitim sekmesinden ders oturumlarina devam et.',
    'quranFocus': 'Kuran Odagi',
    'quranFocusSummary': 'Tilavet, ezber ve tefsir calismalarina gec.',
    'prayerRhythm': 'Namaz Ritmi',
    'prayerRhythmSummary': 'Gunluk ibadeti Namaz sekmesinde gorunur tut.',
    'tutoringSummary': 'Kisisellestirilmis dersler ve calisma destegi.',
    'quranSummary': 'Okuma, ezber ve tefekkur araclari.',
    'prayerSummary': 'Namaz vakitleri, kible ve ibadet rutinleri.',
    'parentSummary': 'Ilerleme ve ayarlar icin veli gorunumu.',
  },
  'id': {
    'appTitle': 'Project Sakina',
    'home': 'Beranda',
    'tutoring': 'Belajar',
    'quran': 'Quran',
    'prayer': 'Salat',
    'parent': 'Orang Tua',
    'homeSummary':
        'Titik awal yang tenang untuk bimbingan, belajar, Quran, salat, dan keluarga.',
    'askSakina': 'Tanya Sakina',
    'openCompanionChat': 'Buka chat pendamping',
    'continueLearning': 'Lanjut Belajar',
    'continueLearningSummary': 'Lanjutkan sesi belajar dari tab Belajar.',
    'quranFocus': 'Fokus Quran',
    'quranFocusSummary': 'Masuk ke tilawah, hafalan, dan tafsir.',
    'prayerRhythm': 'Ritme Salat',
    'prayerRhythmSummary': 'Jaga ibadah harian terlihat dari tab Salat.',
    'tutoringSummary': 'Pelajaran personal dan dukungan belajar.',
    'quranSummary': 'Alat membaca, menghafal, dan refleksi.',
    'prayerSummary': 'Waktu salat, kiblat, dan rutinitas ibadah.',
    'parentSummary': 'Tampilan wali untuk progres dan pengaturan.',
  },
};
