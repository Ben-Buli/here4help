<template>
  <div class="min-h-screen bg-slate-50 flex items-center justify-center py-10 px-4">
    <div class="max-w-3xl w-full">
      <div class="bg-white shadow-2xl rounded-3xl overflow-hidden border border-slate-100">
        <div class="bg-gradient-to-r from-slate-900 via-slate-800 to-slate-900 text-white p-6 sm:p-8">
          <p class="text-sm uppercase tracking-[0.3em] text-slate-300">Here4Help Admin</p>
          <h1 class="mt-3 text-3xl font-semibold">Manual Password Reset</h1>
          <p class="mt-2 text-slate-200 text-sm sm:text-base">
            為了安全，請確認這封信是我們的管理員提供且只分享給你本人。輸入符合規則的新密碼後即可登入。
          </p>
        </div>

        <div class="p-6 sm:p-8 space-y-6">
          <div v-if="linkInvalid" class="rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
            這個連結缺少必要參數或已失效，請聯絡客服或請管理員重新發送新的重設連結。
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium text-gray-700">重設帳號 Email</label>
            <input
              type="email"
              :value="email"
              disabled
              class="w-full rounded-2xl border border-gray-200 bg-gray-50 px-4 py-3 text-gray-600"
            />
          </div>

          <div class="grid gap-4 md:grid-cols-2">
            <div class="space-y-2">
              <label class="text-sm font-medium text-gray-700">新密碼</label>
              <div class="relative">
                <input
                  :type="showNewPassword ? 'text' : 'password'"
                  v-model="newPassword"
                  :disabled="formLocked"
                  class="w-full rounded-2xl border border-gray-200 px-4 py-3 pr-24 text-gray-900 focus:border-slate-500 focus:ring-slate-500"
                  placeholder="輸入新密碼"
                />
                <button
                  type="button"
                  class="absolute inset-y-0 right-3 text-sm font-medium text-slate-600"
                  @click="showNewPassword = !showNewPassword"
                >
                  {{ showNewPassword ? '隱藏' : '顯示' }}
                </button>
              </div>
            </div>
            <div class="space-y-2">
              <label class="text-sm font-medium text-gray-700">確認新密碼</label>
              <div class="relative">
                <input
                  :type="showConfirmPassword ? 'text' : 'password'"
                  v-model="confirmPassword"
                  :disabled="formLocked"
                  class="w-full rounded-2xl border border-gray-200 px-4 py-3 pr-24 text-gray-900 focus:border-slate-500 focus:ring-slate-500"
                  placeholder="再次輸入新密碼"
                />
                <button
                  type="button"
                  class="absolute inset-y-0 right-3 text-sm font-medium text-slate-600"
                  @click="showConfirmPassword = !showConfirmPassword"
                >
                  {{ showConfirmPassword ? '隱藏' : '顯示' }}
                </button>
              </div>
            </div>
          </div>

          <div class="rounded-2xl border border-gray-100 bg-gray-50 p-4">
            <p class="text-sm font-medium text-gray-700">密碼需符合以下條件：</p>
            <ul class="mt-3 space-y-2 text-sm">
              <li
                v-for="rule in requirementList"
                :key="rule.key"
                class="flex items-center gap-2"
                :class="rule.met ? 'text-emerald-600' : 'text-gray-500'"
              >
                <span
                  class="inline-flex h-5 w-5 items-center justify-center rounded-full"
                  :class="rule.met ? 'bg-emerald-100' : 'bg-gray-200'"
                >
                  {{ rule.met ? '✓' : '•' }}
                </span>
                {{ rule.label }}
              </li>
            </ul>
          </div>

          <button
            type="button"
            class="w-full rounded-2xl bg-slate-900 py-3 text-white font-semibold shadow-lg shadow-slate-900/20 hover:bg-slate-800 disabled:bg-gray-300 disabled:text-gray-600"
            :disabled="disabledSubmit"
            @click="handleSubmit"
          >
            {{ isSubmitting ? '重設中…' : hasCompleted ? '已完成' : '重設密碼' }}
          </button>

          <p
            v-if="statusMessage"
            class="text-sm"
            :class="{
              'text-emerald-600': statusType === 'success',
              'text-red-600': statusType === 'error',
              'text-gray-600': statusType === 'info'
            }"
          >
            {{ statusMessage }}
          </p>

          <div class="text-xs text-gray-500 border-t border-gray-100 pt-4">
            若你未主動提出重設需求，請立即聯絡 Here4Help 客服，並勿分享此連結給他人。
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()
const token = ref<string>((route.query.token as string) || '')
const email = ref<string>((route.query.email as string) || '')
const newPassword = ref('')
const confirmPassword = ref('')
const showNewPassword = ref(false)
const showConfirmPassword = ref(false)
const isSubmitting = ref(false)
const hasCompleted = ref(false)
const statusMessage = ref('')
const statusType = ref<'info' | 'error' | 'success'>('info')

const linkInvalid = computed(() => !token.value || !email.value)
const formLocked = computed(() => hasCompleted.value || linkInvalid.value)

const requirementState = computed(() => ({
  length: newPassword.value.length >= 8,
  uppercase: /[A-Z]/.test(newPassword.value),
  lowercase: /[a-z]/.test(newPassword.value),
  number: /\d/.test(newPassword.value),
}))

const requirementList = computed(() => [
  { key: 'length', label: '至少 8 個字元', met: requirementState.value.length },
  { key: 'uppercase', label: '包含一個大寫字母', met: requirementState.value.uppercase },
  { key: 'lowercase', label: '包含一個小寫字母', met: requirementState.value.lowercase },
  { key: 'number', label: '包含一個數字', met: requirementState.value.number },
])

const allRequirementsMet = computed(() => Object.values(requirementState.value).every(Boolean))
const passwordsMatch = computed(() => newPassword.value && newPassword.value === confirmPassword.value)
const disabledSubmit = computed(() => formLocked.value || isSubmitting.value || !allRequirementsMet.value || !passwordsMatch.value)

const adminBasePath = (() => {
  if (typeof window === 'undefined') return ''
  const path = window.location.pathname || ''
  const index = path.indexOf('/admin')
  if (index === -1) return ''
  return path.slice(0, index)
})()

const buildUrl = (path: string) => {
  const prefix = adminBasePath.replace(/\/$/, '')
  const normalized = path.startsWith('/') ? path : `/${path}`
  return `${prefix}${normalized || '/'}` || '/'
}

const getCookieValue = (name: string): string | null => {
  if (typeof document === 'undefined') return null
  const cookies = document.cookie ? document.cookie.split('; ') : []
  for (const cookie of cookies) {
    if (cookie.startsWith(`${name}=`)) {
      return decodeURIComponent(cookie.split('=')[1])
    }
  }
  return null
}

const setStatus = (message: string, type: 'info' | 'error' | 'success' = 'info') => {
  statusMessage.value = message
  statusType.value = type
}

const ensureCsrf = async () => {
  try {
    await fetch(buildUrl('/sanctum/csrf-cookie'), {
      method: 'GET',
      credentials: 'include',
      headers: {
        'X-Requested-With': 'XMLHttpRequest',
      },
    })
  } catch (error) {
    console.warn('Failed to fetch CSRF cookie', error)
  }
}

const handleSubmit = async () => {
  if (formLocked.value) return

  if (linkInvalid.value) {
    setStatus('連結無效或已過期，請再向管理員索取新的重設連結。', 'error')
    return
  }

  if (!allRequirementsMet.value) {
    setStatus('請先符合所有密碼規則後再送出。', 'error')
    return
  }

  if (!passwordsMatch.value) {
    setStatus('兩次輸入的密碼不一致，請再次確認。', 'error')
    return
  }

  isSubmitting.value = true
  setStatus('')

  try {
    await ensureCsrf()
    const xsrfToken = getCookieValue('XSRF-TOKEN')

    const response = await fetch(buildUrl('/admin/reset-password'), {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        ...(xsrfToken ? { 'X-XSRF-TOKEN': xsrfToken } : {}),
      },
      body: JSON.stringify({
        token: token.value,
        email: email.value,
        new_password: newPassword.value,
        confirm_password: confirmPassword.value,
      }),
    })

    const result = await response.json().catch(() => null)

    if (!response.ok || !result?.success) {
      throw new Error(result?.message || '目前無法重設密碼，請稍後再試。')
    }

    hasCompleted.value = true
    setStatus(result.message || '密碼重設成功，請使用新密碼登入。', 'success')
  } catch (error: any) {
    setStatus(error?.message || '系統發生錯誤，請稍後再試。', 'error')
  } finally {
    isSubmitting.value = false
  }
}
</script>
