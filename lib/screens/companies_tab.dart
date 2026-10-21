import 'package:flutter/material.dart';
import '../models/company.dart';
import '../services/storage_service.dart';
import 'dart:async';
import '../services/job_fetcher.dart';
import '../widgets/app_snack.dart';
import '../widgets/layout.dart';

class CompaniesTab extends StatefulWidget {
  const CompaniesTab({super.key});

  @override
  State<CompaniesTab> createState() => _CompaniesTabState();
}

class _CompaniesTabState extends State<CompaniesTab> {
  // ===== PART 1: State (the data this screen remembers) =====
  List<Company> _companies = [];
  bool _isLoading = true;

  final _nameController = TextEditingController();
  final _linkController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ===== PART 2: Start-up and clean-up =====
  @override
  void initState() {
    super.initState();
    _loadCompanies(); // runs once, when the tab first appears
  }

  @override
  void dispose() {
    _nameController.dispose(); // free memory when the screen closes
    _linkController.dispose();
    super.dispose();
  }

  // ===== PART 3: Load, save, add, mute, delete =====
  Future<void> _loadCompanies() async {
    final loaded = await StorageService.loadCompanies();
    if (!mounted) return; // screen closed while loading? stop here
    setState(() {
      _companies = loaded;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    await StorageService.saveCompanies(_companies);
  }

  // Adds https:// if the user forgot it, and trims spaces
  String _normalizeLink(String input) {
    var link = input.trim();
    if (link.startsWith('http://')) {
      link = 'https://${link.substring(7)}'; // Android blocks plain http
    } else if (!link.startsWith('https://')) {
      link = 'https://$link';
    }
    return link;
  }

  // Is this a real-looking web address?
  bool _isValidLink(String link) {
    final uri = Uri.tryParse(link);            // null if it can't be read
    return uri != null && uri.hasScheme && uri.host.contains('.');
  }

  void _addCompany(String name, String link) {
    final company = Company(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // unique ID
      name: name,
      link: link,
    );
    setState(() => _companies.add(company));
    _save();
  }

    Future<void> _updateCompany(
      Company company, String newName, String newLink) async {
    final nameChanged = company.name != newName;
    final linkChanged = company.link != newLink;

    setState(() {
      company.name = newName;
      company.link = newLink;
    });
    await _save();

    // Saved jobs carry a copy of the company name, so update those too
    if (nameChanged) {
      final jobs = await StorageService.loadJobs();
      for (final job in jobs) {
        if (job.companyId == company.id) job.companyName = newName;
      }
      await StorageService.saveJobs(jobs);
    }

    if (!mounted) return;
    showAppSnack(
      context,
      linkChanged
          ? 'Saved. Tap refresh on the Jobs tab to load jobs from the new link'
          : 'Company updated',
    );
  }

  void _toggleMute(Company company) {
    setState(() => company.isMuted = !company.isMuted); // flip true/false
    _save();
    showAppSnack(
      context,
      company.isMuted ? '${company.name} muted' : '${company.name} unmuted',
    );
  }

  void _deleteCompany(Company company) {
    setState(() => _companies.remove(company));
    _save();
  }

  // ===== PART 4: The "Add company" dialog =====
  // existing == null → ADD mode, otherwise → EDIT mode
  void _showCompanyDialog({Company? existing}) {
    final isEditing = existing != null;

    _nameController.text = existing?.name ?? '';
    _linkController.text = existing?.link ?? '';

    var isChecking = false; // true while we test the link
    String? warning;        // problem found by the test (null = none)

    showDialog(
      context: context,
      builder: (dialogContext) {
        // StatefulBuilder lets the dialog redraw itself with setDialogState
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit({required bool skipCheck}) async {
              if (!_formKey.currentState!.validate()) return;

              final name = _nameController.text.trim();
              final link = _normalizeLink(_linkController.text);
              final linkChanged = existing == null || existing.link != link;

              // Test the link (skipped for "Add anyway" or unchanged links)
              if (!skipCheck && linkChanged) {
                setDialogState(() {
                  isChecking = true;
                  warning = null;
                });

                try {
                  final test = Company(id: 'test', name: name, link: link);
                  final jobs = await JobFetcher.fetch(test, quick: true);
                  if (jobs.isEmpty) {
                    throw Exception('The page loaded, but no jobs were found');
                  }
                } catch (e) {
                  if (!dialogContext.mounted) return;
                  setDialogState(() {
                    isChecking = false;
                    warning = e is TimeoutException
                        ? 'The website took too long to answer'
                        : e.toString().replaceFirst('Exception: ', '');
                  });
                  return; // stay in the dialog
                }
              }

              if (!dialogContext.mounted) return;
              if (existing == null) {
                _addCompany(name, link);
              } else {
                _updateCompany(existing, name, link);
              }
              Navigator.pop(dialogContext);
            }

            return AlertDialog(
              scrollable: true,
              title: Text(isEditing ? 'Edit company' : 'Add company'),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _linkController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Link',
                        hintText: 'https://company.com/careers',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a link';
                        }
                        final link = _normalizeLink(value);
                        if (!_isValidLink(link)) {
                          return 'Please enter a valid web link';
                        }
                        if (_companies.any(
                            (c) => c.id != existing?.id && c.link == link)) {
                          return 'This company is already added';
                        }
                        return null;
                      },
                    ),
                    if (isChecking)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Checking link…'),
                          ],
                        ),
                      ),
                    if (warning != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          '$warning\n\nYou can still add it, but it may show no jobs.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isChecking ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                if (warning != null)
                  TextButton(
                    onPressed:
                        isChecking ? null : () => submit(skipCheck: true),
                    child: Text(isEditing ? 'Save anyway' : 'Add anyway'),
                  ),
                FilledButton(
                  onPressed:
                      isChecking ? null : () => submit(skipCheck: false),
                  child: Text(isEditing ? 'Save changes' : 'Add to list'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===== PART 5: "Are you sure?" dialog for delete =====
  Future<bool> _confirmDelete(Company company) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove company?'),
        content: Text('Remove ${company.name} from your list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return result ?? false; // tapped outside the dialog = No
  }

  // ===== PART 6: Drawing the screen =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCompanyDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_companies.isEmpty) {
      return const Center(
        child: Text(
          'No companies yet.\nTap "Add" to get started.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '${_companies.length} companies',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              sidePadding(context, 700, min: 0),
              0,
              sidePadding(context, 700, min: 0),
              90,
            ),
            itemCount: _companies.length,
            itemBuilder: (context, index) {
              final company = _companies[index];

              return Dismissible(
                key: ValueKey(company.id),

                // Shown when swiping RIGHT → delete
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),

                // Shown when swiping LEFT → mute/unmute
                secondaryBackground: Container(
                  color: Colors.orange,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(
                    company.isMuted ? Icons.volume_up : Icons.volume_off,
                    color: Colors.white,
                  ),
                ),

                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    _toggleMute(company);
                    return false;
                  }
                  return await _confirmDelete(company);
                },

                onDismissed: (direction) => _deleteCompany(company),

                child: ListTile(
                  onTap: () => _showCompanyDialog(existing: company),
                  leading: CircleAvatar(
                    child: Text(company.name[0].toUpperCase()),
                  ),
                  title: Text(
                    company.name,
                    style: TextStyle(color: company.isMuted ? Colors.grey : null),
                  ),
                  subtitle: Text(
                    company.link,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (company.isMuted)
                        const Icon(Icons.volume_off, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                    ],
                  ),
                ),
              ); // closes return Dismissible
            }, // closes itemBuilder
          ), // closes ListView.builder
        ), // closes Expanded
      ], // closes Column children
    ); // closes Column / return
  }
}                                            // closes the class