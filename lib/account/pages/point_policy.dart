import 'package:flutter/material.dart';
import 'package:here4help/constants/app_colors.dart';

class PointPolicyPage extends StatelessWidget {
  const PointPolicyPage({Key? key}) : super(key: key);

  TableRow _buildTableRow(String left, String right, {bool isHeader = false}) {
    final style = TextStyle(
      fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
      fontSize: 15,
    );
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(left, style: style),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(right, style: style),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Conversion Rate
          const Text(
            'Conversion Rate',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            '1 Point = NT\$1',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),

          // Purchasing Points & Reward Rules
          const Text(
            'Purchasing Points & Reward Rules',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(2.2),
            },
            children: [
              _buildTableRow(
                'Purchase Amount (NT\$)',
                'Bonus Offer',
                isHeader: true,
              ),
              _buildTableRow(
                'Below 600',
                'No coupon issued',
              ),
              _buildTableRow(
                '600–999',
                '30-point discount coupon applicable to task payments (e.g., for a 600-point task, only 570 points are required after applying the coupon).',
              ),
              _buildTableRow(
                '1,000–1499',
                'Get an additional 100 points credited to your balance (e.g., pay 1,500, receive 1,600 points).',
              ),
              _buildTableRow(
                '2,000 and above',
                'Get an additional 150 points credited (e.g., pay 2000, recive 2,150 points).',
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Points Withdrawal Policy
          const Text(
            'Points Withdrawal Policy',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _policyBullet(
                'Points earned from completed tasks will be disbursed to the task taker on the ',
                '10th of the following month',
                '.',
              ),
              _policyBullet(
                'Any task under dispute is excluded from scheduled disbursement.',
                null,
                null,
              ),
              _policyBullet(
                'Once a dispute is resolved, the corresponding points will be disbursed ',
                'within 7 days',
                ' of resolution.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _policyBullet(String text, String? highlight, String? suffix) {
    const normalStyle = TextStyle(fontSize: 15, height: 1.6);
    final highlightStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.bold,
      color: AppColors.primary,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 18)),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: normalStyle,
                children: [
                  TextSpan(text: text),
                  if (highlight != null)
                    TextSpan(text: highlight, style: highlightStyle),
                  if (suffix != null) TextSpan(text: suffix),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
