use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};
use sqlx::{PgPool, Row};
use uuid::Uuid;

use crate::error::ApiError;
use crate::services::auth::{issue_jwt, session_token_hash, validate_jwt};

#[derive(Clone)]
pub struct Phase2Repository {
    pool: PgPool,
}

impl Phase2Repository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    pub fn pool(&self) -> &PgPool {
        &self.pool
    }

    pub async fn register_user(
        &self,
        mut request: RegisterUserRequest,
    ) -> Result<RegisterUserResponse, ApiError> {
        if request.provider.trim().is_empty() {
            request.provider = "password".to_string();
        }
        request.email = request.email.trim().to_ascii_lowercase();
        validate_email(&request.email)?;
        if request.password.is_some() {
            let existing_user = sqlx::query_scalar::<_, Uuid>(
                "SELECT id FROM public.users WHERE lower(email) = lower($1) LIMIT 1",
            )
            .bind(&request.email)
            .fetch_optional(&self.pool)
            .await
            .map_err(|_| ApiError::internal("failed to check duplicate email"))?;
            if existing_user.is_some() {
                return Err(ApiError::conflict("email is already registered"));
            }
        }
        if request.provider_user_id.trim().is_empty() {
            request.provider_user_id = request.email.trim().to_ascii_lowercase();
        }
        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|_| ApiError::internal("failed to begin auth transaction"))?;

        let user_row = sqlx::query(
            r#"
            INSERT INTO public.users (pub_key, email, auth_provider, is_active)
            VALUES ($1, $2, $3, true)
            ON CONFLICT (email)
            DO NOTHING
            RETURNING id, email, pub_key, auth_provider, created_at::text AS created_at, updated_at::text AS updated_at
            "#,
        )
        .bind(&request.pub_key)
        .bind(&request.email)
        .bind(&request.provider)
        .fetch_one(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to insert user"))?;

        let user_id: Uuid = user_row.get("id");

        let identity_row = sqlx::query(
            r#"
            INSERT INTO public.auth_identities (
                user_id,
                provider,
                provider_user_id,
                provider_email,
                email_verified_at,
                last_login_at,
                metadata
            )
            VALUES ($1, $2, $3, $4, $5, now(), $6)
            ON CONFLICT (provider, provider_user_id)
            DO UPDATE SET
                user_id = EXCLUDED.user_id,
                provider_email = EXCLUDED.provider_email,
                email_verified_at = EXCLUDED.email_verified_at,
                last_login_at = now(),
                metadata = EXCLUDED.metadata,
                updated_at = now()
            RETURNING id
            "#,
        )
        .bind(user_id)
        .bind(&request.provider)
        .bind(&request.provider_user_id)
        .bind(&request.provider_email)
        .bind(request.email_verified_at)
        .bind(
            request
                .metadata
                .clone()
                .unwrap_or_else(|| serde_json::json!({})),
        )
        .fetch_one(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to upsert auth identity"))?;

        if let Some(password) = request.password.as_deref() {
            validate_password(password)?;
            let password_hash = password_hash(password)?;
            sqlx::query(
                r#"
                INSERT INTO public.password_credentials (
                    user_id, password_hash, password_salt, password_version
                )
                VALUES ($1, $2, $3, 'argon2id-v1')
                ON CONFLICT (user_id)
                DO UPDATE SET
                    password_hash = EXCLUDED.password_hash,
                    password_salt = EXCLUDED.password_salt,
                    password_version = EXCLUDED.password_version,
                    updated_at = now()
                "#,
            )
            .bind(user_id)
            .bind(password_hash)
            .bind("argon2id")
            .execute(&mut *tx)
            .await
            .map_err(|_| ApiError::internal("failed to store password credential"))?;
        }

        tx.commit()
            .await
            .map_err(|_| ApiError::internal("failed to commit auth transaction"))?;

        let mut response = RegisterUserResponse {
            user_id,
            identity_id: identity_row.get("id"),
            email: user_row.get("email"),
            pub_key: user_row.get("pub_key"),
            auth_provider: user_row.get("auth_provider"),
            created_at: user_row.get("created_at"),
            updated_at: user_row.get("updated_at"),
            access_token: None,
            refresh_token: None,
        };

        if request.password.is_some() {
            let issued = self
                .issue_session_tokens(user_id, None, Some("password-register"))
                .await?;
            response.access_token = Some(issued.access_token);
            response.refresh_token = Some(issued.refresh_token);
        }

        Ok(response)
    }

    pub async fn create_session(
        &self,
        request: CreateSessionRequest,
    ) -> Result<CreateSessionResponse, ApiError> {
        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|_| ApiError::internal("failed to begin session transaction"))?;

        let session_row = sqlx::query(
            r#"
            INSERT INTO public.auth_sessions (
                user_id,
                session_token_hash,
                ip_address,
                user_agent,
                expires_at,
                last_seen_at
            )
            VALUES ($1, $2, $3::inet, $4, $5, now())
            RETURNING id, created_at::text AS created_at
            "#,
        )
        .bind(request.user_id)
        .bind(&request.session_token_hash)
        .bind(&request.ip_address)
        .bind(&request.user_agent)
        .bind(request.expires_at)
        .fetch_one(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to create auth session"))?;

        let session_id: Uuid = session_row.get("id");

        let refresh_row = sqlx::query(
            r#"
            INSERT INTO public.auth_refresh_tokens (
                session_id,
                user_id,
                refresh_token_hash,
                expires_at
            )
            VALUES ($1, $2, $3, $4)
            RETURNING id, created_at::text AS created_at
            "#,
        )
        .bind(session_id)
        .bind(request.user_id)
        .bind(&request.refresh_token_hash)
        .bind(request.refresh_expires_at)
        .fetch_one(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to create refresh token"))?;

        tx.commit()
            .await
            .map_err(|_| ApiError::internal("failed to commit session transaction"))?;

        Ok(CreateSessionResponse {
            session_id,
            refresh_token_id: refresh_row.get("id"),
            session_created_at: session_row.get("created_at"),
            refresh_created_at: refresh_row.get("created_at"),
        })
    }

    pub async fn login_password(&self, request: LoginRequest) -> Result<LoginResponse, ApiError> {
        let row = sqlx::query(
            r#"
            SELECT
                users.id AS user_id,
                users.email,
                credentials.password_hash,
                credentials.password_salt
            FROM public.users
            JOIN public.password_credentials credentials
              ON credentials.user_id = users.id
            WHERE lower(users.email) = lower($1)
              AND users.is_active = true
            LIMIT 1
            "#,
        )
        .bind(request.email.trim())
        .fetch_optional(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to load password credential"))?;

        let Some(row) = row else {
            return Err(ApiError::unauthorized("invalid email or password"));
        };

        let expected: String = row.get("password_hash");
        if !verify_password(&request.password, &expected)? {
            return Err(ApiError::unauthorized("invalid email or password"));
        }

        let user_id: Uuid = row.get("user_id");
        let issued = self
            .issue_session_tokens(
                user_id,
                request.ip_address.as_deref(),
                Some("password-login"),
            )
            .await?;

        Ok(LoginResponse {
            user_id,
            email: row.get("email"),
            access_token: issued.access_token,
            refresh_token: issued.refresh_token,
            expires_at: issued.expires_at,
        })
    }

    pub async fn refresh_session(
        &self,
        request: RefreshTokenRequest,
    ) -> Result<LoginResponse, ApiError> {
        let refresh_token = request.refresh_token.trim();
        if refresh_token.is_empty() {
            return Err(ApiError::unauthorized("refresh_token is required"));
        }
        let jwt_user_id = validate_jwt(refresh_token)?;
        let refresh_hash = session_token_hash(refresh_token);

        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|_| ApiError::internal("failed to begin refresh transaction"))?;

        let refresh_row = sqlx::query(
            r#"
            SELECT rt.id, rt.user_id, u.email
            FROM public.auth_refresh_tokens rt
            JOIN public.users u ON u.id = rt.user_id
            WHERE rt.refresh_token_hash = $1
              AND rt.expires_at > now()
              AND rt.used_at IS NULL
              AND rt.revoked_at IS NULL
              AND u.is_active = true
            FOR UPDATE
            "#,
        )
        .bind(&refresh_hash)
        .fetch_optional(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to load refresh token"))?;

        let Some(refresh_row) = refresh_row else {
            return Err(ApiError::unauthorized("invalid or expired refresh token"));
        };

        let refresh_user_id: Uuid = refresh_row.get("user_id");
        if refresh_user_id != jwt_user_id {
            return Err(ApiError::unauthorized("refresh token subject mismatch"));
        }

        let refresh_id: Uuid = refresh_row.get("id");
        sqlx::query(
            "UPDATE public.auth_refresh_tokens SET used_at = now(), revoked_at = now() WHERE id = $1",
        )
        .bind(refresh_id)
        .execute(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to rotate refresh token"))?;

        tx.commit()
            .await
            .map_err(|_| ApiError::internal("failed to commit refresh transaction"))?;

        let issued = self
            .issue_session_tokens(refresh_user_id, None, Some("refresh-token"))
            .await?;

        Ok(LoginResponse {
            user_id: refresh_user_id,
            email: refresh_row.get("email"),
            access_token: issued.access_token,
            refresh_token: issued.refresh_token,
            expires_at: issued.expires_at,
        })
    }

    pub async fn get_user_summary(&self, user_id: Uuid) -> Result<UserSummary, ApiError> {
        let row = sqlx::query(
            r#"
            SELECT id, email, auth_provider, is_active, created_at::text AS created_at
            FROM public.users
            WHERE id = $1 AND is_active = true
            "#,
        )
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to load current user"))?
        .ok_or_else(|| ApiError::not_found("user not found"))?;

        Ok(UserSummary {
            user_id: row.get("id"),
            email: row.get("email"),
            auth_provider: row.get("auth_provider"),
            created_at: row.get("created_at"),
        })
    }

    async fn issue_session_tokens(
        &self,
        user_id: Uuid,
        ip_address: Option<&str>,
        user_agent: Option<&str>,
    ) -> Result<IssuedTokens, ApiError> {
        let (access_token, expires_at) = issue_jwt(user_id, 12 * 60 * 60)?;
        let (refresh_token, refresh_expires_at) = issue_jwt(user_id, 30 * 24 * 60 * 60)?;
        self.create_session(CreateSessionRequest {
            user_id,
            session_token_hash: token_hash(&access_token),
            refresh_token_hash: token_hash(&refresh_token),
            expires_at,
            refresh_expires_at,
            ip_address: Some(ip_address.unwrap_or("127.0.0.1").to_string()),
            user_agent: Some(user_agent.unwrap_or("sakina-api").to_string()),
        })
        .await?;

        Ok(IssuedTokens {
            access_token,
            refresh_token,
            expires_at,
        })
    }

    pub async fn upsert_profile(
        &self,
        request: UpsertProfileRequest,
    ) -> Result<UpsertProfileResponse, ApiError> {
        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|_| ApiError::internal("failed to begin profile transaction"))?;

        let profile_row = sqlx::query(
            r#"
            INSERT INTO public.user_profiles (
                user_id, full_name, display_name, timezone, madhhab_preference, metadata
            )
            VALUES ($1, $2, $3, $4, $5, COALESCE($6, '{}'::jsonb))
            ON CONFLICT (user_id)
            DO UPDATE SET
                full_name = EXCLUDED.full_name,
                display_name = EXCLUDED.display_name,
                timezone = EXCLUDED.timezone,
                madhhab_preference = EXCLUDED.madhhab_preference,
                metadata = EXCLUDED.metadata,
                updated_at = now()
            RETURNING id
            "#,
        )
        .bind(request.user_id)
        .bind(&request.full_name)
        .bind(&request.display_name)
        .bind(&request.timezone)
        .bind(&request.madhhab_preference)
        .bind(request.metadata.unwrap_or_else(|| serde_json::json!({})))
        .fetch_one(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to upsert user profile"))?;

        sqlx::query(
            r#"
            INSERT INTO public.language_preferences (
                user_id, ui_language, content_language, transliteration_enabled
            )
            VALUES ($1, $2, $3, $4)
            ON CONFLICT (user_id)
            DO UPDATE SET
                ui_language = EXCLUDED.ui_language,
                content_language = EXCLUDED.content_language,
                transliteration_enabled = EXCLUDED.transliteration_enabled,
                updated_at = now()
            "#,
        )
        .bind(request.user_id)
        .bind(&request.ui_language)
        .bind(&request.content_language)
        .bind(request.transliteration_enabled)
        .execute(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to upsert language preferences"))?;

        sqlx::query(
            r#"
            INSERT INTO public.privacy_preferences (
                user_id, profile_visibility, data_export_allowed, analytics_opt_in
            )
            VALUES ($1, $2, $3, $4)
            ON CONFLICT (user_id)
            DO UPDATE SET
                profile_visibility = EXCLUDED.profile_visibility,
                data_export_allowed = EXCLUDED.data_export_allowed,
                analytics_opt_in = EXCLUDED.analytics_opt_in,
                updated_at = now()
            "#,
        )
        .bind(request.user_id)
        .bind(&request.profile_visibility)
        .bind(request.data_export_allowed)
        .bind(request.analytics_opt_in)
        .execute(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to upsert privacy preferences"))?;

        sqlx::query(
            r#"
            INSERT INTO public.accessibility_preferences (
                user_id, text_scale, high_contrast_enabled, reduced_motion_enabled, screen_reader_optimized
            )
            VALUES ($1, $2, $3, $4, $5)
            ON CONFLICT (user_id)
            DO UPDATE SET
                text_scale = EXCLUDED.text_scale,
                high_contrast_enabled = EXCLUDED.high_contrast_enabled,
                reduced_motion_enabled = EXCLUDED.reduced_motion_enabled,
                screen_reader_optimized = EXCLUDED.screen_reader_optimized,
                updated_at = now()
            "#,
        )
        .bind(request.user_id)
        .bind(request.text_scale)
        .bind(request.high_contrast_enabled)
        .bind(request.reduced_motion_enabled)
        .bind(request.screen_reader_optimized)
        .execute(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to upsert accessibility preferences"))?;

        sqlx::query(
            r#"
            INSERT INTO public.notification_preferences (
                user_id, in_app_enabled, email_enabled, push_enabled
            )
            VALUES ($1, $2, $3, $4)
            ON CONFLICT (user_id)
            DO UPDATE SET
                in_app_enabled = EXCLUDED.in_app_enabled,
                email_enabled = EXCLUDED.email_enabled,
                push_enabled = EXCLUDED.push_enabled,
                updated_at = now()
            "#,
        )
        .bind(request.user_id)
        .bind(request.in_app_enabled)
        .bind(request.email_enabled)
        .bind(request.push_enabled)
        .execute(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to upsert notification preferences"))?;

        tx.commit()
            .await
            .map_err(|_| ApiError::internal("failed to commit profile transaction"))?;

        Ok(UpsertProfileResponse {
            profile_id: profile_row.get("id"),
            user_id: request.user_id,
        })
    }

    pub async fn create_family_profile(
        &self,
        request: CreateFamilyProfileRequest,
    ) -> Result<CreateFamilyProfileResponse, ApiError> {
        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|_| ApiError::internal("failed to begin family transaction"))?;

        let family_row = sqlx::query(
            r#"
            INSERT INTO public.family_profiles (
                user_id, family_name, household_size, location_country_code, metadata
            )
            VALUES ($1, $2, $3, $4, COALESCE($5, '{}'::jsonb))
            RETURNING id
            "#,
        )
        .bind(request.user_id)
        .bind(&request.family_name)
        .bind(request.household_size)
        .bind(&request.location_country_code)
        .bind(request.metadata.unwrap_or_else(|| serde_json::json!({})))
        .fetch_one(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to create family profile"))?;

        let family_profile_id: Uuid = family_row.get("id");
        let mut child_ids = Vec::new();
        for child in request.children {
            let child_row = sqlx::query(
                r#"
                INSERT INTO public.child_profiles (
                    family_profile_id, user_id, preferred_name, birth_year, learning_level, notes, metadata
                )
                VALUES ($1, $2, $3, $4, $5, $6, COALESCE($7, '{}'::jsonb))
                RETURNING id
                "#,
            )
            .bind(family_profile_id)
            .bind(child.user_id)
            .bind(&child.preferred_name)
            .bind(child.birth_year)
            .bind(&child.learning_level)
            .bind(&child.notes)
            .bind(child.metadata.unwrap_or_else(|| serde_json::json!({})))
            .fetch_one(&mut *tx)
            .await
            .map_err(|_| ApiError::internal("failed to create child profile"))?;
            child_ids.push(child_row.get("id"));
        }

        tx.commit()
            .await
            .map_err(|_| ApiError::internal("failed to commit family transaction"))?;

        Ok(CreateFamilyProfileResponse {
            family_profile_id,
            child_ids,
        })
    }

    pub async fn activate_subscription(
        &self,
        request: ActivateSubscriptionRequest,
    ) -> Result<ActivateSubscriptionResponse, ApiError> {
        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|_| ApiError::internal("failed to begin subscription transaction"))?;

        let provider_row = sqlx::query(
            r#"
            INSERT INTO public.payment_providers (provider_key, display_name, provider_status)
            VALUES ($1, $2, 'active')
            ON CONFLICT (provider_key)
            DO UPDATE SET updated_at = now()
            RETURNING id
            "#,
        )
        .bind(&request.provider_key)
        .bind(&request.provider_display_name)
        .fetch_one(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to upsert payment provider"))?;
        let provider_id: Uuid = provider_row.get("id");

        let plan_row = sqlx::query(
            r#"
            INSERT INTO public.subscription_plans (
                provider_id, plan_key, plan_name, billing_interval, currency_code, amount_minor, is_active
            )
            VALUES ($1, $2, $3, $4, $5, $6, true)
            ON CONFLICT (plan_key)
            DO UPDATE SET
                provider_id = EXCLUDED.provider_id,
                plan_name = EXCLUDED.plan_name,
                billing_interval = EXCLUDED.billing_interval,
                currency_code = EXCLUDED.currency_code,
                amount_minor = EXCLUDED.amount_minor,
                updated_at = now()
            RETURNING id
            "#,
        )
        .bind(provider_id)
        .bind(&request.plan_key)
        .bind(&request.plan_name)
        .bind(&request.billing_interval)
        .bind(&request.currency_code)
        .bind(request.amount_minor)
        .fetch_one(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to upsert subscription plan"))?;
        let plan_id: Uuid = plan_row.get("id");

        let customer_row = sqlx::query(
            r#"
            INSERT INTO public.payment_customers (
                user_id, provider_id, provider_customer_ref, customer_status
            )
            VALUES ($1, $2, $3, 'active')
            ON CONFLICT (user_id, provider_id)
            DO UPDATE SET
                provider_customer_ref = EXCLUDED.provider_customer_ref,
                updated_at = now()
            RETURNING id
            "#,
        )
        .bind(request.user_id)
        .bind(provider_id)
        .bind(&request.provider_customer_ref)
        .fetch_one(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to upsert payment customer"))?;
        let payment_customer_id: Uuid = customer_row.get("id");

        let subscription_row = sqlx::query(
            r#"
            INSERT INTO public.user_subscriptions (
                user_id,
                plan_id,
                payment_customer_id,
                provider_subscription_ref,
                subscription_status,
                started_at,
                current_period_start,
                current_period_end
            )
            VALUES ($1, $2, $3, $4, 'active', now(), $5, $6)
            ON CONFLICT (provider_subscription_ref)
            DO UPDATE SET
                plan_id = EXCLUDED.plan_id,
                payment_customer_id = EXCLUDED.payment_customer_id,
                current_period_start = EXCLUDED.current_period_start,
                current_period_end = EXCLUDED.current_period_end,
                subscription_status = 'active',
                updated_at = now()
            RETURNING id
            "#,
        )
        .bind(request.user_id)
        .bind(plan_id)
        .bind(payment_customer_id)
        .bind(&request.provider_subscription_ref)
        .bind(request.current_period_start)
        .bind(request.current_period_end)
        .fetch_one(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to upsert user subscription"))?;
        let subscription_id: Uuid = subscription_row.get("id");

        let invoice_row = sqlx::query(
            r#"
            INSERT INTO public.invoices (
                user_id,
                subscription_id,
                provider_id,
                provider_invoice_ref,
                invoice_status,
                currency_code,
                subtotal_minor,
                total_minor
            )
            VALUES ($1, $2, $3, $4, 'paid', $5, $6, $6)
            ON CONFLICT (provider_invoice_ref)
            DO UPDATE SET
                invoice_status = EXCLUDED.invoice_status,
                total_minor = EXCLUDED.total_minor,
                updated_at = now()
            RETURNING id
            "#,
        )
        .bind(request.user_id)
        .bind(subscription_id)
        .bind(provider_id)
        .bind(&request.provider_invoice_ref)
        .bind(&request.currency_code)
        .bind(request.amount_minor)
        .fetch_one(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to upsert invoice"))?;
        let invoice_id: Uuid = invoice_row.get("id");

        sqlx::query(
            r#"
            INSERT INTO public.payment_transactions (
                user_id,
                provider_id,
                subscription_id,
                invoice_id,
                provider_transaction_ref,
                transaction_type,
                transaction_status,
                currency_code,
                amount_minor,
                processed_at
            )
            VALUES ($1, $2, $3, $4, $5, 'charge', 'succeeded', $6, $7, now())
            ON CONFLICT (provider_transaction_ref)
            DO UPDATE SET
                transaction_status = EXCLUDED.transaction_status,
                amount_minor = EXCLUDED.amount_minor,
                updated_at = now()
            "#,
        )
        .bind(request.user_id)
        .bind(provider_id)
        .bind(subscription_id)
        .bind(invoice_id)
        .bind(&request.provider_transaction_ref)
        .bind(&request.currency_code)
        .bind(request.amount_minor)
        .execute(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to upsert payment transaction"))?;

        for entitlement_key in request.entitlement_keys {
            let entitlement_row = sqlx::query(
                r#"
                INSERT INTO public.entitlements (
                    entitlement_key, entitlement_name, entitlement_scope, is_active
                )
                VALUES ($1, $2, 'module', true)
                ON CONFLICT (entitlement_key)
                DO UPDATE SET
                    entitlement_name = EXCLUDED.entitlement_name,
                    is_active = true,
                    updated_at = now()
                RETURNING id
                "#,
            )
            .bind(&entitlement_key)
            .bind(format!("{} entitlement", entitlement_key))
            .fetch_one(&mut *tx)
            .await
            .map_err(|_| ApiError::internal("failed to upsert entitlement"))?;
            let entitlement_id: Uuid = entitlement_row.get("id");

            sqlx::query(
                r#"
                INSERT INTO public.user_entitlements (
                    user_id, entitlement_id, subscription_id, granted_by
                )
                VALUES ($1, $2, $3, 'phase2_backend')
                ON CONFLICT (user_id, entitlement_id)
                DO UPDATE SET
                    subscription_id = EXCLUDED.subscription_id,
                    revoked_at = NULL,
                    updated_at = now()
                "#,
            )
            .bind(request.user_id)
            .bind(entitlement_id)
            .bind(subscription_id)
            .execute(&mut *tx)
            .await
            .map_err(|_| ApiError::internal("failed to upsert user entitlement"))?;
        }

        tx.commit()
            .await
            .map_err(|_| ApiError::internal("failed to commit subscription transaction"))?;

        Ok(ActivateSubscriptionResponse {
            user_id: request.user_id,
            subscription_id,
            payment_customer_id,
            plan_id,
            invoice_id,
        })
    }

    pub async fn list_user_entitlements(
        &self,
        user_id: Uuid,
    ) -> Result<Vec<UserEntitlementView>, ApiError> {
        let rows = sqlx::query(
            r#"
            SELECT
                ue.id,
                e.entitlement_key,
                ue.granted_at::text AS granted_at,
                ue.expires_at::text AS expires_at
            FROM public.user_entitlements ue
            JOIN public.entitlements e ON e.id = ue.entitlement_id
            WHERE ue.user_id = $1
              AND ue.revoked_at IS NULL
            ORDER BY ue.granted_at DESC
            "#,
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to list user entitlements"))?;

        Ok(rows
            .into_iter()
            .map(|row| UserEntitlementView {
                id: row.get("id"),
                entitlement_key: row.get("entitlement_key"),
                granted_at: row.get("granted_at"),
                expires_at: row.get("expires_at"),
            })
            .collect())
    }

    pub async fn create_chat_feedback(
        &self,
        request: CreateChatFeedbackRequest,
    ) -> Result<Uuid, ApiError> {
        let feedback_id = sqlx::query_scalar(
            r#"
            INSERT INTO public.user_chat_feedback (
                user_id, conversation_id, message_id, feedback_type, feedback_score, feedback_comment
            )
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING id
            "#,
        )
        .bind(request.user_id)
        .bind(request.conversation_id)
        .bind(request.message_id)
        .bind(&request.feedback_type)
        .bind(request.feedback_score)
        .bind(&request.feedback_comment)
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to create chat feedback"))?;
        Ok(feedback_id)
    }

    pub async fn report_answer(&self, request: ReportAnswerRequest) -> Result<Uuid, ApiError> {
        let report_id = sqlx::query_scalar(
            r#"
            INSERT INTO public.user_reported_answers (
                user_id, message_id, report_reason, report_details, report_status
            )
            VALUES ($1, $2, $3, $4, 'open')
            RETURNING id
            "#,
        )
        .bind(request.user_id)
        .bind(request.message_id)
        .bind(&request.report_reason)
        .bind(&request.report_details)
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to create reported answer"))?;
        Ok(report_id)
    }

    pub async fn list_approved_rag_sources(
        &self,
        module: &str,
    ) -> Result<Vec<ApprovedRagSource>, ApiError> {
        let rows = sqlx::query(
            r#"
            SELECT
                s.id AS source_id,
                s.source_key,
                s.source_type,
                s.language,
                d.id AS document_id,
                d.document_key,
                c.id AS chunk_id,
                c.chunk_key,
                c.citation_text
            FROM sakina_ai.islamic_sources s
            JOIN sakina_ai.islamic_documents d ON d.source_id = s.id
            JOIN sakina_ai.islamic_chunks c ON c.document_id = d.id
            WHERE s.source_status = 'approved'
              AND s.review_status IN ('verified', 'approved')
              AND d.source_status = 'approved'
              AND d.review_status IN ('verified', 'approved')
              AND c.source_status = 'approved'
              AND c.review_status IN ('verified', 'approved')
              AND s.source_type = $1
            ORDER BY s.created_at DESC, d.created_at DESC, c.chunk_index ASC
            LIMIT 50
            "#,
        )
        .bind(module)
        .fetch_all(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to list approved rag sources"))?;

        Ok(rows
            .into_iter()
            .map(|row| ApprovedRagSource {
                source_id: row.get("source_id"),
                source_key: row.get("source_key"),
                source_type: row.get("source_type"),
                language: row.get("language"),
                document_id: row.get("document_id"),
                document_key: row.get("document_key"),
                chunk_id: row.get("chunk_id"),
                chunk_key: row.get("chunk_key"),
                citation_text: row.get("citation_text"),
            })
            .collect())
    }

    pub async fn log_rag_retrieval(
        &self,
        request: LogRagRetrievalRequest,
    ) -> Result<Uuid, ApiError> {
        let id = sqlx::query_scalar(
            r#"
            INSERT INTO sakina_ai.rag_retrieval_audit (
                request_id,
                user_id,
                conversation_id,
                query_text,
                selected_module,
                language,
                retrieval_status,
                citation,
                confidence,
                decision_reason
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            RETURNING id
            "#,
        )
        .bind(request.request_id)
        .bind(request.user_id)
        .bind(request.conversation_id)
        .bind(&request.query_text)
        .bind(&request.selected_module)
        .bind(&request.language)
        .bind(&request.retrieval_status)
        .bind(&request.citation)
        .bind(request.confidence)
        .bind(&request.decision_reason)
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to log rag retrieval audit"))?;
        Ok(id)
    }

    pub async fn log_citation_event(
        &self,
        request: LogCitationEventRequest,
    ) -> Result<Uuid, ApiError> {
        let id = sqlx::query_scalar(
            r#"
            INSERT INTO sakina_ai.citation_verification_events (
                request_id,
                retrieval_audit_id,
                citation_text,
                verification_status,
                verification_reason,
                verified_by
            )
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING id
            "#,
        )
        .bind(request.request_id)
        .bind(request.retrieval_audit_id)
        .bind(&request.citation_text)
        .bind(&request.verification_status)
        .bind(&request.verification_reason)
        .bind(&request.verified_by)
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to log citation event"))?;
        Ok(id)
    }

    pub async fn log_safety_classification(
        &self,
        request: LogSafetyClassificationRequest,
    ) -> Result<Uuid, ApiError> {
        let id = sqlx::query_scalar(
            r#"
            INSERT INTO sakina_ai.safety_classifications (
                request_id, user_id, safety_level, islamic_sensitivity, classifier_version, classifier_output
            )
            VALUES ($1, $2, $3, $4, $5, COALESCE($6, '{}'::jsonb))
            RETURNING id
            "#,
        )
        .bind(request.request_id)
        .bind(request.user_id)
        .bind(&request.safety_level)
        .bind(&request.islamic_sensitivity)
        .bind(&request.classifier_version)
        .bind(request.classifier_output.unwrap_or_else(|| serde_json::json!({})))
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to log safety classification"))?;
        Ok(id)
    }

    pub async fn log_mastermind_decision(
        &self,
        request: LogMastermindDecisionRequest,
    ) -> Result<Uuid, ApiError> {
        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|_| ApiError::internal("failed to begin mastermind transaction"))?;

        let request_id = request.request_id;
        let user_id = request.user_id;
        let decision_id = sqlx::query_scalar(
            r#"
            INSERT INTO sakina_ai.mastermind_decisions (
                request_id,
                user_id,
                conversation_id,
                message_id,
                language,
                intent,
                selected_module,
                safety_level,
                islamic_sensitivity,
                rag_allowed,
                retrieval_required,
                citations_required,
                citation_sufficiency,
                answer_allowed,
                scholar_review_required,
                final_response_policy,
                user_subscription_tier,
                entitlement_allowed,
                reason,
                user_message,
                decision_payload
            )
            VALUES (
                $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, COALESCE($21, '{}'::jsonb)
            )
            RETURNING id
            "#,
        )
        .bind(request_id)
        .bind(user_id)
        .bind(request.conversation_id)
        .bind(request.message_id)
        .bind(&request.language)
        .bind(&request.intent)
        .bind(&request.selected_module)
        .bind(&request.safety_level)
        .bind(&request.islamic_sensitivity)
        .bind(request.rag_allowed)
        .bind(request.retrieval_required)
        .bind(request.citations_required)
        .bind(request.citation_sufficiency)
        .bind(request.answer_allowed)
        .bind(request.scholar_review_required)
        .bind(&request.final_response_policy)
        .bind(&request.user_subscription_tier)
        .bind(request.entitlement_allowed)
        .bind(&request.reason)
        .bind(&request.user_message)
        .bind(request.decision_payload.unwrap_or_else(|| serde_json::json!({})))
        .fetch_one(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to log mastermind decision"))?;

        sqlx::query(
            r#"
            INSERT INTO sakina_ai.entitlement_decisions (
                request_id, user_id, subscription_tier, entitlement_allowed, policy_version, reason, decision_payload
            )
            VALUES ($1, $2, $3, $4, 'v1', $5, COALESCE($6, '{}'::jsonb))
            "#,
        )
        .bind(request_id)
        .bind(user_id)
        .bind(&request.user_subscription_tier)
        .bind(request.entitlement_allowed)
        .bind(&request.reason)
        .bind(serde_json::json!({ "source": "phase2_backend" }))
        .execute(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to log entitlement decision"))?;

        tx.commit()
            .await
            .map_err(|_| ApiError::internal("failed to commit mastermind transaction"))?;

        Ok(decision_id)
    }

    pub async fn enqueue_scholar_review(
        &self,
        request: EnqueueScholarReviewRequest,
    ) -> Result<Uuid, ApiError> {
        let id = sqlx::query_scalar(
            r#"
            INSERT INTO sakina_ai.scholar_review_queue (
                request_id,
                mastermind_decision_id,
                conversation_id,
                priority,
                review_status,
                reviewer_notes
            )
            VALUES ($1, $2, $3, $4, 'pending', $5)
            RETURNING id
            "#,
        )
        .bind(request.request_id)
        .bind(request.mastermind_decision_id)
        .bind(request.conversation_id)
        .bind(&request.priority)
        .bind(&request.reviewer_notes)
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to enqueue scholar review"))?;
        Ok(id)
    }

    pub async fn log_wasm_verification(
        &self,
        request: LogWasmVerificationRequest,
    ) -> Result<Uuid, ApiError> {
        let id = sqlx::query_scalar(
            r#"
            INSERT INTO sakina_ai.wasm_verification_events (
                request_id,
                module_name,
                decision_type,
                input_hash,
                output_decision,
                policy_version,
                runtime_mode
            )
            VALUES ($1, $2, $3, $4, COALESCE($5, '{}'::jsonb), $6, $7)
            RETURNING id
            "#,
        )
        .bind(request.request_id)
        .bind(&request.module_name)
        .bind(&request.decision_type)
        .bind(&request.input_hash)
        .bind(
            request
                .output_decision
                .unwrap_or_else(|| serde_json::json!({})),
        )
        .bind(&request.policy_version)
        .bind(&request.runtime_mode)
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to log wasm verification event"))?;
        Ok(id)
    }

    pub async fn upsert_admin_role(
        &self,
        request: UpsertAdminRoleRequest,
    ) -> Result<UpsertAdminRoleResponse, ApiError> {
        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|_| ApiError::internal("failed to begin admin transaction"))?;

        let role_row = sqlx::query(
            r#"
            INSERT INTO public.admin_roles (role_key, role_name, is_system)
            VALUES ($1, $2, false)
            ON CONFLICT (role_key)
            DO UPDATE SET
                role_name = EXCLUDED.role_name,
                updated_at = now()
            RETURNING id
            "#,
        )
        .bind(&request.role_key)
        .bind(&request.role_name)
        .fetch_one(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to upsert admin role"))?;
        let role_id: Uuid = role_row.get("id");

        for permission_key in request.permission_keys {
            let permission_row = sqlx::query(
                r#"
                INSERT INTO public.admin_permissions (permission_key, permission_name)
                VALUES ($1, $2)
                ON CONFLICT (permission_key)
                DO UPDATE SET permission_name = EXCLUDED.permission_name
                RETURNING id
                "#,
            )
            .bind(&permission_key)
            .bind(format!("{} permission", permission_key))
            .fetch_one(&mut *tx)
            .await
            .map_err(|_| ApiError::internal("failed to upsert admin permission"))?;
            let permission_id: Uuid = permission_row.get("id");

            sqlx::query(
                r#"
                INSERT INTO public.admin_role_permissions (role_id, permission_id)
                VALUES ($1, $2)
                ON CONFLICT (role_id, permission_id)
                DO NOTHING
                "#,
            )
            .bind(role_id)
            .bind(permission_id)
            .execute(&mut *tx)
            .await
            .map_err(|_| ApiError::internal("failed to upsert role permission"))?;
        }

        tx.commit()
            .await
            .map_err(|_| ApiError::internal("failed to commit admin transaction"))?;

        Ok(UpsertAdminRoleResponse { role_id })
    }

    pub async fn log_admin_action(&self, request: LogAdminActionRequest) -> Result<Uuid, ApiError> {
        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|_| ApiError::internal("failed to begin admin action transaction"))?;

        let action_id = sqlx::query_scalar(
            r#"
            INSERT INTO public.admin_actions (
                admin_user_id, action_type, target_type, target_id, action_status, notes, metadata
            )
            VALUES ($1, $2, $3, $4, $5, $6, COALESCE($7, '{}'::jsonb))
            RETURNING id
            "#,
        )
        .bind(request.admin_user_id)
        .bind(&request.action_type)
        .bind(&request.target_type)
        .bind(&request.target_id)
        .bind(&request.action_status)
        .bind(&request.notes)
        .bind(
            request
                .metadata
                .clone()
                .unwrap_or_else(|| serde_json::json!({})),
        )
        .fetch_one(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to log admin action"))?;

        sqlx::query(
            r#"
            INSERT INTO public.admin_audit_logs (
                admin_user_id, action_key, entity_type, entity_id, new_value, request_id
            )
            VALUES ($1, $2, $3, $4, COALESCE($5, '{}'::jsonb), $6)
            "#,
        )
        .bind(request.admin_user_id)
        .bind(&request.action_type)
        .bind(&request.target_type)
        .bind(&request.target_id)
        .bind(request.metadata.unwrap_or_else(|| serde_json::json!({})))
        .bind(request.request_id.to_string())
        .execute(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to log admin audit action"))?;

        tx.commit()
            .await
            .map_err(|_| ApiError::internal("failed to commit admin action transaction"))?;

        Ok(action_id)
    }

    pub async fn create_scholar_account(
        &self,
        request: CreateScholarAccountRequest,
    ) -> Result<Uuid, ApiError> {
        let id = sqlx::query_scalar(
            r#"
            INSERT INTO public.scholar_accounts (
                user_id, scholar_slug, display_name, verified, credentials_summary, account_status
            )
            VALUES ($1, $2, $3, $4, $5, $6)
            ON CONFLICT (scholar_slug)
            DO UPDATE SET
                display_name = EXCLUDED.display_name,
                verified = EXCLUDED.verified,
                credentials_summary = EXCLUDED.credentials_summary,
                account_status = EXCLUDED.account_status,
                updated_at = now()
            RETURNING id
            "#,
        )
        .bind(request.user_id)
        .bind(&request.scholar_slug)
        .bind(&request.display_name)
        .bind(request.verified)
        .bind(&request.credentials_summary)
        .bind(&request.account_status)
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to create scholar account"))?;
        Ok(id)
    }

    pub async fn assign_scholar_review(
        &self,
        request: AssignScholarReviewRequest,
    ) -> Result<Uuid, ApiError> {
        let id = sqlx::query_scalar(
            r#"
            INSERT INTO public.scholar_review_assignments (
                scholar_account_id, scholar_review_queue_id, assignment_status, notes
            )
            VALUES ($1, $2, 'assigned', $3)
            ON CONFLICT (scholar_account_id, scholar_review_queue_id)
            DO UPDATE SET
                assignment_status = 'assigned',
                notes = EXCLUDED.notes
            RETURNING id
            "#,
        )
        .bind(request.scholar_account_id)
        .bind(request.scholar_review_queue_id)
        .bind(&request.notes)
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to assign scholar review"))?;
        Ok(id)
    }

    pub async fn list_source_approval_queue(&self) -> Result<Vec<SourceApprovalItem>, ApiError> {
        let rows = sqlx::query(
            r#"
            SELECT id, source_id, approval_status, notes, created_at::text AS created_at
            FROM public.source_approval_queue
            ORDER BY created_at DESC
            LIMIT 50
            "#,
        )
        .fetch_all(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to list source approval queue"))?;

        Ok(rows
            .into_iter()
            .map(|row| SourceApprovalItem {
                id: row.get("id"),
                source_id: row.get("source_id"),
                approval_status: row.get("approval_status"),
                notes: row.get("notes"),
                created_at: row.get("created_at"),
            })
            .collect())
    }

    pub async fn create_source_approval_item(
        &self,
        request: CreateSourceApprovalItemRequest,
    ) -> Result<Uuid, ApiError> {
        let id = sqlx::query_scalar(
            r#"
            INSERT INTO public.source_approval_queue (
                source_id, submitted_by, approval_status, notes
            )
            VALUES ($1, $2, 'pending', $3)
            RETURNING id
            "#,
        )
        .bind(request.source_id)
        .bind(request.submitted_by)
        .bind(&request.notes)
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to create source approval item"))?;
        Ok(id)
    }

    pub async fn create_notification_template(
        &self,
        request: CreateNotificationTemplateRequest,
    ) -> Result<Uuid, ApiError> {
        let id = sqlx::query_scalar(
            r#"
            INSERT INTO public.notification_templates (
                template_key, channel, subject_template, body_template, locale, is_active
            )
            VALUES ($1, $2, $3, $4, $5, true)
            ON CONFLICT (template_key)
            DO UPDATE SET
                channel = EXCLUDED.channel,
                subject_template = EXCLUDED.subject_template,
                body_template = EXCLUDED.body_template,
                locale = EXCLUDED.locale,
                updated_at = now()
            RETURNING id
            "#,
        )
        .bind(&request.template_key)
        .bind(&request.channel)
        .bind(&request.subject_template)
        .bind(&request.body_template)
        .bind(&request.locale)
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to upsert notification template"))?;
        Ok(id)
    }

    pub async fn enqueue_notification(
        &self,
        request: EnqueueNotificationRequest,
    ) -> Result<Uuid, ApiError> {
        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|_| ApiError::internal("failed to begin notification transaction"))?;

        let notification_id = sqlx::query_scalar(
            r#"
            INSERT INTO public.user_notifications (
                user_id, template_id, channel, notification_status, title, body, payload
            )
            VALUES ($1, $2, $3, 'queued', $4, $5, COALESCE($6, '{}'::jsonb))
            RETURNING id
            "#,
        )
        .bind(request.user_id)
        .bind(request.template_id)
        .bind(&request.channel)
        .bind(&request.title)
        .bind(&request.body)
        .bind(request.payload.unwrap_or_else(|| serde_json::json!({})))
        .fetch_one(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to enqueue user notification"))?;

        sqlx::query(
            r#"
            INSERT INTO public.notification_delivery_attempts (
                user_notification_id, attempt_number, delivery_status
            )
            VALUES ($1, 1, 'pending')
            "#,
        )
        .bind(notification_id)
        .execute(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to create delivery attempt"))?;

        tx.commit()
            .await
            .map_err(|_| ApiError::internal("failed to commit notification transaction"))?;
        Ok(notification_id)
    }

    pub async fn list_notifications(
        &self,
        user_id: Uuid,
    ) -> Result<Vec<UserNotificationView>, ApiError> {
        let rows = sqlx::query(
            r#"
            SELECT id, channel, notification_status, title, body, payload,
                   scheduled_at, sent_at, read_at, created_at
            FROM public.user_notifications
            WHERE user_id = $1
            ORDER BY created_at DESC
            LIMIT 50
            "#,
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to list notifications"))?;

        Ok(rows
            .into_iter()
            .map(|row| UserNotificationView {
                id: row.get("id"),
                channel: row.get("channel"),
                notification_status: row.get("notification_status"),
                title: row.get("title"),
                body: row.get("body"),
                payload: row.get("payload"),
                scheduled_at: row
                    .get::<Option<DateTime<Utc>>, _>("scheduled_at")
                    .map(|value| value.to_rfc3339()),
                sent_at: row
                    .get::<Option<DateTime<Utc>>, _>("sent_at")
                    .map(|value| value.to_rfc3339()),
                read_at: row
                    .get::<Option<DateTime<Utc>>, _>("read_at")
                    .map(|value| value.to_rfc3339()),
                created_at: row.get::<DateTime<Utc>, _>("created_at").to_rfc3339(),
            })
            .collect())
    }

    pub async fn mark_notification_read(
        &self,
        user_id: Uuid,
        notification_id: Uuid,
    ) -> Result<Option<UserNotificationView>, ApiError> {
        let row = sqlx::query(
            r#"
            UPDATE public.user_notifications
            SET read_at = COALESCE(read_at, now()),
                notification_status = 'read',
                updated_at = now()
            WHERE id = $1 AND user_id = $2
            RETURNING id, channel, notification_status, title, body, payload,
                      scheduled_at, sent_at, read_at, created_at
            "#,
        )
        .bind(notification_id)
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to mark notification read"))?;

        Ok(row.map(|row| UserNotificationView {
            id: row.get("id"),
            channel: row.get("channel"),
            notification_status: row.get("notification_status"),
            title: row.get("title"),
            body: row.get("body"),
            payload: row.get("payload"),
            scheduled_at: row
                .get::<Option<DateTime<Utc>>, _>("scheduled_at")
                .map(|value| value.to_rfc3339()),
            sent_at: row
                .get::<Option<DateTime<Utc>>, _>("sent_at")
                .map(|value| value.to_rfc3339()),
            read_at: row
                .get::<Option<DateTime<Utc>>, _>("read_at")
                .map(|value| value.to_rfc3339()),
            created_at: row.get::<DateTime<Utc>, _>("created_at").to_rfc3339(),
        }))
    }

    pub async fn upsert_device_token(
        &self,
        request: UpsertDeviceTokenRequest,
    ) -> Result<Uuid, ApiError> {
        let id = sqlx::query_scalar(
            r#"
            INSERT INTO public.device_tokens (
                user_id, platform, token_hash, app_version, last_seen_at, is_active
            )
            VALUES ($1, $2, $3, $4, now(), true)
            ON CONFLICT (token_hash)
            DO UPDATE SET
                user_id = EXCLUDED.user_id,
                platform = EXCLUDED.platform,
                app_version = EXCLUDED.app_version,
                last_seen_at = now(),
                is_active = true,
                updated_at = now()
            RETURNING id
            "#,
        )
        .bind(request.user_id)
        .bind(&request.platform)
        .bind(&request.token_hash)
        .bind(&request.app_version)
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to upsert device token"))?;
        Ok(id)
    }

    pub async fn create_support_ticket(
        &self,
        request: CreateSupportTicketRequest,
    ) -> Result<CreateSupportTicketResponse, ApiError> {
        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|_| ApiError::internal("failed to begin support transaction"))?;

        let ticket_row = sqlx::query(
            r#"
            INSERT INTO public.support_tickets (
                user_id, ticket_status, priority, category, subject
            )
            VALUES ($1, 'open', $2, $3, $4)
            RETURNING id, ticket_number
            "#,
        )
        .bind(request.user_id)
        .bind(&request.priority)
        .bind(&request.category)
        .bind(&request.subject)
        .fetch_one(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to create support ticket"))?;

        let ticket_id: Uuid = ticket_row.get("id");
        let ticket_number: i64 = ticket_row.get("ticket_number");

        let message_id = sqlx::query_scalar(
            r#"
            INSERT INTO public.support_ticket_messages (
                support_ticket_id, sender_type, sender_user_id, message_body
            )
            VALUES ($1, 'user', $2, $3)
            RETURNING id
            "#,
        )
        .bind(ticket_id)
        .bind(request.user_id)
        .bind(&request.message_body)
        .fetch_one(&mut *tx)
        .await
        .map_err(|_| ApiError::internal("failed to create support ticket message"))?;

        tx.commit()
            .await
            .map_err(|_| ApiError::internal("failed to commit support transaction"))?;

        Ok(CreateSupportTicketResponse {
            ticket_id,
            ticket_number,
            message_id,
        })
    }

    pub async fn append_support_ticket_message(
        &self,
        request: AppendSupportTicketMessageRequest,
    ) -> Result<Uuid, ApiError> {
        let id = sqlx::query_scalar(
            r#"
            INSERT INTO public.support_ticket_messages (
                support_ticket_id, sender_type, sender_user_id, message_body
            )
            VALUES ($1, $2, $3, $4)
            RETURNING id
            "#,
        )
        .bind(request.support_ticket_id)
        .bind(&request.sender_type)
        .bind(request.sender_user_id)
        .bind(&request.message_body)
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to append support ticket message"))?;
        Ok(id)
    }

    pub async fn support_ticket_owner(
        &self,
        support_ticket_id: Uuid,
    ) -> Result<Option<Uuid>, ApiError> {
        sqlx::query_scalar(
            r#"
            SELECT user_id
            FROM public.support_tickets
            WHERE id = $1
            "#,
        )
        .bind(support_ticket_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to fetch support ticket owner"))
    }

    pub async fn get_support_ticket(
        &self,
        support_ticket_id: Uuid,
    ) -> Result<SupportTicketDetail, ApiError> {
        let ticket_row = sqlx::query(
            r#"
            SELECT id, ticket_number, ticket_status, priority, category, subject, created_at::text AS created_at, updated_at::text AS updated_at
            FROM public.support_tickets
            WHERE id = $1
            "#,
        )
        .bind(support_ticket_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to fetch support ticket"))?;

        let Some(ticket_row) = ticket_row else {
            return Err(ApiError::not_found("support ticket not found"));
        };

        let message_rows = sqlx::query(
            r#"
            SELECT id, sender_type, sender_user_id, message_body, created_at::text AS created_at
            FROM public.support_ticket_messages
            WHERE support_ticket_id = $1
            ORDER BY created_at ASC
            "#,
        )
        .bind(support_ticket_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to fetch support ticket messages"))?;

        Ok(SupportTicketDetail {
            id: ticket_row.get("id"),
            ticket_number: ticket_row.get("ticket_number"),
            ticket_status: ticket_row.get("ticket_status"),
            priority: ticket_row.get("priority"),
            category: ticket_row.get("category"),
            subject: ticket_row.get("subject"),
            created_at: ticket_row.get("created_at"),
            updated_at: ticket_row.get("updated_at"),
            messages: message_rows
                .into_iter()
                .map(|row| SupportTicketMessageView {
                    id: row.get("id"),
                    sender_type: row.get("sender_type"),
                    sender_user_id: row.get("sender_user_id"),
                    message_body: row.get("message_body"),
                    created_at: row.get("created_at"),
                })
                .collect(),
        })
    }

    pub async fn get_support_ticket_owned_by(
        &self,
        support_ticket_id: Uuid,
        user_id: Uuid,
    ) -> Result<SupportTicketDetail, ApiError> {
        let ticket_row = sqlx::query(
            r#"
            SELECT id, ticket_number, ticket_status, priority, category, subject, created_at::text AS created_at, updated_at::text AS updated_at
            FROM public.support_tickets
            WHERE id = $1 AND user_id = $2
            "#,
        )
        .bind(support_ticket_id)
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to fetch support ticket"))?;

        let Some(ticket_row) = ticket_row else {
            return Err(ApiError::not_found("support ticket not found"));
        };

        let message_rows = sqlx::query(
            r#"
            SELECT id, sender_type, sender_user_id, message_body, created_at::text AS created_at
            FROM public.support_ticket_messages
            WHERE support_ticket_id = $1
            ORDER BY created_at ASC
            "#,
        )
        .bind(support_ticket_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to fetch support ticket messages"))?;

        Ok(SupportTicketDetail {
            id: ticket_row.get("id"),
            ticket_number: ticket_row.get("ticket_number"),
            ticket_status: ticket_row.get("ticket_status"),
            priority: ticket_row.get("priority"),
            category: ticket_row.get("category"),
            subject: ticket_row.get("subject"),
            created_at: ticket_row.get("created_at"),
            updated_at: ticket_row.get("updated_at"),
            messages: message_rows
                .into_iter()
                .map(|row| SupportTicketMessageView {
                    id: row.get("id"),
                    sender_type: row.get("sender_type"),
                    sender_user_id: row.get("sender_user_id"),
                    message_body: row.get("message_body"),
                    created_at: row.get("created_at"),
                })
                .collect(),
        })
    }

    pub async fn create_audit_log(&self, request: CreateAuditLogRequest) -> Result<i64, ApiError> {
        let id = sqlx::query_scalar(
            r#"
            INSERT INTO public.audit_logs (event_type, actor_type, actor_id, request_id, payload)
            VALUES ($1, $2, $3, $4, COALESCE($5, '{}'::jsonb))
            RETURNING id
            "#,
        )
        .bind(&request.event_type)
        .bind(&request.actor_type)
        .bind(&request.actor_id)
        .bind(&request.request_id)
        .bind(request.payload.unwrap_or_else(|| serde_json::json!({})))
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to create audit log"))?;
        Ok(id)
    }

    pub async fn create_security_log(
        &self,
        request: CreateSecurityLogRequest,
    ) -> Result<i64, ApiError> {
        let id = sqlx::query_scalar(
            r#"
            INSERT INTO public.security_logs (event_type, severity, user_id, ip_address, request_id, details)
            VALUES ($1, $2, $3, $4::inet, $5, COALESCE($6, '{}'::jsonb))
            RETURNING id
            "#,
        )
        .bind(&request.event_type)
        .bind(&request.severity)
        .bind(request.user_id)
        .bind(&request.ip_address)
        .bind(&request.request_id)
        .bind(request.details.unwrap_or_else(|| serde_json::json!({})))
        .fetch_one(&self.pool)
        .await
        .map_err(|_| ApiError::internal("failed to create security log"))?;
        Ok(id)
    }

    pub async fn create_app_event(&self, request: CreateEventRequest) -> Result<Uuid, ApiError> {
        self.create_event("public.app_events", request).await
    }

    pub async fn create_chat_event(&self, request: CreateEventRequest) -> Result<Uuid, ApiError> {
        self.create_event("public.chat_events", request).await
    }

    pub async fn create_rag_event(&self, request: CreateEventRequest) -> Result<Uuid, ApiError> {
        self.create_event("public.rag_events", request).await
    }

    pub async fn create_admin_event(&self, request: CreateEventRequest) -> Result<Uuid, ApiError> {
        self.create_event("public.admin_events", request).await
    }

    async fn create_event(
        &self,
        table: &str,
        request: CreateEventRequest,
    ) -> Result<Uuid, ApiError> {
        let sql = match table {
            "public.app_events" => {
                r#"
                INSERT INTO public.app_events (user_id, session_id, event_name, event_payload)
                VALUES ($1, $2, $3, COALESCE($4, '{}'::jsonb))
                RETURNING id
                "#
            }
            "public.chat_events" => {
                r#"
                INSERT INTO public.chat_events (user_id, conversation_id, message_id, event_name, event_payload)
                VALUES ($1, $2, $3, $4, COALESCE($5, '{}'::jsonb))
                RETURNING id
                "#
            }
            "public.rag_events" => {
                r#"
                INSERT INTO public.rag_events (request_id, user_id, retrieval_audit_id, event_name, event_payload)
                VALUES ($1, $2, $3, $4, COALESCE($5, '{}'::jsonb))
                RETURNING id
                "#
            }
            "public.admin_events" => {
                r#"
                INSERT INTO public.admin_events (admin_user_id, event_name, event_payload)
                VALUES ($1, $2, COALESCE($3, '{}'::jsonb))
                RETURNING id
                "#
            }
            _ => return Err(ApiError::internal("unsupported event table")),
        };

        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|_| ApiError::internal("failed to begin event transaction"))?;
        let rls_user_id = if table == "public.admin_events" {
            None
        } else {
            request.user_id
        };
        if let Some(user_id) = rls_user_id {
            sqlx::query("SELECT set_config('sakina.service_role', 'off', true)")
                .execute(&mut *tx)
                .await
                .map_err(|_| ApiError::internal("failed to set event service context"))?;
            sqlx::query("SELECT set_config('sakina.current_user_id', $1, true)")
                .bind(user_id.to_string())
                .execute(&mut *tx)
                .await
                .map_err(|_| ApiError::internal("failed to set event user context"))?;
        } else {
            sqlx::query("SELECT set_config('sakina.current_user_id', '', true)")
                .execute(&mut *tx)
                .await
                .map_err(|_| ApiError::internal("failed to clear event user context"))?;
            sqlx::query("SELECT set_config('sakina.service_role', 'on', true)")
                .execute(&mut *tx)
                .await
                .map_err(|_| ApiError::internal("failed to set event service context"))?;
        }

        let id = match table {
            "public.app_events" => {
                sqlx::query_scalar(sql)
                    .bind(request.user_id)
                    .bind(request.session_id)
                    .bind(&request.event_name)
                    .bind(
                        request
                            .event_payload
                            .unwrap_or_else(|| serde_json::json!({})),
                    )
                    .fetch_one(&mut *tx)
                    .await
            }
            "public.chat_events" => {
                sqlx::query_scalar(sql)
                    .bind(request.user_id)
                    .bind(request.conversation_id)
                    .bind(request.message_id)
                    .bind(&request.event_name)
                    .bind(
                        request
                            .event_payload
                            .unwrap_or_else(|| serde_json::json!({})),
                    )
                    .fetch_one(&mut *tx)
                    .await
            }
            "public.rag_events" => {
                sqlx::query_scalar(sql)
                    .bind(request.request_id)
                    .bind(request.user_id)
                    .bind(request.retrieval_audit_id)
                    .bind(&request.event_name)
                    .bind(
                        request
                            .event_payload
                            .unwrap_or_else(|| serde_json::json!({})),
                    )
                    .fetch_one(&mut *tx)
                    .await
            }
            "public.admin_events" => {
                sqlx::query_scalar(sql)
                    .bind(request.admin_user_id)
                    .bind(&request.event_name)
                    .bind(
                        request
                            .event_payload
                            .unwrap_or_else(|| serde_json::json!({})),
                    )
                    .fetch_one(&mut *tx)
                    .await
            }
            _ => unreachable!(),
        }
        .map_err(|_| ApiError::internal("failed to create event"))?;
        tx.commit()
            .await
            .map_err(|_| ApiError::internal("failed to commit event transaction"))?;
        Ok(id)
    }
}

fn token_hash(token: &str) -> String {
    let digest = Sha256::digest(token.as_bytes());
    format!("{:x}", digest)
}

fn validate_password(password: &str) -> Result<(), ApiError> {
    if password.len() < 8 {
        return Err(ApiError::bad_request(
            "password must be at least 8 characters",
        ));
    }
    let has_upper = password.chars().any(char::is_uppercase);
    let has_lower = password.chars().any(char::is_lowercase);
    let has_digit = password.chars().any(|ch| ch.is_ascii_digit());
    if !(has_upper && has_lower && has_digit) {
        return Err(ApiError::bad_request(
            "password must include uppercase, lowercase, and a number",
        ));
    }
    Ok(())
}

fn validate_email(email: &str) -> Result<(), ApiError> {
    let valid = email.len() <= 254
        && email.contains('@')
        && !email.starts_with('@')
        && !email.ends_with('@')
        && !email.contains(char::is_whitespace);
    if valid {
        Ok(())
    } else {
        Err(ApiError::bad_request("valid email is required"))
    }
}

fn password_hash(password: &str) -> Result<String, ApiError> {
    use argon2::password_hash::{PasswordHasher, SaltString};
    use argon2::Argon2;
    use rand_core::OsRng;

    let salt = SaltString::generate(&mut OsRng);
    Argon2::default()
        .hash_password(password.as_bytes(), &salt)
        .map(|hash| hash.to_string())
        .map_err(|_| ApiError::internal("failed to hash password"))
}

fn verify_password(password: &str, expected_hash: &str) -> Result<bool, ApiError> {
    use argon2::password_hash::{PasswordHash, PasswordVerifier};
    use argon2::Argon2;

    let parsed = PasswordHash::new(expected_hash)
        .map_err(|_| ApiError::internal("stored password hash is invalid"))?;
    Ok(Argon2::default()
        .verify_password(password.as_bytes(), &parsed)
        .is_ok())
}

struct IssuedTokens {
    access_token: String,
    refresh_token: String,
    expires_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegisterUserRequest {
    pub email: String,
    #[serde(default)]
    pub pub_key: Option<String>,
    #[serde(default)]
    pub provider: String,
    #[serde(default)]
    pub provider_user_id: String,
    #[serde(default)]
    pub provider_email: Option<String>,
    #[serde(default)]
    pub email_verified_at: Option<DateTime<Utc>>,
    #[serde(default)]
    pub metadata: Option<Value>,
    #[serde(default)]
    pub password: Option<String>,
    #[serde(default, alias = "display_name")]
    pub name: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegisterUserResponse {
    pub user_id: Uuid,
    pub identity_id: Uuid,
    pub email: Option<String>,
    pub pub_key: Option<String>,
    pub auth_provider: String,
    pub created_at: String,
    pub updated_at: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub access_token: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub refresh_token: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
    #[serde(default)]
    pub ip_address: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefreshTokenRequest {
    pub refresh_token: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoginResponse {
    pub user_id: Uuid,
    pub email: Option<String>,
    pub access_token: String,
    pub refresh_token: String,
    pub expires_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserSummary {
    pub user_id: Uuid,
    pub email: Option<String>,
    pub auth_provider: String,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateSessionRequest {
    pub user_id: Uuid,
    pub session_token_hash: String,
    pub refresh_token_hash: String,
    pub expires_at: DateTime<Utc>,
    pub refresh_expires_at: DateTime<Utc>,
    pub ip_address: Option<String>,
    pub user_agent: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateSessionResponse {
    pub session_id: Uuid,
    pub refresh_token_id: Uuid,
    pub session_created_at: String,
    pub refresh_created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpsertProfileRequest {
    pub user_id: Uuid,
    pub full_name: Option<String>,
    pub display_name: Option<String>,
    pub timezone: Option<String>,
    pub madhhab_preference: Option<String>,
    pub metadata: Option<Value>,
    pub ui_language: String,
    pub content_language: String,
    pub transliteration_enabled: bool,
    pub profile_visibility: String,
    pub data_export_allowed: bool,
    pub analytics_opt_in: bool,
    pub text_scale: f64,
    pub high_contrast_enabled: bool,
    pub reduced_motion_enabled: bool,
    pub screen_reader_optimized: bool,
    pub in_app_enabled: bool,
    pub email_enabled: bool,
    pub push_enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpsertProfileResponse {
    pub profile_id: Uuid,
    pub user_id: Uuid,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChildProfileInput {
    pub user_id: Option<Uuid>,
    pub preferred_name: String,
    pub birth_year: Option<i32>,
    pub learning_level: Option<String>,
    pub notes: Option<String>,
    pub metadata: Option<Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateFamilyProfileRequest {
    pub user_id: Uuid,
    pub family_name: String,
    pub household_size: Option<i32>,
    pub location_country_code: Option<String>,
    pub metadata: Option<Value>,
    pub children: Vec<ChildProfileInput>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateFamilyProfileResponse {
    pub family_profile_id: Uuid,
    pub child_ids: Vec<Uuid>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActivateSubscriptionRequest {
    pub user_id: Uuid,
    pub provider_key: String,
    pub provider_display_name: String,
    pub provider_customer_ref: String,
    pub plan_key: String,
    pub plan_name: String,
    pub billing_interval: String,
    pub provider_subscription_ref: String,
    pub provider_invoice_ref: String,
    pub provider_transaction_ref: String,
    pub currency_code: String,
    pub amount_minor: i32,
    pub current_period_start: DateTime<Utc>,
    pub current_period_end: DateTime<Utc>,
    pub entitlement_keys: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActivateSubscriptionResponse {
    pub user_id: Uuid,
    pub subscription_id: Uuid,
    pub payment_customer_id: Uuid,
    pub plan_id: Uuid,
    pub invoice_id: Uuid,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserEntitlementView {
    pub id: Uuid,
    pub entitlement_key: String,
    pub granted_at: String,
    pub expires_at: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateChatFeedbackRequest {
    pub user_id: Option<Uuid>,
    pub conversation_id: Option<Uuid>,
    pub message_id: Option<Uuid>,
    pub feedback_type: String,
    pub feedback_score: Option<i32>,
    pub feedback_comment: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReportAnswerRequest {
    pub user_id: Option<Uuid>,
    pub message_id: Option<Uuid>,
    pub report_reason: String,
    pub report_details: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApprovedRagSource {
    pub source_id: Uuid,
    pub source_key: String,
    pub source_type: String,
    pub language: String,
    pub document_id: Uuid,
    pub document_key: String,
    pub chunk_id: Uuid,
    pub chunk_key: String,
    pub citation_text: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogRagRetrievalRequest {
    pub request_id: Uuid,
    pub user_id: Option<Uuid>,
    pub conversation_id: Option<Uuid>,
    pub query_text: String,
    pub selected_module: String,
    pub language: String,
    pub retrieval_status: String,
    pub citation: Option<String>,
    pub confidence: Option<f64>,
    pub decision_reason: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogCitationEventRequest {
    pub request_id: Uuid,
    pub retrieval_audit_id: Option<Uuid>,
    pub citation_text: String,
    pub verification_status: String,
    pub verification_reason: Option<String>,
    pub verified_by: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogSafetyClassificationRequest {
    pub request_id: Uuid,
    pub user_id: Option<Uuid>,
    pub safety_level: String,
    pub islamic_sensitivity: String,
    pub classifier_version: String,
    pub classifier_output: Option<Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogMastermindDecisionRequest {
    pub request_id: Uuid,
    pub user_id: Option<Uuid>,
    pub conversation_id: Option<Uuid>,
    pub message_id: Option<Uuid>,
    pub language: String,
    pub intent: String,
    pub selected_module: String,
    pub safety_level: String,
    pub islamic_sensitivity: String,
    pub rag_allowed: bool,
    pub retrieval_required: bool,
    pub citations_required: bool,
    pub citation_sufficiency: bool,
    pub answer_allowed: bool,
    pub scholar_review_required: bool,
    pub final_response_policy: String,
    pub user_subscription_tier: String,
    pub entitlement_allowed: bool,
    pub reason: String,
    pub user_message: String,
    pub decision_payload: Option<Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnqueueScholarReviewRequest {
    pub request_id: Uuid,
    pub mastermind_decision_id: Option<Uuid>,
    pub conversation_id: Option<Uuid>,
    pub priority: String,
    pub reviewer_notes: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogWasmVerificationRequest {
    pub request_id: Uuid,
    pub module_name: String,
    pub decision_type: String,
    pub input_hash: String,
    pub output_decision: Option<Value>,
    pub policy_version: String,
    pub runtime_mode: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpsertAdminRoleRequest {
    pub role_key: String,
    pub role_name: String,
    pub permission_keys: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpsertAdminRoleResponse {
    pub role_id: Uuid,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogAdminActionRequest {
    pub admin_user_id: Option<Uuid>,
    pub request_id: Uuid,
    pub action_type: String,
    pub target_type: String,
    pub target_id: Option<String>,
    pub action_status: String,
    pub notes: Option<String>,
    pub metadata: Option<Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateScholarAccountRequest {
    pub user_id: Option<Uuid>,
    pub scholar_slug: String,
    pub display_name: String,
    pub verified: bool,
    pub credentials_summary: Option<String>,
    pub account_status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AssignScholarReviewRequest {
    pub scholar_account_id: Uuid,
    pub scholar_review_queue_id: Uuid,
    pub notes: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SourceApprovalItem {
    pub id: Uuid,
    pub source_id: Option<Uuid>,
    pub approval_status: String,
    pub notes: Option<String>,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateSourceApprovalItemRequest {
    pub source_id: Option<Uuid>,
    pub submitted_by: Option<Uuid>,
    pub notes: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateNotificationTemplateRequest {
    pub template_key: String,
    pub channel: String,
    pub subject_template: Option<String>,
    pub body_template: String,
    pub locale: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnqueueNotificationRequest {
    pub user_id: Uuid,
    pub template_id: Option<Uuid>,
    pub channel: String,
    pub title: Option<String>,
    pub body: Option<String>,
    pub payload: Option<Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserNotificationView {
    pub id: Uuid,
    pub channel: String,
    pub notification_status: String,
    pub title: Option<String>,
    pub body: Option<String>,
    pub payload: Value,
    pub scheduled_at: Option<String>,
    pub sent_at: Option<String>,
    pub read_at: Option<String>,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpsertDeviceTokenRequest {
    pub user_id: Uuid,
    pub platform: String,
    pub token_hash: String,
    pub app_version: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateSupportTicketRequest {
    pub user_id: Option<Uuid>,
    pub priority: String,
    pub category: Option<String>,
    pub subject: String,
    pub message_body: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateSupportTicketResponse {
    pub ticket_id: Uuid,
    pub ticket_number: i64,
    pub message_id: Uuid,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppendSupportTicketMessageRequest {
    pub support_ticket_id: Uuid,
    pub sender_type: String,
    pub sender_user_id: Option<Uuid>,
    pub message_body: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SupportTicketMessageView {
    pub id: Uuid,
    pub sender_type: String,
    pub sender_user_id: Option<Uuid>,
    pub message_body: String,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SupportTicketDetail {
    pub id: Uuid,
    pub ticket_number: i64,
    pub ticket_status: String,
    pub priority: String,
    pub category: Option<String>,
    pub subject: String,
    pub created_at: String,
    pub updated_at: String,
    pub messages: Vec<SupportTicketMessageView>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateAuditLogRequest {
    pub event_type: String,
    pub actor_type: String,
    pub actor_id: Option<String>,
    pub request_id: Option<String>,
    pub payload: Option<Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateSecurityLogRequest {
    pub event_type: String,
    pub severity: String,
    pub user_id: Option<Uuid>,
    pub ip_address: Option<String>,
    pub request_id: Option<String>,
    pub details: Option<Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateEventRequest {
    pub request_id: Option<Uuid>,
    pub user_id: Option<Uuid>,
    pub admin_user_id: Option<Uuid>,
    pub session_id: Option<Uuid>,
    pub retrieval_audit_id: Option<Uuid>,
    pub conversation_id: Option<Uuid>,
    pub message_id: Option<Uuid>,
    pub event_name: String,
    pub event_payload: Option<Value>,
}
