use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: Uuid,
    pub pub_key: String,
    pub madhhab_preference: String,
    pub created_at: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct RagQuery {
    pub query: String,
    pub user_id: Uuid,
    pub madhhab_filter: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct RagResponse {
    pub answer: String,
    pub sources: Vec<SourceReference>,
    pub confidence: f32,
    pub guardrail_triggered: bool,
    pub processing_time_ms: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct SourceReference {
    pub id: String,
    pub title: String,
    pub author: String,
    pub chapter: String,
    pub authenticity_grade: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ClassifyRequest {
    pub text: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ClassifyResponse {
    pub intent: String,
    pub confidence: f32,
    pub routing_decision: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct BrainAgentSpec {
    pub name: String,
    pub domain: String,
    pub model: String,
    pub pipeline: String,
    pub requires_rag: bool,
    pub requires_wasm: bool,
    pub requires_evaluation: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BrainRouteRequest {
    pub message: String,
    pub language: Option<String>,
    pub user_subscription_tier: String,
    pub safety_context: Option<serde_json::Value>,
    #[serde(default)]
    pub request_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct BrainTraceStep {
    pub step: String,
    pub outcome: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct BrainDecisionTrace {
    pub request_id: String,
    pub user_id: Option<String>,
    pub input_type: String,
    pub intent: String,
    pub language: String,
    pub risk_level: String,
    pub selected_agent: String,
    pub selected_model: String,
    pub selected_pipeline: String,
    pub source_strategy: String,
    pub evaluation_result: String,
    pub final_action: String,
    pub audit_event_id: String,
    pub execution_trace: Vec<BrainTraceStep>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BrainEvaluationReport {
    pub evaluation_score: f32,
    pub review_result: String,
    pub reason: String,
    pub citations_present: bool,
    pub grounded_in_islamic_sources: bool,
    pub escalation_needed: bool,
    pub tone_ok: bool,
    pub language_ok: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct BrainAuditRecord {
    pub request_id: String,
    pub user_id: Option<String>,
    pub decision_path: Vec<String>,
    pub selected_agent: String,
    pub selected_model: String,
    pub final_action: String,
    pub audit_event_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EvaluationCheckRequest {
    pub answer: String,
    pub citations: Vec<String>,
    pub language: String,
    pub grounded_in_islamic_sources: Option<bool>,
    pub safety_level: Option<String>,
    pub tone: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EvaluationCheckResponse {
    pub evaluation_score: f32,
    pub review_result: String,
    pub reason: String,
    pub citation_present: bool,
    pub grounding_present: bool,
    pub language_match: bool,
    pub escalation_needed: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct KnowledgeGraphHealthResponse {
    pub status: String,
    pub entities_table: bool,
    pub edges_table: bool,
    pub ready: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BrainRouteResponse {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub request_id: Option<String>,
    pub selected_agent: String,
    pub selected_model: String,
    pub selected_pipeline: String,
    pub source_strategy: String,
    pub language: String,
    pub risk_level: String,
    pub confidence: f32,
    pub rag_required: bool,
    pub wasm_required: bool,
    pub evaluation_required: bool,
    pub scholar_review_required: bool,
    pub can_generate: bool,
    pub execution_trace: Vec<BrainTraceStep>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ModuleSafetyStatus {
    Disabled,
    Gated,
    EnabledReadOnly,
    RequiresReview,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ReviewStatus {
    Unverified,
    Verified,
    ScholarReviewRequired,
    Rejected,
    Disabled,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct SourceProvenance {
    pub source_type: String,
    pub source_name: String,
    pub source_reference: String,
    pub review_status: String,
    pub effective_date: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RagReadiness {
    pub rag_enabled: bool,
    pub rag_index_ready: bool,
    pub verified_source_count: u64,
    pub last_indexed_at: Option<String>,
    pub review_status: ReviewStatus,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct QuranOverview {
    pub module: String,
    pub safety_status: ModuleSafetyStatus,
    pub review_status: ReviewStatus,
    pub message: String,
    pub rag: RagReadiness,
    pub entries: Vec<QuranOverviewEntry>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct QuranOverviewEntry {
    pub source_type: String,
    pub source_name: String,
    pub source_reference: String,
    pub review_status: String,
    pub effective_date: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PrayerOverview {
    pub module: String,
    pub safety_status: ModuleSafetyStatus,
    pub review_status: ReviewStatus,
    pub message: String,
    pub rag: RagReadiness,
    pub windows: Vec<PrayerOverviewWindow>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PrayerOverviewWindow {
    pub source_type: String,
    pub source_name: String,
    pub source_reference: String,
    pub review_status: String,
    pub effective_date: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct KnowledgeOverview {
    pub module: String,
    pub safety_status: ModuleSafetyStatus,
    pub review_status: ReviewStatus,
    pub message: String,
    pub rag: RagReadiness,
    pub topics: Vec<KnowledgeOverviewTopic>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct KnowledgeOverviewTopic {
    pub source_type: String,
    pub source_name: String,
    pub source_reference: String,
    pub review_status: String,
    pub effective_date: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CommunityOverview {
    pub module: String,
    pub safety_status: ModuleSafetyStatus,
    pub review_status: ReviewStatus,
    pub message: String,
    pub rag: RagReadiness,
    pub channels: Vec<CommunityOverviewChannel>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CommunityOverviewChannel {
    pub source_type: String,
    pub source_name: String,
    pub source_reference: String,
    pub review_status: String,
    pub effective_date: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ModuleLifecycleStatus {
    Active,
    Disabled,
    ComingSoon,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ModuleStatusResponse {
    pub module: String,
    pub enabled: bool,
    pub status: ModuleLifecycleStatus,
    pub reason: String,
    pub requires_subscription: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ModulesStatusCollectionResponse {
    pub modules: Vec<ModuleStatusResponse>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateConversationRequest {
    pub user_id: Option<Uuid>,
    pub title: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateConversationResponse {
    pub id: Uuid,
    pub user_id: Option<Uuid>,
    pub title: String,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConversationMessageResponse {
    pub id: Uuid,
    pub role: String,
    pub content: String,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetConversationResponse {
    pub id: Uuid,
    pub user_id: Option<Uuid>,
    pub title: String,
    pub created_at: String,
    pub updated_at: String,
    pub messages: Vec<ConversationMessageResponse>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AddMessageRequest {
    pub content: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AddMessageResponse {
    pub conversation_id: Uuid,
    pub user_message_id: Uuid,
    pub assistant_message_id: Option<Uuid>,
    pub response: Option<String>,
    pub trace_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RagStatusResponse {
    pub status: String,
    pub rag_enabled: bool,
    pub index_ready: bool,
    pub verified_source_count: u64,
    pub last_indexed_at: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RagSourceItem {
    pub module: String,
    pub source_type: String,
    pub source_name: String,
    pub source_reference: String,
    pub citation: String,
    pub language: String,
    pub review_status: ReviewStatus,
    pub effective_date: Option<String>,
    pub content_hash: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RagSourcesResponse {
    pub sources: Vec<RagSourceItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RagSearchItem {
    pub module: String,
    pub source_type: String,
    pub source_name: String,
    pub source_reference: String,
    pub citation: String,
    pub language: String,
    pub review_status: ReviewStatus,
    pub effective_date: Option<String>,
    pub content_hash: String,
    pub retrieved_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RagSearchResponse {
    pub items: Vec<RagSearchItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum DecisionModule {
    Quran,
    Prayer,
    Knowledge,
    Community,
    GeneralChat,
    Unsupported,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum SafetyRisk {
    Safe,
    ReligiousSensitive,
    MedicalSensitive,
    LegalSensitive,
    CrisisSensitive,
    ChildSensitive,
    Unknown,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DecisionRequest {
    pub question: String,
    pub selected_module: String,
    pub language: String,
    pub user_subscription_tier: String,
    pub safety_context: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DecisionSource {
    pub source_type: String,
    pub source_name: String,
    pub source_reference: String,
    pub citation: String,
    pub language: String,
    pub review_status: ReviewStatus,
    pub effective_date: Option<String>,
    pub content_hash: String,
    pub retrieved_at: String,
    pub similarity_score: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DecisionResponse {
    pub answer: String,
    pub module: DecisionModule,
    pub language: String,
    pub confidence: f32,
    pub safety_status: SafetyRisk,
    pub review_status: ReviewStatus,
    pub sources: Vec<DecisionSource>,
    pub citations: Vec<String>,
    pub generated_from_verified_sources: bool,
    pub requires_scholar_review: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ImanJourneyProgress {
    pub prayer: i32,
    pub quran: i32,
    pub dhikr: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ImanJourneyFamilyReminder {
    pub consent_granted: bool,
    pub reminder_text: Option<String>,
    pub notify_family: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ImanJourneyEvidenceItem {
    pub source_type: String,
    pub source_reference: String,
    pub citation: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ImanJourneySafeFallback {
    pub reason: String,
    pub message: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ImanJourneyReligiousReminder {
    pub text: Option<String>,
    pub confidence_score: f64,
    pub evidence_bundle: Vec<ImanJourneyEvidenceItem>,
    pub safe_fallback: Option<ImanJourneySafeFallback>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ImanJourneyPrivacySettings {
    pub personalization_enabled: bool,
    pub reminders_enabled: bool,
    pub store_journey_enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct UpsertImanJourneyRequest {
    pub journey_date: Option<String>,
    pub today_focus: String,
    pub continue_yesterday_topic: Option<String>,
    pub progress: ImanJourneyProgress,
    pub ask_sakina_today_context: Option<String>,
    pub tomorrow_follow_up: Option<String>,
    pub family_reminder: Option<ImanJourneyFamilyReminder>,
    pub religious_reminder_text: Option<String>,
    pub religious_confidence_score: Option<f64>,
    pub evidence_bundle: Option<Vec<ImanJourneyEvidenceItem>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ImanJourneyResponse {
    pub journey_date: String,
    pub today_focus: String,
    pub continue_yesterday_topic: Option<String>,
    pub progress: ImanJourneyProgress,
    pub personal_dua_list: Vec<ImanDuaItem>,
    pub family_reminder: ImanJourneyFamilyReminder,
    pub ask_sakina_today_context: Option<String>,
    pub tomorrow_follow_up: Option<String>,
    pub privacy_settings: ImanJourneyPrivacySettings,
    pub religious_reminder: ImanJourneyReligiousReminder,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct UpsertImanJourneyPrivacyRequest {
    pub personalization_enabled: bool,
    pub reminders_enabled: bool,
    pub store_journey_enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ImanDuaItem {
    pub id: String,
    pub dua_text: String,
    pub is_answered: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AddDuaItemRequest {
    pub dua_text: String,
}
