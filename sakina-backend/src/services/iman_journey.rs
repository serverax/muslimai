use chrono::{NaiveDate, Utc};
use serde_json::Value;
use sqlx::{PgPool, Row};
use uuid::Uuid;

use crate::error::ApiError;
use crate::models::{
    AddDuaItemRequest, ImanDuaItem, ImanJourneyEvidenceItem, ImanJourneyFamilyReminder,
    ImanJourneyPrivacySettings, ImanJourneyProgress, ImanJourneyReligiousReminder,
    ImanJourneyResponse, ImanJourneySafeFallback, UpsertImanJourneyPrivacyRequest,
    UpsertImanJourneyRequest,
};

#[derive(Clone)]
pub struct ImanJourneyService {
    pool: PgPool,
}

impl ImanJourneyService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    pub async fn upsert_journey(
        &self,
        user_id: Uuid,
        request: UpsertImanJourneyRequest,
    ) -> Result<ImanJourneyResponse, ApiError> {
        if request.today_focus.trim().is_empty() {
            return Err(ApiError::bad_request("today_focus is required"));
        }
        let journey_date = parse_or_today(request.journey_date.as_deref())?;
        let privacy = self.get_or_create_privacy_settings(user_id).await?;
        if !privacy.store_journey_enabled {
            return Err(ApiError::bad_request(
                "stored journey data is disabled by privacy settings",
            ));
        }

        sqlx::query(
            r#"
            INSERT INTO public.iman_journey_daily (
                user_id, journey_date, today_focus, continue_yesterday_topic,
                prayer_progress, quran_progress, dhikr_progress,
                ask_sakina_today_context, tomorrow_follow_up, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, now())
            ON CONFLICT (user_id, journey_date)
            DO UPDATE SET
                today_focus = EXCLUDED.today_focus,
                continue_yesterday_topic = EXCLUDED.continue_yesterday_topic,
                prayer_progress = EXCLUDED.prayer_progress,
                quran_progress = EXCLUDED.quran_progress,
                dhikr_progress = EXCLUDED.dhikr_progress,
                ask_sakina_today_context = EXCLUDED.ask_sakina_today_context,
                tomorrow_follow_up = EXCLUDED.tomorrow_follow_up,
                updated_at = now()
            "#,
        )
        .bind(user_id)
        .bind(journey_date)
        .bind(request.today_focus)
        .bind(request.continue_yesterday_topic)
        .bind(request.progress.prayer)
        .bind(request.progress.quran)
        .bind(request.progress.dhikr)
        .bind(request.ask_sakina_today_context)
        .bind(request.tomorrow_follow_up)
        .execute(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to upsert iman journey"))?;

        if let Some(family) = request.family_reminder {
            let reminder_text = if family.consent_granted {
                family
                    .reminder_text
                    .as_deref()
                    .map(str::trim)
                    .filter(|v| !v.is_empty())
                    .map(ToOwned::to_owned)
            } else {
                None
            };
            let notify_family = family.consent_granted && family.notify_family;
            sqlx::query(
                r#"
                INSERT INTO public.iman_family_reminder_settings (
                    user_id, consent_granted, reminder_text, notify_family, updated_at
                )
                VALUES ($1, $2, $3, $4, now())
                ON CONFLICT (user_id)
                DO UPDATE SET
                    consent_granted = EXCLUDED.consent_granted,
                    reminder_text = EXCLUDED.reminder_text,
                    notify_family = EXCLUDED.notify_family,
                    updated_at = now()
                "#,
            )
            .bind(user_id)
            .bind(family.consent_granted)
            .bind(reminder_text)
            .bind(notify_family)
            .execute(&self.pool)
            .await
            .map_err(|_| ApiError::internal("failed to upsert family reminder settings"))?;
        }

        if request.religious_reminder_text.is_some() || request.evidence_bundle.is_some() {
            let evidence_value = serde_json::to_value(request.evidence_bundle.unwrap_or_default())
                .map_err(|_| ApiError::internal("failed to encode evidence bundle"))?;
            sqlx::query(
                r#"
                INSERT INTO public.iman_journey_evidence_bundles (
                    user_id, journey_date, reminder_text, confidence_score, evidence_bundle, updated_at
                )
                VALUES ($1, $2, $3, $4, $5, now())
                ON CONFLICT (user_id, journey_date)
                DO UPDATE SET
                    reminder_text = EXCLUDED.reminder_text,
                    confidence_score = EXCLUDED.confidence_score,
                    evidence_bundle = EXCLUDED.evidence_bundle,
                    updated_at = now()
                "#,
            )
            .bind(user_id)
            .bind(journey_date)
            .bind(request.religious_reminder_text)
            .bind(request.religious_confidence_score.unwrap_or(0.0))
            .bind(evidence_value)
            .execute(&self.pool)
            .await
            .map_err(|_| ApiError::internal("failed to upsert evidence bundle"))?;
        }

        self.get_journey(user_id, Some(journey_date)).await
    }

    pub async fn get_journey(
        &self,
        user_id: Uuid,
        journey_date: Option<NaiveDate>,
    ) -> Result<ImanJourneyResponse, ApiError> {
        let date = journey_date.unwrap_or_else(today_utc_date);
        let privacy = self.get_or_create_privacy_settings(user_id).await?;
        let family = self.get_family_settings(user_id).await?;
        let dua_list = self.list_dua_items(user_id).await?;

        let row = sqlx::query(
            r#"
            SELECT
                journey_date::text AS journey_date,
                today_focus,
                continue_yesterday_topic,
                prayer_progress,
                quran_progress,
                dhikr_progress,
                ask_sakina_today_context,
                tomorrow_follow_up
            FROM public.iman_journey_daily
            WHERE user_id = $1 AND journey_date = $2
            "#,
        )
        .bind(user_id)
        .bind(date)
        .fetch_optional(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to load iman journey"))?;

        let evidence = self.get_reminder_with_evidence(user_id, date, &privacy).await?;
        if let Some(row) = row {
            Ok(ImanJourneyResponse {
                journey_date: row.get("journey_date"),
                today_focus: row.get("today_focus"),
                continue_yesterday_topic: row.get("continue_yesterday_topic"),
                progress: ImanJourneyProgress {
                    prayer: row.get("prayer_progress"),
                    quran: row.get("quran_progress"),
                    dhikr: row.get("dhikr_progress"),
                },
                personal_dua_list: dua_list,
                family_reminder: family,
                ask_sakina_today_context: row.get("ask_sakina_today_context"),
                tomorrow_follow_up: row.get("tomorrow_follow_up"),
                privacy_settings: privacy,
                religious_reminder: evidence,
            })
        } else {
            Ok(ImanJourneyResponse {
                journey_date: date.to_string(),
                today_focus: "Set your iman focus for today.".to_string(),
                continue_yesterday_topic: None,
                progress: ImanJourneyProgress {
                    prayer: 0,
                    quran: 0,
                    dhikr: 0,
                },
                personal_dua_list: dua_list,
                family_reminder: family,
                ask_sakina_today_context: None,
                tomorrow_follow_up: None,
                privacy_settings: privacy,
                religious_reminder: evidence,
            })
        }
    }

    pub async fn upsert_privacy_settings(
        &self,
        user_id: Uuid,
        request: UpsertImanJourneyPrivacyRequest,
    ) -> Result<ImanJourneyPrivacySettings, ApiError> {
        sqlx::query(
            r#"
            INSERT INTO public.iman_journey_privacy_settings (
                user_id, personalization_enabled, reminders_enabled, store_journey_enabled, updated_at
            )
            VALUES ($1, $2, $3, $4, now())
            ON CONFLICT (user_id)
            DO UPDATE SET
                personalization_enabled = EXCLUDED.personalization_enabled,
                reminders_enabled = EXCLUDED.reminders_enabled,
                store_journey_enabled = EXCLUDED.store_journey_enabled,
                updated_at = now()
            "#,
        )
        .bind(user_id)
        .bind(request.personalization_enabled)
        .bind(request.reminders_enabled)
        .bind(request.store_journey_enabled)
        .execute(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to upsert privacy settings"))?;
        self.get_or_create_privacy_settings(user_id).await
    }

    pub async fn get_or_create_privacy_settings(
        &self,
        user_id: Uuid,
    ) -> Result<ImanJourneyPrivacySettings, ApiError> {
        let row = sqlx::query(
            r#"
            INSERT INTO public.iman_journey_privacy_settings (
                user_id, personalization_enabled, reminders_enabled, store_journey_enabled
            )
            VALUES ($1, false, false, true)
            ON CONFLICT (user_id) DO UPDATE SET updated_at = public.iman_journey_privacy_settings.updated_at
            RETURNING personalization_enabled, reminders_enabled, store_journey_enabled
            "#,
        )
        .bind(user_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to read privacy settings"))?;
        Ok(ImanJourneyPrivacySettings {
            personalization_enabled: row.get("personalization_enabled"),
            reminders_enabled: row.get("reminders_enabled"),
            store_journey_enabled: row.get("store_journey_enabled"),
        })
    }

    pub async fn add_dua_item(
        &self,
        user_id: Uuid,
        request: AddDuaItemRequest,
    ) -> Result<ImanDuaItem, ApiError> {
        if request.dua_text.trim().is_empty() {
            return Err(ApiError::bad_request("dua_text is required"));
        }
        let row = sqlx::query(
            r#"
            INSERT INTO public.iman_personal_dua_list (user_id, dua_text, is_answered)
            VALUES ($1, $2, false)
            RETURNING id::text AS id, dua_text, is_answered
            "#,
        )
        .bind(user_id)
        .bind(request.dua_text.trim())
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to add dua item"))?;
        Ok(ImanDuaItem {
            id: row.get("id"),
            dua_text: row.get("dua_text"),
            is_answered: row.get("is_answered"),
        })
    }

    pub async fn list_dua_items(&self, user_id: Uuid) -> Result<Vec<ImanDuaItem>, ApiError> {
        let rows = sqlx::query(
            r#"
            SELECT id::text AS id, dua_text, is_answered
            FROM public.iman_personal_dua_list
            WHERE user_id = $1
            ORDER BY created_at DESC
            "#,
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to list dua items"))?;
        Ok(rows
            .into_iter()
            .map(|row| ImanDuaItem {
                id: row.get("id"),
                dua_text: row.get("dua_text"),
                is_answered: row.get("is_answered"),
            })
            .collect())
    }

    async fn get_family_settings(&self, user_id: Uuid) -> Result<ImanJourneyFamilyReminder, ApiError> {
        let row = sqlx::query(
            r#"
            SELECT consent_granted, reminder_text, notify_family
            FROM public.iman_family_reminder_settings
            WHERE user_id = $1
            "#,
        )
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to load family reminder settings"))?;
        if let Some(row) = row {
            let consent_granted: bool = row.get("consent_granted");
            Ok(ImanJourneyFamilyReminder {
                consent_granted,
                reminder_text: if consent_granted {
                    row.get("reminder_text")
                } else {
                    None
                },
                notify_family: consent_granted && row.get::<bool, _>("notify_family"),
            })
        } else {
            Ok(ImanJourneyFamilyReminder {
                consent_granted: false,
                reminder_text: None,
                notify_family: false,
            })
        }
    }

    async fn get_reminder_with_evidence(
        &self,
        user_id: Uuid,
        date: NaiveDate,
        privacy: &ImanJourneyPrivacySettings,
    ) -> Result<ImanJourneyReligiousReminder, ApiError> {
        if !privacy.reminders_enabled {
            return Ok(ImanJourneyReligiousReminder {
                text: None,
                confidence_score: 0.0,
                evidence_bundle: Vec::new(),
                safe_fallback: Some(ImanJourneySafeFallback {
                    reason: "reminders_disabled".to_string(),
                    message: "Religious reminders are disabled by your privacy settings."
                        .to_string(),
                }),
            });
        }
        let row = sqlx::query(
            r#"
            SELECT reminder_text, confidence_score, evidence_bundle
            FROM public.iman_journey_evidence_bundles
            WHERE user_id = $1 AND journey_date = $2
            "#,
        )
        .bind(user_id)
        .bind(date)
        .fetch_optional(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to load reminder evidence"))?;
        let Some(row) = row else {
            return Ok(missing_evidence_fallback("missing_evidence"));
        };
        let confidence_score: f64 = row.get("confidence_score");
        let evidence_json: Value = row.get("evidence_bundle");
        let evidence_bundle: Vec<ImanJourneyEvidenceItem> =
            serde_json::from_value::<Vec<ImanJourneyEvidenceItem>>(evidence_json)
            .unwrap_or_default()
            .into_iter()
            .filter(|item| {
                !item.source_reference.trim().is_empty() && !item.citation.trim().is_empty()
            })
            .collect();
        let reminder_text: Option<String> = row.get("reminder_text");
        if confidence_score >= 0.7
            && !evidence_bundle.is_empty()
            && reminder_text
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .is_some()
        {
            Ok(ImanJourneyReligiousReminder {
                text: reminder_text,
                confidence_score,
                evidence_bundle,
                safe_fallback: None,
            })
        } else {
            Ok(missing_evidence_fallback("insufficient_evidence"))
        }
    }
}

fn missing_evidence_fallback(reason: &str) -> ImanJourneyReligiousReminder {
    ImanJourneyReligiousReminder {
        text: None,
        confidence_score: 0.0,
        evidence_bundle: Vec::new(),
        safe_fallback: Some(ImanJourneySafeFallback {
            reason: reason.to_string(),
            message:
                "Verified evidence is not available right now. Please consult a trusted scholar."
                    .to_string(),
        }),
    }
}

fn parse_or_today(raw: Option<&str>) -> Result<NaiveDate, ApiError> {
    match raw {
        Some(value) if !value.trim().is_empty() => NaiveDate::parse_from_str(value, "%Y-%m-%d")
            .map_err(|_| ApiError::bad_request("journey_date must be YYYY-MM-DD")),
        _ => Ok(today_utc_date()),
    }
}

fn today_utc_date() -> NaiveDate {
    Utc::now().date_naive()
}
