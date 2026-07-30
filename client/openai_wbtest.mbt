///|
test "to_llm_message maps a plain user message" {
  let m = to_llm_message(@prompt.Message::user("hello"))
  assert_eq(m.role, @moonllm.User)
  assert_eq(m.content.to_text(), "hello")
  assert_true(m.tool_calls is None)
}

///|
test "to_llm_message maps a tool result to a tool-role message linked by id" {
  let m = to_llm_message(
    @prompt.Message::tool_result(tool="add", output="5", id=Some("c1")),
  )
  assert_eq(m.role, @moonllm.Tool)
  assert_eq(m.content.to_text(), "5")
  assert_eq(m.tool_call_id, Some("c1"))
}

///|
test "to_llm_message maps an assistant tool call" {
  let m = to_llm_message({
    role: Assistant,
    parts: [@prompt.ToolCall(id=Some("c1"), tool="add", args={ "a": 2 })],
    finish_reason: None,
  })
  assert_eq(m.role, @moonllm.Assistant)
  guard m.tool_calls is Some(tcs) else { fail("expected tool calls") }
  assert_eq(tcs.length(), 1)
  assert_eq(tcs[0].id, "c1")
  assert_eq(tcs[0].function.name, "add")
}

///|
test "to_llm_tool builds a JSON-schema object from the descriptor" {
  let d : @tools.ToolDescriptor = {
    name: "add",
    description: "add two ints",
    required_parameters: [
      { name: "a", description: "x", ptype: @tools.TInteger },
      { name: "b", description: "y", ptype: @tools.TInteger },
    ],
    optional_parameters: [],
  }
  let t = to_llm_tool(d)
  assert_eq(t.name, "add")
  // parameters is { "type": "object", "properties": {a,b}, "required": [a,b] }
  match t.parameters {
    Object(m) => {
      assert_eq(m.get("type"), Some(Json::string("object")))
      guard m.get("required") is Some(Array(req)) else {
        fail("no required array")
      }
      assert_eq(req.length(), 2)
    }
    _ => fail("parameters is not an object")
  }
}

///|
test "from_llm_message maps text and tool calls back to Koog parts" {
  let llm_msg : @moonllm.Message = {
    role: @moonllm.Assistant,
    content: Str(""),
    tool_calls: Some([
      { id: "c1", function: { name: "add", arguments: "{\"a\":2,\"b\":3}" } },
    ]),
    tool_call_id: None,
    name: None,
  }
  let m = from_llm_message(llm_msg, Some("tool_calls"))
  assert_eq(m.role, Assistant)
  let calls = m.tool_calls()
  assert_eq(calls.length(), 1)
  guard calls[0] is @prompt.ToolCall(tool=name, ..) else {
    fail("no tool call")
  }
  assert_eq(name, "add")
  assert_eq(m.finish_reason, Some("tool_calls"))
}

///|
test "from_moderation_response maps flags and confidence scores to a Koog verdict" {
  let resp : @moonllm.ModerationResponse = {
    model: "omni-moderation-latest",
    results: [
      {
        flagged: true,
        categories: { "hate": true, "violence": false },
        category_scores: { "hate": 0.92, "violence": 0.03 },
      },
    ],
  }
  let verdict = from_moderation_response(resp)
  assert_eq(verdict.is_harmful, true)
  assert_eq(verdict.is_category_detected("hate"), true)
  assert_eq(verdict.is_category_detected("violence"), false)
  guard verdict.categories.get("hate") is Some(hate) else {
    fail("no hate category")
  }
  assert_eq(hate.detected, true)
  assert_eq(hate.confidence_score, Some(0.92))
}

///|
test "from_moderation_response is safe when the response carries no results" {
  let resp : @moonllm.ModerationResponse = { model: "m", results: [] }
  assert_eq(from_moderation_response(resp).is_harmful, false)
}

///|
test "moderation_input joins the prompt's text parts" {
  let p = @prompt.PromptBuilder::new().system("policy").user("bad text").build()
  assert_eq(moderation_input(p), "policy\nbad text")
}

///|
test "from_chat_response_all maps every choice to its own Koog message" {
  let resp : @moonllm.ChatResponse = {
    id: "x",
    object: "chat.completion",
    created: 0L,
    model: "m",
    choices: [
      {
        index: 0,
        message: {
          role: @moonllm.Assistant,
          content: Str("first"),
          tool_calls: None,
          tool_call_id: None,
          name: None,
        },
        finish_reason: Some("stop"),
      },
      {
        index: 1,
        message: {
          role: @moonllm.Assistant,
          content: Str("second"),
          tool_calls: None,
          tool_call_id: None,
          name: None,
        },
        finish_reason: Some("length"),
      },
    ],
    usage: None,
    system_fingerprint: None,
  }
  let msgs = from_chat_response_all(resp)
  assert_eq(msgs.length(), 2)
  assert_eq(msgs[0].text_content(), "first")
  assert_eq(msgs[1].text_content(), "second")
  assert_eq(msgs[1].finish_reason, Some("length"))
}

///|
test "to_chat_request carries the model, messages, and tools" {
  let p = @prompt.PromptBuilder::new().system("be helpful").user("2+3?").build()
  let d : @tools.ToolDescriptor = {
    name: "add",
    description: "add",
    required_parameters: [
      { name: "a", description: "x", ptype: @tools.TInteger },
    ],
    optional_parameters: [],
  }
  let req = to_chat_request(p, @llm.deepseek_v4_flash, [d])
  assert_eq(req.model, "deepseek-v4-flash")
  assert_eq(req.messages.length(), 2)
  guard req.tools is Some(ts) else { fail("expected tools on the request") }
  assert_eq(ts.length(), 1)
  assert_eq(ts[0].name, "add")
}
