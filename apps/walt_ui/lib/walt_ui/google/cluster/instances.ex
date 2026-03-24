defmodule WaltUi.Google.Cluster.Instances do
  @moduledoc """
  Context module for data on instances running inside our cluster.
  """
  @api_base "https://compute.googleapis.com/compute/v1/projects"
  @zones ["us-east5-a", "us-east5-b", "us-east5-c"]

  @doc """
  Returns internal DNS addresses for instances in the zones we care about.
  """
  @spec internal_dns(String.t(), String.t()) :: [String.t()]
  def internal_dns(project, token) do
    @zones
    |> Enum.map(&get_zone_instance_data(project, &1, token))
    |> Enum.flat_map(&running_instances/1)
    |> Enum.map(&name_and_zone/1)
    |> Enum.map(&to_internal_dns(&1, project))
  end

  defp get_zone_instance_data(project, zone, token) do
    url = "#{@api_base}/#{project}/zones/#{zone}/instances"
    headers = [{"Authorization", "Bearer #{token}"}]

    with {:ok, %{status_code: code, body: body}} when code in 200..299 <-
           HTTPoison.get(url, headers),
         {:ok, data} <- Jason.decode(body) do
      {:ok, Map.get(data, "items", [])}
    end
  end

  defp name_and_zone(%{"name" => name, "zone" => zone}) do
    zone_name =
      zone
      |> URI.parse()
      |> Map.get(:path)
      |> Path.basename()

    {name, zone_name}
  end

  defp running_instances({:error, _}), do: []

  defp running_instances({:ok, instances}) do
    Enum.filter(instances, &(Map.get(&1, "status") == "RUNNING"))
  end

  defp to_internal_dns({instance_name, zone_name}, project) do
    "#{instance_name}.#{zone_name}.c.#{project}.internal"
  end
end
