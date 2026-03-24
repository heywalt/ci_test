defmodule WaltUi.Google.GmailTest do
  use WaltUi.CqrsCase
  import Mox

  import WaltUi.Factory

  alias WaltUi.Google.Gmail

  setup do
    Application.put_env(:tesla, :adapter, WaltUi.Google.GmailMockAdapter)
    on_exit(fn -> Application.delete_env(:tesla, :adapter) end)

    user = insert(:user, email: "test_doesnt_matter@heywalt.ai")

    ea =
      insert(:external_account,
        user: user,
        provider: "google",
        email: "test@heywalt.ai",
        gmail_history_id: "12345"
      )

    [user: user, ea: ea]
  end

  setup :verify_on_exit!

  describe "sync_messages/1" do
    test "successfully syncs messages", %{user: %{id: user_id}, ea: ea} do
      profile_url = "https://www.googleapis.com/gmail/v1/users/#{ea.email}/profile"
      history_url = "https://www.googleapis.com/gmail/v1/users/#{ea.email}/history"

      # Note; this is the message ID that is returned in the history response, and necessary for matching
      # in the mock.
      messages_url =
        "https://www.googleapis.com/gmail/v1/users/#{ea.email}/messages/1958cbbe3128bdaf"

      CQRS.create_contact(%{
        email: "jaxone@heywalt.ai",
        phone: "1111111111",
        remote_id: "remoteId",
        remote_source: "remoteSource",
        user_id: user_id
      })

      # Required to ensure that the contact is created before the sync starts.
      Process.sleep(100)

      Mox.expect(WaltUi.Google.GmailMockAdapter, :call, 3, fn env, _opts ->
        case env.url do
          ^profile_url ->
            {:ok, %Tesla.Env{env | status: 200, body: successful_profile_response()}}

          ^history_url ->
            {:ok, %Tesla.Env{env | status: 200, body: successful_history_response()}}

          ^messages_url ->
            {:ok, %Tesla.Env{env | status: 200, body: successful_messages_response()}}
        end
      end)

      assert messages = Gmail.sync_messages(ea)
      assert is_list(messages)

      message = List.first(messages)
      assert message.source == "google"
      assert message.user_id == ea.user_id
      assert message.message_link =~ "https://mail.google.com/mail"
    end

    test "successfully syncs messages with multiple emails", %{user: %{id: user_id}, ea: ea} do
      profile_url = "https://www.googleapis.com/gmail/v1/users/#{ea.email}/profile"
      history_url = "https://www.googleapis.com/gmail/v1/users/#{ea.email}/history"

      # Note; this is the message ID that is returned in the history response, and necessary for matching
      # in the mock.
      messages_url =
        "https://www.googleapis.com/gmail/v1/users/#{ea.email}/messages/1958cbbe3128bdaf"

      await_contact(%{
        email: "jaxon.evans@gmail.com",
        emails: [
          %{email: "jaxon.evans12312312312@gmail.com", label: "test"},
          %{email: "jaxone@heywalt.ai", label: "work"}
        ],
        phone: "1111111111",
        remote_id: "remoteId",
        remote_source: "remoteSource",
        user_id: user_id
      })

      Mox.expect(WaltUi.Google.GmailMockAdapter, :call, 3, fn env, _opts ->
        case env.url do
          ^profile_url ->
            {:ok, %Tesla.Env{env | status: 200, body: successful_profile_response()}}

          ^history_url ->
            {:ok, %Tesla.Env{env | status: 200, body: successful_history_response()}}

          ^messages_url ->
            {:ok, %Tesla.Env{env | status: 200, body: successful_messages_response()}}
        end
      end)

      assert messages = Gmail.sync_messages(ea)
      assert is_list(messages)

      message = List.first(messages)
      assert message.source == "google"
      assert message.user_id == ea.user_id
      assert message.message_link =~ "https://mail.google.com/mail"
    end

    test "handles error in history list", %{ea: ea} do
      history_url = "https://www.googleapis.com/gmail/v1/users/#{ea.email}/history"

      Mox.expect(WaltUi.Google.GmailMockAdapter, :call, fn env, _opts ->
        case env.url do
          ^history_url ->
            {:ok, %Tesla.Env{env | status: 404, body: "error"}}
        end
      end)

      assert {:error, _} = Gmail.sync_messages(ea)
    end
  end

  describe "set_initial_history_id/1" do
    test "sets initial history ID from profile", %{ea: ea} do
      profile_url = "https://www.googleapis.com/gmail/v1/users/#{ea.email}/profile"

      Mox.expect(WaltUi.Google.GmailMockAdapter, :call, fn env, _opts ->
        case env.url do
          ^profile_url ->
            {:ok, %Tesla.Env{env | status: 200, body: successful_profile_response()}}
        end
      end)

      assert {:ok, updated_ea} = Gmail.set_initial_history_id(ea)
      assert updated_ea.gmail_history_id == "107218"
    end

    test "handles error in profile fetch", %{ea: ea} do
      profile_url = "https://www.googleapis.com/gmail/v1/users/#{ea.email}/profile"

      Mox.expect(WaltUi.Google.GmailMockAdapter, :call, fn env, _opts ->
        case env.url do
          ^profile_url ->
            {:ok, %Tesla.Env{env | status: 404, body: "error"}}
        end
      end)

      assert {:error, _} = Gmail.set_initial_history_id(ea)
    end
  end

  describe "get_latest_message_ids/1" do
    test "extracts message IDs from messagesAdded entries" do
      history = %{
        "history" => [
          %{
            "messagesAdded" => [
              %{"message" => %{"id" => "123"}}
            ]
          },
          %{
            "messagesAdded" => [
              %{"message" => %{"id" => "456"}}
            ]
          }
        ]
      }

      message_ids = Gmail.get_latest_message_ids(history)
      assert message_ids == ["123", "456"]
    end

    test "handles empty history" do
      assert Gmail.get_latest_message_ids(%{"history" => []}) == []
    end
  end

  describe "format_message/1" do
    test "formats message with all fields" do
      message = %{
        "id" => "123",
        "threadId" => "thread123",
        "payload" => %{
          "headers" => [
            %{"name" => "Subject", "value" => "Test Subject"},
            %{"name" => "From", "value" => "sender@example.com"},
            %{"name" => "To", "value" => "recipient@example.com"},
            %{"name" => "Date", "value" => "Thu, 14 Mar 2024 10:00:00 -0600"}
          ]
        }
      }

      formatted = Gmail.format_message(message)
      assert formatted.subject == "Test Subject"
      assert formatted.from == "sender@example.com"
      assert formatted.to == ["recipient@example.com"]
      assert formatted.date == "Thu, 14 Mar 2024 10:00:00 -0600"
      assert formatted.id == "123"
      assert formatted.thread_id == "thread123"
    end

    test "formats message with date header in lowercase" do
      message = %{
        "id" => "123",
        "threadId" => "thread123",
        "payload" => %{
          "headers" => [
            %{"name" => "Subject", "value" => "Test Subject"},
            %{"name" => "From", "value" => "sender@example.com"},
            %{"name" => "To", "value" => "recipient@example.com"},
            %{"name" => "date", "value" => "Thu, 14 Mar 2024 10:00:00 -0600"}
          ]
        }
      }

      formatted = Gmail.format_message(message)
      assert formatted.subject == "Test Subject"
      assert formatted.from == "sender@example.com"
      assert formatted.to == ["recipient@example.com"]
      assert formatted.date == "Thu, 14 Mar 2024 10:00:00 -0600"
      assert formatted.id == "123"
      assert formatted.thread_id == "thread123"
    end

    test "handles missing headers" do
      message = %{
        "id" => "123",
        "threadId" => "thread123",
        "payload" => %{
          "headers" => []
        }
      }

      formatted = Gmail.format_message(message)

      assert is_nil(formatted.subject)
      assert formatted.from == []
      assert formatted.to == []
      assert is_nil(formatted.date)
      assert formatted.id == "123"
      assert formatted.thread_id == "thread123"
    end

    test "formats message with missing email field" do
      message = %{
        "id" => "123",
        "threadId" => "thread123",
        "payload" => %{
          "headers" => [
            %{"name" => "Subject", "value" => "Test Subject"},
            %{"name" => "From", "value" => "sender@example.com"},
            %{"name" => "Date", "value" => "Thu, 14 Mar 2024 10:00:00 -0600"}
          ]
        }
      }

      formatted = Gmail.format_message(message)
      assert formatted.subject == "Test Subject"
      assert formatted.from == "sender@example.com"
      assert formatted.to == nil
      assert formatted.date == "Thu, 14 Mar 2024 10:00:00 -0600"
      assert formatted.id == "123"
      assert formatted.thread_id == "thread123"
    end

    test "formats problematic email addresses" do
      message = problematic_email()
      formatted = Gmail.format_message(message)
      assert formatted.from == "dev@heywalt.ai"
      assert formatted.to == ["dev@heywalt.ai"]
    end
  end

  describe "categorize_messages/2" do
    test "categorizes sent messages" do
      messages = [
        %{
          id: "123",
          from: "test@heywalt.ai",
          to: "recipient@example.com",
          subject: "Test",
          thread_id: "thread123",
          date: "2024-03-14"
        }
      ]

      result = Gmail.categorize_messages(messages, "test@heywalt.ai")
      assert length(result) == 1
      [message] = result
      assert message.direction == "sent"
    end

    test "categorizes received messages" do
      messages = [
        %{
          id: "123",
          from: "sender@example.com",
          to: "test@heywalt.ai",
          subject: "Test",
          thread_id: "thread123",
          date: "2024-03-14"
        }
      ]

      result = Gmail.categorize_messages(messages, "test@heywalt.ai")
      assert length(result) == 1
      [message] = result
      assert message.direction == "received"
    end

    test "handles multiple recipients" do
      messages = [
        %{
          id: "123",
          from: "sender@example.com",
          to: ["test@heywalt.ai", "other@example.com"],
          subject: "Test",
          thread_id: "thread123",
          date: "2024-03-14"
        }
      ]

      result = Gmail.categorize_messages(messages, "test@heywalt.ai")
      assert length(result) == 1
      [message] = result
      assert message.direction == "received"
      assert message.to == "test@heywalt.ai"
    end
  end

  describe "extract_body/1" do
    test "extracts body from simple text/plain message" do
      message = %{
        "payload" => %{
          "mimeType" => "text/plain",
          "body" => %{
            "data" => Base.url_encode64("Hello, this is a test email.", padding: false)
          }
        }
      }

      assert Gmail.extract_body(message) == "Hello, this is a test email."
    end

    test "extracts body from multipart message preferring text/plain" do
      message = %{
        "payload" => %{
          "mimeType" => "multipart/alternative",
          "body" => %{"size" => 0},
          "parts" => [
            %{
              "mimeType" => "text/plain",
              "body" => %{
                "data" => Base.url_encode64("Plain text content", padding: false)
              }
            },
            %{
              "mimeType" => "text/html",
              "body" => %{
                "data" => Base.url_encode64("<p>HTML content</p>", padding: false)
              }
            }
          ]
        }
      }

      assert Gmail.extract_body(message) == "Plain text content"
    end

    test "falls back to text/html when no text/plain available" do
      message = %{
        "payload" => %{
          "mimeType" => "multipart/alternative",
          "body" => %{"size" => 0},
          "parts" => [
            %{
              "mimeType" => "text/html",
              "body" => %{
                "data" => Base.url_encode64("<p>HTML only content</p>", padding: false)
              }
            }
          ]
        }
      }

      body = Gmail.extract_body(message)
      assert body =~ "HTML only content"
    end

    test "handles nested multipart structures" do
      message = %{
        "payload" => %{
          "mimeType" => "multipart/mixed",
          "body" => %{"size" => 0},
          "parts" => [
            %{
              "mimeType" => "multipart/alternative",
              "body" => %{"size" => 0},
              "parts" => [
                %{
                  "mimeType" => "text/plain",
                  "body" => %{
                    "data" => Base.url_encode64("Nested plain text", padding: false)
                  }
                }
              ]
            }
          ]
        }
      }

      assert Gmail.extract_body(message) == "Nested plain text"
    end

    test "returns nil for empty message" do
      message = %{"payload" => %{"body" => %{}}}
      assert Gmail.extract_body(message) == nil
    end

    test "returns nil for message with no body data" do
      message = %{
        "payload" => %{
          "mimeType" => "multipart/alternative",
          "body" => %{"size" => 0},
          "parts" => []
        }
      }

      assert Gmail.extract_body(message) == nil
    end

    test "strips HTML tags when using HTML fallback" do
      message = %{
        "payload" => %{
          "mimeType" => "multipart/alternative",
          "body" => %{"size" => 0},
          "parts" => [
            %{
              "mimeType" => "text/html",
              "body" => %{
                "data" =>
                  Base.url_encode64(
                    "<div><p>Hello</p><br><p>World</p></div>",
                    padding: false
                  )
              }
            }
          ]
        }
      }

      body = Gmail.extract_body(message)
      # Should contain text content without HTML tags
      assert body =~ "Hello"
      assert body =~ "World"
      refute body =~ "<div>"
      refute body =~ "<p>"
    end
  end

  describe "filter_messages_with_contacts/2" do
    test "filters messages with matching contacts", %{ea: ea} do
      contact = insert(:contact, user_id: ea.user_id, email: "contact@example.com")

      messages = [
        %{
          from: ea.email,
          to: contact.email,
          id: "123",
          thread_id: "thread123",
          subject: "Test",
          date: "2024-03-14",
          direction: "sent"
        }
      ]

      filtered = Gmail.filter_messages_with_contacts(messages, ea)
      assert length(filtered) == 1
      [message] = filtered
      assert message.contact_ids == [contact.id]
    end

    test "excludes messages without matching contacts", %{ea: ea} do
      messages = [
        %{
          from: ea.user.email,
          to: "unknown@example.com",
          id: "123",
          thread_id: "thread123",
          subject: "Test",
          date: "2024-03-14",
          direction: "sent"
        }
      ]

      filtered = Gmail.filter_messages_with_contacts(messages, ea)
      assert filtered == []
    end
  end

  defp successful_profile_response do
    %{
      "emailAddress" => "jd@heywalt.ai",
      "historyId" => "107218",
      "messagesTotal" => 207,
      "threadsTotal" => 189
    }
  end

  defp successful_history_response do
    %{
      "history" => [
        %{
          "id" => "105426",
          "messages" => [
            %{"id" => "1958cbbe3128bdaf", "threadId" => "1958cbbe3128bdaf"}
          ],
          "messagesAdded" => [
            %{
              "message" => %{
                "id" => "1958cbbe3128bdaf",
                "labelIds" => ["DRAFT"],
                "threadId" => "1958cbbe3128bdaf"
              }
            }
          ]
        }
      ]
    }
  end

  defp successful_messages_response do
    %{
      "historyId" => "105804",
      "id" => "1958cbc1ef603d4d",
      "internalDate" => "1741822893000",
      "labelIds" => ["SENT"],
      "payload" => %{
        "body" => %{"size" => 0},
        "filename" => "",
        "headers" => [
          %{"name" => "MIME-Version", "value" => "1.0"},
          %{"name" => "Date", "value" => "Wed, 12 Mar 2025 17:41:33 -0600"},
          %{
            "name" => "Message-ID",
            "value" => "<CAOCwrc67WzGS4y=N1_gJV=16003Th0GMhDO303YEyV4kfOQBKA@mail.gmail.com>"
          },
          %{"name" => "Subject", "value" => "Another test..."},
          %{"name" => "From", "value" => "JD Skinner <test@heywalt.ai>"},
          %{
            "name" => "To",
            "value" => "Jaxon Evans <jaxone@heywalt.ai>, Johnson Denen <johnson@heywalt.ai>"
          },
          %{
            "name" => "Content-Type",
            "value" => "multipart/alternative; boundary=\"000000000000dbcfd506302dbe47\""
          }
        ],
        "mimeType" => "multipart/alternative",
        "partId" => "",
        "parts" => [
          %{
            "body" => %{
              "data" => "YmVjYXVzZSBnb29nbGUgaXMgbWFraW5nIG1lIHd0Zi4NCg==",
              "size" => 34
            },
            "filename" => "",
            "headers" => [
              %{
                "name" => "Content-Type",
                "value" => "text/plain; charset=\"UTF-8\""
              }
            ],
            "mimeType" => "text/plain",
            "partId" => "0"
          },
          %{
            "body" => %{
              "data" =>
                "PGRpdiBkaXI9Imx0ciI-YmVjYXVzZSBnb29nbGUgaXMgbWFraW5nIG1lIHd0Zi48L2Rpdj4NCg==",
              "size" => 55
            },
            "filename" => "",
            "headers" => [
              %{
                "name" => "Content-Type",
                "value" => "text/html; charset=\"UTF-8\""
              }
            ],
            "mimeType" => "text/html",
            "partId" => "1"
          }
        ]
      },
      "sizeEstimate" => 631,
      "snippet" => "because google is making me wtf.",
      "threadId" => "1958cbbe3128bdaf"
    }
  end

  defp problematic_email do
    %{
      "historyId" => "110231",
      "id" => "195d347d87486c6f",
      "internalDate" => "1743006452000",
      "labelIds" => ["UNREAD", "CATEGORY_FORUMS", "INBOX"],
      "payload" => %{
        "body" => %{"size" => 0},
        "filename" => "",
        "headers" => [
          %{
            "name" => "Received",
            "value" =>
              "by 2002:a05:7108:4902:b0:40c:840e:6fac with SMTP id ch2csp2975319gdb;        Wed, 26 Mar 2025 09:27:36 -0700 (PDT)"
          },
          %{"name" => "Date", "value" => "Wed, 26 Mar 2025 11:27:32 -0500 (CDT)"},
          %{
            "name" => "From",
            "value" => "\"'Steve Simpson, New Relic' via Development\" <dev@heywalt.ai>"
          },
          %{"name" => "Reply-To", "value" => "amer-events@newrelic.com"},
          %{"name" => "To", "value" => "dev@heywalt.ai"},
          %{
            "name" => "Message-ID",
            "value" => "<2144807125.279456698.1743006452828@abmktmail-batch1g.marketo.org>"
          },
          %{"name" => "Subject", "value" => "I demo my new product. Then you AMA."},
          %{"name" => "MIME-Version", "value" => "1.0"}
        ],
        "mimeType" => "multipart/alternative",
        "partId" => "",
        "parts" => [
          %{
            "body" => %{
              "data" => "SGksDQoNCkn",
              "size" => 1492
            },
            "filename" => "",
            "headers" => [
              %{
                "name" => "Content-Type",
                "value" => "text/plain; charset=\"UTF-8\""
              },
              %{
                "name" => "Content-Transfer-Encoding",
                "value" => "quoted-printable"
              }
            ],
            "mimeType" => "text/plain",
            "partId" => "0"
          },
          %{
            "body" => %{
              "data" => "PCFET0NU",
              "size" => 3831
            },
            "filename" => "",
            "headers" => [
              %{
                "name" => "Content-Type",
                "value" => "text/html; charset=\"UTF-8\""
              },
              %{
                "name" => "Content-Transfer-Encoding",
                "value" => "quoted-printable"
              }
            ],
            "mimeType" => "text/html",
            "partId" => "1"
          }
        ]
      },
      "sizeEstimate" => 18_545,
      "snippet" =>
        "Hi Bart, I&#39;m excited to invite you to a live demo of Intelligent Observability for Digital Experience on March 27 at 9am PT / 12pm ET. Discover how analyzing user behavior alongside performance",
      "threadId" => "195d347d87486c6f"
    }
  end
end
