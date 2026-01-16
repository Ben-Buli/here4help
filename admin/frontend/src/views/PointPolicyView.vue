<template>
  <div class="p-6 space-y-6">
    <div class="flex flex-wrap items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-semibold text-gray-900">Point Policy</h1>
        <p class="text-sm text-gray-500">Manage the in-app point policy document with version history.</p>
      </div>
      <div class="flex gap-3">
        <button
          class="inline-flex items-center rounded-md bg-gray-100 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-200"
          @click="loadPolicies"
          :disabled="loading"
        >
          Refresh
        </button>
        <button
          class="inline-flex items-center rounded-md bg-cyan-600 px-4 py-2 text-sm font-medium text-white shadow hover:bg-cyan-700"
          @click="openCreateModal"
        >
          New Version
        </button>
      </div>
    </div>

    <div class="bg-white shadow-sm rounded-xl border border-gray-100 overflow-hidden">
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Title</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Updated</th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <tr v-if="loading">
              <td colspan="4" class="px-6 py-6 text-center text-gray-500">Loading...</td>
            </tr>
            <tr v-else-if="policies.length === 0">
              <td colspan="4" class="px-6 py-6 text-center text-gray-500">No policy versions found.</td>
            </tr>
            <tr v-for="policy in policies" :key="policy.id" class="hover:bg-gray-50">
              <td class="px-6 py-4 text-sm font-medium text-gray-900">{{ policy.title }}</td>
              <td class="px-6 py-4">
                <span
                  class="inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold"
                  :class="policy.is_active ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'"
                >
                  {{ policy.is_active ? 'Active' : 'Archived' }}
                </span>
              </td>
              <td class="px-6 py-4 text-sm text-gray-500">
                {{ formatDate(policy.updated_at) }}
              </td>
              <td class="px-6 py-4 text-right text-sm font-medium space-x-2">
                <button
                  class="inline-flex items-center rounded-md bg-teal-600 px-4 py-2 text-sm font-medium text-white shadow hover:bg-teal-700 cursor-pointer"
                  @click="openEditModal(policy)"
                >
                  Edit
                </button>
                <button
                  class="text-gray-500 hover:text-gray-800"
                  v-if="!policy.is_active"
                  @click="activatePolicy(policy)"
                >
                  Set Active
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <transition name="fade">
      <div
        v-if="showEditor"
        class="fixed inset-0 z-50 flex items-start justify-center bg-black/40 px-4 py-8 overflow-y-auto"
      >
        <div class="w-full max-w-4xl rounded-2xl bg-white shadow-xl">
          <div class="flex items-center justify-between border-b border-gray-100 px-6 py-4">
            <div>
              <h2 class="text-lg font-semibold text-gray-900">
                {{ editingPolicy ? 'Edit Point Policy' : 'Create Point Policy' }}
              </h2>
              <p class="text-sm text-gray-500">Update the document content and publish when ready.</p>
            </div>
            <button class="text-gray-400 hover:text-gray-600" @click="closeEditor">
              <span class="sr-only">Close</span>
              ✕
            </button>
          </div>

          <div class="px-6 py-5 space-y-5">
            <div>
              <label class="block text-sm font-medium text-gray-700">Title</label>
              <input
                v-model="form.title"
                type="text"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-cyan-500 focus:ring-cyan-500 px-2"
              />
            </div>

            <div class="flex items-center gap-3">
              <input id="policy-active" type="checkbox" v-model="form.is_active" class="h-4 w-4 text-cyan-600 border-gray-300 rounded" />
              <label for="policy-active" class="text-sm text-gray-700">Set this version as active</label>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Document content</label>
              <PointPolicyEditor v-model="form.content" />
            </div>

            <div class="flex items-center justify-end gap-3 border-t border-gray-100 pt-4">
              <button class="px-4 py-2 text-sm font-medium text-gray-600 hover:text-gray-900" @click="closeEditor" :disabled="saving">
                Cancel
              </button>
              <button
                class="inline-flex items-center rounded-md bg-cyan-600 px-5 py-2 text-sm font-semibold text-white shadow hover:bg-cyan-700 disabled:opacity-50"
                @click="savePolicy"
                :disabled="saving"
              >
                {{ saving ? 'Saving...' : editingPolicy ? 'Update Policy' : 'Create Policy' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from 'vue'
import { onBeforeRouteLeave } from 'vue-router'
import api, { type ApiResponse } from '@/services/api'
import { API_ENDPOINTS } from '@/config/api'
import PointPolicyEditor from '@/components/content/PointPolicyEditor.vue'
import { createDefaultPointPolicyDoc } from '@/utils/pointPolicyDefault'

interface PointPolicySummary {
  id: number
  title: string
  is_active: boolean
  created_at: string
  updated_at: string
}

interface PointPolicyDetail extends PointPolicySummary {
  content: Record<string, any>
}

const policies = ref<PointPolicySummary[]>([])
const loading = ref(false)
const saving = ref(false)
const showEditor = ref(false)
const editingPolicy = ref<PointPolicySummary | null>(null)

const cloneDoc = (doc: Record<string, any>) => JSON.parse(JSON.stringify(doc))

const form = reactive({
  title: 'Point Policy',
  content: cloneDoc(createDefaultPointPolicyDoc()),
  is_active: false,
})

const serializeFormState = () =>
  JSON.stringify({
    title: form.title,
    content: form.content,
    is_active: form.is_active,
  })

const initialSnapshot = ref(serializeFormState())

const loadPolicies = async () => {
  try {
    loading.value = true
    const response = await api.get<ApiResponse<PointPolicySummary[]>>(API_ENDPOINTS.pointPolicy.list())
    policies.value = response.data.data ?? []
  } catch (error) {
    console.error('Failed to load point policies', error)
    alert('Failed to load point policies')
  } finally {
    loading.value = false
  }
}

const resetForm = () => {
  form.title = 'Point Policy'
  form.content = cloneDoc(createDefaultPointPolicyDoc())
  form.is_active = policies.value.length === 0
  initialSnapshot.value = serializeFormState()
}

const openCreateModal = () => {
  editingPolicy.value = null
  resetForm()
  showEditor.value = true
}

const openEditModal = async (policy: PointPolicySummary) => {
  try {
    const response = await api.get<ApiResponse<PointPolicyDetail>>(API_ENDPOINTS.pointPolicy.detail(policy.id))
    const data = response.data.data
    if (data) {
      editingPolicy.value = policy
      form.title = data.title
      form.content = cloneDoc(data.content ?? createDefaultPointPolicyDoc())
      form.is_active = data.is_active
      initialSnapshot.value = serializeFormState()
      showEditor.value = true
    }
  } catch (error) {
    console.error('Failed to load policy detail', error)
    alert('Failed to load policy detail')
  }
}

const isDirty = computed(() => showEditor.value && serializeFormState() !== initialSnapshot.value)

const closeEditor = () => {
  if (isDirty.value) {
    const leave = confirm('You have unsaved changes. Close without saving?')
    if (!leave) {
      return
    }
  }
  showEditor.value = false
}

const savePolicy = async () => {
  try {
    saving.value = true
    const payload = {
      title: form.title.trim(),
      content: cloneDoc(form.content),
      is_active: form.is_active,
    }

    if (!payload.title) {
      alert('Title is required')
      return
    }

    if (editingPolicy.value) {
      await api.put<ApiResponse>(API_ENDPOINTS.pointPolicy.detail(editingPolicy.value.id), payload)
    } else {
      await api.post<ApiResponse>(API_ENDPOINTS.pointPolicy.list(), payload)
    }

    await loadPolicies()
    initialSnapshot.value = serializeFormState()
    showEditor.value = false
  } catch (error) {
    console.error('Failed to save point policy', error)
    alert('Failed to save point policy')
  } finally {
    saving.value = false
  }
}

const activatePolicy = async (policy: PointPolicySummary) => {
  if (!confirm(`Activate "${policy.title}" as the current policy?`)) {
    return
  }

  try {
    await api.post<ApiResponse>(API_ENDPOINTS.pointPolicy.activate(policy.id))
    await loadPolicies()
  } catch (error) {
    console.error('Failed to activate policy', error)
    alert('Failed to activate policy')
  }
}

const formatDate = (value: string) => {
  if (!value) return '-'
  return new Date(value).toLocaleString()
}

onMounted(() => {
  loadPolicies()
})

const handleBeforeUnload = (event: BeforeUnloadEvent) => {
  event.preventDefault()
  event.returnValue = 'You have unsaved changes. Leave without saving?'
}

watch(
  isDirty,
  (dirty) => {
    if (dirty) {
      window.addEventListener('beforeunload', handleBeforeUnload)
    } else {
      window.removeEventListener('beforeunload', handleBeforeUnload)
    }
  },
  { immediate: true },
)

onBeforeUnmount(() => {
  window.removeEventListener('beforeunload', handleBeforeUnload)
})

onBeforeRouteLeave((_to, _from, next) => {
  if (isDirty.value && !confirm('You have unsaved changes. Leave without saving?')) {
    next(false)
  } else {
    next()
  }
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
