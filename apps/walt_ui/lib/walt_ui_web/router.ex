defmodule WaltUiWeb.Router do
  use WaltUiWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug WaltUiWeb.Plug.StoreReturnPath
    plug :fetch_live_flash
    plug :put_root_layout, {WaltUiWeb.LayoutHTML, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    # plug JSONAPI.EnsureSpec
    plug JSONAPI.Deserializer
    plug JSONAPI.UnderscoreParameters
  end

  pipeline :api_authenticated do
    plug WaltUi.Authentication.Plug
  end

  pipeline :api_streaming do
    plug :accepts, ["json", "event-stream"]
  end

  pipeline :admin_authenticated do
    plug WaltUi.Authentication.AdminPlug
    plug WaltUiWeb.Plug.StrictCacheControl
  end

  pipeline :web_auth do
    plug WaltUi.Authentication.WebPlug
    plug WaltUiWeb.Plug.StrictCacheControl
  end

  scope "/webhooks", WaltUiWeb do
    post "/revenue-cat", RevenueCatWebhookController, :webhooks
  end

  scope "/api", WaltUiWeb.Api do
    pipe_through :api

    get "/apple-sign-in", AppleController, :index
    post "/apple-sign-in", AppleController, :create
  end

  scope "/api", WaltUiWeb.Api do
    pipe_through [:api, :api_authenticated]

    get "/upload/:scope/:extention", ImageController, :upload

    post "/bulk/contacts", ContactsController, :bulk_create
    put "/bulk/contacts", ContactsController, :bulk_upsert

    get "/contacts", ContactsController, :index
    post "/contacts", ContactsController, :create

    get "/contacts/top-contacts", ContactsController, :get_top_contacts
    get "/contacts/:id", ContactsController, :show
    get "/contacts/:id/ptt", ContactsController, :ptt
    put "/contacts/:id", ContactsController, :update
    delete "/contacts/:id", ContactsController, :delete

    get "/contacts/:contact_id/events", Contacts.EventsController, :index
    post "/contacts/:contact_id/events", Contacts.EventsController, :create

    get "/contacts/:contact_id/notes", Contacts.NotesController, :index
    post "/contacts/:contact_id/notes", Contacts.NotesController, :create

    post "/contacts/:id/feedback", Contacts.FeedbackController, :create

    get "/contacts/:contact_id/addresses", Contacts.AddressController, :index
    put "/contacts/:contact_id/addresses", Contacts.AddressController, :update
    post "/contacts/:contact_id/addresses", Contacts.AddressController, :create

    get "/contact-interactions/:contact_id", ContactInteractionsController, :index

    post "/contacts/:contact_id/tags", ContactTagsController, :create
    delete "/contacts/:contact_id/tags/:tag_id", ContactTagsController, :delete

    get "/enrichment-report", EnrichmentReportController, :index

    resources "/documents", DocumentsController, only: [:index, :show]
    get "/documents/:id/envelopes", DocumentsController, :envelopes

    get "/human-loop/text-message/:contact_id", HumanLoopController, :get_text_message

    get "/notes", NotesController, :index
    get "/notes/:id", NotesController, :show
    put "/notes/:id", NotesController, :update

    get "/search", SearchController, :index
    get "/v2/search", SearchController, :new_index

    post "/stripe/checkout-session", StripeController, :create_checkout_session

    get "/user", UsersController, :show
    put "/user", UsersController, :update
    delete "/user", UsersController, :delete

    post "/user/fcm-tokens", FcmController, :create
    put "/user/fcm-tokens/:id", FcmController, :update
    delete "/user/fcm-tokens/:id", FcmController, :delete

    resources "/tags", TagsController, only: [:index, :create, :show, :update, :delete]

    resources "/tasks", TasksController, only: [:index, :create, :update, :delete]
    put "/tasks/:id/complete", TasksController, :complete
    put "/tasks/:id/uncomplete", TasksController, :uncomplete

    get "/external-accounts", ExternalAccountsController, :index
    post "/external-accounts", ExternalAccountsController, :create
    delete "/external-accounts/:id", ExternalAccountsController, :delete

    get "/calendar/events", CalendarsController, :todays_events
    post "/calendar/:calendar_id/appointment", CalendarsController, :create_appointment
    post "/email", EmailController, :send_email
  end

  scope "/api/ai", WaltUiWeb.Api do
    pipe_through [:api_streaming, :api_authenticated]

    get "/usage", AIController, :usage
    post "/query", AIController, :query
  end

  scope "/auth", WaltUiWeb do
    pipe_through :browser

    get "/auth0", AuthController, :request
    get "/auth0/callback", AuthController, :callback
    post "/auth0/callback", AuthController, :callback

    get "/:provider", ExternalAccountAuthController, :request
    get "/:provider/callback", ExternalAccountAuthController, :callback
  end

  scope "/", WaltUiWeb do
    pipe_through :browser

    get "/login", AuthController, :login
    delete "/logout", AuthController, :logout

    live_session :authenticated, on_mount: WaltUiWeb.AuthLiveAssigns do
      live "/", ContactsLive, :index
      live "/contacts", ContactsLive, :index
      live "/contacts/:id", ContactDetailsLive, :show
      live "/agenda", AgendaLive, :show
      live "/settings", SettingsLive, :show
    end

    scope "/manage", Admin do
      live_session :admins, on_mount: WaltUiWeb.AdminAuthLiveAssigns do
        live "/", DashboardLive
        live "/users/:id", UsersLive
        live "/contacts/:id", ContactsLive
      end
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:walt_ui, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev", host: "app." do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: WaltUiWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
