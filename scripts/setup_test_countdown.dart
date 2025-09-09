#!/usr/bin/env dart

import 'dart:io';

/// 測試倒數設置腳本
/// 將 pending confirmation 的 7 天倒數改為 10 秒，方便測試
void main(List<String> args) {
  print('🧪 設置測試用倒數時間（7天 → 10秒）');

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

      // 替換 7 天為 10 秒
      final originalPattern = 'Duration(days: 7)';
      final testPattern = 'Duration(seconds: 10) // 測試用：原本是 Duration(days: 7)';

      if (content.contains(originalPattern)) {
        content = content.replaceAll(originalPattern, testPattern);
        file.writeAsStringSync(content);
        print('✅ 已修改: $filePath');
        print('   $originalPattern → $testPattern');
      } else if (content.contains(testPattern)) {
        print('⚠️  已經是測試模式: $filePath');
      } else {
        print('🔍 未找到需要替換的內容: $filePath');
      }
    } catch (e) {
      print('❌ 處理文件失敗 $filePath: $e');
    }
  }

  print('\n📋 測試設置完成！');
  print('🔄 請重新啟動 Flutter 應用以生效');
  print('⏰ 現在 pending confirmation 任務將在 10 秒後自動完成');
  print('\n🔧 測試完成後，請執行 restore_countdown.dart 恢復正常設置');
}
