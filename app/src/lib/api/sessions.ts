import { apiClient } from "./client";
import type { FocusSessionDto, SessionTypeEnum } from "@/types";

export interface GetSessionsFilters {
    startDate?: number;
    endDate?: number;
    taskIds?: string[];
    sessionType?: SessionTypeEnum;
    minConcentrationScore?: number;
    maxConcentrationScore?: number;
    hasNotes?: boolean;
}

export interface GetSessionsResponse {
    focusSessions: FocusSessionDto[];
}

export interface UpdateSessionPayload {
    taskId?: string | null;
    sessionType?: SessionTypeEnum;
    actualDuration?: number | null;
    concentrationScore?: number | null;
    startedAt?: number | null;
    endedAt?: number | null;
    notes?: string | null;
}

export const sessionsApi = {
    list: (filters?: GetSessionsFilters) => {
        return apiClient
            .get<GetSessionsResponse>("/api/focus-sessions", { params: filters })
            .then((r) => r.data);
    },

    update: (id: string, payload: UpdateSessionPayload) => {
        return apiClient
            .put<unknown>(`/api/focus-sessions/${id}`, payload)
            .then((r) => r.data);
    },

    delete: (id: string) => {
        return apiClient
            .delete<unknown>(`/api/focus-sessions/${id}`)
            .then((r) => r.data);
    },
};
