use crate::shared::traits::persistence_error::PersistenceError;
use crate::tasks::traits::focus_session_repository::FocusSessionRepository;
use std::sync::Arc;
use thiserror::Error;
use tracing::instrument;
use uuid::Uuid;

#[derive(Debug, Error, PartialEq)]
pub enum DeleteFocusSessionError {
    #[error("Persistence error: {0}")]
    PersistenceError(#[from] PersistenceError),
}

pub type DeleteFocusSessionResult<T> = Result<T, DeleteFocusSessionError>;

pub struct DeleteFocusSessionUseCase {
    session_persistence: Arc<dyn FocusSessionRepository>,
}

impl DeleteFocusSessionUseCase {
    pub fn new(session_persistence: Arc<dyn FocusSessionRepository>) -> Self {
        Self {
            session_persistence,
        }
    }

    #[instrument(skip(self))]
    pub async fn execute(
        &self,
        session_id: Uuid,
    ) -> DeleteFocusSessionResult<()> {
        Ok(self.session_persistence.delete_session(session_id).await?)
    }
}
