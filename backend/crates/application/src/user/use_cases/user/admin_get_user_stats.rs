use std::sync::Arc;

use crate::shared::traits::persistence_error::PersistenceError;
use crate::tasks::traits::focus_session_repository::{
    FindByFiltersCommand, FocusSessionRepository,
};
use crate::user::traits::user_persistence::UserPersistence;
use serde::{Deserialize, Serialize};
use thiserror::Error;
use tracing::instrument;
use uuid::Uuid;

#[derive(Debug, Error)]
pub enum AdminGetUserStatsError {
    #[error("Forbidden")]
    Forbidden,
    #[error("User not found")]
    UserNotFound,
    #[error("Persistence error: {0}")]
    PersistenceError(#[from] PersistenceError),
}

pub type AdminGetUserStatsResult<T> = Result<T, AdminGetUserStatsError>;

#[derive(Debug, Serialize, Deserialize)]
pub struct AdminUserStatsOutput {
    pub total_sessions: i64,
    pub total_focus_duration: i64,
}

pub struct AdminGetUserStatsUseCase {
    user_persistence: Arc<dyn UserPersistence>,
    session_repository: Arc<dyn FocusSessionRepository>,
}

impl AdminGetUserStatsUseCase {
    pub fn new(
        user_persistence: Arc<dyn UserPersistence>,
        session_repository: Arc<dyn FocusSessionRepository>,
    ) -> Self {
        Self {
            user_persistence,
            session_repository,
        }
    }

    #[instrument(skip(self))]
    pub async fn execute(
        &self,
        requester_user_id: Uuid,
        target_user_id: Uuid,
    ) -> AdminGetUserStatsResult<AdminUserStatsOutput> {
        let is_admin = self
            .user_persistence
            .is_user_admin(requester_user_id)
            .await?;
        if !is_admin {
            return Err(AdminGetUserStatsError::Forbidden);
        }

        // Verify target user exists
        self.user_persistence
            .find_user_by_id(target_user_id)
            .await
            .map_err(|e| match e {
                PersistenceError::NotFound(_) => AdminGetUserStatsError::UserNotFound,
                e => AdminGetUserStatsError::PersistenceError(e),
            })?;

        let sessions = self
            .session_repository
            .find_by_filters(FindByFiltersCommand {
                user_id: target_user_id,
                start_date: None,
                end_date: None,
                task_ids: None,
                session_type: None,
                min_concentration_score: None,
                max_concentration_score: None,
                has_notes: None,
            })
            .await?;

        let total_sessions = sessions.len() as i64;
        let total_focus_duration: i64 = sessions.iter().map(|s| s.actual_duration()).sum();

        Ok(AdminUserStatsOutput {
            total_sessions,
            total_focus_duration,
        })
    }
}
