<template>
  <div class="space-y-4">
    <div class="editor-toolbar">
      <div class="toolbar-group">
        <button type="button" class="toolbar-btn icon-only" :class="{ active: editor?.isActive('bold') }" @click="exec('toggleBold')" title="Bold">
          <span class="toolbar-icon font-semibold">B</span>
        </button>
        <button type="button" class="toolbar-btn icon-only" :class="{ active: editor?.isActive('italic') }" @click="exec('toggleItalic')" title="Italic">
          <span class="toolbar-icon italic">I</span>
        </button>
        <button type="button" class="toolbar-btn icon-only" :class="{ active: editor?.isActive('underline') }" @click="exec('toggleUnderline')" title="Underline">
          <span class="toolbar-icon underline">U</span>
        </button>
      </div>

      <div class="toolbar-group">
        <button type="button" class="toolbar-btn text-pill" :class="{ active: editor?.isActive('heading', { level: 1 }) }" @click="setHeading(1)">H1</button>
        <button type="button" class="toolbar-btn text-pill" :class="{ active: editor?.isActive('heading', { level: 2 }) }" @click="setHeading(2)">H2</button>
        <button type="button" class="toolbar-btn text-pill" :class="{ active: editor?.isActive('heading', { level: 3 }) }" @click="setHeading(3)">H3</button>
        <button type="button" class="toolbar-btn text-pill" :class="{ active: editor?.isActive('heading', { level: 4 }) }" @click="setHeading(4)">H4</button>
        <button type="button" class="toolbar-btn text-pill" :class="{ active: editor?.isActive('paragraph') }" @click="setParagraph">Normal</button>
      </div>

      <!-- <div class="toolbar-group">
        <button type="button" class="toolbar-btn icon-only" :class="{ active: editor?.isActive('bulletList') }" @click="editor?.chain().focus().toggleBulletList().run()" title="Bulleted list">
          <svg viewBox="0 0 24 24" class="toolbar-svg">
            <circle cx="6" cy="7" r="1.5" />
            <circle cx="6" cy="12" r="1.5" />
            <circle cx="6" cy="17" r="1.5" />
            <path d="M11 7h7M11 12h7M11 17h7" stroke-width="1.5" stroke-linecap="round" />
          </svg>
        </button>
        <button type="button" class="toolbar-btn icon-only" :class="{ active: editor?.isActive('orderedList') }" @click="editor?.chain().focus().toggleOrderedList().run()" title="Numbered list">
          <svg viewBox="0 0 24 24" class="toolbar-svg">
            <text x="4" y="9" font-size="7" font-weight="600">1.</text>
            <text x="4" y="15" font-size="7" font-weight="600">2.</text>
            <path d="M11 7h7M11 13h7M11 19h7" stroke-width="1.5" stroke-linecap="round" />
          </svg>
        </button>
      </div> -->

      <div class="toolbar-group">
        <button type="button" class="toolbar-btn icon-only" @click="exec('undo')" :disabled="!canUndo" title="Undo">
          <svg class="toolbar-svg" viewBox="0 0 24 24">
            <path d="M9 7l-4 4 4 4" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" />
            <path d="M5 11h7a5 5 0 015 5v1" stroke-width="1.6" stroke-linecap="round" />
          </svg>
        </button>
        <button type="button" class="toolbar-btn icon-only" @click="exec('redo')" :disabled="!canRedo" title="Redo">
          <svg class="toolbar-svg" viewBox="0 0 24 24">
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
import Underline from '@tiptap/extension-underline'

const props = defineProps<{
  modelValue: string
  readonly?: boolean
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: string): void
}>()

const editor = useEditor({
  extensions: [
    StarterKit.configure({
      heading: { levels: [1, 2, 3, 4] },
      history: {},
    }),
    Underline,
  ],
  content: props.modelValue || '<p></p>',
  editable: props.readonly !== true,
  autofocus: false,
  onUpdate({ editor }) {
    emit('update:modelValue', editor.getHTML())
  },
})

watch(
  () => props.modelValue,
  (value) => {
    const instance = editor.value
    if (!instance || value === undefined) return
    const current = instance.getHTML()
    if (current !== value) {
      instance.commands.setContent(value || '<p></p>', false)
    }
  },
)

watch(
  () => props.readonly,
  (value) => {
    editor.value?.setOptions({ editable: value !== true })
  },
)

const exec = (action: 'toggleBold' | 'toggleItalic' | 'toggleUnderline' | 'toggleBulletList' | 'toggleOrderedList' | 'undo' | 'redo') => {
  if (!editor.value) return
  switch (action) {
    case 'toggleBold':
      editor.value.chain().focus().toggleBold().run()
      break
    case 'toggleItalic':
      editor.value.chain().focus().toggleItalic().run()
      break
    case 'toggleUnderline':
      editor.value.chain().focus().toggleUnderline().run()
      break
    case 'toggleBulletList':
      editor.value.chain().focus().toggleBulletList().run()
      break
    case 'toggleOrderedList':
      editor.value.chain().focus().toggleOrderedList().run()
      break
    case 'undo':
      editor.value.chain().focus().undo().run()
      break
    case 'redo':
      editor.value.chain().focus().redo().run()
      break
  }
}

const setHeading = (level: 1 | 2 | 3 | 4) => {
  editor.value?.chain().focus().toggleHeading({ level }).run()
}

const setParagraph = () => {
  editor.value?.chain().focus().setParagraph().run()
}

const canUndo = computed(() => editor.value?.can().undo() ?? false)
const canRedo = computed(() => editor.value?.can().redo() ?? false)

onBeforeUnmount(() => {
  editor.value?.destroy()
})
</script>

<style scoped>
@import "tailwindcss";

.editor-toolbar {
  @apply flex flex-wrap gap-2 items-center;
}

.toolbar-group {
  @apply flex items-center gap-1 rounded-full border border-gray-200 bg-gray-50 px-1 py-1 shadow-sm;
}

.toolbar-btn {
  @apply inline-flex items-center justify-center rounded-full border border-transparent bg-transparent px-3 py-1.5 text-sm font-medium text-gray-600 transition
    hover:bg-white hover:text-cyan-700 focus:outline-none focus-visible:ring-2 focus-visible:ring-cyan-400 disabled:opacity-40;
}

.toolbar-btn.icon-only {
  @apply h-9 w-9 p-0 text-base;
}

.toolbar-btn.text-pill {
  @apply px-3 min-w-[2.5rem];
}

.toolbar-btn.active {
  @apply bg-white text-cyan-700 border-cyan-200 shadow-inner;
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
  min-height: 360px;
  padding: 1rem;
  border-radius: 0.75rem;
  background-color: #fff;
  outline: none;
}

.editor-shell {
  @apply border border-gray-200 rounded-xl bg-white shadow-sm;
}
</style>

