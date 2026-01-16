<template>
  <RichTextEditor
    v-model="internalValue"
    output-format="json"
    :toolbar="toolbarConfig"
    :min-height="320"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { RichTextEditor, FULL_TOOLBAR_CONFIG } from './editor'
import { createDefaultPointPolicyDoc } from '@/utils/pointPolicyDefault'

const props = defineProps<{
  modelValue: Record<string, any> | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: Record<string, any>): void
}>()

// 工具列配置
const toolbarConfig = FULL_TOOLBAR_CONFIG

// 內部值處理
const internalValue = computed({
  get() {
    return props.modelValue ?? createDefaultPointPolicyDoc()
  },
  set(value: string | Record<string, any>) {
    emit('update:modelValue', value as Record<string, any>)
  },
})
</script>
