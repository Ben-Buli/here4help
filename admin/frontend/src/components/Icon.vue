<template>
  <svg 
    :class="className" 
    fill="none" 
    stroke="currentColor" 
    viewBox="0 0 24 24" 
    xmlns="http://www.w3.org/2000/svg"
  >
    <!-- Report Problem -->
    <path 
      v-if="name === 'report-problem'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.464 0L4.34 16.5c-.77.833.192 2.5 1.732 2.5z"
    />
    
    <!-- Clock -->
    <path 
      v-else-if="name === 'clock'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
    />
    
    <!-- Progress -->
    <path 
      v-else-if="name === 'progress'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M13 10V3L4 14h7v7l9-11h-7z"
    />
    
    <!-- Check Circle -->
    <path 
      v-else-if="name === 'check-circle'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
    />
    
    <!-- Trending Up -->
    <path 
      v-else-if="name === 'trending-up'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"
    />
    
    <!-- Loading -->
    <path 
      v-else-if="name === 'loading'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
    />
    
    <!-- Inbox -->
    <path 
      v-else-if="name === 'inbox'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0l-3.5-7-9 0L4 13"
    />
    
    <!-- Chat -->
    <path 
      v-else-if="name === 'chat'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
    />
    
    <!-- Gavel -->
    <path 
      v-else-if="name === 'gavel'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M3 6l3 1m0 0l-3 9a5.002 5.002 0 006.001 0M6 7l3 9M6 7l6-2m6 2l3-1m-3 1l-3 9a5.002 5.002 0 006.001 0M18 7l3 9m-3-9l-6-2m0-2v2m0 16V5m0 16H9m3 0h3"
    />
    
    <!-- Eye -->
    <path 
      v-else-if="name === 'eye'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
    />
    
    <!-- Chevron Left -->
    <path 
      v-else-if="name === 'chevron-left'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M15 19l-7-7 7-7"
    />
    
    <!-- Chevron Right -->
    <path 
      v-else-if="name === 'chevron-right'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M9 5l7 7-7 7"
    />
    
    <!-- Chevron Down -->
    <path 
      v-else-if="name === 'chevron-down'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M19 9l-7 7-7-7"
    />
    
    <!-- Document Text -->
    <path 
      v-else-if="name === 'document-text'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
    />
    
    <!-- Question Mark Circle -->
    <path 
      v-else-if="name === 'question-mark-circle'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
    />
    
    <!-- X Mark -->
    <path 
      v-else-if="name === 'x-mark'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M6 18L18 6M6 6l12 12"
    />
    
    <!-- Arrow Left -->
    <path 
      v-else-if="name === 'arrow-left'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M10 19l-7-7m0 0l7-7m-7 7h18"
    />
    
    <!-- Exclamation Triangle -->
    <path 
      v-else-if="name === 'exclamation-triangle'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.464 0L4.34 16.5c-.77.833.192 2.5 1.732 2.5z"
    />
    
    <!-- Chat Bubble -->
    <path 
      v-else-if="name === 'chat-bubble'" 
      stroke-linecap="round" 
      stroke-linejoin="round" 
      stroke-width="2" 
      d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
    />
    
    <!-- Default fallback -->
    <circle v-else cx="12" cy="12" r="10"/>
  </svg>
</template>

<script setup lang="ts">
interface Props {
  name: string
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  class: 'w-5 h-5'
})

const className = props.class
</script>
