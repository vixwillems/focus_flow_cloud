use std::sync::Arc;

use crate::shared::traits::persistence_error::PersistenceError;
use crate::user::traits::user_persistence::UserPersistence;
use domain::user::entities::user_role::UserRole;
use thiserror::Error;
use tracing::instrument;
use uuid::Uuid;

#[derive(Debug, Error)]
pub enum UpdateUserByAdminError {
    #[error("Forbidden")]
    Forbidden,

    #[error("Username already exists")]
    UsernameAlreadyExists,

    #[error("User not found")]
    UserNotFound,

    #[error("Invalid role")]
    InvalidRole,

    #[error("Persistence error: {0}")]
    PersistenceError(#[from] PersistenceError),
}

pub type UpdateUserByAdminResult<T> = Result<T, UpdateUserByAdminError>;

#[derive(Debug)]
pub struct UpdateUserByAdminCommand {
    pub requester_user_id: Uuid,
    pub target_user_id: Uuid,
    pub new_username: Option<String>,
    pub new_role: Option<String>,
}

pub struct UpdateUserByAdminUseCase {
    user_persistence: Arc<dyn UserPersistence>,
}

impl UpdateUserByAdminUseCase {
    pub fn new(user_persistence: Arc<dyn UserPersistence>) -> Self {
        Self { user_persistence }
    }

    #[instrument(skip(self))]
    pub async fn execute(&self, cmd: UpdateUserByAdminCommand) -> UpdateUserByAdminResult<()> {
        let is_admin = self
            .user_persistence
            .is_user_admin(cmd.requester_user_id)
            .await?;
        if !is_admin {
            return Err(UpdateUserByAdminError::Forbidden);
        }

        let mut user = self
            .user_persistence
            .find_user_by_id(cmd.target_user_id)
            .await
            .map_err(|e| match e {
                PersistenceError::NotFound(_) => UpdateUserByAdminError::UserNotFound,
                e => UpdateUserByAdminError::PersistenceError(e),
            })?;

        if let Some(ref new_username) = cmd.new_username {
            if user.username() != new_username {
                if self
                    .user_persistence
                    .find_user_by_username(new_username)
                    .await
                    .is_ok()
                {
                    return Err(UpdateUserByAdminError::UsernameAlreadyExists);
                }
                user.update_username(new_username.clone());
            }
        }

        if let Some(ref new_role) = cmd.new_role {
            let role = match new_role.to_lowercase().as_str() {
                "admin" => UserRole::Admin,
                "user" => UserRole::User,
                _ => return Err(UpdateUserByAdminError::InvalidRole),
            };
            user.update_role(role);
        }

        self.user_persistence.update_user(user).await?;
        Ok(())
    }
}
