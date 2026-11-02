import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/scout_ui.dart';

typedef SearchSiteLauncher = Future<bool> Function(Uri uri);

class SearchSite {
  const SearchSite({
    required this.name,
    required this.host,
    required this.path,
    required this.queryParameter,
    this.googleSiteSearchDomain,
  });

  final String name;
  final String host;
  final String path;
  final String queryParameter;
  final String? googleSiteSearchDomain;

  Uri searchUri(String keywords) {
    final query = keywords.trim();
    final siteDomain = googleSiteSearchDomain;
    if (siteDomain != null) {
      return Uri.https(
        'www.google.com',
        '/search',
        {'q': '$query site:$siteDomain'},
      );
    }
    return Uri.https(host, path, {queryParameter: query});
  }
}

const searchSites = <SearchSite>[
  SearchSite(
    name: 'Remote4Africa',
    host: 'remote4africa.com',
    path: '/jobs',
    queryParameter: 'search',
  ),
  SearchSite(
    name: 'RemoteJobs.io',
    host: 'www.remotejobs.io',
    path: '/work-from-home',
    queryParameter: 'q',
    googleSiteSearchDomain: 'remotejobs.io',
  ),
  SearchSite(
    name: 'Dynamite Jobs',
    host: 'dynamitejobs.com',
    path: '/remote-jobs',
    queryParameter: 'search',
  ),
  SearchSite(
    name: 'JustRemote',
    host: 'justremote.co',
    path: '/remote-jobs',
    queryParameter: 'search',
  ),
  SearchSite(
    name: 'Glassdoor',
    host: 'www.glassdoor.com',
    path: '/Job/jobs.htm',
    queryParameter: 'sc.keyword',
  ),
  SearchSite(
    name: 'Wellfound',
    host: 'wellfound.com',
    path: '/jobs',
    queryParameter: 'query',
    googleSiteSearchDomain: 'wellfound.com/jobs',
  ),
  SearchSite(
    name: 'Upwork',
    host: 'www.upwork.com',
    path: '/nx/search/jobs/',
    queryParameter: 'q',
  ),
  SearchSite(
    name: 'Handshake',
    host: 'app.joinhandshake.com',
    path: '/stu/postings',
    queryParameter: 'query',
  ),
  SearchSite(
    name: 'Turing',
    host: 'www.turing.com',
    path: '/jobs',
    queryParameter: 'search',
  ),
  SearchSite(
    name: 'Remote Rocketship',
    host: 'www.remoterocketship.com',
    path: '/remote-jobs/',
    queryParameter: 'query',
    googleSiteSearchDomain: 'remoterocketship.com/remote-jobs',
  ),
  SearchSite(
    name: 'Outsourcely',
    host: 'www.outsourcely.com',
    path: '/remote-jobs',
    queryParameter: 'search',
  ),
  SearchSite(
    name: 'Andela',
    host: 'www.andela.com',
    path: '/for-talent',
    queryParameter: 'search',
    googleSiteSearchDomain: 'andela.com',
  ),
  SearchSite(
    name: 'Internship.com',
    host: 'www.internship.com',
    path: '/jobs',
    queryParameter: 'q',
  ),
  SearchSite(
    name: 'Kaggle',
    host: 'www.google.com',
    path: '/search',
    queryParameter: 'q',
  ),
  SearchSite(
    name: 'DataJobs',
    host: 'www.datajobs.com',
    path: '/',
    queryParameter: 'q',
    googleSiteSearchDomain: 'datajobs.com',
  ),
  SearchSite(
    name: 'teftef.space',
    host: 'teftef.space',
    path: '/en',
    queryParameter: 'q',
    googleSiteSearchDomain: 'teftef.space',
  ),
  SearchSite(
    name: 'Google Jobs',
    host: 'www.google.com',
    path: '/search',
    queryParameter: 'q',
  ),
];

class SearchOnSites extends StatefulWidget {
  const SearchOnSites({
    super.key,
    this.initialKeywords = '',
    this.launchSearch,
  });

  final String initialKeywords;
  final SearchSiteLauncher? launchSearch;

  @override
  State<SearchOnSites> createState() => _SearchOnSitesState();
}

class _SearchOnSitesState extends State<SearchOnSites> {
  late final TextEditingController _controller;
  late String _lastInitialKeywords;

  @override
  void initState() {
    super.initState();
    _lastInitialKeywords = widget.initialKeywords;
    _controller = TextEditingController(text: widget.initialKeywords);
  }

  @override
  void didUpdateWidget(covariant SearchOnSites oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialKeywords != _lastInitialKeywords &&
        _controller.text == _lastInitialKeywords) {
      _controller.text = widget.initialKeywords;
    }
    _lastInitialKeywords = widget.initialKeywords;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openSite(SearchSite site) async {
    final keywords = _controller.text.trim();
    if (keywords.isEmpty) return;
    final uri = site.searchUri(
      site.name == 'Kaggle'
          ? '$keywords site:kaggle.com/jobs'
          : site.name == 'Google Jobs'
              ? '$keywords jobs'
              : keywords,
    );
    try {
      final launched = await (widget.launchSearch ??
          (uri) => launchUrl(uri, mode: LaunchMode.externalApplication))(uri);
      if (!launched && mounted) {
        _showLaunchError();
      }
    } on PlatformException catch (error) {
      if (mounted) {
        _showLaunchError(error.message);
      }
    } on MissingPluginException {
      if (mounted) {
        _showLaunchError();
      }
    }
  }

  void _showLaunchError([String? details]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          details == null
              ? 'Could not open that job search.'
              : 'Could not open that job search: $details',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    final canSearch = _controller.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: ScoutSpace.md),
      child: Material(
        color: colors.card,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(ScoutRadius.md),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(Icons.travel_explore, color: colors.primary),
            title: Text('Search on other job sites', style: text.titleSmall),
            subtitle: Text(
              'Some sites use Google results to apply your keywords',
              style: text.bodySmall,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              ScoutSpace.md,
              0,
              ScoutSpace.md,
              ScoutSpace.md,
            ),
            children: [
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Keywords',
                  hintText: 'e.g. junior data analyst',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
              ),
              const SizedBox(height: ScoutSpace.sm),
              Text(
                'Kaggle Jobs has been discontinued; its button searches Google '
                'for Kaggle listings.',
                style: text.bodySmall,
              ),
              const SizedBox(height: ScoutSpace.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tier 3 and 4 sites',
                  style: text.labelMedium!.copyWith(color: colors.muted),
                ),
              ),
              const SizedBox(height: ScoutSpace.xs),
              Wrap(
                spacing: ScoutSpace.xs,
                runSpacing: ScoutSpace.xs,
                children: [
                  for (final site in searchSites)
                    OutlinedButton.icon(
                      key: ValueKey<String>('search-site-${site.name}'),
                      onPressed: canSearch ? () => _openSite(site) : null,
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: Text(site.name),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: ScoutSpace.sm,
                        ),
                        textStyle: text.labelMedium,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
