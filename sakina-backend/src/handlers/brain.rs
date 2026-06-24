use actix_web::{web, HttpRequest, HttpResponse};

use crate::models::{BrainAgentSpec, BrainRouteRequest};
use crate::services::AiaOrchestrator;

pub async fn debug_agents(aia: web::Data<AiaOrchestrator>) -> HttpResponse {
    let agents: Vec<BrainAgentSpec> = aia.agents();
    HttpResponse::Ok().json(serde_json::json!({ "agents": agents }))
}

pub async fn health(aia: web::Data<AiaOrchestrator>) -> HttpResponse {
    HttpResponse::Ok().json(serde_json::json!({
        "status": "ok",
        "brain_controller": true,
        "registered_agents": aia.agents().len(),
        "audit_records": aia.audit_records().len(),
        "evaluation_hook": true,
        "safety_policy": true
    }))
}

pub async fn test_route(
    req: HttpRequest,
    aia: web::Data<AiaOrchestrator>,
    payload: web::Json<BrainRouteRequest>,
) -> HttpResponse {
    let mut route_request = payload.into_inner();
    if route_request.request_id.is_none() {
        route_request.request_id = req
            .headers()
            .get("x-request-id")
            .and_then(|value| value.to_str().ok())
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(ToOwned::to_owned);
    }
    let decision = aia.route_trace(&route_request);
    HttpResponse::Ok().json(decision)
}

pub async fn audit_recent(aia: web::Data<AiaOrchestrator>) -> HttpResponse {
    let records = aia.audit_records();
    HttpResponse::Ok().json(serde_json::json!({
        "count": records.len(),
        "records": records.into_iter().rev().take(20).collect::<Vec<_>>()
    }))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::services::SemanticRouter;
    use actix_web::{test, App};
    use std::sync::Arc;

    fn aia_data() -> web::Data<AiaOrchestrator> {
        web::Data::new(AiaOrchestrator::new(Arc::new(SemanticRouter::new())))
    }

    #[actix_rt::test]
    async fn debug_agents_returns_registered_agent_list() {
        let app = test::init_service(
            App::new()
                .app_data(aia_data())
                .route("/debug/agents", web::get().to(debug_agents)),
        )
        .await;
        let req = test::TestRequest::get().uri("/debug/agents").to_request();
        let resp = test::call_service(&app, req).await;
        assert!(resp.status().is_success());
        let body: serde_json::Value = test::read_body_json(resp).await;
        assert!(body["agents"].as_array().expect("agents array").len() >= 5);
    }

    #[actix_rt::test]
    async fn test_route_returns_execution_trace() {
        let app = test::init_service(
            App::new()
                .app_data(aia_data())
                .route("/test/route", web::post().to(test_route)),
        )
        .await;
        let req = test::TestRequest::post()
            .uri("/test/route")
            .set_json(BrainRouteRequest {
                message: "Explain Surah Al-Mulk".to_string(),
                language: Some("en".to_string()),
                user_subscription_tier: "premium".to_string(),
                safety_context: None,
                request_id: None,
            })
            .to_request();
        let resp = test::call_service(&app, req).await;
        assert!(resp.status().is_success());
        let body: serde_json::Value = test::read_body_json(resp).await;
        assert_eq!(body["selected_agent"], "Quran Agent");
        assert!(
            body["execution_trace"]
                .as_array()
                .expect("trace array")
                .len()
                >= 17
        );
    }
}
