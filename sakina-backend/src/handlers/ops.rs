use actix_web::{http::header::CONTENT_TYPE, web, HttpResponse};

pub async fn metrics(pool: web::Data<sqlx::PgPool>) -> HttpResponse {
    let db_up = if pool.acquire().await.is_ok() { 1 } else { 0 };
    let waitlist_total: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM sakina_ai.waitlist")
        .fetch_one(pool.get_ref())
        .await
        .unwrap_or(0);

    // Lightweight Prometheus exposition format.
    let body = format!(
        concat!(
            "# HELP sakina_backend_up Backend process liveness\n",
            "# TYPE sakina_backend_up gauge\n",
            "sakina_backend_up 1\n",
            "# HELP sakina_waitlist_total Total waitlist entries\n",
            "# TYPE sakina_waitlist_total gauge\n",
            "sakina_waitlist_total {}\n",
            "# HELP sakina_build_info Build/service metadata\n",
            "# TYPE sakina_build_info gauge\n",
            "sakina_build_info{{service=\"sakina-backend\"}} 1\n",
            "# HELP sakina_backend_db_up Database connectivity status\n",
            "# TYPE sakina_backend_db_up gauge\n",
            "sakina_backend_db_up {}\n"
        ),
        waitlist_total, db_up
    );

    HttpResponse::Ok()
        .insert_header((CONTENT_TYPE, "text/plain; version=0.0.4; charset=utf-8"))
        .body(body)
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::body::to_bytes;

    #[actix_rt::test]
    async fn metrics_exposes_required_prometheus_keys() {
        let pool = sqlx::PgPool::connect_lazy("postgres://invalid:invalid@localhost/invalid")
            .expect("lazy pool");
        let response = metrics(web::Data::new(pool)).await;
        assert_eq!(response.status(), actix_web::http::StatusCode::OK);
        let body = to_bytes(response.into_body()).await.expect("metrics body");
        let text = String::from_utf8(body.to_vec()).expect("utf8");
        assert!(text.contains("sakina_backend_up 1"));
        assert!(text.contains("sakina_waitlist_total "));
        assert!(text.contains("sakina_build_info{service=\"sakina-backend\"} 1"));
    }
}
