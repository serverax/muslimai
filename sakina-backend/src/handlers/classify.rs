use actix_web::{web, HttpResponse};
use crate::models::{ClassifyRequest, ClassifyResponse};

pub async fn classify_intent(_req: web::Json<ClassifyRequest>) -> HttpResponse {
    let response = ClassifyResponse {
        intent: "FiqhQuery".to_string(),
        confidence: 0.95,
        routing_decision: "RAG".to_string(),
    };

    HttpResponse::Ok().json(response)
}
