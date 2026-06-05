use serde_json::Value;

fn load_json(path: &str) -> Value {
    let raw = match path {
        "../data/islamic-sources/quran-full-tanzil.json" => {
            include_str!("../data/islamic-sources/quran-full-tanzil.json")
        }
        "../data/islamic-sources/duas.json" => include_str!("../data/islamic-sources/duas.json"),
        "../data/islamic-sources/adhkar.json" => {
            include_str!("../data/islamic-sources/adhkar.json")
        }
        "../data/islamic-sources/names_of_allah.json" => {
            include_str!("../data/islamic-sources/names_of_allah.json")
        }
        "../db/source-candidates/islamic-source-candidates.json" => {
            include_str!("../db/source-candidates/islamic-source-candidates.json")
        }
        "../data/islamic-sources/offline-starter-content.json" => {
            include_str!("../data/islamic-sources/offline-starter-content.json")
        }
        "../data/islamic-sources/internal-reviewed-starter-qa.json" => {
            include_str!("../data/islamic-sources/internal-reviewed-starter-qa.json")
        }
        "../data/islamic-sources/starter-categories.json" => {
            include_str!("../data/islamic-sources/starter-categories.json")
        }
        _ => panic!("unexpected path: {path}"),
    };
    serde_json::from_str(raw).expect("valid JSON asset")
}

#[test]
fn quran_asset_is_loaded_and_citable() {
    let quran: Value = load_json("../data/islamic-sources/quran-full-tanzil.json");
    assert_eq!(quran["surahs"].as_array().expect("surahs array").len(), 114);
    assert_eq!(quran["ayah_count"].as_i64().expect("ayah_count"), 6236);

    let first_ayah = &quran["surahs"][0]["ayahs"][0];
    assert_eq!(first_ayah["source_id"], "tanzil-quran-text");
    assert_eq!(first_ayah["source_approved"], true);
    assert!(!first_ayah["text_uthmani"].as_str().unwrap_or("").is_empty());
}

#[test]
fn dua_adhkar_and_names_assets_are_loaded() {
    let duas: Value = load_json("../data/islamic-sources/duas.json");
    let adhkar: Value = load_json("../data/islamic-sources/adhkar.json");
    let names: Value = load_json("../data/islamic-sources/names_of_allah.json");

    assert_eq!(duas["items"].as_array().expect("duas items").len(), 20);
    assert_eq!(adhkar["items"].as_array().expect("adhkar items").len(), 26);
    assert_eq!(names["names"].as_array().expect("names array").len(), 99);

    let dua_source = duas["items"][0]["source"].as_str().unwrap_or("");
    let adhkar_source = adhkar["items"][0]["source"].as_str().unwrap_or("");
    assert!(!dua_source.is_empty());
    assert!(!adhkar_source.is_empty());
}

#[test]
fn source_registry_contains_approved_quran_source() {
    let registry: Value = load_json("../db/source-candidates/islamic-source-candidates.json");
    let candidates = registry["candidates"].as_array().expect("candidates array");
    let quran_sources = candidates
        .iter()
        .filter(|candidate| candidate["content_type"] == "Quran")
        .count();
    assert!(quran_sources >= 3);
    assert!(
        candidates.iter().any(|candidate| {
            candidate["source_id"] == "tanzil-quran-text"
                && candidate["offline_storage_allowed"] == true
        }),
        "tanzil source should be approved for offline storage"
    );
}

#[test]
fn starter_bundle_and_categories_exist_for_fallback_ui() {
    let starter: Value = load_json("../data/islamic-sources/offline-starter-content.json");
    let categories: Value = load_json("../data/islamic-sources/starter-categories.json");
    let reviewed: Value = load_json("../data/islamic-sources/internal-reviewed-starter-qa.json");

    assert_eq!(starter["schema_version"], 1);
    assert!(
        starter["quran"]["surahs"]
            .as_array()
            .expect("starter surahs")
            .len()
            >= 2
    );
    assert_eq!(
        categories["categories"]
            .as_array()
            .expect("categories")
            .len(),
        7
    );
    assert_eq!(
        reviewed["items"].as_array().expect("reviewed items").len(),
        2
    );
}
