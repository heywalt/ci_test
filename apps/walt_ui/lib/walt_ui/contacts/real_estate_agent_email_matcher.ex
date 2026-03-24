defmodule WaltUi.Contacts.RealEstateAgentEmailMatcher do
  @moduledoc false

  import Ecto.Query

  alias WaltUi.Account.User
  alias WaltUi.ExternalAccounts.ExternalAccount

  @patterns [
    "@bhhs",
    "@cb-hb.com",
    "@cbawest.com",
    "@cbba.com",
    "@cbbain.com",
    "@cbburnet.com",
    "@cbcaine.com",
    "@cbcarolinas.com",
    "@cbdfw.com",
    "@cbelpaso.com",
    "@cbexchange.com",
    "@cbkfalls.com",
    "@cbmove.com",
    "@cbmoves.com",
    "@cbnorcal.com",
    "@cbolympia.com",
    "@cbre.com",
    "@cbrealty.com",
    "@cbrpm.com",
    "@cbselectre.com",
    "@cbstgeorge.com",
    "@cbtulsa.com",
    "@cbunited.com",
    "@cbutah.com",
    "@cbvegas.com",
    "@exprealty.com",
    "@hhgus.com",
    "@kw.com",
    "@redsign.com",
    "@remax",
    "realty",
    "realtor",
    "homes",
    "realestate",
    "group",
    "onegroup",
    "houses"
  ]

  @spec match?(String.t()) :: boolean()
  def match?(email) when is_binary(email) do
    downcased = String.downcase(email)
    Enum.any?(@patterns, &String.contains?(downcased, &1))
  end

  def match?(_), do: false

  @spec any_match?(list(String.t()) | nil) :: boolean()
  def any_match?(emails) when is_list(emails) do
    Enum.any?(emails, &match?/1)
  end

  def any_match?(_), do: false

  @spec any_system_user_match?(list(String.t()) | nil) :: boolean()
  def any_system_user_match?(emails) when is_list(emails) and emails != [] do
    downcased = Enum.map(emails, &String.downcase/1)

    Repo.exists?(from u in User, where: fragment("lower(?)", u.email) in ^downcased) ||
      Repo.exists?(
        from ea in ExternalAccount, where: fragment("lower(?)", ea.email) in ^downcased
      )
  end

  def any_system_user_match?(_), do: false
end
