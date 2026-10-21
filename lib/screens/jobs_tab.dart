import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../widgets/job_card.dart';
import '../services/job_keys.dart';
import '../widgets/app_snack.dart';
import '../services/settings_service.dart';
import '../widgets/layout.dart';

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
  int _maxAgeDays = 0;

  // ===== PART 2: Loading =====

  Future<void> _loadData() async {
    final savedJobs = await StorageService.loadJobs();
    final companies = await StorageService.loadCompanies();
    final settings = await SettingsService.load();

    // Only keep jobs whose company still exists
    final companyIds = companies.map((c) => c.id).toSet();
    final jobs =
        savedJobs.where((j) => companyIds.contains(j.companyId)).toList();

    if (!mounted) return;
    setState(() {
      _jobs = jobs;
      _maxAgeDays = settings.maxAgeDays;
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
    final cutoff = _maxAgeDays > 0
        ? DateTime.now().subtract(Duration(days: _maxAgeDays))
        : null;

    var list = _jobs.where((j) {
      final muted = _mutedCompanyIds.contains(j.companyId) ||
          _mutedCompanyNames.contains(j.companyName.toLowerCase());
      // Favourites always stay, however old
      final tooOld =
          cutoff != null && j.postedDate.isBefore(cutoff) && !j.isFavourite;
      return !j.isRemoved && !muted && !tooOld;
    }).toList();

    final ordered = [...list]
      ..sort((a, b) => (_companyOrder[a.companyId] ?? 0)
          .compareTo(_companyOrder[b.companyId] ?? 0));

    final owners = <String, String>{}; // job key → company that "owns" it
    final unique = <Job>[];
    for (final j in ordered) {
      final key = duplicateKey(j);
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

  // This job + the same job listed by OTHER companies
  List<Job> _copiesOf(Job job) {
    final key = duplicateKey(job);
    return _jobs
        .where((j) =>
            j.id == job.id ||
            (j.companyId != job.companyId && duplicateKey(j) == key))
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
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    final result = await SyncService.syncAll(); // the real fetch
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

    showAppSnack(
      context,
      '${job.title} removed',
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
    );
  }

  Future<void> _openInBrowser(Job job) async {
    final uri = Uri.parse(job.url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showMessage('Could not open the link');
    }
  }

  void _showMessage(String text) => showAppSnack(context, text);

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
    // Android 15+ draws apps behind the navigation bar: stay above it
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildBody(bottomInset)),
          Positioned(
            left: 16,
            bottom: 24 + bottomInset,
            child: FloatingActionButton.small(
              heroTag: 'sortButton',
              onPressed: _showSortOptions,
              child: const Icon(Icons.sort),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 24 + bottomInset,
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

  Widget _buildBody(double bottomInset) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final jobs = _visibleJobs;

    String emptyMessage = 'No jobs yet.\nAdd a company, then pull down to refresh.';
    if (_showOnlyFavourites && _searchText.isEmpty) {
      emptyMessage = 'No favourites yet';
    } else if (_searchText.isNotEmpty) {
      emptyMessage = 'No jobs match your search';
    }

    final side = sidePadding(context, 800, min: 12);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _collapseAll, // tap outside a card → collapse
      child: RefreshIndicator(
        onRefresh: _refresh, // pull down → refresh
        child: CustomScrollView(
          // Lets you pull down even when the list is short or empty
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 12, side, 0),
              sliver: SliverToBoxAdapter(child: _searchBar()),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side + 4, 0, side, 0),
              sliver: SliverToBoxAdapter(child: _countRow(jobs.length)),
            ),
            if (jobs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(emptyMessage, textAlign: TextAlign.center),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 4, side, 90 + bottomInset),
                sliver: SliverList.builder(
                  itemCount: jobs.length,
                  itemBuilder: (context, index) => _jobItem(jobs[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  // Count and sort name (left) + favourites toggle (right)
  Widget _countRow(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$count ${count == 1 ? 'job' : 'jobs'} • $_sortLabel',
          style: const TextStyle(color: Colors.grey),
        ),
        IconButton(
          tooltip:
              _showOnlyFavourites ? 'Show all jobs' : 'Show favourites only',
          icon: Icon(
            _showOnlyFavourites ? Icons.star : Icons.star_border,
            color: Colors.amber,
          ),
          onPressed: () =>
              setState(() => _showOnlyFavourites = !_showOnlyFavourites),
        ),
      ],
    );
  }

  // One swipeable job card
  Widget _jobItem(Job job) {
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
        alsoListedBy:
            _expandedJobId == job.id ? _otherListings(job) : const <String>[],
        onTap: () => _toggleExpand(job),
        onLongPress: () => _showJobOptions(job),
      ),
    );
  }
}