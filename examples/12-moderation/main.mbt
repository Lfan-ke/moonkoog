///|
fn model_for(p : @llm.LLMProvider) -> @llm.LLModel {
  {
    provider: p,
    id: "test-model",
    capabilities: [],
    context_length: None,
    max_output_tokens: None,
  }
}

///|
fn one_prompt() -> @prompt.Prompt {
  @prompt.PromptBuilder::new().user("is this text safe?").build()
}

///|
/// A moderation-capable client that flags a category.
struct Flagging {}

///|
impl @agent.LLMClient for Flagging with fn execute(
  _self,
  prompt~,
  model~,
  tools~,
) {
  let _ = prompt
  let _ = model
  let _ = tools
  @prompt.Message::assistant("ok")
}

///|
impl @agent.LLMClient for Flagging with fn provider(_self) {
  @llm.openai
}

///|
impl @agent.LLMClient for Flagging with fn moderate(_self, prompt~, model~) {
  let _ = prompt
  let _ = model
  {
    is_harmful: true,
    categories: {
      "violence": { detected: true, confidence_score: Some(0.92), },
      "hate": { detected: false, confidence_score: Some(0.02), },
    },
  }
}

///|
impl @agent.LLMClient for Flagging with fn execute_multiple(
  self,
  prompt~,
  model~,
  tools~,
) {
  [@agent.LLMClient::execute(self, prompt~, model~, tools~)]
}

///|
/// Moderation (Koog `LLMClient.moderate`): a plain client has no moderation and
/// reports nothing harmful; a moderation-capable client returns a `ModerationResult`
/// whose per-category flags a caller queries with `is_category_detected`.
///
///     moon run examples/12-moderation --target native
#coverage.skip
async fn main {
  @async.with_task_group(_g => {
    let model = model_for(@llm.openai)
    let plain = @agent.MockClient::new([@prompt.Message::assistant("hi")])
    let safe = plain.moderate(prompt=one_prompt(), model~)
    println(
      "plain client: harmful=\{safe.is_harmful} violence=\{safe.is_category_detected("violence")}",
    )
    let flagging : &@agent.LLMClient = Flagging::{ }
    let checked = flagging.moderate(prompt=one_prompt(), model~)
    println(
      "moderating client: harmful=\{checked.is_harmful} violence=\{checked.is_category_detected("violence")} hate=\{checked.is_category_detected("hate")}",
    )
  })
}
