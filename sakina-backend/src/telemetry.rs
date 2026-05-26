//! OpenTelemetry + tracing initialization (Step 15).
//!
//! Uses OTLP when `OTEL_EXPORTER_OTLP_ENDPOINT` is configured. Local/dev runs
//! fall back to a stdout span exporter.

use opentelemetry::trace::TracerProvider as _;
use opentelemetry_otlp::WithExportConfig;
use opentelemetry_sdk::trace::SdkTracerProvider;
use tracing_subscriber::filter::LevelFilter;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;

/// Initialize tracing with both a console (fmt) layer and an OpenTelemetry layer.
pub fn init() {
    let provider = tracer_provider();
    let tracer = provider.tracer("sakina-api");
    opentelemetry::global::set_tracer_provider(provider);

    tracing_subscriber::registry()
        .with(LevelFilter::INFO)
        .with(tracing_subscriber::fmt::layer())
        .with(tracing_opentelemetry::layer().with_tracer(tracer))
        .init();
}

fn tracer_provider() -> SdkTracerProvider {
    match std::env::var("OTEL_EXPORTER_OTLP_ENDPOINT") {
        Ok(endpoint) if !endpoint.trim().is_empty() => {
            match opentelemetry_otlp::SpanExporter::builder()
                .with_tonic()
                .with_endpoint(endpoint)
                .build()
            {
                Ok(exporter) => SdkTracerProvider::builder()
                    .with_simple_exporter(exporter)
                    .build(),
                Err(err) => {
                    eprintln!("failed to initialize OTLP exporter, falling back to stdout: {err}");
                    stdout_tracer_provider()
                }
            }
        }
        _ => stdout_tracer_provider(),
    }
}

fn stdout_tracer_provider() -> SdkTracerProvider {
    SdkTracerProvider::builder()
        .with_simple_exporter(opentelemetry_stdout::SpanExporter::default())
        .build()
}
