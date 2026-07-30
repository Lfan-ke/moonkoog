// A retrying LLM client (Koog `RetryingPromptExecutor`): wrap a client and re-run a failed
// `execute` up to `max_attempts` times before giving up, so a transient provider error — a
// dropped connection, a 5xx, a rate-limit blip — doesn't fail the whole agent step. The other
// calls delegate straight through; `execute_streaming` inherits the retry through the default,
// which drives `execute`.

///|
/// A client that retries `execute` on failure.
pub struct RetryingClient {
  inner : &LLMClient
  max_attempts : Int
}

///|
/// Wrap `inner`, retrying a failed `execute` up to `max_attempts` times (default 3, i.e. the
/// first try plus two retries).
pub fn RetryingClient::new(
  inner : &LLMClient,
  max_attempts? : Int = 3,
) -> RetryingClient {
  { inner, max_attempts }
}

///|
pub impl LLMClient for RetryingClient with fn execute(
  self,
  prompt~,
  model~,
  tools~,
) {
  let mut attempt = 1
  for ;; {
    let reply = LLMClient::execute(self.inner, prompt~, model~, tools~) catch {
      e => {
        if attempt >= self.max_attempts {
          raise e
        }
        attempt = attempt + 1
        continue
      }
    }
    return reply
  }
}

///|
pub impl LLMClient for RetryingClient with fn provider(self) {
  self.inner.provider()
}

///|
pub impl LLMClient for RetryingClient with fn moderate(self, prompt~, model~) {
  LLMClient::moderate(self.inner, prompt~, model~)
}

///|
pub impl LLMClient for RetryingClient with fn execute_multiple(
  self,
  prompt~,
  model~,
  tools~,
) {
  LLMClient::execute_multiple(self.inner, prompt~, model~, tools~)
}
