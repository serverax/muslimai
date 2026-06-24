#[cfg(test)]
mod tests {
    use crate::handlers::sakina_ask::high_risk_fatwa;

    #[test]
    fn test_high_risk_fatwa_detection() {
        assert!(high_risk_fatwa("How to divorce?"));
        assert!(high_risk_fatwa("Can I issue talaq by text?"));
        assert!(high_risk_fatwa("Is my divorce valid?"));
        assert!(high_risk_fatwa("Give me a fatwa on marriage separation"));
        assert!(high_risk_fatwa("Inheritance rules for daughter"));
        assert!(high_risk_fatwa("Killing is allowed in war?"));
    }
}
