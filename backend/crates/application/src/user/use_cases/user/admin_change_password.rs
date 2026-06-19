use crate::shared::traits::persistence_error::PersistenceError;
use crate::user::traits::user_persistence::UserPersistence;
use secrecy::{ExposeSecret, SecretBox};
use std::sync::Arc;
use thiserror::Error;
use tracing::instrument;
use uuid::Uuid;

#[derive(Debug, Error)]
pub enum AdminChangePasswordError {
    #[error("Forbidden")]
    Forbidden,
    #[error("User not found")]
    UserNotFound,
    #[error("Persistence error: {0}")]
    PersistenceError(#[from] PersistenceError),
}

pub type AdminChangePasswordResult<T> = Result<T, AdminChangePasswordError>;

#[derive(Debug)]
pub struct AdminChangePasswordCommand {
    pub target_user_id: Uuid,
    pub requester_user_id: Uuid,
    pub new_password: SecretBox<str>,
}

pub struct AdminChangePasswordUseCase {
    user_persistence: Arc<dyn UserPersistence>,
}

impl AdminChangePasswordUseCase {
    pub fn new(user_persistence: Arc<dyn UserPersistence>) -> Self {
        Self { user_persistence }
    }

    #[instrument(skip(self))]
    pub async fn execute(&self, cmd: AdminChangePasswordCommand) -> AdminChangePasswordResult<()> {
        let is_admin = self
            .user_persistence
            .is_user_admin(cmd.requester_user_id)
            .await?;
        if !is_admin {
            return Err(AdminChangePasswordError::Forbidden);
        }

        let mut user = self
            .user_persistence
            .find_user_by_id(cmd.target_user_id)
            .await
            .map_err(|_| AdminChangePasswordError::UserNotFound)?;

        user.update_password(cmd.new_password.expose_secret().to_string());
        self.user_persistence.update_user(user).await?;

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::user::traits::user_persistence::MockUserPersistence;
    use domain::user::entities::user::User;
    use domain::user::entities::user_role::UserRole;

    #[tokio::test]
    async fn test_admin_change_password_success() {
        let mut mock = MockUserPersistence::new();
        let target_id = Uuid::new_v4();
        let user = User::reconstitute(target_id, "test".into(), "old_hash".into(), UserRole::User);

        mock.expect_is_user_admin().returning(|_| Ok(true));
        mock.expect_find_user_by_id()
            .returning(move |_| Ok(user.clone()));
        mock.expect_update_user().returning(|_| Ok(()));

        let uc = AdminChangePasswordUseCase::new(Arc::new(mock));
        let result = uc
            .execute(AdminChangePasswordCommand {
                target_user_id: target_id,
                requester_user_id: Uuid::new_v4(),
                new_password: SecretBox::new(Box::from("new_pass")),
            })
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_admin_change_password_forbidden() {
        let mut mock = MockUserPersistence::new();
        mock.expect_is_user_admin().returning(|_| Ok(false));

        let uc = AdminChangePasswordUseCase::new(Arc::new(mock));
        let result = uc
            .execute(AdminChangePasswordCommand {
                target_user_id: Uuid::new_v4(),
                requester_user_id: Uuid::new_v4(),
                new_password: SecretBox::new(Box::from("new_pass")),
            })
            .await;
        assert!(matches!(result, Err(AdminChangePasswordError::Forbidden)));
    }
}
