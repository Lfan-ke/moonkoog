///|
/// Raised when the agent loop runs longer than `max_iterations` without the model
/// producing a final text answer.
pub suberror AgentError {
  AgentError(String)
}

///|
/// A single-run agent — Koog's `AIAgent` as built by its ergonomic factory over
/// the default `singleRunStrategy`. It pairs an LLM executor + model with a tool
/// registry and an optional system prompt, and runs the tool-calling loop.
/// Source: agents/agents-core/.../agent/{AIAgent,AIAgentFactory}.kt.
pub struct AIAgent {
  executor : &LLMClient
  model : @llm.LLModel
  tool_registry : @tools.ToolRegistry
  system_prompt : String?
  max_iterations : Int
}

///|
/// Build an agent. `max_iterations` defaults to Koog's 50.
pub fn AIAgent::new(
  executor : &LLMClient,
  model~ : @llm.LLModel,
  tool_registry? : @tools.ToolRegistry = @tools.ToolRegistry::new(),
  system_prompt? : String? = None,
  max_iterations? : Int = 50,
) -> AIAgent {
  { executor, model, tool_registry, system_prompt, max_iterations }
}

///|
/// Run the agent on `input`, returning the final assistant text. Koog's default
/// `singleRunStrategy`: request a completion; return it if it is plain text;
/// otherwise run every requested tool, feed the results back, and request again,
/// bounded by `max_iterations`.
///
/// This delegates to `run_strategy` with `single_run_strategy` — the loop is not
/// special-cased, it is one wiring of the strategy graph (see strategy.mbt), the
/// way Koog builds `singleRunStrategy` from the same graph DSL.
/// Source: agents/agents-core/.../agent/AIAgentSimpleStrategies.kt
/// (`singleRunStrategy`).
pub async fn AIAgent::run(self : AIAgent, input : String) -> String {
  self.run_strategy(single_run_strategy(), input)
}
