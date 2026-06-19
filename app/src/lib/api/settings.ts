import { apiClient } from "./client";
import type { UserSettingDto } from "@/types";

export const settings = {
    getAll: () =>
        apiClient
            .get<{ settings: UserSettingDto[] }>("/api/setting")
            .then((r) => r.data.settings),

    update: (key: string, value: string) =>
        apiClient.patch<void>("/api/setting", { key, value }).then((r) => r.data),
};
