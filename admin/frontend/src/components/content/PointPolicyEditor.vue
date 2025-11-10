<template>
  <div class="space-y-3">
    <div class="flex flex-wrap gap-2">
      <button class="toolbar-btn" :class="{ active: editor?.isActive('heading', { level: 2 }) }" @click="setHeading(2)">
        H2
      </button>
      <button class="toolbar-btn" :class="{ active: editor?.isActive('heading', { level: 3 }) }" @click="setHeading(3)">
        H3
      </button>
      <button class="toolbar-btn" :class="{ active: editor?.isActive('bold') }" @click="editor?.chain().focus().toggleBold().run()">
        Bold
      </button>
      <button class="toolbar-btn" :class="{ active: editor?.isActive('italic') }" @click="editor?.chain().focus().toggleItalic().run()">
        Italic
      </button>
      <button class="toolbar-btn" :class="{ active: editor?.isActive('underline') }" @click="editor?.chain().focus().toggleUnderline().run()">
        Underline
      </button>
      <button class="toolbar-btn" :class="{ active: editor?.isActive('bulletList') }" @click="editor?.chain().focus().toggleBulletList().run()">
        Bullet List
      </button>
      <button class="toolbar-btn" :class="{ active: editor?.isActive('orderedList') }" @click="editor?.chain().focus().toggleOrderedList().run()">
        Numbered List
      </button>
      <button class="toolbar-btn" @click="insertTable">Insert Table</button>
      <button class="toolbar-btn" @click="addColumn">+ Col</button>
      <button class="toolbar-btn" @click="addRow">+ Row</button>
      <button class="toolbar-btn" @click="deleteColumn">Del Col</button>
      <button class="toolbar-btn" @click="deleteRow">Del Row</button>
      <button class="toolbar-btn" @click="deleteTable">Delete Table</button>
      <span class="flex-1"></span>
      <button class="toolbar-btn" :disabled="!canUndo" @click="editor?.chain().focus().undo().run()">Undo</button>
      <button class="toolbar-btn" :disabled="!canRedo" @click="editor?.chain().focus().redo().run()">Redo</button>
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
      history: true,
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
    if (!editor || !value) {
      return
    }
    const current = editor.getJSON()
    if (JSON.stringify(current) !== JSON.stringify(value)) {
      editor.commands.setContent(value)
    }
  },
  { deep: true },
)

onBeforeUnmount(() => {
  editor?.destroy()
})

const canUndo = computed(() => editor?.can().undo() ?? false)
const canRedo = computed(() => editor?.can().redo() ?? false)

const insertTable = () => {
  editor?.chain().focus().insertTable({ rows: 3, cols: 2, withHeaderRow: true }).run()
}

const addColumn = () => editor?.chain().focus().addColumnAfter().run()
const addRow = () => editor?.chain().focus().addRowAfter().run()
const deleteColumn = () => editor?.chain().focus().deleteColumn().run()
const deleteRow = () => editor?.chain().focus().deleteRow().run()
const deleteTable = () => editor?.chain().focus().deleteTable().run()
const setHeading = (level: number) => editor?.chain().focus().toggleHeading({ level }).run()
</script>

<style scoped>
@import "tailwindcss";

.toolbar-btn {
  @apply px-3 py-1.5 text-sm border rounded-md bg-white hover:bg-gray-100 transition disabled:opacity-50 disabled:cursor-not-allowed;
}

.toolbar-btn.active {
  @apply bg-cyan-100 text-cyan-700 border-cyan-300;
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
