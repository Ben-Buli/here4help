<template>
  <div class="min-h-screen bg-gray-50 flex">
    <!-- 側邊欄 -->
    <div
      class="fixed inset-y-0 left-0 z-50 w-64 bg-white shadow-lg transform transition-transform duration-300 ease-in-out flex flex-col lg:relative lg:translate-x-0 lg:z-auto"
      :class="{ '-translate-x-full': !sidebarOpen }"
    >
      <!-- 側邊欄標題 -->
      <div class="flex items-center justify-between h-16 px-6 bg-cyan-600">
        <div class="flex items-center">
          <div class="flex-shrink-0 w-8 h-8 bg-white rounded-lg flex items-center justify-center">
            <span class="text-cyan-600 font-bold text-lg">H4H</span>
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
      <nav class="flex-1 mt-8 px-4 space-y-2 overflow-y-auto">
        <template v-for="item in navigation" :key="item.name">
          <!-- 一般選單項目 -->
          <router-link
            v-if="!item.children"
            :to="item.href"
            class="group flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors duration-200"
            :class="[
              $route.path === item.href || $route.path.startsWith(item.href + '/')
                ? 'bg-cyan-100 text-cyan-700 border-r-2 border-cyan-500'
                : 'text-gray-700 hover:bg-gray-100 hover:text-gray-900',
            ]"
            @click="sidebarOpen = false"
          >
            <svg
              class="mr-3 h-5 w-5 flex-shrink-0"
              :class="[
                $route.path === item.href || $route.path.startsWith(item.href + '/')
                  ? 'text-cyan-500'
                  : 'text-gray-400 group-hover:text-gray-500',
              ]"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path v-if="item.name === 'Dashboard'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path>
              <path v-else-if="item.name === 'Users'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"></path>
              <path v-else-if="item.name === 'Settings'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path>
              <circle v-if="item.name === 'Settings'" cx="12" cy="12" r="3"></circle>
              <path v-else-if="item.name === 'Customer Support'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
              <path v-else-if="item.name === 'Task Management'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"></path>
              <path v-else-if="item.name === 'Payments'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"></path>
              <path v-else-if="item.name === 'Logs'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
              <path v-else-if="item.name === 'FAQ Management'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
              <path v-else-if="item.name === 'Point Policy'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m-7 5h8a2 2 0 002-2V5a2 2 0 00-2-2H9a2 2 0 00-2 2v14a2 2 0 002 2zm0 0H7a2 2 0 01-2-2V7m12-4v4h4"></path>
            </svg>
            {{ item.name }}
          </router-link>

          <!-- 有子選單的項目 -->
          <div v-else class="space-y-1">
            <button
              @click="toggleSubmenu(item.name)"
              class="group w-full flex items-center justify-between px-3 py-2 text-sm font-medium rounded-md transition-colors duration-200"
              :class="[
                $route.path.startsWith(item.href)
                  ? 'bg-cyan-100 text-cyan-700 border-r-2 border-cyan-500'
                  : 'text-gray-700 hover:bg-gray-100 hover:text-gray-900',
              ]"
            >
              <div class="flex items-center">
                <svg
                  class="mr-3 h-5 w-5 flex-shrink-0"
                  :class="[
                    $route.path.startsWith(item.href)
                      ? 'text-cyan-500'
                      : 'text-gray-400 group-hover:text-gray-500',
                  ]"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path v-if="item.name === 'Users'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"></path>
                  <path v-else-if="item.name === 'Customer Support'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
                  <path v-else-if="item.name === 'Task Management'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"></path>
                  <path v-else-if="item.name === 'Payments'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"></path>
                  <path v-else-if="item.name === 'Logs'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                </svg>
                {{ item.name }}
              </div>
              <svg
                class="w-4 h-4 transition-transform duration-200"
                :class="{ 'rotate-180': openSubmenus.includes(item.name) }"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
              </svg>
            </button>
            
            <!-- 子選單 -->
            <div
              v-show="openSubmenus.includes(item.name)"
              class="ml-4 space-y-1"
            >
              <router-link
                v-for="child in item.children"
                :key="child.name"
                :to="child.href"
                class="group flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors duration-200"
                :class="[
                  $route.path === child.href
                    ? 'bg-cyan-50 text-cyan-600'
                    : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900',
                ]"
                @click="sidebarOpen = false"
              >
                <svg
                  class="mr-3 h-4 w-4 flex-shrink-0"
                  :class="[
                    $route.path === child.href
                      ? 'text-cyan-500'
                      : 'text-gray-400 group-hover:text-gray-500',
                  ]"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path v-if="child.name === 'Issues List'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
                  <path v-else-if="child.name === 'Support Chat List'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
                  <path v-else-if="child.name === 'All Tasks'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"></path>
                  <path v-else-if="child.name === 'Task Disputes'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 15.5c-.77.833.192 2.5 1.732 2.5z"></path>
                  <path v-else-if="child.name === 'Deposit Requests'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"></path>
                  <path v-else-if="child.name === 'Official Account'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z"></path>
                  <path v-else-if="child.name === 'System Logs'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                  <path v-else-if="child.name === 'User Activities'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"></path>
                  <path v-else-if="child.name === 'User Transactions'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"></path>
                  <path v-else-if="child.name === 'User List'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6 6 0 10-12 0v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"></path>
                  <path v-else-if="child.name === 'Referral Codes'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7h18M3 12h18M3 17h18"></path>
                </svg>
                {{ child.name }}
              </router-link>
            </div>
          </div>
        </template>
      </nav>
    </div>

    <!-- 主要內容區域 -->
    <div class="flex-1 flex flex-col min-w-0">
      <!-- 頂部導航欄 -->
      <div class="sticky top-0 z-40 flex h-16 bg-white shadow-sm border-b border-gray-200">
        <button
          @click="sidebarOpen = true"
          class="px-4 text-gray-500 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-cyan-500 lg:hidden"
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
            <!-- <button
              class="p-1 rounded-full text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-cyan-500"
            >
              <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M15 17h5l-5 5v-5zM11 17H6l5 5v-5z"
                />
              </svg>
            </button> -->

            <!-- 用戶選單 -->
            <div class="relative user-menu-container">
              <button
                @click="userMenuOpen = !userMenuOpen"
                class="flex items-center text-sm rounded-full focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-cyan-500"
              >
                <div class="w-8 h-8 bg-cyan-100 rounded-full flex items-center justify-center">
                  <span class="text-cyan-600 font-medium text-sm">
                    {{ authStore.userDisplayName.charAt(0).toUpperCase() }}
                  </span>
                </div>
              </button>

              <!-- 下拉選單 -->
              <div
                v-show="userMenuOpen"
                class="origin-top-right absolute right-0 mt-2 w-48 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 focus:outline-none z-50"
              >
                <div class="py-1">
                  <div class="px-4 py-2 text-sm text-gray-700 border-b border-gray-200">
                    <p class="font-medium">{{ authStore.userDisplayName }}</p>
                    <p class="text-xs text-gray-500">{{ authStore.user?.email }}</p>
                  </div>
                  <button
                    @click="handleLogout"
                    class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors duration-200"
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
      <main class="flex-1 p-6 overflow-auto">
        <router-view />
      </main>
    </div>

    <!-- 側邊欄遮罩 (僅手機版且側邊欄開啟時) -->
    <div
      v-if="sidebarOpen && !isDesktop"
      @click="sidebarOpen = false"
    class="fixed inset-0 z-40 bg-opacity-30 backdrop-blur-sm lg:hidden transition"
    ></div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'


const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()

// 桌面版預設開啟側邊欄，手機版預設關閉
const isDesktop = ref(window.innerWidth >= 1024)
const sidebarOpen = ref(isDesktop.value)
const userMenuOpen = ref(false)
const openSubmenus = ref<string[]>([])

// 定義導航項目類型
interface NavigationItem {
  name: string
  href: string
  children?: NavigationItem[]
}

const navigation: NavigationItem[] = [
  { name: 'Dashboard', href: '/dashboard' },
  { 
    name: 'Users', 
    href: '/users',
    children: [
      { name: 'User List', href: '/users' },
      { name: 'Referral Codes', href: '/users/referral-codes' },
    ]
  },
  { 
    name: 'Customer Support', 
    href: '/issues', 
    children: [
      { name: 'Issues List', href: '/issues' },
      { name: 'Support Chat List', href: '/support-chat-list' },
    ]
  },
  { 
    name: 'Task Management', 
    href: '/tasks', 
    children: [
      { name: 'All Tasks', href: '/tasks' },
      { name: 'Task Disputes', href: '/task-disputes' },
    ]
  },
  { 
    name: 'Payments', 
    href: '/payments/requests', 
    children: [
      { name: 'Deposit Requests', href: '/payments/requests' },
      { name: 'Fee Settings', href: '/payments/fee-settings' },
      { name: 'Fee Revenue', href: '/payments/fee-revenue' },
      { name: 'Official Account', href: '/payments/official-account' },
    ]
  },
  { 
    name: 'Logs', 
    href: '/logs', 
    children: [
      { name: 'System Logs', href: '/logs' },
      { name: 'User Activities', href: '/user-activities' },
      { name: 'User Transactions', href: '/user-transactions' },
    ]
  },
  { name: 'FAQ Management', href: '/faqs' },
  { name: 'Point Policy', href: '/point-policies' },
  // { name: 'Settings', href: '/settings' },
]

const toggleSubmenu = (menuName: string) => {
  const isCurrentlyOpen = openSubmenus.value.includes(menuName)
  
  // 如果點擊的是已經展開的選單，則收合它
  if (isCurrentlyOpen) {
    openSubmenus.value = []
  } else {
    // 否則關閉所有其他選單，只展開當前選單
    openSubmenus.value = [menuName]
  }
}

// 根據當前路由自動展開對應的父選單
const autoExpandSubmenu = () => {
  const currentPath = route.path
  
  // 查找當前路由對應的父選單
  for (const item of navigation) {
    if (item.children) {
      const hasActiveChild = item.children.some(child => 
        currentPath === child.href || currentPath.startsWith(child.href + '/')
      )
      
      if (hasActiveChild) {
        openSubmenus.value = [item.name]
        return
      }
    }
  }
  
  // 如果沒有找到匹配的子選單，則收合所有選單
  openSubmenus.value = []
}

const handleLogout = async () => {
  userMenuOpen.value = false
  await authStore.logout()
  router.push('/login')
}

// 響應式處理視窗大小變化
const handleResize = () => {
  const wasDesktop = isDesktop.value
  isDesktop.value = window.innerWidth >= 1024
  
  // 從手機版切換到桌面版時，自動開啟側邊欄
  if (!wasDesktop && isDesktop.value) {
    sidebarOpen.value = true
  }
  // 從桌面版切換到手機版時，關閉側邊欄
  else if (wasDesktop && !isDesktop.value) {
    sidebarOpen.value = false
  }
}

// 點擊外部關閉用戶選單
const handleClickOutside = (event: Event) => {
  const target = event.target as HTMLElement
  const userMenu = document.querySelector('.user-menu-container')
  
  if (userMenu && !userMenu.contains(target)) {
    userMenuOpen.value = false
  }
}

onMounted(() => {
  window.addEventListener('resize', handleResize)
  document.addEventListener('click', handleClickOutside)
  // 初始化時根據當前路由自動展開對應的選單
  autoExpandSubmenu()
})

// 監聽路由變化，自動展開對應的選單
watch(() => route.path, () => {
  autoExpandSubmenu()
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
  document.removeEventListener('click', handleClickOutside)
})
</script>

<style scoped>
/* 點擊外部關閉選單的指令 */
</style>
