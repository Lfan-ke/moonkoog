///|
/// What ends a run other than an answer: `AgentError` when the loop runs longer than
/// `max_iterations` without the model producing a final text answer, `AgentStopped`
/// when the run was asked to stop through its [`RunHandle`], carrying the text it had
/// reached by then.
pub suberror AgentError {
  AgentError(String)
  AgentStopped(String)
}

///|
/// A handle for stopping a run from outside it. Koog cancels the agent's coroutine,
/// which can land in the middle of a tool call; a graph walk can stop more politely
/// than that, so a run holding one of these finishes the node it is in and stops at
/// the next boundary. Hand the same handle to `run` or `run_strategy` and call `stop`
/// from anywhere — a supervisor, a signal handler, a deadline.
pub struct RunHandle {
  mut stopping : Bool
}

///|
/// A handle that has not been asked to stop.
pub fn RunHandle::new() -> RunHandle {
  { stopping: false, }
}

///|
/// Ask the run to stop at its next node boundary. Calling this more than once, or
/// after the run has finished, does nothing further.
pub fn RunHandle::stop(self : RunHandle) -> Unit {
  self.stopping = true
}

///|
/// Whether a stop has been requested.
pub fn RunHandle::stopping(self : RunHandle) -> Bool {
  self.stopping
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
  events : EventHandler
}

///|
/// Build an agent. `max_iterations` defaults to Koog's 50; `events` defaults to a
/// no-op handler (install one to observe the run).
pub fn AIAgent::new(
  executor : &LLMClient,
  model~ : @llm.LLModel,
  tool_registry? : @tools.ToolRegistry = @tools.ToolRegistry::new(),
  system_prompt? : String? = None,
  max_iterations? : Int = 50,
  events? : EventHandler = EventHandler::new(),
) -> AIAgent {
  { executor, model, tool_registry, system_prompt, max_iterations, events, }
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
pub async fn AIAgent::run(
  self : AIAgent,
  input : String,
  stop? : RunHandle,
) -> String {
  self.run_strategy(single_run_strategy(), input, stop?)
}
