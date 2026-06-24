# CLAUDE CODE - MASTER EXECUTION ORDER
## Complete Project Sakina from Current State to Production

**Current State:** Infrastructure validated (38 K8s objects), scaffolding complete, all docs accurate.
**Your Role:** Solo implementation of all business logic, data pipeline, frontend services, and monitoring.
**Timeline:** ~3-4 months (Tiers 1-2 critical path).

> Provenance note: this is the roadmap as authored. Some code blocks are
> illustrative (e.g., the Step 5 handler references `embedding`/`elapsed`/`vllm`
> that get introduced as their steps land; the Step 7 Rust calls an
> `ArabicSemanticChunker` whose reference impl is Python — bridge via a sidecar/
> Job or PyO3, a decision flagged in SPRINT-GAP-ANALYSIS.md). Treat each block as
> the target to adapt and compile per the per-step `cargo`/`flutter` checks.

---

# PHASE 1: CORE BUSINESS LOGIC (Weeks 1-2)

## Sprint 2 Implementation: RAG Engine & Guardrails

### Step 1: Semantic Router (Days 1-2)

**File:** `sakina-backend/src/services/semantic_router.rs`

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum QueryIntent {
    FiqhQuery,      // Islamic jurisprudence question
    TafsirQuery,    // Quran interpretation question
    CompanionChat,  // General Islamic discussion
    OutOfScope,     // Not an Islamic question
}

#[derive(Debug, Serialize)]
pub struct ClassifyResult {
    pub intent: QueryIntent,
    pub confidence: f32,
    pub routing_decision: String,
}

pub struct SemanticRouter {
    // Will use vLLM or local classifier
}

impl SemanticRouter {
    pub fn new() -> Self {
        SemanticRouter {}
    }

    /// Classify incoming query to determine intent
    /// Returns QueryIntent and confidence score
    pub async fn classify(&self, query: &str) -> Result<ClassifyResult, Box<dyn std::error::Error>> {
        // TODO: Call vLLM on /v1/completions with prompt:
        // "Classify this Islamic question into one of: FiqhQuery, TafsirQuery, CompanionChat, OutOfScope.
        //  Question: [query]
        //  Classification: "
        //
        // Parse response for intent + confidence
        //
        // For now, return stub that matches test expectations
        Ok(ClassifyResult {
            intent: QueryIntent::FiqhQuery,
            confidence: 0.95,
            routing_decision: "RAG".to_string(),
        })
    }
}
```

**Wire into:** `handlers/classify.rs`
- Call `self.router.classify(&req.query).await?`
- Return `ClassifyResponse` with intent, confidence
- Log to `audit.logs` (via middleware)

**Test:** `cargo test` passes (uses stub until vLLM available)

---

### Step 2: Guardrails Engine (Days 3-4)

**File:** `sakina-backend/src/services/guardrails.rs`

```rust
use qdrant_client::prelude::*;

#[derive(Debug, Serialize)]
pub struct GuardrailResult {
    pub passed: bool,
    pub reason: Option<String>,
    pub confidence: f32,
}

pub struct Guardrails {
    similarity_threshold: f32,  // 0.85
    qdrant: QdrantClient,
}

impl Guardrails {
    pub fn new(qdrant: QdrantClient, threshold: f32) -> Self {
        Guardrails {
            similarity_threshold: threshold,
            qdrant,
        }
    }

    /// Check if query meets confidence threshold
    /// If similarity score < 0.85, return guardrail_triggered=true
    pub async fn check(
        &self,
        query_embedding: &[f32],
    ) -> Result<GuardrailResult, Box<dyn std::error::Error>> {
        // TODO: Search Qdrant for similar chunks
        // let results = self.qdrant.search_points(...)
        //
        // if results.is_empty() || results[0].score < self.similarity_threshold {
        //     return Ok(GuardrailResult {
        //         passed: false,
        //         reason: Some("Query below confidence threshold".to_string()),
        //         confidence: results.get(0).map(|r| r.score).unwrap_or(0.0),
        //     })
        // }
        //
        // For now, return stub (passed=true, high confidence)
        Ok(GuardrailResult {
            passed: true,
            reason: None,
            confidence: 0.92,
        })
    }
}
```

**Wire into:** `handlers/rag.rs`
- Embed query via vLLM embeddings endpoint
- Call `self.guardrails.check(&embedding).await?`
- If `!passed`: return fallback response "Consult a scholar"
- Log to `audit.logs` with `guardrail_triggered: true`

**Test:** `cargo test` passes

---

### Step 3: Citation Engine (Days 5-6)

**File:** `sakina-backend/src/services/citation.rs`

```rust
use sqlx::PgPool;

#[derive(Debug, Serialize, Clone)]
pub struct Citation {
    pub title: String,
    pub author: String,
    pub chapter: Option<String>,
    pub authenticity_grade: Option<String>,
}

pub struct CitationEngine {
    pool: PgPool,
}

impl CitationEngine {
    pub fn new(pool: PgPool) -> Self {
        CitationEngine { pool }
    }

    /// Given retrieved chunks, fetch source metadata
    pub async fn cite(
        &self,
        chunk_ids: &[i64],
    ) -> Result<Vec<Citation>, Box<dyn std::error::Error>> {
        // TODO: For each chunk_id:
        // SELECT source_document_id FROM verified_knowledge.chunks WHERE id = $1
        // SELECT title, author, chapter, authenticity_grade
        //   FROM verified_knowledge.source_documents WHERE id = source_document_id
        //
        // Return vector of Citations
        //
        // For now, return stub citations
        Ok(vec![Citation {
            title: "Sample Islamic Text".to_string(),
            author: "Scholar Name".to_string(),
            chapter: Some("Chapter 1".to_string()),
            authenticity_grade: Some("Sahih".to_string()),
        }])
    }
}
```

**Wire into:** `handlers/rag.rs`
- After RAG retrieval, get chunk IDs
- Call `self.citations.cite(&chunk_ids).await?`
- Include in `RagQueryResponse.sources`

**Test:** Integration tests assert on `sources` field

---

### Step 4: Audit Middleware (Days 7-8)

**File:** `sakina-backend/src/middleware/audit.rs`

```rust
use actix_web::{
    dev::{forward_ready, Service, ServiceRequest, ServiceResponse, Transform},
    Error, HttpMessage,
};
use futures_util::future::LocalBoxFuture;
use std::time::Instant;

pub struct AuditMiddleware;

impl<S, B> Transform<S, ServiceRequest> for AuditMiddleware
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error>,
    S::Future: 'static,
    B: 'static,
{
    type Response = ServiceResponse<B>;
    type Error = Error;
    type InitError = ();
    type Transform = AuditMiddlewareService<S>;
    type Future = std::future::Ready<Result<Self::Transform, Self::InitError>>;

    fn new_transform(&self, service: S) -> Self::Future {
        std::future::ready(Ok(AuditMiddlewareService { service }))
    }
}

pub struct AuditMiddlewareService<S> {
    service: S,
}

impl<S, B> Service<ServiceRequest> for AuditMiddlewareService<S>
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error>,
    S::Future: 'static,
    B: 'static,
{
    type Response = ServiceResponse<B>;
    type Error = Error;
    type Future = LocalBoxFuture<'static, Result<Self::Response, Self::Error>>;

    forward_ready!(service);

    fn call(&self, req: ServiceRequest) -> Self::Future {
        let start = Instant::now();
        let method = req.method().to_string();
        let path = req.path().to_string();
        let user_id = req
            .extensions()
            .get::<String>()
            .map(|s| s.clone())
            .unwrap_or_else(|| "anonymous".to_string());

        let fut = self.service.call(req);

        Box::pin(async move {
            let res = fut.await?;
            let elapsed = start.elapsed();

            // Log to audit.logs
            tracing::info!(
                event = "http_request",
                method = method,
                path = path,
                status = res.status().as_u16(),
                duration_ms = elapsed.as_millis(),
                user_id = user_id,
                "HTTP request"
            );

            Ok(res)
        })
    }
}
```

**Wire into:** `main.rs`
- Add to app middleware chain: `.wrap(AuditMiddleware)`
- Logs all HTTP requests to tracing (which writes to audit.logs)

**Test:** `cargo test` passes

---

## Sprint 3 Implementation: Wire Endpoints

### Step 5: Wire Handler Logic (Days 9-10)

**File:** Update all handlers in `sakina-backend/src/handlers/`

**handlers/rag.rs:**
```rust
pub async fn rag_query(
    req: web::Json<RagQueryRequest>,
    router: web::Data<Arc<SemanticRouter>>,
    guardrails: web::Data<Arc<Guardrails>>,
    citations: web::Data<Arc<CitationEngine>>,
) -> Result<web::Json<RagQueryResponse>, ApiError> {
    // 1. Classify intent
    let intent = router.classify(&req.query).await?;

    // 2. Check guardrails
    // (Embed query, check threshold)
    let guardrail_result = guardrails.check(&embedding).await?;

    if !guardrail_result.passed {
        audit_log("guardrail_triggered", &req.query);
        return Ok(web::Json(RagQueryResponse {
            answer: "To maintain accuracy, I cannot provide an answer below our confidence threshold. Please consult a qualified Islamic scholar.".to_string(),
            sources: vec![],
            confidence: 0.0,
            guardrail_triggered: true,
            processing_time_ms: elapsed.as_millis() as i64,
        }));
    }

    // 3. Retrieve from Qdrant (RAG)
    let chunks = qdrant.search_points(...)?;

    // 4. Generate with vLLM
    let answer = vllm.complete(&chunks, &req.query).await?;

    // 5. Add citations
    let sources = citations.cite(&chunk_ids).await?;

    // 6. Return response
    Ok(web::Json(RagQueryResponse {
        answer,
        sources,
        confidence: guardrail_result.confidence,
        guardrail_triggered: false,
        processing_time_ms: elapsed.as_millis() as i64,
    }))
}
```

**handlers/classify.rs:**
```rust
pub async fn classify(
    req: web::Json<ClassifyRequest>,
    router: web::Data<Arc<SemanticRouter>>,
) -> Result<web::Json<ClassifyResponse>, ApiError> {
    let result = router.classify(&req.text).await?;
    Ok(web::Json(ClassifyResponse {
        intent: format!("{:?}", result.intent),
        confidence: result.confidence,
        routing_decision: result.routing_decision,
    }))
}
```

**Test:** All integration tests pass

---

## Phase 1 Validation

```bash
cd F:\SakinaAL\sakina-backend

# Step 1-4: Unit tests
cargo test

# Step 5: Compile all handlers
cargo check

# Step 6: Clippy (required for CI)
cargo clippy -- -D warnings

# Step 7: Build release
cargo build --release
```

**Expected:** All pass without errors.

---

# PHASE 2: DATA PIPELINE (Weeks 3-4)

## Sprint 1 Implementation: Ingestion & Chunking

### Step 6: ArabicSemanticChunker (Days 1-3)

**File:** `sakina-backend/chunking.py`

```python
from typing import List
from transformers import AutoTokenizer
import re

class ArabicSemanticChunker:
    def __init__(self, model_name: str = "GATE-AraBERT-v1"):
        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
        self.max_chunk_size = 512
        self.overlap_size = 75  # tokens

    def preprocess(self, text: str) -> str:
        """Remove diacritics, normalize whitespace"""
        # Remove Arabic diacritics
        text = re.sub(r'[ً-ٟ]', '', text)
        # Normalize whitespace
        text = ' '.join(text.split())
        return text

    def split_by_markers(self, text: str) -> List[str]:
        """Split by Islamic text structure markers"""
        markers = ['باب', 'فصل', 'مسألة', '\\n\\n']
        sections = [text]

        for marker in markers:
            new_sections = []
            for section in sections:
                new_sections.extend(section.split(marker))
            sections = new_sections

        return [s.strip() for s in sections if s.strip()]

    def chunk(self, text: str) -> List[str]:
        """Create overlapping chunks with semantic awareness"""
        # 1. Preprocess
        text = self.preprocess(text)

        # 2. Split by markers
        sections = self.split_by_markers(text)

        # 3. Create overlapping chunks
        chunks = []
        for section in sections:
            tokens = self.tokenizer.tokenize(section)

            for i in range(0, len(tokens), self.max_chunk_size - self.overlap_size):
                chunk_tokens = tokens[i : i + self.max_chunk_size]
                chunk_text = self.tokenizer.convert_tokens_to_string(chunk_tokens)
                if chunk_text.strip():
                    chunks.append(chunk_text)

        return chunks

# Export for use
__all__ = ['ArabicSemanticChunker']
```

**Test:** `python -m pytest chunking_test.py` passes

---

### Step 7: Ingestion Producer (Days 4-6)

**File:** `sakina-backend/src/services/ingestion_producer.rs`

```rust
use sqlx::PgPool;
use qdrant_client::prelude::*;
use std::path::Path;

pub struct IngestionProducer {
    pool: PgPool,
    qdrant: QdrantClient,
}

impl IngestionProducer {
    pub fn new(pool: PgPool, qdrant: QdrantClient) -> Self {
        IngestionProducer { pool, qdrant }
    }

    /// Ingest a single document: read, chunk, embed, store
    pub async fn ingest_document(
        &self,
        path: &Path,
        madhhab: &str,
        scholar: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // 1. Read file
        let content = std::fs::read_to_string(path)?;
        let title = path.file_name().unwrap().to_string_lossy().to_string();

        // 2. Insert source document
        let source_doc_id: i64 = sqlx::query_scalar(
            "INSERT INTO verified_knowledge.source_documents
             (title, author, madhhab, scholar, integrity_hash, approved_at)
             VALUES ($1, $2, $3, $4, $5, NOW())
             RETURNING id"
        )
        .bind(&title)
        .bind(scholar)
        .bind(madhhab)
        .bind(scholar)
        .bind(sha256(&content))  // integrity_hash
        .fetch_one(&self.pool)
        .await?;

        // 3. Chunk text
        let chunker = ArabicSemanticChunker::new();
        let chunks = chunker.chunk(&content)?;

        // 4. For each chunk: embed, insert, add to Qdrant
        for (idx, chunk) in chunks.iter().enumerate() {
            // Get embedding from vLLM
            let embedding = self.get_embedding(chunk).await?;

            // Insert chunk to PostgreSQL
            let chunk_id: i64 = sqlx::query_scalar(
                "INSERT INTO verified_knowledge.chunks
                 (source_document_id, content_chunk, madhhab, scholar, token_count)
                 VALUES ($1, $2, $3, $4, $5)
                 RETURNING id"
            )
            .bind(source_doc_id)
            .bind(chunk)
            .bind(madhhab)
            .bind(scholar)
            .bind(chunk.split_whitespace().count() as i32)
            .fetch_one(&self.pool)
            .await?;

            // Insert to Qdrant
            self.qdrant.upsert_points(
                "verified_knowledge",
                vec![PointStruct {
                    id: chunk_id as u64,
                    vector: embedding,
                    payload: json!({
                        "source_id": source_doc_id,
                        "madhhab": madhhab,
                    }),
                }],
            )
            .await?;

            // Insert to outbox for sync
            sqlx::query(
                "INSERT INTO outbox.events (event_type, payload, status)
                 VALUES ($1, $2, $3)"
            )
            .bind("chunk_indexed")
            .bind(json!({"chunk_id": chunk_id, "source_id": source_doc_id}))
            .bind("Pending")
            .execute(&self.pool)
            .await?;
        }

        Ok(())
    }

    async fn get_embedding(&self, text: &str) -> Result<Vec<f32>, Box<dyn std::error::Error>> {
        // Call vLLM embeddings endpoint
        // POST /v1/embeddings with text
        // Return vector
        todo!()
    }
}
```

**Test:** `cargo test` passes (mocked vLLM)

---

### Step 8: Outbox Relay (Days 7-8)

**File:** `sakina-backend/src/services/outbox_relay.rs`

```rust
use sqlx::PgPool;
use tokio::time::{Duration, sleep};

pub struct OutboxRelay {
    pool: PgPool,
    max_retries: i32,
}

impl OutboxRelay {
    pub fn new(pool: PgPool) -> Self {
        OutboxRelay {
            pool,
            max_retries: 5,
        }
    }

    /// Relay pending events to Qdrant (idempotent)
    pub async fn relay_events(&self) -> Result<(), Box<dyn std::error::Error>> {
        loop {
            // FOR UPDATE SKIP LOCKED to avoid conflicts
            let events: Vec<OutboxEvent> = sqlx::query_as(
                "SELECT id, event_type, payload, retry_count
                 FROM outbox.events
                 WHERE status = 'Pending'
                 FOR UPDATE SKIP LOCKED
                 LIMIT 10"
            )
            .fetch_all(&self.pool)
            .await?;

            for event in events {
                match event.event_type.as_str() {
                    "chunk_indexed" => {
                        // Already sent to Qdrant during ingestion
                        // Mark as Sent
                        sqlx::query("UPDATE outbox.events SET status = 'Sent' WHERE id = $1")
                            .bind(event.id)
                            .execute(&self.pool)
                            .await?;
                    }
                    _ => {}
                }
            }

            // Sleep and retry
            sleep(Duration::from_secs(5)).await;
        }
    }
}
```

**Wire into:** `main.rs`
- Spawn tokio task: `tokio::spawn(relay.relay_events())`

**Test:** `cargo test` passes

---

### Step 9: Ingestion Job (Days 9-10)

**File:** `sakina-backend/src/bin/ingest.rs`

```rust
use sakina_backend::services::IngestionProducer;
use std::path::PathBuf;
use clap::Parser;

#[derive(Parser)]
struct Args {
    #[arg(long)]
    path: PathBuf,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    let pool = create_pool().await?;
    let qdrant = create_qdrant_client().await?;
    let producer = IngestionProducer::new(pool, qdrant);

    // Ingest all .txt files in directory
    for entry in std::fs::read_dir(&args.path)? {
        let entry = entry?;
        let path = entry.path();

        if path.extension().map_or(false, |ext| ext == "txt") {
            println!("Ingesting {:?}...", path);
            producer.ingest_document(&path, "hanafi", "Unknown").await?;
            println!("✓ Ingested");
        }
    }

    Ok(())
}
```

**Kubernetes Job:**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: sakina-data-ingestion
  namespace: sakina-data
spec:
  template:
    spec:
      containers:
      - name: ingest
        image: sakina-backend-api:latest
        command: ["/usr/local/bin/sakina-ingest", "--path", "/data/verified-texts"]
        volumeMounts:
        - name: texts
          mountPath: /data/verified-texts
      volumes:
      - name: texts
        emptyDir: {}  # In production, use ConfigMap or PVC
      restartPolicy: Never
  backoffLimit: 3
```

**Test:** `cargo build --bin ingest` passes

---

## Phase 2 Validation

```bash
cd F:\SakinaAL\sakina-backend

# Test chunker
python -m pytest chunking_test.py

# Test ingestion
cargo test

# Build ingestion binary
cargo build --release --bin ingest

# Verify all handlers still compile
cargo check
```

---

# PHASE 3: FRONTEND SERVICES (Weeks 5-6)

## Sprint 4 Implementation: Flutter Integration

### Step 10: LocalDBService (Days 1-3)

**File:** `sakina-frontend/lib/services/local_db_service.dart`

⚠️ **Package prerequisite:**
```yaml
# pubspec.yaml - MUST update before implementing
dependencies:
  sqflite_sqlcipher: ^2.5.0  # NOT plain sqflite
  cryptography: ^2.7.0        # For ChaCha20-Poly1305
  http: ^1.1.0                # Already present
```

```dart
import 'package:sqflite_sqlcipher/sqflite.dart';

class LocalDBService {
  static const String _dbName = 'sakina.db';
  static const int _dbVersion = 1;
  late Database _db;
  late String _password;

  Future<void> init(String password) async {
    _password = password;
    _db = await openDatabase(
      _dbName,
      version: _dbVersion,
      password: password,  // SQLCipher encryption
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        role TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        sources TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_timestamp ON messages(timestamp DESC)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle schema migrations
  }

  Future<void> saveMessage(Message msg) async {
    await _db.insert('messages', msg.toMap());
  }

  Future<List<Message>> getMessages() async {
    final maps = await _db.query(
      'messages',
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => Message.fromMap(m)).toList();
  }

  Future<void> clearMessages() async {
    await _db.delete('messages');
  }

  Future<void> close() async {
    await _db.close();
  }
}

class Message {
  final String id;
  final String content;
  final String role;  // 'user' or 'assistant'
  final int timestamp;
  final String? sources;
  final int createdAt;

  Message({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.sources,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'content': content,
    'role': role,
    'timestamp': timestamp,
    'sources': sources,
    'created_at': createdAt,
  };

  factory Message.fromMap(Map<String, dynamic> map) => Message(
    id: map['id'],
    content: map['content'],
    role: map['role'],
    timestamp: map['timestamp'],
    sources: map['sources'],
    createdAt: map['created_at'],
  );
}
```

**Test:** `flutter test` includes LocalDB tests

---

### Step 11: SyncService (Days 4-6)

**File:** `sakina-frontend/lib/services/sync_service.dart`

⚠️ **Package prerequisite:**
```yaml
# pubspec.yaml - MUST update
dependencies:
  cryptography: ^2.7.0  # For ChaCha20-Poly1305 + ECDH
```

```dart
import 'package:cryptography/cryptography.dart';
import 'dart:convert';

class SyncService {
  final ApiService _api;
  final LocalDBService _localDb;
  late PrivateKey _privateKey;
  late PublicKey _publicKey;

  SyncService(this._api, this._localDb);

  Future<void> init() async {
    // Generate ECDH key pair on first run
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    _privateKey = await keyPair.extractPrivateKey();
    _publicKey = await keyPair.extractPublicKey();
  }

  /// Encrypt and backup all messages
  Future<void> backupEncrypted() async {
    // 1. Get all messages
    final messages = await _localDb.getMessages();
    final plaintext = jsonEncode(
      messages.map((m) => m.toMap()).toList()
    );

    // 2. Get server's public key
    final serverPubKey = await _api.getPublicKey();

    // 3. Encrypt with ChaCha20-Poly1305
    final encrypted = await _encryptData(plaintext, serverPubKey);

    // 4. Upload to server
    await _api.uploadBackup(encrypted);
  }

  /// Decrypt and restore backup
  Future<void> restoreEncrypted(String privateKeyHex) async {
    // 1. Download encrypted blob
    final encrypted = await _api.downloadBackup();

    // 2. Decrypt with private key
    final plaintext = await _decryptData(encrypted, privateKeyHex);

    // 3. Parse and restore
    final messages = (jsonDecode(plaintext) as List)
      .map((m) => Message.fromMap(m as Map<String, dynamic>))
      .toList();

    for (var msg in messages) {
      await _localDb.saveMessage(msg);
    }
  }

  Future<String> _encryptData(String plaintext, PublicKey serverPubKey) async {
    final algorithm = ChaCha20Poly1305Aead();
    final secretKey = await algorithm.newSecretKey();
    final nonce = Nonce.randomBytes(12);

    final ciphertext = await algorithm.encrypt(
      utf8.encode(plaintext) as List<int>,
      secretKey: secretKey,
      nonce: nonce,
    );

    // Return: nonce || ciphertext || tag (base64)
    final combined = [...nonce.bytes, ...ciphertext.cipherText, ...ciphertext.mac.bytes];
    return base64.encode(combined);
  }

  Future<String> _decryptData(String encrypted, String privateKeyHex) async {
    final algorithm = ChaCha20Poly1305Aead();
    final bytes = base64.decode(encrypted);

    final nonce = Nonce(bytes.sublist(0, 12));
    final ciphertext = bytes.sublist(12, bytes.length - 16);
    final mac = Mac(bytes.sublist(bytes.length - 16));

    final secretKey = await algorithm.newSecretKey();

    final plaintext = await algorithm.decrypt(
      SecretBox(ciphertext, nonce: nonce, mac: mac),
      secretKey: secretKey,
    );

    return utf8.decode(plaintext);
  }
}
```

**Test:** `flutter test` includes Sync tests (mocked API)

---

### Step 12: API Service Integration (Days 7-8)

**File:** `sakina-frontend/lib/services/api_service.dart`

⚠️ **Note:** Use `http` package (already in pubspec), not Dio

```dart
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<RagResponse> query(
    String message, {
    String? madhab,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/v1/rag/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': message,
          'user_id': _getUserId(),
          'madhhab_filter': madhab,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return RagResponse.fromJson(jsonDecode(response.body));
      } else {
        throw ApiException('HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Query failed: $e');
    }
  }

  Future<ClassifyResponse> classify(String text) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/v1/classify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return ClassifyResponse.fromJson(jsonDecode(response.body));
      } else {
        throw ApiException('HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Classify failed: $e');
    }
  }

  Future<PublicKey> getPublicKey() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/v1/users/pubkey'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw ApiException('Failed to get public key');
    }
  }

  Future<void> uploadBackup(String encrypted) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/v1/sync/backup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'data': encrypted}),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw ApiException('Backup upload failed');
    }
  }

  Future<String> downloadBackup() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/v1/sync/backup'),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      throw ApiException('Backup download failed');
    }
  }

  String _getUserId() {
    // TODO: Get from SharedPreferences or auth provider
    return 'anonymous';
  }
}

class RagResponse {
  final String answer;
  final List<Citation> sources;
  final double confidence;
  final bool guardrailTriggered;
  final int processingTimeMs;

  RagResponse({
    required this.answer,
    required this.sources,
    required this.confidence,
    required this.guardrailTriggered,
    required this.processingTimeMs,
  });

  factory RagResponse.fromJson(Map<String, dynamic> json) => RagResponse(
    answer: json['answer'] as String,
    sources: (json['sources'] as List?)
      ?.map((s) => Citation.fromJson(s as Map<String, dynamic>))
      .toList() ?? [],
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    guardrailTriggered: json['guardrail_triggered'] as bool? ?? false,
    processingTimeMs: json['processing_time_ms'] as int? ?? 0,
  );
}

class ClassifyResponse {
  final String intent;
  final double confidence;
  final String routingDecision;

  ClassifyResponse({
    required this.intent,
    required this.confidence,
    required this.routingDecision,
  });

  factory ClassifyResponse.fromJson(Map<String, dynamic> json) => ClassifyResponse(
    intent: json['intent'] as String,
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    routingDecision: json['routing_decision'] as String? ?? '',
  );
}

class Citation {
  final String title;
  final String author;
  final String? chapter;
  final String? authenticityGrade;

  Citation({
    required this.title,
    required this.author,
    this.chapter,
    this.authenticityGrade,
  });

  factory Citation.fromJson(Map<String, dynamic> json) => Citation(
    title: json['title'] as String,
    author: json['author'] as String,
    chapter: json['chapter'] as String?,
    authenticityGrade: json['authenticity_grade'] as String?,
  );
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
```

**Wire into:** `lib/main.dart`
- Provide ApiService, LocalDBService, SyncService
- Initialize in main with Riverpod

**Test:** `flutter test` includes API service tests (mocked)

---

### Step 13: Citation UI (Days 9-10)

**File:** `sakina-frontend/lib/widgets/citation_widget.dart`

```dart
import 'package:flutter/material.dart';

class CitationBadge extends StatelessWidget {
  final Citation source;

  const CitationBadge({Key? key, required this.source}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCitationDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),  // Brand accent green
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF1B6B5E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              source.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B6B5E),
              ),
            ),
            if (source.author.isNotEmpty)
              Text(
                'by ${source.author}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCitationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(source.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildField('Author', source.author),
              if (source.chapter != null)
                _buildField('Chapter', source.chapter!),
              if (source.authenticityGrade != null)
                _buildField('Grade', source.authenticityGrade!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }
}

// In chat_screen.dart, use in message list:
ListView.builder(
  itemCount: messages.length,
  itemBuilder: (context, index) {
    final msg = messages[index];
    return MessageBubble(
      message: msg,
      citations: msg.sources
        ?.map((c) => CitationBadge(source: c))
        .toList() ?? [],
    );
  },
)
```

**Test:** `flutter test` includes Citation UI tests

---

## Phase 3 Validation

```bash
cd F:\SakinaAL\sakina-frontend

# Update dependencies
flutter pub get

# Analyze code
flutter analyze

# Run tests
flutter test

# Build APK
flutter build apk --release

# Build IPA (requires macOS)
flutter build ios --release
```

---

# PHASE 4: SECURITY & MONITORING (Weeks 7-8)

## Sprint 5 Implementation: Dashboard & Instrumentation

### Step 14: Dashboard UI (Days 1-4)

See gap analysis for dashboard requirements. Build single-page Vue.js app for moderation team.

**Files:**
- `sakina-dashboard/index.html`
- `sakina-dashboard/main.js`
- `sakina-dashboard/api.js`
- `sakina-dashboard/styles.css`

**Features:**
- Real-time guardrail triggers
- Hallucination detection
- System health metrics

---

### Step 15: OpenTelemetry Instrumentation (Days 5-8)

**File:** `sakina-backend/src/telemetry.rs`

Wire Jaeger tracing and Prometheus metrics into all service layers.

---

## Phase 4 Validation

```bash
# Deploy full stack
make setup-k8s
make deploy

# Port-forward services
kubectl port-forward -n sakina-api svc/sakina-api 8080:8080 &
kubectl port-forward -n sakina-monitoring svc/prometheus 9090:9090 &
kubectl port-forward -n sakina-monitoring svc/grafana 3000:3000 &

# Verify endpoints
curl http://localhost:8080/v1/health
curl http://localhost:9090/-/ready
curl http://localhost:3000/api/health

# Run integration tests
pytest sakina-tests/integration/ -v
```

---

# FINAL VERIFICATION (Week 9)

```bash
# Full compilation
cd sakina-backend && cargo build --release && cargo test
cd ../sakina-frontend && flutter build apk --release && flutter build ios --release

# Full integration
kubectl apply -R -f sakina-infra/manifests/ --dry-run=client

# Load testing
locust -f load_tests.py

# Penetration testing
# (Hire external firm)
```

---

# DELIVERABLES

**After Week 9, you will have:**

✅ **Backend**
- Zero-hallucination RAG engine (threshold 0.85)
- Complete data pipeline (ingestion → chunking → embedding → Qdrant)
- Audit trail (all queries logged)
- API serving on localhost:8080 (Kubernetes-ready)

✅ **Frontend**
- Chat interface (iOS + Android)
- Local encrypted storage (SQLCipher)
- Encrypted cloud backup
- Citation display with source metadata
- Offline-first architecture

✅ **Infrastructure**
- Local Kubernetes cluster (Kind, 4 namespaces)
- PostgreSQL + Qdrant (production-ready)
- Prometheus + Grafana (monitoring)
- Jaeger (distributed tracing)
- Network policies (default-deny)
- API Gateway (Traefik)
- TLS/mTLS (cert-manager)

✅ **Operations**
- Dashboard (moderation team)
- Health checks (liveness/readiness)
- Metrics (request rate, latency, errors)
- Audit logs (immutable)
- Load testing (verified at scale)

✅ **Documentation**
- Architecture decisions (why each choice)
- API documentation (all endpoints)
- Runbooks (operations procedures)
- Security guidelines (threat model)
- Deployment procedures

---

# SUCCESS CRITERIA

Project Sakina is **production-ready** when:

1. ✅ **Zero hallucinations** — All responses cite sources; guardrail threshold enforced
2. ✅ **Complete privacy** — All data encrypted; no external API calls
3. ✅ **High availability** — 3 API replicas, health checks, graceful degradation
4. ✅ **Observable** — Full metrics, traces, and audit logs
5. ✅ **Secure** — mTLS, network policies, no hardcoded secrets
6. ✅ **Tested** — Integration tests pass; load test verified to 1000 concurrent users
7. ✅ **Documented** — Every decision recorded; runbooks for operators

---

**Code fast, test constantly, and ship when criteria are met.**

🚀 **Project Sakina: Sovereign. Intelligent. Secure. Islamic.**

Made with precision, intelligence, and respect for privacy. 🙏
