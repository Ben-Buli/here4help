import 'package:flutter/material.dart';

class FAQPage extends StatelessWidget {
  const FAQPage({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {'q': 'How do I reset my password?', 'a': 'Go to Security Settings and select "Change Password".'},
      {'q': 'How do I contact support?', 'a': 'Use the "Contact Us" option in Customer Support.'},
      {'q': 'How do I check my points?', 'a': 'Go to My Wallet to view your points balance.'},
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: faqs.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final faq = faqs[index];
        return ExpansionTile(
          title: Text(faq['q']!),
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(faq['a']!),
            ),
          ],
        );
      },
    );
  }
}