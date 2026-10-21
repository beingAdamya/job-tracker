import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';
import '../widgets/app_snack.dart';
import '../widgets/layout.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ===== PART 1: State and loading =====
  Profile _profile = Profile.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await ProfileService.load();
    if (!mounted) return;
    setState(() {
      _profile = loaded;
      _isLoading = false;
    });
  }

  Future<void> _save() => ProfileService.save(_profile);

  void _msg(String text) {
    if (!mounted) return;
    showAppSnack(context, text);
  }

  // ===== PART 2: Fields =====
  Future<void> _copy(ProfileField f) async {
    await Clipboard.setData(ClipboardData(text: f.value));
    _msg('${f.label} copied');
  }

  TextInputType _keyboardFor(String kind) {
    switch (kind) {
      case 'email':
        return TextInputType.emailAddress;
      case 'phone':
        return TextInputType.phone;
      case 'url':
        return TextInputType.url;
      case 'multiline':
        return TextInputType.multiline;
      default:
        return TextInputType.text;
    }
  }

  // Edit one field. `isNew` = a field the user is just adding.
  Future<void> _editField(ProfileField f, {bool isNew = false}) async {
    final valueController = TextEditingController(text: f.value);
    final labelController = TextEditingController(text: f.label);
    final long = f.kind == 'multiline';

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(f.isCustom ? (isNew ? 'New field' : 'Edit field') : f.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (f.isCustom) ...[
              TextField(
                controller: labelController,
                autofocus: isNew,
                decoration: const InputDecoration(labelText: 'Field name'),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: valueController,
              autofocus: !isNew,
              keyboardType: _keyboardFor(f.kind),
              minLines: long ? 3 : 1,
              maxLines: long ? 8 : 1,
              decoration: const InputDecoration(labelText: 'Value'),
            ),
          ],
        ),
        actions: [
          if (f.isCustom && !isNew)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'delete'),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (action == 'delete') {
      setState(() => _profile.fields.remove(f));
      await _save();
      return;
    }
    if (action != 'save') return;

    final newLabel = labelController.text.trim();
    if (f.isCustom && newLabel.isEmpty) {
      _msg('Please give the field a name');
      return;
    }

    setState(() {
      f.value = valueController.text.trim();
      if (f.isCustom) f.label = newLabel;
      if (isNew) _profile.fields.add(f);
    });
    await _save();
  }

  Future<void> _addField() {
    final f = ProfileField(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      label: '',
      isCustom: true,
    );
    return _editField(f, isNew: true);
  }

  // ===== PART 3: CV =====
  Future<void> _pickCv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result == null || result.files.isEmpty) return; // cancelled

    final file = result.files.single;
    final path = file.path;
    if (path == null) {
      _msg('Could not read that file');
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      _msg('Please choose a file under 10 MB');
      return;
    }

    final stored = await ProfileService.storeCv(path, file.name);
    setState(() {
      _profile.cvPath = stored;
      _profile.cvName = file.name;
      _profile.cvAdded = DateTime.now();
    });
    await _save();
    _msg('CV saved');
  }

  Future<void> _openCv() async {
    final path = _profile.cvPath;
    if (path == null || !File(path).existsSync()) {
      _msg('CV file not found. Please upload it again.');
      return;
    }
    final result = await OpenFilex.open(path);
    if (result.type == ResultType.noAppToOpen) {
      _msg('No app found to open this file');
    } else if (result.type != ResultType.done) {
      _msg('Could not open the file');
    }
  }

  Future<void> _deleteCv() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete CV?'),
        content: const Text('The copy stored in this app will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ProfileService.deleteCvFiles();
    setState(() {
      _profile.cvPath = null;
      _profile.cvName = null;
      _profile.cvAdded = null;
    });
    await _save();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime? d) =>
      d == null ? '' : '${d.day}/${d.month}/${d.year}';

  // ===== PART 4: Drawing the screen =====
  Widget _cvCard() {
    final path = _profile.cvPath;
    final hasCv = path != null && File(path).existsSync();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.description_outlined),
                SizedBox(width: 8),
                Text('CV / Resume',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            if (hasCv) ...[
              Text(_profile.cvName ?? 'CV'),
              Text(
                '${_formatSize(File(path).lengthSync())} • added ${_formatDate(_profile.cvAdded)}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _openCv,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickCv,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Replace'),
                  ),
                  TextButton.icon(
                    onPressed: _deleteCv,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'No CV yet. It is stored only on this phone.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _pickCv,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload CV (PDF or Word)'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fieldTile(ProfileField f) {
    final empty = f.value.isEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _editField(f),
        title: Text(
          f.label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        subtitle: Text(
          empty ? 'Tap to add' : f.value,
          maxLines: f.kind == 'multiline' ? 4 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 15, color: empty ? Colors.grey : null),
        ),
        trailing: IconButton(
          tooltip: 'Copy',
          icon: const Icon(Icons.copy),
          onPressed: empty ? null : () => _copy(f),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final side = sidePadding(context, 700);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile and CV')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addField,
        icon: const Icon(Icons.add),
        label: const Text('Add field'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(side, 12, side, 100 + bottomInset),
              children: [
                _cvCard(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text(
                    'Tap a row to edit it. Tap the copy icon to copy it, then paste it into an application form.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
                for (final f in _profile.fields) _fieldTile(f),
              ],
            ),
    );
  }
}