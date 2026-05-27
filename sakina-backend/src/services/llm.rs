//! vLLM completion client for grounded RAG answers.
//!
//! Uses the OpenAI-compatible `/v1/chat/completions` endpoint. The prompt
//! explicitly constrains the model to retrieved verified context and requires a
//! scholar-referral fallback when the context is insufficient.

use reqwest::Client;
use serde::{Deserialize, Serialize};
use tokio::time::{sleep, Duration};

#[derive(Debug, Clone)]
pub struct RetrievedContext {
    pub chunk_id: String,
    pub title: String,
    pub text: String,
}

#[derive(Serialize)]
struct ChatCompletionRequest {
    model: String,
    messages: Vec<ChatMessage>,
    temperature: f32,
    max_tokens: u32,
}

#[derive(Serialize)]
struct ChatMessage {
    role: &'static str,
    content: String,
}

#[derive(Deserialize)]
struct ChatCompletionResponse {
    choices: Vec<ChatChoice>,
}

#[derive(Deserialize)]
struct ChatChoice {
    message: ChatChoiceMessage,
}

#[derive(Deserialize)]
struct ChatChoiceMessage {
    content: String,
}

pub struct LlmService {
    client: Client,
    base_url: String,
    model: String,
}

impl LlmService {
    pub fn new(base_url: &str) -> Self {
        let client = Client::builder()
            .connect_timeout(Duration::from_secs(5))
            .timeout(Duration::from_secs(45))
            .build()
            .unwrap_or_else(|_| Client::new());
        LlmService {
            client,
            base_url: base_url.trim_end_matches('/').to_string(),
            model: std::env::var("VLLM_CHAT_MODEL").unwrap_or_else(|_| "sakina-local".to_string()),
        }
    }

    pub async fn generate_grounded_answer(
        &self,
        query: &str,
        contexts: &[RetrievedContext],
    ) -> Result<String, Box<dyn std::error::Error>> {
        if contexts.is_empty() {
            return Err("cannot generate an answer without retrieved context".into());
        }

        let req = ChatCompletionRequest {
            model: self.model.clone(),
            messages: vec![
                ChatMessage {
                    role: "system",
                    content: system_prompt(),
                },
                ChatMessage {
                    role: "user",
                    content: build_grounded_prompt(query, contexts),
                },
            ],
            temperature: 0.1,
            max_tokens: 700,
        };

        let mut last_err: Option<String> = None;
        let mut resp: Option<ChatCompletionResponse> = None;
        for attempt in 1..=3 {
            let response = self
                .client
                .post(format!("{}/v1/chat/completions", self.base_url))
                .json(&req)
                .send()
                .await;
            match response {
                Ok(http_response) => {
                    let http_response = http_response.error_for_status()?;
                    resp = Some(http_response.json().await?);
                    break;
                }
                Err(err) => {
                    last_err = Some(err.to_string());
                    if attempt < 3 {
                        sleep(Duration::from_millis(250 * attempt as u64)).await;
                    }
                }
            }
        }
        let resp = match resp {
            Some(v) => v,
            None => {
                return Err(last_err
                    .unwrap_or_else(|| "llm request failed".to_string())
                    .into())
            }
        };

        resp.choices
            .into_iter()
            .next()
            .map(|choice| choice.message.content.trim().to_string())
            .filter(|answer| !answer.is_empty())
            .ok_or_else(|| "vLLM returned an empty completion".into())
    }

    pub async fn health_check(&self) -> bool {
        self.client
            .get(format!("{}/v1/models", self.base_url))
            .send()
            .await
            .map(|resp| resp.status().is_success())
            .unwrap_or(false)
    }
}

fn system_prompt() -> String {
    "You are Sakina, a cautious Islamic guidance assistant. Answer only from \
     the verified context supplied by the application. Do not invent rulings, \
     sources, schools of law, narrations, scholars, or certainty. If the \
     supplied context does not directly support an answer, say that the verified \
     sources are insufficient and advise the user to consult a qualified Islamic \
     scholar. Keep the answer concise, respectful, and cite source labels like \
     [S1] when using context."
        .to_string()
}

pub fn build_grounded_prompt(query: &str, contexts: &[RetrievedContext]) -> String {
    let mut prompt = String::from("Question:\n");
    prompt.push_str(query.trim());
    prompt.push_str("\n\nVerified context:\n");

    for (idx, context) in contexts.iter().enumerate() {
        prompt.push_str(&format!(
            "[S{}] chunk_id={} title={}\n{}\n\n",
            idx + 1,
            context.chunk_id,
            context.title,
            context.text.trim()
        ));
    }

    prompt.push_str(
        "Instructions:\n- Answer only from the verified context above.\n- Use source labels like [S1].\n- If the context is insufficient, refuse to answer and advise consulting a qualified Islamic scholar.\n",
    );
    prompt
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn prompt_contains_query_context_and_source_labels() {
        let prompt = build_grounded_prompt(
            "Is this permissible?",
            &[RetrievedContext {
                chunk_id: "abc".to_string(),
                title: "Verified Text".to_string(),
                text: "A relevant passage.".to_string(),
            }],
        );

        assert!(prompt.contains("Is this permissible?"));
        assert!(prompt.contains("[S1]"));
        assert!(prompt.contains("A relevant passage."));
        assert!(prompt.contains("If the context is insufficient"));
    }
}
