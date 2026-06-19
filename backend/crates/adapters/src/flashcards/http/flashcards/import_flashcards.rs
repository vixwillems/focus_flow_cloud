use application::flashcards::use_cases::create_flashcards::CreateFlashcardCommand;
use application::flashcards::use_cases::create_folder::CreateFolderCommand;
use axum::{extract::State, Extension, Json};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;
use validator::Validate;

use crate::{
    http_error::{HttpError, HttpResult},
    openapi::FLASHCARD_TAG,
    shared::http::{app_state::AppState, model::session_model::UserSession},
};

#[derive(Debug, Serialize, Deserialize, Validate, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ImportCardDto {
    #[validate(length(min = 1, max = 500))]
    pub front: String,
    #[validate(length(min = 1, max = 500))]
    pub back: String,
    pub folder_path: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Validate, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ImportFlashcardsDto {
    pub version: u32,
    #[validate(length(min = 1))]
    pub cards: Vec<ImportCardDto>,
}

#[derive(Debug, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ImportFlashcardsResponseDto {
    pub imported: usize,
}

async fn ensure_folder_path(
    flashcard_persistence: &dyn application::flashcards::traits::flashcard_persistence::FlashcardPersistence,
    create_folder_uc: &application::flashcards::use_cases::create_folder::CreateFolderUseCase,
    user_id: Uuid,
    path: &str,
) -> Result<Uuid, HttpError> {
    let root = flashcard_persistence
        .find_root_folder_by_user(&user_id)
        .await
        .map_err(|_| HttpError::NotFound("Root folder not found".to_string()))?;

    if path.is_empty() {
        return Ok(root.id());
    }

    let parts: Vec<&str> = path.split('/').collect();
    let mut parent_id = root.id();

    for part in &parts {
        let trimmed = part.trim();
        if trimmed.is_empty() {
            continue;
        }
        let subfolders = flashcard_persistence
            .find_subfolders_by_parent(&parent_id)
            .await
            .unwrap_or_default();
        let existing = subfolders.iter().find(|f| f.name() == trimmed);
        match existing {
            Some(f) => parent_id = f.id(),
            None => {
                let folder = create_folder_uc
                    .execute(CreateFolderCommand {
                        name: trimmed.to_string(),
                        user_id,
                        parent_id,
                    })
                    .await
                    .map_err(|e| HttpError::GenericError(format!("Failed to create folder: {}", e)))?;
                parent_id = folder.id();
            }
        }
    }

    Ok(parent_id)
}

#[utoipa::path(
    post,
    path = "/api/flashcard/all/import",
    tag = FLASHCARD_TAG,
    summary = "Import flashcards",
    request_body = ImportFlashcardsDto,
    responses(
        (status = 200, description = "Flashcards imported successfully"),
        (status = 400, description = "Bad request"),
        (status = 401, description = "Unauthorized"),
    ),
    security(("jwt" = []))
)]
pub async fn import_flashcards_api(
    State(state): State<AppState>,
    Extension(user): Extension<UserSession>,
    Json(payload): Json<ImportFlashcardsDto>,
) -> HttpResult<Json<ImportFlashcardsResponseDto>> {
    payload
        .validate()
        .map_err(|e| HttpError::BadRequest(e.to_string()))?;

    let mut imported = 0usize;
    for card in &payload.cards {
        let folder_id = match &card.folder_path {
            Some(path) => {
                ensure_folder_path(
                    &*state.flashcards.flashcard_persistence,
                    &state.flashcards.create_folder_uc,
                    user.user_id,
                    path,
                )
                .await?
            }
            None => {
                let root = state
                    .flashcards
                    .flashcard_persistence
                    .find_root_folder_by_user(&user.user_id)
                    .await
                    .map_err(|_| {
                        HttpError::NotFound("Root folder not found".to_string())
                    })?;
                root.id()
            }
        };

        state
            .flashcards
            .create_flashcard_uc
            .execute(CreateFlashcardCommand {
                front: card.front.clone(),
                back: card.back.clone(),
                user_id: user.user_id,
                folder_id,
            })
            .await
            .map_err(|e| HttpError::GenericError(format!("Failed to create card: {}", e)))?;

        imported += 1;
    }

    Ok(Json(ImportFlashcardsResponseDto { imported }))
}
