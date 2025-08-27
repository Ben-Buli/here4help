import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// 圖片上傳測試頁面
/// 用於測試各種圖片格式、壓縮和 Web 兼容性問題
class ImageUploadTestPage extends StatefulWidget {
  const ImageUploadTestPage({Key? key}) : super(key: key);

  @override
  State<ImageUploadTestPage> createState() => _ImageUploadTestPageState();
}

class _ImageUploadTestPageState extends State<ImageUploadTestPage> {
  final ImagePicker _picker = ImagePicker();
  final List<TestResult> _testResults = [];
  bool _isTesting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('圖片上傳測試工具'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 環境信息
            _buildEnvironmentInfo(),
            const SizedBox(height: 20),

            // 測試按鈕
            _buildTestButtons(),
            const SizedBox(height: 20),

            // 測試結果
            Expanded(
              child: _buildTestResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '環境信息',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('平台: ${kIsWeb ? 'Web' : 'Native'}'),
            const Text('Debug 模式: ${kDebugMode ? '是' : '否'}'),
            if (!kIsWeb) Text('操作系統: ${Platform.operatingSystem}'),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '測試選項',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _isTesting ? null : () => _testImageSelection(),
                  child: const Text('測試圖片選擇'),
                ),
                ElevatedButton(
                  onPressed: _isTesting ? null : () => _testImageCompression(),
                  child: const Text('測試圖片壓縮'),
                ),
                ElevatedButton(
                  onPressed:
                      _isTesting ? null : () => _testThumbnailGeneration(),
                  child: const Text('測試縮圖生成'),
                ),
                ElevatedButton(
                  onPressed: _isTesting ? null : () => _testFullPipeline(),
                  child: const Text('完整流程測試'),
                ),
                ElevatedButton(
                  onPressed: _testResults.isEmpty ? null : _clearResults,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('清除結果'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResults() {
    if (_testResults.isEmpty) {
      return const Card(
        child: Center(
          child: Text(
            '點擊上方按鈕開始測試',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '測試結果',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _testResults.length,
              itemBuilder: (context, index) {
                final result = _testResults[index];
                return ListTile(
                  leading: Icon(
                    result.success ? Icons.check_circle : Icons.error,
                    color: result.success ? Colors.green : Colors.red,
                  ),
                  title: Text(result.testName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.message),
                      if (result.details.isNotEmpty)
                        ...result.details.map(
                          (detail) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '• $detail',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ),
                    ],
                  ),
                  isThreeLine: result.details.isNotEmpty,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 測試圖片選擇
  Future<void> _testImageSelection() async {
    setState(() => _isTesting = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (image == null) {
        _addResult(TestResult(
          testName: '圖片選擇測試',
          success: false,
          message: '用戶取消選擇',
        ));
        return;
      }

      final fileSize = await image.length();
      final bytes = await image.readAsBytes();

      // 獲取圖片信息
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final width = frameInfo.image.width;
      final height = frameInfo.image.height;

      _addResult(TestResult(
        testName: '圖片選擇測試',
        success: true,
        message: '圖片選擇成功',
        details: [
          '檔案名稱: ${image.name}',
          '檔案大小: ${_formatBytes(fileSize)}',
          '圖片尺寸: ${width}x$height',
          '路徑: ${image.path}',
          'MIME 類型: ${image.mimeType ?? '未知'}',
        ],
      ));
    } catch (e) {
      _addResult(TestResult(
        testName: '圖片選擇測試',
        success: false,
        message: '選擇失敗: $e',
      ));
    } finally {
      setState(() => _isTesting = false);
    }
  }

  // 測試圖片壓縮
  Future<void> _testImageCompression() async {
    setState(() => _isTesting = true);

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        _addResult(TestResult(
          testName: '圖片壓縮測試',
          success: false,
          message: '用戶取消選擇',
        ));
        return;
      }

      final originalBytes = await image.readAsBytes();
      final originalSize = originalBytes.length;

      // 測試不同的壓縮方式
      final List<String> compressionResults = [];

      // 1. Web 兼容壓縮（僅質量）
      try {
        Uint8List webCompressed;
        if (kIsWeb) {
          // Web 環境：直接使用 bytes，不轉換
          webCompressed = await FlutterImageCompress.compressWithList(
            originalBytes,
            quality: 80,
            format: CompressFormat.webp,
          );
        } else {
          // 原生環境：轉換為 Uint8List
          webCompressed = await FlutterImageCompress.compressWithList(
            Uint8List.fromList(originalBytes),
            quality: 80,
            format: CompressFormat.webp,
          );
        }
        compressionResults.add(
            'Web 兼容壓縮: ${_formatBytes(originalSize)} → ${_formatBytes(webCompressed.length)}');
      } catch (e) {
        compressionResults.add('Web 兼容壓縮失敗: $e');
      }

      // 2. 原生壓縮（含尺寸參數）
      if (!kIsWeb) {
        try {
          final nativeCompressed = await FlutterImageCompress.compressWithList(
            Uint8List.fromList(originalBytes),
            minWidth: 1024,
            minHeight: 1024,
            quality: 80,
            format: CompressFormat.webp,
          );
          compressionResults.add(
              '原生壓縮: ${_formatBytes(originalSize)} → ${_formatBytes(nativeCompressed.length)}');
        } catch (e) {
          compressionResults.add('原生壓縮失敗: $e');
        }
      }

      // 3. JPEG 格式壓縮
      try {
        Uint8List jpegCompressed;
        if (kIsWeb) {
          // Web 環境：直接使用 bytes
          jpegCompressed = await FlutterImageCompress.compressWithList(
            originalBytes,
            quality: 80,
            format: CompressFormat.jpeg,
          );
        } else {
          // 原生環境：轉換為 Uint8List
          jpegCompressed = await FlutterImageCompress.compressWithList(
            Uint8List.fromList(originalBytes),
            quality: 80,
            format: CompressFormat.jpeg,
          );
        }
        compressionResults.add(
            'JPEG 壓縮: ${_formatBytes(originalSize)} → ${_formatBytes(jpegCompressed.length)}');
      } catch (e) {
        compressionResults.add('JPEG 壓縮失敗: $e');
      }

      _addResult(TestResult(
        testName: '圖片壓縮測試',
        success: true,
        message: '壓縮測試完成',
        details: [
          '原始大小: ${_formatBytes(originalSize)}',
          ...compressionResults,
        ],
      ));
    } catch (e) {
      _addResult(TestResult(
        testName: '圖片壓縮測試',
        success: false,
        message: '壓縮測試失敗: $e',
      ));
    } finally {
      setState(() => _isTesting = false);
    }
  }

  // 測試縮圖生成
  Future<void> _testThumbnailGeneration() async {
    setState(() => _isTesting = true);

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        _addResult(TestResult(
          testName: '縮圖生成測試',
          success: false,
          message: '用戶取消選擇',
        ));
        return;
      }

      final originalBytes = await image.readAsBytes();
      final originalSize = originalBytes.length;

      // 獲取原始尺寸
      final ui.Codec codec = await ui.instantiateImageCodec(originalBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final originalWidth = frameInfo.image.width;
      final originalHeight = frameInfo.image.height;

      final List<String> thumbnailResults = [];

      // 1. Web 兼容縮圖
      try {
        Uint8List webThumbnail;
        if (kIsWeb) {
          // Web 環境：直接使用 bytes
          webThumbnail = await FlutterImageCompress.compressWithList(
            originalBytes,
            quality: 70,
            format: CompressFormat.webp,
          );
        } else {
          // 原生環境：轉換為 Uint8List
          webThumbnail = await FlutterImageCompress.compressWithList(
            Uint8List.fromList(originalBytes),
            quality: 70,
            format: CompressFormat.webp,
          );
        }
        thumbnailResults.add('Web 兼容縮圖: ${_formatBytes(webThumbnail.length)}');
      } catch (e) {
        thumbnailResults.add('Web 兼容縮圖失敗: $e');
      }

      // 2. 原生縮圖（含尺寸參數）
      if (!kIsWeb) {
        try {
          final nativeThumbnail = await FlutterImageCompress.compressWithList(
            Uint8List.fromList(originalBytes),
            minWidth: 256,
            minHeight: 256,
            quality: 70,
            format: CompressFormat.webp,
          );
          thumbnailResults.add('原生縮圖: ${_formatBytes(nativeThumbnail.length)}');
        } catch (e) {
          thumbnailResults.add('原生縮圖失敗: $e');
        }
      }

      _addResult(TestResult(
        testName: '縮圖生成測試',
        success: true,
        message: '縮圖測試完成',
        details: [
          '原始尺寸: ${originalWidth}x$originalHeight (${_formatBytes(originalSize)})',
          ...thumbnailResults,
        ],
      ));
    } catch (e) {
      _addResult(TestResult(
        testName: '縮圖生成測試',
        success: false,
        message: '縮圖測試失敗: $e',
      ));
    } finally {
      setState(() => _isTesting = false);
    }
  }

  // 完整流程測試
  Future<void> _testFullPipeline() async {
    setState(() => _isTesting = true);

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        _addResult(TestResult(
          testName: '完整流程測試',
          success: false,
          message: '用戶取消選擇',
        ));
        return;
      }

      final List<String> pipelineResults = [];
      bool allSuccess = true;

      // 1. 讀取圖片
      try {
        final bytes = await image.readAsBytes();
        final fileSize = await image.length();
        pipelineResults.add('✅ 圖片讀取成功: ${_formatBytes(fileSize)}');
      } catch (e) {
        pipelineResults.add('❌ 圖片讀取失敗: $e');
        allSuccess = false;
      }

      // 2. 獲取尺寸
      try {
        final bytes = await image.readAsBytes();
        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        final width = frameInfo.image.width;
        final height = frameInfo.image.height;
        pipelineResults.add('✅ 尺寸獲取成功: ${width}x$height');

        // 3. 尺寸驗證
        if (width >= 320 && height >= 320) {
          pipelineResults.add('✅ 尺寸驗證通過');
        } else {
          pipelineResults.add('❌ 尺寸驗證失敗: 小於 320x320');
          allSuccess = false;
        }
      } catch (e) {
        pipelineResults.add('❌ 尺寸獲取失敗: $e');
        allSuccess = false;
      }

      // 4. 壓縮測試
      try {
        final bytes = await image.readAsBytes();
        final compressed = await FlutterImageCompress.compressWithList(
          kIsWeb ? bytes : Uint8List.fromList(bytes),
          quality: 80,
          format: CompressFormat.webp,
        );
        pipelineResults.add('✅ 圖片壓縮成功: ${_formatBytes(compressed.length)}');
      } catch (e) {
        pipelineResults.add('❌ 圖片壓縮失敗: $e');
        allSuccess = false;
      }

      // 5. 縮圖生成測試
      try {
        final bytes = await image.readAsBytes();
        final thumbnail = await FlutterImageCompress.compressWithList(
          kIsWeb ? bytes : Uint8List.fromList(bytes),
          quality: 70,
          format: CompressFormat.webp,
        );
        pipelineResults.add('✅ 縮圖生成成功: ${_formatBytes(thumbnail.length)}');
      } catch (e) {
        pipelineResults.add('❌ 縮圖生成失敗: $e');
        allSuccess = false;
      }

      _addResult(TestResult(
        testName: '完整流程測試',
        success: allSuccess,
        message: allSuccess ? '所有步驟都成功' : '部分步驟失敗',
        details: pipelineResults,
      ));
    } catch (e) {
      _addResult(TestResult(
        testName: '完整流程測試',
        success: false,
        message: '流程測試失敗: $e',
      ));
    } finally {
      setState(() => _isTesting = false);
    }
  }

  void _addResult(TestResult result) {
    setState(() {
      _testResults.insert(0, result);
    });
  }

  void _clearResults() {
    setState(() {
      _testResults.clear();
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
}

class TestResult {
  final String testName;
  final bool success;
  final String message;
  final List<String> details;

  TestResult({
    required this.testName,
    required this.success,
    required this.message,
    this.details = const [],
  });
}
