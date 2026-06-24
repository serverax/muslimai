//! Deterministic public Islamic calculators (no login required).
//! Zakat, Qibla bearing, Hijri (tabular) date, and a faraid (inheritance) core.
//! All pure functions with unit tests — no external API, no LLM.

use actix_web::{web, HttpResponse};
use serde::{Deserialize, Serialize};

use crate::error::ApiError;

// --------------------------------------------------------------------------
// Zakat
// --------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
pub struct ZakatRequest {
    #[serde(default)]
    pub cash: f64,
    #[serde(default)]
    pub gold_grams: f64,
    #[serde(default)]
    pub silver_grams: f64,
    #[serde(default)]
    pub business_assets: f64,
    #[serde(default)]
    pub liabilities: f64,
    /// Market price per gram. Required for an accurate nisab.
    #[serde(default = "default_gold_price")]
    pub gold_price_per_gram: f64,
    #[serde(default = "default_silver_price")]
    pub silver_price_per_gram: f64,
}

fn default_gold_price() -> f64 {
    0.0
}
fn default_silver_price() -> f64 {
    0.0
}

#[derive(Debug, Serialize)]
pub struct ZakatResponse {
    pub net_zakatable: f64,
    pub nisab_gold: f64,
    pub nisab_silver: f64,
    pub nisab_used: f64,
    pub eligible: bool,
    pub zakat_rate: f64,
    pub zakat_due: f64,
    pub basis: &'static str,
    pub citation: &'static str,
}

/// Nisab: 85g gold or 595g silver. We use the LOWER monetary nisab (cautious,
/// majority position) so more wealth becomes eligible.
pub fn compute_zakat(req: &ZakatRequest) -> ZakatResponse {
    let nisab_gold = 85.0 * req.gold_price_per_gram;
    let nisab_silver = 595.0 * req.silver_price_per_gram;
    let candidates: Vec<f64> = [nisab_gold, nisab_silver]
        .into_iter()
        .filter(|v| *v > 0.0)
        .collect();
    let nisab_used = candidates.iter().cloned().fold(f64::INFINITY, f64::min);
    let nisab_used = if nisab_used.is_finite() { nisab_used } else { 0.0 };

    let net = req.cash
        + req.gold_grams * req.gold_price_per_gram
        + req.silver_grams * req.silver_price_per_gram
        + req.business_assets
        - req.liabilities;
    let net = if net < 0.0 { 0.0 } else { net };

    let eligible = nisab_used > 0.0 && net >= nisab_used;
    let rate = 0.025;
    let due = if eligible { net * rate } else { 0.0 };

    ZakatResponse {
        net_zakatable: round2(net),
        nisab_gold: round2(nisab_gold),
        nisab_silver: round2(nisab_silver),
        nisab_used: round2(nisab_used),
        eligible,
        zakat_rate: rate,
        zakat_due: round2(due),
        basis: "lower of gold(85g)/silver(595g) nisab; 2.5% on net zakatable wealth held one year",
        citation: "Zakat 2.5% — Sahih Muslim 979; nisab thresholds per classical fiqh",
    }
}

pub async fn zakat(req: web::Json<ZakatRequest>) -> Result<HttpResponse, ApiError> {
    Ok(HttpResponse::Ok().json(compute_zakat(&req)))
}

// --------------------------------------------------------------------------
// Qibla — initial great-circle bearing to the Kaaba.
// --------------------------------------------------------------------------

const KAABA_LAT: f64 = 21.4225241;
const KAABA_LNG: f64 = 39.8261818;

#[derive(Debug, Deserialize)]
pub struct QiblaQuery {
    pub lat: f64,
    pub lng: f64,
}

#[derive(Debug, Serialize)]
pub struct QiblaResponse {
    pub bearing_degrees: f64,
    pub from: [f64; 2],
    pub kaaba: [f64; 2],
    pub note: &'static str,
}

pub fn qibla_bearing(lat: f64, lng: f64) -> f64 {
    let phi1 = lat.to_radians();
    let phi2 = KAABA_LAT.to_radians();
    let dlng = (KAABA_LNG - lng).to_radians();
    let y = dlng.sin() * phi2.cos();
    let x = phi1.cos() * phi2.sin() - phi1.sin() * phi2.cos() * dlng.cos();
    let bearing = y.atan2(x).to_degrees();
    (bearing + 360.0) % 360.0
}

pub async fn qibla(q: web::Query<QiblaQuery>) -> Result<HttpResponse, ApiError> {
    if !(-90.0..=90.0).contains(&q.lat) || !(-180.0..=180.0).contains(&q.lng) {
        return Err(ApiError::bad_request("lat/lng out of range"));
    }
    Ok(HttpResponse::Ok().json(QiblaResponse {
        bearing_degrees: round2(qibla_bearing(q.lat, q.lng)),
        from: [q.lat, q.lng],
        kaaba: [KAABA_LAT, KAABA_LNG],
        note: "initial great-circle bearing from true north toward the Kaaba",
    }))
}

// --------------------------------------------------------------------------
// Hijri (tabular Islamic) date conversion.
// --------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
pub struct HijriQuery {
    /// Gregorian date YYYY-MM-DD.
    pub date: String,
}

#[derive(Debug, Serialize)]
pub struct HijriResponse {
    pub gregorian: String,
    pub hijri_year: i64,
    pub hijri_month: i64,
    pub hijri_day: i64,
    pub month_name: &'static str,
}

const HIJRI_MONTHS: [&str; 12] = [
    "Muharram",
    "Safar",
    "Rabi al-Awwal",
    "Rabi al-Thani",
    "Jumada al-Awwal",
    "Jumada al-Thani",
    "Rajab",
    "Shaban",
    "Ramadan",
    "Shawwal",
    "Dhu al-Qadah",
    "Dhu al-Hijjah",
];

fn gregorian_to_jdn(y: i64, m: i64, d: i64) -> i64 {
    let a = (14 - m) / 12;
    let yy = y + 4800 - a;
    let mm = m + 12 * a - 3;
    d + (153 * mm + 2) / 5 + 365 * yy + yy / 4 - yy / 100 + yy / 400 - 32045
}

/// Tabular (arithmetical) Islamic calendar, civil epoch JDN 1948440 (16 Jul 622).
pub fn gregorian_to_hijri(y: i64, m: i64, d: i64) -> (i64, i64, i64) {
    let jdn = gregorian_to_jdn(y, m, d);
    let days = jdn - 1948440 + 10632;
    let n = (days - 1) / 10631;
    let days = days - 10631 * n + 354;
    let j = (10985 - days) / 5316 * ((50 * days) / 17719) + (days / 5670) * ((43 * days) / 15238);
    let days = days - (30 - j) / 15 * ((17719 * j) / 50) - (j / 16) * ((15238 * j) / 43) + 29;
    let month = (24 * days) / 709;
    let day = days - (709 * month) / 24;
    let year = 30 * n + j - 30;
    (year, month, day)
}

pub async fn hijri(q: web::Query<HijriQuery>) -> Result<HttpResponse, ApiError> {
    let parts: Vec<&str> = q.date.split('-').collect();
    if parts.len() != 3 {
        return Err(ApiError::bad_request("date must be YYYY-MM-DD"));
    }
    let y: i64 = parts[0].parse().map_err(|_| ApiError::bad_request("bad year"))?;
    let m: i64 = parts[1].parse().map_err(|_| ApiError::bad_request("bad month"))?;
    let d: i64 = parts[2].parse().map_err(|_| ApiError::bad_request("bad day"))?;
    if !(1..=12).contains(&m) || !(1..=31).contains(&d) {
        return Err(ApiError::bad_request("month/day out of range"));
    }
    let (hy, hm, hd) = gregorian_to_hijri(y, m, d);
    let name = HIJRI_MONTHS
        .get((hm - 1).clamp(0, 11) as usize)
        .copied()
        .unwrap_or("Unknown");
    Ok(HttpResponse::Ok().json(HijriResponse {
        gregorian: q.date.clone(),
        hijri_year: hy,
        hijri_month: hm,
        hijri_day: hd,
        month_name: name,
    }))
}

// --------------------------------------------------------------------------
// Inheritance (faraid) — core cases: spouse, parents, sons, daughters.
// Scope-limited (no grandchildren/siblings/grandparents). Applies 'awl.
// --------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
pub struct InheritanceRequest {
    pub estate: f64,
    #[serde(default)]
    pub husband: bool,
    #[serde(default)]
    pub wives: u32,
    #[serde(default)]
    pub father: bool,
    #[serde(default)]
    pub mother: bool,
    #[serde(default)]
    pub sons: u32,
    #[serde(default)]
    pub daughters: u32,
}

#[derive(Debug, Serialize)]
pub struct Share {
    pub heir: String,
    pub fraction: f64,
    pub amount: f64,
}

#[derive(Debug, Serialize)]
pub struct InheritanceResponse {
    pub estate: f64,
    pub shares: Vec<Share>,
    pub awl_applied: bool,
    pub scope_note: &'static str,
    pub citation: &'static str,
}

/// Returns (heir, fraction) pairs before normalisation. Children take the residue
/// (sons:daughters 2:1). If only daughters, they take the fixed Quranic share.
pub fn faraid(req: &InheritanceRequest) -> InheritanceResponse {
    let has_children = req.sons > 0 || req.daughters > 0;
    let mut fixed: Vec<(String, f64)> = Vec::new();

    if req.husband {
        fixed.push(("husband".into(), if has_children { 1.0 / 4.0 } else { 1.0 / 2.0 }));
    }
    if req.wives > 0 {
        let total = if has_children { 1.0 / 8.0 } else { 1.0 / 4.0 };
        fixed.push((format!("wives (x{})", req.wives), total));
    }
    if req.mother {
        // 1/6 with children, else 1/3 (siblings not modelled here).
        fixed.push(("mother".into(), if has_children { 1.0 / 6.0 } else { 1.0 / 3.0 }));
    }
    if req.father {
        // 1/6 when children present (plus residue as asaba below); else pure asaba.
        if has_children {
            fixed.push(("father".into(), 1.0 / 6.0));
        }
    }

    // Daughters-only fixed share (no sons): 1/2 (one) or 2/3 (two+).
    let daughters_only = req.daughters > 0 && req.sons == 0;
    if daughters_only {
        let share = if req.daughters == 1 { 1.0 / 2.0 } else { 2.0 / 3.0 };
        fixed.push((format!("daughters (x{})", req.daughters), share));
    }

    let fixed_sum: f64 = fixed.iter().map(|(_, f)| f).sum();

    // 'awl: fixed shares over-subscribe → scale down proportionally.
    let awl_applied = fixed_sum > 1.0 + 1e-9;
    let scale = if awl_applied { 1.0 / fixed_sum } else { 1.0 };

    let mut shares: Vec<Share> = fixed
        .iter()
        .map(|(h, f)| Share {
            heir: h.clone(),
            fraction: round4(f * scale),
            amount: round2(req.estate * f * scale),
        })
        .collect();

    // Residue (only when not over-subscribed) → asaba.
    let residue = if awl_applied { 0.0 } else { 1.0 - fixed_sum };
    if residue > 1e-9 {
        if req.sons > 0 {
            // sons + daughters split residue 2:1.
            let units = (req.sons * 2 + req.daughters) as f64;
            let per = residue / units;
            shares.push(Share {
                heir: format!("sons (x{})", req.sons),
                fraction: round4(per * (req.sons * 2) as f64),
                amount: round2(req.estate * per * (req.sons * 2) as f64),
            });
            if req.daughters > 0 {
                shares.push(Share {
                    heir: format!("daughters (x{})", req.daughters),
                    fraction: round4(per * req.daughters as f64),
                    amount: round2(req.estate * per * req.daughters as f64),
                });
            }
        } else if req.father {
            // father takes residue as asaba (in addition to any 1/6 above).
            shares.push(Share {
                heir: "father (residue/asaba)".into(),
                fraction: round4(residue),
                amount: round2(req.estate * residue),
            });
        } else if daughters_only {
            // radd (return) of residue to daughters when no asaba present.
            if let Some(s) = shares.iter_mut().find(|s| s.heir.starts_with("daughters")) {
                s.fraction = round4(s.fraction + residue);
                s.amount = round2(s.amount + req.estate * residue);
            }
        }
        // else: residue would go to other asaba not modelled (documented in scope_note).
    }

    InheritanceResponse {
        estate: round2(req.estate),
        shares,
        awl_applied,
        scope_note: "Core faraid: spouse, parents, sons, daughters only. Siblings, grandchildren, \
                     and grandparents are not modelled. Verify complex estates with a scholar.",
        citation: "Quran 4:11-12 (fixed shares); residue to asaba per classical fiqh",
    }
}

pub async fn inheritance(req: web::Json<InheritanceRequest>) -> Result<HttpResponse, ApiError> {
    if req.estate < 0.0 {
        return Err(ApiError::bad_request("estate must be non-negative"));
    }
    Ok(HttpResponse::Ok().json(faraid(&req)))
}

// --------------------------------------------------------------------------

// --------------------------------------------------------------------------
// Prayer times — deterministic astronomical calculation (no external API).
// Algorithm after PrayTimes.org. Public, no login.
// --------------------------------------------------------------------------

const DEG2RAD: f64 = std::f64::consts::PI / 180.0;

#[derive(Debug, Deserialize)]
pub struct PrayerQuery {
    pub lat: f64,
    pub lng: f64,
    /// Gregorian date YYYY-MM-DD.
    pub date: String,
    /// Timezone offset in hours from UTC (e.g. 3 for Makkah, 0 for London winter).
    #[serde(default)]
    pub tz: f64,
    /// mwl | isna | egypt | makkah | karachi (default mwl).
    #[serde(default)]
    pub method: Option<String>,
    /// standard | hanafi (default standard).
    #[serde(default)]
    pub asr: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct PrayerTimes {
    pub date: String,
    pub method: String,
    pub asr_method: String,
    pub location: [f64; 2],
    pub timezone: f64,
    pub fajr: String,
    pub sunrise: String,
    pub dhuhr: String,
    pub asr: String,
    pub maghrib: String,
    pub isha: String,
    pub note: &'static str,
}

fn julian_day(y: i64, m: i64, d: i64) -> f64 {
    let (yy, mm) = if m <= 2 { (y - 1, m + 12) } else { (y, m) };
    let a = (yy as f64 / 100.0).floor();
    let b = 2.0 - a + (a / 4.0).floor();
    (365.25 * (yy as f64 + 4716.0)).floor()
        + (30.6001 * (mm as f64 + 1.0)).floor()
        + d as f64
        + b
        - 1524.5
}

/// (declination_deg, equation_of_time_hours)
fn sun_position(jd: f64) -> (f64, f64) {
    let d = jd - 2451545.0;
    let g = (357.529 + 0.98560028 * d).rem_euclid(360.0);
    let q = (280.459 + 0.98564736 * d).rem_euclid(360.0);
    let l = (q + 1.915 * (g * DEG2RAD).sin() + 0.020 * (2.0 * g * DEG2RAD).sin())
        .rem_euclid(360.0);
    let e = 23.439 - 0.00000036 * d;
    let ra = (((e * DEG2RAD).cos() * (l * DEG2RAD).sin()).atan2((l * DEG2RAD).cos()) / DEG2RAD
        / 15.0)
        .rem_euclid(24.0);
    let decl = (((e * DEG2RAD).sin()) * (l * DEG2RAD).sin()).asin() / DEG2RAD;
    let eqt = q / 15.0 - ra;
    (decl, eqt)
}

/// hours from local noon for the sun to reach angle `a` degrees below the horizon.
fn time_for_angle(a: f64, lat: f64, decl: f64) -> Option<f64> {
    let x = (-(a * DEG2RAD).sin() - (lat * DEG2RAD).sin() * (decl * DEG2RAD).sin())
        / ((lat * DEG2RAD).cos() * (decl * DEG2RAD).cos());
    if !(-1.0..=1.0).contains(&x) {
        return None;
    }
    Some(x.acos() / DEG2RAD / 15.0)
}

fn asr_time(factor: f64, lat: f64, decl: f64) -> Option<f64> {
    let alt = (1.0 / (factor + ((lat - decl).abs() * DEG2RAD).tan())).atan() / DEG2RAD;
    time_for_angle(-alt, lat, decl)
}

fn fmt_hm(h: f64) -> String {
    let h = h.rem_euclid(24.0);
    let mut hh = h.floor() as i64;
    let mut mm = ((h - hh as f64) * 60.0).round() as i64;
    if mm == 60 {
        mm = 0;
        hh += 1;
    }
    format!("{:02}:{:02}", hh.rem_euclid(24), mm)
}

pub fn compute_prayer_times(q: &PrayerQuery) -> Result<PrayerTimes, ApiError> {
    let parts: Vec<&str> = q.date.split('-').collect();
    if parts.len() != 3 {
        return Err(ApiError::bad_request("date must be YYYY-MM-DD"));
    }
    let y: i64 = parts[0].parse().map_err(|_| ApiError::bad_request("bad year"))?;
    let m: i64 = parts[1].parse().map_err(|_| ApiError::bad_request("bad month"))?;
    let d: i64 = parts[2].parse().map_err(|_| ApiError::bad_request("bad day"))?;
    if !(-90.0..=90.0).contains(&q.lat) || !(-180.0..=180.0).contains(&q.lng) {
        return Err(ApiError::bad_request("lat/lng out of range"));
    }

    let method = q.method.as_deref().unwrap_or("mwl").to_lowercase();
    let (fajr_angle, isha_angle, isha_is_interval) = match method.as_str() {
        "isna" => (15.0, 15.0, false),
        "egypt" => (19.5, 17.5, false),
        "karachi" => (18.0, 18.0, false),
        "makkah" => (18.5, 0.0, true), // Isha = Maghrib + 90 min
        _ => (18.0, 17.0, false),      // mwl
    };
    let asr_method = q.asr.as_deref().unwrap_or("standard").to_lowercase();
    let asr_factor = if asr_method == "hanafi" { 2.0 } else { 1.0 };

    let jd = julian_day(y, m, d) - q.lng / (15.0 * 24.0);
    let (decl, eqt) = sun_position(jd + 0.5);

    let dhuhr = 12.0 + q.tz - q.lng / 15.0 - eqt;
    let err = || ApiError::bad_request("prayer times undefined at this latitude/date (polar)");
    // Sunrise/Maghrib (sun at 0.833 below horizon). Error only in true polar day/night.
    let rise_t = time_for_angle(0.833, q.lat, decl).ok_or_else(err)?;
    let sunrise = dhuhr - rise_t;
    let maghrib = dhuhr + rise_t;
    // Length of the night (Maghrib -> next Sunrise), used for high-latitude fallback.
    let night = 24.0 - 2.0 * rise_t;
    let asr = dhuhr + asr_time(asr_factor, q.lat, decl).ok_or_else(err)?;
    // High-latitude rule: when the twilight angle never occurs (e.g. London in
    // summer), fall back to the "one-seventh of the night" method instead of failing.
    let fajr = match time_for_angle(fajr_angle, q.lat, decl) {
        Some(t) => dhuhr - t,
        None => sunrise - night / 7.0,
    };
    let isha = if isha_is_interval {
        maghrib + 1.5
    } else {
        match time_for_angle(isha_angle, q.lat, decl) {
            Some(t) => dhuhr + t,
            None => maghrib + night / 7.0,
        }
    };

    Ok(PrayerTimes {
        date: q.date.clone(),
        method,
        asr_method,
        location: [q.lat, q.lng],
        timezone: q.tz,
        fajr: fmt_hm(fajr),
        sunrise: fmt_hm(sunrise),
        dhuhr: fmt_hm(dhuhr),
        asr: fmt_hm(asr),
        maghrib: fmt_hm(maghrib),
        isha: fmt_hm(isha),
        note: "deterministic calculation; confirm with your local masjid timetable",
    })
}

pub async fn prayer_times(q: web::Query<PrayerQuery>) -> Result<HttpResponse, ApiError> {
    Ok(HttpResponse::Ok().json(compute_prayer_times(&q)?))
}

// --------------------------------------------------------------------------
// Islamic calendar — today's Hijri + important dates (Hijri-anchored; Gregorian
// varies by moon sighting, stated honestly).
// --------------------------------------------------------------------------

pub async fn islamic_dates(q: web::Query<HijriQuery>) -> Result<HttpResponse, ApiError> {
    let parts: Vec<&str> = q.date.split('-').collect();
    if parts.len() != 3 {
        return Err(ApiError::bad_request("date must be YYYY-MM-DD"));
    }
    let y: i64 = parts[0].parse().map_err(|_| ApiError::bad_request("bad year"))?;
    let m: i64 = parts[1].parse().map_err(|_| ApiError::bad_request("bad month"))?;
    let d: i64 = parts[2].parse().map_err(|_| ApiError::bad_request("bad day"))?;
    let (hy, hm, hd) = gregorian_to_hijri(y, m, d);
    let name = HIJRI_MONTHS
        .get((hm - 1).clamp(0, 11) as usize)
        .copied()
        .unwrap_or("Unknown");

    let important = serde_json::json!([
        {"name": "Ramadan (start)", "hijri_month": 9, "hijri_day": 1, "note": "exact start depends on moon sighting"},
        {"name": "Laylat al-Qadr", "hijri_month": 9, "hijri_day": "odd nights of last 10", "note": "seek in the last ten nights of Ramadan"},
        {"name": "Eid al-Fitr", "hijri_month": 10, "hijri_day": 1, "note": "1 Shawwal; depends on moon sighting"},
        {"name": "Day of Arafah", "hijri_month": 12, "hijri_day": 9, "note": "first ten days of Dhul Hijjah are blessed"},
        {"name": "Eid al-Adha", "hijri_month": 12, "hijri_day": 10, "note": "10 Dhul Hijjah"},
        {"name": "Day of Ashura", "hijri_month": 1, "hijri_day": 10, "note": "10 Muharram"},
    ]);

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "gregorian": q.date,
        "today_hijri": { "year": hy, "month": hm, "day": hd, "month_name": name },
        "important_dates": important,
        "note": "Hijri dates are calculated (tabular); the actual day can shift by 1 day with local moon sighting.",
    })))
}

fn round2(v: f64) -> f64 {
    (v * 100.0).round() / 100.0
}
fn round4(v: f64) -> f64 {
    (v * 10000.0).round() / 10000.0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zakat_eligible_and_due() {
        let r = ZakatRequest {
            cash: 10000.0,
            gold_grams: 0.0,
            silver_grams: 0.0,
            business_assets: 0.0,
            liabilities: 0.0,
            gold_price_per_gram: 60.0,
            silver_price_per_gram: 0.7,
        };
        let z = compute_zakat(&r);
        // silver nisab 595*0.7=416.5 (lower) → eligible
        assert!(z.eligible);
        assert_eq!(z.zakat_due, 250.0); // 2.5% of 10000
    }

    #[test]
    fn zakat_below_nisab_not_due() {
        let r = ZakatRequest {
            cash: 100.0,
            gold_grams: 0.0,
            silver_grams: 0.0,
            business_assets: 0.0,
            liabilities: 0.0,
            gold_price_per_gram: 60.0,
            silver_price_per_gram: 0.7,
        };
        let z = compute_zakat(&r);
        assert!(!z.eligible);
        assert_eq!(z.zakat_due, 0.0);
    }

    #[test]
    fn qibla_london_is_southeast() {
        // London ≈ 51.5074, -0.1278 → qibla ≈ 119°
        let b = qibla_bearing(51.5074, -0.1278);
        assert!((b - 119.0).abs() < 2.0, "bearing was {b}");
    }

    #[test]
    fn hijri_year_is_sane() {
        let (y, m, d) = gregorian_to_hijri(2026, 6, 22);
        assert!((1447..=1448).contains(&y), "hijri year {y}");
        assert!((1..=12).contains(&m));
        assert!((1..=30).contains(&d));
    }

    #[test]
    fn faraid_husband_parents_son_daughter() {
        let r = InheritanceRequest {
            estate: 24000.0,
            husband: true,
            wives: 0,
            father: true,
            mother: true,
            sons: 1,
            daughters: 1,
        };
        let out = faraid(&r);
        let amt = |h: &str| {
            out.shares
                .iter()
                .find(|s| s.heir.starts_with(h))
                .map(|s| s.amount)
                .unwrap_or(0.0)
        };
        assert_eq!(amt("husband"), 6000.0); // 1/4
        assert_eq!(amt("mother"), 4000.0); // 1/6
        assert_eq!(amt("father"), 4000.0); // 1/6
        // residue 10000 to son:daughter 2:1
        assert_eq!(amt("sons"), 6666.67);
        assert_eq!(amt("daughters"), 3333.33);
    }

    #[test]
    fn faraid_awl_applied() {
        // With children: husband 1/4 + father 1/6 + mother 1/6 + 2 daughters 2/3
        // = 15/12 > 1 → 'awl (proportional scale-down), total preserved.
        let r = InheritanceRequest {
            estate: 12000.0,
            husband: true,
            wives: 0,
            father: true,
            mother: true,
            sons: 0,
            daughters: 2,
        };
        let out = faraid(&r);
        assert!(out.awl_applied);
        let total: f64 = out.shares.iter().map(|s| s.amount).sum();
        assert!((total - 12000.0).abs() < 1.0, "total {total}");
    }

    #[test]
    fn faraid_radd_to_daughters_no_awl() {
        // husband 1/4 + 2 daughters 2/3 = 11/12 < 1 → residue 1/12 radd to daughters.
        let r = InheritanceRequest {
            estate: 7000.0,
            husband: true,
            wives: 0,
            father: false,
            mother: false,
            sons: 0,
            daughters: 2,
        };
        let out = faraid(&r);
        assert!(!out.awl_applied);
        let total: f64 = out.shares.iter().map(|s| s.amount).sum();
        assert!((total - 7000.0).abs() < 1.0, "total {total}");
    }

    #[test]
    fn prayer_times_are_ordered_for_london() {
        let q = PrayerQuery {
            lat: 51.5074,
            lng: -0.1278,
            date: "2026-06-23".to_string(),
            tz: 1.0,
            method: None,
            asr: None,
        };
        let p = compute_prayer_times(&q).expect("london prayer times");
        let mins = |s: &str| {
            let v: Vec<i64> = s.split(':').map(|x| x.parse().unwrap()).collect();
            v[0] * 60 + v[1]
        };
        // Fajr < Sunrise < Dhuhr < Asr < Maghrib < Isha
        assert!(mins(&p.fajr) < mins(&p.sunrise), "{p:?}");
        assert!(mins(&p.sunrise) < mins(&p.dhuhr));
        assert!(mins(&p.dhuhr) < mins(&p.asr));
        assert!(mins(&p.asr) < mins(&p.maghrib));
        assert!(mins(&p.maghrib) < mins(&p.isha));
    }
}
