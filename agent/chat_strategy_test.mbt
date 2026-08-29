// Koog's chatAgentStrategy: a plain-text reply is nudged to call a tool, a tool call is run,
// and the exit tool ends the chat with the transformed "Chat finished" result.

///|
struct GreetTool {}

///|
impl @tools.Tool for GreetTool with fn descriptor(_self) {
  {
    name: "greet",
    description: "greet someone",
    required_parameters: [],
    optional_parameters: [],
  }
}

///|
impl @tools.Tool for GreetTool with fn execute_raw(_self, _args) {
  "greetings"
}

///|
async test "chat strategy: nudges on plain text, runs a tool, finishes on the exit tool" {
  @async.with_task_group(_g => {
    let plain = @prompt.Message::assistant("let me think out loud")
    let tool_call : @prompt.Message = {
      role: @prompt.Assistant,
      parts: [
        @prompt.ToolCall(id=Some("c1"), tool="greet", args={ "name": "lfanke" }),
      ],
      finish_reason: None,
    }
    let exit_call : @prompt.Message = {
      role: @prompt.Assistant,
      parts: [
        @prompt.ToolCall(id=Some("c2"), tool="__exit__", args={
          "result": "bye",
        }),
      ],
      finish_reason: None,
    }
    let mock = @agent.MockClient::new([plain, tool_call, exit_call])
    let registry = @tools.ToolRegistry::new().add(GreetTool::{ })
    let agent = @agent.AIAgent::new(
      mock,
      model=@llm.deepseek_v4_flash,
      tool_registry=registry,
    )
    let out = agent.run_strategy(@agent.chat_agent_strategy(), "hello") catch {
      e => fail(e.to_string())
    }
    assert_eq(out, "Chat finished")
  })
}
