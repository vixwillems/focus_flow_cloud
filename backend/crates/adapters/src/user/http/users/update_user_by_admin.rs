use crate::http_error::{HttpError, HttpResult};
use crate::openapi::USERS_TAG;
use crate::shared::http::app_state::AppState;
use crate::shared::http::model::session_model::UserSession;
use application::user::use_cases::user::update_user_by_admin::{
    UpdateUserByAdminCommand, UpdateUserByAdminError,
};
use axum::extract::{Extension, Path, State};
use axum::Json;
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;
use validator::Validate;

impl From<UpdateUserByAdminError> for HttpError {
    fn from(value: UpdateUserByAdminError) -> Self {
        match value {
            UpdateUserByAdminError::Forbidden => HttpError::Forbidden,
            UpdateUserByAdminError::UsernameAlreadyExists => {
                HttpError::ResourceAlreadyExist("Username already exists".to_string())
            }
            UpdateUserByAdminError::UserNotFound => HttpError::NotFound("User not found".to_string()),
            UpdateUserByAdminError::InvalidRole => HttpError::BadRequest("Invalid role".to_string()),
            UpdateUserByAdminError::PersistenceError(e) => HttpError::GenericError(e.to_string()),
        }
    }
}

#[derive(Debug, Serialize, Deserialize, Validate, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct UpdateUserByAdminDto {
    pub username: Option<String>,
    pub role: Option<String>,
}

#[utoipa::path(
    put,
    path = "/api/users/{id}",
    tag = USERS_TAG,
    summary = "Update user username and/or role (admin only)",
    request_body = UpdateUserByAdminDto,
    responses(
        (status = 200, description = "User updated"),
        (status = 400, description = "Bad request"),
        (status = 403, description = "Forbidden"),
        (status = 404, description = "User not found"),
    ),
    security(("jwt" = []))
)]
pub async fn update_user_by_admin_api(
    State(state): State<AppState>,
    Extension(user): Extension<UserSession>,
    Path(id): Path<Uuid>,
    Json(payload): Json<UpdateUserByAdminDto>,
) -> HttpResult<()> {
    let cmd = UpdateUserByAdminCommand {
        requester_user_id: user.user_id,
        target_user_id: id,
        new_username: payload.username,
        new_role: payload.role,
    };
    state.user.update_user_by_admin_uc.execute(cmd).await?;
    Ok(())
}
