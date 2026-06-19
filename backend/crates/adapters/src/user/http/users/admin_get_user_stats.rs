use crate::http_error::{HttpError, HttpResult};
use crate::openapi::USERS_TAG;
use crate::shared::http::app_state::AppState;
use crate::shared::http::model::session_model::UserSession;
use application::user::use_cases::user::admin_get_user_stats::AdminGetUserStatsError;
use axum::extract::{Extension, Path, State};
use axum::Json;
use uuid::Uuid;

impl From<AdminGetUserStatsError> for HttpError {
    fn from(value: AdminGetUserStatsError) -> Self {
        match value {
            AdminGetUserStatsError::Forbidden => HttpError::Forbidden,
            AdminGetUserStatsError::UserNotFound => HttpError::NotFound("User not found".to_string()),
            AdminGetUserStatsError::PersistenceError(e) => HttpError::GenericError(e.to_string()),
        }
    }
}

#[utoipa::path(
    get,
    path = "/api/users/{id}/stats",
    tag = USERS_TAG,
    summary = "Get user stats (admin only)",
    responses(
        (status = 200, description = "User stats"),
        (status = 403, description = "Forbidden"),
        (status = 404, description = "User not found"),
    ),
    security(("jwt" = []))
)]
pub async fn admin_get_user_stats_api(
    State(state): State<AppState>,
    Extension(user): Extension<UserSession>,
    Path(id): Path<Uuid>,
) -> HttpResult<Json<application::user::use_cases::user::admin_get_user_stats::AdminUserStatsOutput>> {
    let stats = state
        .user
        .admin_get_user_stats_uc
        .execute(user.user_id, id)
        .await?;
    Ok(Json(stats))
}
