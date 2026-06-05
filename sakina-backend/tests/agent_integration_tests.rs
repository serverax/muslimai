use std::time::Duration;

use sakina_backend::agent::{AgentNode, AgenticOrchestrator, SakinaMemoryStore, SakinaState};
use uuid::Uuid;

#[tokio::test]
async fn redis_persists_agent_state_and_researcher_returns_rag_context() {
    let redis_url =
        std::env::var("SAKINA_REDIS_URL").unwrap_or_else(|_| "redis://localhost:6380".to_string());
    let store = SakinaMemoryStore::from_url(&redis_url)
        .expect("redis pool")
        .with_ttl(120);
    let orchestrator =
        AgenticOrchestrator::new(Duration::from_millis(200)).with_memory_store(store.clone());
    let mut state = SakinaState::new(
        Uuid::new_v4(),
        "Can I shorten prayer while travelling?",
        "en",
    );
    let trace_id = state.trace_id;

    let result = orchestrator
        .route_with_memory(state.clone())
        .await
        .expect("agentic route with memory");

    assert_eq!(result.selected_node, AgentNode::Researcher);
    let rag_context = result.rag_context.expect("rag context");
    assert_eq!(rag_context.source, "quran_rag");
    assert!(rag_context.citations.iter().any(|c| c == "Quran 2:184"));
    assert!(result
        .state
        .memory_trace
        .iter()
        .any(|entry| entry == "researcher_node_used_quran_rag_context"));

    let saved = store
        .get_state(trace_id)
        .await
        .expect("redis get")
        .expect("persisted state");
    assert_eq!(saved.trace_id, trace_id);
    assert_eq!(saved.context, result.state.context);

    state.user_query = "Can I shorten prayer while travelling again?".to_string();
    let rerun = orchestrator
        .route_with_memory(state)
        .await
        .expect("agentic reroute with loaded memory");

    assert!(rerun
        .state
        .memory_trace
        .iter()
        .any(|entry| entry == "loaded_existing_state_from_redis"));
}
