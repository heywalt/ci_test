defmodule WaltUi.SearchFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the Typesense search
  """
  import WaltUi.DirectoryFixtures
  import WaltUi.Factory

  @doc """
  Generate a search response for a user.
  """
  def search_response(user) do
    contact = insert(:contact, user_id: user.id)
    contact2 = insert(:contact, user_id: user.id)

    note = note_fixture(%{contact_id: contact2.id})

    {:ok,
     %{
       results: [
         %{
           facet_counts: [],
           found: 2,
           hits: [
             search_contact_hit(contact),
             search_contact_hit(contact2, 15)
           ],
           out_of: 6270,
           page: 1,
           request_params: %{
             collection_name: "contacts",
             first_q: "test",
             per_page: 10,
             q: "test"
           },
           search_cutoff: false,
           search_time_ms: 0
         },
         %{
           facet_counts: [],
           found: 1,
           hits: [
             search_note_hit(note)
           ],
           out_of: 6270,
           page: 1,
           request_params: %{
             collection_name: "notes",
             first_q: "test",
             per_page: 10,
             q: "test"
           },
           search_cutoff: false,
           search_time_ms: 0
         }
       ]
     }}
  end

  defp search_contact_hit(contact, score \\ 10) do
    %{
      document: %{
        email: contact.email,
        first_name: contact.first_name,
        id: contact.id,
        last_name: contact.last_name,
        ptt: contact.ptt,
        user_id: contact.user_id
      },
      highlight: %{
        last_name: %{
          matched_tokens: [contact.last_name],
          snippet: "<mark>#{contact.last_name}</mark>"
        }
      },
      highlights: [
        %{
          field: "last_name",
          matched_tokens: [contact.last_name],
          snippet: "<mark>#{contact.last_name}</mark>"
        }
      ],
      text_match: score,
      text_match_info: %{
        best_field_score: "1108091339008",
        best_field_weight: 14,
        fields_matched: 1,
        num_tokens_dropped: 0,
        score: "#{score}",
        tokens_matched: 1,
        typo_prefix_score: 0
      }
    }
  end

  defp search_note_hit(note, score \\ 5) do
    %{
      document: %{
        contact_id: note.contact_id,
        id: note.id,
        note: note.note,
        user_id: "11f7dce1-f553-4572-8b06-e678cd7069d4"
      },
      highlight: %{
        note: %{
          matched_tokens: ["test"],
          snippet: "<mark>test</mark>"
        }
      },
      highlights: [
        %{
          field: "note",
          matched_tokens: ["test"],
          snippet: "<mark>test</mark>"
        }
      ],
      text_match: score,
      text_match_info: %{
        best_field_score: "1108091339008",
        best_field_weight: 15,
        fields_matched: 1,
        num_tokens_dropped: 0,
        score: "#{score}",
        tokens_matched: 1,
        typo_prefix_score: 0
      }
    }
  end
end

# {:ok,
#  %{
#    "results" => [
#      %{
#        "facet_counts" => [],
#        "found" => 1,
#        "hits" => [
#          %{
#            "document" => %{
#              "email" => "jaxon.evans@gmail.com",
#              "first_name" => "Jaxon",
#              "id" => "8d71008c-f2dd-48ce-ad7f-b2f034320229",
#              "last_name" => "Test",
#              "ptt" => 0.02148957850440067,
#              "user_id" => "11f7dce1-f553-4572-8b06-e678cd7069d4"
#            },
#            "highlight" => %{
#              "last_name" => %{
#                "matched_tokens" => ["Test"],
#                "snippet" => "<mark>Test</mark>"
#              }
#            },
#            "highlights" => [
#              %{
#                "field" => "last_name",
#                "matched_tokens" => ["Test"],
#                "snippet" => "<mark>Test</mark>"
#              }
#            ],
#            "text_match" => 578730123365711985,
#            "text_match_info" => %{
#              "best_field_score" => "1108091339008",
#              "best_field_weight" => 14,
#              "fields_matched" => 1,
#              "num_tokens_dropped" => 0,
#              "score" => "578730123365711985",
#              "tokens_matched" => 1,
#              "typo_prefix_score" => 0
#            }
#          }
#        ],
#        "out_of" => 6270,
#        "page" => 1,
#        "request_params" => %{
#          "collection_name" => "contacts",
#          "first_q" => "test",
#          "per_page" => 10,
#          "q" => "test"
#        },
#        "search_cutoff" => false,
#        "search_time_ms" => 0
#      },
#      %{
#        "facet_counts" => [],
#        "found" => 5,
#        "hits" => [
#          %{
#            "document" => %{
#              "contact_id" => "f7600e42-66a2-46ec-8dc0-06242165d632",
#              "id" => "75c589a4-47bb-4461-8c89-ecf64ef73392",
#              "note" => "test",
#              "user_id" => "11f7dce1-f553-4572-8b06-e678cd7069d4"
#            },
#            "highlight" => %{
#              "note" => %{
#                "matched_tokens" => ["test"],
#                "snippet" => "<mark>test</mark>"
#              }
#            },
#            "highlights" => [
#              %{
#                "field" => "note",
#                "matched_tokens" => ["test"],
#                "snippet" => "<mark>test</mark>"
#              }
#            ],
#            "text_match" => 578730123365711993,
#            "text_match_info" => %{
#              "best_field_score" => "1108091339008",
#              "best_field_weight" => 15,
#              "fields_matched" => 1,
#              "num_tokens_dropped" => 0,
#              "score" => "578730123365711993",
#              "tokens_matched" => 1,
#              "typo_prefix_score" => 0
#            }
#          },
#          %{
#            "document" => %{
#              "contact_id" => "f7600e42-66a2-46ec-8dc0-06242165d632",
#              "id" => "724a9725-20ef-467b-9d3b-ff4b42753f4e",
#              "note" => "this is a test",
#              "user_id" => "11f7dce1-f553-4572-8b06-e678cd7069d4"
#            },
#            "highlight" => %{
#              "note" => %{
#                "matched_tokens" => ["test"],
#                "snippet" => "this is a <mark>test</mark>"
#              }
#            },
#            "highlights" => [
#              %{
#                "field" => "note",
#                "matched_tokens" => ["test"],
#                "snippet" => "this is a <mark>test</mark>"
#              }
#            ],
#            "text_match" => 578730123365187705,
#            "text_match_info" => %{
#              "best_field_score" => "1108091338752",
#              "best_field_weight" => 15,
#              "fields_matched" => 1,
#              "num_tokens_dropped" => 0,
#              "score" => "578730123365187705",
#              "tokens_matched" => 1,
#              "typo_prefix_score" => 0
#            }
#          },
#          %{
#            "document" => %{
#              "contact_id" => "fea7853d-7f79-4386-87d6-5cbf5dde0cb8",
#              "id" => "9e44778f-da48-49d8-8b64-bc6bcf2d40ce",
#              "note" => "test note 3",
#              "user_id" => "11f7dce1-f553-4572-8b06-e678cd7069d4"
#            },
#            "highlight" => %{
#              "note" => %{
#                "matched_tokens" => ["test"],
#                "snippet" => "<mark>test</mark> note 3"
#              }
#            },
#            "highlights" => [
#              %{
#                "field" => "note",
#                "matched_tokens" => ["test"],
#                "snippet" => "<mark>test</mark> note 3"
#              }
#            ],
#            "text_match" => 578730123365187705,
#            "text_match_info" => %{
#              "best_field_score" => "1108091338752",
#              "best_field_weight" => 15,
#              "fields_matched" => 1,
#              "num_tokens_dropped" => 0,
#              "score" => "578730123365187705",
#              "tokens_matched" => 1,
#              "typo_prefix_score" => 0
#            }
#          },
#          %{
#            "document" => %{
#              "contact_id" => "21e828cc-dd65-4f6a-8ec2-3031aa389f05",
#              "id" => "600b7874-d1fc-4f98-b6c1-322e56170a1a",
#              "note" => "test note 2",
#              "user_id" => "11f7dce1-f553-4572-8b06-e678cd7069d4"
#            },
#            "highlight" => %{
#              "note" => %{
#                "matched_tokens" => ["test"],
#                "snippet" => "<mark>test</mark> note 2"
#              }
#            },
#            "highlights" => [
#              %{
#                "field" => "note",
#                "matched_tokens" => ["test"],
#                "snippet" => "<mark>test</mark> note 2"
#              }
#            ],
#            "text_match" => 578730123365187705,
#            "text_match_info" => %{
#              "best_field_score" => "1108091338752",
#              "best_field_weight" => 15,
#              "fields_matched" => 1,
#              "num_tokens_dropped" => 0,
#              "score" => "578730123365187705",
#              "tokens_matched" => 1,
#              "typo_prefix_score" => 0
#            }
#          },
#          %{
#            "document" => %{
#              "contact_id" => "2d070e85-c6c6-486c-b1db-7f0cc5ae75e1",
#              "id" => "d2be5c0d-4bf1-4318-8ba2-0245942fe461",
#              "note" => "test note",
#              "user_id" => "11f7dce1-f553-4572-8b06-e678cd7069d4"
#            },
#            "highlight" => %{
#              "note" => %{
#                "matched_tokens" => ["test"],
#                "snippet" => "<mark>test</mark> note"
#              }
#            },
#            "highlights" => [
#              %{
#                "field" => "note",
#                "matched_tokens" => ["test"],
#                "snippet" => "<mark>test</mark> note"
#              }
#            ],
#            "text_match" => 578730123365187705,
#            "text_match_info" => %{
#              "best_field_score" => "1108091338752",
#              "best_field_weight" => 15,
#              "fields_matched" => 1,
#              "num_tokens_dropped" => 0,
#              "score" => "578730123365187705",
#              "tokens_matched" => 1,
#              "typo_prefix_score" => 0
#            }
#          }
#        ],
#        "out_of" => 13,
#        "page" => 1,
#        "request_params" => %{
#          "collection_name" => "notes",
#          "first_q" => "test",
#          "per_page" => 10,
#          "q" => "test"
#        },
#        "search_cutoff" => false,
#        "search_time_ms" => 0
#      }
#    ]
#  }}
