//! PHASE 3 — Islamic corpus read/search endpoints (public) + citation guard.
//! Citations come from the DB corpus, never fabricated. Every Islamic answer's
//! citation validation result + source links are recorded (answer_source_links,
//! islamic_citation_checks, rag_retrieval_traces).

use actix_web::{web, HttpResponse};
use serde::Deserialize;
use serde_json::Value;
use sqlx::{PgPool, Row};

use crate::error::ApiError;

#[derive(Debug, Deserialize)]
pub struct SearchQuery {
    pub q: Option<String>,
}

// ----------------------------- Quran -----------------------------

pub async fn quran_surahs(pool: web::Data<PgPool>) -> Result<HttpResponse, ApiError> {
    let rows = sqlx::query(
        r#"SELECT surah_number, surah_name_en, surah_name_ar, count(*)::int AS ayah_count
           FROM sakina_ai.corpus_quran GROUP BY surah_number, surah_name_en, surah_name_ar
           ORDER BY surah_number"#,
    )
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to list surahs"))?;
    let items: Vec<Value> = rows
        .into_iter()
        .map(|r| {
            serde_json::json!({
                "surah_number": r.get::<i32, _>("surah_number"),
                "name_en": r.get::<String, _>("surah_name_en"),
                "name_ar": r.get::<String, _>("surah_name_ar"),
                "ayah_count": r.get::<i32, _>("ayah_count"),
            })
        })
        .collect();
    Ok(HttpResponse::Ok().json(serde_json::json!({ "surahs": items, "count": items.len() })))
}

fn ayah_json(r: sqlx::postgres::PgRow) -> Value {
    serde_json::json!({
        "surah_number": r.get::<i32, _>("surah_number"),
        "ayah_number": r.get::<i32, _>("ayah_number"),
        "surah_name_en": r.get::<String, _>("surah_name_en"),
        "surah_name_ar": r.get::<String, _>("surah_name_ar"),
        "text_arabic": r.get::<String, _>("text_arabic"),
        "translation_en": r.get::<String, _>("translation_en"),
        "translation_source": r.get::<String, _>("translation_source"),
        "source_reference": r.get::<String, _>("source_reference"),
    })
}

pub async fn quran_surah(
    pool: web::Data<PgPool>,
    path: web::Path<i32>,
) -> Result<HttpResponse, ApiError> {
    let rows = sqlx::query(
        r#"SELECT surah_number, ayah_number, surah_name_en, surah_name_ar, text_arabic,
                  translation_en, translation_source, source_reference
           FROM sakina_ai.corpus_quran WHERE surah_number = $1 ORDER BY ayah_number"#,
    )
    .bind(path.into_inner())
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load surah"))?;
    if rows.is_empty() {
        return Err(ApiError::not_found("surah not found in seeded corpus"));
    }
    let items: Vec<Value> = rows.into_iter().map(ayah_json).collect();
    Ok(HttpResponse::Ok().json(serde_json::json!({ "ayahs": items, "count": items.len() })))
}

pub async fn quran_ayah(
    pool: web::Data<PgPool>,
    path: web::Path<(i32, i32)>,
) -> Result<HttpResponse, ApiError> {
    let (s, a) = path.into_inner();
    let row = sqlx::query(
        r#"SELECT surah_number, ayah_number, surah_name_en, surah_name_ar, text_arabic,
                  translation_en, translation_source, source_reference
           FROM sakina_ai.corpus_quran WHERE surah_number = $1 AND ayah_number = $2"#,
    )
    .bind(s)
    .bind(a)
    .fetch_optional(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load ayah"))?;
    match row {
        Some(r) => Ok(HttpResponse::Ok().json(ayah_json(r))),
        None => Err(ApiError::not_found("ayah not found in seeded corpus")),
    }
}

pub async fn quran_search(
    pool: web::Data<PgPool>,
    q: web::Query<SearchQuery>,
) -> Result<HttpResponse, ApiError> {
    let term = q.q.clone().unwrap_or_default();
    if term.trim().is_empty() {
        return Err(ApiError::bad_request("q is required"));
    }
    let rows = sqlx::query(
        r#"SELECT surah_number, ayah_number, surah_name_en, surah_name_ar, text_arabic,
                  translation_en, translation_source, source_reference
           FROM sakina_ai.corpus_quran
           WHERE translation_en ILIKE '%'||$1||'%' OR text_arabic ILIKE '%'||$1||'%'
           ORDER BY surah_number, ayah_number LIMIT 50"#,
    )
    .bind(&term)
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to search quran"))?;
    let items: Vec<Value> = rows.into_iter().map(ayah_json).collect();
    Ok(HttpResponse::Ok().json(serde_json::json!({ "results": items, "count": items.len() })))
}

pub async fn quran_tafsir(
    pool: web::Data<PgPool>,
    path: web::Path<(i32, i32)>,
) -> Result<HttpResponse, ApiError> {
    let (s, a) = path.into_inner();
    let rows = sqlx::query(
        r#"SELECT tafsir_source, tafsir_text, source_reference
           FROM sakina_ai.corpus_quran_tafsir WHERE surah_number = $1 AND ayah_number = $2"#,
    )
    .bind(s)
    .bind(a)
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load tafsir"))?;
    if rows.is_empty() {
        return Err(ApiError::not_found("no tafsir seeded for this ayah"));
    }
    let items: Vec<Value> = rows
        .into_iter()
        .map(|r| {
            serde_json::json!({
                "tafsir_source": r.get::<String, _>("tafsir_source"),
                "tafsir_text": r.get::<String, _>("tafsir_text"),
                "source_reference": r.get::<String, _>("source_reference"),
            })
        })
        .collect();
    Ok(HttpResponse::Ok().json(serde_json::json!({ "surah_number": s, "ayah_number": a, "tafsir": items })))
}

// ----------------------------- Hadith -----------------------------

fn hadith_json(r: sqlx::postgres::PgRow) -> Value {
    serde_json::json!({
        "collection": r.get::<String, _>("collection"),
        "book": r.get::<Option<String>, _>("book"),
        "hadith_number": r.get::<String, _>("hadith_number"),
        "narrator": r.get::<Option<String>, _>("narrator"),
        "text_arabic": r.get::<Option<String>, _>("text_arabic"),
        "text_english": r.get::<String, _>("text_english"),
        "grading": r.get::<String, _>("grading"),
        "source_reference": r.get::<String, _>("source_reference"),
    })
}

pub async fn hadith_collections(pool: web::Data<PgPool>) -> Result<HttpResponse, ApiError> {
    let rows = sqlx::query(
        r#"SELECT collection, count(*)::int AS n FROM sakina_ai.corpus_hadith
           GROUP BY collection ORDER BY collection"#,
    )
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to list collections"))?;
    let items: Vec<Value> = rows
        .into_iter()
        .map(|r| serde_json::json!({ "collection": r.get::<String, _>("collection"), "count": r.get::<i32, _>("n") }))
        .collect();
    Ok(HttpResponse::Ok().json(serde_json::json!({ "collections": items })))
}

pub async fn hadith_search(
    pool: web::Data<PgPool>,
    q: web::Query<SearchQuery>,
) -> Result<HttpResponse, ApiError> {
    let term = q.q.clone().unwrap_or_default();
    if term.trim().is_empty() {
        return Err(ApiError::bad_request("q is required"));
    }
    let rows = sqlx::query(
        r#"SELECT collection, book, hadith_number, narrator, text_arabic, text_english, grading, source_reference
           FROM sakina_ai.corpus_hadith
           WHERE text_english ILIKE '%'||$1||'%' OR tags ILIKE '%'||$1||'%' OR COALESCE(text_arabic,'') ILIKE '%'||$1||'%'
           ORDER BY collection, hadith_number LIMIT 50"#,
    )
    .bind(&term)
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to search hadith"))?;
    let items: Vec<Value> = rows.into_iter().map(hadith_json).collect();
    Ok(HttpResponse::Ok().json(serde_json::json!({ "results": items, "count": items.len() })))
}

pub async fn hadith_detail(
    pool: web::Data<PgPool>,
    path: web::Path<(String, String)>,
) -> Result<HttpResponse, ApiError> {
    let (collection, number) = path.into_inner();
    let row = sqlx::query(
        r#"SELECT collection, book, hadith_number, narrator, text_arabic, text_english, grading, source_reference
           FROM sakina_ai.corpus_hadith
           WHERE collection ILIKE $1 AND hadith_number = $2 LIMIT 1"#,
    )
    .bind(format!("%{}%", collection))
    .bind(&number)
    .fetch_optional(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load hadith"))?;
    match row {
        Some(r) => Ok(HttpResponse::Ok().json(hadith_json(r))),
        None => Err(ApiError::not_found("hadith not found in seeded corpus")),
    }
}

// ----------------------------- Sources / Fatwa -----------------------------

pub async fn islamic_sources(pool: web::Data<PgPool>) -> Result<HttpResponse, ApiError> {
    let rows = sqlx::query(
        r#"SELECT source_name, source_url, language, madhhab, category, trust_level,
                  allowed_usage, restricted_usage, citation_format
           FROM sakina_ai.corpus_islamic_sources ORDER BY trust_level, source_name"#,
    )
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to list sources"))?;
    let items: Vec<Value> = rows
        .into_iter()
        .map(|r| {
            serde_json::json!({
                "source_name": r.get::<String, _>("source_name"),
                "source_url": r.get::<Option<String>, _>("source_url"),
                "language": r.get::<String, _>("language"),
                "madhhab": r.get::<Option<String>, _>("madhhab"),
                "category": r.get::<String, _>("category"),
                "trust_level": r.get::<String, _>("trust_level"),
                "allowed_usage": r.get::<String, _>("allowed_usage"),
                "restricted_usage": r.get::<Option<String>, _>("restricted_usage"),
                "citation_format": r.get::<String, _>("citation_format"),
            })
        })
        .collect();
    Ok(HttpResponse::Ok().json(serde_json::json!({ "sources": items, "count": items.len() })))
}

pub async fn fatwa_search(
    pool: web::Data<PgPool>,
    q: web::Query<SearchQuery>,
) -> Result<HttpResponse, ApiError> {
    let term = q.q.clone().unwrap_or_default();
    let rows = sqlx::query(
        r#"SELECT title, source_name, reference_url, topic, summary
           FROM sakina_ai.corpus_fatwa_refs
           WHERE ($1 = '' OR title ILIKE '%'||$1||'%' OR topic ILIKE '%'||$1||'%' OR summary ILIKE '%'||$1||'%')
           ORDER BY topic LIMIT 50"#,
    )
    .bind(&term)
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to search fatwa refs"))?;
    let items: Vec<Value> = rows
        .into_iter()
        .map(|r| {
            serde_json::json!({
                "title": r.get::<String, _>("title"),
                "source_name": r.get::<String, _>("source_name"),
                "reference_url": r.get::<Option<String>, _>("reference_url"),
                "topic": r.get::<String, _>("topic"),
                "summary": r.get::<String, _>("summary"),
            })
        })
        .collect();
    Ok(HttpResponse::Ok().json(serde_json::json!({ "results": items, "count": items.len() })))
}

// ----------------------------- Citation guard -----------------------------

#[derive(Debug, Deserialize)]
pub struct CitationCheckQuery {
    pub trace_id: String,
}

pub async fn citation_check(
    pool: web::Data<PgPool>,
    q: web::Query<CitationCheckQuery>,
) -> Result<HttpResponse, ApiError> {
    let check = sqlx::query(
        r#"SELECT result, reason, citation_count, created_at::text AS created_at
           FROM sakina_ai.islamic_citation_checks WHERE trace_id = $1
           ORDER BY created_at DESC LIMIT 1"#,
    )
    .bind(&q.trace_id)
    .fetch_optional(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load citation check"))?;
    let links = sqlx::query(
        r#"SELECT source_type, source_ref, citation_text FROM sakina_ai.answer_source_links
           WHERE trace_id = $1 ORDER BY created_at"#,
    )
    .bind(&q.trace_id)
    .fetch_all(pool.get_ref())
    .await
    .map_err(|_| ApiError::internal("failed to load source links"))?;
    let link_items: Vec<Value> = links
        .into_iter()
        .map(|r| {
            serde_json::json!({
                "source_type": r.get::<String, _>("source_type"),
                "source_ref": r.get::<String, _>("source_ref"),
                "citation_text": r.get::<Option<String>, _>("citation_text"),
            })
        })
        .collect();
    let check_json = check.map(|r| {
        serde_json::json!({
            "result": r.get::<String, _>("result"),
            "reason": r.get::<Option<String>, _>("reason"),
            "citation_count": r.get::<i32, _>("citation_count"),
            "created_at": r.get::<String, _>("created_at"),
        })
    });
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "trace_id": q.trace_id,
        "citation_check": check_json,
        "source_links": link_items,
    })))
}

/// Classify one citation as a recognised, sourced reference.
fn classify_citation(c: &Value) -> Option<(String, String)> {
    let st = c.get("source_type").and_then(Value::as_str).unwrap_or("");
    let ayah = c.get("ayah").and_then(Value::as_str);
    let title = c.get("title").and_then(Value::as_str).unwrap_or("");
    let chapter = c.get("chapter").and_then(Value::as_str).unwrap_or("");
    if st == "quran" {
        if let Some(a) = ayah.filter(|v| !v.is_empty()) {
            return Some(("quran".into(), format!("Quran {a}")));
        }
    }
    if st == "hadith" && !title.is_empty() {
        return Some(("hadith".into(), title.to_string()));
    }
    if !title.is_empty() {
        return Some((
            if st.is_empty() { "reference".into() } else { st.into() },
            title.to_string(),
        ));
    }
    if !chapter.is_empty() {
        return Some(("reference".into(), chapter.to_string()));
    }
    None
}

/// PHASE 3 citation guard: record the validation result + source links + a RAG
/// retrieval trace for an Islamic answer. Blocking of uncited answers is done in
/// sakina_ask.rs (SAK-005); this records the outcome so it is auditable.
pub async fn persist_citation_trace(
    pool: &PgPool,
    trace_id: &str,
    intent: &str,
    query: &str,
    citations: &Value,
    blocked: bool,
    safety_state: &str,
) {
    let is_islamic = !matches!(intent, "emotional_support");
    if !is_islamic {
        let _ = sqlx::query(
            "INSERT INTO sakina_ai.islamic_citation_checks (trace_id, result, reason, citation_count) VALUES ($1,'not_required','non-fiqh intent',0)",
        )
        .bind(trace_id)
        .execute(pool)
        .await;
        return;
    }

    let mut valid: Vec<(String, String)> = Vec::new();
    if let Some(arr) = citations.as_array() {
        for c in arr {
            if let Some(link) = classify_citation(c) {
                valid.push(link);
            }
        }
    }
    let count = valid.len() as i32;

    let (result, reason) = if safety_state == "ESCALATED_TO_HUMAN" {
        ("escalated", "high-risk fatwa escalated to scholar")
    } else if blocked {
        ("blocked", "answer blocked / insufficient verified citations")
    } else if count > 0 {
        ("valid", "answer carries verified corpus citations")
    } else {
        ("blocked", "no verified citation for Islamic answer")
    };

    let _ = sqlx::query(
        "INSERT INTO sakina_ai.islamic_citation_checks (trace_id, result, reason, citation_count) VALUES ($1,$2,$3,$4)",
    )
    .bind(trace_id)
    .bind(result)
    .bind(reason)
    .bind(count)
    .execute(pool)
    .await;

    for (stype, sref) in &valid {
        let _ = sqlx::query(
            "INSERT INTO sakina_ai.answer_source_links (trace_id, source_type, source_ref, citation_text) VALUES ($1,$2,$3,$4)",
        )
        .bind(trace_id)
        .bind(stype)
        .bind(sref)
        .bind(sref)
        .execute(pool)
        .await;
    }

    let top_ref = valid.first().map(|(_, r)| r.clone());
    let _ = sqlx::query(
        "INSERT INTO sakina_ai.rag_retrieval_traces (trace_id, query, corpus, hit_count, top_ref) VALUES ($1,$2,'corpus',$3,$4)",
    )
    .bind(trace_id)
    .bind(query)
    .bind(count)
    .bind(top_ref)
    .execute(pool)
    .await;
}
