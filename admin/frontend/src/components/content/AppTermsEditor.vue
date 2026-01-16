<template>
  <RichTextEditor
    v-model="internalValue"
    output-format="html"
    :toolbar="toolbarConfig"
    :min-height="360"
    :readonly="readonly"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { RichTextEditor, SIMPLE_TOOLBAR_CONFIG } from './editor'

const props = withDefaults(defineProps<{
  modelValue: string
  readonly?: boolean
}>(), {
  readonly: false,
})

const emit = defineEmits<{
  (e: 'update:modelValue', value: string): void
}>()

// 工具列配置
const toolbarConfig = SIMPLE_TOOLBAR_CONFIG

// 內部值處理
const internalValue = computed({
  get() {
    return props.modelValue || '<p></p>'
  },
  set(value: string | Record<string, any>) {
    emit('update:modelValue', value as string)
  },
})
</script>
