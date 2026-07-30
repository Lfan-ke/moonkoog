// The Anthropic Messages API request format (POST /v1/messages) — the second wire format an
// agent framework must speak alongside OpenAI's chat completions. Anthropic differs in three
// ways this maps faithfully: the system prompt is a top-level `system` field (not a message),
// `max_tokens` is required, and tools carry an `input_schema` rather than `parameters`. This is
// the request half of a moonkoog Anthropic-compatible client.

///|
/// The role name Anthropic's Messages API uses; system messages are lifted out, so only user
/// and assistant appear in `messages`.
fn anthropic_role(r : @prompt.Role) -> String {
  match r {
    User => "user"
    Assistant => "assistant"
    System => "system"
  }
}

///|
/// The concatenated text of a message's `Text` parts.
fn anthropic_text(m : @prompt.Message) -> String {
  let sb = StringBuilder::new()
  for part in m.parts {
    match part {
      Text(t) => sb.write_string(t)
      _ => ()
    }
  }
  sb.to_string()
}

///|
/// Map a Koog tool descriptor to an Anthropic tool: `{name, description, input_schema}`, the
/// input_schema being the JSON Schema of the tool's parameters.
fn to_anthropic_tool(d : @tools.ToolDescriptor) -> Json {
  let properties : Map[String, Json] = Map([])
  let required : Array[Json] = []
  for p in d.required_parameters {
    properties[p.name] = p.ptype.to_json_schema()
    required.push(p.name.to_json())
  }
  for p in d.optional_parameters {
    properties[p.name] = p.ptype.to_json_schema()
  }
  Json::object({
    "name": Json::string(d.name),
    "description": Json::string(d.description),
    "input_schema": Json::object({
      "type": Json::string("object"),
      "properties": Json::object(properties),
      "required": Json::array(required),
    }),
  })
}

///|
/// Build an Anthropic Messages API request from a Koog prompt, model, and tools. System messages
/// are lifted to the top-level `system` field; `max_tokens` (required by Anthropic) comes from
/// the params, then the model's output limit, then a default of 4096.
pub fn to_anthropic_request(
  prompt : @prompt.Prompt,
  model : @llm.LLModel,
  tools : Array[@tools.ToolDescriptor],
) -> Json {
  let mut system = ""
  let messages : Array[Json] = []
  for m in prompt.messages {
    match m.role {
      System => system = system + anthropic_text(m)
      _ =>
        messages.push(
          Json::object({
            "role": Json::string(anthropic_role(m.role)),
            "content": Json::string(anthropic_text(m)),
          }),
        )
    }
  }
  let max_tokens = match prompt.params.max_tokens {
    Some(n) => n
    None =>
      match model.max_output_tokens {
        Some(n) => n
        None => 4096
      }
  }
  let fields : Map[String, Json] = {
    "model": Json::string(model.id),
    "max_tokens": max_tokens.to_json(),
    "messages": Json::array(messages),
  }
  if system != "" {
    fields["system"] = Json::string(system)
  }
  match prompt.params.temperature {
    Some(t) => fields["temperature"] = t.to_json()
    None => ()
  }
  if tools.length() > 0 {
    let arr : Array[Json] = []
    for d in tools {
      arr.push(to_anthropic_tool(d))
    }
    fields["tools"] = Json::array(arr)
  }
  Json::object(fields)
}

///|
/// Parse an Anthropic Messages API response into a Koog assistant message: each `text` content
/// block becomes a `Text` part, each `tool_use` block a `ToolCall` (its `input` the arguments),
/// and `stop_reason` the finish reason.
pub fn from_anthropic_response(response : Json) -> @prompt.Message {
  let parts : Array[@prompt.MessagePart] = []
  let mut finish : String? = None
  match response {
    Object(obj) => {
      match obj.get("content") {
        Some(Array(blocks)) =>
          for block in blocks {
            match block {
              Object(b) => {
                let btype = match b.get("type") {
                  Some(String(t)) => t
                  _ => ""
                }
                if btype == "text" {
                  match b.get("text") {
                    Some(String(t)) => parts.push(Text(t))
                    _ => ()
                  }
                } else if btype == "tool_use" {
                  let id = match b.get("id") {
                    Some(String(i)) => Some(i)
                    _ => None
                  }
                  let name = match b.get("name") {
                    Some(String(n)) => n
                    _ => ""
                  }
                  let input = match b.get("input") {
                    Some(v) => v
                    None => Json::object({})
                  }
                  parts.push(ToolCall(id~, tool=name, args=input))
                }
              }
              _ => ()
            }
          }
        _ => ()
      }
      match obj.get("stop_reason") {
        Some(String(s)) => finish = Some(s)
        _ => ()
      }
    }
    _ => ()
  }
  { role: Assistant, parts, finish_reason: finish }
}
