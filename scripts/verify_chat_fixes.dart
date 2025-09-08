#!/usr/bin/env dart
// 驗證 Posted Tasks 和 My Works 修復是否正確實施的腳本
// 使用方法：dart scripts/verify_chat_fixes.dart

import 'dart:io';

void main() {
  print('🔍 驗證聊天室修復實施狀態...\n');

  final results = <String, bool>{};

  // 檢查 1：增強邏輯文件是否存在
  results['增強邏輯文件'] = _checkEnhancementFiles();

  // 檢查 2：Posted Tasks 修改是否實施
  results['Posted Tasks 修改'] = _checkPostedTasksModifications();

  // 檢查 3：My Works 修改是否實施
  results['My Works 修改'] = _checkMyWorksModifications();

  // 檢查 4：補丁文件是否存在
  results['補丁文件'] = _checkPatchFiles();

  // 輸出結果
  _printResults(results);

  // 提供建議
  _provideSuggestions(results);
}

bool _checkEnhancementFiles() {
  final files = [
    'lib/chat/widgets/posted_tasks_widget_enhanced.dart',
    'lib/chat/widgets/my_works_widget_enhanced.dart',
  ];

  print('📁 檢查增強邏輯文件:');
  bool allExists = true;

  for (final file in files) {
    final exists = File(file).existsSync();
    final status = exists ? '✅' : '❌';
    print('  $status $file');
    allExists = allExists && exists;
  }

  return allExists;
}

bool _checkPostedTasksModifications() {
  const filePath = 'lib/chat/widgets/posted_tasks_widget.dart';
  final file = File(filePath);

  print('\n📋 檢查 Posted Tasks 修改:');

  if (!file.existsSync()) {
    print('  ❌ 文件不存在: $filePath');
    return false;
  }

  final content = file.readAsStringSync();
  final checks = <String, bool>{};

  // 檢查是否添加了 import
  checks['導入增強邏輯'] = content.contains('posted_tasks_widget_enhanced.dart');

  // 檢查是否添加了 mixin
  checks['添加 Mixin'] = content.contains('PostedTasksApplicantFilterMixin');

  // 檢查是否有篩選邏輯
  checks['篩選邏輯調用'] = content.contains('filterApplicantsForTask') ||
      content.contains('shouldShowApplicantsForTask');

  // 檢查是否有調試信息
  checks['調試信息'] =
      content.contains('PostedTasksApplicantFilter.debugTaskApplicants');

  for (final entry in checks.entries) {
    final status = entry.value ? '✅' : '❌';
    print('  $status ${entry.key}');
  }

  return checks.values.every((v) => v);
}

bool _checkMyWorksModifications() {
  const filePath = 'lib/chat/widgets/my_works_widget.dart';
  final file = File(filePath);

  print('\n🏗️ 檢查 My Works 修改:');

  if (!file.existsSync()) {
    print('  ❌ 文件不存在: $filePath');
    return false;
  }

  final content = file.readAsStringSync();
  final checks = <String, bool>{};

  // 檢查是否添加了 import
  checks['導入增強邏輯'] = content.contains('my_works_widget_enhanced.dart');

  // 檢查是否添加了 mixin
  checks['添加 Mixin'] = content.contains('MyWorksRealtimeMessageMixin');

  // 檢查是否有實時訊息邏輯
  checks['實時訊息邏輯'] = content.contains('buildEnhancedChatPartnerSection') ||
      content.contains('supportsRealtimeMessages');

  // 檢查是否有預載入邏輯
  checks['預載入連接'] = content.contains('preloadRealtimeConnections');

  // 檢查是否有統計信息
  checks['統計信息'] = content.contains('MyWorksMessageStats');

  for (final entry in checks.entries) {
    final status = entry.value ? '✅' : '❌';
    print('  $status ${entry.key}');
  }

  return checks.values.every((v) => v);
}

bool _checkPatchFiles() {
  final files = [
    'patches/posted_tasks_applicant_filter.patch',
    'patches/my_works_realtime_message.patch',
  ];

  print('\n🔧 檢查補丁文件:');
  bool allExists = true;

  for (final file in files) {
    final exists = File(file).existsSync();
    final status = exists ? '✅' : '❌';
    print('  $status $file');
    allExists = allExists && exists;
  }

  return allExists;
}

void _printResults(Map<String, bool> results) {
  print('\n📊 驗證結果摘要:');
  print('━━━━━━━━━━━━━━━━━━━━');

  for (final entry in results.entries) {
    final status = entry.value ? '✅ 通過' : '❌ 失敗';
    print('  ${entry.key.padRight(12)} $status');
  }

  final totalChecks = results.length;
  final passedChecks = results.values.where((v) => v).length;
  final passRate = (passedChecks / totalChecks * 100).toStringAsFixed(1);

  print('━━━━━━━━━━━━━━━━━━━━');
  print('  總體通過率: $passedChecks/$totalChecks ($passRate%)');

  if (passedChecks == totalChecks) {
    print('\n🎉 所有檢查通過！修復已正確實施。');
  } else {
    print('\n⚠️  還有 ${totalChecks - passedChecks} 個檢查未通過，需要進一步實施。');
  }
}

void _provideSuggestions(Map<String, bool> results) {
  print('\n💡 實施建議:');
  print('━━━━━━━━━━━━━━━━━━━━');

  if (!results['增強邏輯文件']!) {
    print('1. 複製增強邏輯文件到 lib/chat/widgets/ 目錄');
  }

  if (!results['Posted Tasks 修改']!) {
    print('2. 按照 patches/posted_tasks_applicant_filter.patch 修改 Posted Tasks');
    print('   - 添加 import 和 mixin');
    print('   - 在 _buildTaskCard 中調用篩選邏輯');
    print('   - 增強應徵者區塊顯示');
  }

  if (!results['My Works 修改']!) {
    print('3. 按照 patches/my_works_realtime_message.patch 修改 My Works');
    print('   - 添加 import 和 mixin');
    print('   - 實現抽象方法');
    print('   - 替換 _buildChatPartnerSection 方法');
  }

  if (!results['補丁文件']!) {
    print('4. 確保補丁文件存在於 patches/ 目錄中');
  }

  print('\n📚 詳細實施指南:');
  print('   參考 docs/chat_filter_and_realtime_fixes_guide.md');

  print('\n🧪 測試驗證:');
  print('   1. 檢查 Posted Tasks 不同狀態的應徵者顯示');
  print('   2. 測試 My Works 實時訊息更新');
  print('   3. 查看調試日誌確認功能正常');
}
