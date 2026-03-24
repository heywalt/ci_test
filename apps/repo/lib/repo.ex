defmodule Repo do
  @moduledoc false

  use EctoHooks.Repo,
    otp_app: :repo,
    adapter: Ecto.Adapters.Postgres

  use Scrivener, page_size: 100

  def default_options(operation) do
    super(operation) ++ Appsignal.Ecto.Repo.default_options()
  end

  @doc """
  Function to reload a data struct before preloading the given fields. If the
  reloaded data struct cannot be found, this function returns `nil`. Options are
  given to `Ecto.Repo.preload/3`. See its documentation for available options.

  ## NOTE

  `Ecto.Repo.reload/2` accepts a list of structs. This function does not.
  """
  @spec re_preload(Ecto.Schema.t(), preloads :: term, Keyword.t()) :: Ecto.Schema.t() | nil
  def re_preload(record, preloads, opts \\ []) when is_struct(record) do
    if record = reload(record) do
      preload(record, preloads, opts)
    end
  end
end
