#!/usr/bin/env dart

import 'dart:io';

/// 恢復倒數設置腳本
/// 將測試用的 10 秒倒數改回正常的 7 天
void main(List<String> args) {
  print('🔄 恢復正常倒數時間（10秒 → 7天）');

  final files = [
    'lib/chat/widgets/task_card_components.dart',
    'lib/chat/pages/chat_detail_page.dart',
  ];

  for (final filePath in files) {
    final file = File(filePath);

    if (!file.existsSync()) {
      print('❌ 文件不存在: $filePath');
      continue;
    }

    try {
      String content = file.readAsStringSync();

      // 恢復測試設置為正常設置
      const testPattern = 'Duration(seconds: 10) // 測試用：原本是 Duration(days: 7)';
      const originalPattern = 'Duration(days: 7)';

      if (content.contains(testPattern)) {
        content = content.replaceAll(testPattern, originalPattern);
        file.writeAsStringSync(content);
        print('✅ 已恢復: $filePath');
        print('   $testPattern → $originalPattern');
      } else if (content.contains(originalPattern)) {
        print('✅ 已經是正常模式: $filePath');
      } else {
        print('🔍 未找到需要恢復的內容: $filePath');
      }
    } catch (e) {
      print('❌ 處理文件失敗 $filePath: $e');
    }
  }

  print('\n📋 恢復設置完成！');
  print('🔄 請重新啟動 Flutter 應用以生效');
  print('⏰ 現在 pending confirmation 任務將在 7 天後自動完成');
}
