<template>
  <div class="min-h-screen bg-gray-50">
    <!-- 側邊欄 -->
    <div
      class="fixed inset-y-0 left-0 z-50 w-64 bg-white shadow-lg transform transition-transform duration-300 ease-in-out lg:translate-x-0"
      :class="{ '-translate-x-full': !sidebarOpen }"
    >
      <!-- 側邊欄標題 -->
      <div class="flex items-center justify-between h-16 px-6 bg-primary-600">
        <div class="flex items-center">
          <div class="flex-shrink-0 w-8 h-8 bg-white rounded-lg flex items-center justify-center">
            <span class="text-primary-600 font-bold text-lg">H4H</span>
          </div>
          <span class="ml-3 text-white font-semibold">Admin Panel</span>
        </div>
        <button @click="sidebarOpen = false" class="lg:hidden text-white hover:text-gray-200">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M6 18L18 6M6 6l12 12"
            />
          </svg>
        </button>
      </div>

      <!-- 導航選單 -->
      <nav class="mt-8 px-4 space-y-2">
        <router-link
          v-for="item in navigation"
          :key="item.name"
          :to="item.href"
          class="group flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors duration-200"
          :class="[
            $route.path === item.href || $route.path.startsWith(item.href + '/')
              ? 'bg-primary-100 text-primary-700 border-r-2 border-primary-500'
              : 'text-gray-700 hover:bg-gray-100 hover:text-gray-900',
          ]"
          @click="sidebarOpen = false"
        >
          <component
            :is="item.icon"
            class="mr-3 h-5 w-5 flex-shrink-0"
            :class="[
              $route.path === item.href || $route.path.startsWith(item.href + '/')
                ? 'text-primary-500'
                : 'text-gray-400 group-hover:text-gray-500',
            ]"
          />
          {{ item.name }}
        </router-link>
      </nav>

      <!-- 用戶資訊 -->
      <div class="absolute bottom-0 left-0 right-0 p-4 border-t border-gray-200">
        <div class="flex items-center">
          <div
            class="flex-shrink-0 w-8 h-8 bg-primary-100 rounded-full flex items-center justify-center"
          >
            <span class="text-primary-600 font-medium text-sm">
              {{ authStore.userDisplayName.charAt(0).toUpperCase() }}
            </span>
          </div>
          <div class="ml-3 flex-1 min-w-0">
            <p class="text-sm font-medium text-gray-900 truncate">
              {{ authStore.userDisplayName }}
            </p>
            <p class="text-xs text-gray-500 truncate">
              {{ authStore.userRole }}
            </p>
          </div>
        </div>
      </div>
    </div>

    <!-- 主要內容區域 -->
    <div class="lg:pl-64">
      <!-- 頂部導航欄 -->
      <div class="sticky top-0 z-40 flex h-16 bg-white shadow-sm border-b border-gray-200">
        <button
          @click="sidebarOpen = true"
          class="px-4 text-gray-500 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-primary-500 lg:hidden"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M4 6h16M4 12h16M4 18h16"
            />
          </svg>
        </button>

        <div class="flex-1 flex justify-between items-center px-4 sm:px-6 lg:px-8">
          <div class="flex-1">
            <!-- 麵包屑導航 -->
            <nav class="flex" aria-label="Breadcrumb">
              <ol class="flex items-center space-x-4">
                <li>
                  <div>
                    <router-link to="/dashboard" class="text-gray-400 hover:text-gray-500">
                      <svg class="flex-shrink-0 h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                        <path
                          d="M10.707 2.293a1 1 0 00-1.414 0l-7 7a1 1 0 001.414 1.414L4 10.414V17a1 1 0 001 1h2a1 1 0 001-1v-2a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 001 1h2a1 1 0 001-1v-6.586l.293.293a1 1 0 001.414-1.414l-7-7z"
                        />
                      </svg>
                    </router-link>
                  </div>
                </li>
                <li v-if="$route.meta.title">
                  <div class="flex items-center">
                    <svg
                      class="flex-shrink-0 h-5 w-5 text-gray-300"
                      fill="currentColor"
                      viewBox="0 0 20 20"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z"
                        clip-rule="evenodd"
                      />
                    </svg>
                    <span class="ml-4 text-sm font-medium text-gray-500">
                      {{ $route.meta.title }}
                    </span>
                  </div>
                </li>
              </ol>
            </nav>
          </div>

          <div class="flex items-center space-x-4">
            <!-- 通知按鈕 -->
            <button
              class="p-1 rounded-full text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
            >
              <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M15 17h5l-5 5v-5zM11 17H6l5 5v-5z"
                />
              </svg>
            </button>

            <!-- 用戶選單 -->
            <div class="relative">
              <button
                @click="userMenuOpen = !userMenuOpen"
                class="flex items-center text-sm rounded-full focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
              >
                <div class="w-8 h-8 bg-primary-100 rounded-full flex items-center justify-center">
                  <span class="text-primary-600 font-medium text-sm">
                    {{ authStore.userDisplayName.charAt(0).toUpperCase() }}
                  </span>
                </div>
              </button>

              <!-- 下拉選單 -->
              <div
                v-show="userMenuOpen"
                @click.away="userMenuOpen = false"
                class="origin-top-right absolute right-0 mt-2 w-48 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 focus:outline-none z-50"
              >
                <div class="py-1">
                  <div class="px-4 py-2 text-sm text-gray-700 border-b border-gray-200">
                    <p class="font-medium">{{ authStore.userDisplayName }}</p>
                    <p class="text-xs text-gray-500">{{ authStore.user?.email }}</p>
                  </div>
                  <button
                    @click="handleLogout"
                    class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                  >
                    Sign out
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 頁面內容 -->
      <main class="flex-1 p-6">
        <router-view />
      </main>
    </div>

    <!-- 側邊欄遮罩 (手機版) -->
    <div
      v-show="sidebarOpen"
      @click="sidebarOpen = false"
      class="fixed inset-0 z-40 bg-gray-600 bg-opacity-75 lg:hidden"
    ></div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

// Icons (using heroicons)
const HomeIcon = 'svg'
const UsersIcon = 'svg'
const ClipboardListIcon = 'svg'
const DocumentTextIcon = 'svg'
const CogIcon = 'svg'

const router = useRouter()
const authStore = useAuthStore()

const sidebarOpen = ref(false)
const userMenuOpen = ref(false)

const navigation = [
  { name: 'Dashboard', href: '/dashboard', icon: HomeIcon },
  { name: 'Users', href: '/users', icon: UsersIcon },
  { name: 'Tasks', href: '/tasks', icon: ClipboardListIcon },
  { name: 'Logs', href: '/logs', icon: DocumentTextIcon },
  { name: 'Settings', href: '/settings', icon: CogIcon },
]

const handleLogout = async () => {
  await authStore.logout()
  router.push('/login')
}
</script>

<style scoped>
/* 點擊外部關閉選單的指令 */
</style>
