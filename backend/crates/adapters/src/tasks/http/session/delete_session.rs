use crate::http_error::{HttpError, HttpResult};
use crate::openapi::SESSION_TAG;
use crate::shared::http::app_state::AppState;
use crate::shared::http::validators::validate_uuid::validate_uuid;
use application::tasks::use_cases::focus_session::delete_focus_session::DeleteFocusSessionError;

impl From<DeleteFocusSessionError> for HttpError {
    fn from(value: DeleteFocusSessionError) -> Self {
        match value {
            DeleteFocusSessionError::PersistenceError(e) => HttpError::GenericError(e.to_string()),
        }
    }
}
use axum::extract::{Path, State};
use axum::Json;
use serde::{Deserialize, Serialize};
use tracing::debug;
use utoipa::ToSchema;
use uuid::Uuid;
use validator::Validate;

#[derive(Debug, Serialize, Deserialize, Validate, ToSchema)]
pub struct DeleteFocusSessionPathDto {
    #[validate(custom(function = "validate_uuid"))]
    pub id: String,
}

#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct DeleteFocusSessionResponseDto {}

#[utoipa::path(
    delete,
    path = "/api/focus-sessions/{id}",
    tag = SESSION_TAG,
    summary = "Delete focus session",
    responses(
        (status = 204, description = "Session deleted successfully"),
        (status = 400, description = "Bad request - validation error"),
        (status = 401, description = "Unauthorized"),
        (status = 500, description = "Internal server error")
    ),
    security(
        ("jwt" = [])
    )
)]
pub async fn delete_session_api(
    State(state): State<AppState>,
    Path(path): Path<DeleteFocusSessionPathDto>,
) -> HttpResult<Json<DeleteFocusSessionResponseDto>> {
    debug!("Deleting session: {:?}", path);

    path.validate()
        .map_err(|e| HttpError::BadRequest(e.to_string()))?;

    let session_id = Uuid::parse_str(&path.id)
        .map_err(|_| HttpError::BadRequest("Invalid session id".to_string()))?;

    state.tasks.delete_focus_session_uc.execute(session_id).await?;

    Ok(Json(DeleteFocusSessionResponseDto {}))
}
