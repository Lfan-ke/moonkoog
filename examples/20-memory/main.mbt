///|
fn render(f : @memory.Fact) -> String {
  match f {
    SingleFact(concept~, value~, ..) => concept.keyword + " = " + value
    MultipleFacts(concept~, values~, ..) =>
      concept.keyword + " = [" + values.join(", ") + "]"
  }
}

///|
/// Agent memory (Koog `agents-features-memory`): facts about a subject, held under
/// a scope. A `Concept` names what is remembered and whether it is single- or
/// multi-valued; `load` filters by concept, `load_all` returns a whole bucket, and
/// buckets are isolated by `MemorySubject` and `MemoryScope`.
///
///     moon run examples/20-memory --target native
#coverage.skip
fn main {
  let mem = @memory.InMemoryProvider::new()
  let name : @memory.Concept = {
    keyword: "user_name",
    description: "the user's name",
    fact_type: Single,
  }
  let hobbies : @memory.Concept = {
    keyword: "hobbies",
    description: "the user's hobbies",
    fact_type: Multiple,
  }

  // Save into the user/product bucket.
  mem.save(
    SingleFact(concept=name, value="lfanke", timestamp=233L),
    @memory.subject_user,
    ScopeProduct,
  )
  mem.save(
    MultipleFacts(concept=hobbies, values=["chess", "hiking"], timestamp=234L),
    @memory.subject_user,
    ScopeProduct,
  )
  println(
    "subject '\{@memory.subject_user.name}' priority=\{@memory.subject_user.priority}",
  )

  // load filters by concept; load_all returns the bucket.
  for f in mem.load(name, @memory.subject_user, ScopeProduct) {
    println("load(user_name): " + render(f))
  }
  println(
    "load_all(user/product): \{mem.load_all(@memory.subject_user, ScopeProduct).length()} fact(s)",
  )
  for f in mem.load_all(@memory.subject_user, ScopeProduct) {
    println("  " + render(f))
  }

  // A different subject or scope is a different, empty bucket.
  println(
    "load(user_name) for machine subject: \{mem.load(name, @memory.subject_machine, ScopeProduct).length()} fact(s)",
  )
  println(
    "load(user_name) in agent scope: \{mem.load(name, @memory.subject_user, ScopeAgent("assistant")).length()} fact(s)",
  )
}
