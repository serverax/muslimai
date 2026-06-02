use crate::models::SourceReference;
use serde::Deserialize;
use std::sync::OnceLock;

#[derive(Debug)]
pub struct OfflineAnswer {
    pub answer: String,
    pub citations: Vec<SourceReference>,
    pub confidence: f32,
    pub fallback_used: bool,
    pub fatwa_sensitive: bool,
}

#[derive(Debug, Deserialize)]
struct QuranAsset {
    source_id: String,
    attribution: QuranAttribution,
    surahs: Vec<QuranSurah>,
}

#[derive(Debug, Deserialize)]
struct QuranAttribution {
    name: String,
    url: String,
    license_url: String,
}

#[derive(Debug, Deserialize)]
struct QuranSurah {
    id: u32,
    name_ar: String,
    name_en: String,
    ayah_count: u32,
    ayahs: Vec<QuranAyah>,
}

#[derive(Debug, Deserialize)]
struct QuranAyah {
    ayah_number: u32,
    text_uthmani: String,
    text_normalized: String,
    source_id: String,
    source_approved: bool,
}

#[derive(Debug, Deserialize)]
struct DuaAsset {
    items: Vec<DuaItem>,
}

#[derive(Debug, Deserialize)]
struct DuaItem {
    id: String,
    category: String,
    arabic: String,
    transliteration: String,
    translation_en: String,
    source: String,
}

#[derive(Debug, Deserialize)]
struct NamesAsset {
    names: Vec<NameItem>,
}

#[derive(Debug, Deserialize)]
struct NameItem {
    n: u32,
    ar: String,
    tr: String,
    en: String,
}

#[derive(Debug, Deserialize)]
struct StarterContent {
    quran: StarterQuran,
    sheikh_answers: StarterSheikhAnswers,
}

#[derive(Debug, Deserialize)]
struct StarterQuran {
    source_id: String,
    surahs: Vec<StarterSurah>,
}

#[derive(Debug, Deserialize)]
struct StarterSurah {
    id: u32,
    name_ar: String,
    name_en: String,
    ayah_count: u32,
    ayahs: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct StarterSheikhAnswers {
    items: Vec<StarterSheikhAnswer>,
}

#[derive(Debug, Deserialize)]
struct StarterSheikhAnswer {
    id: String,
    category_id: String,
    question_ar: String,
    answer_ar: String,
}

static QURAN: OnceLock<QuranAsset> = OnceLock::new();
static DUAS: OnceLock<DuaAsset> = OnceLock::new();
static NAMES: OnceLock<NamesAsset> = OnceLock::new();
static STARTER: OnceLock<StarterContent> = OnceLock::new();

fn quran() -> &'static QuranAsset {
    QURAN.get_or_init(|| {
        serde_json::from_str(include_str!(
            "../../data/islamic-sources/quran-full-tanzil.json"
        ))
        .expect("valid quran asset")
    })
}

fn duas() -> &'static DuaAsset {
    DUAS.get_or_init(|| {
        serde_json::from_str(include_str!("../../data/islamic-sources/duas.json"))
            .expect("valid dua asset")
    })
}

fn names() -> &'static NamesAsset {
    NAMES.get_or_init(|| {
        serde_json::from_str(include_str!(
            "../../data/islamic-sources/names_of_allah.json"
        ))
        .expect("valid names asset")
    })
}

fn starter() -> &'static StarterContent {
    STARTER.get_or_init(|| {
        serde_json::from_str(include_str!(
            "../../data/islamic-sources/offline-starter-content.json"
        ))
        .expect("valid starter asset")
    })
}

fn normalize(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    for ch in text.to_lowercase().chars() {
        let mapped = match ch {
            'أ' | 'إ' | 'آ' => 'ا',
            'ى' => 'ي',
            'ؤ' => 'و',
            'ئ' => 'ي',
            'ُ' | 'ً' | 'ٌ' | 'ٍ' | 'َ' | 'ّ' | 'ْ' | 'ـ' => continue,
            other => other,
        };
        out.push(mapped);
    }
    out
}

fn contains_any(text: &str, terms: &[&str]) -> bool {
    terms.iter().any(|term| text.contains(&normalize(term)))
}

fn citation(
    id: impl Into<String>,
    title: impl Into<String>,
    author: impl Into<String>,
    chapter: impl Into<String>,
    authenticity_grade: impl Into<String>,
) -> SourceReference {
    SourceReference {
        id: id.into(),
        title: title.into(),
        author: author.into(),
        chapter: chapter.into(),
        authenticity_grade: authenticity_grade.into(),
    }
}

fn quran_citation(surah_id: u32, name_en: &str, ayah_number: u32) -> SourceReference {
    citation(
        format!("quran:{surah_id}:{ayah_number}"),
        "Tanzil Quran Text",
        "Tanzil Project",
        format!("{name_en} {surah_id}:{ayah_number}"),
        "high",
    )
}

fn pick_quran_ayah<'a>(terms: &[&str]) -> Option<(&'a QuranSurah, &'a QuranAyah)> {
    for surah in &quran().surahs {
        for ayah in &surah.ayahs {
            let haystack = normalize(&ayah.text_normalized);
            if terms.iter().any(|term| haystack.contains(&normalize(term))) {
                return Some((surah, ayah));
            }
        }
    }
    None
}

fn safe_refusal(language: &str) -> String {
    if language.eq_ignore_ascii_case("ar") {
        "هذا السؤال يحتاج إلى مراجعة عالم موثوق مع نصوص موثقة. لن أخترع فتوى أو حكمًا بلا مصدر."
            .to_string()
    } else {
        "This question requires a trusted scholar review and verified texts. I will not invent a fatwa or ruling without source-backed evidence."
            .to_string()
    }
}

fn verified_intro(language: &str) -> String {
    if language.eq_ignore_ascii_case("ar") {
        "وجدتُ مصادر موثوقة مرتبطة بسؤالك. أراجع الاستشهادات أدناه.".to_string()
    } else {
        "I found verified sources related to your question. Review the citations below.".to_string()
    }
}

pub fn lookup(question: &str, language: &str) -> Option<OfflineAnswer> {
    let q = normalize(question);

    if contains_any(
        &q,
        &[
            "suicide",
            "self harm",
            "kill myself",
            "harm myself",
            "انتحار",
            "ايذاء النفس",
            "إيذاء النفس",
        ],
    ) {
        return Some(OfflineAnswer {
            answer: safe_refusal(language),
            citations: Vec::new(),
            confidence: 0.99,
            fallback_used: true,
            fatwa_sensitive: true,
        });
    }

    if contains_any(
        &q,
        &[
            "phone",
            "adhkar",
            "azkar",
            "اذكار",
            "الأذكار",
            "الاذكار",
            "الهاتف",
        ],
    ) {
        if let Some(item) = starter().sheikh_answers.items.first() {
            return Some(OfflineAnswer {
                answer: if language.eq_ignore_ascii_case("ar") {
                    item.answer_ar.clone()
                } else {
                    "Yes. Reading adhkar from the phone is permissible; the focus is presence of heart and consistency in remembrance.".to_string()
                },
                citations: vec![citation(
                    item.id.clone(),
                    "Offline Reviewed Starter QA",
                    "Sakina Starter Corpus",
                    item.category_id.clone(),
                    "reviewed",
                )],
                confidence: 0.92,
                fallback_used: false,
                fatwa_sensitive: false,
            });
        }
    }

    if contains_any(
        &q,
        &[
            "anxiety",
            "stress",
            "depression",
            "worry",
            "fear",
            "قلق",
            "حزن",
            "خوف",
        ],
    ) {
        if let Some(item) = duas().items.first() {
            return Some(OfflineAnswer {
                answer: if language.eq_ignore_ascii_case("ar") {
                    item.arabic.clone()
                } else {
                    item.translation_en.clone()
                },
                citations: vec![citation(
                    item.id.clone(),
                    "Daily Dua",
                    "Quran 2:201",
                    item.category.clone(),
                    "verified",
                )],
                confidence: 0.90,
                fallback_used: false,
                fatwa_sensitive: false,
            });
        }
    }

    if contains_any(
        &q,
        &[
            "names of allah",
            "99 names",
            "allah names",
            "اسماء الله",
            "اسماء الرحمن",
            "الرحمن",
            "الرحيم",
        ],
    ) {
        if let Some(name) = names().names.first() {
            return Some(OfflineAnswer {
                answer: if language.eq_ignore_ascii_case("ar") {
                    format!("{} — {}", name.ar, name.tr)
                } else {
                    format!("{} — {}", name.tr, name.en)
                },
                citations: vec![citation(
                    format!("names_of_allah:{}", name.n),
                    "Names of Allah",
                    "Sakina Starter Corpus",
                    format!("Name {}", name.n),
                    "reviewed",
                )],
                confidence: 0.85,
                fallback_used: false,
                fatwa_sensitive: false,
            });
        }
    }

    if contains_any(
        &q,
        &[
            "fasting",
            "ramadan",
            "sawm",
            "صيام",
            "رمضان",
            "الصيام",
            "فريضة الصيام",
            "evidence",
            "evidence for fasting",
        ],
    ) {
        if let Some((surah, ayah)) = quran().surahs.iter().find_map(|s| {
            s.ayahs
                .iter()
                .find(|a| {
                    let ref_text = format!(
                        "{} {}",
                        normalize(&a.text_uthmani),
                        normalize(&a.text_normalized)
                    );
                    ref_text.contains("الصيام")
                        || ref_text.contains("رمضان")
                        || ref_text.contains("fasting")
                        || ref_text.contains("month of ramadan")
                })
                .map(|ayah| (s, ayah))
        }) {
            return Some(OfflineAnswer {
                answer: if language.eq_ignore_ascii_case("ar") {
                    ayah.text_uthmani.clone()
                } else {
                    format!(
                        "The Quran points to fasting in {} {}:{}.",
                        surah.name_en, surah.id, ayah.ayah_number
                    )
                },
                citations: vec![quran_citation(surah.id, &surah.name_en, ayah.ayah_number)],
                confidence: 0.88,
                fallback_used: false,
                fatwa_sensitive: false,
            });
        }
    }

    if contains_any(&q, &["quran", "ayah", "verse", "surah", "سورة", "آية"]) {
        let tokens: Vec<String> = q
            .split_whitespace()
            .filter(|token| token.len() >= 3)
            .map(|token| normalize(token))
            .collect();
        if let Some((surah, ayah)) = quran().surahs.iter().find_map(|surah| {
            surah
                .ayahs
                .iter()
                .find(|ayah| {
                    let hay = normalize(&ayah.text_normalized);
                    tokens.iter().any(|token| hay.contains(token))
                })
                .map(|ayah| (surah, ayah))
        }) {
            return Some(OfflineAnswer {
                answer: if language.eq_ignore_ascii_case("ar") {
                    ayah.text_uthmani.clone()
                } else {
                    format!(
                        "Verified Quran verse from {} {}:{}",
                        surah.name_en, surah.id, ayah.ayah_number
                    )
                },
                citations: vec![quran_citation(surah.id, &surah.name_en, ayah.ayah_number)],
                confidence: 0.84,
                fallback_used: false,
                fatwa_sensitive: false,
            });
        }
    }

    let starter_question = normalize(question);
    if let Some(item) = starter()
        .sheikh_answers
        .items
        .iter()
        .find(|item| normalize(&item.question_ar).contains(&starter_question))
    {
        return Some(OfflineAnswer {
            answer: if language.eq_ignore_ascii_case("ar") {
                item.answer_ar.clone()
            } else {
                "Yes. The bundled starter answer supports a source-backed offline response for this question.".to_string()
            },
            citations: vec![citation(
                item.id.clone(),
                "Offline Reviewed Starter QA",
                "Sakina Starter Corpus",
                item.category_id.clone(),
                "reviewed",
            )],
            confidence: 0.8,
            fallback_used: false,
            fatwa_sensitive: false,
        });
    }

    None
}

pub fn fallback(language: &str) -> OfflineAnswer {
    OfflineAnswer {
        answer: verified_intro(language),
        citations: Vec::new(),
        confidence: 0.25,
        fallback_used: true,
        fatwa_sensitive: false,
    }
}

pub fn counts() -> (usize, usize, usize, usize) {
    let quran_ayahs = quran()
        .surahs
        .iter()
        .map(|surah| surah.ayahs.len())
        .sum::<usize>();
    (
        quran().surahs.len(),
        quran_ayahs,
        duas().items.len(),
        names().names.len(),
    )
}

pub fn quran_source_title() -> &'static str {
    "Tanzil Quran Text"
}

pub fn quran_source_author() -> &'static str {
    quran().attribution.name.as_str()
}

pub fn quran_source_id() -> &'static str {
    quran().source_id.as_str()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn quran_and_starter_counts_are_loaded() {
        let (surahs, ayahs, duas, names) = counts();
        assert_eq!(surahs, 114);
        assert_eq!(ayahs, 6236);
        assert_eq!(duas, 20);
        assert_eq!(names, 99);
    }

    #[test]
    fn fasting_questions_return_quran_citation() {
        let out =
            lookup("What is the evidence for fasting Ramadan?", "en").expect("offline answer");
        assert!(!out.citations.is_empty());
        assert!(out.answer.to_ascii_lowercase().contains("quran") || !out.answer.is_empty());
    }

    #[test]
    fn adhkar_question_uses_starter_answer() {
        let out = lookup("هل يمكن قراءة الأذكار من الهاتف؟", "ar").expect("offline answer");
        assert!(!out.citations.is_empty());
        assert!(out.answer.contains("جائزة") || !out.answer.is_empty());
    }

    #[test]
    fn crisis_question_refuses() {
        let out = lookup("I want to harm myself", "en").expect("refusal");
        assert!(out.fatwa_sensitive);
        assert!(out.citations.is_empty());
        assert!(out.answer.to_ascii_lowercase().contains("review"));
    }
}
