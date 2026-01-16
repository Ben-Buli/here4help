<template>
  <div class="color-picker" ref="containerRef">
    <button
      type="button"
      class="color-trigger"
      :class="{ active: isOpen }"
      @click="toggleOpen"
      title="文字顏色"
    >
      <svg viewBox="0 0 24 24" class="color-icon" fill="none">
        <path d="M12 3L4 21h4l1.5-4h5l1.5 4h4L12 3z" stroke="currentColor" stroke-width="2" stroke-linejoin="round" />
        <line x1="8" y1="14" x2="16" y2="14" stroke="currentColor" stroke-width="2" />
      </svg>
      <span class="color-indicator" :style="{ backgroundColor: currentColor || '#000000' }"></span>
    </button>

    <Transition name="fade">
      <div v-if="isOpen" class="color-dropdown">
        <div class="color-grid">
          <button
            v-for="color in colors"
            :key="color"
            type="button"
            class="color-swatch"
            :class="{ selected: currentColor === color }"
            :style="{ backgroundColor: color }"
            @click="selectColor(color)"
            :title="color"
          >
            <svg v-if="currentColor === color" viewBox="0 0 24 24" class="check-icon">
              <path d="M5 12l5 5L20 7" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" fill="none" />
            </svg>
          </button>
        </div>
        <button type="button" class="reset-btn" @click="resetColor">
          移除顏色
        </button>
      </div>
    </Transition>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { DEFAULT_COLOR_PRESETS } from './types'

const props = withDefaults(defineProps<{
  modelValue?: string | null
  presets?: string[]
}>(), {
  presets: () => DEFAULT_COLOR_PRESETS,
})

const emit = defineEmits<{
  (e: 'update:modelValue', value: string | null): void
  (e: 'select', color: string | null): void
}>()

const isOpen = ref(false)
const containerRef = ref<HTMLElement | null>(null)
const currentColor = ref<string | null>(props.modelValue ?? null)

const colors = props.presets

const toggleOpen = () => {
  isOpen.value = !isOpen.value
}

const selectColor = (color: string) => {
  currentColor.value = color
  emit('update:modelValue', color)
  emit('select', color)
  isOpen.value = false
}

const resetColor = () => {
  currentColor.value = null
  emit('update:modelValue', null)
  emit('select', null)
  isOpen.value = false
}

const handleClickOutside = (event: MouseEvent) => {
  if (containerRef.value && !containerRef.value.contains(event.target as Node)) {
    isOpen.value = false
  }
}

onMounted(() => {
  document.addEventListener('click', handleClickOutside)
})

onBeforeUnmount(() => {
  document.removeEventListener('click', handleClickOutside)
})
</script>

<style scoped>
.color-picker {
  position: relative;
}

.color-trigger {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 2rem;
  height: 2rem;
  padding: 0.25rem;
  background: transparent;
  border: none;
  border-radius: 0.375rem;
  cursor: pointer;
  transition: all 0.15s ease;
}

.color-trigger:hover {
  background-color: #f3f4f6;
}

.color-trigger.active {
  background-color: #ecfeff;
}

.color-icon {
  width: 1rem;
  height: 1rem;
  color: #4b5563;
}

.color-indicator {
  width: 1rem;
  height: 3px;
  border-radius: 1px;
  margin-top: 1px;
}

.color-dropdown {
  position: absolute;
  top: 100%;
  left: 50%;
  transform: translateX(-50%);
  margin-top: 0.5rem;
  padding: 0.5rem;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1);
  z-index: 50;
}

.color-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 0.25rem;
  margin-bottom: 0.5rem;
}

.color-swatch {
  width: 1.5rem;
  height: 1.5rem;
  border: 2px solid transparent;
  border-radius: 0.25rem;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.15s ease;
}

.color-swatch:hover {
  transform: scale(1.1);
}

.color-swatch.selected {
  border-color: #0891b2;
  box-shadow: 0 0 0 2px rgba(8, 145, 178, 0.3);
}

.check-icon {
  width: 0.875rem;
  height: 0.875rem;
}

.reset-btn {
  width: 100%;
  padding: 0.375rem 0.5rem;
  font-size: 0.75rem;
  color: #6b7280;
  background: #f3f4f6;
  border: none;
  border-radius: 0.25rem;
  cursor: pointer;
  transition: all 0.15s ease;
}

.reset-btn:hover {
  background: #e5e7eb;
  color: #374151;
}

/* Transition */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.15s ease, transform 0.15s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateX(-50%) translateY(-4px);
}
</style>
