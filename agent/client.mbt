///|
/// The LLM client contract (Koog `LLMClientAPI`, collapsed for the MVP with the
/// single-LLM `PromptExecutor` — a single-provider executor is a one-line delegate
/// to its client). `execute` sends a prompt with the tool descriptors the model
/// may call and returns the assistant reply; any tool calls come back inside the
/// reply's `parts` as `ToolCall`s. Streaming / multiple-choice / moderation are
/// deferred (Koog has them; out of MVP scope).
/// Source: prompt/prompt-executor/prompt-executor-clients/.../LLMClientAPI.kt.
pub(open) trait LLMClient {
  async fn execute(
    Self,
    prompt~ : @prompt.Prompt,
    model~ : @llm.LLModel,
    tools~ : Array[@tools.ToolDescriptor],
  ) -> @prompt.Message
  fn provider(Self) -> @llm.LLMProvider
}

///|
/// A deterministic in-memory client for tests: it replays a scripted list of
/// assistant replies, one per `execute` call, ignoring the prompt. This is what
/// lets the agent loop be tested without a network or a real model — the loop's
/// control flow is exercised by scripting "reply with a tool call", then "reply
/// with the final text".
pub struct MockClient {
  scripted : Array[@prompt.Message]
  mut next : Int
  provider_id : @llm.LLMProvider
}

///|
/// A mock that will hand back `scripted` replies in order.
pub fn MockClient::new(
  scripted : Array[@prompt.Message],
  provider? : @llm.LLMProvider = @llm.openai,
) -> MockClient {
  { scripted, next: 0, provider_id: provider }
}

///|
pub impl LLMClient for MockClient with fn execute(self, prompt~, model~, tools~) {
  let _ = prompt
  let _ = model
  let _ = tools
  let i = self.next
  self.next = self.next + 1
  self.scripted[i]
}

///|
pub impl LLMClient for MockClient with fn provider(self) {
  self.provider_id
}
