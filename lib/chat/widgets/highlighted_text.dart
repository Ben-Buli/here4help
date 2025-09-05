import 'package:flutter/material.dart';

/// 高亮文字 Widget - 支援搜尋關鍵字高亮顯示
///
/// 功能特點：
/// - 支援多個關鍵字同時高亮
/// - 大小寫不敏感匹配
/// - 自動清除效果（當搜尋為空時）
/// - 可自定義高亮樣式
/// - 支援中文和英文混合搜尋
class HighlightedText extends StatelessWidget {
  /// 要顯示的完整文字
  final String text;

  /// 要高亮的搜尋關鍵字
  final String highlight;

  /// 正常文字的樣式
  final TextStyle? normalStyle;

  /// 高亮文字的樣式
  final TextStyle? highlightStyle;

  /// 文字對齊方式
  final TextAlign? textAlign;

  /// 最大行數
  final int? maxLines;

  /// 文字溢出處理
  final TextOverflow? overflow;

  /// 是否啟用軟換行
  final bool? softWrap;

  const HighlightedText({
    Key? key,
    required this.text,
    required this.highlight,
    this.normalStyle,
    this.highlightStyle,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 如果沒有高亮關鍵字，直接顯示原文
    if (highlight.isEmpty) {
      return Text(
        text,
        style: normalStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      );
    }

    // 獲取主題配色
    final theme = Theme.of(context);
    final defaultNormalStyle = normalStyle ?? theme.textTheme.bodyMedium;
    final defaultHighlightStyle = highlightStyle ??
        TextStyle(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.3),
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        );

    // 建構高亮文字片段
    final textSpans = _buildHighlightedSpans(
      text,
      highlight,
      defaultNormalStyle!,
      defaultHighlightStyle,
    );

    return RichText(
      text: TextSpan(children: textSpans),
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      softWrap: softWrap ?? true,
    );
  }

  /// 建構高亮文字片段
  List<TextSpan> _buildHighlightedSpans(
    String text,
    String highlight,
    TextStyle normalStyle,
    TextStyle highlightStyle,
  ) {
    final List<TextSpan> spans = [];

    // 正規化搜尋關鍵字（移除多餘空格，轉小寫）
    final normalizedHighlight = highlight.trim().toLowerCase();
    if (normalizedHighlight.isEmpty) {
      spans.add(TextSpan(text: text, style: normalStyle));
      return spans;
    }

    // 正規化原文（保持原始大小寫用於顯示）
    final normalizedText = text.toLowerCase();

    int currentIndex = 0;

    // 尋找所有匹配位置
    while (currentIndex < text.length) {
      final matchIndex =
          normalizedText.indexOf(normalizedHighlight, currentIndex);

      if (matchIndex == -1) {
        // 沒有更多匹配，添加剩餘文字
        if (currentIndex < text.length) {
          spans.add(TextSpan(
            text: text.substring(currentIndex),
            style: normalStyle,
          ));
        }
        break;
      }

      // 添加匹配前的正常文字
      if (matchIndex > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, matchIndex),
          style: normalStyle,
        ));
      }

      // 添加高亮的匹配文字（保持原始大小寫）
      spans.add(TextSpan(
        text:
            text.substring(matchIndex, matchIndex + normalizedHighlight.length),
        style: highlightStyle,
      ));

      currentIndex = matchIndex + normalizedHighlight.length;
    }

    return spans;
  }
}

/// 智能高亮文字 Widget - 支援多關鍵字和模糊匹配
///
/// 進階功能：
/// - 支援空格分隔的多關鍵字
/// - 每個關鍵字獨立高亮
/// - 支援部分匹配
class SmartHighlightedText extends StatelessWidget {
  /// 要顯示的完整文字
  final String text;

  /// 要高亮的搜尋關鍵字（支援多關鍵字，空格分隔）
  final String highlight;

  /// 正常文字的樣式
  final TextStyle? normalStyle;

  /// 高亮文字的樣式
  final TextStyle? highlightStyle;

  /// 文字對齊方式
  final TextAlign? textAlign;

  /// 最大行數
  final int? maxLines;

  /// 文字溢出處理
  final TextOverflow? overflow;

  /// 是否啟用軟換行
  final bool? softWrap;

  /// 最小匹配長度（避免過短關鍵字造成過度高亮）
  final int minMatchLength;

  const SmartHighlightedText({
    Key? key,
    required this.text,
    required this.highlight,
    this.normalStyle,
    this.highlightStyle,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.minMatchLength = 2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 如果沒有高亮關鍵字，直接顯示原文
    if (highlight.isEmpty) {
      return Text(
        text,
        style: normalStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      );
    }

    // 獲取主題配色
    final theme = Theme.of(context);
    final defaultNormalStyle = normalStyle ?? theme.textTheme.bodyMedium;
    final defaultHighlightStyle = highlightStyle ??
        TextStyle(
          backgroundColor: theme.colorScheme.secondary.withOpacity(0.4),
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        );

    // 建構智能高亮文字片段
    final textSpans = _buildSmartHighlightedSpans(
      text,
      highlight,
      defaultNormalStyle!,
      defaultHighlightStyle,
    );

    return RichText(
      text: TextSpan(children: textSpans),
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      softWrap: softWrap ?? true,
    );
  }

  /// 建構智能高亮文字片段（支援多關鍵字）
  List<TextSpan> _buildSmartHighlightedSpans(
    String text,
    String highlight,
    TextStyle normalStyle,
    TextStyle highlightStyle,
  ) {
    // 分割多個關鍵字
    final keywords = highlight
        .trim()
        .split(RegExp(r'\s+'))
        .where((keyword) => keyword.length >= minMatchLength)
        .map((keyword) => keyword.toLowerCase())
        .toList();

    if (keywords.isEmpty) {
      return [TextSpan(text: text, style: normalStyle)];
    }

    // 找出所有匹配位置
    final List<MatchInfo> matches = [];
    final normalizedText = text.toLowerCase();

    for (final keyword in keywords) {
      int startIndex = 0;
      while (true) {
        final matchIndex = normalizedText.indexOf(keyword, startIndex);
        if (matchIndex == -1) break;

        matches.add(MatchInfo(
          start: matchIndex,
          end: matchIndex + keyword.length,
          keyword: keyword,
        ));

        startIndex = matchIndex + 1;
      }
    }

    // 按位置排序並合併重疊的匹配
    matches.sort((a, b) => a.start.compareTo(b.start));
    final mergedMatches = _mergeOverlappingMatches(matches);

    // 建構文字片段
    final List<TextSpan> spans = [];
    int currentIndex = 0;

    for (final match in mergedMatches) {
      // 添加匹配前的正常文字
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: normalStyle,
        ));
      }

      // 添加高亮文字
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: highlightStyle,
      ));

      currentIndex = match.end;
    }

    // 添加剩餘的正常文字
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: normalStyle,
      ));
    }

    return spans;
  }

  /// 合併重疊的匹配區間
  List<MatchInfo> _mergeOverlappingMatches(List<MatchInfo> matches) {
    if (matches.isEmpty) return matches;

    final List<MatchInfo> merged = [];
    MatchInfo current = matches.first;

    for (int i = 1; i < matches.length; i++) {
      final next = matches[i];

      if (next.start <= current.end) {
        // 重疊或相鄰，合併
        current = MatchInfo(
          start: current.start,
          end: next.end > current.end ? next.end : current.end,
          keyword: '${current.keyword}+${next.keyword}',
        );
      } else {
        // 不重疊，保存當前並開始新的
        merged.add(current);
        current = next;
      }
    }

    merged.add(current);
    return merged;
  }
}

/// 匹配信息類
class MatchInfo {
  final int start;
  final int end;
  final String keyword;

  MatchInfo({
    required this.start,
    required this.end,
    required this.keyword,
  });
}

/// 高亮文字工具類
class HighlightTextUtils {
  /// 正規化搜尋文本 - 移除特殊字符並轉為小寫
  static String normalizeSearchText(String text) {
    if (text.isEmpty) return '';

    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\-\(\)\.\,\:\;\!\?]'), '') // 保留更多標點符號
        .replaceAll(RegExp(r'\s+'), ' ') // 將多個空格替換為單個空格
        .trim();
  }

  /// 檢查文字是否包含搜尋關鍵字
  static bool containsKeyword(String text, String keyword) {
    if (keyword.isEmpty) return true;

    final normalizedText = normalizeSearchText(text);
    final normalizedKeyword = normalizeSearchText(keyword);

    return normalizedText.contains(normalizedKeyword);
  }

  /// 計算匹配相關性分數
  static int calculateRelevanceScore(String text, String keyword) {
    if (keyword.isEmpty) return 0;

    final normalizedText = normalizeSearchText(text);
    final normalizedKeyword = normalizeSearchText(keyword);

    if (normalizedText == normalizedKeyword) return 100; // 完全匹配
    if (normalizedText.startsWith(normalizedKeyword)) return 80; // 前綴匹配
    if (normalizedText.contains(normalizedKeyword)) return 60; // 包含匹配

    return 0; // 無匹配
  }
}
