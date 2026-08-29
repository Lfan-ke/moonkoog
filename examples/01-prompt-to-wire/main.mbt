///|
struct Weather {}

///|
impl @tools.Tool for Weather with fn descriptor(_) {
  {
    name: "weather",
    description: "current weather for a city",
    required_parameters: [
      {
        name: "city",
        description: "city to look up, e.g. heke1228",
        ptype: @tools.TString,
      },
    ],
    optional_parameters: [
      {
        name: "unit",
        description: "temperature unit",
        ptype: @tools.TEnum(["celsius", "fahrenheit"]),
      },
    ],
  }
}

///|
impl @tools.Tool for Weather with fn execute_raw(_, _args) {
  "{\"temp_c\": 23, \"sky\": \"clear\"}"
}

///|
/// Prompt to wire. Build a Koog prompt — a system instruction, a user turn, one
/// registered tool, and `LLMParams` that force that tool — then map it to the
/// Anthropic Messages request body and print the JSON that goes on the wire. No
/// LLM is called; this is the request half of a client, on its own.
///
///     moon run examples/01-prompt-to-wire --target native
#coverage.skip
fn main {
  let registry = @tools.ToolRegistry::new().add(Weather::{ })
  let params : @prompt.LLMParams = {
    ..@prompt.LLMParams::default(),
    temperature: Some(0.2),
    max_tokens: Some(1024),
    tool_choice: Some(@prompt.Named("weather")),
  }
  let prompt = @prompt.PromptBuilder::new()
    .system("You are a terse weather bot. Answer in one short sentence.")
    .user("what's the weather in heke1228 today?")
    .params(params)
    .build()
  let model = @llm.claude_sonnet_4_5
  let wire = @client.to_anthropic_request(prompt, model, registry.descriptors())
  println(
    "model \{model.id} - ToolChoice capable: \{model.supports(@llm.ToolChoice)}",
  )
  println(wire.stringify())
}
