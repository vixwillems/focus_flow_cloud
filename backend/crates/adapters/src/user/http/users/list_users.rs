use crate::http_error::{HttpError, HttpResult};
use crate::openapi::USERS_TAG;
use crate::shared::http::app_state::AppState;
use crate::shared::http::model::session_model::UserSession;
use application::user::use_cases::user::list_users::ListUsersError;
use axum::extract::{Extension, State};
use axum::Json;

impl From<ListUsersError> for HttpError {
    fn from(value: ListUsersError) -> Self {
        match value {
            ListUsersError::Forbidden => HttpError::Forbidden,
            ListUsersError::PersistenceError(e) => HttpError::GenericError(e.to_string()),
        }
    }
}

#[utoipa::path(
    get,
    path = "/api/users",
    tag = USERS_TAG,
    summary = "List all users (admin only)",
    responses(
        (status = 200, description = "List of users"),
        (status = 403, description = "Forbidden"),
    ),
    security(("jwt" = []))
)]
pub async fn list_users_api(
    State(state): State<AppState>,
    Extension(user): Extension<UserSession>,
) -> HttpResult<Json<Vec<application::user::use_cases::user::list_users::UserListItem>>> {
    let users = state
        .user
        .list_users_uc
        .execute(user.user_id)
        .await?;
    Ok(Json(users))
}
