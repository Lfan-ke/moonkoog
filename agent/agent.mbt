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
/// Run the agent on `input`, returning the final assistant text. A faithful
/// implementation of Koog's `singleRunStrategy`:
///
/// 1. seed the prompt (system?, then the user input) and request a completion;
/// 2. if the reply is plain text (no tool calls) → return it;
/// 3. otherwise keep the assistant reply, run each requested tool, append each
///    result as a tool-result message, and request again;
/// 4. repeat, bounded by `max_iterations`.
///
/// Source: agents/agents-core/.../agent/AIAgentSimpleStrategies.kt
/// (`singleRunStrategy`).
pub async fn AIAgent::run(self : AIAgent, input : String) -> String {
  let builder = @prompt.PromptBuilder::new()
  match self.system_prompt {
    Some(sp) => builder.system(sp) |> ignore
    None => ()
  }
  builder.user(input) |> ignore
  let mut prompt = builder.build()
  let descriptors = self.tool_registry.descriptors()
  let mut iterations = 0
  while iterations < self.max_iterations {
    iterations = iterations + 1
    let reply = self.executor.execute(
      prompt~,
      model=self.model,
      tools=descriptors,
    )
    let calls = reply.tool_calls()
    if calls.is_empty() {
      return reply.text_content()
    }
    // Keep the assistant reply (carrying its tool-call parts) in the conversation,
    // then answer every tool call with a tool-result message.
    prompt = prompt.append(reply)
    for call in calls {
      guard call is @prompt.ToolCall(id~, tool~, args~) else { continue }
      let output = match self.tool_registry.get_tool(tool) {
        Some(t) =>
          t.execute_raw(args) catch {
            e => "tool error: " + e.to_string()
          }
        None => "unknown tool: " + tool
      }
      prompt = prompt.append(@prompt.Message::tool_result(tool~, output~, id~))
    }
  }
  raise AgentError(
    "max iterations (" + self.max_iterations.to_string() + ") exceeded",
  )
}
