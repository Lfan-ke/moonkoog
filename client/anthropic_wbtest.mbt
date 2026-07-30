// The Anthropic Messages API request format.

///|
fn anthropic_test_model() -> @llm.LLModel {
  {
    provider: @llm.anthropic,
    id: "claude-3-5-sonnet",
    capabilities: [],
    context_length: None,
    max_output_tokens: None,
  }
}

///|
test "anthropic request: the system prompt is lifted, max_tokens defaults, messages mapped" {
  let prompt = @prompt.PromptBuilder::new()
    .system("you are helpful")
    .user("hi")
    .build()
  let req = to_anthropic_request(prompt, anthropic_test_model(), [])
  let expected : Json = Json::object({
    "model": Json::string("claude-3-5-sonnet"),
    "max_tokens": (4096).to_json(),
    "messages": Json::array([
      Json::object({
        "role": Json::string("user"),
        "content": Json::string("hi"),
      }),
    ]),
    "system": Json::string("you are helpful"),
  })
  assert_eq(req, expected)
}

///|
test "anthropic request: params max_tokens and temperature are carried" {
  let params : @prompt.LLMParams = {
    ..@prompt.LLMParams::default(),
    temperature: Some(0.5),
    max_tokens: Some(512),
  }
  let prompt = @prompt.PromptBuilder::new(params~).user("go").build()
  let req = to_anthropic_request(prompt, anthropic_test_model(), [])
  let expected : Json = Json::object({
    "model": Json::string("claude-3-5-sonnet"),
    "max_tokens": (512).to_json(),
    "messages": Json::array([
      Json::object({
        "role": Json::string("user"),
        "content": Json::string("go"),
      }),
    ]),
    "temperature": 0.5.to_json(),
  })
  assert_eq(req, expected)
}

///|
test "anthropic response: text and tool_use blocks become a Koog assistant message" {
  let response = @json.parse(
    (
      #|{"id":"msg_1","type":"message","role":"assistant","content":[{"type":"text","text":"hello"},{"type":"tool_use","id":"tu_1","name":"search","input":{"q":"x"}}],"stop_reason":"tool_use"}
    ),
  )
  let msg = from_anthropic_response(response)
  assert_eq(msg.role, Assistant)
  assert_eq(msg.finish_reason, Some("tool_use"))
  assert_eq(msg.parts.length(), 2)
  match msg.parts[0] {
    Text(t) => assert_eq(t, "hello")
    _ => abort("expected a text part")
  }
  match msg.parts[1] {
    ToolCall(id~, tool~, args~) => {
      assert_eq(id, Some("tu_1"))
      assert_eq(tool, "search")
      assert_eq(args, @json.parse("{\"q\":\"x\"}"))
    }
    _ => abort("expected a tool call")
  }
}
