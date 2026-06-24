use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::{PgPool, Row};
use uuid::Uuid;

use crate::error::ApiError;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct KnowledgeGraphEntityView {
    pub id: Uuid,
    pub entity_type: String,
    pub entity_name: String,
    pub source_type: String,
    pub citation: String,
    pub reliability_level: String,
    pub language: String,
    pub domain: String,
    pub metadata: Value,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct KnowledgeGraphEdgeView {
    pub from_entity_id: Uuid,
    pub to_entity_id: Uuid,
    pub from_entity_name: String,
    pub to_entity_name: String,
    pub relation_type: String,
    pub confidence: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct KnowledgeGraphLookupResult {
    pub query: String,
    pub focus_entity: Option<KnowledgeGraphEntityView>,
    pub connected_nodes: Vec<KnowledgeGraphEntityView>,
    pub graph_path: Vec<String>,
    pub related_topics: Vec<String>,
    pub related_hadith: Vec<String>,
    pub citations: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct KnowledgeGraphService {
    pool: PgPool,
}

impl KnowledgeGraphService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    async fn lookup_focus(
        &self,
        query: &str,
    ) -> Result<Option<KnowledgeGraphEntityView>, ApiError> {
        let row = sqlx::query(
            r#"
            SELECT id, entity_type, entity_name, source_type, citation, reliability_level,
                   language, domain, metadata
            FROM sakina_ai.knowledge_graph_entities
            WHERE entity_name ILIKE $1
               OR citation ILIKE $1
               OR metadata::text ILIKE $1
            ORDER BY
                CASE WHEN entity_name ILIKE $1 THEN 0 ELSE 1 END,
                created_at DESC
            LIMIT 1
            "#,
        )
        .bind(format!("%{}%", query.trim()))
        .fetch_optional(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to query knowledge graph"))?;

        Ok(row.map(|row| KnowledgeGraphEntityView {
            id: row.get("id"),
            entity_type: row.get("entity_type"),
            entity_name: row.get("entity_name"),
            source_type: row.get("source_type"),
            citation: row.get("citation"),
            reliability_level: row.get("reliability_level"),
            language: row.get("language"),
            domain: row.get("domain"),
            metadata: row.get("metadata"),
        }))
    }

    async fn connected_entities(
        &self,
        focus_id: Uuid,
    ) -> Result<Vec<(KnowledgeGraphEntityView, String, f32)>, ApiError> {
        let rows = sqlx::query(
            r#"
            WITH RECURSIVE graph_walk AS (
                SELECT e.id, e.entity_type, e.entity_name, e.source_type, e.citation,
                       e.reliability_level, e.language, e.domain, e.metadata, 0 AS depth
                FROM sakina_ai.knowledge_graph_entities e
                WHERE e.id = $1
                UNION ALL
                SELECT n.id, n.entity_type, n.entity_name, n.source_type, n.citation,
                       n.reliability_level, n.language, n.domain, n.metadata, graph_walk.depth + 1
                FROM graph_walk
                JOIN sakina_ai.knowledge_graph_edges edge ON edge.from_entity_id = graph_walk.id
                JOIN sakina_ai.knowledge_graph_entities n ON n.id = edge.to_entity_id
                WHERE graph_walk.depth < 2
            )
            SELECT DISTINCT id, entity_type, entity_name, source_type, citation,
                   reliability_level, language, domain, metadata, depth
            FROM graph_walk
            WHERE depth > 0
            ORDER BY depth ASC, entity_name ASC
            "#,
        )
        .bind(focus_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to expand knowledge graph"))?;

        Ok(rows
            .into_iter()
            .map(|row| {
                (
                    KnowledgeGraphEntityView {
                        id: row.get("id"),
                        entity_type: row.get("entity_type"),
                        entity_name: row.get("entity_name"),
                        source_type: row.get("source_type"),
                        citation: row.get("citation"),
                        reliability_level: row.get("reliability_level"),
                        language: row.get("language"),
                        domain: row.get("domain"),
                        metadata: row.get("metadata"),
                    },
                    row.get::<i32, _>("depth").to_string(),
                    if row.get::<i32, _>("depth") == 1 {
                        0.88
                    } else {
                        0.76
                    },
                )
            })
            .collect())
    }

    pub async fn lookup(&self, query: &str) -> Result<KnowledgeGraphLookupResult, ApiError> {
        let focus_entity = self.lookup_focus(query).await?;
        let mut connected_nodes = Vec::new();
        let mut graph_path = Vec::new();
        let mut related_topics = Vec::new();
        let mut related_hadith = Vec::new();
        let mut citations = Vec::new();

        if let Some(entity) = &focus_entity {
            citations.push(entity.citation.clone());
            graph_path.push(entity.entity_name.clone());
            let neighbors = self.connected_entities(entity.id).await?;
            for (neighbor, depth_label, _confidence) in neighbors {
                if !citations.contains(&neighbor.citation) {
                    citations.push(neighbor.citation.clone());
                }
                if neighbor.entity_type.eq_ignore_ascii_case("topic") {
                    related_topics.push(neighbor.entity_name.clone());
                }
                if neighbor.entity_type.eq_ignore_ascii_case("hadith") {
                    related_hadith.push(neighbor.entity_name.clone());
                }
                graph_path.push(format!("{}:{}", depth_label, neighbor.entity_name.clone()));
                connected_nodes.push(neighbor);
            }
        }

        if focus_entity.is_none() {
            let fallback_rows = sqlx::query(
                r#"
                SELECT id, entity_type, entity_name, source_type, citation, reliability_level,
                       language, domain, metadata
                FROM sakina_ai.knowledge_graph_entities
                WHERE entity_type = 'topic'
                   OR metadata::text ILIKE $1
                ORDER BY created_at DESC
                LIMIT 10
                "#,
            )
            .bind(format!("%{}%", query.trim()))
            .fetch_all(&self.pool)
            .await
            .map_err(|_| ApiError::internal("failed to load fallback graph entities"))?;
            for row in fallback_rows {
                let entity = KnowledgeGraphEntityView {
                    id: row.get("id"),
                    entity_type: row.get("entity_type"),
                    entity_name: row.get("entity_name"),
                    source_type: row.get("source_type"),
                    citation: row.get("citation"),
                    reliability_level: row.get("reliability_level"),
                    language: row.get("language"),
                    domain: row.get("domain"),
                    metadata: row.get("metadata"),
                };
                citations.push(entity.citation.clone());
                if entity.entity_type.eq_ignore_ascii_case("topic") {
                    related_topics.push(entity.entity_name.clone());
                }
                connected_nodes.push(entity.clone());
                graph_path.push(entity.entity_name.clone());
            }
        }

        connected_nodes.sort_by(|a, b| a.entity_name.cmp(&b.entity_name));
        connected_nodes.dedup_by(|a, b| a.id == b.id);
        related_topics.sort();
        related_topics.dedup();
        related_hadith.sort();
        related_hadith.dedup();
        citations.sort();
        citations.dedup();

        Ok(KnowledgeGraphLookupResult {
            query: query.to_string(),
            focus_entity,
            connected_nodes,
            graph_path,
            related_topics,
            related_hadith,
            citations,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lookup_result_serializes() {
        let result = KnowledgeGraphLookupResult {
            query: "sadness".to_string(),
            focus_entity: None,
            connected_nodes: vec![],
            graph_path: vec![],
            related_topics: vec![],
            related_hadith: vec![],
            citations: vec![],
        };
        let json = serde_json::to_string(&result).unwrap();
        assert!(json.contains("\"query\":\"sadness\""));
    }
}
