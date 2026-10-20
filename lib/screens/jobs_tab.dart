import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../widgets/job_card.dart';

class JobsTab extends StatefulWidget {
  const JobsTab({super.key});

  @override
  State<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<JobsTab> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);          // NEW
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);       // NEW
    _searchController.dispose();
    super.dispose();
  }

  // NEW: the app came back to the front → pick up what the background found
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadData();
  }
  // ===== PART 1: State =====
  List<Job> _jobs = [];
  Set<String> _mutedCompanyIds = {};
  Set<String> _mutedCompanyNames = {};
  Map<String, int> _companyOrder = {};
  String? _expandedJobId;
  bool _isLoading = true;

  bool _isRefreshing = false;                       // NEW
  String _searchText = '';                          // NEW
  bool _showOnlyFavourites = false;                 // NEW
  String _sortBy = 'date';                          // NEW: title/date/location/mode
  bool _ascending = false;                          // NEW: false = newest first
  final _searchController = TextEditingController(); // NEW

  // ===== PART 2: Loading =====

  Future<void> _loadData() async {
    final savedJobs = await StorageService.loadJobs();
    final companies = await StorageService.loadCompanies();

    // Only keep jobs whose company still exists
    final companyIds = companies.map((c) => c.id).toSet();
    final jobs =
        savedJobs.where((j) => companyIds.contains(j.companyId)).toList();

    if (!mounted) return;
    setState(() {
      _jobs = jobs;
      _companyOrder = {
        for (var i = 0; i < companies.length; i++) companies[i].id: i
      };
      _mutedCompanyIds =
          companies.where((c) => c.isMuted).map((c) => c.id).toSet();
      _mutedCompanyNames = companies
          .where((c) => c.isMuted)
          .map((c) => c.name.toLowerCase())
          .toSet();
      _isLoading = false;
    });
  }

  // The pipeline: everything that decides what appears on screen
  List<Job> get _visibleJobs {
    // Stage 1: not removed, not from a muted company
    var list = _jobs.where((j) {
      final muted = _mutedCompanyIds.contains(j.companyId) ||
          _mutedCompanyNames.contains(j.companyName.toLowerCase());
      return !j.isRemoved && !muted;
    }).toList();

    final ordered = [...list]
      ..sort((a, b) => (_companyOrder[a.companyId] ?? 0)
          .compareTo(_companyOrder[b.companyId] ?? 0));

    final owners = <String, String>{}; // job key → company that "owns" it
    final unique = <Job>[];
    for (final j in ordered) {
      final key = _dupKey(j);
      final owner = owners[key];
      if (owner != null && owner != j.companyId) continue; // a copy → skip
      owners[key] = j.companyId;
      unique.add(j);
    }
    list = unique;

    // Stage 2: favourites only?
    if (_showOnlyFavourites) {
      list = list.where((j) => j.isFavourite).toList();
    }

    // Stage 3: search
    final q = _searchText.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((j) {
        return j.title.toLowerCase().contains(q) ||
            j.role.toLowerCase().contains(q) ||
            j.companyName.toLowerCase().contains(q) ||
            j.location.toLowerCase().contains(q) ||
            j.mode.toLowerCase().contains(q) ||
            j.description.toLowerCase().contains(q) ||
            (j.noLongerListed &&                         // NEW
                q.length >= 3 &&
                'no longer listed'.contains(q));
      }).toList();
    }

    // Stage 4: sort
    list.sort((a, b) {
      int result;
      switch (_sortBy) {
        case 'title':
          result = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case 'location':
          result = a.location.toLowerCase().compareTo(b.location.toLowerCase());
          break;
        case 'mode':
          result = a.mode.toLowerCase().compareTo(b.mode.toLowerCase());
          break;
        default: // 'date'
          result = a.postedDate.compareTo(b.postedDate);
      }
      return _ascending ? result : -result; // flip for descending
    });

    return list;
  }
  // Human-readable name of the current sort      ← PASTE BELOW THIS LINE
  String get _sortLabel {
    switch (_sortBy) {
      case 'title':
        return _ascending ? 'Title A → Z' : 'Title Z → A';
      case 'location':
        return _ascending ? 'Location A → Z' : 'Location Z → A';
      case 'mode':
        return _ascending ? 'Mode A → Z' : 'Mode Z → A';
      default:
        return _ascending ? 'Oldest first' : 'Newest first';
    }
  }

  String _dupKey(Job j) {
    String clean(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    final city = j.location.split(',').first; // "San Francisco, CA" → city only
    return '${clean(j.title)}|${clean(city)}';
  }

  // This job + the same job listed by OTHER companies
  List<Job> _copiesOf(Job job) {
    final key = _dupKey(job);
    return _jobs
        .where((j) =>
            j.id == job.id ||
            (j.companyId != job.companyId && _dupKey(j) == key))
        .toList();
  }

  List<String> _otherListings(Job job) {
    final names = <String>{}; // a Set, so each name appears once

    for (final j in _copiesOf(job)) {
      if (j.id == job.id) continue;   // skip the job itself
      if (j.isRemoved) continue;      // you removed that copy

      final muted = _mutedCompanyIds.contains(j.companyId) ||
          _mutedCompanyNames.contains(j.companyName.toLowerCase());
      if (muted) continue;            // you muted that company

      names.add(j.companyName);
    }
    return names.toList();
  }

  Future<void> _save() async {        // ← existing code, stays as it is
    await StorageService.saveJobs(_jobs);
  }

  // NEW: refresh (fake delay for now; real fetching comes in Lesson 5)
  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);

    final result = await SyncService.syncAll(); // the real fetch!
    await _loadData();

    if (!mounted) return;
    setState(() => _isRefreshing = false);

    final count = result.newJobs.length;
    _showMessage(count == 0
        ? 'Up to date, no new jobs'
        : '$count new ${count == 1 ? 'job' : 'jobs'} found');

    if (result.errors.isNotEmpty) {
      _showSyncErrors(result.errors);
    }
  }

  void _showSyncErrors(List<String> errors) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Some pages could not be read'),
        content: SingleChildScrollView(child: Text(errors.join('\n\n'))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ===== PART 3: Expand / collapse =====
  void _toggleExpand(Job job) {
    setState(() {
      _expandedJobId = (_expandedJobId == job.id) ? null : job.id;
    });
  }

  void _collapseAll() {
    FocusScope.of(context).unfocus(); // NEW: also hides the keyboard
    if (_expandedJobId != null) {
      setState(() => _expandedJobId = null);
    }
  }

  // ===== PART 4: Actions =====
  void _toggleFavourite(Job job) {
    final newValue = !job.isFavourite;
    setState(() {
      for (final j in _copiesOf(job)) {
        j.isFavourite = newValue;
      }
    });
    _save();
    _showMessage(newValue ? 'Added to favourites' : 'Removed from favourites');
  }

  void _removeJob(Job job) {
    final copies = _copiesOf(job);
    setState(() {
      for (final j in copies) {
        j.isRemoved = true;
      }
      if (_expandedJobId == job.id) _expandedJobId = null;
    });
    _save();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${job.title} removed'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            setState(() {
              for (final j in copies) {
                j.isRemoved = false;
              }
            });
            _save();
          },
        ),
      ),
    );
  }

  Future<void> _openInBrowser(Job job) async {
    final uri = Uri.parse(job.url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showMessage('Could not open the link');
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ===== PART 5: Long-press menu =====
  void _showJobOptions(Job job) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Open in browser'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openInBrowser(job);
                },
              ),
              ListTile(
                leading: Icon(job.isFavourite ? Icons.star : Icons.star_border),
                title: Text(job.isFavourite
                    ? 'Remove from favourites'
                    : 'Mark as favourite'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _toggleFavourite(job);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove from list'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _removeJob(job);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ===== PART 5B: Sort menu (NEW) =====
  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Sort by',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                _sortTile(sheetContext, 'Newest first', 'date', false),
                _sortTile(sheetContext, 'Oldest first', 'date', true),
                _sortTile(sheetContext, 'Title A → Z', 'title', true),
                _sortTile(sheetContext, 'Title Z → A', 'title', false),
                _sortTile(sheetContext, 'Location A → Z', 'location', true),
                _sortTile(sheetContext, 'Location Z → A', 'location', false),
                _sortTile(sheetContext, 'Mode A → Z', 'mode', true),
                _sortTile(sheetContext, 'Mode Z → A', 'mode', false),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sortTile(
      BuildContext sheetContext, String label, String sortBy, bool ascending) {
    final selected = _sortBy == sortBy && _ascending == ascending;
    return ListTile(
      title: Text(label),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: () {
        setState(() {
          _sortBy = sortBy;
          _ascending = ascending;
        });
        Navigator.pop(sheetContext);
      },
    );
  }

  // ===== PART 6: Drawing the screen =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(                                   // NEW: layers on top of each other
        children: [
          _buildBody(),
          Positioned(                                // sort: bottom-left
            left: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              heroTag: 'sortButton',
              onPressed: _showSortOptions,
              child: const Icon(Icons.sort),
            ),
          ),
          Positioned(                                // refresh: bottom-right
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'refreshButton',
              onPressed: _isRefreshing ? null : _refresh,
              child: _isRefreshing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final jobs = _visibleJobs;

    String emptyMessage = 'No jobs yet.\nAdd a company, then tap refresh.';
    if (_showOnlyFavourites && _searchText.isEmpty) {
      emptyMessage = 'No favourites yet';
    } else if (_searchText.isNotEmpty) {
      emptyMessage = 'No jobs match your search';
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchText = value),
            decoration: InputDecoration(
              hintText: 'Search jobs...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchText.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchText = '');
                      },
                    ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ),

        // Count (left) + favourites toggle (right)
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${jobs.length} ${jobs.length == 1 ? 'job' : 'jobs'} • $_sortLabel',
                style: const TextStyle(color: Colors.grey),
              ),
              IconButton(
                tooltip: _showOnlyFavourites
                    ? 'Show all jobs'
                    : 'Show favourites only',
                icon: Icon(
                  _showOnlyFavourites ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                onPressed: () =>
                    setState(() => _showOnlyFavourites = !_showOnlyFavourites),
              ),
            ],
          ),
        ),

        // The list
        Expanded(
          child: jobs.isEmpty
              ? Center(
                  child: Text(
                    emptyMessage,
                    textAlign: TextAlign.center,
                  ),
                )
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _collapseAll,
                  child: ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                    itemCount: jobs.length,
                    itemBuilder: (context, index) {
                      final job = jobs[index];

                      return Dismissible(
                        key: ValueKey(job.id),

                        // Swipe RIGHT → remove
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: Colors.red,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),

                        // Swipe LEFT → favourite
                        secondaryBackground: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: Colors.amber,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Icon(
                            job.isFavourite ? Icons.star_border : Icons.star,
                            color: Colors.white,
                          ),
                        ),

                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.endToStart) {
                            _toggleFavourite(job);
                            return false;
                          }
                          return true;
                        },

                        onDismissed: (direction) => _removeJob(job),

                        child: JobCard(
                          job: job,
                          isExpanded: _expandedJobId == job.id,
                          alsoListedBy: _expandedJobId == job.id    // NEW
                              ? _otherListings(job)
                              : const <String>[],
                          onTap: () => _toggleExpand(job),
                          onLongPress: () => _showJobOptions(job),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}