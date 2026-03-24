data "google_secret_manager_secret_version" "appsignal-push-api-key" {
  secret  = "appsignal_push_api_key"
  version = 1
}

data "google_secret_manager_secret_version" "auth0-api-client-id" {
  secret  = "auth0_api_client_id"
  version = 1
}

data "google_secret_manager_secret_version" "auth0-api-client-secret" {
  secret  = "auth0_api_client_secret"
  version = 1
}

data "google_secret_manager_secret_version" "auth0-auth-client-id" {
  secret  = "auth0_auth_client_id"
  version = 1
}

data "google_secret_manager_secret_version" "auth0-auth-client-secret" {
  secret  = "auth0_auth_client_secret"
  version = 1
}

data "google_secret_manager_secret_version" "cookie" {
  secret  = "walt_ui_release_cookie"
  version = 1
}

data "google_secret_manager_secret_version" "db-password" {
  secret  = "walt_ui_database_password"
  version = 1
}

data "google_secret_manager_secret_version" "endato-api-id" {
  secret  = "endato_api_id"
  version = 1
}

data "google_secret_manager_secret_version" "endato-api-key" {
  secret  = "endato_api_key"
  version = 1
}

data "google_secret_manager_secret_version" "faraday-api-key" {
  secret  = "faraday_api_key"
  version = 1
}

data "google_secret_manager_secret_version" "google-api-key" {
  secret  = "google_api_key"
  version = 1
}

data "google_secret_manager_secret_version" "google-android-client-id" {
  secret  = "google_android_client_id"
  version = 1
}

data "google_secret_manager_secret_version" "google-ios-client-id" {
  secret  = "google_ios_client_id"
  version = 1
}

data "google_secret_manager_secret_version" "google-client-id" {
  secret  = "google_client_id"
  version = 1
}

data "google_secret_manager_secret_version" "google-client-secret" {
  secret  = "google_client_secret"
  version = 1
}

data "google_secret_manager_secret_version" "google-custom-search-engine-id" {
  secret  = "google_custom_search_engine_id"
  version = 1
}

data "google_secret_manager_secret_version" "humanloop-api-key" {
  secret  = "humanloop_api_key"
  version = 1
}

data "google_secret_manager_secret_version" "mailchimp-api-key" {
  secret  = "mailchimp_api_key"
  version = 1
}

data "google_secret_manager_secret_version" "openai-key" {
  secret  = "openai_key"
  version = 1
}

data "google_secret_manager_secret_version" "openai-organization-key" {
  secret  = "openai_organization_key"
  version = 1
}

data "google_secret_manager_secret_version" "replica-password" {
  secret  = "walt_ui_replica_password"
  version = 1
}

data "google_secret_manager_secret_version" "revenue-cat-auth-secret" {
  secret  = "revenue_cat_auth_secret"
  version = 1
}

data "google_secret_manager_secret_version" "revenue-cat-stripe-public-api-key" {
  secret  = "revenue_cat_stripe_public_api_key"
  version = 1
}

data "google_secret_manager_secret_version" "sa-credentials" {
  secret  = "walt_ui_service_account_json"
  version = 1
}

data "google_secret_manager_secret_version" "secret-key-base" {
  secret  = "walt_ui_secret_key_base"
  version = 1
}

data "google_secret_manager_secret_version" "skyslope-client-id" {
  secret  = "skyslope_client_id"
  version = 1
}

data "google_secret_manager_secret_version" "stripe-api-key" {
  secret  = "stripe_api_key"
  version = 1
}

data "google_secret_manager_secret_version" "stripe-signing-secret" {
  secret  = "stripe_signing_secret"
  version = 1
}

data "google_secret_manager_secret_version" "trestle-api-key" {
  secret  = "trestle_api_key"
  version = 1
}

data "google_secret_manager_secret_version" "typesense-key" {
  secret  = "typesense_key"
  version = 1
}

data "google_secret_manager_secret_version" "readonly-db-password" {
  secret  = "walt_ui_readonly_db_password"
  version = 1
}

data "google_secret_manager_secret_version" "posthog-db-password" {
  secret  = "walt_ui_posthog_db_password"
  version = 1
}

data "google_secret_manager_secret_version" "house-canary-db-password" {
  secret  = "house_canary_database_password"
  version = 1
}
