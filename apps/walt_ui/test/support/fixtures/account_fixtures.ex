defmodule WaltUi.AccountFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `WaltUi.Account` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    rand_seed = Enum.random(0..2550)

    {:ok, user} =
      attrs
      |> Enum.into(%{
        auth_uid: "auth0bogusId#{rand_seed}",
        email: "christian_horner#{rand_seed}@gmail.com",
        first_name: "Christian",
        last_name: "Horner",
        phone: "8018109795"
      })
      |> WaltUi.Account.create_user()

    user
  end
end
