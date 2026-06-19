use crate::http_error::{HttpError, HttpResult};
use crate::openapi::USERS_TAG;
use crate::shared::http::app_state::AppState;
use crate::shared::http::model::session_model::UserSession;
use application::user::use_cases::user::delete_user::{DeleteUserCommand, DeleteUserError};
use axum::extract::{Extension, Path, State};
use uuid::Uuid;

impl From<DeleteUserError> for HttpError {
    fn from(value: DeleteUserError) -> Self {
        match value {
            DeleteUserError::Forbidden => HttpError::Forbidden,
            DeleteUserError::PersistenceError(e) => HttpError::GenericError(e.to_string()),
        }
    }
}

#[utoipa::path(
    delete,
    path = "/api/users/{id}",
    tag = USERS_TAG,
    summary = "Delete a user (admin only or self)",
    responses(
        (status = 200, description = "User deleted"),
        (status = 403, description = "Forbidden"),
    ),
    security(("jwt" = []))
)]
pub async fn delete_user_api(
    State(state): State<AppState>,
    Extension(user): Extension<UserSession>,
    Path(id): Path<Uuid>,
) -> HttpResult<()> {
    let cmd = DeleteUserCommand {
        target_user_id: id,
        requester_user_id: user.user_id,
    };
    state.user.delete_user_uc.execute(cmd).await?;
    Ok(())
}
