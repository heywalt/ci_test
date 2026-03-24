defmodule CQRS.EventStore do
  @moduledoc false

  use EventStore, otp_app: :cqrs
end
