use crate::http_error::{HttpError, HttpResult};
use crate::openapi::USERS_TAG;
use crate::shared::http::app_state::AppState;
use crate::shared::http::model::session_model::UserSession;
use application::user::use_cases::user::admin_change_password::{
    AdminChangePasswordCommand, AdminChangePasswordError,
};
use axum::extract::{Extension, Path, State};
use axum::Json;
use secrecy::SecretBox;
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;
use validator::Validate;

impl From<AdminChangePasswordError> for HttpError {
    fn from(value: AdminChangePasswordError) -> Self {
        match value {
            AdminChangePasswordError::Forbidden => HttpError::Forbidden,
            AdminChangePasswordError::UserNotFound => HttpError::NotFound("User not found".to_string()),
            AdminChangePasswordError::PersistenceError(e) => {
                HttpError::GenericError(e.to_string())
            }
        }
    }
}

#[derive(Debug, Serialize, Deserialize, Validate, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct AdminChangePasswordDto {
    #[validate(length(min = 1, message = "New password is required"))]
    pub new_password: String,
}

#[utoipa::path(
    put,
    path = "/api/users/{id}/password",
    tag = USERS_TAG,
    summary = "Change another user's password (admin only)",
    request_body = AdminChangePasswordDto,
    responses(
        (status = 200, description = "Password updated"),
        (status = 403, description = "Forbidden"),
        (status = 404, description = "User not found"),
    ),
    security(("jwt" = []))
)]
pub async fn admin_change_password_api(
    State(state): State<AppState>,
    Extension(user): Extension<UserSession>,
    Path(id): Path<Uuid>,
    Json(payload): Json<AdminChangePasswordDto>,
) -> HttpResult<()> {
    let cmd = AdminChangePasswordCommand {
        target_user_id: id,
        requester_user_id: user.user_id,
        new_password: SecretBox::new(payload.new_password.into_boxed_str()),
    };
    state.user.admin_change_password_uc.execute(cmd).await?;
    Ok(())
}
