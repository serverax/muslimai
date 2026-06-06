#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PiiRedactionResult {
    pub redacted_text: String,
    pub pii_detected: bool,
}

pub fn redact_pii(input: &str) -> PiiRedactionResult {
    let mut working = input.to_string();
    let mut detected = false;

    for marker in [
        "my name is",
        "i am called",
        "call me",
        "اسمي",
        "أنا اسمي",
        "انا اسمي",
    ] {
        working = redact_phrase_value(&working, marker, "[REDACTED_NAME]", &mut detected);
    }
    for marker in [
        "i live at",
        "my address is",
        "address is",
        "i live in",
        "أعيش في",
        "اسكن في",
        "أسكن في",
        "عنواني",
    ] {
        working = redact_phrase_value(&working, marker, "[REDACTED_ADDRESS]", &mut detected);
    }

    let mut redacted = String::new();
    let mut token = String::new();

    let flush_token = |token: &mut String, out: &mut String, detected: &mut bool| {
        if token.is_empty() {
            return;
        }

        let lower = token.to_ascii_lowercase();
        let digit_count = token.chars().filter(|c| c.is_ascii_digit()).count();
        let replacement = if lower.contains('@') && lower.contains('.') {
            *detected = true;
            "[REDACTED_EMAIL]"
        } else if digit_count >= 4 {
            *detected = true;
            "[REDACTED_NUMBER]"
        } else {
            token.as_str()
        };

        out.push_str(replacement);
        token.clear();
    };

    for ch in working.chars() {
        if ch.is_whitespace() {
            flush_token(&mut token, &mut redacted, &mut detected);
            redacted.push(ch);
        } else {
            token.push(ch);
        }
    }
    flush_token(&mut token, &mut redacted, &mut detected);

    PiiRedactionResult {
        redacted_text: redacted.trim().to_string(),
        pii_detected: detected,
    }
}

fn redact_phrase_value(
    input: &str,
    marker: &str,
    replacement: &str,
    detected: &mut bool,
) -> String {
    let lower = input.to_ascii_lowercase();
    let marker_lower = marker.to_ascii_lowercase();
    let Some(start) = lower.find(&marker_lower) else {
        return input.to_string();
    };
    *detected = true;
    let value_start = start + marker.len();
    let tail = &input[value_start..];
    let semantic_stop = tail.to_ascii_lowercase();
    let phrase_stop = [
        " and i live",
        " and my address",
        " and address",
        " وأعيش",
        " واسكن",
        " وأسكن",
    ]
    .iter()
    .filter_map(|needle| semantic_stop.find(needle))
    .min();
    let value_end_offset = phrase_stop.unwrap_or_else(|| {
        tail.char_indices()
            .find_map(|(idx, ch)| {
                if matches!(ch, '.' | ',' | ';' | '\n') {
                    Some(idx)
                } else {
                    None
                }
            })
            .unwrap_or_else(|| {
                tail.char_indices()
                    .take(5)
                    .last()
                    .map(|(idx, ch)| idx + ch.len_utf8())
                    .unwrap_or(0)
            })
    });
    let value_end = value_start + value_end_offset;
    let mut out = String::new();
    out.push_str(&input[..start]);
    out.push_str(marker);
    out.push(' ');
    out.push_str(replacement);
    out.push_str(&input[value_end..]);
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn redacts_email_and_phone_like_numbers() {
        let result = redact_pii("Email user@example.com or call 07700900123");
        assert!(result.pii_detected);
        assert!(result.redacted_text.contains("[REDACTED_EMAIL]"));
        assert!(result.redacted_text.contains("[REDACTED_NUMBER]"));
        assert!(!result.redacted_text.contains("user@example.com"));
        assert!(!result.redacted_text.contains("07700900123"));
    }

    #[test]
    fn redacts_names_and_addresses_from_common_phrases() {
        let result = redact_pii("My name is Ahmed and I live at 22 Green Street. I need help.");
        assert!(result.pii_detected);
        assert!(result.redacted_text.contains("[REDACTED_NAME]"));
        assert!(result.redacted_text.contains("[REDACTED_ADDRESS]"));
        assert!(!result.redacted_text.contains("Ahmed"));
        assert!(!result.redacted_text.contains("22 Green Street"));
    }

    #[test]
    fn safe_text_is_unchanged() {
        let result = redact_pii("What is the dua for patience?");
        assert!(!result.pii_detected);
        assert_eq!(result.redacted_text, "What is the dua for patience?");
    }
}
