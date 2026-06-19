use crate::shared::traits::persistence_error::PersistenceError;
use crate::user::traits::user_persistence::UserPersistence;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use thiserror::Error;
use tracing::instrument;
use uuid::Uuid;

#[derive(Debug, Error)]
pub enum ListUsersError {
    #[error("Forbidden")]
    Forbidden,
    #[error("Persistence error: {0}")]
    PersistenceError(#[from] PersistenceError),
}

pub type ListUsersResult<T> = Result<T, ListUsersError>;

#[derive(Debug, Serialize, Deserialize)]
pub struct UserListItem {
    pub id: Uuid,
    pub username: String,
    pub role: String,
}

pub struct ListUsersUseCase {
    user_persistence: Arc<dyn UserPersistence>,
}

impl ListUsersUseCase {
    pub fn new(user_persistence: Arc<dyn UserPersistence>) -> Self {
        Self { user_persistence }
    }

    #[instrument(skip(self))]
    pub async fn execute(&self, requester_user_id: Uuid) -> ListUsersResult<Vec<UserListItem>> {
        let is_admin = self
            .user_persistence
            .is_user_admin(requester_user_id)
            .await?;
        if !is_admin {
            return Err(ListUsersError::Forbidden);
        }

        let users = self.user_persistence.find_all_users().await?;
        Ok(users
            .into_iter()
            .map(|u| UserListItem {
                id: u.id(),
                username: u.username().to_string(),
                role: u.role().to_string(),
            })
            .collect())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::user::traits::user_persistence::MockUserPersistence;
    use domain::user::entities::user::User;
    use domain::user::entities::user_role::UserRole;

    #[tokio::test]
    async fn test_list_users_by_admin() {
        let mut mock = MockUserPersistence::new();
        mock.expect_is_user_admin().returning(|_| Ok(true));
        mock.expect_find_all_users().returning(|| Ok(vec![]));

        let uc = ListUsersUseCase::new(Arc::new(mock));
        let result = uc.execute(Uuid::new_v4()).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_list_users_forbidden() {
        let mut mock = MockUserPersistence::new();
        mock.expect_is_user_admin().returning(|_| Ok(false));

        let uc = ListUsersUseCase::new(Arc::new(mock));
        let result = uc.execute(Uuid::new_v4()).await;
        assert!(matches!(result, Err(ListUsersError::Forbidden)));
    }
}
