<template>
  <div class="min-h-screen bg-gray-50 flex">
    <!-- 側邊欄 -->
    <div
      class="fixed inset-y-0 left-0 z-50 w-64 bg-white shadow-lg transform transition-transform duration-300 ease-in-out flex flex-col lg:relative lg:translate-x-0 lg:z-auto"
      :class="{ '-translate-x-full': !sidebarOpen }"
    >
      <!-- 側邊欄標題 -->
      <div class="flex items-center justify-between h-16 px-6 bg-cyan-600">
        <div
          class="flex items-center cursor-pointer"
          @click="$router.push('/dashboard')"
        >
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
      <nav class="flex-1 mt-6 px-3 pb-6 overflow-y-auto">
        <div
          v-for="section in navigationSections"
          :key="section.title"
          class="space-y-2"
        >
          <template v-for="item in section.items" :key="item.name">
            <!-- 一般選單項目 -->
            <router-link
              v-if="!item.children"
              :to="item.href"
              class="group flex items-center gap-3 px-3 py-2.5 text-sm font-medium rounded-lg transition-colors duration-150 border-l-4 border-transparent"
              :class="[
                $route.path === item.href || $route.path.startsWith(item.href + '/')
                  ? 'bg-cyan-50 text-cyan-800 border-cyan-500'
                  : 'text-gray-700 hover:bg-gray-100 hover:text-gray-900',
              ]"
              @click="sidebarOpen = false"
            >
              <component
                :is="getNavIcon(item.name)"
                class="h-5 w-5 flex-shrink-0"
                :class="[
                  $route.path === item.href || $route.path.startsWith(item.href + '/')
                    ? 'text-cyan-500'
                    : 'text-gray-400 group-hover:text-gray-500',
                ]"
              />
              {{ item.name }}
            </router-link>

            <!-- 有子選單的項目 -->
            <div v-else class="space-y-1">
              <button
                @click="toggleSubmenu(item.name)"
                class="group w-full flex items-center justify-between px-3 py-2.5 text-sm font-medium rounded-lg transition-colors duration-150 border-l-4 border-transparent"
                :class="[
                  isParentActive(item.href)
                    ? 'bg-cyan-50 text-cyan-800 border-cyan-500'
                    : 'text-gray-700 hover:bg-gray-100 hover:text-gray-900',
                ]"
              >
                <div class="flex items-center gap-3 w-full">
                  <component
                    :is="getNavIcon(item.name)"
                    class="h-5 w-5 flex-shrink-0"
                    :class="[
                      isParentActive(item.href)
                        ? 'text-cyan-500'
                        : 'text-gray-400 group-hover:text-gray-500',
                    ]"
                  />
                  <span>{{ item.name }}</span>
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
              <transition name="submenu">
                <div
                  v-show="openSubmenus.includes(item.name)"
                  class="ml-6 pl-4 border-l border-gray-200 space-y-1 overflow-hidden"
                >
                  <router-link
                    v-for="child in item.children"
                    :key="child.name"
                    :to="child.href"
                    class="group flex items-center gap-2 px-2 py-2 text-[13px] font-medium rounded-md transition-colors duration-150"
                    :class="[
                      $route.path === child.href
                        ? 'bg-cyan-50 text-cyan-700'
                        : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900',
                    ]"
                    @click="sidebarOpen = false"
                  >
                    <span
                      class="h-1.5 w-1.5 rounded-full"
                      :class="[
                        $route.path === child.href
                          ? 'bg-cyan-500'
                          : 'bg-gray-300 group-hover:bg-gray-400',
                      ]"
                    ></span>
                    {{ child.name }}
                  </router-link>
                </div>
              </transition>
            </div>
          </template>
        </div>
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
                <div
                  class="w-8 h-8 rounded-full flex items-center justify-center"
                  :class="selectedAvatarConfig.bgClass"
                >
                  <!-- Legacy avatar (admin initial) retained for reference
                  <span class="text-cyan-600 font-medium text-sm">
                    {{ authStore.userDisplayName.charAt(0).toUpperCase() }}
                  </span>
                  -->
                  <svg
                    v-if="selectedAvatarConfig.key === 'bear'"
                    class="w-6 h-6"
                    :class="selectedAvatarConfig.iconClass"
                    viewBox="0 0 64 64"
                    aria-hidden="true"
                  >
                    <circle cx="20" cy="20" r="9" fill="currentColor" fill-opacity="0.2"></circle>
                    <circle cx="44" cy="20" r="9" fill="currentColor" fill-opacity="0.2"></circle>
                    <circle cx="32" cy="36" r="20" fill="currentColor" fill-opacity="0.18"></circle>
                    <circle cx="24" cy="34" r="3" fill="currentColor"></circle>
                    <circle cx="40" cy="34" r="3" fill="currentColor"></circle>
                    <path d="M24 44c4 4 12 4 16 0" stroke="currentColor" stroke-width="3" stroke-linecap="round"></path>
                  </svg>
                  <svg
                    v-else-if="selectedAvatarConfig.key === 'fox'"
                    class="w-6 h-6"
                    :class="selectedAvatarConfig.iconClass"
                    viewBox="0 0 64 64"
                    aria-hidden="true"
                  >
                    <path
                      d="M12 26l20-14 20 14v18c0 8.837-7.163 16-16 16h-8c-8.837 0-16-7.163-16-16V26z"
                      fill="currentColor"
                      fill-opacity="0.18"
                    ></path>
                    <path
                      d="M12 26l20-14 20 14"
                      stroke="currentColor"
                      stroke-width="3"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    ></path>
                    <path
                      d="M24 28l8 8 8-8"
                      stroke="currentColor"
                      stroke-width="3"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    ></path>
                    <path
                      d="M24 44c3 2 13 2 16 0"
                      stroke="currentColor"
                      stroke-width="3"
                      stroke-linecap="round"
                    ></path>
                  </svg>
                  <svg
                    v-else-if="selectedAvatarConfig.key === 'owl'"
                    class="w-6 h-6"
                    :class="selectedAvatarConfig.iconClass"
                    viewBox="0 0 64 64"
                    aria-hidden="true"
                  >
                    <circle cx="22" cy="28" r="9" fill="currentColor" fill-opacity="0.18"></circle>
                    <circle cx="42" cy="28" r="9" fill="currentColor" fill-opacity="0.18"></circle>
                    <circle cx="22" cy="28" r="4" fill="white"></circle>
                    <circle cx="42" cy="28" r="4" fill="white"></circle>
                    <circle cx="22" cy="28" r="2" fill="currentColor"></circle>
                    <circle cx="42" cy="28" r="2" fill="currentColor"></circle>
                    <path
                      d="M16 20l16-10 16 10"
                      stroke="currentColor"
                      stroke-width="3"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    ></path>
                    <path
                      d="M18 40c4 6 8 10 14 10s10-4 14-10"
                      stroke="currentColor"
                      stroke-width="3"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    ></path>
                  </svg>
                  <svg
                    v-else-if="selectedAvatarConfig.key === 'whale'"
                    class="w-6 h-6"
                    :class="selectedAvatarConfig.iconClass"
                    viewBox="0 0 64 64"
                    aria-hidden="true"
                  >
                    <path
                      d="M10 34c2 8 10 16 22 16 20 0 22-14 22-20 0-8-6-10-10-8s-4 8-10 8-8-6-14-6-10 4-10 10z"
                      fill="currentColor"
                      fill-opacity="0.18"
                    ></path>
                    <path
                      d="M14 28s-2-6 4-10"
                      stroke="currentColor"
                      stroke-width="3"
                      stroke-linecap="round"
                    ></path>
                    <path
                      d="M48 26s6-4 6 6"
                      stroke="currentColor"
                      stroke-width="3"
                      stroke-linecap="round"
                    ></path>
                    <circle cx="44" cy="32" r="2" fill="currentColor"></circle>
                  </svg>
                  <svg
                    v-else-if="selectedAvatarConfig.key === 'rabbit'"
                    class="w-6 h-6"
                    :class="selectedAvatarConfig.iconClass"
                    viewBox="0 0 64 64"
                    aria-hidden="true"
                  >
                    <rect x="18" y="4" width="8" height="18" rx="4" fill="currentColor" fill-opacity="0.25"></rect>
                    <rect x="38" y="4" width="8" height="18" rx="4" fill="currentColor" fill-opacity="0.25"></rect>
                    <ellipse cx="32" cy="38" rx="16" ry="18" fill="currentColor" fill-opacity="0.2"></ellipse>
                    <circle cx="26" cy="34" r="3" fill="currentColor"></circle>
                    <circle cx="38" cy="34" r="3" fill="currentColor"></circle>
                    <path d="M28 44c2 2 8 2 10 0" stroke="currentColor" stroke-width="3" stroke-linecap="round"></path>
                  </svg>
                  <svg
                    v-else-if="selectedAvatarConfig.key === 'lion'"
                    class="w-6 h-6"
                    :class="selectedAvatarConfig.iconClass"
                    viewBox="0 0 64 64"
                    aria-hidden="true"
                  >
                    <circle cx="32" cy="36" r="18" fill="currentColor" fill-opacity="0.18"></circle>
                    <circle cx="32" cy="32" r="12" fill="currentColor" fill-opacity="0.3"></circle>
                    <circle cx="24" cy="30" r="3" fill="currentColor"></circle>
                    <circle cx="40" cy="30" r="3" fill="currentColor"></circle>
                    <path d="M26 40c4 2 8 2 12 0" stroke="currentColor" stroke-width="3" stroke-linecap="round"></path>
                    <path d="M16 26c0-10 32-10 32 0" stroke="currentColor" stroke-width="3" stroke-linecap="round"></path>
                  </svg>
                  <svg
                    v-else-if="selectedAvatarConfig.key === 'panda'"
                    class="w-6 h-6"
                    :class="selectedAvatarConfig.iconClass"
                    viewBox="0 0 64 64"
                    aria-hidden="true"
                  >
                    <circle cx="20" cy="20" r="8" fill="currentColor" fill-opacity="0.2"></circle>
                    <circle cx="44" cy="20" r="8" fill="currentColor" fill-opacity="0.2"></circle>
                    <circle cx="32" cy="34" r="18" fill="currentColor" fill-opacity="0.18"></circle>
                    <ellipse cx="24" cy="34" rx="6" ry="8" fill="currentColor"></ellipse>
                    <ellipse cx="40" cy="34" rx="6" ry="8" fill="currentColor"></ellipse>
                    <circle cx="32" cy="40" r="3" fill="white"></circle>
                    <circle cx="32" cy="40" r="1.5" fill="currentColor"></circle>
                  </svg>
                  <svg
                    v-else-if="selectedAvatarConfig.key === 'koala'"
                    class="w-6 h-6"
                    :class="selectedAvatarConfig.iconClass"
                    viewBox="0 0 64 64"
                    aria-hidden="true"
                  >
                    <circle cx="16" cy="28" r="10" fill="currentColor" fill-opacity="0.2"></circle>
                    <circle cx="48" cy="28" r="10" fill="currentColor" fill-opacity="0.2"></circle>
                    <circle cx="32" cy="34" r="18" fill="currentColor" fill-opacity="0.18"></circle>
                    <circle cx="24" cy="32" r="3" fill="currentColor"></circle>
                    <circle cx="40" cy="32" r="3" fill="currentColor"></circle>
                    <ellipse cx="32" cy="40" rx="4" ry="6" fill="currentColor"></ellipse>
                  </svg>
                  <svg
                    v-else-if="selectedAvatarConfig.key === 'dolphin'"
                    class="w-6 h-6"
                    :class="selectedAvatarConfig.iconClass"
                    viewBox="0 0 64 64"
                    aria-hidden="true"
                  >
                    <path
                      d="M10 36c6-12 20-20 32-18 12 2 12 12 8 18s-14 8-22 8-18-4-18-8z"
                      fill="currentColor"
                      fill-opacity="0.18"
                    ></path>
                    <path
                      d="M22 28s0-8 8-12 16 0 16 0"
                      stroke="currentColor"
                      stroke-width="3"
                      stroke-linecap="round"
                    ></path>
                    <circle cx="42" cy="32" r="2" fill="currentColor"></circle>
                  </svg>
                  <svg
                    v-else-if="selectedAvatarConfig.key === 'tiger'"
                    class="w-6 h-6"
                    :class="selectedAvatarConfig.iconClass"
                    viewBox="0 0 64 64"
                    aria-hidden="true"
                  >
                    <circle cx="32" cy="34" r="20" fill="currentColor" fill-opacity="0.18"></circle>
                    <path
                      d="M16 28l10 6-10 6m32-12l-10 6 10 6"
                      stroke="currentColor"
                      stroke-width="3"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    ></path>
                    <path
                      d="M28 22l2 6-6 2m12-8l-2 6 6 2"
                      stroke="currentColor"
                      stroke-width="3"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    ></path>
                    <circle cx="24" cy="34" r="3" fill="currentColor"></circle>
                    <circle cx="40" cy="34" r="3" fill="currentColor"></circle>
                    <path d="M26 42c4 2 8 2 12 0" stroke="currentColor" stroke-width="3" stroke-linecap="round"></path>
                  </svg>
                  <svg
                    v-else
                    class="w-6 h-6"
                    :class="selectedAvatarConfig.iconClass"
                    viewBox="0 0 64 64"
                    aria-hidden="true"
                  >
                    <path
                      d="M20 12c-4 12 2 18 12 18s16-6 12-18"
                      stroke="currentColor"
                      stroke-width="3"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    ></path>
                    <path
                      d="M18 24c-6 4-10 12-6 18s14 8 20 4"
                      stroke="currentColor"
                      stroke-width="3"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    ></path>
                    <path
                      d="M46 24c6 4 10 12 6 18s-14 8-20 4"
                      stroke="currentColor"
                      stroke-width="3"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    ></path>
                    <circle cx="26" cy="30" r="3" fill="currentColor"></circle>
                    <circle cx="38" cy="30" r="3" fill="currentColor"></circle>
                  </svg>
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
                    @click="openAvatarSettings"
                    class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors duration-200"
                  >
                    Customize avatar
                  </button>
                  <button
                    @click="handleLogout"
                    class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors duration-200 border-t border-gray-200"
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

    <!-- Avatar selection modal -->
    <div v-if="isAvatarModalOpen" class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 backdrop-blur-lg" @click="closeAvatarSettings"></div>
      <div
        class="relative bg-white w-full max-w-3xl mx-4 rounded-lg shadow-2xl p-6 space-y-4"
        @click.stop
      >
        <div class="flex items-start justify-between">
          <div>
            <h3 class="text-lg font-semibold	text-gray-900">Customize avatar</h3>
            <p class="text-sm text-gray-500">Choose a themed icon or keep the default assignment.</p>
          </div>
          <button class="text-gray-400 hover:text-gray-600" @click="closeAvatarSettings">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>

        <div class="grid grid-cols-2 sm:grid-cols-5 gap-4">
          <button
            v-for="config in adminAvatarConfigs"
            :key="config.key"
            type="button"
            class="flex flex-col items-center gap-2 rounded-lg border p-3 transition focus:outline-none"
            :class="avatarSelection === config.key ? 'border-cyan-500 bg-cyan-50 shadow-sm' : 'border-gray-200 hover:border-cyan-300'"
            @click="selectAvatarOption(config.key)"
          >
            <div
              :class="[
                'w-14 h-14 rounded-full flex items-center justify-center',
                config.bgClass,
              ]"
            >
              <svg
                v-if="config.key === 'bear'"
                class="w-8 h-8"
                :class="config.iconClass"
                viewBox="0 0 64 64"
                aria-hidden="true"
              >
                <circle cx="20" cy="20" r="9" fill="currentColor" fill-opacity="0.2"></circle>
                <circle cx="44" cy="20" r="9" fill="currentColor" fill-opacity="0.2"></circle>
                <circle cx="32" cy="36" r="20" fill="currentColor" fill-opacity="0.18"></circle>
                <circle cx="24" cy="34" r="3" fill="currentColor"></circle>
                <circle cx="40" cy="34" r="3" fill="currentColor"></circle>
                <path d="M24 44c4 4 12 4 16 0" stroke="currentColor" stroke-width="3" stroke-linecap="round"></path>
              </svg>
              <svg
                v-else-if="config.key === 'fox'"
                class="w-8 h-8"
                :class="config.iconClass"
                viewBox="0 0 64 64"
                aria-hidden="true"
              >
                <path
                  d="M12 26l20-14 20 14v18c0 8.837-7.163 16-16 16h-8c-8.837 0-16-7.163-16-16V26z"
                  fill="currentColor"
                  fill-opacity="0.18"
                ></path>
                <path
                  d="M12 26l20-14 20 14"
                  stroke="currentColor"
                  stroke-width="3"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                ></path>
                <path
                  d="M24 28l8 8 8-8"
                  stroke="currentColor"
                  stroke-width="3"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                ></path>
                <path
                  d="M24 44c3 2 13 2 16 0"
                  stroke="currentColor"
                  stroke-width="3"
                  stroke-linecap="round"
                ></path>
              </svg>
              <svg
                v-else-if="config.key === 'owl'"
                class="w-8 h-8"
                :class="config.iconClass"
                viewBox="0 0 64 64"
                aria-hidden="true"
              >
                <circle cx="22" cy="28" r="9" fill="currentColor" fill-opacity="0.18"></circle>
                <circle cx="42" cy="28" r="9" fill="currentColor" fill-opacity="0.18"></circle>
                <circle cx="22" cy="28" r="4" fill="white"></circle>
                <circle cx="42" cy="28" r="4" fill="white"></circle>
                <circle cx="22" cy="28" r="2" fill="currentColor"></circle>
                <circle cx="42" cy="28" r="2" fill="currentColor"></circle>
                <path
                  d="M16 20l16-10 16 10"
                  stroke="currentColor"
                  stroke-width="3"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                ></path>
                <path
                  d="M18 40c4 6 8 10 14 10s10-4 14-10"
                  stroke="currentColor"
                  stroke-width="3"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                ></path>
              </svg>
              <svg
                v-else-if="config.key === 'whale'"
                class="w-8 h-8"
                :class="config.iconClass"
                viewBox="0 0 64 64"
                aria-hidden="true"
              >
                <path
                  d="M10 34c2 8 10 16 22 16 20 0 22-14 22-20 0-8-6-10-10-8s-4 8-10 8-8-6-14-6-10 4-10 10z"
                  fill="currentColor"
                  fill-opacity="0.18"
                ></path>
                <path
                  d="M14 28s-2-6 4-10"
                  stroke="currentColor"
                  stroke-width="3"
                  stroke-linecap="round"
                ></path>
                <path
                  d="M48 26s6-4 6 6"
                  stroke="currentColor"
                  stroke-width="3"
                  stroke-linecap="round"
                ></path>
                <circle cx="44" cy="32" r="2" fill="currentColor"></circle>
              </svg>
              <svg
                v-else-if="config.key === 'rabbit'"
                class="w-8 h-8"
                :class="config.iconClass"
                viewBox="0 0 64 64"
                aria-hidden="true"
              >
                <rect x="18" y="4" width="8" height="18" rx="4" fill="currentColor" fill-opacity="0.25"></rect>
                <rect x="38" y="4" width="8" height="18" rx="4" fill="currentColor" fill-opacity="0.25"></rect>
                <ellipse cx="32" cy="38" rx="16" ry="18" fill="currentColor" fill-opacity="0.2"></ellipse>
                <circle cx="26" cy="34" r="3" fill="currentColor"></circle>
                <circle cx="38" cy="34" r="3" fill="currentColor"></circle>
                <path d="M28 44c2 2 8 2 10 0" stroke="currentColor" stroke-width="3" stroke-linecap="round"></path>
              </svg>
              <svg
                v-else-if="config.key === 'lion'"
                class="w-8 h-8"
                :class="config.iconClass"
                viewBox="0 0 64 64"
                aria-hidden="true"
              >
                <circle cx="32" cy="36" r="18" fill="currentColor" fill-opacity="0.18"></circle>
                <circle cx="32" cy="32" r="12" fill="currentColor" fill-opacity="0.3"></circle>
                <circle cx="24" cy="30" r="3" fill="currentColor"></circle>
                <circle cx="40" cy="30" r="3" fill="currentColor"></circle>
                <path d="M26 40c4 2 8 2 12 0" stroke="currentColor" stroke-width="3" stroke-linecap="round"></path>
                <path d="M16 26c0-10 32-10 32 0" stroke="currentColor" stroke-width="3" stroke-linecap="round"></path>
              </svg>
              <svg
                v-else-if="config.key === 'panda'"
                class="w-8 h-8"
                :class="config.iconClass"
                viewBox="0 0 64 64"
                aria-hidden="true"
              >
                <circle cx="20" cy="20" r="8" fill="currentColor" fill-opacity="0.2"></circle>
                <circle cx="44" cy="20" r="8" fill="currentColor" fill-opacity="0.2"></circle>
                <circle cx="32" cy="34" r="18" fill="currentColor" fill-opacity="0.18"></circle>
                <ellipse cx="24" cy="34" rx="6" ry="8" fill="currentColor"></ellipse>
                <ellipse cx="40" cy="34" rx="6" ry="8" fill="currentColor"></ellipse>
                <circle cx="32" cy="40" r="3" fill="white"></circle>
                <circle cx="32" cy="40" r="1.5" fill="currentColor"></circle>
              </svg>
              <svg
                v-else-if="config.key === 'koala'"
                class="w-8 h-8"
                :class="config.iconClass"
                viewBox="0 0 64 64"
                aria-hidden="true"
              >
                <circle cx="16" cy="28" r="10" fill="currentColor" fill-opacity="0.2"></circle>
                <circle cx="48" cy="28" r="10" fill="currentColor" fill-opacity="0.2"></circle>
                <circle cx="32" cy="34" r="18" fill="currentColor" fill-opacity="0.18"></circle>
                <circle cx="24" cy="32" r="3" fill="currentColor"></circle>
                <circle cx="40" cy="32" r="3" fill="currentColor"></circle>
                <ellipse cx="32" cy="40" rx="4" ry="6" fill="currentColor"></ellipse>
              </svg>
              <svg
                v-else-if="config.key === 'dolphin'"
                class="w-8 h-8"
                :class="config.iconClass"
                viewBox="0 0 64 64"
                aria-hidden="true"
              >
                <path
                  d="M10 36c6-12 20-20 32-18 12 2 12 12 8 18s-14 8-22 8-18-4-18-8z"
                  fill="currentColor"
                  fill-opacity="0.18"
                ></path>
                <path
                  d="M22 28s0-8 8-12 16 0 16 0"
                  stroke="currentColor"
                  stroke-width="3"
                  stroke-linecap="round"
                ></path>
                <circle cx="42" cy="32" r="2" fill="currentColor"></circle>
              </svg>
              <svg
                v-else
                class="w-8 h-8"
                :class="config.iconClass"
                viewBox="0 0 64 64"
                aria-hidden="true"
              >
                <circle cx="32" cy="34" r="20" fill="currentColor" fill-opacity="0.18"></circle>
                <path
                  d="M16 28l10 6-10 6m32-12l-10 6 10 6"
                  stroke="currentColor"
                  stroke-width="3"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                ></path>
                <path
                  d="M28 22l2 6-6 2m12-8l-2 6 6 2"
                  stroke="currentColor"
                  stroke-width="3"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                ></path>
                <circle cx="24" cy="34" r="3" fill="currentColor"></circle>
                <circle cx="40" cy="34" r="3" fill="currentColor"></circle>
                <path d="M26 42c4 2 8 2 12 0" stroke="currentColor" stroke-width="3" stroke-linecap="round"></path>
              </svg>
            </div>
            <span class="text-xs font-medium text-gray-700 capitalize">{{ config.key }}</span>
          </button>
        </div>

        <div class="flex items-center justify-between pt-2">
          <button type="button" class="text-sm text-gray-500 hover:text-gray-700" @click="useDefaultAvatar">
            Use default assignment
          </button>
          <div class="space-x-3">
            <button type="button" class="admin-button-secondary" @click="closeAvatarSettings">Cancel</button>
            <button type="button" class="admin-button-primary" @click="saveAvatarSelection">Save</button>
          </div>
        </div>
      </div>
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
import { ref, onMounted, onUnmounted, watch, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import {
  HomeIcon,
  UsersIcon,
  UserCircleIcon,
  ChatBubbleLeftRightIcon,
  ClipboardDocumentCheckIcon,
  CreditCardIcon,
  DocumentTextIcon,
  QuestionMarkCircleIcon,
  AdjustmentsHorizontalIcon,
  DocumentCheckIcon,
} from '@heroicons/vue/24/outline'


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

interface NavigationSection {
  title: string
  items: NavigationItem[]
}

const navigationSections: NavigationSection[] = [
  {
    title: 'Overview',
    items: [{ name: 'Dashboard', href: '/dashboard' }],
  },
  {
    title: 'People',
    items: [
      {
        name: 'Users',
        href: '/users',
        children: [
          { name: 'User List', href: '/users' },
          { name: 'Referral Codes', href: '/users/referral-codes' },
        ],
      },
      { name: 'Admins', href: '/admin-accounts' },
    ],
  },
  {
    title: 'Operations',
    items: [
      {
        name: 'Support',
        href: '/issues',
        children: [
          { name: 'Issues List', href: '/issues' },
          { name: 'Support Chat List', href: '/support-chat-list' },
        ],
      },
      {
        name: 'Tasks',
        href: '/tasks',
        children: [
          { name: 'All Tasks', href: '/tasks' },
          { name: 'Task Disputes', href: '/task-disputes' },
        ],
      },
    ],
  },
  {
    title: 'Finance',
    items: [
      {
        name: 'Payments',
        href: '/payments/requests',
        children: [
          { name: 'Deposit Requests', href: '/payments/requests' },
          { name: 'Withdraw Requests', href: '/payments/withdraw-requests' },
          { name: 'Fee Settings', href: '/payments/fee-settings' },
          { name: 'Official Account', href: '/payments/official-account' },
        ],
      },
    ],
  },
  {
    title: 'Audit',
    items: [
      {
        name: 'Logs',
        href: '/logs',
        children: [
          { name: 'Admin Logs', href: '/logs' },
          { name: 'User Logs', href: '/user-logs' },
        ],
      },
    ],
  },
  {
    title: 'Content',
    items: [
      { name: 'FAQs', href: '/faqs' },
      { name: 'Point Policy', href: '/point-policies' },
      { name: 'Terms of Use', href: '/app-terms' },
    ],
  },
]

const navigationItems = navigationSections.flatMap((section) => section.items)

const navigationIcons: Record<string, any> = {
  'Dashboard': HomeIcon,
  'Users': UsersIcon,
  'Admins': UserCircleIcon,
  'Support': ChatBubbleLeftRightIcon,
  'Tasks': ClipboardDocumentCheckIcon,
  'Payments': CreditCardIcon,
  'Logs': DocumentTextIcon,
  'FAQs': QuestionMarkCircleIcon,
  'Point Policy': AdjustmentsHorizontalIcon,
  'Terms of Use': DocumentCheckIcon,
}

const getNavIcon = (name: string) => navigationIcons[name] || HomeIcon

const AVATAR_STORAGE_PREFIX = 'admin_avatar_choice_'

interface AdminAvatarConfig {
  key: string
  bgClass: string
  iconClass: string
}

const adminAvatarConfigs: AdminAvatarConfig[] = [
  { key: 'bear', bgClass: 'bg-cyan-100', iconClass: 'text-cyan-600' },
  { key: 'fox', bgClass: 'bg-amber-100', iconClass: 'text-amber-600' },
  { key: 'owl', bgClass: 'bg-indigo-100', iconClass: 'text-indigo-600' },
  { key: 'whale', bgClass: 'bg-sky-100', iconClass: 'text-sky-600' },
  { key: 'rabbit', bgClass: 'bg-rose-100', iconClass: 'text-rose-500' },
  { key: 'lion', bgClass: 'bg-yellow-100', iconClass: 'text-yellow-600' },
  { key: 'panda', bgClass: 'bg-gray-100', iconClass: 'text-gray-600' },
  { key: 'koala', bgClass: 'bg-lime-100', iconClass: 'text-lime-600' },
  { key: 'dolphin', bgClass: 'bg-blue-100', iconClass: 'text-blue-600' },
  { key: 'tiger', bgClass: 'bg-orange-100', iconClass: 'text-orange-600' },
]

const storedAvatarKey = ref<string | null>(null)
const isAvatarModalOpen = ref(false)
const avatarSelection = ref<string | null>(null)

const getAvatarStorageKey = () => {
  if (typeof authStore.user?.id !== 'number') {
    return null
  }
  return `${AVATAR_STORAGE_PREFIX}${authStore.user.id}`
}

const loadStoredAvatarPreference = () => {
  if (typeof window === 'undefined') {
    storedAvatarKey.value = null
    return
  }
  const storageKey = getAvatarStorageKey()
  if (!storageKey) {
    storedAvatarKey.value = null
    return
  }
  const saved = localStorage.getItem(storageKey)
  const exists = adminAvatarConfigs.some((config) => config.key === saved)
  storedAvatarKey.value = exists && saved ? saved : null
}

const defaultAvatarKey = computed(() => {
  const userId = authStore.user?.id
  if (typeof userId === 'number' && userId >= 0) {
    const index = userId % adminAvatarConfigs.length
    return adminAvatarConfigs[index]?.key || adminAvatarConfigs[0].key
  }
  return adminAvatarConfigs[0].key
})

const selectedAvatarKey = computed(() => storedAvatarKey.value || defaultAvatarKey.value)

const selectedAvatarConfig = computed<AdminAvatarConfig>(() => {
  const config = adminAvatarConfigs.find((item) => item.key === selectedAvatarKey.value)
  return config || adminAvatarConfigs[0]
})

const openAvatarSettings = () => {
  avatarSelection.value = storedAvatarKey.value
  userMenuOpen.value = false
  isAvatarModalOpen.value = true
}

const closeAvatarSettings = () => {
  isAvatarModalOpen.value = false
}

const selectAvatarOption = (key: string) => {
  avatarSelection.value = key
}

const useDefaultAvatar = () => {
  avatarSelection.value = null
}

const saveAvatarSelection = () => {
  if (typeof window === 'undefined') {
    closeAvatarSettings()
    return
  }
  const storageKey = getAvatarStorageKey()
  if (!storageKey) {
    storedAvatarKey.value = null
    closeAvatarSettings()
    return
  }

  if (avatarSelection.value) {
    localStorage.setItem(storageKey, avatarSelection.value)
    storedAvatarKey.value = avatarSelection.value
  } else {
    localStorage.removeItem(storageKey)
    storedAvatarKey.value = null
  }
  closeAvatarSettings()
}


watch(
  () => authStore.user?.id,
  () => {
    loadStoredAvatarPreference()
  },
  { immediate: true },
)

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
  for (const item of navigationItems) {
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

const isParentActive = (path: string) => {
  return route.path.startsWith(path)
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
.submenu-enter-active,
.submenu-leave-active {
  transition: max-height 0.25s ease, opacity 0.2s ease;
}

.submenu-enter-from,
.submenu-leave-to {
  max-height: 0;
  opacity: 0;
}

.submenu-enter-to,
.submenu-leave-from {
  max-height: 320px;
  opacity: 1;
}
</style>
