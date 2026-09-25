import 'package:flutter_test/flutter_test.dart';
import 'package:remotescout/core/utils/dedup.dart';
import 'package:remotescout/models/models.dart';

Job _job({
  required String id,
  required String externalId,
  required String source,
  String company = 'Example Labs',
  String title = 'Junior Data Analyst',
  String applyUrl = 'https://remotive.com/remote-jobs/data/analyst-1',
}) {
  final now = DateTime(2026, 9, 25);
  return Job(
    id: id,
    externalId: externalId,
    source: source,
    title: title,
    company: company,
    description: '',
    applyUrl: applyUrl,
    sourceUrl: applyUrl,
    locationText: 'Worldwide',
    locationScope: LocationScope.worldwide,
    employmentType: 'full_time',
    publishedAt: now,
    collectedAt: now,
  );
}

void main() {
  test('same (source, external_id) is a duplicate', () {
    final a = _job(id: '1', externalId: 'ext-9', source: 'remotive');
    final b = _job(id: '2', externalId: 'ext-9', source: 'remotive',
        applyUrl: 'https://example.com/other');
    expect(
      isDuplicateJob(a.ingestKey, a.crossSourceKey, b.ingestKey, b.crossSourceKey),
      isTrue,
    );
  });

  test('near-identical listing from a different source is a duplicate', () {
    // Same company/title/apply_url — only the trailing slash and casing differ.
    final a = _job(
      id: '1',
      externalId: 'ext-9',
      source: 'remotive',
      applyUrl: 'https://remotive.com/remote-jobs/data/analyst-1/',
    );
    final b = _job(
      id: '2',
      externalId: 'ro-77',
      source: 'remoteok',
      applyUrl: 'https://REmotive.com/remote-jobs/data/analyst-1',
    );
    expect(
      isDuplicateJob(a.ingestKey, a.crossSourceKey, b.ingestKey, b.crossSourceKey),
      isTrue,
    );
  });

  test('different jobs are not duplicates', () {
    final a = _job(id: '1', externalId: 'ext-9', source: 'remotive');
    final b = _job(
        id: '2',
        externalId: 'ext-10',
        source: 'remotive',
        title: 'Junior BI Analyst',
        company: 'Northwind',
        applyUrl: 'https://remotive.com/remote-jobs/data/bi-10');
    expect(
      isDuplicateJob(a.ingestKey, a.crossSourceKey, b.ingestKey, b.crossSourceKey),
      isFalse,
    );
  });

  test('DedupIndex rejects both duplicate flavours', () {
    final index = DedupIndex();
    expect(index.tryAdd('remotive|ext-9', 'labs|analyst|url'), isTrue);
    // Same ingest key.
    expect(index.tryAdd('remotive|ext-9', 'other|other|other'), isFalse);
    // Same cross-source key from another source.
    expect(index.tryAdd('remoteok|ro-1', 'labs|analyst|url'), isFalse);
    // Genuinely new listing.
    expect(index.tryAdd('remoteok|ro-2', 'co|title|u'), isTrue);
  });

  test('near-identical listings: only the first ingestion wins', () {
    final store = DedupIndex();
    final first = _job(id: '1', externalId: 'e1', source: 'remotive');
    final dupe = _job(
      id: '2',
      externalId: 'e2',
      source: 'remoteok',
      applyUrl: 'https://remotive.com/remote-jobs/data/analyst-1/',
    );
    expect(store.tryAdd(first.ingestKey, first.crossSourceKey), isTrue);
    expect(store.tryAdd(dupe.ingestKey, dupe.crossSourceKey), isFalse);
  });
}
