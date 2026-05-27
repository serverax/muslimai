use actix_web::{http::header::CONTENT_TYPE, web, HttpResponse};

pub async fn metrics(pool: web::Data<sqlx::PgPool>) -> HttpResponse {
    let db_up = if pool.acquire().await.is_ok() { 1 } else { 0 };

    // Lightweight Prometheus exposition format.
    let body = format!(
        concat!(
            "# HELP sakina_backend_up Backend process liveness\n",
            "# TYPE sakina_backend_up gauge\n",
            "sakina_backend_up 1\n",
            "# HELP sakina_backend_db_up Database connectivity status\n",
            "# TYPE sakina_backend_db_up gauge\n",
            "sakina_backend_db_up {}\n"
        ),
        db_up
    );

    HttpResponse::Ok()
        .insert_header((CONTENT_TYPE, "text/plain; version=0.0.4; charset=utf-8"))
        .body(body)
}
