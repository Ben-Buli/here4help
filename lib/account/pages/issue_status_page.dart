import 'package:flutter/material.dart';

class IssueStatusPage extends StatelessWidget {
  final bool hasIssue;
  final int status; // 0: Submitted, 1: In Progress, 2: Resolved
  final String submittedDate;

  const IssueStatusPage({
    super.key,
    this.hasIssue = true,
    this.status = 1,
    this.submittedDate = 'April 8, 2024',
  });

  @override
  Widget build(BuildContext context) {
    return hasIssue
        ? Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStep('Submitted', 0, status, date: submittedDate),
                  _buildStep('In Progress', 1, status),
                  _buildStep('Resolved', 2, status),
                ],
              ),
            ),
          )
        : const Center(
            child: Text(
              'No issues pending at the moment.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          );
  }

  Widget _buildStep(String label, int step, int current, {String? date}) {
    final isActive = current >= step;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: isActive ? Colors.blue : Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.blue : Colors.grey,
          ),
        ),
        if (date != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              date,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
