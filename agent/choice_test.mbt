// Choice selection: FirstChoice takes index 0; the LLM judge returns the candidate it names.

///|
async test "choice selection: first takes index 0; the LLM judge takes the named index" {
  @async.with_task_group(_g => {
    let choices = [
      @prompt.Message::assistant("answer A"),
      @prompt.Message::assistant("answer B"),
      @prompt.Message::assistant("answer C"),
    ]
    let empty = @prompt.PromptBuilder::new().build()
    let first = @agent.FirstChoice::new()
    assert_eq(
      @agent.ChoiceSelectionStrategy::choose(first, empty, choices).text_content(),
      "answer A",
    )
    let judge = @agent.MockClient::new([@prompt.Message::assistant("I pick 1")])
    let selector = @agent.LLMChoiceSelector::new(judge, @llm.deepseek_v4_flash)
    assert_eq(
      @agent.ChoiceSelectionStrategy::choose(selector, empty, choices).text_content(),
      "answer B",
    )
  })
}
