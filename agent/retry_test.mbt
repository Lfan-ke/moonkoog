// The retrying client: a client that fails a scripted number of times then succeeds proves
// the retry re-runs `execute` and gives up at `max_attempts`.

///|
suberror FlakyError {
  FlakyError(String)
}

///|
struct FlakyClient {
  mut calls : Int
  fail_times : Int
}

///|
impl @agent.LLMClient for FlakyClient with fn execute(
  self,
  prompt~,
  model~,
  tools~,
) {
  let _ = prompt
  let _ = model
  let _ = tools
  self.calls = self.calls + 1
  if self.calls <= self.fail_times {
    raise FlakyError("transient failure")
  }
  @prompt.Message::assistant("ok")
}

///|
impl @agent.LLMClient for FlakyClient with fn provider(self) {
  let _ = self
  @llm.openai
}

///|
impl @agent.LLMClient for FlakyClient with fn moderate(self, prompt~, model~) {
  let _ = self
  let _ = prompt
  let _ = model
  @agent.ModerationResult::safe()
}

///|
impl @agent.LLMClient for FlakyClient with fn execute_multiple(
  self,
  prompt~,
  model~,
  tools~,
) {
  [@agent.LLMClient::execute(self, prompt~, model~, tools~)]
}

///|
async test "retrying client: retries a transient failure and eventually succeeds" {
  @async.with_task_group(_g => {
    let flaky = FlakyClient::{ calls: 0, fail_times: 2, }
    let client = @agent.RetryingClient::new(flaky, max_attempts=3)
    let prompt = @prompt.PromptBuilder::new().user("hi").build()
    let reply = @agent.LLMClient::execute(
      client,
      prompt~,
      model=@llm.deepseek_v4_flash,
      tools=[],
    )
    assert_eq(reply.text_content(), "ok")
    assert_eq(flaky.calls, 3)
  })
}

///|
async test "retrying client: gives up after max_attempts" {
  @async.with_task_group(_g => {
    let flaky = FlakyClient::{ calls: 0, fail_times: 5, }
    let client = @agent.RetryingClient::new(flaky, max_attempts=2)
    let prompt = @prompt.PromptBuilder::new().user("hi").build()
    let failed = try {
      let _ = @agent.LLMClient::execute(
        client,
        prompt~,
        model=@llm.deepseek_v4_flash,
        tools=[],
      )
      false
    } catch {
      _ => true
    }
    assert_eq(failed, true)
    assert_eq(flaky.calls, 2)
  })
}
