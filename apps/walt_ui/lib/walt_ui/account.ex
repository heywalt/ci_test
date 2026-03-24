defmodule WaltUi.Account do
  @moduledoc """
  The Account context.
  """
  import Ecto.Query, warn: false

  alias WaltUi.Account.Session
  alias WaltUi.Account.User
  alias WaltUi.Contacts
  alias WaltUi.Mailchimp

  # Users
  @spec list_users() :: [User.t()]
  def list_users do
    Repo.all(User)
  end

  @spec list_users_with_contact_counts() :: Scrivener.Page.t()
  def list_users_with_contact_counts do
    list_users_with_contact_counts(order_by: :inserted_at, order: :desc)
  end

  @spec list_users_with_contact_counts(keyword()) :: Scrivener.Page.t()
  def list_users_with_contact_counts(opts) do
    order_by = Keyword.get(opts, :order_by, :inserted_at)
    order = Keyword.get(opts, :order, :desc)
    search = Keyword.get(opts, :search, "")
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 50)

    contact_count_subquery = contact_count_subquery()

    from(u in User,
      as: :user,
      select_merge: %{contact_count: subquery(contact_count_subquery)}
    )
    |> apply_search_filter(search)
    |> apply_sorting(order_by, order, contact_count_subquery)
    |> Repo.paginate(page: page, page_size: page_size)
  end

  # Use subquery for contact count - avoids GROUP BY which breaks Scrivener
  defp contact_count_subquery do
    from(c in WaltUi.Projections.Contact,
      where: c.user_id == parent_as(:user).id,
      select: count(c.id)
    )
  end

  defp apply_search_filter(query, ""), do: query

  defp apply_search_filter(query, search) do
    case Ecto.UUID.cast(search) do
      {:ok, uuid} ->
        from(u in query, where: u.id == ^uuid)

      :error ->
        search_term = "%#{search}%"

        from(u in query,
          where:
            ilike(u.email, ^search_term) or
              ilike(u.first_name, ^search_term) or
              ilike(u.last_name, ^search_term) or
              ilike(u.phone, ^search_term)
        )
    end
  end

  defp apply_sorting(query, :name, order, _subquery) do
    from(u in query,
      order_by: [{^order, fragment("? || ' ' || ?", u.first_name, u.last_name)}]
    )
  end

  defp apply_sorting(query, :email, order, _subquery) do
    from(u in query, order_by: [{^order, u.email}])
  end

  defp apply_sorting(query, :contact_count, order, contact_count_subquery) do
    from(u in query, order_by: [{^order, subquery(contact_count_subquery)}])
  end

  defp apply_sorting(query, :inserted_at, order, _subquery) do
    from(u in query, order_by: [{^order, u.inserted_at}])
  end

  defp apply_sorting(query, _order_by, _order, _subquery) do
    from(u in query, order_by: [desc: u.inserted_at])
  end

  @spec preload_contacts(Ecto.Queryable.t()) :: Ecto.Queryable.t()
  def preload_contacts(query) do
    Repo.preload(query, :contacts)
  end

  @spec get_user(String.t()) :: User.t() | nil
  def get_user(id), do: Repo.get(User, id)

  @spec get_user_with_subscription(String.t()) :: {:ok, User.t()} | {:error, atom()}
  def get_user_with_subscription(id) do
    case get_user(id) do
      nil -> {:error, :not_found}
      user -> {:ok, Repo.preload(user, [:subscription, :external_accounts])}
    end
  end

  @spec get_user_by_email(String.t()) :: {:ok, User.t()} | {:error, atom()}
  def get_user_by_email(email) do
    case Repo.get_by(User, email: email) do
      nil -> {:error, :not_found}
      user -> {:ok, Repo.preload(user, :external_accounts)}
    end
  end

  @spec find_or_create_user_by_oauth_user(map) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def find_or_create_user_by_oauth_user(auth_user) do
    case get_user_by_email(auth_user.email) do
      {:ok, user} -> {:ok, user}
      {:error, :not_found} -> create_user(auth_user)
    end
  end

  @spec create_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
    |> then(fn
      {:ok, user} ->
        user = Repo.preload(user, [:contacts, :external_accounts])

        Mailchimp.add_user_to_list(user)

        {:ok, user}

      {:error, changeset} ->
        {:error, changeset}
    end)
  end

  @spec update_user(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_user(User.t()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def delete_user(%User{} = user) do
    user.id
    |> Contacts.simple_user_contacts_query()
    |> Repo.all()
    |> Enum.each(&CQRS.delete_contact(&1.id, consistency: :strong))

    Repo.delete(user)
  end

  @spec create_session(User.t(), map()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def create_session(user, auth_data) do
    expires_at = calculate_expires_at(auth_data.credentials.expires_at)

    auth_data = %{
      "uid" => auth_data.uid,
      "provider" => to_string(auth_data.provider),
      "email" => auth_data.info.email,
      "name" => auth_data.info.name,
      "image" => auth_data.info.image,
      "nickname" => auth_data.info.nickname,
      "token" => auth_data.credentials.token,
      "expires_at" => expires_at,
      "scopes" => auth_data.credentials.scopes || []
    }

    session_params = %{
      user_id: user.id,
      auth_data: auth_data,
      expires_at: expires_at
    }

    %Session{}
    |> Session.changeset(session_params)
    |> Repo.insert()
  end

  @spec get_session(String.t()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def get_session(id) do
    case Repo.get(Session, id) do
      %Session{expires_at: expires_at} = session ->
        if NaiveDateTime.compare(expires_at, NaiveDateTime.utc_now()) == :gt do
          {:ok, Repo.preload(session, :user)}
        else
          delete_session(id)
          {:error, :expired}
        end

      nil ->
        {:error, :not_found}
    end
  end

  @spec delete_session(String.t()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()} | {:ok, nil}
  def delete_session(id) do
    case Repo.get(Session, id) do
      %Session{} = session -> Repo.delete(session)
      nil -> {:ok, nil}
    end
  end

  @spec cleanup_expired_sessions() :: :ok
  def cleanup_expired_sessions do
    from(s in Session, where: s.expires_at < ^NaiveDateTime.utc_now())
    |> Repo.delete_all()
  end

  # 24 hours
  defp calculate_expires_at(nil), do: NaiveDateTime.add(NaiveDateTime.utc_now(), 24 * 60 * 60)

  defp calculate_expires_at(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp) |> DateTime.to_naive()
  end
end
