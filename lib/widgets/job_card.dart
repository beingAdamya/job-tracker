import 'package:flutter/material.dart';
import '../models/job.dart';

class JobCard extends StatelessWidget {
  final Job job;
  final bool isExpanded;          // decided by the parent (the list)
  final VoidCallback onTap;       // what to do when tapped
  final VoidCallback onLongPress; // what to do when long-pressed
  final List<String> alsoListedBy; 

  const JobCard({
    super.key,
    required this.job,
    required this.isExpanded,
    required this.onTap,
    required this.onLongPress,
    this.alsoListedBy = const [],  
  });

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  // Pick a colour for each mode
  Color _modeColor(String mode) {
    switch (mode) {
      case 'Remote':
        return Colors.green.shade100;
      case 'Hybrid':
        return Colors.blue.shade100;
      case 'On-site':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade200; // anything unexpected
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isExpanded ? 4 : 1, // expanded card "lifts up"
      clipBehavior: Clip.antiAlias,  // keeps the tap ripple inside the rounded corners
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250), // smooth grow/shrink
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // left-align everything
              children: [
                // Row 1: title + star + expand icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        job.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (job.isFavourite)
                      const Icon(Icons.star, color: Colors.amber),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Row 2: role • company
                Text(
                  '${job.role} • ${job.companyName}',
                  style: const TextStyle(color: Colors.grey),
                ),
                if (job.noLongerListed)                         // NEW
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'No longer listed',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),

                // Row 3: location + mode
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        job.location,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Chip(
                      label: Text(job.mode),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: _modeColor(job.mode),
                    ),
                  ],
                ),

                // Extra details: only when expanded
                if (isExpanded) ...[
                  const Divider(height: 24),
                  Text(
                    'Posted: ${_formatDate(job.postedDate)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (alsoListedBy.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Also listed by ${alsoListedBy.join(', ')}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(job.description),
                  const SizedBox(height: 8),
                  Text(job.description),
                  const SizedBox(height: 12),
                  const Text(
                    'Long-press for more options',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}