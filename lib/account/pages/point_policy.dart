import 'package:flutter/material.dart';
import 'package:here4help/constants/app_colors.dart';
import 'package:here4help/services/point_policy_service.dart';

class PointPolicyPage extends StatefulWidget {
  const PointPolicyPage({super.key});

  @override
  State<PointPolicyPage> createState() => _PointPolicyPageState();
}

class _PointPolicyPageState extends State<PointPolicyPage> {
  late Future<PointPolicyDocument> _future;

  @override
  void initState() {
    super.initState();
    _future = PointPolicyService.fetchActiveDocument();
  }

  Future<void> _reload() async {
    final doc = await PointPolicyService.fetchActiveDocument();
    if (!mounted) return;
    setState(() {
      _future = Future.value(doc);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<PointPolicyDocument>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 240),
                Center(child: CircularProgressIndicator()),
                SizedBox(height: 320),
              ],
            );
          }

          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 80),
                Icon(Icons.error_outline,
                    size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Unable to load the point policy.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error?.toString() ?? 'Unknown error',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
                const SizedBox(height: 320),
              ],
            );
          }

          final document = snapshot.data;
          if (document == null) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 80),
                Text('No point policy available at the moment.'),
                SizedBox(height: 320),
              ],
            );
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              Text(
                document.title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Last updated: ${_formatDate(document.updatedAt)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: _TiptapDocumentRenderer(document: document.content),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _TiptapDocumentRenderer extends StatelessWidget {
  final Map<String, dynamic> document;

  const _TiptapDocumentRenderer({required this.document});

  @override
  Widget build(BuildContext context) {
    final content = document['content'];
    if (content is! List) {
      return Text(
        'Unable to display content.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final children = <Widget>[];
    for (final node in content) {
      final widget = _renderNode(context, node);
      if (widget != null) {
        children.add(widget);
        children.add(const SizedBox(height: 16));
      }
    }

    if (children.isNotEmpty) {
      children.removeLast();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget? _renderNode(BuildContext context, dynamic node) {
    if (node is! Map<String, dynamic>) return null;
    final type = node['type'];
    switch (type) {
      case 'heading':
        return _buildHeading(context, node);
      case 'paragraph':
        return _buildParagraph(context, node);
      case 'bulletList':
        return _buildBulletList(context, node);
      case 'orderedList':
        return _buildOrderedList(context, node);
      case 'table':
        return _buildTable(context, node);
      default:
        return null;
    }
  }

  Widget _buildHeading(BuildContext context, Map<String, dynamic> node) {
    final level = node['attrs']?['level'] ?? 2;
    final style = switch (level) {
      1 => Theme.of(context)
          .textTheme
          .headlineSmall
          ?.copyWith(fontWeight: FontWeight.w700),
      2 => Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
      3 => Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w600),
      _ => Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    };
    return Text.rich(
      TextSpan(children: _buildTextSpans(node['content'], style)),
    );
  }

  Widget _buildParagraph(BuildContext context, Map<String, dynamic> node,
      {EdgeInsets padding = EdgeInsets.zero}) {
    return Padding(
      padding: padding,
      child: Text.rich(
        TextSpan(
          children: _buildTextSpans(
            node['content'],
            Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        textAlign: TextAlign.start,
      ),
    );
  }

  Widget _buildBulletList(BuildContext context, Map<String, dynamic> node) {
    final items = node['content'];
    if (items is! List) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map<Widget>((item) {
        if (item is! Map<String, dynamic>) return const SizedBox.shrink();
        final paragraph = item['content']?[0];
        if (paragraph is! Map<String, dynamic>) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ',
                  style: TextStyle(fontSize: 16, height: 1.4)),
              Expanded(child: _buildParagraph(context, paragraph)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOrderedList(BuildContext context, Map<String, dynamic> node) {
    final items = node['content'];
    if (items is! List) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(items.length, (index) {
        final paragraph = items[index]['content']?[0];
        if (paragraph is! Map<String, dynamic>) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${index + 1}. ',
                  style: const TextStyle(fontSize: 16, height: 1.4)),
              Expanded(child: _buildParagraph(context, paragraph)),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTable(BuildContext context, Map<String, dynamic> node) {
    final rows = node['content'];
    if (rows is! List) return const SizedBox.shrink();

    final rowWidgets = <TableRow>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final cells = row['content'];
      if (cells is! List) continue;

      final tableCells = cells.map<Widget>((cell) {
        final isHeader = cell['type'] == 'tableHeader';
        final paragraph = cell['content']?[0];
        final cellWidget = paragraph is Map<String, dynamic>
            ? _buildParagraph(
                context,
                paragraph,
                padding: EdgeInsets.zero,
              )
            : const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isHeader ? Colors.grey.shade100 : Colors.white,
          ),
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
                ),
            child: cellWidget,
          ),
        );
      }).toList();

      rowWidgets.add(TableRow(children: tableCells));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          border: TableBorder.symmetric(
            inside: BorderSide(color: Colors.grey.shade200),
            outside: BorderSide(color: Colors.grey.shade200),
          ),
          children: rowWidgets,
        ),
      ),
    );
  }

  List<InlineSpan> _buildTextSpans(
      dynamic content, TextStyle? baseStyle) {
    if (content is! List) {
      return [
        TextSpan(
          text: '',
          style: baseStyle,
        )
      ];
    }

    final spans = <InlineSpan>[];
    for (final node in content) {
      if (node is! Map<String, dynamic>) continue;
      if (node['type'] == 'text') {
        spans.add(TextSpan(
          text: node['text'] ?? '',
          style: _applyMarks(baseStyle, node['marks']),
        ));
      } else if (node['type'] == 'hardBreak') {
        spans.add(const TextSpan(text: '\n'));
      } else if (node['content'] != null) {
        spans.addAll(_buildTextSpans(node['content'], baseStyle));
      }
    }
    return spans;
  }

  TextStyle? _applyMarks(TextStyle? style, dynamic marks) {
    if (marks is! List) return style;
    var result = style ?? const TextStyle();
    for (final mark in marks) {
      final type = mark['type'];
      switch (type) {
        case 'bold':
          result = result.copyWith(fontWeight: FontWeight.w600);
          break;
        case 'italic':
          result = result.copyWith(fontStyle: FontStyle.italic);
          break;
        case 'underline':
          result = result.copyWith(decoration: TextDecoration.underline);
          break;
        case 'textStyle':
          final color = mark['attrs']?['color'];
          if (color is String) {
            result = result.copyWith(color: _parseColor(color));
          }
          break;
        default:
      }
    }
    return result;
  }

  Color? _parseColor(String hex) {
    if (hex.startsWith('#')) {
      final value = int.tryParse(hex.substring(1), radix: 16);
      if (value != null) {
        if (hex.length == 7) {
          return Color(0xFF000000 | value);
        } else if (hex.length == 9) {
          return Color(value);
        }
      }
    }
    return null;
  }
}
