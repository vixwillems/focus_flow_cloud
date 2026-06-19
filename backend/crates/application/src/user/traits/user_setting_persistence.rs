use crate::shared::traits::persistence_error::PersistenceResult;
use async_trait::async_trait;
use domain::user::entities::user_setting::UserSetting;
use uuid::Uuid;

#[cfg_attr(test, mockall::automock)]
#[async_trait]
pub trait UserSettingPersistence: Send + Sync {
    /// Find all settings for a specific user. Used by `GET /api/setting`.
    async fn find_by_user(&self, user_id: Uuid) -> PersistenceResult<Vec<UserSetting>>;

    /// Check whether a (user, key) pair already exists. Used by the update
    /// use case to decide between `update_setting` and `create_setting`.
    async fn exists_for_user(
        &self,
        user_id: Uuid,
        key: &str,
    ) -> PersistenceResult<bool>;

    async fn update_setting(
        &self,
        user_id: Uuid,
        key: String,
        value: String,
    ) -> PersistenceResult<()>;

    async fn create_setting(
        &self,
        user_id: Uuid,
        key: String,
        value: String,
    ) -> PersistenceResult<()>;
}

#[cfg(test)]
mod tests {
    use crate::shared::traits::persistence_error::PersistenceError;

    use super::*;

    #[tokio::test]
    async fn test_find_by_user() {
        let mut mock = MockUserSettingPersistence::new();
        mock.expect_find_by_user().returning(|_| Ok(vec![]));
        let result = mock.find_by_user(Uuid::new_v4()).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_exists_for_user() {
        let mut mock = MockUserSettingPersistence::new();
        mock.expect_exists_for_user().returning(|_, _| Ok(true));
        let result = mock.exists_for_user(Uuid::new_v4(), "key").await;
        assert!(result.is_ok());
        assert!(result.unwrap());
    }

    #[tokio::test]
    async fn test_update_setting() {
        let mut mock = MockUserSettingPersistence::new();
        mock.expect_update_setting().returning(|_, _, _| Ok(()));
        let result = mock
            .update_setting(Uuid::new_v4(), "key".to_string(), "value".to_string())
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_create_setting() {
        let mut mock = MockUserSettingPersistence::new();
        mock.expect_create_setting().returning(|_, _, _| Ok(()));
        let result = mock
            .create_setting(Uuid::new_v4(), "key".to_string(), "value".to_string())
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_create_setting_error() {
        let mut mock = MockUserSettingPersistence::new();
        mock.expect_create_setting()
            .returning(|_, _, _| Err(PersistenceError::Unexpected("test".to_string())));
        let result = mock
            .create_setting(Uuid::new_v4(), "key".to_string(), "value".to_string())
            .await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_update_setting_error() {
        let mut mock = MockUserSettingPersistence::new();
        mock.expect_update_setting()
            .returning(|_, _, _| Err(PersistenceError::Unexpected("test".to_string())));
        let result = mock
            .update_setting(Uuid::new_v4(), "key".to_string(), "value".to_string())
            .await;
        assert!(result.is_err())
    }
}
