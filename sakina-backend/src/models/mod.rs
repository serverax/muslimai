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

#[derive(Debug, Serialize, Deserialize)]
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
    pub safety_context: Option<String>,
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
