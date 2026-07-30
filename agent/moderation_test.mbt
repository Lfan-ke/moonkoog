// Moderation (Koog `LLMClient.moderate`): the default is safe; a client can flag categories.

///|
struct FlaggingClient {}

///|
impl @agent.LLMClient for FlaggingClient with fn execute(
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
impl @agent.LLMClient for FlaggingClient with fn provider(_self) {
  @llm.openai
}

///|
impl @agent.LLMClient for FlaggingClient with fn moderate(
  _self,
  prompt~,
  model~,
) {
  let _ = prompt
  let _ = model
  @agent.ModerationResult::{
    is_harmful: true,
    categories: { "violence": { detected: true, confidence_score: Some(0.92) } },
  }
}

///|
async test "moderation: the default reports nothing harmful; a client can flag categories" {
  @async.with_task_group(_g => {
    // A client without moderation support reports nothing harmful.
    let mock = @agent.MockClient::new([@prompt.Message::assistant("hi")])
    let safe = mock.moderate(prompt=one_prompt(), model=model_for(@llm.openai))
    assert_eq(safe.is_harmful, false)
    assert_eq(safe.is_category_detected("violence"), false)
    // A moderation-capable client flags the categories its provider detected.
    let flagging : &@agent.LLMClient = FlaggingClient::{  }
    let flagged = flagging.moderate(
      prompt=one_prompt(),
      model=model_for(@llm.openai),
    )
    assert_eq(flagged.is_harmful, true)
    assert_eq(flagged.is_category_detected("violence"), true)
    assert_eq(flagged.is_category_detected("hate"), false)
  })
}
