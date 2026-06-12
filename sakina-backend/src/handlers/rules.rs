use crate::models::rules::{RulesEvaluateRequest, RulesEvaluateResponse};
use actix_web::{web, HttpResponse};
use serde_json::json;

pub async fn evaluate(payload: web::Json<RulesEvaluateRequest>) -> HttpResponse {
    let request = payload.into_inner();
    let message = request.message.to_ascii_lowercase();
    let language = request.language.to_ascii_lowercase();

    // 1. Crisis / Emergency Detection
    if detects_crisis(&message) {
        return HttpResponse::Ok().json(RulesEvaluateResponse {
            allowed: false,
            action: "escalate".to_string(),
            reason: "crisis_detected".to_string(),
            fallback_answer: Some(if language == "ar" {
                "إذا كنت في خطر مباشر أو تفكر في إيذاء نفسك، اتصل بخدمات الطوارئ الآن.".to_string()
            } else {
                "If you are in immediate danger or may harm yourself, contact emergency services now.".to_string()
            }),
        });
    }

    // 2. Out of Scope / Harmful Detection
    if is_out_of_scope(&message) {
        return HttpResponse::Ok().json(RulesEvaluateResponse {
            allowed: false,
            action: "block".to_string(),
            reason: "out_of_scope".to_string(),
            fallback_answer: Some(if language == "ar" {
                "لا أستطيع المساعدة في طلبات خارج نطاق الدعم الإسلامي الآمن.".to_string()
            } else {
                "I cannot help with out-of-scope or harmful requests.".to_string()
            }),
        });
    }

    // 3. Fabricated Ritual Detection
    if is_fabricated_ritual(&message) {
        return HttpResponse::Ok().json(RulesEvaluateResponse {
            allowed: false,
            action: "block".to_string(),
            reason: "fabricated_ritual".to_string(),
            fallback_answer: Some(if language == "ar" {
                "لا أستطيع العثور على حكم سني موثوق لهذا السؤال.".to_string()
            } else {
                "I cannot find a verified Sunni ruling on this in my current database.".to_string()
            }),
        });
    }

    // 4. High Risk Fatwa Detection
    if is_high_risk_fatwa(&message) {
        return HttpResponse::Ok().json(RulesEvaluateResponse {
            allowed: false,
            action: "escalate".to_string(),
            reason: "scholar_review_required".to_string(),
            fallback_answer: Some(if language == "ar" {
                "هذا سؤال فتوى حساس يحتاج عالمًا مؤهلًا يراجع التفاصيل.".to_string()
            } else {
                "This is a sensitive fatwa question that requires a qualified scholar to review the details.".to_string()
            }),
        });
    }

    HttpResponse::Ok().json(RulesEvaluateResponse {
        allowed: true,
        action: "allow".to_string(),
        reason: "safe_to_proceed".to_string(),
        fallback_answer: None,
    })
}

fn detects_crisis(text: &str) -> bool {
    [
        "kill myself",
        "self harm",
        "suicide",
        "انتحار",
        "إيذاء النفس",
    ]
    .iter()
    .any(|&needle| text.contains(needle))
}

fn is_out_of_scope(text: &str) -> bool {
    ["hacking", "malware", "illegal", "drugs", "porn"]
        .iter()
        .any(|&needle| text.contains(needle))
}

fn is_fabricated_ritual(text: &str) -> bool {
    // Example: Maghrib with 4 rakats
    let maghrib_four = (text.contains("maghrib") || text.contains("المغرب"))
        && (text.contains("4 rakat") || text.contains("٤ ركعات") || text.contains("4 ركعات"));

    let stop_maghrib = text.contains("stop praying maghrib") || text.contains("ترك صلاة المغرب");

    maghrib_four || stop_maghrib
}

fn is_high_risk_fatwa(text: &str) -> bool {
    [
        "divorce",
        "inheritance",
        "killing",
        "war",
        "طلاق",
        "ميراث",
        "قتل",
        "حرب",
        "talaq",
        "marriage separation",
        "binding fatwa",
        "final fatwa",
        "is my divorce valid",
        "marriage separation",
    ]
    .iter()
    .any(|&needle| text.contains(needle))
}
