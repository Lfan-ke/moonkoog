///|
/// Choice selection (Koog `ChoiceSelectionStrategy`): given several candidate
/// completions, pick one. `FirstChoice` takes index 0; `LLMChoiceSelector` asks a
/// judge model which candidate to keep and returns the one it names. The candidate
/// list is what a client's `execute_multiple` produces when a model returns several.
///
///     moon run examples/13-choice-selection --target native
#coverage.skip
async fn main {
  @async.with_task_group(_g => {
    let candidates = [
      @prompt.Message::assistant("answer A"),
      @prompt.Message::assistant("answer B"),
      @prompt.Message::assistant("answer C"),
    ]
    let context = @prompt.PromptBuilder::new().user("which is best?").build()

    // The trivial strategy: keep the first.
    let first = @agent.FirstChoice::new()
    let picked_first = @agent.ChoiceSelectionStrategy::choose(
      first, context, candidates,
    )
    println("FirstChoice -> " + picked_first.text_content())

    // The LLM judge: a scripted judge that names candidate index 1.
    let judge = @agent.MockClient::new([@prompt.Message::assistant("I pick 1")])
    let selector = @agent.LLMChoiceSelector::new(judge, @llm.deepseek_v4_flash)
    let picked_judge = @agent.ChoiceSelectionStrategy::choose(
      selector, context, candidates,
    )
    println("LLMChoiceSelector -> " + picked_judge.text_content())
  })
}
