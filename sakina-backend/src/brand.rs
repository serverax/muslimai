//! Project Sakina Brand Identity Module
//!
//! This module defines and manages the brand identity for Project Sakina.
//! All branding, messaging, and identity is centralized here.

pub struct BrandIdentity {
    pub name: &'static str,
    pub vision: &'static str,
    pub mission: &'static str,
    pub tagline: &'static str,
    pub values: &'static [&'static str],
}

pub const SAKINA: BrandIdentity = BrandIdentity {
    name: "SAKINA",
    vision: "Empower Muslims with Sovereign, Intelligent, and Trustworthy Islamic Guidance",
    mission: "Zero-hallucination Islamic guidance with complete privacy and sovereignty",
    tagline: "Trustworthy. Private. Islamic.",
    values: &[
        "Integrity - Never compromise on authenticity",
        "Privacy - User data is sacred",
        "Excellence - Zero tolerance for hallucinations",
        "Accessibility - Simple, works offline",
        "Community - Open source, collaborative",
    ],
};

pub struct Colors {
    pub primary: &'static str,
    pub background: &'static str,
    pub text: &'static str,
    pub accent: &'static str,
    pub error: &'static str,
}

pub const BRAND_COLORS: Colors = Colors {
    primary: "#1B6B5E",    // Islamic Green
    background: "#F5F5F5", // Light
    text: "#212121",       // Dark
    accent: "#E8F5E9",     // Soft Green
    error: "#D32F2F",      // Alert Red
};

pub fn get_brand_promise() -> &'static str {
    "Authentic Islamic guidance, complete privacy, transparency in every interaction"
}

pub fn get_brand_motto() -> (&'static str, &'static str) {
    (
        "Authentic. Private. Trusted.", // English
        "أصيل. خاص. موثوق",             // Arabic
    )
}
