resource "google_storage_bucket" "hey-walt-contacts" {
  name     = "hey-walt-contacts"
  location = "US"

  public_access_prevention    = "inherited"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.hey-walt-contacts.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "random_id" "db_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "main" {
  name                = "walt-ui-${random_id.db_suffix.hex}"
  database_version    = "POSTGRES_15"
  deletion_protection = true

  lifecycle {
    ignore_changes = [settings[0].disk_size]
  }

  settings {
    tier                  = "db-custom-8-32768"
    disk_size             = 10
    disk_autoresize       = true
    disk_autoresize_limit = 100
    connector_enforcement = "NOT_REQUIRED"

    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled    = var.db_backup_enabled
      start_time = "06:00"

      backup_retention_settings {
        retention_unit   = "COUNT"
        retained_backups = 3
      }
    }

    maintenance_window {
      day          = 6
      hour         = 7
      update_track = "stable"
    }
  }
}

resource "google_sql_database_instance" "replica" {
  name                 = "walt-ui-${random_id.db_suffix.hex}-replica"
  database_version     = "POSTGRES_15"
  master_instance_name = google_sql_database_instance.main.name

  lifecycle {
    ignore_changes = [
      settings[0].disk_autoresize_limit,
      settings[0].disk_size
    ]
  }

  replica_configuration {
    username                  = "postgresreplica"
    password                  = data.google_secret_manager_secret_version.replica-password.secret_data
    ssl_cipher                = "ALL"
    verify_server_certificate = false
  }

  settings {
    tier              = "db-custom-2-7680"
    disk_size         = 20
    availability_type = "REGIONAL"

    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ENCRYPTED_ONLY"
      
      authorized_networks {
        name  = "posthog-ip-1"
        value = "44.205.89.55"
      }
      
      authorized_networks {
        name  = "posthog-ip-2"
        value = "44.208.188.173"
      }
      
      authorized_networks {
        name  = "posthog-ip-3"
        value = "52.4.194.122"
      }
    }

    backup_configuration {
      enabled = false
    }
  }
}

resource "google_sql_user" "user" {
  instance = google_sql_database_instance.main.name
  name     = "postgres"
  password = data.google_secret_manager_secret_version.db-password.secret_data
  type     = "BUILT_IN"
}

resource "google_sql_user" "readonly_user" {
  instance = google_sql_database_instance.main.name
  name     = "readonly"
  password = data.google_secret_manager_secret_version.readonly-db-password.secret_data
  type     = "BUILT_IN"
}

resource "google_sql_user" "posthog_user" {
  instance = google_sql_database_instance.main.name
  name     = "posthog"
  password = data.google_secret_manager_secret_version.posthog-db-password.secret_data
  type     = "BUILT_IN"
}

resource "google_sql_database_instance" "house_canary" {
  name                = "house-canary-${random_id.db_suffix.hex}"
  database_version    = "POSTGRES_15"
  deletion_protection = true

  lifecycle {
    ignore_changes = [settings[0].disk_size]
  }

  settings {
    tier                  = "db-custom-2-7680"
    disk_size             = 150
    disk_autoresize       = true
    disk_autoresize_limit = 250
    connector_enforcement = "NOT_REQUIRED"

    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled = false
    }

    maintenance_window {
      day          = 6
      hour         = 7
      update_track = "stable"
    }
  }
}

resource "google_sql_database" "house_canary" {
  name     = "house_canary"
  instance = google_sql_database_instance.house_canary.name
}

resource "google_sql_user" "house_canary_user" {
  instance = google_sql_database_instance.house_canary.name
  name     = "postgres"
  password = data.google_secret_manager_secret_version.house-canary-db-password.secret_data
  type     = "BUILT_IN"
}

resource "google_storage_bucket" "house-canary-imports" {
  name     = "walt-house-canary-imports"
  location = "US"

  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "snowflake_gcs_export" {
  bucket = google_storage_bucket.house-canary-imports.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:kjz930000@prod3-f617.iam.gserviceaccount.com"
}

resource "google_pubsub_topic" "create-contacts" {
  name = "create-contacts"
}

resource "google_pubsub_subscription" "create-contacts-consumer" {
  name                  = "create-contacts-consumer"
  topic                 = google_pubsub_topic.create-contacts.name
  ack_deadline_seconds  = 300
  retain_acked_messages = true

  retry_policy {
    minimum_backoff = "60s"
    maximum_backoff = "600s"
  }
}

resource "google_pubsub_topic" "upsert-contacts" {
  name = "upsert-contacts"
}

resource "google_pubsub_subscription" "upsert-contacts-consumer" {
  name                  = "upsert-contacts-consumer"
  topic                 = google_pubsub_topic.upsert-contacts.name
  ack_deadline_seconds  = 300
  retain_acked_messages = true

  retry_policy {
    minimum_backoff = "60s"
    maximum_backoff = "600s"
  }
}

module "gce-container" {
  source  = "terraform-google-modules/container-vm/google"
  version = "~> 3.1"

  container = {
    image = "${var.image}:${var.image_tag}"

    env = [
      {
        name  = "APPSIGNAL_PUSH_API_KEY"
        value = data.google_secret_manager_secret_version.appsignal-push-api-key.secret_data
      },
      {
        name  = "AUTH0_API_CLIENT_ID"
        value = data.google_secret_manager_secret_version.auth0-api-client-id.secret_data
      },
      {
        name  = "AUTH0_API_CLIENT_SECRET"
        value = data.google_secret_manager_secret_version.auth0-api-client-secret.secret_data
      },
      {
        name  = "AUTH0_AUTH_CLIENT_ID"
        value = data.google_secret_manager_secret_version.auth0-auth-client-id.secret_data
      },
      {
        name  = "AUTH0_AUTH_CLIENT_SECRET"
        value = data.google_secret_manager_secret_version.auth0-auth-client-secret.secret_data
      },
      {
        name  = "AUTH0_DOMAIN"
        value = "dev-vq6htmkq1zxm2lfv.us.auth0.com"
      },
      {
        name  = "AUTH0_URL"
        value = "https://dev-vq6htmkq1zxm2lfv.us.auth0.com"
      },
      {
        name  = "DB_CONNECTION"
        value = google_sql_database_instance.main.connection_name
      },
      {
        name  = "DB_PASSWORD"
        value = data.google_secret_manager_secret_version.db-password.secret_data
      },
      {
        name  = "ENDATO_API_KEY"
        value = data.google_secret_manager_secret_version.endato-api-key.secret_data
      },
      {
        name  = "ENDATO_API_ID"
        value = data.google_secret_manager_secret_version.endato-api-id.secret_data
      },
      {
        name  = "ENDATO_URL"
        value = "https://devapi.endato.com/"
      },
      {
        name  = "FARADAY_API_KEY"
        value = data.google_secret_manager_secret_version.faraday-api-key.secret_data
      },
      {
        name  = "FARADAY_API_URL"
        value = "https://api.faraday.ai/v1/targets/8a7b93b3-06e5-4d9c-9814-d1cd79bbe7e9/lookup"
      },
      {
        name  = "GIT_SHA"
        value = var.image_tag
      },
      {
        name  = "GOOGLE_API_KEY"
        value = data.google_secret_manager_secret_version.google-api-key.secret_data
      },
      {
        name  = "GOOGLE_ANDROID_CLIENT_ID"
        value = data.google_secret_manager_secret_version.google-android-client-id.secret_data
      },
      {
        name  = "GOOGLE_IOS_CLIENT_ID"
        value = data.google_secret_manager_secret_version.google-ios-client-id.secret_data
      },
      {
        name  = "GOOGLE_CLIENT_ID"
        value = data.google_secret_manager_secret_version.google-client-id.secret_data
      },
      {
        name  = "GOOGLE_CLIENT_SECRET"
        value = data.google_secret_manager_secret_version.google-client-secret.secret_data
      },
      {
        name  = "GOOGLE_CUSTOM_SEARCH_ENGINE_ID"
        value = data.google_secret_manager_secret_version.google-custom-search-engine-id.secret_data
      },
      {
        name  = "HUMANLOOP_API_KEY"
        value = data.google_secret_manager_secret_version.humanloop-api-key.secret_data
      },
      {
        name  = "MAILCHIMP_API_KEY"
        value = data.google_secret_manager_secret_version.mailchimp-api-key.secret_data
      },
      {
        name  = "OPENAI_KEY"
        value = data.google_secret_manager_secret_version.openai-key.secret_data
      },
      {
        name  = "OPENAI_ORGANIZATION_KEY"
        value = data.google_secret_manager_secret_version.openai-organization-key.secret_data
      },
      {
        name  = "RELEASE_COOKIE"
        value = data.google_secret_manager_secret_version.cookie.secret_data
      },
      {
        name  = "REVENUE_CAT_AUTH_SECRET"
        value = data.google_secret_manager_secret_version.revenue-cat-auth-secret.secret_data
      },
      {
        name  = "REVENUE_CAT_STRIPE_PUBLIC_API_KEY"
        value = data.google_secret_manager_secret_version.revenue-cat-stripe-public-api-key.secret_data
      },
      {
        name  = "SECRET_KEY_BASE"
        value = data.google_secret_manager_secret_version.secret-key-base.secret_data
      },
      {
        name  = "SKYSLOPE_CLIENT_ID"
        value = data.google_secret_manager_secret_version.skyslope-client-id.secret_data
      },
      {
        name  = "STRIPE_API_KEY"
        value = data.google_secret_manager_secret_version.stripe-api-key.secret_data
      },
      {
        name  = "STRIPE_SIGNING_SECRET"
        value = data.google_secret_manager_secret_version.stripe-signing-secret.secret_data
      },
      {
        name  = "TRESTLE_API_KEY"
        value = data.google_secret_manager_secret_version.trestle-api-key.secret_data
      },
      {
        name  = "TYPESENSE_HOST"
        value = "g1z9q56sdmwfhi3tp.a1.typesense.net"
      },
      {
        name  = "TYPESENSE_KEY"
        value = data.google_secret_manager_secret_version.typesense-key.secret_data
      },
      {
        name  = "WALT_UI_SERVICE_ACCOUNT_JSON"
        value = data.google_secret_manager_secret_version.sa-credentials.secret_data
      },
      {
        name  = "HOUSE_CANARY_DB_CONNECTION"
        value = google_sql_database_instance.house_canary.connection_name
      },
      {
        name  = "HOUSE_CANARY_DB_PASSWORD"
        value = data.google_secret_manager_secret_version.house-canary-db-password.secret_data
      }
    ]
  }

  restart_policy = "Always"
}

module "mig_template" {
  source      = "terraform-google-modules/vm/google//modules/instance_template"
  version     = "~> 14.0"
  project_id  = var.project_id
  region      = "us-east5"
  name_prefix = "walt-ui"

  network    = "default"
  subnetwork = "default"

  source_image_family  = "cos-stable"
  source_image_project = "cos-cloud"

  machine_type = "e2-highcpu-8"

  service_account = {
    email  = "walt-ui-service-account@${var.project_id}.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }

  metadata = {
    "gce-container-declaration" = module.gce-container.metadata_value
    "user-data"                 = file("cloud-init.yml")
  }

  tags = ["http-server"]
}

module "mig" {
  source     = "terraform-google-modules/vm/google//modules/mig"
  version    = "~> 14.0"
  project_id = var.project_id
  region     = "us-east5"

  instance_template = module.mig_template.self_link
  mig_name          = "walt-ui-group"
  hostname          = "walt-ui"
  target_size       = 1

  health_check_name = "walt-ui-health-check"
  health_check = {
    type         = "http"
    port         = 8080
    request_path = "/api/health-check"

    initial_delay_sec   = 45
    check_interval_sec  = 5
    timeout_sec         = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    enable_logging      = false

    host         = ""
    proxy_header = "NONE"
    request      = ""
    response     = ""
  }

  named_ports = [
    { name = "http", port = 8080 },
    { name = "www", port = 8008 },
    { name = "epmd", port = 4369 },
    { name = "erl1", port = 9996 },
    { name = "erl2", port = 9997 },
    { name = "erl3", port = 9998 },
    { name = "erl4", port = 9999 }
  ]

  update_policy = [{
    type                           = "PROACTIVE"
    replacement_method             = "SUBSTITUTE"
    most_disruptive_allowed_action = "REPLACE"
    minimal_action                 = "REPLACE"
    max_surge_fixed                = 3
    max_unavailable_fixed          = 0
    min_ready_sec                  = 10

    max_surge_percent            = null
    max_unavailable_percent      = null
    instance_redistribution_type = null
  }]
}

resource "google_compute_backend_service" "lb-backend" {
  name          = "walt-ui-backend"
  health_checks = [module.mig.health_check_self_links[0]]
  timeout_sec   = 1800
  port_name     = "http"

  backend {
    group           = module.mig.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1
    max_utilization = 0.8
  }
}

resource "google_compute_backend_service" "lb-marketing" {
  name          = "walt-ui-marketing"
  timeout_sec   = 1800
  health_checks = [google_compute_health_check.marketing-health-check.self_link]
  port_name     = "www"

  backend {
    group           = module.mig.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1
    max_utilization = 0.8
  }
}

resource "google_compute_health_check" "marketing-health-check" {
  name               = "marketing-helath-check"
  timeout_sec        = 5
  check_interval_sec = 30

  http_health_check {
    port               = 8008
    port_specification = "USE_FIXED_PORT"
    request_path       = "/health-check"
  }
}
