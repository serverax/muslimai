use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct McpConnectorSpec {
    pub name: String,
    pub category: String,
    pub enabled: bool,
    pub endpoint: Option<String>,
}

#[derive(Debug, Clone)]
pub struct McpConnectorRegistry {
    enabled: bool,
    connectors: Vec<McpConnectorSpec>,
}

impl McpConnectorRegistry {
    pub fn from_env() -> Self {
        let enabled = std::env::var("SAKINA_MCP_ENABLED")
            .ok()
            .map(|value| {
                matches!(
                    value.trim().to_ascii_lowercase().as_str(),
                    "1" | "true" | "yes"
                )
            })
            .unwrap_or(false);
        let connectors = vec![
            McpConnectorSpec {
                name: "documents".to_string(),
                category: "documents".to_string(),
                enabled,
                endpoint: std::env::var("SAKINA_MCP_DOCUMENTS_ENDPOINT").ok(),
            },
            McpConnectorSpec {
                name: "calendar_reminders".to_string(),
                category: "calendar".to_string(),
                enabled,
                endpoint: std::env::var("SAKINA_MCP_CALENDAR_ENDPOINT").ok(),
            },
            McpConnectorSpec {
                name: "web_search".to_string(),
                category: "search".to_string(),
                enabled,
                endpoint: std::env::var("SAKINA_MCP_WEB_ENDPOINT").ok(),
            },
            McpConnectorSpec {
                name: "internal_db".to_string(),
                category: "database".to_string(),
                enabled,
                endpoint: std::env::var("SAKINA_MCP_DB_ENDPOINT").ok(),
            },
            McpConnectorSpec {
                name: "admin_tools".to_string(),
                category: "admin".to_string(),
                enabled,
                endpoint: std::env::var("SAKINA_MCP_ADMIN_ENDPOINT").ok(),
            },
        ];
        Self {
            enabled,
            connectors,
        }
    }

    pub fn connectors(&self) -> &[McpConnectorSpec] {
        &self.connectors
    }

    pub fn enabled(&self) -> bool {
        self.enabled
    }

    pub fn can_call(&self, name: &str) -> bool {
        self.enabled
            && self.connectors.iter().any(|connector| {
                connector.enabled && connector.name == name && connector.endpoint.is_some()
            })
    }

    pub fn call(&self, name: &str) -> Result<serde_json::Value, String> {
        if !self.can_call(name) {
            return Err("connector disabled by configuration".to_string());
        }
        Err(format!(
            "connector {name} has no production executor wired; failing closed"
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn registry_is_disabled_by_default() {
        std::env::remove_var("SAKINA_MCP_ENABLED");
        let registry = McpConnectorRegistry::from_env();
        assert!(!registry.enabled());
        assert!(!registry.can_call("documents"));
        assert!(registry.call("documents").is_err());
    }
}
