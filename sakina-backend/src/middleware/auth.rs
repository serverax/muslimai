use actix_web::{
    body::{EitherBody, MessageBody},
    dev::{forward_ready, Service, ServiceRequest, ServiceResponse, Transform},
    http::header,
    Error, HttpMessage, HttpResponse,
};
use futures_util::future::LocalBoxFuture;
use uuid::Uuid;

pub struct AuthMiddleware {
    expected_bearer_token: String,
}

impl AuthMiddleware {
    pub fn new(expected_bearer_token: String) -> Self {
        Self {
            expected_bearer_token,
        }
    }
}

impl<S, B> Transform<S, ServiceRequest> for AuthMiddleware
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error> + 'static,
    S::Future: 'static,
    B: MessageBody + 'static,
{
    type Response = ServiceResponse<EitherBody<B>>;
    type Error = Error;
    type InitError = ();
    type Transform = AuthMiddlewareService<S>;
    type Future = std::future::Ready<Result<Self::Transform, Self::InitError>>;

    fn new_transform(&self, service: S) -> Self::Future {
        std::future::ready(Ok(AuthMiddlewareService {
            service,
            expected_bearer_token: self.expected_bearer_token.clone(),
        }))
    }
}

pub struct AuthMiddlewareService<S> {
    service: S,
    expected_bearer_token: String,
}

impl<S, B> Service<ServiceRequest> for AuthMiddlewareService<S>
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error> + 'static,
    S::Future: 'static,
    B: MessageBody + 'static,
{
    type Response = ServiceResponse<EitherBody<B>>;
    type Error = Error;
    type Future = LocalBoxFuture<'static, Result<Self::Response, Self::Error>>;

    forward_ready!(service);

    fn call(&self, req: ServiceRequest) -> Self::Future {
        let path = req.path().to_string();
        if !requires_auth(&path) {
            let fut = self.service.call(req);
            return Box::pin(async move { Ok(fut.await?.map_into_left_body()) });
        }

        let auth_header = req
            .headers()
            .get(header::AUTHORIZATION)
            .and_then(|h| h.to_str().ok())
            .unwrap_or_default();
        let expected = format!("Bearer {}", self.expected_bearer_token);

        if auth_header != expected {
            let response = req
                .into_response(HttpResponse::Unauthorized().json(serde_json::json!({
                    "error": "unauthorized"
                })))
                .map_into_right_body();
            return Box::pin(async move { Ok(response) });
        }

        let user_id_header = req
            .headers()
            .get("x-sakina-user-id")
            .and_then(|h| h.to_str().ok())
            .unwrap_or_default();

        let user_id = match Uuid::parse_str(user_id_header) {
            Ok(id) => id,
            Err(_) => {
                let response = req
                    .into_response(HttpResponse::Unauthorized().json(serde_json::json!({
                        "error": "missing or invalid x-sakina-user-id header"
                    })))
                    .map_into_right_body();
                return Box::pin(async move { Ok(response) });
            }
        };

        req.extensions_mut().insert(user_id);
        let fut = self.service.call(req);
        Box::pin(async move { Ok(fut.await?.map_into_left_body()) })
    }
}

fn requires_auth(path: &str) -> bool {
    if path == "/v1/users/pubkey" {
        return false;
    }

    matches!(
        path,
        "/v1/rag/query" | "/v1/classify" | "/v1/dashboard/guardrails" | "/v1/users"
    ) || path.starts_with("/v1/sync/backup/")
        || path.starts_with("/v1/users/")
}
