//! Citation engine: maps retrieved chunk IDs back to their verified source
//! documents and builds the `Citation` list returned with each answer.
//!
//! Step 3 (Phase 1): typed `Citation` + a stubbed `cite()`. The real path will
//! join `verified_knowledge.chunks` → `verified_knowledge.source_documents`;
//! stubbed until ingestion (Phase 2) populates those tables.

use serde::Serialize;
use sqlx::PgPool;

#[derive(Debug, Serialize, Clone)]
pub struct Citation {
    pub title: String,
    pub author: String,
    pub chapter: Option<String>,
    pub authenticity_grade: Option<String>,
}

pub struct CitationEngine {
    pool: PgPool,
}

impl CitationEngine {
    pub fn new(pool: PgPool) -> Self {
        CitationEngine { pool }
    }

    /// Given retrieved chunk IDs, fetch source metadata.
    ///
    /// TODO:
    ///   SELECT source_document_id FROM verified_knowledge.chunks WHERE id = ANY($1)
    ///   SELECT title, author, chapter, authenticity_grade
    ///     FROM verified_knowledge.source_documents WHERE id = ANY(...)
    /// Stubbed (one sample citation) until the tables are populated.
    pub async fn cite(
        &self,
        chunk_ids: &[i64],
    ) -> Result<Vec<Citation>, Box<dyn std::error::Error>> {
        // Touch pool + chunk_ids so the field/param aren't flagged unused.
        let _ = (&self.pool, chunk_ids);
        Ok(vec![Citation {
            title: "Sample Islamic Text".to_string(),
            author: "Scholar Name".to_string(),
            chapter: Some("Chapter 1".to_string()),
            authenticity_grade: Some("Sahih".to_string()),
        }])
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn citation_serializes_expected_shape() {
        let c = Citation {
            title: "Sahih al-Bukhari".to_string(),
            author: "Imam al-Bukhari".to_string(),
            chapter: Some("Book of Faith".to_string()),
            authenticity_grade: Some("Sahih".to_string()),
        };
        let json = serde_json::to_string(&c).unwrap();
        assert!(json.contains("\"title\":\"Sahih al-Bukhari\""));
        assert!(json.contains("\"authenticity_grade\":\"Sahih\""));
    }
}
