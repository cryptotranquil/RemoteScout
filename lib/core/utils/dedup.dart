/// Deterministic duplicate detection (03_App_Flow.md §9, TRD §5.3).
///
/// 1. Ingestion key `(source, external_id)` — never ingest the same listing
///    twice from the same source.
/// 2. Cross-source key `(company, title, apply_url)` after normalization —
///    the same job from a different source never becomes a second card.
library;

String normalizeKeyPart(String input) => input
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9@.]+'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

String normalizeUrlKey(String input) {
  var u = input.toLowerCase().trim();
  u = u.replaceAll(RegExp(r'^https?://'), '');
  u = u.replaceAll(RegExp(r'/+$'), '');
  return u;
}

/// True when [a] and [b] represent the same listing.
bool isDuplicateJob(String ingestA, String crossA, String ingestB, String crossB) =>
    ingestA == ingestB || crossA == crossB;

class DedupIndex {
  final Set<String> _ingestKeys = {};
  final Set<String> _crossKeys = {};

  /// Returns true if [ingestKey]/[crossKey] was not seen before (and records it).
  bool tryAdd(String ingestKey, String crossKey) {
    if (_ingestKeys.contains(ingestKey) || _crossKeys.contains(crossKey)) {
      return false;
    }
    _ingestKeys.add(ingestKey);
    _crossKeys.add(crossKey);
    return true;
  }

  /// Rebuilds the index from existing keys (used when loading the store).
  void seed(Iterable<(String, String)> keys) {
    for (final (ingest, cross) in keys) {
      _ingestKeys.add(ingest);
      _crossKeys.add(cross);
    }
  }

  bool containsIngest(String ingestKey) => _ingestKeys.contains(ingestKey);

  bool containsCross(String crossKey) => _crossKeys.contains(crossKey);
}
