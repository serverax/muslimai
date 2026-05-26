use std::fs;

#[test]
fn api_exposes_kubernetes_probe_routes() {
    let main_rs = fs::read_to_string("src/main.rs").expect("read src/main.rs");
    let health_rs =
        fs::read_to_string("src/handlers/health.rs").expect("read src/handlers/health.rs");

    assert!(main_rs.contains(".route(\"/health\""));
    assert!(main_rs.contains(".route(\"/ready\""));
    assert!(main_rs.contains("web::scope(\"/v1\")"));
    assert!(health_rs.contains("readiness_check"));
    assert!(health_rs.contains("HttpResponse::ServiceUnavailable()"));
}
