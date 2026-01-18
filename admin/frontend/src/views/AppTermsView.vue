<template>
    <div class="flex items-center justify-between flex-wrap gap-4">
      <div>
        <h1 class="text-2xl font-semibold text-gray-900">App Terms of Use</h1>
        <p class="text-sm text-gray-500">Manage published terms versions for the Here4Help app.</p>
      </div>
      <button class="admin-button-secondary" @click="loadTerms" :disabled="isLoading">
        {{ isLoading ? 'Loading...' : 'Refresh' }}
      </button>
    </div>

    <div class="admin-card overflow-hidden">
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Version</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Title</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Updated</th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <tr v-if="isLoading">
              <td colspan="5" class="px-6 py-6 text-center text-gray-500">Loading terms...</td>
            </tr>
            <tr v-else-if="terms.length === 0">
              <td colspan="5" class="px-6 py-6 text-center text-gray-500">No terms versions found.</td>
            </tr>
            <tr v-for="term in terms" :key="term.id" class="hover:bg-gray-50">
              <td class="px-6 py-4 text-sm text-gray-900 font-medium">v{{ term.version }}</td>
              <td class="px-6 py-4 text-sm text-gray-700">{{ term.title }}</td>
              <td class="px-6 py-4">
                <span
                  class="inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold"
                  :class="term.is_active ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'"
                >
                  {{ term.is_active ? 'Active' : 'Archived' }}
                </span>
              </td>
              <td class="px-6 py-4 text-sm text-gray-500">{{ formatDate(term.updated_at) }}</td>
              <td class="px-6 py-4 text-right text-sm font-medium space-x-2">
                <button class="admin-button-secondary !px-4 !py-1 text-sm" @click="openTerm(term.id)">Edit</button>
           
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <transition name="fade">
      <div
        v-if="showModal && selectedTerm"
        class="fixed inset-0 z-50 flex items-center justify-center px-4 bg-white/40 backdrop-blur-sm"
      >
        <div class="bg-white rounded-2xl shadow-xl max-h-[90vh] w-full max-w-4xl overflow-hidden flex flex-col">
          <div class="flex items-center justify-between px-6 py-4 border-b">
            <div>
              <h2 class="text-xl font-semibold text-gray-900">{{ selectedTerm.title }}</h2>
              <p class="text-sm text-gray-500">Version {{ selectedTerm.version }}</p>
            </div>
            <button class="text-gray-400 hover:text-gray-600" @click="closeModal">✕</button>
          </div>
          <div class="px-6 py-4 overflow-y-auto flex-1 space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Title</label>
              <input
                v-model="modalForm.title"
                type="text"
                :maxlength="TITLE_LIMIT"
                :class="[
                  'block w-full rounded-lg px-3 py-2 focus-visible:outline-none',
                  titleLimitReached
                    ? 'border-red-500 focus:border-red-500 focus:ring-red-500/40'
                    : 'border-gray-200 focus:border-cyan-500 focus:ring-cyan-500/40'
                ]"
              />
              <div class="flex justify-between text-xs mt-1" :class="titleLimitReached ? 'text-red-600' : 'text-gray-500'">
                <span>At most {{ TITLE_LIMIT }} characters</span>
                <span>{{ titleLength }} / {{ TITLE_LIMIT }}</span>
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Summary</label>
              <textarea
                v-model="modalForm.summary"
                rows="2"
                :maxlength="SUMMARY_LIMIT"
                :class="[
                  'block w-full rounded-lg px-3 py-2 focus-visible:outline-none',
                  summaryLimitReached
                    ? 'border-red-500 focus:border-red-500 focus:ring-red-500/40'
                    : 'border-gray-200 focus:border-cyan-500 focus:ring-cyan-500/40'
                ]"
                placeholder="Optional description for admin reference"
              ></textarea>
              <div class="flex justify-between text-xs mt-1" :class="summaryLimitReached ? 'text-red-600' : 'text-gray-500'">
                <span>At most {{ SUMMARY_LIMIT }} characters</span>
                <span>{{ summaryLength }} / {{ SUMMARY_LIMIT }}</span>
              </div>
            </div>
            <div class="flex items-center gap-2">
              <input id="requires-ack" type="checkbox" class="rounded text-cyan-600" v-model="modalForm.requires_ack" />
              <label for="requires-ack" class="text-sm text-gray-700">Require users to re-acknowledge after publishing</label>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Terms Content</label>
              <AppTermsEditor v-model="modalForm.content" />
            </div>
          </div>
          <div class="border-t px-6 py-4 flex justify-between items-center">
            <div class="text-sm text-gray-500">
              Updated {{ formatDate(selectedTerm.updated_at) }} · Created by
              <template v-if="selectedTerm.created_by_admin">
                {{ displayAdmin(selectedTerm.created_by_admin) }}
                <!-- (ID #{{ selectedTerm.created_by_admin.id }}) -->
              </template>
              <template v-else>System</template>
            </div>
            <button class="admin-button-primary" @click="pushTerm(selectedTerm.id)" :disabled="isPushing">
              {{ isPushing ? 'Publishing...' : 'Push New Version' }}
            </button>
          </div>
        </div>
      </div>
    </transition>
</template>

<script setup lang="ts">
import { onMounted, ref, reactive, computed } from 'vue'
import { appTermsApi } from '@/services/api'
import AppTermsEditor from '@/components/content/AppTermsEditor.vue'

interface AdminInfo {
  id: number
  name?: string | null
  username?: string | null
  email?: string | null
}

interface AppTermSummary {
  id: number
  version: string
  title: string
  summary?: string | null
  is_active: boolean
  updated_at: string
  created_by_admin?: AdminInfo | null
}

interface AppTermDetail extends AppTermSummary {
  content: string
  requires_ack: boolean
}

const TITLE_LIMIT = 255
const SUMMARY_LIMIT = 500

const terms = ref<AppTermSummary[]>([])
const isLoading = ref(false)
const showModal = ref(false)
const selectedTerm = ref<AppTermDetail | null>(null)
const isPushing = ref(false)
const modalForm = reactive({
  title: '',
  summary: '',
  content: '',
  requires_ack: true,
})

const titleLength = computed(() => modalForm.title.length)
const summaryLength = computed(() => modalForm.summary.length)
const titleLimitReached = computed(() => titleLength.value >= TITLE_LIMIT)
const summaryLimitReached = computed(() => summaryLength.value >= SUMMARY_LIMIT)

const loadTerms = async () => {
  try {
    isLoading.value = true
    const response = await appTermsApi.list()
    terms.value = response.data?.data ?? []
  } catch (error) {
    console.error('Failed to load terms', error)
    alert('Failed to load terms')
  } finally {
    isLoading.value = false
  }
}

const openTerm = async (id: number) => {
  try {
    const response = await appTermsApi.detail(id)
    if (response.data?.data) {
      const data = response.data.data as AppTermDetail
      selectedTerm.value = data
      modalForm.title = data.title
      modalForm.summary = data.summary ?? ''
      modalForm.content = data.content ?? '<p></p>'
      modalForm.requires_ack = data.requires_ack ?? true
      showModal.value = true
    }
  } catch (error) {
    console.error('Failed to load term', error)
    alert('Failed to load term detail')
  }
}

const closeModal = () => {
  showModal.value = false
  selectedTerm.value = null
}

const pushTerm = async (id: number) => {
  if (!confirm('Push this version as the new active terms?')) return

  try {
    isPushing.value = true
    const response = await appTermsApi.push(id, {
      title: modalForm.title,
      summary: modalForm.summary,
      content: modalForm.content,
      requires_ack: modalForm.requires_ack,
    })
    const newTerm = response.data?.data as AppTermDetail | undefined
    await loadTerms()
    if (newTerm) {
      selectedTerm.value = newTerm
      modalForm.title = newTerm.title
      modalForm.summary = newTerm.summary ?? ''
      modalForm.content = newTerm.content ?? '<p></p>'
      modalForm.requires_ack = newTerm.requires_ack ?? true
      showModal.value = true
    } else if (showModal.value) {
      await openTerm(id)
    }
    alert('New terms version published successfully.')
  } catch (error) {
    console.error('Failed to push new terms version', error)
    alert('Failed to push new version')
  } finally {
    isPushing.value = false
  }
}

const formatDate = (value?: string | null) => {
  if (!value) return '-'
  return new Date(value).toLocaleString()
}

const displayAdmin = (admin: AdminInfo) => {
  if (admin.name && admin.name.trim().length > 0) {
    return admin.name
  }
  if (admin.username && admin.username.trim().length > 0) {
    return admin.username
  }
  return `Admin #${admin.id}`
}

onMounted(() => {
  loadTerms()
})
</script>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>

