// Agent checkpointing and persistence (Koog `agents-features-snapshot`): a snapshot of a graph
// agent's resumable state — its message history, LLM configuration, serialized storage, and its
// position in the strategy graph — plus a storage provider that keeps a session's checkpoints so an
// agent can be restored to an earlier point. Timestamps are supplied by the caller (MoonBit has no
// ambient clock), keeping checkpoints deterministic.
// Source: agents/agents-features/agents-features-snapshot/.../feature/AgentCheckpointData.kt +
// providers/PersistenceStorageProvider.kt.

///|
/// A checkpoint of a graph agent's state at a point in its run (Koog `AgentCheckpointData` with
/// `GraphCheckpointProperties`): everything needed to resume — the message history, the LLM params /
/// model / tool names, the serialized `AgentStorage`, the current node and its last output, the
/// iteration count, and a schema version.
pub(all) struct AgentCheckpoint {
  checkpoint_id : String
  created_at : Int64
  message_history : Array[@prompt.Message]
  llm_params : @prompt.LLMParams?
  llm_model : @llm.LLModel?
  tools : Array[String]?
  storage : Json
  node_path : String
  last_output : Json?
  agent_iterations : Int
  version : Int64
}

///|
/// A store of a session's checkpoints (Koog `PersistenceStorageProvider`): save a checkpoint under a
/// session id, list a session's checkpoints, or fetch the most recent one. In-memory here; a
/// database- or file-backed provider implements the same shape.
pub struct InMemoryPersistence {
  by_session : Map[String, Array[AgentCheckpoint]]
}

///|
/// A fresh empty persistence store.
pub fn InMemoryPersistence::new() -> InMemoryPersistence {
  { by_session: {}, }
}

///|
/// Save `checkpoint` under `session_id`.
pub fn InMemoryPersistence::save_checkpoint(
  self : InMemoryPersistence,
  session_id : String,
  checkpoint : AgentCheckpoint,
) -> Unit {
  match self.by_session.get(session_id) {
    Some(list) => list.push(checkpoint)
    None => self.by_session[session_id] = [checkpoint]
  }
}

///|
/// Every checkpoint saved for `session_id`, in save order.
pub fn InMemoryPersistence::get_checkpoints(
  self : InMemoryPersistence,
  session_id : String,
) -> Array[AgentCheckpoint] {
  match self.by_session.get(session_id) {
    Some(list) => list
    None => []
  }
}

///|
/// The most recent checkpoint for `session_id` (highest `created_at`), or `None`.
pub fn InMemoryPersistence::get_latest_checkpoint(
  self : InMemoryPersistence,
  session_id : String,
) -> AgentCheckpoint? {
  guard self.by_session.get(session_id) is Some(list) else { return None }
  guard list.length() > 0 else { return None }
  let mut latest = list[0]
  for checkpoint in list {
    if checkpoint.created_at > latest.created_at {
      latest = checkpoint
    }
  }
  Some(latest)
}
