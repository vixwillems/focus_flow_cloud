import { apiClient } from "./client";

export interface UserListItem {
    id: string;
    username: string;
    role: string;
}

export interface UserStats {
    totalSessions: number;
    totalFocusDuration: number;
}

export const admin = {
    listUsers: () =>
        apiClient.get<UserListItem[]>("/api/users").then((r) => r.data),

    deleteUser: (id: string) =>
        apiClient.delete(`/api/users/${id}`).then((r) => r.data),

    changePassword: (id: string, newPassword: string) =>
        apiClient
            .put(`/api/users/${id}/password`, { newPassword })
            .then((r) => r.data),

    updateUser: (id: string, data: { username?: string; role?: string }) =>
        apiClient.put(`/api/users/${id}`, data).then((r) => r.data),

    getUserStats: (id: string) =>
        apiClient.get<UserStats>(`/api/users/${id}/stats`).then((r) => r.data),
};
