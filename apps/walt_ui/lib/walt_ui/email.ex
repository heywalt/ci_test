defmodule WaltUi.Email do
  @moduledoc """
  Email context, used as a jumping off point into email integrations like Gmail.
  """

  alias WaltUi.Google.Gmail

  def sync_messages(external_account) do
    case external_account.provider do
      :google -> Gmail.sync_messages(external_account)
      _ -> {:error, "Cannot sync email; unknown provider"}
    end
  end

  def send_email(external_account, params) do
    case external_account.provider do
      :google -> Gmail.send_email(external_account, params)
      _ -> {:error, "Cannot send email; unknown provider"}
    end
  end
end
