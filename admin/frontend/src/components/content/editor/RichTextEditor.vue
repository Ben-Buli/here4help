<template>
  <div class="rich-text-editor">
    <!-- 工具列 -->
    <EditorToolbar
      :editor="editor"
      :config="toolbar"
      @insert-table="insertTable"
      @add-column="addColumn"
      @add-row="addRow"
      @delete-table="deleteTable"
    />

    <!-- 編輯區域 -->
    <div class="editor-shell" :style="{ minHeight: `${minHeight}px` }">
      <EditorContent :editor="editor" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, watch } from 'vue'
import { EditorContent, useEditor } from '@tiptap/vue-3'
import StarterKit from '@tiptap/starter-kit'
import Underline from '@tiptap/extension-underline'
import TextStyle from '@tiptap/extension-text-style'
import Color from '@tiptap/extension-color'
import Table from '@tiptap/extension-table'
import TableRow from '@tiptap/extension-table-row'
import TableHeader from '@tiptap/extension-table-header'
import TableCell from '@tiptap/extension-table-cell'
import EditorToolbar from './EditorToolbar.vue'
import { DEFAULT_TOOLBAR_CONFIG, type EditorToolbarConfig, type EditorOutputFormat, type HeadingLevel } from './types'

const props = withDefaults(defineProps<{
  /** v-model 綁定值（HTML 字串或 JSON 物件） */
  modelValue: string | Record<string, any> | null
  /** 輸出格式 */
  outputFormat?: EditorOutputFormat
  /** 工具列配置 */
  toolbar?: EditorToolbarConfig
  /** 最小高度（px） */
  minHeight?: number
  /** 是否唯讀 */
  readonly?: boolean
  /** Placeholder 文字 */
  placeholder?: string
}>(), {
  outputFormat: 'html',
  toolbar: () => DEFAULT_TOOLBAR_CONFIG,
  minHeight: 320,
  readonly: false,
  placeholder: '',
})

const emit = defineEmits<{
  (e: 'update:modelValue', value: string | Record<string, any>): void
}>()

// 計算支援的標題層級
const headingLevels = computed<HeadingLevel[]>(() => {
  return props.toolbar?.headings ?? [2, 3]
})

// 建立編輯器擴展
const createExtensions = () => {
  const extensions: any[] = [
    StarterKit.configure({
      heading: { levels: headingLevels.value },
      history: props.toolbar?.history !== false ? {} : false,
    }),
    Underline,
  ]

  // 文字顏色擴展
  if (props.toolbar?.textColor) {
    extensions.push(TextStyle)
    extensions.push(Color)
  }

  // 表格擴展
  if (props.toolbar?.table) {
    extensions.push(
      Table.configure({ resizable: true }),
      TableRow,
      TableHeader,
      TableCell
    )
  }

  return extensions
}

// 取得初始內容
const getInitialContent = () => {
  if (!props.modelValue) {
    return props.outputFormat === 'json' ? { type: 'doc', content: [] } : '<p></p>'
  }
  return props.modelValue
}

const editor = useEditor({
  extensions: createExtensions(),
  content: getInitialContent(),
  editable: !props.readonly,
  autofocus: false,
  onUpdate({ editor }) {
    if (props.outputFormat === 'json') {
      emit('update:modelValue', editor.getJSON())
    } else {
      emit('update:modelValue', editor.getHTML())
    }
  },
})

// 監聽 modelValue 變化
watch(
  () => props.modelValue,
  (value) => {
    const instance = editor.value
    if (!instance || value === undefined) return

    if (props.outputFormat === 'json') {
      const current = instance.getJSON()
      if (JSON.stringify(current) !== JSON.stringify(value)) {
        instance.commands.setContent(value as Record<string, any>)
      }
    } else {
      const current = instance.getHTML()
      if (current !== value) {
        instance.commands.setContent((value as string) || '<p></p>', false)
      }
    }
  },
  { deep: true }
)

// 監聽 readonly 變化
watch(
  () => props.readonly,
  (value) => {
    editor.value?.setOptions({ editable: !value })
  }
)

onBeforeUnmount(() => {
  editor.value?.destroy()
})

// 表格操作
const insertTable = () => {
  editor.value?.chain().focus().insertTable({ rows: 3, cols: 2, withHeaderRow: true }).run()
}

const addColumn = () => editor.value?.chain().focus().addColumnAfter().run()
const addRow = () => editor.value?.chain().focus().addRowAfter().run()
const deleteTable = () => editor.value?.chain().focus().deleteTable().run()

// 暴露編輯器實例給父組件使用
defineExpose({
  editor,
})
</script>

<style scoped>
/* 編輯區域容器 */
.editor-shell {
  border: 1px solid #e5e7eb;
  border-radius: 0 0 0.75rem 0.75rem;
  background-color: white;
  overflow: hidden;
}

.editor-shell:focus-within {
  border-color: #22d3ee;
  box-shadow: 0 0 0 3px rgba(34, 211, 238, 0.1);
}

/* ProseMirror 編輯器內容 */
.editor-shell :deep(.ProseMirror) {
  min-height: v-bind('`${minHeight}px`');
  padding: 1.25rem;
  outline: none;
  font-size: 1rem;
  line-height: 1.625;
  color: #1f2937;
}

.editor-shell :deep(.ProseMirror p) {
  margin: 0 0 1rem;
}

.editor-shell :deep(.ProseMirror p:last-child) {
  margin-bottom: 0;
}

/* 標題樣式 */
.editor-shell :deep(.ProseMirror h1) {
  font-size: 1.5rem;
  font-weight: 700;
  margin: 1rem 0;
  color: #111827;
}

.editor-shell :deep(.ProseMirror h2) {
  font-size: 1.25rem;
  font-weight: 700;
  margin: 0.75rem 0;
  color: #0891b2;
}

.editor-shell :deep(.ProseMirror h3) {
  font-size: 1.125rem;
  font-weight: 600;
  margin: 0.5rem 0;
  color: #374151;
}

.editor-shell :deep(.ProseMirror h4) {
  font-size: 1rem;
  font-weight: 600;
  margin: 0.5rem 0;
  color: #4b5563;
}

.editor-shell :deep(.ProseMirror h1:first-child),
.editor-shell :deep(.ProseMirror h2:first-child),
.editor-shell :deep(.ProseMirror h3:first-child),
.editor-shell :deep(.ProseMirror h4:first-child) {
  margin-top: 0;
}

/* 文字格式 */
.editor-shell :deep(.ProseMirror strong) {
  font-weight: 700;
}

.editor-shell :deep(.ProseMirror em) {
  font-style: italic;
}

.editor-shell :deep(.ProseMirror u) {
  text-decoration: underline;
}

/* 清單樣式 */
.editor-shell :deep(.ProseMirror ul) {
  list-style-type: disc;
  padding-left: 1.5rem;
  margin: 0.5rem 0 1rem;
}

.editor-shell :deep(.ProseMirror ol) {
  list-style-type: decimal;
  padding-left: 1.5rem;
  margin: 0.5rem 0 1rem;
}

.editor-shell :deep(.ProseMirror li) {
  margin-bottom: 0.375rem;
}

.editor-shell :deep(.ProseMirror li p) {
  margin: 0;
}

/* 表格樣式 */
.editor-shell :deep(.ProseMirror table) {
  border-collapse: collapse;
  width: 100%;
  margin: 1rem 0;
  table-layout: fixed;
}

.editor-shell :deep(.ProseMirror table td),
.editor-shell :deep(.ProseMirror table th) {
  border: 1px solid #d1d5db;
  padding: 0.75rem;
  vertical-align: top;
  position: relative;
  min-width: 100px;
}

.editor-shell :deep(.ProseMirror table th) {
  background-color: #f3f4f6;
  font-weight: 600;
  color: #374151;
  text-align: left;
}

.editor-shell :deep(.ProseMirror table td) {
  background-color: #fff;
}

/* 表格選中狀態 */
.editor-shell :deep(.ProseMirror .selectedCell::after) {
  content: '';
  position: absolute;
  left: 0;
  right: 0;
  top: 0;
  bottom: 0;
  background: rgba(34, 211, 238, 0.15);
  pointer-events: none;
  z-index: 2;
}

/* 表格調整大小把手 */
.editor-shell :deep(.ProseMirror .column-resize-handle) {
  position: absolute;
  right: -2px;
  top: 0;
  bottom: -2px;
  width: 4px;
  background-color: #22d3ee;
  cursor: col-resize;
  z-index: 20;
}

.editor-shell :deep(.ProseMirror.resize-cursor) {
  cursor: col-resize;
}
</style>
