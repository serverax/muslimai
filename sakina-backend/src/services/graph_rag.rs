use serde::{Deserialize, Serialize};

use crate::error::ApiError;
use crate::services::KnowledgeGraphService;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GraphRagResult {
    pub query: String,
    pub connected_nodes: Vec<String>,
    pub graph_path: Vec<String>,
    pub related_topics: Vec<String>,
    pub related_hadith: Vec<String>,
    pub citations: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct GraphRagService {
    kg: KnowledgeGraphService,
}

impl GraphRagService {
    pub fn new(kg: KnowledgeGraphService) -> Self {
        Self { kg }
    }

    pub async fn traverse(&self, query: &str) -> Result<GraphRagResult, ApiError> {
        let result = self.kg.lookup(query).await?;
        Ok(GraphRagResult {
            query: query.to_string(),
            connected_nodes: result
                .connected_nodes
                .iter()
                .map(|node| node.entity_name.clone())
                .collect(),
            graph_path: result.graph_path,
            related_topics: result.related_topics,
            related_hadith: result.related_hadith,
            citations: result.citations,
        })
    }
}
