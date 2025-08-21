import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { authApi } from '@/services/api'
import type { ApiResponse } from '@/services/api'

export interface AdminUser {
  id: number
  username: string
  full_name: string
  email: string
  role: {
    id: number
    name: string
    display_name: string
    permissions: string[]
  }
  status: string
  last_login: string | null
}

export const useAuthStore = defineStore('auth', () => {
  // 狀態
  const token = ref<string | null>(localStorage.getItem('admin_token'))
  const user = ref<AdminUser | null>(null)
  const permissions = ref<string[]>([])
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  // 計算屬性
  const isAuthenticated = computed(() => !!token.value && !!user.value)
  const userDisplayName = computed(() => user.value?.full_name || user.value?.username || '')
  const userRole = computed(() => user.value?.role?.display_name || '')

  // 檢查權限
  const hasPermission = (permission: string): boolean => {
    return permissions.value.includes(permission)
  }

  // 檢查多個權限（任一符合）
  const hasAnyPermission = (permissionList: string[]): boolean => {
    return permissionList.some((permission) => hasPermission(permission))
  }

  // 檢查多個權限（全部符合）
  const hasAllPermissions = (permissionList: string[]): boolean => {
    return permissionList.every((permission) => hasPermission(permission))
  }

  // 登入
  const login = async (email: string, password: string): Promise<boolean> => {
    try {
      isLoading.value = true
      error.value = null

      const response = await authApi.login(email, password)

      if (response.data.success && response.data.data) {
        const { admin, token: newToken, permissions: userPermissions } = response.data.data

        // 保存到狀態
        token.value = newToken
        user.value = admin
        permissions.value = userPermissions || []

        // 保存到本地存儲
        localStorage.setItem('admin_token', newToken)
        localStorage.setItem('admin_user', JSON.stringify(admin))
        localStorage.setItem('admin_permissions', JSON.stringify(userPermissions || []))

        return true
      } else {
        error.value = response.data.message || 'Login failed'
        return false
      }
    } catch (err: any) {
      error.value = err.response?.data?.message || 'Login failed'
      return false
    } finally {
      isLoading.value = false
    }
  }

  // 登出
  const logout = async (): Promise<void> => {
    try {
      if (token.value) {
        await authApi.logout()
      }
    } catch (err) {
      console.error('Logout error:', err)
    } finally {
      // 清除狀態
      token.value = null
      user.value = null
      permissions.value = []
      error.value = null

      // 清除本地存儲
      localStorage.removeItem('admin_token')
      localStorage.removeItem('admin_user')
      localStorage.removeItem('admin_permissions')
    }
  }

  // 獲取當前用戶資訊
  const fetchUser = async (): Promise<boolean> => {
    try {
      if (!token.value) return false

      isLoading.value = true
      const response = await authApi.me()

      if (response.data.success && response.data.data) {
        const { admin, permissions: userPermissions } = response.data.data

        user.value = admin
        permissions.value = userPermissions || []

        // 更新本地存儲
        localStorage.setItem('admin_user', JSON.stringify(admin))
        localStorage.setItem('admin_permissions', JSON.stringify(userPermissions || []))

        return true
      } else {
        await logout()
        return false
      }
    } catch (err) {
      console.error('Fetch user error:', err)
      await logout()
      return false
    } finally {
      isLoading.value = false
    }
  }

  // 刷新 token
  const refreshToken = async (): Promise<boolean> => {
    try {
      if (!token.value) return false

      const response = await authApi.refresh()

      if (response.data.success && response.data.data?.token) {
        const newToken = response.data.data.token
        token.value = newToken
        localStorage.setItem('admin_token', newToken)
        return true
      } else {
        await logout()
        return false
      }
    } catch (err) {
      console.error('Refresh token error:', err)
      await logout()
      return false
    }
  }

  // 初始化（從本地存儲恢復狀態）
  const initialize = async (): Promise<void> => {
    const savedToken = localStorage.getItem('admin_token')
    const savedUser = localStorage.getItem('admin_user')
    const savedPermissions = localStorage.getItem('admin_permissions')

    if (savedToken && savedUser) {
      token.value = savedToken
      try {
        user.value = JSON.parse(savedUser)
        permissions.value = savedPermissions ? JSON.parse(savedPermissions) : []

        // 驗證 token 是否仍然有效
        await fetchUser()
      } catch (err) {
        console.error('Initialize error:', err)
        await logout()
      }
    }
  }

  return {
    // 狀態
    token: readonly(token),
    user: readonly(user),
    permissions: readonly(permissions),
    isLoading: readonly(isLoading),
    error: readonly(error),

    // 計算屬性
    isAuthenticated,
    userDisplayName,
    userRole,

    // 方法
    hasPermission,
    hasAnyPermission,
    hasAllPermissions,
    login,
    logout,
    fetchUser,
    refreshToken,
    initialize,
  }
})
