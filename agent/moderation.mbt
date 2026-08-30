///|
/// One safety category's verdict (Koog `ModerationCategoryResult`): whether the category was
/// detected in the content and, when the provider gives one, its confidence score.
pub(all) struct ModerationCategoryResult {
  detected : Bool
  confidence_score : Double?
} derive(Eq, Debug, ToJson, FromJson)

///|
/// A moderation verdict (Koog `ModerationResult`): whether the content is harmful overall and
/// the per-category detections a provider's moderation endpoint returned.
pub(all) struct ModerationResult {
  is_harmful : Bool
  categories : Map[String, ModerationCategoryResult]
} derive(Eq, Debug, ToJson, FromJson)

///|
/// A verdict that flags nothing — what a client without moderation support returns.
pub fn ModerationResult::safe() -> ModerationResult {
  { is_harmful: false, categories: Map([]), }
}

///|
/// Whether `category` was detected in the moderated content.
pub fn ModerationResult::is_category_detected(
  self : ModerationResult,
  category : String,
) -> Bool {
  match self.categories.get(category) {
    Some(r) => r.detected
    None => false
  }
}
