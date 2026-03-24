defprotocol WaltUi.Enrichment.Composable do
  @moduledoc """
  Protocol for normalizing provider-specific enrichment data into a standard format
  and providing quality assessment capabilities.

  Each provider has different data structures and quality indicators, but this protocol
  allows us to work with them uniformly in the composition logic
  """

  @doc """
  Normalizes provider-specific data structure into a standard field format.

  For example:
  - Trestle: Converts `addresses` list to flat address fields, maps `age_range` to `age`
  - Faraday: Preserves existing flat structure as-is
  """
  def normalize_data(provider_data)

  @doc """
  Calculates a unified quality score (0-100) from provider-specific quality metadata.

  Higher scores indicate more reliable/accurate data from that provider.
  """
  def calculate_quality_score(provider_data)

  @doc """
  Extracts a specific field value from the provider's normalized data.

  Returns the field value or nil if not present.
  """
  def extract_field(provider_data, field)

  @doc """
  Returns a list of fields that this provider typically excels at providing.

  Used for default provider selection when quality scores are similar.
  """
  def get_field_capabilities(provider_data)
end
