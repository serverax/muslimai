use std::collections::HashSet;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CompressedEvidenceChunk {
    pub source_id: String,
    pub title: String,
    pub citation: String,
    pub trust_level: String,
    pub language: String,
    pub text: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CompressionReport {
    pub tokens_before: usize,
    pub tokens_after: usize,
    pub compression_ratio: f32,
    pub preserved_citations: Vec<String>,
    pub compressed_chunks: Vec<CompressedEvidenceChunk>,
}

#[derive(Debug, Default, Clone)]
pub struct ContextCompressionService;

impl ContextCompressionService {
    pub fn new() -> Self {
        Self
    }

    pub fn compress(
        &self,
        chunks: &[CompressedEvidenceChunk],
        max_chunks: usize,
    ) -> CompressionReport {
        let tokens_before = chunks
            .iter()
            .map(|chunk| chunk.text.len() + chunk.citation.len() + chunk.title.len())
            .sum::<usize>();
        let mut seen = HashSet::new();
        let mut ordered = chunks.to_vec();
        ordered.sort_by(|a, b| {
            b.trust_level
                .cmp(&a.trust_level)
                .then_with(|| b.citation.len().cmp(&a.citation.len()))
        });

        let mut compressed_chunks = Vec::new();
        let mut preserved_citations = Vec::new();
        for chunk in ordered {
            let key = normalize(&format!(
                "{}|{}|{}",
                chunk.source_id, chunk.citation, chunk.text
            ));
            if seen.insert(key) {
                preserved_citations.push(chunk.citation.clone());
                compressed_chunks.push(CompressedEvidenceChunk {
                    text: compress_text(&chunk.text),
                    ..chunk
                });
            }
            if compressed_chunks.len() >= max_chunks {
                break;
            }
        }

        let tokens_after = compressed_chunks
            .iter()
            .map(|chunk| chunk.text.len() + chunk.citation.len() + chunk.title.len())
            .sum::<usize>();
        let compression_ratio = if tokens_before == 0 {
            1.0
        } else {
            tokens_after as f32 / tokens_before as f32
        };

        CompressionReport {
            tokens_before,
            tokens_after,
            compression_ratio,
            preserved_citations,
            compressed_chunks,
        }
    }
}

fn normalize(text: &str) -> String {
    text.to_ascii_lowercase()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

fn compress_text(text: &str) -> String {
    const MAX_CHARS: usize = 96;
    if text.chars().count() <= MAX_CHARS {
        return text.to_string();
    }

    let mut compressed = text.chars().take(MAX_CHARS).collect::<String>();
    compressed.push_str(" ...");
    compressed
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compression_deduplicates_and_preserves_citations() {
        let service = ContextCompressionService::new();
        let report = service.compress(
            &[
                CompressedEvidenceChunk {
                    source_id: "1".to_string(),
                    title: "Quran".to_string(),
                    citation: "Quran 2:153".to_string(),
                    trust_level: "verified".to_string(),
                    language: "en".to_string(),
                    text: "Indeed, Allah is with the patient.".to_string(),
                },
                CompressedEvidenceChunk {
                    source_id: "1".to_string(),
                    title: "Quran".to_string(),
                    citation: "Quran 2:153".to_string(),
                    trust_level: "verified".to_string(),
                    language: "en".to_string(),
                    text: "Indeed, Allah is with the patient.".to_string(),
                },
            ],
            5,
        );
        assert_eq!(report.compressed_chunks.len(), 1);
        assert_eq!(report.preserved_citations, vec!["Quran 2:153"]);
        assert!(report.tokens_before >= report.tokens_after);
    }
}
