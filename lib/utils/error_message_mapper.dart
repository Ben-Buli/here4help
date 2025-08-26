/// 圖片上傳錯誤訊息映射工具
/// 將技術性錯誤轉換為用戶友好的提示訊息

String getImageUploadErrorMessage(String error) {
  final errorLower = error.toLowerCase();

  // 圖片尺寸相關錯誤
  if (errorLower.contains('圖片尺寸太小') || errorLower.contains('最小需要')) {
    return '圖片尺寸太小，請選擇至少 320x320 的圖片';
  }

  // 檔案大小相關錯誤
  if (errorLower.contains('檔案過大') ||
      errorLower.contains('最大允許') ||
      errorLower.contains('file size') ||
      errorLower.contains('too large')) {
    return '圖片檔案過大，請選擇小於 10MB 的圖片';
  }

  // 檔案格式相關錯誤
  if (errorLower.contains('不支援的檔案格式') ||
      errorLower.contains('格式') ||
      errorLower.contains('format') ||
      errorLower.contains('extension')) {
    return '不支援的檔案格式，請選擇 JPG、PNG 或 WebP 圖片';
  }

  // 網路相關錯誤
  if (errorLower.contains('網路') ||
      errorLower.contains('network') ||
      errorLower.contains('connection') ||
      errorLower.contains('timeout')) {
    return '網路連線問題，請檢查網路後重試';
  }

  // 壓縮相關錯誤
  if (errorLower.contains('壓縮') ||
      errorLower.contains('compress') ||
      errorLower.contains('platform._operatingsystem') ||
      errorLower.contains('unsupported operation')) {
    return '圖片處理失敗，請嘗試選擇其他圖片';
  }

  // Web 環境相關錯誤
  if (errorLower.contains('_namespace') ||
      errorLower.contains('web') ||
      errorLower.contains('browser')) {
    return '瀏覽器環境處理失敗，請重新選擇圖片';
  }

  // 托盤相關錯誤
  if (errorLower.contains('托盤已滿') || errorLower.contains('最多只能添加')) {
    return '托盤已滿，最多只能添加 9 張圖片';
  }

  // 上傳相關錯誤
  if (errorLower.contains('上傳') || errorLower.contains('upload')) {
    return '圖片上傳失敗，請重試';
  }

  // 選擇圖片相關錯誤
  if (errorLower.contains('選擇') || errorLower.contains('pick')) {
    return '選擇圖片失敗，請重試';
  }

  // 重試相關錯誤
  if (errorLower.contains('重試') || errorLower.contains('retry')) {
    return '重試失敗，請稍後再試';
  }

  // 通用錯誤
  return '操作失敗，請重試';
}
