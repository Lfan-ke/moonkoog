///|
/// Lifecycle hooks over an agent run (← Koog's agents-features-event-handler
/// `EventHandlerConfig`): observe the agent starting and completing, each LLM call,
/// each tool call, and each strategy node as it runs. The transcribed core of
/// Koog's hook set — enough for logging, tracing, and token accounting to sit
/// outside the agent loop. Registering a handler *chains* it after any already
/// registered for that hook, so several observers all fire (Koog composes the
/// previous handler with the new one). Hooks are synchronous; an async observer is
/// a later refinement, as Koog's `suspend` hooks are.
pub struct EventHandler {
  mut on_agent_starting : (String) -> Unit
  mut on_agent_completed : (String) -> Unit
  mut on_llm_call_starting : (@prompt.Prompt) -> Unit
  mut on_llm_call_completed : (@prompt.Message) -> Unit
  mut on_tool_call_starting : (String, Json) -> Unit
  mut on_tool_call_completed : (String, String) -> Unit
  mut on_node_execution_starting : (String) -> Unit
  mut on_node_execution_completed : (String) -> Unit
}

///|
/// An event handler with every hook a no-op — the default an agent carries when no
/// observer is installed.
pub fn EventHandler::new() -> EventHandler {
  {
    on_agent_starting: _input => (),
    on_agent_completed: _result => (),
    on_llm_call_starting: _prompt => (),
    on_llm_call_completed: _reply => (),
    on_tool_call_starting: (_tool, _args) => (),
    on_tool_call_completed: (_tool, _result) => (),
    on_node_execution_starting: _node => (),
    on_node_execution_completed: _node => (),
  }
}

///|
/// Observe the agent starting, on its `input`. Chains after any prior handler.
pub fn EventHandler::on_agent_starting(
  self : EventHandler,
  handler : (String) -> Unit,
) -> EventHandler {
  let prev = self.on_agent_starting
  self.on_agent_starting = input => {
    prev(input)
    handler(input)
  }
  self
}

///|
/// Observe the agent completing, with its final text. Chains.
pub fn EventHandler::on_agent_completed(
  self : EventHandler,
  handler : (String) -> Unit,
) -> EventHandler {
  let prev = self.on_agent_completed
  self.on_agent_completed = result => {
    prev(result)
    handler(result)
  }
  self
}

///|
/// Observe each LLM request just before it is sent, with the prompt. Chains.
pub fn EventHandler::on_llm_call_starting(
  self : EventHandler,
  handler : (@prompt.Prompt) -> Unit,
) -> EventHandler {
  let prev = self.on_llm_call_starting
  self.on_llm_call_starting = prompt => {
    prev(prompt)
    handler(prompt)
  }
  self
}

///|
/// Observe each LLM reply, with the assistant message. Chains.
pub fn EventHandler::on_llm_call_completed(
  self : EventHandler,
  handler : (@prompt.Message) -> Unit,
) -> EventHandler {
  let prev = self.on_llm_call_completed
  self.on_llm_call_completed = reply => {
    prev(reply)
    handler(reply)
  }
  self
}

///|
/// Observe each tool call before it runs, with the tool name and JSON arguments.
/// Chains.
pub fn EventHandler::on_tool_call_starting(
  self : EventHandler,
  handler : (String, Json) -> Unit,
) -> EventHandler {
  let prev = self.on_tool_call_starting
  self.on_tool_call_starting = (tool, args) => {
    prev(tool, args)
    handler(tool, args)
  }
  self
}

///|
/// Observe each tool call after it runs, with the tool name and its result string.
/// Chains.
pub fn EventHandler::on_tool_call_completed(
  self : EventHandler,
  handler : (String, String) -> Unit,
) -> EventHandler {
  let prev = self.on_tool_call_completed
  self.on_tool_call_completed = (tool, result) => {
    prev(tool, result)
    handler(tool, result)
  }
  self
}

///|
/// Observe each strategy node before it runs, by name. Chains.
pub fn EventHandler::on_node_execution_starting(
  self : EventHandler,
  handler : (String) -> Unit,
) -> EventHandler {
  let prev = self.on_node_execution_starting
  self.on_node_execution_starting = node => {
    prev(node)
    handler(node)
  }
  self
}

///|
/// Observe each strategy node after it runs, by name. Chains.
pub fn EventHandler::on_node_execution_completed(
  self : EventHandler,
  handler : (String) -> Unit,
) -> EventHandler {
  let prev = self.on_node_execution_completed
  self.on_node_execution_completed = node => {
    prev(node)
    handler(node)
  }
  self
}
