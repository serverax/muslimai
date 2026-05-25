//! OpenTelemetry + tracing initialization (Step 15).
//!
//! Builds an OTel tracer with a stdout span exporter and layers it onto the
//! tracing subscriber alongside the fmt logger. To export to Jaeger instead,
//! swap `opentelemetry_stdout::SpanExporter` for `opentelemetry_otlp`'s span
//! exporter pointed at `http://jaeger.sakina-monitoring:4317` (adds tonic).

use opentelemetry::trace::TracerProvider as _;
use opentelemetry_sdk::trace::SdkTracerProvider;
use tracing_subscriber::filter::LevelFilter;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;

/// Initialize tracing with both a console (fmt) layer and an OpenTelemetry layer.
pub fn init() {
    let provider = SdkTracerProvider::builder()
        .with_simple_exporter(opentelemetry_stdout::SpanExporter::default())
        .build();
    let tracer = provider.tracer("sakina-api");
    opentelemetry::global::set_tracer_provider(provider);

    tracing_subscriber::registry()
        .with(LevelFilter::INFO)
        .with(tracing_subscriber::fmt::layer())
        .with(tracing_opentelemetry::layer().with_tracer(tracer))
        .init();
}
