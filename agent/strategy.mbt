///|
/// Koog's agent strategy as a directed graph of nodes joined by conditional
/// edges. `AIAgent.run`'s tool-calling loop is not special-cased — it is one
/// wiring of this graph (`single_run_strategy` below), the way Koog builds
/// `singleRunStrategy` from the same `strategy { ... }` DSL. A run threads a
/// value from the start node along the first outgoing edge whose condition holds,
/// node to node, until it reaches the finish node.
///
/// Koog's nodes are statically typed on their input/output and its edges carry
/// arbitrary transform lambdas; MoonBit has neither per-node generics across a
/// heterogeneous graph nor a receiver-lambda DSL, so the value in flight is the
/// `NodeValue` sum and the standard node behaviours are named `NodeKind`s.
/// Arbitrary nodes are `NodeCustom` handlers run against a `NodeSession` — the
/// MoonBit-idiomatic stand-in for Kotlin's receiver-lambda node DSL — and edges may
/// carry a value transform, together enough to express Koog's chat and reAct strategies.
/// Source: agents/agents-core/.../agent/entity/{AIAgentStrategy,AIAgentNodeBase,
/// AIAgentEdge}.kt and AIAgentSimpleStrategies.kt (`singleRunStrategy`).

///|
/// The value passed between strategy nodes: the text that enters at the start and
/// leaves at the finish, an LLM assistant reply, or a bare token from a node whose
/// effect is on the conversation (tools executed) rather than on a carried value.
pub(all) enum NodeValue {
  VText(String)
  VReply(@prompt.Message)
  VUnit
} derive(Eq, Debug)

///|
/// The text a `NodeValue` carries: the raw text, an assistant reply's text, or empty.
pub fn NodeValue::text(self : NodeValue) -> String {
  match self {
    VText(s) => s
    VReply(m) => m.text_content()
    VUnit => ""
  }
}

///|
/// A standard node's behaviour (Koog's `nodeStart` / `nodeFinish` /
/// `nodeLLMRequest` / `nodeExecuteTool` / `nodeLLMSendToolResult`).
/// `NodeExecuteTools` runs every tool call in the reply (Koog's multiple-tool
/// variant), matching the conversation the loop builds.
pub(all) enum NodeKind {
  NodeStart
  NodeFinish
  NodeLLMRequest
  NodeExecuteTools
  NodeLLMSendToolResult
  // A parametrized LLM request that first appends a fixed instruction (Koog's custom
  // `node { ... appendPrompt { user(...) }; requestLLM() }` — e.g. the chat strategy's
  // "call a tool instead of chatting" nudge), then requests the model.
  NodeLLMRequestWith(String)
  // A node whose behaviour is an arbitrary handler registered by name (Koog's fully
  // general `node<In, Out> { ... }`). The handler runs against a `NodeSession` — the
  // MoonBit-idiomatic stand-in for Kotlin's receiver-lambda session, giving closures the
  // request/append/storage operations a custom node needs (e.g. reAct's reasoning steps).
  NodeCustom(String)
} derive(Eq, Debug)

///|
/// When an edge fires, tested against the source node's output. `Always` is an
/// unconditional edge; `OnAssistantMessage` fires on a plain-text reply (no tool
/// calls); `OnToolCalls` fires on a reply that requests tools. Koog's `onCondition`
/// / `onAssistantMessage` / `onToolCall`.
pub(all) enum EdgeCondition {
  Always
  OnAssistantMessage
  OnToolCalls
  OnToolNamed(String)
} derive(Eq, Debug)

///|
/// A directed edge `from -> to` that fires when `condition` holds.
pub(all) struct StrategyEdge {
  from : String
  to : String
  condition : EdgeCondition
  // When set, the value carried to `to` is replaced by this text (Koog's edge
  // `transformed { ... }`) — e.g. the chat strategy finishing on the exit tool with
  // "Chat finished" rather than the tool call.
  transform : String?
} derive(Eq, Debug)

///|
/// A strategy graph: named nodes, edges between them, and the start / finish node
/// names. `max_steps` bounds node visits, a backstop against a cyclic graph that
/// never reaches finish (the per-agent `max_iterations` bounds LLM calls).
pub struct AIAgentStrategy {
  name : String
  nodes : Map[String, NodeKind]
  edges : Array[StrategyEdge]
  // Handlers for `NodeCustom` nodes, keyed by node name.
  custom : Map[String, async (NodeSession, NodeValue) -> NodeValue]
  start : String
  finish : String
  max_steps : Int
}

///|
/// The canonical start / finish node names.
pub let start_node : String = "__start__"

///|
pub let finish_node : String = "__finish__"

///|
/// A strategy seeded with the start and finish nodes, ready to have nodes and
/// edges added. `max_steps` defaults to a generous backstop.
pub fn AIAgentStrategy::new(
  name : String,
  max_steps? : Int = 1000,
) -> AIAgentStrategy {
  {
    name,
    nodes: Map([(start_node, NodeStart), (finish_node, NodeFinish)]),
    edges: [],
    custom: Map([]),
    start: start_node,
    finish: finish_node,
    max_steps,
  }
}

///|
/// Add a named node, returning the strategy so calls chain.
pub fn AIAgentStrategy::node(
  self : AIAgentStrategy,
  name : String,
  kind : NodeKind,
) -> AIAgentStrategy {
  self.nodes[name] = kind
  self
}

///|
/// Add a custom node `name` whose behaviour is `handler` — an arbitrary step run against a
/// `NodeSession` (Koog's `node<In, Out> { ... }`). Returns the strategy so calls chain.
pub fn AIAgentStrategy::custom_node(
  self : AIAgentStrategy,
  name : String,
  handler : async (NodeSession, NodeValue) -> NodeValue,
) -> AIAgentStrategy {
  self.nodes[name] = NodeCustom(name)
  self.custom[name] = handler
  self
}

///|
/// Add an edge `from -> to` firing on `condition` (unconditional by default),
/// returning the strategy so calls chain.
pub fn AIAgentStrategy::edge(
  self : AIAgentStrategy,
  from : String,
  to : String,
  condition? : EdgeCondition = Always,
  transform? : String? = None,
) -> AIAgentStrategy {
  self.edges.push({ from, to, condition, transform, })
  self
}

///|
/// Koog's `singleRunStrategy` expressed as a graph: request the LLM; on a
/// plain-text reply finish, on a tool-call reply execute the tools, feed the
/// results back, and request again — looping until the model answers in text.
pub fn single_run_strategy(max_steps? : Int = 1000) -> AIAgentStrategy {
  AIAgentStrategy::new("single_run", max_steps~)
  .node("llm_request", NodeLLMRequest)
  .node("execute_tools", NodeExecuteTools)
  .node("send_tool_result", NodeLLMSendToolResult)
  .edge(start_node, "llm_request")
  .edge("llm_request", finish_node, condition=OnAssistantMessage)
  .edge("llm_request", "execute_tools", condition=OnToolCalls)
  .edge("execute_tools", "send_tool_result")
  .edge("send_tool_result", finish_node, condition=OnAssistantMessage)
  .edge("send_tool_result", "execute_tools", condition=OnToolCalls)
}

///|
/// Koog's `chatAgentStrategy` expressed as a graph: request the LLM; a tool call is
/// executed, but a plain-text reply is nudged ("call a tool instead of chatting") and the
/// LLM re-requested until it calls a tool; the loop finishes when the model calls the exit
/// tool (`__exit__`), whose edge carries "Chat finished" as the result.
pub fn chat_agent_strategy(max_steps? : Int = 1000) -> AIAgentStrategy {
  let nudge = "Don't reply with plain text. Call one of the available tools instead."
  AIAgentStrategy::new("chat", max_steps~)
  .node("llm_request", NodeLLMRequest)
  .node("feedback", NodeLLMRequestWith(nudge))
  .node("execute_tools", NodeExecuteTools)
  .node("send_tool_result", NodeLLMSendToolResult)
  .edge(start_node, "llm_request")
  .edge("llm_request", "execute_tools", condition=OnToolCalls)
  .edge("llm_request", "feedback", condition=OnAssistantMessage)
  .edge("feedback", "feedback", condition=OnAssistantMessage)
  .edge("feedback", "execute_tools", condition=OnToolCalls)
  .edge("execute_tools", "send_tool_result")
  .edge(
    "send_tool_result",
    finish_node,
    condition=OnToolNamed("__exit__"),
    transform=Some("Chat finished"),
  )
  .edge("send_tool_result", finish_node, condition=OnAssistantMessage)
  .edge("send_tool_result", "execute_tools", condition=OnToolCalls)
}

///|
/// Koog's `reActStrategy`: alternate reasoning and action. Each round reasons (a tools-off
/// request seeded with `reasoning_prompt`), then acts (a request with tools); a tool call is
/// executed and, every `reasoning_interval` rounds, the results are reasoned over before the
/// next action; a plain-text reply finishes. Built on custom nodes carrying a reasoning-step
/// counter in the session's per-run store.
pub fn react_strategy(
  reasoning_interval? : Int = 1,
  reasoning_prompt? : String = "Please give your thoughts about the task and plan the next steps.",
  max_steps? : Int = 1000,
) -> AIAgentStrategy {
  let interval = if reasoning_interval > 0 { reasoning_interval } else { 1 }
  AIAgentStrategy::new("re_act", max_steps~)
  .custom_node("setup", (s, v) => {
    s.set("step", 0)
    v
  })
  .custom_node("reason_input", (s, v) => {
    s.append_user(v.text())
    s.append_user(reasoning_prompt)
    s.append(s.request_llm_no_tools())
    VUnit
  })
  .custom_node("call_llm", (s, _v) => VReply(s.request_llm()))
  .node("execute_tools", NodeExecuteTools)
  .custom_node("reason_after", (s, _v) => {
    let step = match s.get("step") {
      Some(n) => n
      None => 0
    }
    if step % interval == 0 {
      s.append_user(reasoning_prompt)
      s.append(s.request_llm_no_tools())
    }
    s.set("step", step + 1)
    VUnit
  })
  .edge(start_node, "setup")
  .edge("setup", "reason_input")
  .edge("reason_input", "call_llm")
  .edge("call_llm", "execute_tools", condition=OnToolCalls)
  .edge("call_llm", finish_node, condition=OnAssistantMessage)
  .edge("execute_tools", "reason_after")
  .edge("reason_after", "call_llm")
}

///|
/// The mutable run context threaded through the nodes: the executor + model to
/// call, the tool registry to dispatch to, the growing prompt, and the tool
/// descriptors advertised on every request.
struct StrategyContext {
  executor : &LLMClient
  model : @llm.LLModel
  tool_registry : @tools.ToolRegistry
  mut prompt : @prompt.Prompt
  descriptors : Array[@tools.ToolDescriptor]
  events : EventHandler
  // Custom-node handlers by name, and a small per-run integer store custom nodes use to
  // carry state across the graph (e.g. reAct's reasoning-step counter).
  custom : Map[String, async (NodeSession, NodeValue) -> NodeValue]
  storage : Map[String, Int]
}

///|
/// The session a custom node runs against (Koog's `AIAgentLLMWriteSession` receiver): the
/// request/append/storage operations a node closure needs, without exposing the whole
/// context. This is the MoonBit stand-in for Kotlin's receiver-lambda node DSL.
pub struct NodeSession {
  ctx : StrategyContext
}

///|
/// Append a user message to the conversation.
pub fn NodeSession::append_user(self : NodeSession, text : String) -> Unit {
  self.ctx.prompt = self.ctx.prompt.append(@prompt.Message::user(text))
}

///|
/// Append a ready message to the conversation.
pub fn NodeSession::append(
  self : NodeSession,
  message : @prompt.Message,
) -> Unit {
  self.ctx.prompt = self.ctx.prompt.append(message)
}

///|
/// Request the model with the advertised tools (Koog `requestLLM`).
pub async fn NodeSession::request_llm(self : NodeSession) -> @prompt.Message {
  (self.ctx.events.on_llm_call_starting)(self.ctx.prompt)
  let reply = self.ctx.executor.execute(
    prompt=self.ctx.prompt,
    model=self.ctx.model,
    tools=self.ctx.descriptors,
  )
  (self.ctx.events.on_llm_call_completed)(reply)
  reply
}

///|
/// Request the model with no tools — a reasoning step (Koog `requestLLMWithoutTools`).
pub async fn NodeSession::request_llm_no_tools(
  self : NodeSession,
) -> @prompt.Message {
  (self.ctx.events.on_llm_call_starting)(self.ctx.prompt)
  let reply = self.ctx.executor.execute(
    prompt=self.ctx.prompt,
    model=self.ctx.model,
    tools=[],
  )
  (self.ctx.events.on_llm_call_completed)(reply)
  reply
}

///|
/// Read a per-run counter (`None` if unset).
pub fn NodeSession::get(self : NodeSession, key : String) -> Int? {
  self.ctx.storage.get(key)
}

///|
/// Write a per-run counter.
pub fn NodeSession::set(self : NodeSession, key : String, value : Int) -> Unit {
  self.ctx.storage[key] = value
}

///|
/// The names of the tools advertised to the model.
pub fn NodeSession::tool_names(self : NodeSession) -> Array[String] {
  self.ctx.descriptors.map(d => d.name)
}

///|
/// Whether `condition` holds for `value`.
fn edge_matches(condition : EdgeCondition, value : NodeValue) -> Bool {
  match condition {
    Always => true
    OnAssistantMessage =>
      match value {
        VReply(m) => m.tool_calls().is_empty()
        _ => false
      }
    OnToolCalls =>
      match value {
        VReply(m) => !m.tool_calls().is_empty()
        _ => false
      }
    OnToolNamed(name) =>
      match value {
        VReply(m) => {
          let mut found = false
          for part in m.tool_calls() {
            if part is @prompt.ToolCall(tool~, ..) && tool == name {
              found = true
            }
          }
          found
        }
        _ => false
      }
  }
}

///|
/// The text a `NodeValue` carries out of the finish node.
fn node_value_text(value : NodeValue) -> String {
  match value {
    VText(s) => s
    VReply(m) => m.text_content()
    VUnit => ""
  }
}

///|
/// Run one node against the context, returning its output value.
async fn run_node(
  ctx : StrategyContext,
  kind : NodeKind,
  value : NodeValue,
) -> NodeValue {
  match kind {
    NodeStart => value
    NodeFinish => value
    NodeLLMRequest => {
      let input = node_value_text(value)
      ctx.prompt = ctx.prompt.append(@prompt.Message::user(input))
      (ctx.events.on_llm_call_starting)(ctx.prompt)
      let reply = ctx.executor.execute(
        prompt=ctx.prompt,
        model=ctx.model,
        tools=ctx.descriptors,
      )
      (ctx.events.on_llm_call_completed)(reply)
      VReply(reply)
    }
    NodeExecuteTools => {
      guard value is VReply(reply) else { return VUnit }
      ctx.prompt = ctx.prompt.append(reply)
      for call in reply.tool_calls() {
        guard call is @prompt.ToolCall(id~, tool~, args~) else { continue }
        (ctx.events.on_tool_call_starting)(tool, args)
        let output = match ctx.tool_registry.get_tool(tool) {
          Some(t) =>
            t.execute_raw(args) catch {
              e => "tool error: " + e.to_string()
            }
          None => "unknown tool: " + tool
        }
        (ctx.events.on_tool_call_completed)(tool, output)
        ctx.prompt = ctx.prompt.append(
          @prompt.Message::tool_result(tool~, output~, id~),
        )
      }
      VUnit
    }
    NodeLLMSendToolResult => {
      (ctx.events.on_llm_call_starting)(ctx.prompt)
      let reply = ctx.executor.execute(
        prompt=ctx.prompt,
        model=ctx.model,
        tools=ctx.descriptors,
      )
      (ctx.events.on_llm_call_completed)(reply)
      VReply(reply)
    }
    NodeLLMRequestWith(instruction) => {
      // Keep the previous reply in the conversation, then nudge and re-request.
      if value is VReply(prev) {
        ctx.prompt = ctx.prompt.append(prev)
      }
      ctx.prompt = ctx.prompt.append(@prompt.Message::user(instruction))
      (ctx.events.on_llm_call_starting)(ctx.prompt)
      let reply = ctx.executor.execute(
        prompt=ctx.prompt,
        model=ctx.model,
        tools=ctx.descriptors,
      )
      (ctx.events.on_llm_call_completed)(reply)
      VReply(reply)
    }
    NodeCustom(key) =>
      match ctx.custom.get(key) {
        Some(handler) => handler({ ctx, }, value)
        None => value
      }
  }
}

///|
/// Run `strategy` on `input`, returning the finish node's text. Seeds the prompt
/// with the agent's system message, then walks the graph: run the current node,
/// follow the first outgoing edge whose condition holds, and stop at finish. LLM
/// requests are bounded by the agent's `max_iterations` (Koog's iteration cap),
/// node visits by the strategy's `max_steps`.
pub async fn AIAgent::run_strategy(
  self : AIAgent,
  strategy : AIAgentStrategy,
  input : String,
  stop? : RunHandle,
) -> String {
  let builder = @prompt.PromptBuilder::new()
  if self.system_prompt is Some(sp) {
    builder.system(sp) |> ignore
  }
  let ctx : StrategyContext = {
    executor: self.executor,
    model: self.model,
    tool_registry: self.tool_registry,
    prompt: builder.build(),
    descriptors: self.tool_registry.descriptors(),
    events: self.events,
    custom: strategy.custom,
    storage: Map([]),
  }
  (self.events.on_agent_starting)(input)
  for step = 0, current = strategy.start, value = VText(input), llm_calls = 0; step <
     strategy.max_steps; {
    if stop is Some(handle) && handle.stopping {
      raise AgentStopped(node_value_text(value))
    }
    guard strategy.nodes.get(current) is Some(kind) else {
      raise AgentError("strategy has no node named '" + current + "'")
    }
    let is_llm = kind
      is (NodeLLMRequest | NodeLLMSendToolResult | NodeLLMRequestWith(_))
    guard !(is_llm && llm_calls >= self.max_iterations) else {
      raise AgentError(
        "max iterations (" + self.max_iterations.to_string() + ") exceeded",
      )
    }
    (ctx.events.on_node_execution_starting)(current)
    let out = run_node(ctx, kind, value)
    (ctx.events.on_node_execution_completed)(current)
    if current == strategy.finish {
      let result = node_value_text(out)
      (self.events.on_agent_completed)(result)
      return result
    }
    guard strategy.edges
      .iter()
      .find_first(e => e.from == current && edge_matches(e.condition, out))
      is Some(edge) else {
      raise AgentError("no edge out of '" + current + "' matched")
    }
    let carried = match edge.transform {
      Some(t) => VText(t)
      None => out
    }
    continue step + 1,
      edge.to,
      carried,
      if is_llm {
        llm_calls + 1
      } else {
        llm_calls
      }
  }
  raise AgentError(
    "strategy '" +
    strategy.name +
    "' exceeded " +
    strategy.max_steps.to_string() +
    " node steps",
  )
}
