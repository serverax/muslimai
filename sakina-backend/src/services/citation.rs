//! Citation engine: maps retrieved chunk IDs back to their verified source
//! documents and builds the `Citation` list returned with each answer.
//!
//! Joins `verified_knowledge.chunks` to `source_documents` and returns source
//! metadata for the retrieved chunk IDs.

use serde::Serialize;
use sqlx::PgPool;
use uuid::Uuid;

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

#[derive(Debug, sqlx::FromRow)]
struct CitationRow {
    title: String,
    author: String,
    chapter: Option<String>,
    authenticity_grade: Option<String>,
}

impl CitationEngine {
    pub fn new(pool: PgPool) -> Self {
        CitationEngine { pool }
    }

    pub async fn cite(
        &self,
        chunk_ids: &[Uuid],
    ) -> Result<Vec<Citation>, Box<dyn std::error::Error>> {
        if chunk_ids.is_empty() {
            return Ok(vec![]);
        }

        let rows: Vec<CitationRow> = sqlx::query_as(
            "SELECT DISTINCT sd.title, sd.author, c.chapter, c.authenticity_grade \
             FROM verified_knowledge.chunks c \
             JOIN verified_knowledge.source_documents sd ON sd.id = c.source_document_id \
             WHERE c.id = ANY($1)",
        )
        .bind(chunk_ids)
        .fetch_all(&self.pool)
        .await?;

        Ok(rows
            .into_iter()
            .map(|row| Citation {
                title: row.title,
                author: row.author,
                chapter: row.chapter,
                authenticity_grade: row.authenticity_grade,
            })
            .collect())
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
