#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PiiRedactionResult {
    pub redacted_text: String,
    pub pii_detected: bool,
}

pub fn redact_pii(input: &str) -> PiiRedactionResult {
    let mut redacted = String::new();
    let mut token = String::new();
    let mut detected = false;

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

    for ch in input.chars() {
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
    fn safe_text_is_unchanged() {
        let result = redact_pii("What is the dua for patience?");
        assert!(!result.pii_detected);
        assert_eq!(result.redacted_text, "What is the dua for patience?");
    }
}
