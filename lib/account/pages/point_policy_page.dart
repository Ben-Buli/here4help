import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
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
                  child: _PolicyHtmlRenderer(content: document.content),
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

class _PolicyHtmlRenderer extends StatelessWidget {
  final Map<String, dynamic> content;

  const _PolicyHtmlRenderer({required this.content});

  @override
  Widget build(BuildContext context) {
    final htmlText = _TiptapHtmlConverter.convert(content);
    if (htmlText.isEmpty) {
      return Text(
        'Unable to display content.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final htmlWidget = Html(
      data: htmlText,
      extensions: const [TableHtmlExtension()],
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(16),
          color: Colors.grey.shade800,
        ),
        'p': Style(
          margin: Margins.only(bottom: 16),
          lineHeight: LineHeight.number(1.5),
        ),
        'h1': Style(
          margin: Margins.only(bottom: 16),
          fontSize: FontSize(24),
          fontWeight: FontWeight.w700,
        ),
        'h2': Style(
          margin: Margins.only(top: 8, bottom: 12),
          fontSize: FontSize(20),
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
        'h3': Style(
          margin: Margins.only(top: 8, bottom: 10),
          fontSize: FontSize(18),
          fontWeight: FontWeight.w600,
        ),
        'ul': Style(
          margin: Margins.only(left: 20, bottom: 16),
        ),
        'ol': Style(
          margin: Margins.only(left: 20, bottom: 16),
        ),
        'li': Style(
          margin: Margins.only(bottom: 8),
        ),
        'table': Style(
          margin: Margins.only(top: 12, bottom: 12),
          width: Width.auto(),
          backgroundColor: Colors.transparent,
          border: Border.all(color: Colors.grey.shade200),
        ),
        'th': Style(
          padding: HtmlPaddings.all(12),
          backgroundColor: Colors.grey.shade100,
          fontWeight: FontWeight.w600,
          border: Border.all(color: Colors.grey.shade300),
        ),
        'td': Style(
          padding: HtmlPaddings.all(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
      },
    );

    return htmlWidget;
  }
}

class _TiptapHtmlConverter {
  static const HtmlEscape _escape = HtmlEscape();

  static String convert(Map<String, dynamic>? document) {
    if (document == null) return '';
    final buffer = StringBuffer('<div class="policy-body">');
    final nodes = document['content'];
    if (nodes is List) {
      for (final node in nodes) {
        buffer.write(_renderNode(node));
      }
    }
    buffer.write('</div>');
    final result = buffer.toString();
    return result == '<div class="policy-body"></div>' ? '' : result;
  }

  static String _renderNode(dynamic node) {
    if (node is! Map<String, dynamic>) return '';
    final type = node['type'];
    switch (type) {
      case 'heading':
        final level = node['attrs']?['level'] ?? 2;
        return '<h$level>${_renderInlineContent(node['content'])}</h$level>';
      case 'paragraph':
        final body = _renderInlineContent(node['content']);
        if (body.trim().isEmpty) return '';
        return '<p>$body</p>';
      case 'bulletList':
        return '<ul>${_renderListItems(node['content'])}</ul>';
      case 'orderedList':
        return '<ol>${_renderListItems(node['content'])}</ol>';
      case 'listItem':
        return '<li>${_renderChildNodes(node['content'])}</li>';
      case 'table':
        final rows = node['content'];
        if (rows is! List) return '';
        final rowHtml = rows.map(_renderTableRow).join();
        return '<div class="policy-table"><table>$rowHtml</table></div>';
      case 'tableRow':
        return _renderTableRow(node);
      case 'tableHeader':
      case 'tableCell':
        return _renderTableCell(node);
      default:
        return _renderChildNodes(node['content']);
    }
  }

  static String _renderListItems(dynamic nodes) {
    if (nodes is! List) return '';
    return nodes.map((item) => _renderNode(item)).join();
  }

  static String _renderChildNodes(dynamic nodes) {
    if (nodes is! List) return '';
    final buffer = StringBuffer();
    for (final child in nodes) {
      buffer.write(_renderNode(child));
    }
    return buffer.toString();
  }

  static String _renderInlineContent(dynamic nodes) {
    if (nodes is! List) return '';
    final buffer = StringBuffer();
    for (final node in nodes) {
      if (node is! Map<String, dynamic>) continue;
      switch (node['type']) {
        case 'text':
          buffer.write(_renderTextNode(node));
          break;
        case 'hardBreak':
          buffer.write('<br/>');
          break;
        default:
          buffer.write(_renderNode(node));
      }
    }
    return buffer.toString();
  }

  static String _renderTableRow(dynamic row) {
    if (row is! Map<String, dynamic>) return '';
    final cells = row['content'];
    if (cells is! List) return '';
    final buffer = StringBuffer('<tr>');
    for (final cell in cells) {
      buffer.write(_renderTableCell(cell));
    }
    buffer.write('</tr>');
    return buffer.toString();
  }

  static String _renderTableCell(dynamic cell) {
    if (cell is! Map<String, dynamic>) return '';
    final type = cell['type'] == 'tableHeader' ? 'th' : 'td';
    final colspan = cell['attrs']?['colspan'];
    final rowspan = cell['attrs']?['rowspan'];
    final attributes = StringBuffer();
    if (colspan is int && colspan > 1) {
      attributes.write(' colspan="$colspan"');
    }
    if (rowspan is int && rowspan > 1) {
      attributes.write(' rowspan="$rowspan"');
    }
    final content = _renderInlineContent(cell['content']);
    return '<$type${attributes.toString()}>$content</$type>';
  }

  static String _renderTextNode(Map<String, dynamic> node) {
    final text = _escape.convert(node['text'] ?? '');
    final marks = node['marks'];
    if (marks is! List || marks.isEmpty) {
      return text;
    }

    var result = text;
    for (final mark in marks) {
      if (mark is! Map<String, dynamic>) continue;
      switch (mark['type']) {
        case 'bold':
          result = '<strong>$result</strong>';
          break;
        case 'italic':
          result = '<em>$result</em>';
          break;
        case 'underline':
          result = '<u>$result</u>';
          break;
        case 'textStyle':
          final color = mark['attrs']?['color'];
          if (color is String && color.isNotEmpty) {
            result = '<span style="color:$color">$result</span>';
          }
          break;
        default:
      }
    }
    return result;
  }
}
