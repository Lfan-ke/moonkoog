///|
/// A conversation role. Koog 1.1.1 collapses to three: a tool exchange is carried
/// as parts inside a user/assistant message, not as a fourth top-level role.
pub(all) enum Role {
  System
  User
  Assistant
} derive(Eq, Debug, ToJson)

///|
/// One typed piece of a message's content. Koog 1.1.1 moved off flat string
/// content to an ordered list of `MessagePart`s. A `ToolCall` carries its
/// arguments as a JSON value (Koog keeps the raw JSON string; we keep it parsed);
/// a `ToolResult` carries the exact string the model is shown.
pub(all) enum MessagePart {
  Text(String)
  Reasoning(Array[String])
  ToolCall(id~ : String?, tool~ : String, args~ : Json)
  ToolResult(id~ : String?, tool~ : String, output~ : String, is_error~ : Bool)
} derive(Eq, Debug, ToJson)

///|
/// A single message: a role and its ordered content parts. `finish_reason` is the
/// provider's stop reason on an assistant reply, `None` on a request message.
pub(all) struct Message {
  role : Role
  parts : Array[MessagePart]
  finish_reason : String?
} derive(Eq, Debug, ToJson)

///|
/// A plain system message.
pub fn Message::system(text : String) -> Message {
  { role: System, parts: [Text(text)], finish_reason: None, }
}

///|
/// A plain user message.
pub fn Message::user(text : String) -> Message {
  { role: User, parts: [Text(text)], finish_reason: None, }
}

///|
/// A plain assistant message.
pub fn Message::assistant(text : String) -> Message {
  { role: Assistant, parts: [Text(text)], finish_reason: None, }
}

///|
/// A user message carrying a single tool result (a `ToolResult` is a request
/// part, so it rides a user message). What the agent loop appends after running a
/// tool.
pub fn Message::tool_result(
  tool~ : String,
  output~ : String,
  id? : String? = None,
  is_error? : Bool = false,
) -> Message {
  {
    role: User,
    parts: [ToolResult(id~, tool~, output~, is_error~)],
    finish_reason: None,
  }
}

///|
/// The concatenated text of every `Text` part, joined by `separator` (Koog's
/// `Message.textContent`). Non-text parts contribute nothing.
pub fn Message::text_content(
  self : Message,
  separator? : String = "\n",
) -> String {
  let texts = []
  for part in self.parts {
    match part {
      Text(t) => texts.push(t)
      _ => ()
    }
  }
  texts.join(separator)
}

///|
/// The tool calls this message requests: its `ToolCall` parts, in order. Empty
/// when the message is a plain text reply — the loop's signal to finish.
pub fn Message::tool_calls(self : Message) -> Array[MessagePart] {
  let calls = []
  for part in self.parts {
    if part is ToolCall(..) {
      calls.push(part)
    }
  }
  calls
}
