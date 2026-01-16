<template>
  <div class="editor-toolbar">
    <!-- 文字格式：粗體、斜體、底線 -->
    <div v-if="config.bold || config.italic || config.underline" class="toolbar-group">
      <button
        v-if="config.bold"
        type="button"
        class="toolbar-btn icon-only"
        :class="{ active: editor?.isActive('bold') }"
        @click="editor?.chain().focus().toggleBold().run()"
        title="粗體 (Ctrl+B)"
      >
        <span class="font-semibold">B</span>
      </button>
      <button
        v-if="config.italic"
        type="button"
        class="toolbar-btn icon-only"
        :class="{ active: editor?.isActive('italic') }"
        @click="editor?.chain().focus().toggleItalic().run()"
        title="斜體 (Ctrl+I)"
      >
        <span class="italic">I</span>
      </button>
      <button
        v-if="config.underline"
        type="button"
        class="toolbar-btn icon-only"
        :class="{ active: editor?.isActive('underline') }"
        @click="editor?.chain().focus().toggleUnderline().run()"
        title="底線 (Ctrl+U)"
      >
        <span class="underline">U</span>
      </button>
    </div>

    <!-- 標題 -->
    <div v-if="config.headings?.length || config.paragraph" class="toolbar-group">
      <button
        v-for="level in config.headings"
        :key="`h${level}`"
        type="button"
        class="toolbar-btn text-pill"
        :class="{ active: editor?.isActive('heading', { level }) }"
        @click="editor?.chain().focus().toggleHeading({ level }).run()"
        :title="`標題 ${level}`"
      >
        H{{ level }}
      </button>
      <button
        v-if="config.paragraph"
        type="button"
        class="toolbar-btn text-pill"
        :class="{ active: !editor?.isActive('heading') && editor?.isActive('paragraph') }"
        @click="editor?.chain().focus().setParagraph().run()"
        title="一般段落"
      >
        P
      </button>
    </div>

    <!-- 文字顏色 -->
    <div v-if="config.textColor" class="toolbar-group">
      <ColorPicker
        :presets="config.colorPresets"
        @select="handleColorSelect"
      />
    </div>

    <!-- 清單 -->
    <div v-if="config.bulletList || config.orderedList" class="toolbar-group">
      <button
        v-if="config.bulletList"
        type="button"
        class="toolbar-btn icon-only"
        :class="{ active: editor?.isActive('bulletList') }"
        @click="editor?.chain().focus().toggleBulletList().run()"
        title="項目符號清單"
      >
        <svg viewBox="0 0 24 24" class="toolbar-svg" fill="none">
          <circle cx="5" cy="6" r="2" fill="currentColor" />
          <circle cx="5" cy="12" r="2" fill="currentColor" />
          <circle cx="5" cy="18" r="2" fill="currentColor" />
          <line x1="10" y1="6" x2="20" y2="6" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
          <line x1="10" y1="12" x2="20" y2="12" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
          <line x1="10" y1="18" x2="20" y2="18" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
        </svg>
      </button>
      <button
        v-if="config.orderedList"
        type="button"
        class="toolbar-btn icon-only"
        :class="{ active: editor?.isActive('orderedList') }"
        @click="editor?.chain().focus().toggleOrderedList().run()"
        title="編號清單"
      >
        <svg viewBox="0 0 24 24" class="toolbar-svg" fill="none">
          <text x="3" y="8" font-size="6" font-weight="bold" fill="currentColor">1</text>
          <text x="3" y="14" font-size="6" font-weight="bold" fill="currentColor">2</text>
          <text x="3" y="20" font-size="6" font-weight="bold" fill="currentColor">3</text>
          <line x1="10" y1="6" x2="20" y2="6" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
          <line x1="10" y1="12" x2="20" y2="12" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
          <line x1="10" y1="18" x2="20" y2="18" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
        </svg>
      </button>
    </div>

    <!-- 表格操作 -->
    <div v-if="config.table" class="toolbar-group">
      <button
        type="button"
        class="toolbar-btn icon-only"
        @click="$emit('insertTable')"
        title="插入表格"
      >
        <svg viewBox="0 0 24 24" class="toolbar-svg" fill="none">
          <rect x="3" y="3" width="18" height="18" rx="2" stroke="currentColor" stroke-width="1.5" />
          <line x1="3" y1="9" x2="21" y2="9" stroke="currentColor" stroke-width="1.5" />
          <line x1="3" y1="15" x2="21" y2="15" stroke="currentColor" stroke-width="1.5" />
          <line x1="9" y1="3" x2="9" y2="21" stroke="currentColor" stroke-width="1.5" />
          <line x1="15" y1="3" x2="15" y2="21" stroke="currentColor" stroke-width="1.5" />
        </svg>
      </button>
      <button
        type="button"
        class="toolbar-btn icon-only"
        @click="$emit('addColumn')"
        title="新增欄位"
      >
        <svg viewBox="0 0 24 24" class="toolbar-svg" fill="none">
          <rect x="4" y="4" width="6" height="16" rx="1" stroke="currentColor" stroke-width="1.5" />
          <line x1="17" y1="8" x2="17" y2="16" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
          <line x1="13" y1="12" x2="21" y2="12" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
        </svg>
      </button>
      <button
        type="button"
        class="toolbar-btn icon-only"
        @click="$emit('addRow')"
        title="新增列"
      >
        <svg viewBox="0 0 24 24" class="toolbar-svg" fill="none">
          <rect x="4" y="4" width="16" height="6" rx="1" stroke="currentColor" stroke-width="1.5" />
          <line x1="8" y1="17" x2="16" y2="17" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
          <line x1="12" y1="13" x2="12" y2="21" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
        </svg>
      </button>
      <button
        type="button"
        class="toolbar-btn icon-only"
        @click="$emit('deleteTable')"
        title="刪除表格"
      >
        <svg viewBox="0 0 24 24" class="toolbar-svg" fill="none">
          <rect x="3" y="3" width="18" height="18" rx="2" stroke="currentColor" stroke-width="1.5" />
          <line x1="9" y1="3" x2="9" y2="21" stroke="currentColor" stroke-width="1.5" />
          <line x1="3" y1="9" x2="21" y2="9" stroke="currentColor" stroke-width="1.5" />
          <line x1="8" y1="14" x2="16" y2="14" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
        </svg>
      </button>
    </div>

    <!-- 復原/重做 -->
    <div v-if="config.history" class="toolbar-group">
      <button
        type="button"
        class="toolbar-btn icon-only"
        :disabled="!canUndo"
        @click="editor?.chain().focus().undo().run()"
        title="復原 (Ctrl+Z)"
      >
        <svg viewBox="0 0 24 24" class="toolbar-svg" fill="none">
          <path d="M3 10h10a5 5 0 0 1 5 5v2" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
          <path d="M7 6l-4 4 4 4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </button>
      <button
        type="button"
        class="toolbar-btn icon-only"
        :disabled="!canRedo"
        @click="editor?.chain().focus().redo().run()"
        title="重做 (Ctrl+Y)"
      >
        <svg viewBox="0 0 24 24" class="toolbar-svg" fill="none">
          <path d="M21 10H11a5 5 0 0 0-5 5v2" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
          <path d="M17 6l4 4-4 4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { Editor } from '@tiptap/vue-3'
import ColorPicker from './ColorPicker.vue'
import { DEFAULT_TOOLBAR_CONFIG, type EditorToolbarConfig } from './types'

const props = withDefaults(defineProps<{
  editor: Editor | undefined
  config?: EditorToolbarConfig
}>(), {
  config: () => DEFAULT_TOOLBAR_CONFIG,
})

defineEmits<{
  (e: 'insertTable'): void
  (e: 'addColumn'): void
  (e: 'addRow'): void
  (e: 'deleteTable'): void
}>()

const config = computed(() => ({
  ...DEFAULT_TOOLBAR_CONFIG,
  ...props.config,
}))

const canUndo = computed(() => props.editor?.can().undo() ?? false)
const canRedo = computed(() => props.editor?.can().redo() ?? false)

const handleColorSelect = (color: string | null) => {
  if (!props.editor) return
  if (color) {
    props.editor.chain().focus().setColor(color).run()
  } else {
    props.editor.chain().focus().unsetColor().run()
  }
}
</script>

<style scoped>
.editor-toolbar {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  align-items: center;
  padding: 0.75rem;
  background-color: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 0.75rem 0.75rem 0 0;
  border-bottom: none;
}

.toolbar-group {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.25rem;
  background-color: white;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
}

.toolbar-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0.375rem 0.625rem;
  font-size: 0.875rem;
  font-weight: 500;
  color: #4b5563;
  background-color: transparent;
  border: none;
  border-radius: 0.375rem;
  cursor: pointer;
  transition: all 0.15s ease;
}

.toolbar-btn:hover {
  background-color: #f3f4f6;
  color: #0891b2;
}

.toolbar-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.toolbar-btn.active {
  background-color: #ecfeff;
  color: #0891b2;
}

.toolbar-btn.icon-only {
  width: 2rem;
  height: 2rem;
  padding: 0.25rem;
}

.toolbar-btn.text-pill {
  min-width: 2rem;
  font-weight: 600;
}

.toolbar-svg {
  width: 1.125rem;
  height: 1.125rem;
}
</style>
