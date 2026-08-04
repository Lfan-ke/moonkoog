///|
fn show_int(x : Int?) -> String {
  match x {
    Some(n) => n.to_string()
    None => "none"
  }
}

///|
/// Agent state and checkpointing (Koog `AIAgentStorage` + persistence): typed values
/// go into a JSON-backed `AgentStorage` and come back at the type requested at the
/// call site; a snapshot round-trips through JSON. A full `AgentCheckpoint` — the
/// message history, model, tools, and storage at a strategy node — is then saved to
/// an `InMemoryPersistence` and read back, latest-first.
///
///     moon run examples/19-agent-checkpoint --target native
#coverage.skip
fn main {
  // Typed key/value storage backed by Json.
  let store = @agent.AgentStorage::new()
  store.set("count", 233)
  store.set("name", "heke1228")
  store.set("ratio", 0.5)
  println("count as Int: " + show_int(store.get("count")))
  println("name absent as Int: " + show_int(store.get("name")))
  println("size=\{store.size()} contains(name)=\{store.contains("name")}")
  let _ = store.remove("ratio")
  println("after remove(ratio): size=\{store.size()}")
  let snap = store.snapshot()
  println("snapshot: " + snap.stringify())

  // A fresh store restored from that snapshot holds the same values.
  let restored = @agent.AgentStorage::new()
  restored.restore(snap)
  println("restored count: " + show_int(restored.get("count")))

  // A checkpoint of a whole agent run, persisted and read back.
  let persistence = @agent.InMemoryPersistence::new()
  let checkpoint : @agent.AgentCheckpoint = {
    checkpoint_id: "cp-233",
    created_at: 233L,
    message_history: [
      @prompt.Message::user("what is 2 + 3?"),
      @prompt.Message::assistant("the answer is 5"),
    ],
    llm_params: Some(@prompt.LLMParams::default()),
    llm_model: Some(@llm.deepseek_v4_flash),
    tools: Some(["add"]),
    storage: snap,
    node_path: "send_tool_result",
    last_output: Some("the answer is 5"),
    agent_iterations: 2,
    version: 1L,
  }
  persistence.save_checkpoint("session-qwq", checkpoint)
  persistence.save_checkpoint("session-qwq", {
    ..checkpoint,
    checkpoint_id: "cp-234",
    created_at: 234L,
    node_path: "__finish__",
  })
  let all = persistence.get_checkpoints("session-qwq")
  println("session-qwq has \{all.length()} checkpoint(s)")
  match persistence.get_latest_checkpoint("session-qwq") {
    Some(cp) =>
      println(
        "latest: " +
        cp.checkpoint_id +
        " at node " +
        cp.node_path +
        ", history=\{cp.message_history.length()} msgs, iterations=\{cp.agent_iterations}",
      )
    None => println("no checkpoint")
  }
}
