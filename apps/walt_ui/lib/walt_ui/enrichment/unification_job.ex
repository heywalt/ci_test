defmodule WaltUi.Enrichment.UnificationJob do
  @moduledoc false

  use Oban.Pro.Worker,
    queue: :open_ai,
    max_attempts: 5

  require Logger

  alias CQRS.Leads.Commands.Unify
  alias WaltUi.Enrichment.OpenAi

  # Define structured arguments schema
  args_schema do
    field :contact_id, :string, required: true
    field :contact_first_name, :string
    field :contact_last_name, :string
    field :enrichment_id, :string, required: true
    field :enrichment_first_name, :string
    field :enrichment_last_name, :string
    field :enrichment_alternate_names, {:array, :string}, default: []
    field :enrichment_data, :map, default: %{}
    field :enrichment_type, :string
    field :user_id, :string, required: true
  end

  @impl Oban.Pro.Worker
  def process(%{args: args}) do
    Logger.metadata(contact_id: args.contact_id, module: __MODULE__, user_id: args.user_id)

    contact_name = get_name(:contact, args)
    enrichment_name = get_name(:enrichment, args)

    case OpenAi.confirm_identity(contact_name, enrichment_name) do
      {:ok, true} ->
        Logger.info("Identity confirmed via GPT")
        dispatch_unify_command(args)

      {:ok, false} ->
        Logger.info("Identity unconfirmed via GPT")
        :ok

      {:error, %{message: "OpenAI request timeout"}} ->
        Logger.warning("Identity confirmation timeout")
        {:error, "OpenAI timeout"}

      {:error, reason} ->
        Logger.warning("Identity confirmation error", reason: inspect(reason))
        :ok
    end
  end

  defp dispatch_unify_command(args) do
    enrichment_data = CQRS.Utils.get(args, :enrichment_data, %{})

    command = %Unify{
      id: args.contact_id,
      enrichment_id: args.enrichment_id,
      enrichment_type: parse_enrichment_type(args.enrichment_type),
      ptt: CQRS.Utils.get(enrichment_data, :ptt, 0),
      city: CQRS.Utils.get(enrichment_data, :city),
      state: CQRS.Utils.get(enrichment_data, :state),
      street_1: CQRS.Utils.get(enrichment_data, :street_1),
      street_2: CQRS.Utils.get(enrichment_data, :street_2),
      zip: CQRS.Utils.get(enrichment_data, :zip)
    }

    CQRS.dispatch(command)
  end

  defp get_name(key, args) do
    first_name = CQRS.Utils.get(args, :"#{key}_first_name") || ""
    last_name = CQRS.Utils.get(args, :"#{key}_last_name") || ""

    base_name = %{
      first_name: String.downcase(first_name),
      last_name: String.downcase(last_name)
    }

    # Add alternate names for enrichment data
    if key == :enrichment do
      alternate_names = CQRS.Utils.get(args, :enrichment_alternate_names, [])
      Map.put(base_name, :alternate_names, alternate_names)
    else
      base_name
    end
  end

  defp parse_enrichment_type(:best), do: :best
  defp parse_enrichment_type("best"), do: :best
  defp parse_enrichment_type(_), do: :lesser
end
