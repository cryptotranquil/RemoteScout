import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:remotescout/data/app_store.dart';
import 'package:remotescout/data/local_store.dart';
import 'package:remotescout/models/models.dart';

import 'fixtures/mock_data.dart';

void main() {
  late Directory directory;
  late LocalStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('rs_mock_cleanup');
    Hive.init(directory.path);
    store = await LocalStore.open();
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('removes legacy demo jobs and their related local data', () async {
    await seedMockJobs(store);
    await store.saveProfile(
      Profile(
        id: AppStore.userId,
        name: 'Scout',
        email: 'scout@example.com',
        skills: const ['SQL'],
        targetRoles: const ['Analyst'],
        preferredCountries: const ['worldwide'],
        experienceLevel: 'junior',
        createdAt: DateTime(2026, 9, 1),
      ),
    );
    await store.rescore();
    await store.trackJob(
      store.allJobs.first.id,
      ApplicationStatus.saved,
    );

    await store.removeBundledMockData();

    expect(store.allJobs, isEmpty);
    expect(store.allMatches, isEmpty);
    expect(store.allApplications, isEmpty);
  });
}
