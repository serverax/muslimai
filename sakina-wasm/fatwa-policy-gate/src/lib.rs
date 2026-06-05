// Deterministic policy gate for Sakina fatwa / high-risk answer handling.
// This crate is pure Rust and can compile to native rlib for testing and to
// wasm32-unknown-unknown cdylib for mobile or host-side integration.

#![cfg_attr(target_arch = "wasm32", no_std)]

#[cfg(target_arch = "wasm32")]
extern crate alloc;

#[cfg(target_arch = "wasm32")]
use alloc::string::{String, ToString};

use serde::{Deserialize, Serialize};

#[cfg(target_arch = "wasm32")]
use wasm_bindgen::prelude::*;

#[derive(Debug, Clone, Deserialize)]
pub struct AnswerInput {
    pub has_scholar_approval: bool,
    pub has_verified_quran_or_hadith_citation: bool,
    pub publication_mode_public: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Decision {
    pub decision: &'static str,
    pub reason: &'static str,
}

pub fn evaluate(input: &AnswerInput) -> Decision {
    if input.publication_mode_public {
        if !input.has_scholar_approval {
            return Decision {
                decision: "block",
                reason: "public_fatwa_requires_scholar_approval",
            };
        }
        if !input.has_verified_quran_or_hadith_citation {
            return Decision {
                decision: "block",
                reason: "public_fatwa_requires_quran_or_hadith_citation",
            };
        }
        return Decision {
            decision: "allow_publish",
            reason: "approved_and_cited",
        };
    }

    if input.has_verified_quran_or_hadith_citation {
        return Decision {
            decision: "allow_publish",
            reason: "private_answer_with_citation",
        };
    }

    Decision {
        decision: "needs_scholar_review",
        reason: "private_answer_without_quran_or_hadith_citation",
    }
}

#[cfg(target_arch = "wasm32")]
#[wasm_bindgen]
pub fn evaluate_json(input_json: String) -> String {
    let input: AnswerInput = serde_json::from_str(&input_json).unwrap_or(AnswerInput {
        has_scholar_approval: false,
        has_verified_quran_or_hadith_citation: false,
        publication_mode_public: false,
    });
    let decision = evaluate(&input);
    serde_json::to_string(&decision).unwrap_or_else(|_| "{}".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn input(approval: bool, citation: bool, public: bool) -> AnswerInput {
        AnswerInput {
            has_scholar_approval: approval,
            has_verified_quran_or_hadith_citation: citation,
            publication_mode_public: public,
        }
    }

    #[test]
    fn public_without_approval_blocked() {
        let d = evaluate(&input(false, true, true));
        assert_eq!(d.decision, "block");
        assert_eq!(d.reason, "public_fatwa_requires_scholar_approval");
    }

    #[test]
    fn public_without_citation_blocked() {
        let d = evaluate(&input(true, false, true));
        assert_eq!(d.decision, "block");
        assert_eq!(d.reason, "public_fatwa_requires_quran_or_hadith_citation");
    }

    #[test]
    fn public_with_both_passes() {
        let d = evaluate(&input(true, true, true));
        assert_eq!(d.decision, "allow_publish");
    }

    #[test]
    fn private_with_citation_passes() {
        let d = evaluate(&input(false, true, false));
        assert_eq!(d.decision, "allow_publish");
    }

    #[test]
    fn private_without_citation_needs_review() {
        let d = evaluate(&input(false, false, false));
        assert_eq!(d.decision, "needs_scholar_review");
    }
}
