`moonkoog` is an agent framework for MoonBit, transcribed from JetBrains' Koog `1.1.1`: a prompt and message model, an LLM-client contract, a tool registry, and an `AIAgent` that walks a strategy graph to drive the tool-calling loop. It composes with the rest of the moon\* suite — an agent can be served over `moonrpc` or `moonapi`, and its memory can sit in `moonorm`.

# Working here

This repository is one module with a package per concern, and commands run from the root:

| package | target | what it is |
|:--|:--|:--|
| `prompt`, `llm`, `tools`, `memory`, `persistence`, `mcp`, `a2a` | all | the portable core |
| `agent`, `client`, `embeddings`, `rag` | native | anything that reaches an LLM over the network |
| `cmd/smoke` | native | a manual end-to-end run against a real model |

- `moon fmt` before anything else. CI runs `moon fmt && git diff --exit-code`, so an unformatted file fails the build on its own.
- `moon check --target all --deny-warn` and `moon build --target all` are the gate. Warnings are errors, and the native-only packages are simply skipped on the other three backends.
- `moon test --target all`.
- `moon info` regenerates each package's `pkg.generated.mbti`. If a file does not change, your edit is not visible to anyone depending on that package, which usually means the refactor was safe. `moon info` skips packages pinned to `supported_targets = "native"`, so the four network-facing ones have no tracked interface today; the portable seven do.
- CI installs the latest moon on every run, so a toolchain that is behind will disagree with it. Upgrade locally rather than pinning.

# Layout

`prompt/` is the message model, `llm/` the model catalogue and client contract, `tools/` the registry plus the prebuilt file, shell and search tools. `agent/` is the framework proper: `strategy.mbt` holds the graph and the walk that runs it, and `agent.mbt`'s `run` is one wiring of it rather than a loop of its own. Some of the package still sits *beside* the graph rather than inside it — `retry.mbt`, `caching.mbt` and `multi.mbt` decorate an `LLMClient`; `critic.mbt`, `planner.mbt` and `goap.mbt` run loops of their own. Bringing one of those into the graph is real work, not a rename; moderation, streaming, multi-choice and structured output have made that trip and are node kinds now. `events.mbt` is the hook pipeline and `tracing.mbt` the one feature built on it. `client/` has the OpenAI and Anthropic clients, `embeddings/` and `rag/` the vector side, `memory/` and `persistence/` the state between runs, and `mcp/` and `a2a/` the two interop protocols. Tests sit beside their subject as `*_test.mbt` or `*_wbtest.mbt`; `examples/NN-topic/` are runnable one-file demos.

# Things worth knowing

- `AIAgent::run` is not a special-cased loop — it is `run_strategy` wired with `single_run_strategy`, the same way Koog builds its `singleRunStrategy` from the graph DSL. A new agent behaviour is a new strategy, not a new loop.
- A run can be stopped from outside through a `RunHandle`. Koog cancels the agent's coroutine, which can land in the middle of a tool call; the graph walk checks between nodes instead, so the node in progress always finishes and the run raises `AgentStopped` carrying the text it reached. Anything long-running added here should keep that boundary.
- MoonBit has no reflection, so a tool states its JSON schema through an explicit descriptor rather than deriving it from an argument type. That is deliberate and matches `moonapi` and `moonctl`; do not try to infer schemas.
- The transcription is anchored to Koog 1.1.1 and the doc comments cite their Kotlin source file. Keep those citations when adding a feature — they are how the port gets audited against the original, which only works if they are right: an audit found four that named files Koog does not have. `memory/` is the one package deliberately behind — its `Concept`/`Fact`/`MemorySubject` model is Koog 0.7.3's and was removed upstream by 0.8.0.
- The test suite never talks to a real model: every test drives a fixture client, which is what makes the loop assertions mean something. `cmd/smoke` is the one place a live model is reached, and it reads `MOONKOOG_API_KEY`, `MOONKOOG_BASE_URL` and `MOONKOOG_MODEL` from the environment — run it by hand after touching a client, since CI cannot.
