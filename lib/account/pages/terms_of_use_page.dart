import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:here4help/services/terms_service.dart';

class TermsOfUsePage extends StatefulWidget {
  const TermsOfUsePage({super.key});

  @override
  State<TermsOfUsePage> createState() => _TermsOfUsePageState();
}

class _TermsOfUsePageState extends State<TermsOfUsePage> {
  static const String _errorMessage =
      'This feature is temporarily unavailable. Please contact support.';

  late Future<TermsContent?> _termsFuture;

  @override
  void initState() {
    super.initState();
    _termsFuture = TermsService.fetchActiveTerms();
  }

  Future<void> _reload() async {
    setState(() {
      _termsFuture = TermsService.fetchActiveTerms();
    });
    await _termsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TermsContent?>(
      future: _termsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _buildErrorState();
        }

        final terms = snapshot.data!;
        final updatedAt = terms.updatedAt;
        final updatedLabel = updatedAt != null
            ? 'Updated ${updatedAt.toLocal().toString().split('.').first}'
            : null;
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                terms.title.isNotEmpty ? terms.title : 'Terms of Use',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Version ${terms.version}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              if (updatedLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  updatedLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              Html(data: terms.content),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _reload,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
