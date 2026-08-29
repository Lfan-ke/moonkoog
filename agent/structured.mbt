///|
/// Structured LLM output: constrain the model to reply with a JSON object that
/// matches a schema, parse it into a value, and re-prompt to fix a malformed
/// reply. Koog's `requestLLMStructured` + `StructureFixingParser`. Koog derives
/// the schema and deserializer from the Kotlin type via kotlinx.serialization;
/// MoonBit has no reflection, so the caller states the schema (a
/// `@tools.ToolParameterType`, usually a `TObject`) and supplies the `parse` that
/// turns the model's JSON into `T` — the same explicit shape a tool takes for its
/// descriptor plus `decodeArgs`.
/// Source: prompt/prompt-structure/.../StructuredOutput.kt and
/// agents/.../StructureFixingParser.kt.

///|
/// A structured-response request: the schema the reply must match and the parser
/// that turns its JSON into a `T`.
pub(all) struct StructuredSchema[T] {
  name : String
  description : String
  schema : @tools.ToolParameterType
  parse : (Json) -> T?
}

///|
/// A structured request's result: the parsed value and the raw model text it came
/// from.
pub(all) struct StructuredResponse[T] {
  value : T
  raw : String
}

///|
/// Pull the first brace-balanced JSON object out of `text`, tolerating code fences
/// or surrounding prose (models rarely emit a bare object). Scans respecting string
/// literals and escapes; `None` if there is no balanced `{...}`.
fn extract_json_object(text : String) -> String? {
  let n = text.length()
  let mut start = -1
  for i = 0; i < n; i = i + 1 {
    if text[i].to_int() == '{'.to_int() {
      start = i
      break
    }
  }
  guard start >= 0 else { return None }
  let mut depth = 0
  let mut in_string = false
  let mut escaped = false
  for i = start; i < n; i = i + 1 {
    let c = text[i].to_int()
    if in_string {
      if escaped {
        escaped = false
      } else if c == '\\'.to_int() {
        escaped = true
      } else if c == '"'.to_int() {
        in_string = false
      }
    } else if c == '"'.to_int() {
      in_string = true
    } else if c == '{'.to_int() {
      depth = depth + 1
    } else if c == '}'.to_int() {
      depth = depth - 1
      if depth == 0 {
        return Some(text[start:i + 1].to_owned())
      }
    }
  }
  None
}

///|
/// Request a structured response to `input`, retrying up to `max_fixes` times when
/// the reply does not parse. Seeds the prompt with a schema instruction (after the
/// agent's system prompt), then on each malformed reply appends the bad output and
/// a fixing instruction and asks again — Koog's `StructureFixingParser`. Raises
/// `AgentError` if no reply parses within the budget.
pub async fn[T] AIAgent::request_structured(
  self : AIAgent,
  input : String,
  schema : StructuredSchema[T],
  max_fixes? : Int = 2,
) -> StructuredResponse[T] {
  let builder = @prompt.PromptBuilder::new()
  if self.system_prompt is Some(sp) {
    builder.system(sp) |> ignore
  }
  builder
  .system(
    "Respond with a single JSON object and nothing else — no prose, no code fences. It must match this JSON schema for \"" +
    schema.name +
    "\" (" +
    schema.description +
    "): " +
    schema.schema.to_json_schema().stringify(),
  )
  .user(input)
  |> ignore
  let mut prompt = builder.build()
  let descriptors = self.tool_registry.descriptors()
  for _attempt = 0; _attempt <= max_fixes; _attempt = _attempt + 1 {
    let reply = self.executor.execute(
      prompt~,
      model=self.model,
      tools=descriptors,
    )
    let text = reply.text_content()
    let parsed = if extract_json_object(text) is Some(js) {
      (schema.parse)(@json.parse(js) catch { _ => Json::null() })
    } else {
      None
    }
    if parsed is Some(value) {
      return { value, raw: text, }
    }
    prompt = prompt.append(reply)
    prompt = prompt.append(
      @prompt.Message::user(
        "That was not a valid JSON object matching the schema. Respond again with only the JSON object.",
      ),
    )
  }
  raise AgentError(
    "no valid structured response after " +
    (max_fixes + 1).to_string() +
    " attempts",
  )
}
