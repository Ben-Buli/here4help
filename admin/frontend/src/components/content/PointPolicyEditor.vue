<template>
  <div class="space-y-4">
    <div class="editor-toolbar">
      <div class="toolbar-group">
        <button
          type="button"
          class="toolbar-btn icon-only"
          :class="{ active: editor?.isActive('bold') }"
          @click="editor?.chain().focus().toggleBold().run()"
          title="Bold"
        >
          <span class="toolbar-icon font-semibold">B</span>
        </button>
        <button
          type="button"
          class="toolbar-btn icon-only"
          :class="{ active: editor?.isActive('italic') }"
          @click="editor?.chain().focus().toggleItalic().run()"
          title="Italic"
        >
          <span class="toolbar-icon italic">I</span>
        </button>
        <button
          type="button"
          class="toolbar-btn icon-only"
          :class="{ active: editor?.isActive('underline') }"
          @click="editor?.chain().focus().toggleUnderline().run()"
          title="Underline"
        >
          <span class="toolbar-icon underline">U</span>
        </button>
      </div>

      <div class="toolbar-group">
        <button
          type="button"
          class="toolbar-btn text-pill"
          :class="{ active: editor?.isActive('heading', { level: 2 }) }"
          @click="setHeading(2)"
          title="Heading 2"
        >
          H2
        </button>
        <button
          type="button"
          class="toolbar-btn text-pill"
          :class="{ active: editor?.isActive('heading', { level: 3 }) }"
          @click="setHeading(3)"
          title="Heading 3"
        >
          H3
        </button>
      </div>

      <div class="toolbar-group">
        <button
          type="button"
          class="toolbar-btn icon-only"
          :class="{ active: editor?.isActive('bulletList') }"
          @click="editor?.chain().focus().toggleBulletList().run()"
          title="Bullet list"
        >
          <svg viewBox="0 0 24 24" class="toolbar-svg">
            <circle cx="6" cy="7" r="1.5" />
            <circle cx="6" cy="12" r="1.5" />
            <circle cx="6" cy="17" r="1.5" />
            <path d="M11 7h7M11 12h7M11 17h7" stroke-width="1.5" stroke-linecap="round" />
          </svg>
        </button>
        <button
          type="button"
          class="toolbar-btn icon-only"
          :class="{ active: editor?.isActive('orderedList') }"
          @click="editor?.chain().focus().toggleOrderedList().run()"
          title="Numbered list"
        >
          <svg viewBox="0 0 24 24" class="toolbar-svg">
            <text x="4" y="9" font-size="7" font-weight="600">1.</text>
            <text x="4" y="15" font-size="7" font-weight="600">2.</text>
            <text x="4" y="21" font-size="7" font-weight="600">3.</text>
            <path d="M11 7h7M11 13h7M11 19h7" stroke-width="1.5" stroke-linecap="round" />
          </svg>
        </button>
      </div>

      <div class="toolbar-group table-tools">
        <button type="button" class="toolbar-btn icon-only" @click="insertTable" title="Insert table">
          <svg viewBox="0 0 24 24" class="toolbar-svg">
            <rect x="5" y="5" width="14" height="14" rx="2" />
            <path d="M5 11h14M5 17h14M11 5v14M17 5v14" stroke-width="1.2" stroke-linecap="round" />
          </svg>
        </button>
        <button type="button" class="toolbar-btn icon-only" @click="addColumn" title="Add column">
          <svg viewBox="0 0 24 24" class="toolbar-svg">
            <path d="M12 5v14M7 12h10" stroke-width="1.8" stroke-linecap="round" />
            <rect x="5" y="5" width="14" height="14" rx="2" stroke-width="1.2" />
          </svg>
        </button>
        <button type="button" class="toolbar-btn icon-only" @click="addRow" title="Add row">
          <svg viewBox="0 0 24 24" class="toolbar-svg">
            <path d="M12 5v14M5 12h14" stroke-width="1.8" stroke-linecap="round" />
            <rect x="5" y="5" width="14" height="14" rx="2" stroke-width="1.2" />
          </svg>
        </button>
        <button type="button" class="toolbar-btn icon-only" @click="deleteColumn" title="Delete column">
          <svg viewBox="0 0 24 24" class="toolbar-svg">
            <path d="M12 5v14" stroke-width="1.8" stroke-linecap="round" />
            <path d="M9 9l6 6M15 9l-6 6" stroke-width="1.5" stroke-linecap="round" />
          </svg>
        </button>
        <button type="button" class="toolbar-btn icon-only" @click="deleteRow" title="Delete row">
          <svg viewBox="0 0 24 24" class="toolbar-svg">
            <path d="M5 12h14" stroke-width="1.8" stroke-linecap="round" />
            <path d="M9 9l6 6M15 9l-6 6" stroke-width="1.5" stroke-linecap="round" />
          </svg>
        </button>
        <button type="button" class="toolbar-btn icon-only" @click="deleteTable" title="Delete table">
          <svg viewBox="0 0 24 24" class="toolbar-svg">
            <rect x="5" y="5" width="14" height="14" rx="2" stroke-width="1.2" />
            <path d="M9 9l6 6M15 9l-6 6" stroke-width="1.5" stroke-linecap="round" />
          </svg>
        </button>
      </div>

      <div class="toolbar-group">
        <button type="button" class="toolbar-btn icon-only" :disabled="!canUndo" @click="editor?.chain().focus().undo().run()" title="Undo">
          <svg viewBox="0 0 24 24" class="toolbar-svg">
            <path d="M9 7l-4 4 4 4" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" />
            <path d="M5 11h7a5 5 0 015 5v1" stroke-width="1.6" stroke-linecap="round" />
          </svg>
        </button>
        <button type="button" class="toolbar-btn icon-only" :disabled="!canRedo" @click="editor?.chain().focus().redo().run()" title="Redo">
          <svg viewBox="0 0 24 24" class="toolbar-svg">
            <path d="M15 7l4 4-4 4" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" />
            <path d="M19 11h-7a5 5 0 00-5 5v1" stroke-width="1.6" stroke-linecap="round" />
          </svg>
        </button>
      </div>
    </div>

    <div class="editor-shell">
      <EditorContent :editor="editor" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, watch } from 'vue'
import { EditorContent, useEditor } from '@tiptap/vue-3'
import StarterKit from '@tiptap/starter-kit'
import Table from '@tiptap/extension-table'
import TableRow from '@tiptap/extension-table-row'
import TableHeader from '@tiptap/extension-table-header'
import TableCell from '@tiptap/extension-table-cell'
import Underline from '@tiptap/extension-underline'
import TextStyle from '@tiptap/extension-text-style'
import Color from '@tiptap/extension-color'
import { createDefaultPointPolicyDoc } from '@/utils/pointPolicyDefault'

const props = defineProps<{
  modelValue: Record<string, any> | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: Record<string, any>): void
}>()

const editor = useEditor({
  extensions: [
    StarterKit.configure({
      heading: { levels: [1, 2, 3] },
      history: {},
    }),
    Underline,
    TextStyle,
    Color,
    Table.configure({
      resizable: true,
    }),
    TableRow,
    TableHeader,
    TableCell,
  ],
  content: props.modelValue ?? createDefaultPointPolicyDoc(),
  autofocus: false,
  onUpdate({ editor }) {
    emit('update:modelValue', editor.getJSON())
  },
})

watch(
  () => props.modelValue,
  (value) => {
    const instance = editor.value
    if (!instance || !value) {
      return
    }
    const current = instance.getJSON()
    if (JSON.stringify(current) !== JSON.stringify(value)) {
      instance.commands.setContent(value)
    }
  },
  { deep: true },
)

onBeforeUnmount(() => {
  editor.value?.destroy()
})

const canUndo = computed(() => editor.value?.can().undo() ?? false)
const canRedo = computed(() => editor.value?.can().redo() ?? false)

const insertTable = () => {
  editor.value?.chain().focus().insertTable({ rows: 3, cols: 2, withHeaderRow: true }).run()
}

const addColumn = () => editor.value?.chain().focus().addColumnAfter().run()
const addRow = () => editor.value?.chain().focus().addRowAfter().run()
const deleteColumn = () => editor.value?.chain().focus().deleteColumn().run()
const deleteRow = () => editor.value?.chain().focus().deleteRow().run()
const deleteTable = () => editor.value?.chain().focus().deleteTable().run()
const setHeading = (level: 1 | 2 | 3) => editor.value?.chain().focus().toggleHeading({ level }).run()
</script>

<style scoped>
@import "tailwindcss";

.editor-toolbar {
  @apply flex flex-wrap gap-2 items-center;
}

.toolbar-group {
  @apply flex items-center gap-1 rounded-full border border-gray-200 bg-gray-50 px-1 py-1 shadow-sm;
}

.toolbar-group.table-tools {
  @apply flex-wrap gap-1;
}

.toolbar-btn {
  @apply inline-flex items-center justify-center rounded-full border border-transparent bg-transparent px-3 py-1.5 text-sm font-medium text-gray-600 transition
    hover:bg-white hover:text-cyan-700 focus:outline-none focus-visible:ring-2 focus-visible:ring-cyan-400 disabled:opacity-40;
}

.toolbar-btn.active {
  @apply bg-white text-cyan-700 border-cyan-200 shadow-inner;
}

.toolbar-btn.icon-only {
  @apply h-9 w-9 p-0 text-base;
}

.toolbar-btn.text-pill {
  @apply px-3 min-w-[2.5rem];
}

.toolbar-icon {
  @apply text-base leading-none;
}

.toolbar-svg {
  width: 1.25rem;
  height: 1.25rem;
  fill: none;
  stroke: currentColor;
}

.editor-shell :deep(.ProseMirror) {
  min-height: 320px;
  padding: 1rem;
  border-radius: 0.75rem;
  background-color: #fff;
  outline: none;
}

.editor-shell {
  @apply border border-gray-200 rounded-xl bg-white shadow-sm;
}

.editor-shell :deep(.ProseMirror table) {
  border-collapse: collapse;
  width: 100%;
}

.editor-shell :deep(.ProseMirror table td),
.editor-shell :deep(.ProseMirror table th) {
  border: 1px solid #d1d5db;
  padding: 0.5rem;
  vertical-align: top;
}

.editor-shell :deep(.ProseMirror table th) {
  background-color: #f9fafb;
  font-weight: 600;
}

.editor-shell :deep(.ProseMirror p) {
  margin: 0 0 0.5rem;
}
</style>
