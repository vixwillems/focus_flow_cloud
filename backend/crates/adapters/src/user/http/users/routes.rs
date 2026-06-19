use crate::shared::http::app_state::AppState;
use crate::user::http::users::admin_change_password::admin_change_password_api;
use crate::user::http::users::admin_get_user_stats::admin_get_user_stats_api;
use crate::user::http::users::create_user::create_user_api;
use crate::user::http::users::delete_user::delete_user_api;
use crate::user::http::users::get_info::get_user_info_api;
use crate::user::http::users::list_users::list_users_api;
use crate::user::http::users::update_password::update_password_api;
use crate::user::http::users::update_user_by_admin::update_user_by_admin_api;
use crate::user::http::users::update_username::update_username_api;
use axum::routing::{get, post, put};
use axum::Router;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/", post(create_user_api))
        .route("/", get(list_users_api))
        .route("/password", put(update_password_api))
        .route("/username", put(update_username_api))
        .route("/me", get(get_user_info_api))
        .route("/{id}", put(update_user_by_admin_api).delete(delete_user_api))
        .route("/{id}/password", put(admin_change_password_api))
        .route("/{id}/stats", get(admin_get_user_stats_api))
}
