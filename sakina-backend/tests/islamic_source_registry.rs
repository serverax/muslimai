use serde_json::Value;

#[test]
fn islamic_source_registry_is_present_and_well_formed() {
    let registry: Value = serde_json::from_str(include_str!(
        "../db/source-candidates/islamic-source-candidates.json"
    ))
    .expect("registry JSON should parse");

    assert_eq!(registry["registry_version"], 1);
    assert_eq!(registry["source_approved_default"], false);

    let candidates = registry["candidates"].as_array().expect("candidates array");
    assert!(
        !candidates.is_empty(),
        "registry should contain at least one candidate"
    );

    for candidate in candidates {
        for key in [
            "source_id",
            "title",
            "provider",
            "url",
            "content_type",
            "language",
            "licence_status",
            "approval_status",
            "notes",
        ] {
            assert!(
                candidate.get(key).and_then(|v| v.as_str()).is_some(),
                "candidate missing {key}"
            );
        }

        assert!(
            candidate
                .get("source_id")
                .and_then(|v| v.as_str())
                .and_then(|s| s.chars().next())
                .map(|c| c.is_ascii_lowercase())
                .unwrap_or(false),
            "source_id should be machine-readable"
        );
    }
}

#[test]
fn islamic_source_registry_contains_core_sources() {
    let registry: Value = serde_json::from_str(include_str!(
        "../db/source-candidates/islamic-source-candidates.json"
    ))
    .expect("registry JSON should parse");
    let candidates = registry["candidates"].as_array().expect("candidates array");
    let ids: Vec<&str> = candidates
        .iter()
        .filter_map(|c| c.get("source_id").and_then(|v| v.as_str()))
        .collect();

    for expected in ["tanzil-quran-text", "fawazahmed0-hadith-api", "aladhan-api"] {
        assert!(
            ids.contains(&expected),
            "missing expected source {expected}"
        );
    }
}
