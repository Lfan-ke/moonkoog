///|
/// An OpenAI-compatible LLM client (Koog `OpenAILLMClient` and its provider
/// siblings). It implements moonkoog's `LLMClient` by mapping Koog's
/// prompt/message/tool model onto moonllm's request/response types and back;
/// moonllm carries the actual HTTPS transport. One client talks to any
/// OpenAI-compatible endpoint by its `base_url`.
/// Source: prompt/prompt-executor/prompt-executor-clients/prompt-executor-openai-client/.../OpenAILLMClient.kt.
pub struct OpenAiCompatibleClient {
  inner : @moonllm.Client
  its_provider : @llm.LLMProvider
}

///|
/// Build a client for `base_url`, authenticating with a bearer `api_key`.
pub fn OpenAiCompatibleClient::new(
  api_key~ : String,
  base_url~ : String,
  provider~ : @llm.LLMProvider,
  timeout_ms? : Int = 60000,
) -> OpenAiCompatibleClient {
  {
    inner: @moonllm.Client::new(api_key, base_url~, timeout_ms~),
    its_provider: provider,
  }
}

///|
pub impl @agent.LLMClient for OpenAiCompatibleClient with fn execute(
  self,
  prompt~,
  model~,
  tools~,
) {
  let request = to_chat_request(prompt, model, tools)
  let response = self.inner.chat(request)
  from_chat_response(response)
}

///|
pub impl @agent.LLMClient for OpenAiCompatibleClient with fn provider(self) {
  self.its_provider
}

///|
/// Map a Koog prompt + model + tool descriptors to a moonllm chat request.
fn to_chat_request(
  prompt : @prompt.Prompt,
  model : @llm.LLModel,
  tools : Array[@tools.ToolDescriptor],
) -> @moonllm.ChatRequest {
  let messages = []
  for m in prompt.messages {
    messages.push(to_llm_message(m))
  }
  let request = @moonllm.ChatRequest::new(model.id, messages)
  if !tools.is_empty() {
    let llm_tools = []
    for d in tools {
      llm_tools.push(to_llm_tool(d))
    }
    request.tools(llm_tools) |> ignore
  }
  if prompt.params.temperature is Some(t) {
    request.temperature(t) |> ignore
  }
  if prompt.params.max_tokens is Some(n) {
    request.max_tokens(n) |> ignore
  }
  request
}

///|
/// Map a Koog message to a moonllm message. A message carrying a tool result
/// becomes a `tool`-role message linked by `tool_call_id`; a message carrying
/// tool calls becomes an assistant message with `tool_calls`; otherwise it is a
/// plain text message in its role.
fn to_llm_message(m : @prompt.Message) -> @moonllm.Message {
  let role = match m.role {
    System => @moonllm.System
    User => @moonllm.User
    Assistant => @moonllm.Assistant
  }
  let mut text = ""
  let tool_calls : Array[@moonllm.ToolCall] = []
  let mut result_id : String? = None
  let mut is_result = false
  for part in m.parts {
    match part {
      Text(t) => text = text + t
      Reasoning(_) => ()
      ToolResult(id~, output~, ..) => {
        text = output
        result_id = id
        is_result = true
      }
      ToolCall(id~, tool~, args~) =>
        tool_calls.push({
          id: id.unwrap_or(""),
          function: { name: tool, arguments: args.stringify() },
        })
    }
  }
  if is_result {
    {
      role: @moonllm.Tool,
      content: Str(text),
      tool_calls: None,
      tool_call_id: result_id,
      name: None,
    }
  } else if !tool_calls.is_empty() {
    {
      role,
      content: Str(text),
      tool_calls: Some(tool_calls),
      tool_call_id: None,
      name: None,
    }
  } else {
    {
      role,
      content: Str(text),
      tool_calls: None,
      tool_call_id: None,
      name: None,
    }
  }
}

///|
/// Map a Koog tool descriptor to a moonllm tool: a JSON-schema `parameters`
/// object built from the required / optional parameter lists.
fn to_llm_tool(d : @tools.ToolDescriptor) -> @moonllm.Tool {
  let properties : Map[String, Json] = Map([])
  let required : Array[Json] = []
  for p in d.required_parameters {
    properties[p.name] = param_schema(p.ptype)
    required.push(p.name.to_json())
  }
  for p in d.optional_parameters {
    properties[p.name] = param_schema(p.ptype)
  }
  {
    name: d.name,
    description: d.description,
    parameters: Json::object({
      "type": Json::string("object"),
      "properties": Json::object(properties),
      "required": Json::array(required),
    }),
  }
}

///|
/// The JSON Schema for one tool-parameter type.
fn param_schema(t : @tools.ToolParameterType) -> Json {
  match t {
    TString => { "type": "string" }
    TInteger => { "type": "integer" }
    TFloat => { "type": "number" }
    TBoolean => { "type": "boolean" }
    TNull => { "type": "null" }
    TEnum(values) => {
      let vs : Array[Json] = []
      for v in values {
        vs.push(v.to_json())
      }
      Json::object({ "type": Json::string("string"), "enum": Json::array(vs) })
    }
    TList(inner) =>
      Json::object({
        "type": Json::string("array"),
        "items": param_schema(inner),
      })
    TObject(properties~, required~) => {
      let props : Map[String, Json] = Map([])
      for p in properties {
        props[p.name] = param_schema(p.ptype)
      }
      let req : Array[Json] = []
      for r in required {
        req.push(r.to_json())
      }
      Json::object({
        "type": Json::string("object"),
        "properties": Json::object(props),
        "required": Json::array(req),
      })
    }
    TAnyOf(descs) => {
      let arr : Array[Json] = []
      for d in descs {
        arr.push(param_schema(d.ptype))
      }
      Json::object({ "anyOf": Json::array(arr) })
    }
  }
}

///|
/// Map a moonllm chat response to a Koog assistant message (the first choice).
fn from_chat_response(resp : @moonllm.ChatResponse) -> @prompt.Message {
  guard resp.choices.length() > 0 else {
    { role: Assistant, parts: [], finish_reason: None }
  }
  let choice = resp.choices[0]
  from_llm_message(choice.message, choice.finish_reason)
}

///|
/// Map a moonllm message to a Koog message: its text becomes a `Text` part, each
/// returned tool call becomes a `ToolCall` part (its JSON arguments re-parsed).
fn from_llm_message(
  msg : @moonllm.Message,
  finish_reason : String?,
) -> @prompt.Message {
  let parts : Array[@prompt.MessagePart] = []
  let text = msg.content.to_text()
  if text != "" {
    parts.push(Text(text))
  }
  if msg.tool_calls is Some(tcs) {
    for tc in tcs {
      parts.push(
        ToolCall(
          id=Some(tc.id),
          tool=tc.function.name,
          args=parse_json(tc.function.arguments),
        ),
      )
    }
  }
  { role: Assistant, parts, finish_reason }
}

///|
/// Parse a JSON string, or an empty object if it does not parse.
fn parse_json(s : String) -> Json {
  @json.parse(s) catch {
    _ => Json::object({})
  }
}
