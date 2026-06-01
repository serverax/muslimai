use actix_web::{web, HttpRequest, HttpResponse};
use chrono::NaiveDate;
use uuid::Uuid;

use crate::error::ApiError;
use crate::models::{AddDuaItemRequest, UpsertImanJourneyPrivacyRequest, UpsertImanJourneyRequest};
use crate::services::ImanJourneyService;

#[derive(Debug, serde::Deserialize)]
pub struct JourneyDateQuery {
    pub date: Option<String>,
}

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/iman-journey")
            .route("/{user_id}", web::get().to(get_iman_journey))
            .route("/{user_id}", web::put().to(upsert_iman_journey))
            .route("/{user_id}/privacy", web::get().to(get_privacy_settings))
            .route("/{user_id}/privacy", web::put().to(update_privacy_settings)),
    )
    .service(
        web::scope("/dua-list")
            .route("/{user_id}", web::get().to(list_dua_items))
            .route("/{user_id}", web::post().to(add_dua_item)),
    );
}

pub async fn get_iman_journey(
    req: HttpRequest,
    service: web::Data<ImanJourneyService>,
    path: web::Path<Uuid>,
    query: web::Query<JourneyDateQuery>,
) -> Result<HttpResponse, ApiError> {
    let user_id = path.into_inner();
    authorize_user_scope(&req, user_id)?;
    let parsed_date = parse_date_query(query.date.as_deref())?;
    let response = service.get_journey(user_id, parsed_date).await?;
    Ok(HttpResponse::Ok().json(response))
}

pub async fn upsert_iman_journey(
    req: HttpRequest,
    service: web::Data<ImanJourneyService>,
    path: web::Path<Uuid>,
    body: web::Json<UpsertImanJourneyRequest>,
) -> Result<HttpResponse, ApiError> {
    let user_id = path.into_inner();
    authorize_user_scope(&req, user_id)?;
    let response = service.upsert_journey(user_id, body.into_inner()).await?;
    Ok(HttpResponse::Ok().json(response))
}

pub async fn get_privacy_settings(
    req: HttpRequest,
    service: web::Data<ImanJourneyService>,
    path: web::Path<Uuid>,
) -> Result<HttpResponse, ApiError> {
    let user_id = path.into_inner();
    authorize_user_scope(&req, user_id)?;
    let response = service.get_or_create_privacy_settings(user_id).await?;
    Ok(HttpResponse::Ok().json(response))
}

pub async fn update_privacy_settings(
    req: HttpRequest,
    service: web::Data<ImanJourneyService>,
    path: web::Path<Uuid>,
    body: web::Json<UpsertImanJourneyPrivacyRequest>,
) -> Result<HttpResponse, ApiError> {
    let user_id = path.into_inner();
    authorize_user_scope(&req, user_id)?;
    let response = service
        .upsert_privacy_settings(user_id, body.into_inner())
        .await?;
    Ok(HttpResponse::Ok().json(response))
}

pub async fn list_dua_items(
    req: HttpRequest,
    service: web::Data<ImanJourneyService>,
    path: web::Path<Uuid>,
) -> Result<HttpResponse, ApiError> {
    let user_id = path.into_inner();
    authorize_user_scope(&req, user_id)?;
    let items = service.list_dua_items(user_id).await?;
    Ok(HttpResponse::Ok().json(serde_json::json!({ "items": items })))
}

pub async fn add_dua_item(
    req: HttpRequest,
    service: web::Data<ImanJourneyService>,
    path: web::Path<Uuid>,
    body: web::Json<AddDuaItemRequest>,
) -> Result<HttpResponse, ApiError> {
    let user_id = path.into_inner();
    authorize_user_scope(&req, user_id)?;
    let item = service.add_dua_item(user_id, body.into_inner()).await?;
    Ok(HttpResponse::Created().json(item))
}

fn authorize_user_scope(req: &HttpRequest, requested_user_id: Uuid) -> Result<(), ApiError> {
    let header_user_id = req
        .headers()
        .get("x-sakina-user-id")
        .and_then(|value| value.to_str().ok())
        .and_then(|value| Uuid::parse_str(value).ok())
        .ok_or_else(|| ApiError::unauthorized("x-sakina-user-id header is required"))?;
    if header_user_id != requested_user_id {
        return Err(ApiError::unauthorized(
            "requested user_id does not match x-sakina-user-id header",
        ));
    }
    Ok(())
}

fn parse_date_query(raw: Option<&str>) -> Result<Option<NaiveDate>, ApiError> {
    match raw {
        Some(date_str) if !date_str.trim().is_empty() => NaiveDate::parse_from_str(date_str, "%Y-%m-%d")
            .map(Some)
            .map_err(|_| ApiError::bad_request("date must be YYYY-MM-DD")),
        _ => Ok(None),
    }
}
