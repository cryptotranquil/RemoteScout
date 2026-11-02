import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remotescout/features/discover/search_on_sites.dart';

void main() {
  test('search site URLs encode keywords and target their site', () {
    final glassdoor = searchSites
        .singleWhere((site) => site.name == 'Glassdoor')
        .searchUri('junior data analyst');
    expect(glassdoor.host, 'www.glassdoor.com');
    expect(glassdoor.path, '/Job/jobs.htm');
    expect(glassdoor.queryParameters['sc.keyword'], 'junior data analyst');

    final upwork = searchSites
        .singleWhere((site) => site.name == 'Upwork')
        .searchUri('C++ remote');
    expect(upwork.queryParameters['q'], 'C++ remote');

    final kaggle = searchSites
        .singleWhere((site) => site.name == 'Kaggle')
        .searchUri('data analyst site:kaggle.com/jobs');
    expect(kaggle.host, 'www.google.com');
    expect(
      kaggle.queryParameters['q'],
      'data analyst site:kaggle.com/jobs',
    );

    for (final site in [
      'Remote Rocketship',
      'DataJobs',
      'teftef.space',
      'RemoteJobs.io',
      'Wellfound',
      'Andela',
    ]) {
      final uri = searchSites
          .singleWhere((candidate) => candidate.name == site)
          .searchUri('junior data analyst');
      expect(uri.host, 'www.google.com', reason: site);
      expect(
        uri.queryParameters['q'],
        contains('junior data analyst site:'),
        reason: site,
      );
    }

    final rocketship =
        searchSites.singleWhere((site) => site.name == 'Remote Rocketship');
    expect(rocketship.path, '/remote-jobs/');
    final andela = searchSites.singleWhere((site) => site.name == 'Andela');
    expect(andela.path, '/for-talent');
    expect(searchSites, hasLength(17));
  });

  testWidgets('site search uses profile keywords and opens externally',
      (tester) async {
    Uri? openedUri;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SearchOnSites(
              initialKeywords: 'junior data analyst',
              launchSearch: (uri) async {
                openedUri = uri;
                return true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Search on other job sites'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'junior data analyst',
    );

    await tester.tap(find.byKey(const ValueKey('search-site-Upwork')));
    await tester.pump();
    expect(openedUri?.host, 'www.upwork.com');
    expect(openedUri?.queryParameters['q'], 'junior data analyst');
  });

  testWidgets('search buttons stay disabled without keywords', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: SearchOnSites()),
        ),
      ),
    );

    await tester.tap(find.text('Search on other job sites'));
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('search-site-Glassdoor')),
    );
    expect(button.onPressed, isNull);
  });
}
