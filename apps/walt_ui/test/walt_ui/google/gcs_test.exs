defmodule WaltUi.Google.GcsTest do
  use ExUnit.Case

  alias WaltUi.Google.Gcs

  test "file_delivery_url/1" do
    assert Gcs.file_delivery_url(nil) == nil
    assert Gcs.file_delivery_url("") == nil

    assert Gcs.file_delivery_url("path/to/file") ==
             "https://storage.googleapis.com/hey-walt-contacts/path/to/file"
  end
end
