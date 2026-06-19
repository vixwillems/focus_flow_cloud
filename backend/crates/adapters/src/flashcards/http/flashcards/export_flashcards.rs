use axum::{extract::State, Extension, Json};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

use crate::{
    http_error::HttpResult,
    openapi::FLASHCARD_TAG,
    shared::http::{app_state::AppState, model::session_model::UserSession},
};

#[derive(Debug, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ExportCardDto {
    pub front: String,
    pub back: String,
    pub folder_path: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ExportFlashcardsResponseDto {
    pub version: u32,
    pub cards: Vec<ExportCardDto>,
}

async fn collect_all_cards(
    flashcard_persistence: &dyn application::flashcards::traits::flashcard_persistence::FlashcardPersistence,
    folder_id: Uuid,
    path_so_far: String,
    cards: &mut Vec<ExportCardDto>,
) {
    let contents = flashcard_persistence
        .find_by_folder(&folder_id)
        .await
        .unwrap_or_default();
    for card in &contents {
        let folder_path = if path_so_far.is_empty() {
            None
        } else {
            Some(path_so_far.clone())
        };
        cards.push(ExportCardDto {
            front: card.front().to_string(),
            back: card.back().to_string(),
            folder_path,
        });
    }
    let subfolders = flashcard_persistence
        .find_subfolders_by_parent(&folder_id)
        .await
        .unwrap_or_default();
    for sub in &subfolders {
        let sub_path = if path_so_far.is_empty() {
            sub.name().to_string()
        } else {
            format!("{}/{}", path_so_far, sub.name())
        };
        Box::pin(collect_all_cards(
            flashcard_persistence,
            sub.id(),
            sub_path,
            cards,
        ))
        .await;
    }
}

#[utoipa::path(
    get,
    path = "/api/flashcard/all/export",
    tag = FLASHCARD_TAG,
    summary = "Export all flashcards",
    responses(
        (status = 200, description = "Flashcards exported successfully"),
        (status = 401, description = "Unauthorized"),
    ),
    security(("jwt" = []))
)]
pub async fn export_flashcards_api(
    State(state): State<AppState>,
    Extension(user): Extension<UserSession>,
) -> HttpResult<Json<ExportFlashcardsResponseDto>> {
    let root = state
        .flashcards
        .flashcard_persistence
        .find_root_folder_by_user(&user.user_id)
        .await
        .map_err(|_| crate::http_error::HttpError::NotFound("Root folder not found".to_string()))?;

    let mut cards = Vec::new();
    collect_all_cards(
        &*state.flashcards.flashcard_persistence,
        root.id(),
        String::new(),
        &mut cards,
    )
    .await;

    Ok(Json(ExportFlashcardsResponseDto {
        version: 1,
        cards,
    }))
}
