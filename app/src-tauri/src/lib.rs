mod live_activity;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
  tauri::Builder::default()
    .plugin(tauri_plugin_notification::init())
    .invoke_handler(tauri::generate_handler![
      live_activity::live_activity_is_available,
      live_activity::live_activity_is_enabled,
      live_activity::live_activity_set_enabled,
      live_activity::live_activity_start,
      live_activity::live_activity_update,
      live_activity::live_activity_end,
      live_activity::live_activity_end_all,
    ])
    .setup(|app| {
      if cfg!(debug_assertions) {
        app.handle().plugin(
          tauri_plugin_log::Builder::default()
            .level(log::LevelFilter::Info)
            .build(),
        )?;
      }
      Ok(())
    })
    .run(tauri::generate_context!())
    .expect("error while running tauri application");
}
