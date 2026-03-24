defmodule WaltUi.Scripts.BackfillStandardPhone do
  @moduledoc """
  Script to backfill the new `standard_phone` field for existing contact projections.
  """

  import Ecto.Query

  def run do
    Repo.update_all(query(), [])
  end

  defp query do
    from con in WaltUi.Projections.Contact,
      where: fragment("LENGTH(?) >= 10", con.phone),
      where: is_nil(con.standard_phone),
      update: [
        set: [
          standard_phone:
            fragment(
              """
              CASE WHEN LENGTH(REGEXP_REPLACE(?, '[^0-9]+', '', 'g')) = 11 THEN SUBSTRING(REGEXP_REPLACE(?, '[^0-9]+', '', 'g') FROM 2)
                   WHEN LENGTH(REGEXP_REPLACE(?, '[^0-9]+', '', 'g')) = 10 THEN REGEXP_REPLACE(?, '[^0-9]+', '', 'g')
                   ELSE NULL
              END
              """,
              con.phone,
              con.phone,
              con.phone,
              con.phone
            )
        ]
      ]
  end
end
