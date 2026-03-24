defmodule WaltUi.Contacts do
  @moduledoc """
  The Directory context.
  """
  require Logger

  import Ecto.Query, warn: false
  import Ecto.Changeset

  alias NimbleCSV.RFC4180, as: CSV
  alias WaltUi.Account.User
  alias WaltUi.Contacts.ContactEvent
  alias WaltUi.Contacts.Highlight
  alias WaltUi.Error
  alias WaltUi.Projections
  alias WaltUi.PubSub
  alias WaltUi.Realtors.RealtorIdentity
  alias WaltUi.Realtors.RealtorPhoneNumber

  @max_rows_allowed 10_001

  def contacts_by_user_query(user_id) do
    user_id
    |> simple_user_contacts_query()
    |> exclude_hidden_contacts()
    |> exclude_realtors()
    |> enrich_contact_query()
    |> order_by([con, jit: jit],
      desc: con.is_favorite,
      desc_nulls_last: coalesce(jit.ptt, con.ptt),
      asc_nulls_last: con.first_name
    )
  end

  def hidden_contacts_by_user_query(user_id) do
    user_id
    |> simple_user_contacts_query()
    |> only_hidden_contacts()
    |> enrich_contact_query()
    |> order_by([con, jit: jit],
      desc: con.is_favorite,
      desc_nulls_last: coalesce(jit.ptt, con.ptt),
      asc_nulls_last: con.first_name
    )
  end

  def enrich_contact_query(query) do
    from con in query,
      left_join: enr in Projections.Enrichment,
      on: enr.id == con.enrichment_id,
      as: :enr,
      left_join: jit in Projections.Jitter,
      on: jit.id == con.enrichment_id,
      as: :jit,
      left_join: grav in Projections.Gravatar,
      on: grav.id == con.enrichment_id,
      as: :grav,
      select_merge: %{enrichment: enr},
      select_merge: %{ptt: coalesce(jit.ptt, con.ptt)},
      select_merge: %{avatar: coalesce(con.avatar, grav.url)}
  end

  def exclude_hidden_contacts(query) do
    from con in query,
      where: con.is_hidden == false
  end

  def only_hidden_contacts(query) do
    from con in query, where: con.is_hidden == true
  end

  def exclude_realtors(query) do
    from con in query,
      left_join: ri in RealtorIdentity,
      on: fragment("LOWER(?) = LOWER(?)", con.email, ri.email),
      left_join: rpn in RealtorPhoneNumber,
      on: con.standard_phone == rpn.number,
      where: is_nil(ri.id) and is_nil(rpn.id)
  end

  def simple_user_contacts_query(user_id) do
    from con in Projections.Contact,
      join: u in WaltUi.Account.User,
      on: u.id == con.user_id,
      left_join: csc in Projections.ContactShowcase,
      on: csc.contact_id == con.id,
      where: con.user_id == ^user_id,
      select_merge: %{is_showcased: fragment("? IS NOT NULL", csc.id)},
      order_by: [
        desc:
          fragment("CASE WHEN ? = 'freemium' THEN ? IS NOT NULL ELSE true END", u.tier, csc.id)
      ]
  end

  def preload_common_associations(query) do
    preload(query, [:notes, :tags])
  end

  @spec get_contact(Ecto.UUID.t()) :: Projections.Contact.t() | nil
  def get_contact(id) do
    Repo.one(
      enrich_contact_query(
        from con in Projections.Contact,
          left_join: csc in Projections.ContactShowcase,
          on: csc.contact_id == con.id,
          where: con.id == ^id,
          select_merge: %{is_showcased: fragment("? IS NOT NULL", csc.id)}
      )
    )
  end

  @spec get_contact(Ecto.UUID.t(), String.t(), String.t()) :: Projections.Contact.t() | nil
  def get_contact(user_id, remote_source, remote_id) do
    Repo.one(
      enrich_contact_query(
        from con in Projections.Contact,
          left_join: csc in Projections.ContactShowcase,
          on: csc.contact_id == con.id,
          where: con.user_id == ^user_id,
          where: con.remote_source == ^remote_source,
          where: con.remote_id == ^remote_id,
          select_merge: %{is_showcased: fragment("? IS NOT NULL", csc.id)}
      )
    )
  end

  @spec contact_exists?(Ecto.UUID.t(), Ecto.UUID.t()) :: boolean()
  def contact_exists?(contact_id, user_id) do
    Repo.exists?(
      from c in Projections.Contact,
        where: c.id == ^contact_id and c.user_id == ^user_id
    )
  end

  @spec get_contact_by_enrichment_id(Ecto.UUID.t()) :: Projections.Contact.t() | nil
  def get_contact_by_enrichment_id(enrichment_id) do
    Repo.one(
      from(c in Projections.Contact,
        where: c.enrichment_id == ^enrichment_id
      )
    )
  end

  @spec within_bounding_box(Ecto.UUID.t(), float(), float(), float()) :: Ecto.Query.t()
  def within_bounding_box(user_id, center_lat, center_lng, radius_miles) do
    lat_delta = radius_miles / 69.0
    lng_delta = radius_miles / (69.0 * :math.cos(center_lat * :math.pi() / 180))

    from(c in Projections.Contact,
      where: c.user_id == ^user_id,
      where: c.latitude >= ^(center_lat - lat_delta),
      where: c.latitude <= ^(center_lat + lat_delta),
      where: c.longitude >= ^(center_lng - lng_delta),
      where: c.longitude <= ^(center_lng + lng_delta),
      where: not is_nil(c.latitude),
      where: not is_nil(c.longitude)
    )
  end

  @spec geocodable_contacts_query(Ecto.UUID.t()) :: Ecto.Query.t()
  def geocodable_contacts_query(user_id) do
    from c in Projections.Contact,
      where: c.user_id == ^user_id,
      where: not is_nil(c.street_1),
      where: is_nil(c.latitude),
      where: is_nil(c.longitude),
      where: not is_nil(c.city) or not is_nil(c.zip),
      where: fragment("TRIM(?) != ''", c.street_1),
      select: c
  end

  @spec geocodable_contacts_for_all_premium_users_query() :: Ecto.Query.t()
  def geocodable_contacts_for_all_premium_users_query do
    from c in Projections.Contact,
      join: u in WaltUi.Account.User,
      on: u.id == c.user_id,
      where: u.tier == :premium,
      where: not is_nil(c.street_1),
      where: is_nil(c.latitude),
      where: is_nil(c.longitude),
      where: not is_nil(c.city) or not is_nil(c.zip),
      where: fragment("TRIM(?) != ''", c.street_1),
      select: %{contact_id: c.id, user_id: c.user_id}
  end

  @spec get_possible_addresses(Ecto.UUID.t()) :: [Projections.PossibleAddress.t()]
  def get_possible_addresses(contact_id) do
    Repo.all(
      from con in Projections.Contact,
        inner_join: addr in Projections.PossibleAddress,
        on: addr.enrichment_id == con.enrichment_id,
        where: con.id == ^contact_id,
        select: addr
    )
  end

  def get_top_contacts(user_id) do
    midnight =
      DateTime.utc_now()
      |> DateTime.shift_zone!("America/Denver")
      |> DateTime.to_naive()
      |> NaiveDateTime.beginning_of_day()

    case get_todays_highlighted_contacts(user_id, midnight) do
      [] -> get_new_top_3_contacts(user_id)
      highlighted -> highlighted
    end
  end

  def get_todays_highlighted_contacts(user_id, midnight) do
    Repo.all(
      enrich_contact_query(
        from(c in Projections.Contact,
          inner_join: hl in Highlight,
          on: hl.contact_id == c.id,
          left_join: csc in Projections.ContactShowcase,
          on: csc.contact_id == c.id,
          where: c.user_id == ^user_id,
          where: hl.inserted_at >= ^midnight,
          select_merge: %{is_showcased: fragment("? IS NOT NULL", csc.id)},
          preload: [:notes, :tags]
        )
        |> exclude_realtors()
      )
    )
  end

  def get_new_top_3_contacts(user_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.all(:new_top_3, new_top_3_query(user_id))
    |> Ecto.Multi.delete_all(:delete_old_3, from(c in Highlight, where: c.user_id == ^user_id))
    |> Ecto.Multi.insert_all(:create_highlights, Highlight, &new_highlights(&1, user_id))
    |> Repo.transaction()
    |> case do
      {:ok, result} -> result.new_top_3
      _error -> []
    end
  end

  @spec fetch_contact(any()) :: {:ok, any()} | Error.t()
  def fetch_contact(id) do
    case get_contact(id) do
      nil ->
        Error.new("Contact not found", reason_atom: :not_found, details: %{contact_id: id})

      contact ->
        preloaded =
          Repo.preload(contact, [:notes, :events, :tags])

        {:ok, preloaded}
    end
  end

  @spec ptt_history(Ecto.UUID.t()) :: [Projections.PttScore.t()]
  def ptt_history(contact_id) do
    contact_id
    |> Projections.PttScore.ptt_history_query()
    |> Repo.all()
    |> Projections.PttScore.fill_history([])
    |> Enum.reverse()
    |> Enum.slice(0..11)
  end

  @spec jitter(Contact.t()) :: [Projections.Jitter.t()]
  def jitter(%{id: contact_id}) do
    from(j in Projections.Jitter,
      join: c in Projections.Contact,
      on: c.enrichment_id == j.id,
      where: c.id == ^contact_id
    )
    |> Repo.one()
  end

  def contact_display_name(contact) do
    "#{contact.first_name} #{contact.last_name}"
  end

  def list_contacts_by_user(user_id) do
    user_id
    |> contacts_by_user_query()
    |> preload_common_associations()
    |> Repo.all()
  end

  @spec list_favorites(Ecto.UUID.t()) :: [Projections.Contact.t()]
  def list_favorites(user_id) do
    user_id
    |> simple_user_contacts_query()
    |> where([c], c.is_favorite == true)
    |> enrich_contact_query()
    |> preload_common_associations()
    |> order_by([con, jit: jit],
      desc_nulls_last: coalesce(jit.ptt, con.ptt),
      asc_nulls_last: con.first_name
    )
    |> Repo.all()
  end

  @spec paginate_all_contacts(Ecto.UUID.t(), map()) :: Scrivener.Page.t()
  def paginate_all_contacts(user_id, opts \\ %{}) do
    from(con in Projections.Contact,
      left_join: jit in Projections.Jitter,
      on: jit.id == con.enrichment_id,
      where: con.user_id == ^user_id and (con.is_favorite != true or is_nil(con.is_favorite)),
      order_by: [desc: coalesce(jit.ptt, con.ptt), asc: con.first_name]
    )
    |> preload_common_associations()
    |> paginate(opts)
  end

  def get_contacts_in_id_list(id_list, opts \\ []) do
    preload = Keyword.get(opts, :preload, [:notes, :events, :tags])

    Repo.all(
      from c in Projections.Contact,
        left_join: csc in Projections.ContactShowcase,
        on: csc.contact_id == c.id,
        where: c.id in ^id_list,
        select_merge: %{is_showcased: fragment("? IS NOT NULL", csc.id)},
        preload: ^preload
    )
  end

  @spec get_by_email(Ecto.UUID.t(), String.t()) :: [Ecto.UUID.t()] | []
  def get_by_email(user_id, email) do
    Repo.all(
      from c in Projections.Contact,
        where: c.user_id == ^user_id,
        where:
          c.email == ^email or
            fragment(
              "EXISTS (SELECT 1 FROM unnest(COALESCE(?, '{}'::jsonb[])) AS elem WHERE elem->>'email' = ?)",
              c.emails,
              ^email
            ),
        select: c.id
    )
  end

  @doc """
  Bulk lookup of contact IDs by multiple email addresses.
  Returns a map of email -> [contact_ids] for efficient contact matching.
  """
  @spec get_contacts_by_emails(Ecto.UUID.t(), [String.t()]) :: %{String.t() => [String.t()]}
  def get_contacts_by_emails(_user_id, []), do: %{}

  def get_contacts_by_emails(user_id, emails) when is_list(emails) do
    # Use IN and ANY for much better performance with indexes
    results =
      Repo.all(
        from c in Projections.Contact,
          where: c.user_id == ^user_id,
          where:
            c.email in ^emails or
              fragment(
                "EXISTS (SELECT 1 FROM unnest(COALESCE(?, '{}'::jsonb[])) AS elem WHERE elem->>'email' = ANY(?))",
                c.emails,
                ^emails
              ),
          select: {c.id, c.email, c.emails}
      )

    # Build map of email -> [contact_ids]
    emails_set = MapSet.new(emails)

    Enum.reduce(results, %{}, fn {contact_id, primary_email, email_list}, acc ->
      acc
      |> add_primary_email_to_map(contact_id, primary_email, emails_set)
      |> add_emails_array_to_map(contact_id, email_list, emails_set)
    end)
  end

  @doc """
  Search for contacts by name (first name, last name, or full name).
  Returns a list of matching contacts ordered by most recently updated.
  """
  @spec search_by_name(Ecto.UUID.t(), String.t(), Keyword.t()) :: [Projections.Contact.t()]
  def search_by_name(user_id, name, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    name_parts =
      name
      |> String.trim()
      |> String.split(~r/\s+/)

    user_id
    |> simple_user_contacts_query()
    |> apply_name_search(name_parts)
    |> order_by([c], desc: c.updated_at)
    |> limit(^limit)
    |> Repo.all()
  end

  defp apply_name_search(query, [first_part, last_part]) do
    first_term = "%#{first_part}%"
    last_term = "%#{last_part}%"

    where(
      query,
      [c],
      (ilike(c.first_name, ^first_term) and ilike(c.last_name, ^last_term)) or
        ilike(c.email, ^first_term)
    )
  end

  defp apply_name_search(query, name_parts) do
    search_term =
      name_parts
      |> Enum.join(" ")
      |> then(&"%#{&1}%")

    where(
      query,
      [c],
      ilike(c.first_name, ^search_term) or
        ilike(c.last_name, ^search_term) or
        ilike(c.email, ^search_term)
    )
  end

  @doc """
  Lists all unique email addresses for a user's contacts.
  Returns both primary email field and emails array entries.
  """
  @spec list_all_emails(Ecto.UUID.t()) :: [String.t()]
  def list_all_emails(user_id) do
    Repo.all(
      from c in Projections.Contact,
        where: c.user_id == ^user_id,
        select: {c.email, c.emails}
    )
    |> extract_all_emails()
  end

  @doc """
  Gets a chunk of contacts with their email data for chunked processing.
  Uses chronological ordering (inserted_at) for stable pagination.
  """
  @spec get_contacts_chunk(Ecto.UUID.t(), integer(), integer()) :: [{String.t(), [map()]}]
  def get_contacts_chunk(user_id, offset, limit) do
    Repo.all(
      from c in Projections.Contact,
        where: c.user_id == ^user_id,
        where: not is_nil(c.email) or fragment("array_length(?, 1) > 0", c.emails),
        select: {c.email, c.emails},
        order_by: c.inserted_at,
        offset: ^offset,
        limit: ^limit
    )
  end

  @doc """
  Counts total contacts with email addresses for a user.
  Used for progress tracking in chunked processing.
  """
  @spec count_contacts_with_emails(Ecto.UUID.t()) :: integer()
  def count_contacts_with_emails(user_id) do
    Repo.one(
      from c in Projections.Contact,
        where: c.user_id == ^user_id,
        where: not is_nil(c.email) or fragment("array_length(?, 1) > 0", c.emails),
        select: count(c.id)
    )
  end

  @doc """
  Gets email addresses for a specific chunk of contacts.
  Combines get_contacts_chunk with email extraction.
  """
  @spec get_emails_for_contact_chunk(Ecto.UUID.t(), integer(), integer()) :: [String.t()]
  def get_emails_for_contact_chunk(user_id, offset, limit) do
    user_id
    |> get_contacts_chunk(offset, limit)
    |> extract_all_emails()
  end

  defdelegate create_contact(attrs), to: CQRS

  @spec send_bulk_create_events(User.t(), [map()]) :: :ok
  def send_bulk_create_events(user, contacts) do
    contacts
    |> Task.async_stream(fn contact ->
      contact = Map.put(contact, "user_id", user.id)
      PubSub.send_message(contact, topic: "create-contacts")
    end)
    |> Stream.run()
  end

  @spec send_bulk_upsert_events(User.t(), [map]) :: :ok
  def send_bulk_upsert_events(user, contacts) do
    contacts
    |> Task.async_stream(fn con ->
      con
      |> Map.put("user_id", user.id)
      |> PubSub.send_message(topic: "upsert-contacts")
    end)
    |> Stream.run()
  end

  @spec bulk_create([map]) :: :ok
  def bulk_create(bulk_attrs) do
    Enum.each(bulk_attrs, &CQRS.create_contact/1)
  end

  def create_contacts_from_csv(path, user, opts \\ []) do
    # used to update LiveView
    update_fun = Keyword.get(opts, :update_fun, fn _, _ -> :ok end)
    create_fun = Keyword.get(opts, :create_fun, &send_bulk_create_events/2)

    dt = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    total_rows = count_lines(path)

    total_rows = if total_rows > @max_rows_allowed, do: @max_rows_allowed, else: total_rows

    headers =
      path
      |> File.open!()
      |> IO.read(:line)
      |> String.trim()
      |> String.split(",")
      |> Enum.map(&normalize_column_name/1)

    path
    |> File.stream!()
    |> Stream.take(@max_rows_allowed)
    |> CSV.parse_stream(skip_headers: true)
    |> Stream.map(fn row ->
      contact_map =
        headers
        |> Enum.zip(row)
        |> Map.new()

      fname = Map.get(contact_map, "first_name")
      lname = Map.get(contact_map, "last_name")
      phone = Map.get(contact_map, "phone")

      remote_id = :crypto.hash(:sha256, "#{fname}#{lname}#{phone}") |> Base.encode64()

      contact_map
      |> Map.merge(%{
        "updated_at" => dt,
        "inserted_at" => dt,
        "remote_id" => remote_id,
        "remote_source" => "csv"
      })
    end)
    |> Stream.chunk_every(1000)
    |> Enum.reduce(0, fn chunk, acc ->
      new_acc = length(chunk) + acc

      create_fun.(user, chunk)
      update_fun.(new_acc, total_rows)

      new_acc
    end)
  end

  @column_aliases %{
    "Phone" => "phone",
    "PHONE" => "phone",
    "phone_number" => "phone",
    "Phone Number" => "phone",
    "First Name" => "first_name",
    "FirstName" => "first_name",
    "first name" => "first_name",
    "FIRST_NAME" => "first_name",
    "Last Name" => "last_name",
    "LastName" => "last_name",
    "last name" => "last_name",
    "LAST_NAME" => "last_name",
    "Email" => "email",
    "EMAIL" => "email",
    "e-mail" => "email",
    "E-mail" => "email",
    "Tags" => "tags",
    "TAGS" => "tags"
  }

  defp normalize_column_name(header) do
    header = String.trim(header)
    Map.get(@column_aliases, header, header)
  end

  defdelegate update_contact(contact, attrs), to: CQRS

  def delete_contact(%Projections.Contact{} = contact) do
    CQRS.delete_contact(contact.id)
  end

  @spec delete_user_contacts(Ecto.UUID.t()) :: :ok
  def delete_user_contacts(user_id) do
    Repo.all(from con in Projections.Contact, where: con.user_id == ^user_id)
    |> Enum.each(&CQRS.delete_contact(&1.id))
  end

  # Not a fan of this but
  # not sure where else it should live for now
  def paginate(query, opts) do
    Repo.paginate(query, opts)
  end

  #########
  # EVENTS
  #########
  def create_event(attrs \\ %{}) do
    %ContactEvent{}
    |> change_event(attrs)
    |> Repo.insert()
  end

  def change_event(%ContactEvent{} = event, attrs \\ %{}) do
    event
    |> ContactEvent.changeset(attrs)
    |> cast_assoc(:note)
  end

  defp add_primary_email_to_map(acc, contact_id, primary_email, emails_set) do
    if primary_email && MapSet.member?(emails_set, primary_email) do
      Map.update(acc, primary_email, [contact_id], &[contact_id | &1])
    else
      acc
    end
  end

  defp add_emails_array_to_map(acc, contact_id, email_list, emails_set) do
    case email_list do
      nil ->
        acc

      emails_array when is_list(emails_array) ->
        Enum.reduce(emails_array, acc, fn email_entry, inner_acc ->
          add_email_entry_to_map(inner_acc, contact_id, email_entry, emails_set)
        end)

      _ ->
        acc
    end
  end

  defp add_email_entry_to_map(acc, contact_id, email_entry, emails_set) do
    case email_entry do
      # Handle struct with atom keys (from Ecto embedded schema)
      %{email: email} when is_binary(email) ->
        if MapSet.member?(emails_set, email) do
          Map.update(acc, email, [contact_id], &[contact_id | &1])
        else
          acc
        end

      # Handle map with string keys (legacy support)
      %{"email" => email} when is_binary(email) ->
        if MapSet.member?(emails_set, email) do
          Map.update(acc, email, [contact_id], &[contact_id | &1])
        else
          acc
        end

      _ ->
        acc
    end
  end

  defp extract_all_emails(contact_records) do
    contact_records
    |> Enum.reduce([], fn {primary_email, emails_array}, acc ->
      acc
      |> add_primary_email(primary_email)
      |> add_array_emails(emails_array)
    end)
    |> Enum.uniq()
  end

  defp add_primary_email(acc, nil), do: acc
  defp add_primary_email(acc, ""), do: acc
  defp add_primary_email(acc, email), do: [email | acc]

  defp add_array_emails(acc, nil), do: acc
  defp add_array_emails(acc, []), do: acc

  defp add_array_emails(acc, emails_array) do
    array_emails =
      emails_array
      |> Enum.map(&extract_email_from_map/1)
      |> Enum.reject(&(is_nil(&1) || &1 == ""))

    acc ++ array_emails
  end

  defp extract_email_from_map(%{"email" => email}), do: email
  defp extract_email_from_map(%{email: email}), do: email
  defp extract_email_from_map(_), do: nil

  defp new_highlights(%{new_top_3: contacts}, user_id) do
    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    Enum.map(contacts, fn con ->
      %{
        id: Ecto.UUID.generate(),
        contact_id: con.id,
        user_id: user_id,
        inserted_at: now,
        updated_at: now
      }
    end)
  end

  defp new_top_3_query(user_id) do
    enrich_contact_query(
      from(c in Projections.Contact,
        join: u in WaltUi.Account.User,
        on: u.id == c.user_id,
        left_join: hl in Highlight,
        on: hl.contact_id == c.id,
        left_join: csc in Projections.ContactShowcase,
        on: csc.contact_id == c.id,
        where: c.user_id == ^user_id,
        where: c.is_hidden == false,
        where: c.ptt >= 50,
        where: is_nil(hl.contact_id),
        where:
          fragment("CASE WHEN ? = 'freemium' THEN ? IS NOT NULL ELSE true END", u.tier, csc.id),
        select_merge: %{is_showcased: fragment("? IS NOT NULL", csc.id)},
        preload: [:notes, :tags],
        order_by: fragment("RANDOM()"),
        limit: 3
      )
      |> exclude_realtors()
    )
  end

  defp count_lines(path) do
    {result, 0} = System.cmd("wc", ["-l", path])

    result
    |> String.trim()
    |> String.split(" ")
    |> List.first()
    |> String.to_integer()
  end

  @doc """
  Returns contacts for a user with Move Score changes over the last week,
  grouped into 'top' (scores went up) and 'bottom' (scores went down).
  """
  def get_enrichment_report(user_id) do
    one_week_ago = DateTime.utc_now() |> DateTime.add(-7, :day)

    user_contact_ids =
      from(c in Projections.Contact,
        where: c.user_id == ^user_id and c.is_hidden == false,
        select: c.id
      )

    prev_scores_query =
      from(ptt in Projections.PttScore,
        where: ptt.contact_id in subquery(user_contact_ids),
        select: %{
          contact_id: ptt.contact_id,
          score: ptt.score,
          rn:
            over(row_number(),
              partition_by: ptt.contact_id,
              order_by: [desc: ptt.occurred_at]
            )
        }
      )

    contacts_with_changes =
      Projections.Contact
      |> where([con], con.user_id == ^user_id)
      |> where([con], con.is_hidden == false)
      |> join(:inner, [con], ptt in Projections.PttScore, on: ptt.contact_id == con.id, as: :ptt)
      |> where([ptt: ptt], ptt.occurred_at >= ^one_week_ago)
      |> with_cte("prev_scores", as: ^prev_scores_query)
      |> join(:inner, [ptt: ptt], pre in "prev_scores",
        on: pre.contact_id == ptt.contact_id,
        as: :pre
      )
      |> where([pre: pre], pre.rn == 2)
      |> select([con, ptt: ptt, pre: pre], %{
        contact: con,
        score_change: fragment("COALESCE(?, 0) - ?", ptt.score, pre.score)
      })
      |> Repo.all()

    # Group contacts into top and bottom based on score change
    contacts_by_change =
      contacts_with_changes
      |> Enum.reduce(%{top: [], bottom: []}, fn contact, acc ->
        case contact.score_change do
          n when n > 0 -> %{acc | top: [contact | acc.top]}
          n when n < 0 -> %{acc | bottom: [contact | acc.bottom]}
          _0 -> acc
        end
      end)

    top =
      contacts_by_change.top
      |> Enum.sort_by(&abs(&1.score_change), :desc)
      |> Enum.take(5)
      |> Enum.map(&drop_preloads/1)

    bottom =
      contacts_by_change.bottom
      |> Enum.sort_by(&abs(&1.score_change), :desc)
      |> Enum.take(5)
      |> Enum.map(&drop_preloads/1)

    %{
      top: top,
      bottom: bottom
    }
  end

  defp drop_preloads(data) do
    Map.update(
      data,
      :contact,
      nil,
      &Map.drop(&1, [:__meta__, :__struct__, :events, :notes, :tags, :unified_contact])
    )
  end
end
