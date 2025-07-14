import 'package:flutter/material.dart';

class FAQPage extends StatelessWidget {
  const FAQPage({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'q': 'How do I reset my password?',
        'a': 'Go to Security Settings and select "Change Password".'
      },
      {
        'q': 'How do I contact support?',
        'a': 'Use the "Contact Us" option in Customer Support.'
      },
      {
        'q': 'How do I check my points?',
        'a': 'Go to My Wallet to view your points balance.'
      },
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: faqs.map((faq) {
        return Column(
          children: [
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 10),
              title: Text(
                faq['q']!,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    child: Text(faq['a']!),
                  ),
                ),
              ],
            ),
            const Divider(height: 1),
          ],
        );
      }).toList(),
    );
  }
}
