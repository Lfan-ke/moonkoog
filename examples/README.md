# Examples

Runnable `main` packages that use the public moonkoog API — one per feature
cluster, each building something small end to end. Read them for the shape of the
real calls; run them to see the actual bytes, decoded values, and traces a feature
produces. None call a live model: clients are scripted and wire bytes are fixed, so
every run is deterministic.

```bash
moon run examples/01-prompt-to-wire --target native
```

Every example rides packages that reach the network over `moonllm` and the async
runtime, so they run on the `native` backend — hence `--target native`. The work
itself is in-process and synchronous at the seam it demonstrates.

## Prompt, model, and tools

| # | Example | What it shows |
| --- | --- | --- |
| 01 | [`prompt-to-wire`](01-prompt-to-wire/) | Build a prompt (system + user), register a tool, force it with `LLMParams.tool_choice`, and map the whole request to the Anthropic Messages body — the request half of a client, `to_anthropic_request`, on its own |
| 02 | [`prompt-model`](02-prompt-model/) | The prompt/message model itself: a multi-turn `PromptBuilder`, the four `MessagePart` kinds, `text_content`/`tool_calls`, non-mutating `append`, and the `ToJson` wire form of messages and `LLMParams` |
| 03 | [`model-catalog`](03-model-catalog/) | The `LLMProvider` list and `LLModel` catalog — context windows, the per-provider `*_models()` lists, and `LLModel::supports` over the `LLMCapability` set (tools, tool-choice, vision, thinking, embed, moderation) |
| 04 | [`tool-schema`](04-tool-schema/) | The tool/registry model: every `ToolParameterType` variant (including `TObject`/`TList`/`TAnyOf`/`TEnum`) rendered by `to_json_schema`, a `ToolDescriptor` composed into one schema, and `ToolRegistry` add/descriptors/get_tool |
| 05 | [`prebuilt-tools`](05-prebuilt-tools/) | The ready-made tools driven through `execute_raw`: file tools over a `MemFileSystem`, `RegexSearchTool`, the shell tool over an injected `ShellExecutor`, and the `ExitTool`/`SayToUser`/`AskUser` user-I/O tools |
| 06 | [`anthropic-response`](06-anthropic-response/) | The response half of the client: `from_anthropic_response` maps a Messages reply (text + `tool_use`) back into a Koog message, and the `AnthropicClient`/`OpenAiCompatibleClient` report their provider |

## The agent and its strategies

| # | Example | What it shows |
| --- | --- | --- |
| 07 | [`agent-loop`](07-agent-loop/) | The `AIAgent` tool-calling loop end to end (Koog's `singleRunStrategy`): request, run the tool the model asked for, feed the result back, finish on plain text — the answer derived from the tool's real output |
| 08 | [`strategy-graph`](08-strategy-graph/) | The strategy-graph DSL: the prebuilt `single_run`/`chat`/`react` strategies, a hand-wired start→llm→finish graph, and a `custom_node` handler over a `NodeSession`, each run against a scripted client |
| 09 | [`structured-output`](09-structured-output/) | `request_structured`: ask the model for a value matching a `StructuredSchema`, extract the JSON from prose or a code fence, parse it, and re-prompt on malformed output |
| 10 | [`agent-events`](10-agent-events/) | The `EventHandler` hooks: every lifecycle callback wired to a log so one tool-loop run prints its whole shape — agent start, each node visit, the two LLM calls bracketing the tool call, completion |
| 11 | [`client-wrappers`](11-client-wrappers/) | The `LLMClient` wrappers: `CachingClient` (served-from-cache), `RetryingClient` (transient retry), `MultiLLMClient` (provider routing + fallback), and the default `execute_streaming` single-chunk contract |
| 12 | [`moderation`](12-moderation/) | `LLMClient.moderate`: the default reports nothing harmful; a moderation-capable client returns a `ModerationResult` whose per-category flags `is_category_detected` queries |
| 13 | [`choice-selection`](13-choice-selection/) | `ChoiceSelectionStrategy`: `FirstChoice` takes index 0, `LLMChoiceSelector` asks a judge model which candidate to keep |
| 14 | [`history-compression`](14-history-compression/) | `HistoryCompressor`: `WholeHistory` folds a conversation into one summary; `FromLastN` summarizes older turns and keeps the last N verbatim |
| 15 | [`critic`](15-critic/) | `LLMCritic`: a judge model reviews an answer and returns a `CriticVerdict` — CORRECT passes, otherwise it fails and extracts the feedback |
| 16 | [`planner`](16-planner/) | `LLMPlanner`: parse a plan from the model, execute each step threading state, mark it done, drive to completion with `run`, and keep/replan on the critic's verdict |
| 17 | [`goap`](17-goap/) | `goap_plan`: goal-oriented action planning — least-cost action sequence from a start state to a goal over `GoapAction`/`GoapGoal`, pure search, no model |
| 18 | [`agent-serving`](18-agent-serving/) | `AgentEndpoint`: serve an agent as an HTTP handler — a well-formed body returns the output as JSON, `handle_sse` frames it as an SSE event, a malformed body is a 400 |
| 19 | [`agent-checkpoint`](19-agent-checkpoint/) | `AgentStorage` typed key/value round-tripped through JSON (snapshot/restore) and a full `AgentCheckpoint` saved to `InMemoryPersistence`, read back latest-first |

## Memory, retrieval, and interop

| # | Example | What it shows |
| --- | --- | --- |
| 20 | [`memory`](20-memory/) | `InMemoryProvider`: facts about a `MemorySubject` under a `MemoryScope` — `Concept`s, single/multiple `Fact`s, `load` by concept vs `load_all`, and bucket isolation by subject and scope |
| 21 | [`persistence`](21-persistence/) | `PersistenceStorageProvider`: save `AgentCheckpoint`s per session, list them in order or read latest-first to resume, isolated by session |
| 22 | [`embeddings`](22-embeddings/) | The `Vector` similarity math (dimension, magnitude, dot product, cosine, euclidean) and the deterministic `MockEmbedder` behind the `Embedder` contract |
| 23 | [`rag`](23-rag/) | `EmbeddingStorage` embed-on-add / rank-on-search, the `rank_by_similarity` primitive with min_score/limit/offset, and the `VectorStore` index underneath |
| 24 | [`a2a-card`](24-a2a-card/) | The Agent-to-Agent `AgentCard`: transports, provider, skills, capabilities — round-tripped through its wire JSON and fetched by `resolve_agent_card` |
| 25 | [`a2a-protocol`](25-a2a-protocol/) | The A2A JSON-RPC protocol end to end over a real `A2AServer`: `message/send`, `tasks/get`, `tasks/cancel`, push configs, `parse_sse`, and `stream_message` into typed events |
| 26 | [`mcp`](26-mcp/) | The Model Context Protocol adapter: expose a `ToolRegistry` as an `McpServer`, discover and call it from an `McpClient` over `tools/list`+`tools/call`, and map a full JSON-Schema with `parse_tool` |
| 27 | [`agent-tracing`](27-agent-tracing/) | `EventHandler::tracing` rendering a whole run to a `LineTrace`, an interceptor rewriting the prompt on its way to the client, `on_tool_call_failed` reporting a tool that raised, and the `ResponseMetaInfo` token counts riding back on each reply |
