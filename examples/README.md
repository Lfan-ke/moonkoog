# Examples

Runnable `main` packages that use the public moonkoog API. Each folder builds
something small end to end; read them for the shape of the real calls.

```bash
moon run examples/01-prompt-to-wire --target native
```

| # | Example | What it shows | Key API |
| --- | --- | --- | --- |
| 01 | [`prompt-to-wire`](01-prompt-to-wire/) | Build a prompt (system + user), register a tool, force it with `LLMParams`, then map the whole thing to the Anthropic Messages request body and print the wire JSON | `PromptBuilder::new`/`system`/`user`/`params`/`build`, `LLMParams::default`, `ToolChoice::Named`, `ToolRegistry::new`/`add`/`descriptors`, `Tool`, `ToolDescriptor`, `to_anthropic_request`, `LLModel::supports` |

The example rides the `client` package, which speaks the network over
`moonllm` and so is native-only — hence `--target native`. It never calls a
model: `to_anthropic_request` is pure prompt-to-JSON, the request half of a
client on its own, so the output is deterministic. The matching OpenAI mapping
(`to_chat_request`) is internal to the client, exercised through
`OpenAiCompatibleClient::execute`.
