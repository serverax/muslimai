use actix_web::{web, HttpRequest, HttpResponse, ResponseError};
use serde_json::{json, Value};
use sqlx::Row;
use uuid::Uuid;

use crate::error::error_response;
use crate::models::{
    BrainRouteRequest, SakinaAskRequest, SakinaAskResponse, SakinaSafetyStatus, SakinaSourcePath,
};
use crate::services::{
    authenticated_user_id, pii_redaction::redact_pii, AiaOrchestrator, AskIslamicRequest,
    IslamicAnswerService, SakinaLlmGateway, SakinaLlmGatewayRequest,
};

fn detect_language(message: &str, requested: Option<&str>) -> String {
    match requested.map(str::trim).filter(|value| !value.is_empty()) {
        Some(value) if !value.eq_ignore_ascii_case("auto") => value.to_ascii_lowercase(),
        _ if message
            .chars()
            .any(|ch| ('\u{0600}'..='\u{06ff}').contains(&ch)) =>
        {
            "ar".to_string()
        }
        _ => "en".to_string(),
    }
}

fn detect_intent(message: &str, section: &str) -> String {
    let q = message.to_ascii_lowercase();
    if section == "new_muslim_journey"
        || q.contains("new muslim")
        || q.contains("shahadah")
        || q.contains("convert")
        || q.contains("مسلم جديد")
    {
        "new_muslim".to_string()
    } else if q.contains("wudu") || q.contains("وضوء") || q.contains("الوضوء") {
        "wudu".to_string()
    } else if q.contains("salah") || q.contains("prayer") || q.contains("صلاة") {
        "salah".to_string()
    } else if q.contains("dua") || q.contains("دعاء") {
        "dua".to_string()
    } else if q.contains("anxious")
        || q.contains("anxiety")
        || q.contains("overwhelmed")
        || q.contains("قلق")
        || q.contains("خائف")
    {
        "emotional_support".to_string()
    } else {
        "islamic_guidance".to_string()
    }
}

fn topic_key_for_intent(message: &str, intent: &str, section: &str) -> Option<&'static str> {
    let q = message.to_ascii_lowercase();
    if intent == "wudu" || q.contains("wudu") {
        Some("wudu")
    } else if intent == "salah" || q.contains("fajr") || q.contains("prayer") {
        Some("salah")
    } else if intent == "dua" || q.contains("dua") {
        Some("basic_dua")
    } else if intent == "new_muslim" || section == "new_muslim_journey" {
        if q.contains("shahadah") {
            Some("shahadah")
        } else {
            Some("new_muslim_first_steps")
        }
    } else {
        None
    }
}

fn out_of_scope(message: &str) -> bool {
    let q = message.to_ascii_lowercase();
    [
        "hacking code",
        "exploit",
        "malware",
        "steal password",
        "bypass login",
        "write python hacking",
    ]
    .iter()
    .any(|needle| q.contains(needle))
}

fn crisis_or_emergency(message: &str) -> bool {
    let q = message.to_ascii_lowercase();
    [
        // self-harm / suicidal ideation — broadened recall (SAK-004)
        "kill myself",
        "kill me",
        "self harm",
        "self-harm",
        "harm myself",
        "hurt myself",
        "harming myself",
        "end my life",
        "end it all",
        "take my life",
        "want to die",
        "wanna die",
        "don't want to live",
        "dont want to live",
        "no reason to live",
        "no point in living",
        "better off dead",
        "suicide",
        "suicidal",
        // medical emergencies
        "medical emergency",
        "chest pain",
        "can't breathe",
        "cant breathe",
        "overdose",
        // Arabic
        "انتحار",
        "أريد أن أموت",
        "اريد ان اموت",
        "أنهي حياتي",
        "انهي حياتي",
        "إيذاء النفس",
        "ايذاء النفس",
        "أؤذي نفسي",
        "اؤذي نفسي",
    ]
    .iter()
    .any(|needle| q.contains(needle))
}

pub fn high_risk_fatwa(message: &str) -> bool {
    let q = message.to_ascii_lowercase();
    q.contains("final fatwa")
        || q.contains("complex divorce")
        || q.contains("divorce situation")
        || q.contains("binding fatwa")
        || q.contains("فتوى")
        || q.contains("طلاق")
        || q.contains("divorce")
        || q.contains("talaq")
        || q.contains("inheritance")
        || q.contains("marriage separation")
        || q.contains("killing")
        || q.contains("war")
}

fn fabricated_or_unsupported_ritual_claim(message: &str) -> bool {
    let q = message.to_ascii_lowercase();
    let maghrib_four = (q.contains("maghrib") || q.contains("مغرب"))
        && (q.contains("4 rakats")
            || q.contains("four rakats")
            || q.contains("four raka")
            || q.contains("٤")
            || q.contains("أربع")
            || q.contains("اربع"));
    let artificial_day_condition = q.contains("on a tuesday") || q.contains("يوم الثلاثاء");
    maghrib_four && (artificial_day_condition || q.contains("halal") || q.contains("حلال"))
}

async fn ensure_default_workspace(
    pool: &sqlx::PgPool,
    user_id: Uuid,
) -> Result<Uuid, HttpResponse> {
    sqlx::query_scalar::<_, Uuid>("SELECT sakina_ai.ensure_default_workspace($1)")
        .bind(user_id)
        .fetch_one(pool)
        .await
        .map_err(|err| {
            tracing::error!("ensure default workspace failed: {err}");
            error_response(
                actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
                "internal_error",
                "failed to load user workspace",
            )
        })
}

async fn local_topic(
    pool: &sqlx::PgPool,
    topic_key: Option<&str>,
    language: &str,
) -> Result<Option<Value>, HttpResponse> {
    let Some(topic_key) = topic_key else {
        return Ok(None);
    };
    sqlx::query(
        r#"
        SELECT topic_key, language, section, intent, title, answer, citations, next_steps
        FROM sakina_ai.local_sunni_topics
        WHERE topic_key = $1 AND language = $2
        LIMIT 1
        "#,
    )
    .bind(topic_key)
    .bind(language)
    .fetch_optional(pool)
    .await
    .map(|row| {
        row.map(|row| {
            json!({
                "topic_key": row.get::<String, _>("topic_key"),
                "language": row.get::<String, _>("language"),
                "section": row.get::<String, _>("section"),
                "intent": row.get::<String, _>("intent"),
                "title": row.get::<String, _>("title"),
                "answer": row.get::<String, _>("answer"),
                "citations": row.get::<Value, _>("citations"),
                "next_steps": row.get::<Value, _>("next_steps"),
            })
        })
    })
    .map_err(|err| {
        tracing::error!("local topic lookup failed: {err}");
        error_response(
            actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
            "internal_error",
            "failed to query local Sunni topic DB",
        )
    })
}

struct PersistTraceInput<'a> {
    trace_id: &'a str,
    user_id: Uuid,
    workspace_id: Uuid,
    language: &'a str,
    intent: &'a str,
    source_path: &'a SakinaSourcePath,
    safety: &'a SakinaSafetyStatus,
    execution_trace: Value,
    answer: &'a str,
    citations: &'a Value,
    redacted_message: &'a str,
}

async fn persist_trace(
    pool: &sqlx::PgPool,
    input: PersistTraceInput<'_>,
) -> Result<(), HttpResponse> {
    sqlx::query(
        r#"
        INSERT INTO sakina_ai.brain_decision_traces (
            request_id, user_id, workspace_id, input_type, intent, language, risk_level,
            selected_agent, selected_model, selected_pipeline, source_strategy,
            evaluation_result, final_action, audit_event_id, execution_trace
        )
        VALUES ($1, $2, $3, 'sakina_ask', $4, $5, $6, 'Mother Algorithm', $7,
                'sakina_mother_algorithm', $8, $9, $10, $11, $12)
        "#,
    )
    .bind(input.trace_id)
    .bind(input.user_id.to_string())
    .bind(input.workspace_id)
    .bind(input.intent)
    .bind(input.language)
    .bind(
        if input.safety.crisis_detected || high_risk_fatwa(input.redacted_message) {
            "high"
        } else {
            "normal"
        },
    )
    .bind(if input.source_path.llm_used {
        "sakina-islamic-support:cpu"
    } else {
        "local_db_rag_graph"
    })
    .bind(input.source_path.answer_source.as_str())
    .bind(if input.safety.guardrails_passed {
        "PASS"
    } else {
        "BLOCK"
    })
    .bind(if input.source_path.blocked {
        "blocked_or_escalated"
    } else {
        "answer_returned"
    })
    .bind(Uuid::new_v4().to_string())
    .bind(input.execution_trace)
    .execute(pool)
    .await
    .map_err(|err| {
        tracing::error!("sakina ask brain trace persistence failed: {err}");
        error_response(
            actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
            "internal_error",
            "failed to persist Sakina ask trace",
        )
    })?;

    sqlx::query(
        r#"
        INSERT INTO sakina_ai.ask_shaikh_answers (
            trace_id, user_id, workspace_id, language, intent, question_redacted,
            answer, citations, source_path, safety
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        "#,
    )
    .bind(input.trace_id)
    .bind(input.user_id)
    .bind(input.workspace_id)
    .bind(input.language)
    .bind(input.intent)
    .bind(input.redacted_message)
    .bind(input.answer)
    .bind(input.citations)
    .bind(serde_json::to_value(input.source_path).unwrap_or_else(|_| json!({})))
    .bind(serde_json::to_value(input.safety).unwrap_or_else(|_| json!({})))
    .execute(pool)
    .await
    .map_err(|err| {
        tracing::error!("sakina ask answer persistence failed: {err}");
        error_response(
            actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
            "internal_error",
            "failed to persist Sakina answer",
        )
    })?;
    Ok(())
}

async fn persist_anonymous_learning(
    pool: &sqlx::PgPool,
    trace_id: &str,
    language: &str,
    intent: &str,
    section: &str,
    pii_removed: bool,
) {
    let _ = sqlx::query(
        r#"
        INSERT INTO sakina_ai.anonymous_learning_events (
            trace_id, language, intent, section, pii_removed, safe_pattern, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        "#,
    )
    .bind(trace_id)
    .bind(language)
    .bind(intent)
    .bind(section)
    .bind(pii_removed)
    .bind(format!(
        "section={section};intent={intent};language={language}"
    ))
    .bind(json!({
        "anonymous_only": true,
        "raw_user_message_saved": false,
        "private_memory": false,
        "model_learning": false,
    }))
    .execute(pool)
    .await;
}

async fn enqueue_scholar_review(pool: &sqlx::PgPool, trace_uuid: Uuid, notes: &str) -> bool {
    // SAK-022: do not silently swallow a failed escalation insert. Log it and
    // report success so the caller can avoid telling the user "escalated" falsely.
    match sqlx::query(
        r#"
        INSERT INTO sakina_ai.scholar_review_queue (
            request_id, priority, review_status, reviewer_notes
        )
        VALUES ($1, 'high', 'pending', $2)
        "#,
    )
    .bind(trace_uuid)
    .bind(notes)
    .execute(pool)
    .await
    {
        Ok(_) => true,
        Err(e) => {
            tracing::error!(trace_id = %trace_uuid, "failed to enqueue scholar review: {:?}", e);
            false
        }
    }
}

pub async fn ask(
    req: HttpRequest,
    aia: web::Data<AiaOrchestrator>,
    answer_service: web::Data<IslamicAnswerService>,
    llm_gateway: web::Data<SakinaLlmGateway>,
    distributed_client: web::Data<crate::services::distributed::DistributedClient>,
    pool: web::Data<sqlx::PgPool>,
    payload: web::Json<SakinaAskRequest>,
) -> HttpResponse {
    // Distributed architecture: if SAKINA_BRAIN_URL is set, we are the API gateway,
    // so we call the Brain service (which then executes locally).
    if let Ok(brain_url) = std::env::var("SAKINA_BRAIN_URL") {
        if !brain_url.trim().is_empty() {
            let auth_header = req
                .headers()
                .get("Authorization")
                .and_then(|h| h.to_str().ok());
            match distributed_client
                .answer_sakina(&brain_url, &payload, auth_header)
                .await
            {
                Ok(response) => return HttpResponse::Ok().json(response),
                Err(err) => return err.error_response(),
            }
        }
    }

    let user_id = match authenticated_user_id(&req, pool.get_ref()).await {
        Ok(user_id) => user_id,
        Err(err) => return err.error_response(),
    };
    let message = payload.message.trim();
    if message.is_empty() {
        return error_response(
            actix_web::http::StatusCode::BAD_REQUEST,
            "bad_request",
            "message is required",
        );
    }

    let workspace_id = match ensure_default_workspace(pool.get_ref(), user_id).await {
        Ok(id) => id,
        Err(response) => return response,
    };
    let section = payload
        .section
        .clone()
        .unwrap_or_else(|| "ask_sakina".to_string());
    let redaction = redact_pii(message);
    let safe_message = redaction.redacted_text;
    let language = detect_language(&safe_message, payload.language.as_deref());
    let intent = detect_intent(&safe_message, &section);
    let trace_uuid = Uuid::new_v4();
    let trace_id = trace_uuid.to_string();

    let mut source_path = SakinaSourcePath {
        local_db_checked: true,
        rag_checked: false,
        graph_rag_checked: false,
        llm_used: false,
        answer_source: "none".to_string(),
        blocked: false,
    };
    let mut safety_state = "ALLOWED_WITH_GUARDRAILS".to_string();
    let mut safety = SakinaSafetyStatus {
        pii_removed: redaction.pii_detected,
        guardrails_passed: true,
        crisis_detected: crisis_or_emergency(&safe_message),
        out_of_scope_blocked: out_of_scope(&safe_message),
    };

    let mut answer = String::new();
    let mut citations = json!([]);
    let mut local_db_context = json!(null);
    let mut rag_context = json!(null);
    let mut graph_context = json!(null);
    let mut graph_path = Vec::<String>::new();
    let mut model_provider = "local_db_rag_graph".to_string();
    let mut llm_model = None;

    let local_topic = match local_topic(
        pool.get_ref(),
        topic_key_for_intent(&safe_message, &intent, &section),
        &language,
    )
    .await
    {
        Ok(value) => value,
        Err(response) => return response,
    };
    if let Some(topic) = local_topic {
        answer = topic
            .get("answer")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_string();
        citations = topic.get("citations").cloned().unwrap_or_else(|| json!([]));
        local_db_context = topic;
        source_path.answer_source = "local_db".to_string();
    }

    // Distributed architecture: if SAKINA_RULES_ENGINE_URL is set, we call the Rules Engine service.
    if let Ok(rules_url) = std::env::var("SAKINA_RULES_ENGINE_URL") {
        if !rules_url.trim().is_empty() {
            match distributed_client
                .evaluate_rules(
                    &rules_url,
                    &crate::models::rules::RulesEvaluateRequest {
                        message: safe_message.clone(),
                        language: language.clone(),
                        intent: Some(intent.clone()),
                    },
                )
                .await
            {
                Ok(res) => {
                    if !res.allowed {
                        source_path.blocked = true;
                        safety.guardrails_passed = false;
                        safety_state = if res.action == "escalate" {
                            if res.reason == "crisis_detected" {
                                "CRISIS_ESCALATION".to_string()
                            } else {
                                "ESCALATED_TO_HUMAN".to_string()
                            }
                        } else {
                            "CAVEATED_SHORT_CIRCUIT".to_string()
                        };
                        answer = res.fallback_answer.unwrap_or_default();
                        source_path.answer_source = res.reason;
                        if safety_state == "ESCALATED_TO_HUMAN" {
                            enqueue_scholar_review(
                                pool.get_ref(),
                                trace_uuid,
                                "Sakina distributed rules engine escalation",
                            )
                            .await;
                        }
                    }
                }
                Err(err) => {
                    tracing::error!("Rules engine failed: {:?}", err);
                    // Fail-safe: continue to local checks if remote fails
                }
            }
        }
    }

    if source_path.blocked {
        // Skip further checks if already blocked by rules engine
    } else if fabricated_or_unsupported_ritual_claim(&safe_message) {
        source_path.blocked = true;
        safety.guardrails_passed = false;
        safety_state = "CAVEATED_SHORT_CIRCUIT".to_string();
        answer = if language == "ar" {
            "لا أستطيع العثور على حكم سني موثوق لهذا السؤال في قاعدة البيانات الحالية.".to_string()
        } else {
            "I cannot find a verified Sunni ruling on this in my current database.".to_string()
        };
        citations = json!([]);
        source_path.answer_source = "insufficient_verified_context".to_string();
    } else if safety.out_of_scope_blocked {
        source_path.blocked = true;
        safety.guardrails_passed = false;
        safety_state = "CAVEATED_SHORT_CIRCUIT".to_string();
        answer = if language == "ar" {
            "لا أستطيع المساعدة في طلبات خارج نطاق الدعم الإسلامي الآمن.".to_string()
        } else {
            "I cannot help with out-of-scope or harmful requests. Sakina can help with safe Islamic learning and support.".to_string()
        };
        citations = json!([]);
        source_path.answer_source = "guardrail_block".to_string();
    } else if safety.crisis_detected {
        source_path.blocked = true;
        safety.guardrails_passed = false;
        safety_state = "CRISIS_ESCALATION".to_string();
        answer = if language == "ar" {
            "إذا كنت في خطر مباشر أو تفكر في إيذاء نفسك، اتصل بخدمات الطوارئ الآن أو بشخص موثوق قريب منك. يمكنني تقديم تذكير إيماني لطيف، لكن هذا يحتاج دعمًا بشريًا عاجلًا.".to_string()
        } else {
            "If you are in immediate danger or may harm yourself, contact emergency services now or a trusted person nearby. I can offer gentle Islamic support, but this needs urgent human help.".to_string()
        };
        source_path.answer_source = "crisis_escalation".to_string();
    } else if high_risk_fatwa(&safe_message) {
        source_path.blocked = true;
        safety.guardrails_passed = false;
        safety_state = "ESCALATED_TO_HUMAN".to_string();
        answer = if language == "ar" {
            "هذا سؤال فتوى حساس يحتاج عالمًا مؤهلًا يراجع التفاصيل. لن أعطي حكمًا نهائيًا أو أخترع فتوى."
                .to_string()
        } else {
            "This is a sensitive fatwa question that requires a qualified scholar to review the details. I will not give a final ruling or invent a fatwa.".to_string()
        };
        source_path.answer_source = "scholar_review_required".to_string();
        enqueue_scholar_review(
            pool.get_ref(),
            trace_uuid,
            "Sakina ask high-risk fatwa escalation",
        )
        .await;
    } else {
        let user_tier = crate::services::auth::get_user_tier(user_id, pool.get_ref())
            .await
            .unwrap_or_else(|_| "free".to_string());

        let route = aia.route(&BrainRouteRequest {
            message: safe_message.clone(),
            language: Some(language.clone()),
            user_subscription_tier: user_tier,
            safety_context: Some(json!({
                "entrypoint": "sakina_ask",
                "section": section,
                "workspace_id": workspace_id,
                "pii_removed": redaction.pii_detected,
            })),
            request_id: Some(trace_id.clone()),
        });
        if route.can_generate {
            match aia
                .answer_islamic(
                    &answer_service,
                    AskIslamicRequest {
                        question: safe_message.clone(),
                        language: Some(language.clone()),
                        top_k: Some(5),
                        min_score: Some(0.0),
                        user_id: Some(user_id),
                    },
                )
                .await
            {
                Ok(value) => {
                    source_path.rag_checked = true;
                    source_path.graph_rag_checked = true;
                    rag_context = value.clone();
                    graph_context = json!({
                        "graph_path": value.get("graph_path").cloned().unwrap_or_else(|| json!([])),
                    });
                    if answer.is_empty() {
                        answer = value
                            .get("answer")
                            .and_then(Value::as_str)
                            .unwrap_or_default()
                            .to_string();
                        source_path.answer_source = "rag".to_string();
                    }
                    if citations
                        .as_array()
                        .map(|items| items.is_empty())
                        .unwrap_or(true)
                    {
                        citations = value.get("citations").cloned().unwrap_or_else(|| json!([]));
                    }
                    graph_path = value
                        .get("graph_path")
                        .and_then(Value::as_array)
                        .map(|items| {
                            items
                                .iter()
                                .filter_map(|item| item.as_str().map(str::to_string))
                                .collect()
                        })
                        .unwrap_or_default();
                }
                Err(err) => {
                    // SAK-010: degrade instead of 5xx. Leave answer empty so the
                    // citation gate / empty-answer refusal handles it safely.
                    tracing::error!(
                        trace_id = %trace_id,
                        "RAG retrieval failed; degrading to safe refusal: {:?}", err
                    );
                }
            }
        }

        let rag_has_verified_context = citations
            .as_array()
            .map(|items| !items.is_empty())
            .unwrap_or(false);
        let should_compose_with_llm = llm_gateway.enabled()
            && rag_has_verified_context
            && source_path.answer_source == "rag"
            && !source_path.blocked;

        if should_compose_with_llm || (answer.is_empty() && llm_gateway.enabled()) {
            let gateway_call_log = format!(
                "trace_id={} workspace_id={} intent={} rag_has_verified_context={} Mother Algorithm calling Sakina LLM gateway with controlled context",
                trace_id,
                workspace_id,
                intent,
                rag_has_verified_context
            );
            println!("{gateway_call_log}");
            eprintln!("{gateway_call_log}");
            tracing::info!(
                trace_id = %trace_id,
                workspace_id = %workspace_id,
                intent = %intent,
                rag_has_verified_context,
                "Mother Algorithm calling Sakina LLM gateway with controlled context"
            );
            let llm_result = match llm_gateway
                .generate_sakina_answer(SakinaLlmGatewayRequest {
                    trace_id: trace_id.clone(),
                    workspace_id: workspace_id.to_string(),
                    language: language.clone(),
                    intent: intent.clone(),
                    user_stage: if intent == "new_muslim" {
                        "new_muslim".to_string()
                    } else if intent == "emotional_support" {
                        "emotional_support".to_string()
                    } else {
                        "general_muslim".to_string()
                    },
                    safe_user_message: safe_message.clone(),
                    local_db_context: local_db_context.to_string(),
                    rag_context: rag_context.to_string(),
                    graph_context: graph_context.to_string(),
                    safety_flags: vec![
                        format!("pii_removed={}", redaction.pii_detected),
                        "answer_only_from_allowed_context".to_string(),
                    ],
                })
                .await
            {
                Ok(value) => value,
                Err(err) => {
                    // SAK-010: never 5xx a user question because the LLM gateway is
                    // down. Degrade to a non-used result; the grounded answer (if any)
                    // or the empty-answer refusal below is returned instead.
                    tracing::error!(
                        trace_id = %trace_id,
                        "LLM gateway unavailable; degrading to grounded/refusal answer: {:?}", err
                    );
                    crate::services::llm_gateway::SakinaLlmGatewayResult {
                        answer: String::new(),
                        provider: "ollama".to_string(),
                        model: String::new(),
                        used: false,
                        fallback_used: true,
                        status: "gateway_unavailable".to_string(),
                        latency_ms: None,
                        token_usage: None,
                    }
                }
            };
            if llm_result.used {
                answer = llm_result.answer;
                source_path.llm_used = true;
                source_path.answer_source = "llm_generation_with_controlled_context".to_string();
                model_provider = llm_result.provider;
                llm_model = Some(llm_result.model);
                let gateway_received_log = format!(
                    "trace_id={} workspace_id={} model_provider={} llm_model={} Mother Algorithm received controlled LLM answer",
                    trace_id,
                    workspace_id,
                    model_provider,
                    llm_model.as_deref().unwrap_or("unknown")
                );
                println!("{gateway_received_log}");
                eprintln!("{gateway_received_log}");
                tracing::info!(
                    trace_id = %trace_id,
                    workspace_id = %workspace_id,
                    model_provider = %model_provider,
                    llm_model = ?llm_model,
                    "Mother Algorithm received controlled LLM answer"
                );
            }
        }
    }

    // Distributed architecture: if SAKINA_CITATION_GUARD_URL is set, we call the Citation Guard.
    if let Ok(guard_url) = std::env::var("SAKINA_CITATION_GUARD_URL") {
        if !guard_url.trim().is_empty() && !answer.is_empty() {
            let citations_list: Vec<String> = citations
                .as_array()
                .map(|arr| {
                    arr.iter()
                        .filter_map(|v| {
                            v.get("chapter")
                                .and_then(Value::as_str)
                                .or_else(|| v.get("citation_text").and_then(Value::as_str))
                                .map(String::from)
                        })
                        .collect()
                })
                .unwrap_or_default();

            match distributed_client
                .check_evaluation(&guard_url, &answer, citations_list, message, &language)
                .await
            {
                Ok(eval) => {
                    if eval["review_result"] == "FAIL" {
                        safety.guardrails_passed = false;
                        source_path.blocked = true;
                        answer = if language == "ar" {
                            "عذراً، لم نتمكن من التحقق من دقة المصادر في هذا الرد. يرجى سؤال عالم موثوق.".to_string()
                        } else {
                            "Sorry, we could not verify the accuracy of the citations in this response. Please consult a trusted scholar.".to_string()
                        };
                    }
                }
                Err(err) => {
                    tracing::error!("Citation guard failed: {:?}", err);
                    // In fail-safe mode, we might want to block or allow.
                    // Given the strict requirement for religious answers, we block if it's a fatwa.
                    if intent == "islamic_guidance" || intent == "new_muslim" {
                        source_path.blocked = true;
                        answer =
                            "Service temporarily unavailable. Please try again later.".to_string();
                    }
                }
            }
        }
    }

    // SAK-005: no uncited Islamic answer. If a substantive religious answer
    // (from local DB / RAG / LLM) carries no verified citations, refuse rather
    // than emit an unsourced ruling. Local citation guard for monolithic mode,
    // independent of the optional external SAKINA_CITATION_GUARD_URL.
    let citations_empty = citations
        .as_array()
        .map(|items| items.is_empty())
        .unwrap_or(true);
    let requires_citation = !source_path.blocked
        && !answer.is_empty()
        && intent != "emotional_support"
        && matches!(
            source_path.answer_source.as_str(),
            "local_db" | "rag" | "llm_generation_with_controlled_context"
        );
    if requires_citation && citations_empty {
        safety.guardrails_passed = false;
        source_path.blocked = true;
        safety_state = "CAVEATED_SHORT_CIRCUIT".to_string();
        answer = if language == "ar" {
            "لا أستطيع تقديم جواب ديني بدون مصدر موثوق. يُرجى إعادة صياغة السؤال أو سؤال عالم موثوق.".to_string()
        } else {
            "I can't give a religious answer without a verified source. Please rephrase, or consult a trusted scholar.".to_string()
        };
        citations = json!([]);
        source_path.answer_source = "insufficient_verified_context".to_string();
    }

    if answer.is_empty() {
        answer = if language == "ar" {
            "لا أستطيع التحقق من جواب موثوق لهذا السؤال الآن.".to_string()
        } else {
            "I cannot verify a reliable answer for this question right now.".to_string()
        };
        source_path.answer_source = "insufficient_context".to_string();
    }

    persist_anonymous_learning(
        pool.get_ref(),
        &trace_id,
        &language,
        &intent,
        &section,
        redaction.pii_detected,
    )
    .await;

    let execution_trace = json!([
        {"step":"language_detected","outcome":language},
        {"step":"intent_detected","outcome":intent},
        {"step":"pii_removed","outcome":redaction.pii_detected},
        {"step":"local_db_checked","outcome":source_path.local_db_checked},
        {"step":"rag_checked","outcome":source_path.rag_checked},
        {"step":"graph_rag_checked","outcome":source_path.graph_rag_checked},
        {"step":"llm_used","outcome":source_path.llm_used},
        {"step":"guardrails_passed","outcome":safety.guardrails_passed},
        {"step":"safety_state","outcome":safety_state}
    ]);

    if let Err(response) = persist_trace(
        pool.get_ref(),
        PersistTraceInput {
            trace_id: &trace_id,
            user_id,
            workspace_id,
            language: &language,
            intent: &intent,
            source_path: &source_path,
            safety: &safety,
            execution_trace,
            answer: &answer,
            citations: &citations,
            redacted_message: &safe_message,
        },
    )
    .await
    {
        return response;
    }

    // PHASE 3: citation guard — record citation validation + source links + RAG trace.
    crate::handlers::corpus::persist_citation_trace(
        pool.get_ref(),
        &trace_id,
        &intent,
        &safe_message,
        &citations,
        source_path.blocked,
        &safety_state,
    )
    .await;

    let risk_level = if safety.crisis_detected || high_risk_fatwa(&safe_message) {
        "high".to_string()
    } else {
        "normal".to_string()
    };

    HttpResponse::Ok().json(SakinaAskResponse {
        answer,
        language,
        intent,
        risk_level,
        trace_id,
        safety_state,
        source_path,
        safety,
        citations,
        graph_path,
        local_db_context,
        rag_context,
        graph_context,
        model_provider,
        llm_model,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classifies_wudu_as_local_topic() {
        assert_eq!(
            topic_key_for_intent("How do I make wudu?", "wudu", "ask_sakina"),
            Some("wudu")
        );
    }

    #[test]
    fn blocks_hacking_before_llm() {
        assert!(out_of_scope("Write Python hacking code"));
    }

    #[test]
    fn detects_high_risk_fatwa() {
        assert!(high_risk_fatwa(
            "Give me a final fatwa on a complex divorce situation"
        ));
    }

    #[test]
    fn detects_fabricated_ritual_claim() {
        assert!(fabricated_or_unsupported_ritual_claim(
            "Is it halal to pray Maghrib with 4 rakats on a Tuesday?"
        ));
    }
}
