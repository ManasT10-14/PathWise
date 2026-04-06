# Domain Pitfalls

**Domain:** AI-powered career guidance platform (Vertex AI + Flutter + Firebase + FastAPI)
**Researched:** 2026-04-07
**Confidence:** HIGH (verified across official docs, GitHub issues, community reports)

---

## Critical Pitfalls

Mistakes that cause rewrites, data loss, security breaches, or production outages.

---

### Pitfall 1: Gemini 2.5 Flash Structured JSON Output Failures

**What goes wrong:** Gemini 2.5 Flash intermittently produces broken JSON: truncated responses mid-object, `json` prefix with backticks instead of raw JSON, infinite token repetition until max_tokens, and 400 errors claiming "JSON mode is not enabled for this model." This directly threatens the 4-step prompt chain (goal analyzer, skill gap, roadmap planner, resource curator) because each step must parse the previous step's JSON output.

**Why it happens:** Google has repeatedly changed structured output behavior across model versions without warning. In August 2025, the model suddenly stopped returning valid JSON structures. The 2.5-flash model also has known incompatibility between tool-calling history and structured output mode -- when tool calls are present in message history, structured output fails entirely. Token-heavy responses sometimes hit internal limits before completing valid JSON.

**Consequences:**
- A single broken JSON response cascades through the entire 4-step chain, producing garbage roadmaps
- Users see error screens or receive malformed career guidance
- Retry loops burn through quota and money without user benefit

**Warning signs:**
- Responses ending with `"finish_reason": "MAX_TOKENS"` instead of `"STOP"`
- JSON parsing exceptions spiking in logs
- Inconsistent response lengths for similar prompts

**Prevention:**
1. Always use `response_mime_type: "application/json"` WITH a `response_schema` (Pydantic model or JSON schema) -- do not rely on prompt instructions alone for JSON formatting
2. Implement a JSON validation + repair layer after every Gemini call: try `json.loads()`, and if it fails, attempt truncation repair (find last valid closing brace/bracket)
3. Set `max_output_tokens` generously (at least 2x expected output size) to prevent truncation
4. Wrap each prompt chain step in a retry decorator with exponential backoff (retry on 429, 500, 502, 503, 504 and on JSON parse failures), max 3 attempts per step
5. Never mix tool-calling and structured output mode in the same request
6. Pin a specific model version (e.g., `gemini-2.5-flash-001`) rather than using the auto-updating `gemini-2.5-flash` alias -- model behavior changes without notice

**Detection:** Log raw responses before parsing. Set up alerting on JSON parse failure rate exceeding 2%.

**Phase relevance:** Backend/AI phase -- must be addressed when building the prompt chain. This is the single highest-risk item in the entire project.

**Sources:**
- [2.5-flash stopped delivering true json structures (Google AI Forum)](https://discuss.ai.google.dev/t/2-5-flash-stopped-delivering-true-json-structures/100175)
- [Inconsistent Structured outputs between 2.0 and 2.5 (GitHub)](https://github.com/googleapis/python-genai/issues/706)
- [Gemini-2.5-flash repeats tokens until max-tokens (Google AI Forum)](https://discuss.ai.google.dev/t/gemini-2-5-flash-repeats-tokens-until-max-tokens-reached-in-structured-output/107176)
- [Structured output docs (Google Cloud)](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/multimodal/control-generated-output)

---

### Pitfall 2: Prompt Chain Error Propagation (Silent Corruption)

**What goes wrong:** In a 4-step sequential prompt chain (goal analyzer -> skill gap -> roadmap planner -> resource curator), a subtly wrong output from step 1 does not throw an error but poisons all downstream steps. For example, the goal analyzer misidentifies a user's target role, and the skill gap analysis proceeds confidently on the wrong premise. The user receives a polished, confident, completely irrelevant roadmap.

**Why it happens:** LLMs do not raise exceptions for semantic errors. JSON validates fine structurally even when the content is nonsensical. Developers build retry logic for crashes but not for semantic drift. Each step trusts its input implicitly.

**Consequences:**
- Users receive plausible but wrong career guidance (worse than an error -- erodes trust silently)
- No error logs to diagnose the problem
- Support burden increases as users report "the AI doesn't understand me"

**Warning signs:**
- User feedback saying recommendations don't match their goals
- Roadmap skills that don't logically connect to the stated career target
- Anomalously short or generic skill gap analyses

**Prevention:**
1. Add confidence scores to every prompt chain step output (require the model to self-assess confidence 0.0-1.0 as a schema field)
2. Add a validation gate between steps: if step 1 outputs a career_goal, have the user confirm it before proceeding to step 2 (at least for the initial analysis)
3. Include the original user input in EVERY step's prompt, not just step 1 -- so downstream steps can cross-reference
4. Log the full chain: store each step's input/output in Firestore under the roadmap document for debugging
5. Implement a lightweight "chain coherence check" -- a final prompt that reviews the full chain output against the original user request and flags mismatches

**Detection:** Compare goal_analyzer output role against user's stated career goal string similarity. Flag if below 70% semantic match.

**Phase relevance:** Backend/AI phase -- design into the prompt chain architecture from day one. Retrofitting validation gates is painful.

---

### Pitfall 3: Client-Side Payment Trust (Razorpay)

**What goes wrong:** The Flutter app currently has Razorpay integrated in test mode. When moving to production, developers commonly trust the client-side callback (`onPaymentSuccess`) as proof of payment and immediately grant access to paid features. An attacker can spoof the callback, modify the `razorpay_payment_id`, or replay old payment IDs.

**Why it happens:** Razorpay's Flutter SDK fires a client-side success callback that feels authoritative. The "happy path" works in testing. Developers skip server-side verification because it requires building an additional API endpoint.

**Consequences:**
- Users get free consultations (direct revenue loss)
- Financial reconciliation fails (Razorpay dashboard shows different numbers than your database)
- Potential legal/compliance issues with unverified transactions

**Warning signs:**
- Payment records in Firestore that don't match Razorpay dashboard
- Consultation access granted but no corresponding Razorpay capture event
- Any client-side code that writes a `paid: true` field to Firestore

**Prevention:**
1. Server-side order creation: FastAPI creates the Razorpay order via `razorpay.order.create()`, stores order_id + amount + consultation_id in Firestore, returns order_id to Flutter
2. Server-side signature verification: After client callback, Flutter sends `razorpay_payment_id`, `razorpay_order_id`, `razorpay_signature` to FastAPI, which verifies using `razorpay.utility.verify_payment_signature()`
3. NEVER update Firestore payment status from Flutter directly -- only the FastAPI server (via Admin SDK) marks payments as confirmed
4. Implement webhook handler (`payment.captured` event) as the authoritative payment confirmation, with the client-side flow as the fast path
5. Store Razorpay webhook secret separately from API keys; rotate periodically

**Detection:** Reconciliation job: daily cron comparing Firestore payment records against Razorpay API `payments.all()`.

**Phase relevance:** Payment hardening phase -- must happen before any real money flows. Block production launch until server-side verification is confirmed working.

**Sources:**
- [Razorpay Integration Steps (Python SDK)](https://razorpay.com/docs/payments/server-integration/python/integration-steps/)
- [Razorpay Webhook Best Practices](https://razorpay.com/docs/webhooks/best-practices/)
- [Razorpay Third-Party Validation Best Practices](https://razorpay.com/docs/payments/third-party-validation/best-practices/)

---

### Pitfall 4: Webhook Idempotency and Event Ordering (Razorpay)

**What goes wrong:** Razorpay retries webhooks when your server is slow or down. Without idempotency, processing the same `payment.captured` event twice grants double credits or creates duplicate consultation records. Separately, Razorpay does NOT guarantee event ordering -- a `payment.failed` webhook can arrive AFTER `payment.captured`, overwriting a successful payment with a failure state.

**Why it happens:** Developers handle webhooks as simple POST handlers without checking whether the event was already processed. Status updates use direct field assignment (`status = event.status`) instead of state-machine transitions.

**Consequences:**
- Duplicate consultation bookings for a single payment
- Successful payments incorrectly marked as failed (user loses access, contacts support)
- Database inconsistency between payment status and consultation status

**Warning signs:**
- Duplicate entries in consultations collection with same payment_id
- User complaints about "paid but can't access" consultation
- Webhook endpoint returning 500 errors (triggers Razorpay retries, compounding the problem)

**Prevention:**
1. Store a `processed_webhook_ids` set (or check `payments/{payment_id}.webhook_processed` flag) -- skip if already processed
2. Use state machine transitions, not direct assignment: only allow `pending -> captured`, `pending -> failed`, never `captured -> failed`
3. Respond to Razorpay webhook with 200 immediately after validation and storing the event, then process asynchronously (background task in FastAPI)
4. Set up Razorpay webhook retry policy understanding: they retry for up to 24 hours. Your endpoint MUST respond within 5 seconds
5. Use Firestore transactions when updating payment status to prevent race conditions between webhook and client-side verification path

**Detection:** Monitor for duplicate webhook event IDs in logs. Alert on any `captured -> failed` status transition.

**Phase relevance:** Payment hardening phase -- implement alongside server-side verification (Pitfall 3).

**Sources:**
- [Razorpay Webhook Validate and Test](https://razorpay.com/docs/webhooks/validate-test/)
- [INVALID_WEBHOOK_SIGNATURE diagnosis](https://drdroid.io/integration-diagnosis-knowledge/razorpay-invalid-webhook-signature)
- [FastAPI webhook integration guide](https://www.shekharverma.com/python-integrating-payment-webhooks-with-fastapi-in-python-2/)

---

### Pitfall 5: Firestore Security Rules vs Admin SDK Dual-Access Confusion

**What goes wrong:** The Flutter app uses Firestore client SDK (subject to security rules) while FastAPI uses Firebase Admin SDK (bypasses ALL security rules). Developers write security rules assuming they protect all access paths, but the Admin SDK ignores them entirely. Conversely, developers may write overly restrictive rules that block the Flutter client from reading data the server wrote, or leave rules wide open thinking "the server needs access."

**Why it happens:** Firebase Admin SDK authenticates via service account and is designed to bypass rules for trusted server operations. This is documented but easy to forget when designing rules for 5 collections (users, experts, consultations, roadmaps, reviews) with mixed client/server write patterns.

**Consequences:**
- Security rules that appear comprehensive but leave server-written data unprotected from other attack vectors
- Flutter client unable to read roadmaps or payment status that FastAPI wrote (rules block it)
- Rules set to `allow read, write: if true` because "it was the only way to make it work" -- exposing all data publicly

**Warning signs:**
- Flutter app showing "permission-denied" errors after server writes data
- Security rules containing `allow read, write: if true` on any collection
- No distinction in rules between fields the client can write vs fields only the server should write

**Prevention:**
1. Map every Firestore collection to its access pattern: who reads (client/server/both), who writes (client/server/both), which fields
2. Use field-level validation in security rules: clients can write `request.consultation_id` but NOT `payment_status` (only server writes that via Admin SDK)
3. Adopt a "default deny" base rule, then explicitly allow specific operations
4. Server-written fields should be in sub-documents or use naming conventions (e.g., `_server_` prefix) that security rules block clients from modifying
5. Test rules with the Firebase Emulator Suite -- it shows exactly which rules allow/deny which operations
6. Document the access matrix: a table of collection x operation x actor (client/server/admin)

**Detection:** Firebase Console "Rules Playground" for manual testing. Automated rule tests in CI using `@firebase/rules-unit-testing`.

**Phase relevance:** Infrastructure/security phase -- design the access matrix before writing any security rules. Must be finalized before production launch.

**Sources:**
- [Firebase Security Rules + Admin SDK Tips](https://firebase.blog/posts/2019/03/firebase-security-rules-admin-sdk-tips/)
- [Fix insecure rules (Firebase)](https://firebase.google.com/docs/firestore/security/insecure-rules)
- [Firestore role-based access](https://firebase.google.com/docs/firestore/solutions/role-based-access)

---

## Moderate Pitfalls

Mistakes that cause significant rework, performance degradation, or user experience issues.

---

### Pitfall 6: BackdropFilter Glassmorphism Performance Collapse

**What goes wrong:** Applying `BackdropFilter` with `ImageFilter.blur` for glassmorphism UI effects causes severe frame drops (below 30fps) on mid-range Android devices, especially when multiple blurred elements are on screen simultaneously or when blur is applied over scrolling content. On iOS with the Impeller engine, the problem is even worse -- documented as a known Impeller issue.

**Why it happens:** Each `BackdropFilter` forces the GPU to re-render the entire area behind it every frame. Multiple overlapping blur effects multiply this cost. Scrolling content behind blur means the blurred region must be recomputed every frame. This is the most expensive single widget in Flutter's rendering pipeline.

**Consequences:**
- Janky scrolling on the main screens users interact with most
- "Beautiful" UI that feels sluggish and cheap
- Battery drain from constant GPU overdraw
- Users on budget Android phones (common for Indian students -- the target demographic) get the worst experience

**Warning signs:**
- Frame times exceeding 16ms in Flutter DevTools performance overlay
- Rasterizer thread (GPU) showing higher load than UI thread
- User complaints about "laggy" or "slow" app specifically on screens with frosted glass effects

**Prevention:**
1. Use `BackdropGroup` (Flutter 3.29+) to batch multiple `BackdropFilter` widgets into a single render layer -- 40-60% performance improvement
2. Limit `BackdropFilter` to small, bounded elements (cards, dialogs, bottom sheets) -- NEVER full-screen blur
3. Wrap blurred elements in `ClipRRect` to constrain the repaint area
4. Cache static blurred backgrounds using `RepaintBoundary` -- prevents redrawing every frame
5. For scrolling lists behind blur, use a pre-rendered blurred snapshot image instead of live `BackdropFilter`
6. Test on a budget Android device (Redmi/Realme under INR 10,000) -- if it stutters there, simplify the effect
7. Consider reducing blur sigma (5-8 instead of 15-20) -- visual effect is similar but render cost drops significantly
8. Provide a "reduce animations" accessibility toggle that replaces blur with solid semi-transparent backgrounds

**Detection:** Profile with `flutter run --profile` and check raster thread in DevTools. Target: every frame under 16ms.

**Phase relevance:** UI overhaul phase -- make performance testing part of every UI PR, not a post-hoc optimization pass.

**Sources:**
- [iOS BackdropFilter Performance Issues with Impeller (GitHub #161297)](https://github.com/flutter/flutter/issues/161297)
- [Impeller Blur BackdropFilter performance degradation (GitHub #126353)](https://github.com/flutter/flutter/issues/126353)
- [Implementing Glassmorphism in Flutter (icreationsent)](https://icreationsent.com/blog/flutter-glassmorphism-workarounds)
- [Flutter performance: diagnose jank and FPS drops (2026)](https://chdr.tech/en/2026/03/05/flutter-performance-diagnose-jank-fps/)

---

### Pitfall 7: Animation Widget Tree Rebuild Storm

**What goes wrong:** Wrapping large widget subtrees in animation controllers causes the entire subtree to rebuild 60 times per second. Developers animate a container's opacity or position by putting the animation value in the parent widget's `build()` method, forcing all children to rebuild even though only one property changed.

**Why it happens:** Flutter's reactive model rebuilds the widget subtree from where `setState` is called downward. Placing `AnimationController.addListener(() => setState(() {}))` at a high level in the tree means everything below rebuilds per frame.

**Consequences:**
- Smooth animations on high-end devices but severe jank on mid-range ones
- Compound effect with glassmorphism -- blur + animation rebuild = unusable
- Battery drain and thermal throttling on prolonged use

**Prevention:**
1. Use `AnimatedBuilder` or `AnimatedWidget` to isolate animation rebuilds to the smallest possible subtree
2. Mark all static child widgets as `const` -- canonicalization prevents rebuild
3. Wrap animated sections in `RepaintBoundary` to prevent paint propagation to siblings
4. Use `Transform` widgets for position/rotation/scale animations -- these operate at the compositing layer (GPU) and don't trigger layout
5. Avoid animating properties that trigger layout (width, height, padding) -- animate `Transform.translate` and `Opacity` instead
6. Use `TweenAnimationBuilder` for simple one-off animations instead of managing `AnimationController` lifecycle manually

**Detection:** Enable "Show repaint rainbow" in Flutter DevTools -- regions that flash constantly are over-rebuilding.

**Phase relevance:** UI overhaul phase -- establish animation patterns in the first animated component, then reuse across all screens.

**Sources:**
- [Flutter Performance Optimization 2026 (DEV Community)](https://dev.to/techwithsam/flutter-performance-optimization-2026-make-your-app-10x-faster-best-practices-2p07)
- [Is Animation Slowing Your Flutter App (2026)](https://copyprogramming.com/howto/is-animation-slow-your-app-flutter)
- [Flutter animation performance guide (Digia)](https://www.digia.tech/post/flutter-animation-performance-guide)

---

### Pitfall 8: Vertex AI Quota Exhaustion and Cost Runaway

**What goes wrong:** The 4-step prompt chain means every user analysis consumes 4 API calls with potentially large token counts. During development, a retry loop on broken JSON (Pitfall 1) can burn through daily quota in minutes. In production, a viral day or a bug causing infinite retries can generate a surprise cloud bill.

**Why it happens:** Gemini 2.5 Flash quota is per-project, measured in requests-per-minute AND tokens-per-minute. Retry loops compound both. The December 2025 quota adjustments caught many developers off guard with lower limits. There is no built-in spend cap on Vertex AI -- billing continues until you hit quota or manually stop it.

**Consequences:**
- 429 errors for all users when one user's retry loop exhausts the shared quota
- Unexpected GCP bills (hundreds of dollars from a development bug)
- Complete service outage for the AI features during quota reset periods

**Warning signs:**
- Increasing 429 error rates in FastAPI logs
- GCP billing alerts
- Retry counts per request averaging above 1.5

**Prevention:**
1. Implement per-user rate limiting in FastAPI: max 3 full analyses per user per day, max 1 replan per day
2. Set a hard retry ceiling: max 3 retries per prompt chain step, then fail gracefully with a user-friendly message
3. Set up GCP budget alerts at 50%, 80%, and 100% of monthly budget with email + Pub/Sub notification
4. Use `gemini-2.5-flash` (not Pro) for cost efficiency -- Flash is designed for high-volume, lower-cost usage
5. Cache repeat analyses: if a user re-analyzes the same goal within 24 hours, return the cached result from Firestore
6. Monitor token usage per request and set a max_input_tokens guard (truncate overly long user inputs)
7. Consider a circuit breaker pattern: if error rate exceeds 50% in a 5-minute window, stop making API calls and show a "service temporarily unavailable" message

**Detection:** GCP Cloud Monitoring dashboard tracking `vertex_ai/prediction/request_count` and `vertex_ai/prediction/token_count` metrics. Alert on anomalies.

**Phase relevance:** Backend/AI phase -- implement rate limiting and cost controls before any production deployment.

**Sources:**
- [Vertex AI Quotas and Limits (Google Cloud)](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/quotas)
- [Rate limits and quotas (Firebase AI Logic)](https://firebase.google.com/docs/ai-logic/quotas)
- [Retry strategy (Vertex AI)](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/retry-strategy)

---

### Pitfall 9: Firebase SDK Naming Migration Trap (firebase_vertexai -> firebase_ai)

**What goes wrong:** The Flutter package `firebase_vertexai` has been deprecated and replaced by `firebase_ai` (renamed to "Firebase AI Logic" in May 2025). Tutorials, Stack Overflow answers, and even recent Medium articles still reference the old package. Starting the project with `firebase_vertexai` means a forced migration later with breaking API changes.

**Why it happens:** The rename is recent and documentation lags. The old package still works but receives no new features. Breaking changes include: `citationSources` renamed to `citations`, `CitationSource` type renamed to `Citation`, parameter order changes for `systemInstruction`.

**Consequences:**
- Building on a deprecated package that will stop receiving updates
- Migration rework when the old package is eventually removed
- Missing access to new features (Gemini Developer API support) only available in `firebase_ai`

**Warning signs:**
- Import statements containing `firebase_vertexai`
- Following tutorials that use `FirebaseVertexAI` class instead of `FirebaseAI`

**Prevention:**
1. Start with `firebase_ai` package from day one -- do NOT use `firebase_vertexai`
2. Use `FirebaseAI.vertexAI()` factory (not `FirebaseVertexAI.instance`)
3. However, for this project the Flutter client does NOT call Vertex AI directly -- the FastAPI backend does. The Flutter client should only call FastAPI endpoints via HTTP. Using `firebase_ai` client-side is unnecessary and adds complexity

**Important note for Pathwise:** Since the architecture has FastAPI calling Vertex AI server-side (via the Python `google-cloud-aiplatform` SDK or `google-genai` SDK), the Flutter app should NOT include `firebase_ai` or `firebase_vertexai` at all. The existing `AiRoadmapService` stub should be replaced with an HTTP client calling FastAPI, not with a direct Vertex AI client.

**Phase relevance:** Architecture phase -- clarify the boundary: Flutter calls FastAPI, FastAPI calls Vertex AI. No AI SDK in the Flutter app.

**Sources:**
- [Migrate to Firebase AI Logic SDKs](https://firebase.google.com/docs/ai-logic/migrate-to-latest-sdk)
- [firebase_ai vs firebase_vertexai (FlutterFire Discussion)](https://github.com/firebase/flutterfire/discussions/17396)

---

### Pitfall 10: Firestore Document Contention on Roadmap Updates

**What goes wrong:** The `Roadmap` document gets written by both the Flutter client (user marks a stage complete, updates progress percentage) and the FastAPI server (AI replanning updates phases, adds new stages). Concurrent writes to the same document cause Firestore transaction retries and potential data loss when one write overwrites the other.

**Why it happens:** Firestore transactions use optimistic concurrency: they read, compute, then try to write. If another write happened in between, the transaction retries. Client SDK transactions retry up to 5 times then fail. When the user completes a stage at the same moment the server triggers a replan, one operation will fail or overwrite the other.

**Consequences:**
- User progress lost (server replan overwrites client progress update)
- Replan results lost (client update overwrites server replan)
- Flickering UI as Firestore listeners receive conflicting states
- Flutter `cloud_firestore` has a known bug where transactions don't retry properly after concurrent writes (GitHub #10905)

**Warning signs:**
- Intermittent "transaction failed" errors in either client or server logs
- User complaints about lost progress
- Roadmap data that oscillates between two states in the realtime listener

**Prevention:**
1. Split the Roadmap document: user-mutable fields (`stageProgress`, `completedAt`) in a `roadmaps/{id}/progress/{stageId}` subcollection, AI-generated fields (`phases`, `resources`, `skills`) in the parent document
2. Client only writes to progress subcollection; server only writes to parent document -- eliminating contention entirely
3. If splitting is too complex, use `FieldValue.increment()` and `FieldValue.arrayUnion()` for atomic updates instead of read-modify-write
4. Implement an `updatedBy` field with `client` or `server` value and a `lastUpdated` timestamp for conflict detection
5. Use Firestore `update()` with specific fields instead of `set()` with full document replacement

**Detection:** Log all Firestore write operations with source (`client`/`server`) and document path. Alert on concurrent writes to the same document within 5 seconds.

**Phase relevance:** Backend/AI phase (data model design) -- must be decided before implementing replanning or progress tracking.

**Sources:**
- [Firestore Transaction Serializability and Isolation](https://firebase.google.com/docs/firestore/transaction-data-contention)
- [Race Conditions in Firestore (Medium)](https://medium.com/quintoandar-tech-blog/race-conditions-in-firestore-how-to-solve-it-5d6ff9e69ba7)
- [cloud_firestore Transaction not retrying (GitHub #10905)](https://github.com/firebase/flutterfire/issues/10905)

---

## Minor Pitfalls

Issues that cause friction, debugging time, or suboptimal outcomes but are recoverable.

---

### Pitfall 11: Service Account Key Exposure

**What goes wrong:** The FastAPI server needs a Firebase service account JSON key to initialize the Admin SDK. Developers commit this key to the repository, hardcode the path, or include it in Docker images.

**Prevention:**
1. Add `*.json` service account files to `.gitignore` immediately
2. Use environment variable `GOOGLE_APPLICATION_CREDENTIALS` pointing to the key file path
3. In production, use GCP Secret Manager or workload identity instead of key files
4. Never include the key in Docker images -- mount it at runtime or use environment injection

**Phase relevance:** Infrastructure phase -- set up credential management before writing any FastAPI code.

---

### Pitfall 12: FastAPI Cold Start Blocking AI Responses

**What goes wrong:** FastAPI endpoints calling Vertex AI block the async event loop if the Vertex AI client is initialized synchronously or if blocking SDK calls are made without `asyncio` wrapping. This causes all other requests to queue behind one slow AI call.

**Prevention:**
1. Initialize the Vertex AI client at application startup (in a `lifespan` handler), not per-request
2. Use `asyncio.to_thread()` or `run_in_executor()` for blocking Vertex AI SDK calls if the SDK does not offer native async support
3. Set appropriate `timeout` values on Vertex AI requests (30s for generation, not the default 600s)
4. Consider a background task queue (Celery, or even simple FastAPI `BackgroundTasks`) for the full 4-step chain, returning a job ID to Flutter and polling for completion

**Phase relevance:** Backend/AI phase -- architecture decision needed early: synchronous request-response vs async job queue.

---

### Pitfall 13: Gemini Model Version Deprecation

**What goes wrong:** Gemini 2.0 Flash was retired from new customers on March 6, 2026 and shuts down entirely June 1, 2026. Developers hardcoding model names without a configuration system must redeploy to change models.

**Prevention:**
1. Store the model name in an environment variable or remote config, not hardcoded in source
2. Use `gemini-2.5-flash` (current stable) as the target model
3. Monitor the [Gemini deprecation page](https://ai.google.dev/gemini-api/docs/deprecations) monthly
4. Build model name as a FastAPI config parameter that can be changed without redeployment

**Phase relevance:** Backend/AI phase -- trivial to implement correctly from the start, painful to fix later.

**Sources:**
- [Gemini deprecations (Google AI)](https://ai.google.dev/gemini-api/docs/deprecations)
- [Model versions and lifecycle (Vertex AI)](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/learn/model-versions)

---

### Pitfall 14: Missing App Check on Firebase Client

**What goes wrong:** Without Firebase App Check, anyone can call Firestore directly using the project's public Firebase config (visible in the APK). Security rules help but an attacker with a valid Firebase Auth token can read/write any document their rules allow -- including creating fake consultations or reading other users' roadmaps.

**Prevention:**
1. Enable Firebase App Check with Play Integrity provider (Android)
2. Enforce App Check on Firestore in the Firebase Console
3. Also enforce App Check on Cloud Functions if used
4. Note: App Check does NOT apply to Admin SDK calls (server-side) -- this is correct behavior

**Phase relevance:** Security/infrastructure phase -- enable before production launch. Can be added incrementally.

---

### Pitfall 15: Razorpay Test Mode Keys in Production Build

**What goes wrong:** The app currently uses Razorpay test mode. Forgetting to switch to live keys for production builds means payments appear to succeed but no real money moves. Conversely, accidentally using live keys in development charges real cards.

**Prevention:**
1. Use Flutter build flavors or `--dart-define` to inject Razorpay keys per environment
2. Never hardcode Razorpay keys in source -- use environment config
3. Server-side: FastAPI should load Razorpay key_id and key_secret from environment variables
4. Add a startup check: if running in production mode but Razorpay key starts with `rzp_test_`, log a CRITICAL warning and refuse to start

**Phase relevance:** Payment hardening phase -- environment configuration must be production-ready before launch.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation | Severity |
|-------------|---------------|------------|----------|
| Backend/AI prompt chain | Broken JSON from Gemini (Pitfall 1) | Response schema + validation + retry | Critical |
| Backend/AI prompt chain | Silent semantic corruption (Pitfall 2) | Confidence scores + chain logging | Critical |
| Backend/AI prompt chain | Quota exhaustion (Pitfall 8) | Per-user rate limits + budget alerts | Moderate |
| Backend/AI prompt chain | Blocking event loop (Pitfall 12) | Async wrapping or job queue | Moderate |
| Backend/AI prompt chain | Model deprecation (Pitfall 13) | Configurable model name | Minor |
| Payment hardening | Client-side trust (Pitfall 3) | Server-side order + verify | Critical |
| Payment hardening | Webhook idempotency (Pitfall 4) | Dedup + state machine | Critical |
| Payment hardening | Test keys in prod (Pitfall 15) | Build flavor env injection | Minor |
| UI overhaul | BackdropFilter jank (Pitfall 6) | BackdropGroup + bounded blur | Moderate |
| UI overhaul | Animation rebuild storm (Pitfall 7) | AnimatedBuilder + const + RepaintBoundary | Moderate |
| Security/Infrastructure | Firestore rules confusion (Pitfall 5) | Access matrix + emulator testing | Critical |
| Security/Infrastructure | Service account exposure (Pitfall 11) | .gitignore + env vars | Minor |
| Security/Infrastructure | Missing App Check (Pitfall 14) | Enable before production | Minor |
| Data model design | Roadmap document contention (Pitfall 10) | Split client/server write paths | Moderate |
| Architecture | Wrong AI SDK in Flutter (Pitfall 9) | HTTP client to FastAPI, no AI SDK in Flutter | Moderate |

---

## Research Gaps

- **Razorpay production activation process:** Specific steps and timelines for Razorpay live mode activation in India were not deeply researched. May need KYC documentation lead time.
- **Vertex AI regional availability:** Whether `us-central1` vs `asia-south1` affects latency for Indian users was not verified. Worth testing.
- **Flutter `google_fonts` + glassmorphism interaction:** Custom fonts with blur effects may compound rendering cost. Needs profiling on target devices.
- **Firebase Auth + FastAPI token validation edge cases:** Token expiry during long prompt chains (4 steps could take 30+ seconds) may cause auth failures mid-chain.

---

*This document should be revisited at each phase transition to verify pitfalls remain relevant and prevention strategies are being followed.*
