///|
/// A tool with a nested argument shape: the descriptor states its schema through
/// the explicit `ToolParameterType` model (MoonBit has no reflection to derive it).
struct Search {}

///|
impl @tools.Tool for Search with fn descriptor(_self) {
  {
    name: "search",
    description: "search a corpus with filters",
    required_parameters: [
      {
        name: "query",
        description: "the search string",
        ptype: @tools.TString,
      },
    ],
    optional_parameters: [
      {
        name: "filters",
        description: "structured filters",
        ptype: @tools.TObject(
          properties=[
            {
              name: "tags",
              description: "tag whitelist",
              ptype: @tools.TList(@tools.TString),
            },
            {
              name: "max_results",
              description: "cap on hits",
              ptype: @tools.TInteger,
            },
          ],
          required=["tags"],
        ),
      },
      {
        name: "format",
        description: "result rendering",
        ptype: @tools.TEnum(["json", "text", "markdown"]),
      },
      {
        name: "score",
        description: "either a float threshold or the literal null",
        ptype: @tools.TAnyOf([
          { name: "", description: "", ptype: @tools.TFloat, },
          { name: "", description: "", ptype: @tools.TNull, },
        ]),
      },
      {
        name: "verbose",
        description: "include debug fields",
        ptype: @tools.TBoolean,
      },
    ],
  }
}

///|
impl @tools.Tool for Search with fn execute_raw(_self, args) {
  args.stringify()
}

///|
/// The tool/registry model: every `ToolParameterType` variant renders to its
/// JSON-Schema fragment, a `ToolDescriptor` composes them into one schema, and a
/// `ToolRegistry` holds tools and hands back their descriptors for a request.
///
///     moon run examples/04-tool-schema --target native
#coverage.skip
fn main {
  let samples : Array[(String, @tools.ToolParameterType)] = [
    ("string", @tools.TString),
    ("integer", @tools.TInteger),
    ("enum", @tools.TEnum(["celsius", "fahrenheit"])),
    ("list", @tools.TList(@tools.TInteger)),
    (
      "anyOf",
      @tools.TAnyOf([
        { name: "", description: "", ptype: @tools.TString, },
        { name: "", description: "", ptype: @tools.TNull, },
      ]),
    ),
  ]
  for s in samples {
    let (label, ptype) = s
    println(label + ": " + ptype.to_json_schema().stringify())
  }

  // The whole tool as one input schema.
  let registry = @tools.ToolRegistry::new().add(Search::{ })
  let descriptors = registry.descriptors()
  println("registry holds \{descriptors.length()} tool(s)")
  let search = descriptors[0]
  println(
    "\{search.name}: \{search.required_parameters.length()} required, \{search.optional_parameters.length()} optional",
  )
  let object_schema = @tools.TObject(
    properties=search.required_parameters + search.optional_parameters,
    required=["query"],
  )
  println(object_schema.to_json_schema().stringify())

  // Lookup by name; a miss is None.
  println("get_tool(search) is Some: \{registry.get_tool("search") is Some(_)}")
  println("get_tool(missing) is None: \{registry.get_tool("missing") is None}")
}
