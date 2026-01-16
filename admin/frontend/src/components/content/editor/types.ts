/**
 * 共用富文本編輯器類型定義
 */

/** 支援的標題層級 */
export type HeadingLevel = 1 | 2 | 3 | 4

/** 編輯器輸出格式 */
export type EditorOutputFormat = 'html' | 'json'

/** 工具列配置 */
export interface EditorToolbarConfig {
  /** 粗體 */
  bold?: boolean
  /** 斜體 */
  italic?: boolean
  /** 底線 */
  underline?: boolean

  /** 標題層級（例如 [1, 2, 3] 表示 H1, H2, H3） */
  headings?: HeadingLevel[]
  /** 段落按鈕 */
  paragraph?: boolean

  /** 文字顏色選擇器 */
  textColor?: boolean
  /** 預設顏色選項 */
  colorPresets?: string[]

  /** 無序清單 */
  bulletList?: boolean
  /** 有序清單 */
  orderedList?: boolean

  /** 表格操作 */
  table?: boolean

  /** 復原/重做 */
  history?: boolean
}

/** 預設顏色選項 */
export const DEFAULT_COLOR_PRESETS = [
  '#000000', // 黑色
  '#374151', // 灰色
  '#dc2626', // 紅色
  '#ea580c', // 橙色
  '#16a34a', // 綠色
  '#0891b2', // 青色
  '#2563eb', // 藍色
  '#7c3aed', // 紫色
]

/** 預設工具列配置 */
export const DEFAULT_TOOLBAR_CONFIG: EditorToolbarConfig = {
  bold: true,
  italic: true,
  underline: true,
  headings: [2, 3],
  paragraph: true,
  textColor: false,
  bulletList: true,
  orderedList: true,
  table: false,
  history: true,
}

/** 完整功能配置（給 PointPolicyEditor 使用） */
export const FULL_TOOLBAR_CONFIG: EditorToolbarConfig = {
  bold: true,
  italic: true,
  underline: true,
  headings: [1, 2, 3],
  paragraph: true,
  textColor: true,
  colorPresets: DEFAULT_COLOR_PRESETS,
  bulletList: true,
  orderedList: true,
  table: true,
  history: true,
}

/** 簡易配置（給 AppTermsEditor 使用） */
export const SIMPLE_TOOLBAR_CONFIG: EditorToolbarConfig = {
  bold: true,
  italic: true,
  underline: true,
  headings: [1, 2, 3, 4],
  paragraph: true,
  bulletList: true,
  orderedList: true,
  history: true,
}
