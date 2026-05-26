//! Audit middleware: logs every HTTP request (method, path, status, latency,
//! user) via `tracing`. Step 4 (Phase 1).
//!
use actix_web::{
    dev::{forward_ready, Service, ServiceRequest, ServiceResponse, Transform},
    web, Error, HttpMessage,
};
use futures_util::future::LocalBoxFuture;
use sqlx::PgPool;
use std::time::Instant;
use uuid::Uuid;

pub struct AuditMiddleware;

impl<S, B> Transform<S, ServiceRequest> for AuditMiddleware
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error>,
    S::Future: 'static,
    B: 'static,
{
    type Response = ServiceResponse<B>;
    type Error = Error;
    type InitError = ();
    type Transform = AuditMiddlewareService<S>;
    type Future = std::future::Ready<Result<Self::Transform, Self::InitError>>;

    fn new_transform(&self, service: S) -> Self::Future {
        std::future::ready(Ok(AuditMiddlewareService { service }))
    }
}

pub struct AuditMiddlewareService<S> {
    service: S,
}

impl<S, B> Service<ServiceRequest> for AuditMiddlewareService<S>
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error>,
    S::Future: 'static,
    B: 'static,
{
    type Response = ServiceResponse<B>;
    type Error = Error;
    type Future = LocalBoxFuture<'static, Result<Self::Response, Self::Error>>;

    forward_ready!(service);

    fn call(&self, req: ServiceRequest) -> Self::Future {
        let start = Instant::now();
        let method = req.method().to_string();
        let path = req.path().to_string();
        let user_id = req.extensions().get::<Uuid>().copied();
        let pool = req.app_data::<web::Data<PgPool>>().cloned();

        let fut = self.service.call(req);

        Box::pin(async move {
            let res = fut.await?;
            let elapsed_ms = start.elapsed().as_millis() as u64;
            let status: u64 = res.status().as_u16().into();

            tracing::info!(
                event = "http_request",
                method = %method,
                path = %path,
                status = status,
                duration_ms = elapsed_ms,
                user_id = ?user_id,
                "HTTP request"
            );

            if let Some(pool) = pool {
                if let Err(e) = sqlx::query(
                    "INSERT INTO audit.logs (event_type, payload, user_id) \
                     VALUES ($1, $2, $3)",
                )
                .bind("http_request")
                .bind(serde_json::json!({
                    "method": method,
                    "path": path,
                    "status": status,
                    "duration_ms": elapsed_ms
                }))
                .bind(user_id)
                .execute(pool.get_ref())
                .await
                {
                    tracing::warn!("failed to persist audit log: {}", e);
                }
            }

            Ok(res)
        })
    }
}
