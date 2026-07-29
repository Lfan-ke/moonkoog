///|
/// A snapshot of an agent's session at a point in its run (Koog
/// `AgentCheckpointData`): the message history so far, where the strategy graph
/// had reached (`node_id`) and the input pending there (`last_input`), the
/// iteration count, and a schema `version`. `created_at` is caller-supplied — Koog
/// stamps it from a `Clock`, which MoonBit has no ambient equivalent of. Restoring
/// a checkpoint replays `message_history` and resumes at `node_id`.
///
/// The advanced `graphProperties` / `plannerProperties` / free-form JSON `storage`
/// of Koog's record are folded to `node_id` + `last_input` here; the richer planner
/// state lands with the planner feature.
pub(all) struct AgentCheckpoint {
  checkpoint_id : String
  created_at : Int64
  message_history : Array[@prompt.Message]
  node_id : String?
  last_input : String?
  agent_iterations : Int
  version : Int64
} derive(Eq, Debug)

///|
/// The checkpoint storage contract (Koog `PersistenceStorageProvider`): save a
/// checkpoint under a session, list a session's checkpoints, or fetch its latest.
pub(open) trait PersistenceStorageProvider {
  fn save_checkpoint(Self, session_id : String, checkpoint : AgentCheckpoint) -> Unit
  fn get_checkpoints(Self, session_id : String) -> Array[AgentCheckpoint]
  fn get_latest_checkpoint(Self, session_id : String) -> AgentCheckpoint?
}

///|
/// An in-memory `PersistenceStorageProvider` (Koog `InMemoryPersistencyStorageProvider`):
/// checkpoints kept per session in save order, the latest being the last saved.
pub struct InMemoryPersistence {
  by_session : Map[String, Array[AgentCheckpoint]]
}

///|
/// An empty in-memory checkpoint store.
pub fn InMemoryPersistence::new() -> InMemoryPersistence {
  { by_session: Map([]) }
}

///|
pub impl PersistenceStorageProvider for InMemoryPersistence with fn save_checkpoint(
  self,
  session_id,
  checkpoint,
) {
  match self.by_session.get(session_id) {
    Some(cps) => cps.push(checkpoint)
    None => self.by_session[session_id] = [checkpoint]
  }
}

///|
pub impl PersistenceStorageProvider for InMemoryPersistence with fn get_checkpoints(
  self,
  session_id,
) {
  match self.by_session.get(session_id) {
    Some(cps) => [..cps]
    None => []
  }
}

///|
pub impl PersistenceStorageProvider for InMemoryPersistence with fn get_latest_checkpoint(
  self,
  session_id,
) {
  match self.by_session.get(session_id) {
    Some(cps) => cps.last()
    None => None
  }
}
