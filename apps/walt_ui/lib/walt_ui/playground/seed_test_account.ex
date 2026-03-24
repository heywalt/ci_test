defmodule WaltUi.Playground.SeedTestAccount do
  @moduledoc false

  alias WaltUi.Account
  alias WaltUi.Contacts

  def create_test_account do
    with {:ok, test_user} <-
           Account.create_user(%{
             email: "test@heywalt.ai",
             first_name: "Test",
             last_name: "Account"
           }) do
      Contacts.send_bulk_create_events(test_user, fake_contact_attrs())
    end
  end

  defp fake_contact_attrs do
    [
      %{
        "email" => "jennie2060@brekke.com",
        "first_name" => "Jany",
        "last_name" => "Gusikowski",
        "phone" => "689/959-6058",
        "remote_id" => "46c92016-c15d-4a92-bfc9-7263a2eccf8c",
        "remote_source" => "mobile"
      },
      %{
        "email" => "lazaro.kling@jenkins.com",
        "first_name" => "Cortez",
        "last_name" => "Thompson",
        "phone" => "246.728.1482",
        "remote_id" => "025da3a2-8a4d-4788-a497-517bde73a42f",
        "remote_source" => "mobile"
      },
      %{
        "email" => "sabryna1908@rath.name",
        "first_name" => "Nikita",
        "last_name" => "Gaylord",
        "phone" => "(500) 266-5340",
        "remote_id" => "6f60c692-42f1-4e5d-9a33-1c44f2e2748b",
        "remote_source" => "mobile"
      },
      %{
        "email" => "donato_wiegand@hyatt.net",
        "first_name" => "Kianna",
        "last_name" => "Sipes",
        "phone" => "200/928-9850",
        "remote_id" => "1e9fda15-1cdf-428b-abf7-32004c98e78d",
        "remote_source" => "mobile"
      },
      %{
        "email" => "garrick.satterfield@barrows.biz",
        "first_name" => "Vivien",
        "last_name" => "Lang",
        "phone" => "353.514.4575",
        "remote_id" => "37296351-8ccc-4550-9b78-5562c7aed3e5",
        "remote_source" => "mobile"
      },
      %{
        "email" => "harmon.ruecker@gleason.com",
        "first_name" => "Arnold",
        "last_name" => "Dietrich",
        "phone" => "928/374-8905",
        "remote_id" => "923a619f-0e7b-4f6d-b38e-6eaa6be39803",
        "remote_source" => "mobile"
      },
      %{
        "email" => "princess.harris@von.biz",
        "first_name" => "Keagan",
        "last_name" => "Parker",
        "phone" => "457/232-3568",
        "remote_id" => "5db6412b-dde3-424d-84ae-cf5dce399c34",
        "remote_source" => "mobile"
      },
      %{
        "email" => "curtis_tromp@cremin.org",
        "first_name" => "Diana",
        "last_name" => "Dickinson",
        "phone" => "5088774313",
        "remote_id" => "ee88c8e4-0267-4737-99d0-fd0de4ea7e47",
        "remote_source" => "mobile"
      },
      %{
        "email" => "amelie2054@ziemann.org",
        "first_name" => "Alan",
        "last_name" => "Ritchie",
        "phone" => "(937) 643-2036",
        "remote_id" => "e4e04d18-9624-4fe7-bf5d-fc83688634a6",
        "remote_source" => "mobile"
      },
      %{
        "email" => "jayne2070@schinner.info",
        "first_name" => "Daisy",
        "last_name" => "Steuber",
        "phone" => "738-443-8338",
        "remote_id" => "4bd7a4e6-4d9a-4fda-aa22-aaa459e72a8e",
        "remote_source" => "mobile"
      },
      %{
        "email" => "elouise_mante@williamson.name",
        "first_name" => "Thomas",
        "last_name" => "Schinner",
        "phone" => "401-581-7616",
        "remote_id" => "2ce3330f-badf-4ff9-b25f-995167453360",
        "remote_source" => "mobile"
      },
      %{
        "email" => "harvey_fadel@willms.info",
        "first_name" => "Lemuel",
        "last_name" => "Swaniawski",
        "phone" => "852.887.0929",
        "remote_id" => "484ddd16-a8fb-430b-8549-ee4a1901348d",
        "remote_source" => "mobile"
      },
      %{
        "email" => "astrid2032@hoeger.biz",
        "first_name" => "Hillary",
        "last_name" => "Shanahan",
        "phone" => "355/929-7094",
        "remote_id" => "4e2a54be-c2ac-42b2-989f-d354d7c864e0",
        "remote_source" => "mobile"
      },
      %{
        "email" => "audie.beahan@christiansen.org",
        "first_name" => "Justina",
        "last_name" => "Brown",
        "phone" => "741-515-7904",
        "remote_id" => "6722b574-c623-43fb-80db-d2cf6970dd7c",
        "remote_source" => "mobile"
      },
      %{
        "email" => "elmer2056@schumm.biz",
        "first_name" => "Cristopher",
        "last_name" => "Wilderman",
        "phone" => "903/359-6819",
        "remote_id" => "794675da-a759-44dc-9f4b-d122921e58d8",
        "remote_source" => "mobile"
      },
      %{
        "email" => "mark.watsica@wilderman.org",
        "first_name" => "Ariel",
        "last_name" => "Gleason",
        "phone" => "308.216.0963",
        "remote_id" => "a6f51730-c409-42a8-918d-b43e95c1ae82",
        "remote_source" => "mobile"
      },
      %{
        "email" => "rowland_roberts@weber.info",
        "first_name" => "Leonor",
        "last_name" => "McKenzie",
        "phone" => "436-605-2691",
        "remote_id" => "89d7e980-30d2-458a-aaed-af95e4d1011f",
        "remote_source" => "mobile"
      },
      %{
        "email" => "arden_kunze@schimmel.org",
        "first_name" => "Toney",
        "last_name" => "Hermiston",
        "phone" => "9564677641",
        "remote_id" => "814f1464-a9e7-4d34-8120-1028eadb4bc5",
        "remote_source" => "mobile"
      },
      %{
        "email" => "bethel2061@davis.name",
        "first_name" => "Ophelia",
        "last_name" => "Senger",
        "phone" => "533/536-0700",
        "remote_id" => "7a4a9a36-d767-44f8-b6ed-e52e42951986",
        "remote_source" => "mobile"
      },
      %{
        "email" => "janick2000@howell.name",
        "first_name" => "Alexzander",
        "last_name" => "Hand",
        "phone" => "(934) 304-0737",
        "remote_id" => "f3778ba9-12ec-4d61-9b0f-887cc4afe985",
        "remote_source" => "mobile"
      },
      %{
        "email" => "ned1927@douglas.org",
        "first_name" => "Declan",
        "last_name" => "Mueller",
        "phone" => "411/945-6772",
        "remote_id" => "54b1ef82-3d0c-4950-b022-e752bb2741f6",
        "remote_source" => "mobile"
      },
      %{
        "email" => "uriel1959@keeling.info",
        "first_name" => "Diamond",
        "last_name" => "Morissette",
        "phone" => "(521) 854-3992",
        "remote_id" => "0bfcbba3-dbda-4914-94c7-6dedab201299",
        "remote_source" => "mobile"
      },
      %{
        "email" => "tressa_boehm@ohara.biz",
        "first_name" => "Roma",
        "last_name" => "Miller",
        "phone" => "776/577-7682",
        "remote_id" => "71e718e5-26af-4a36-bc6b-79a30591e296",
        "remote_source" => "mobile"
      },
      %{
        "email" => "rosalinda1951@kub.info",
        "first_name" => "Orie",
        "last_name" => "Conroy",
        "phone" => "(976) 486-2379",
        "remote_id" => "d2a14685-16e0-4929-8804-1e4878ba454f",
        "remote_source" => "mobile"
      },
      %{
        "email" => "monserrate_brakus@marks.com",
        "first_name" => "Daron",
        "last_name" => "Nienow",
        "phone" => "780/469-8494",
        "remote_id" => "fc8f25e3-f53f-47be-ac46-f4f7f45cc62e",
        "remote_source" => "mobile"
      },
      %{
        "email" => "susanna.streich@morar.info",
        "first_name" => "Gerda",
        "last_name" => "Hintz",
        "phone" => "6298935189",
        "remote_id" => "82424401-2584-4483-9768-8518f76acaf3",
        "remote_source" => "mobile"
      },
      %{
        "email" => "sophie1962@mcdermott.org",
        "first_name" => "Jaquan",
        "last_name" => "Altenwerth",
        "phone" => "288-494-2684",
        "remote_id" => "4cd91781-b760-4267-a2c2-a11b9d7a2bae",
        "remote_source" => "mobile"
      },
      %{
        "email" => "hailie1976@feest.net",
        "first_name" => "Kody",
        "last_name" => "O'Hara",
        "phone" => "879-757-3665",
        "remote_id" => "ae8b6a72-4bea-4b82-8f85-b187cfed98bf",
        "remote_source" => "mobile"
      },
      %{
        "email" => "chelsey2077@reinger.org",
        "first_name" => "Trent",
        "last_name" => "Torp",
        "phone" => "418/351-6106",
        "remote_id" => "bc0d2c6b-65ab-484a-b9c4-b957474460bd",
        "remote_source" => "mobile"
      },
      %{
        "email" => "ervin_gerhold@raynor.net",
        "first_name" => "Tina",
        "last_name" => "Mueller",
        "phone" => "(247) 608-4049",
        "remote_id" => "bbf7e669-d337-4b55-931e-52d21f0d363e",
        "remote_source" => "mobile"
      },
      %{
        "email" => "jana.conn@emmerich.net",
        "first_name" => "Orlando",
        "last_name" => "Kunde",
        "phone" => "633/691-6016",
        "remote_id" => "06126904-654e-4c6e-9620-f04401564459",
        "remote_source" => "mobile"
      },
      %{
        "email" => "delphia1902@hahn.org",
        "first_name" => "Orrin",
        "last_name" => "Torp",
        "phone" => "(980) 328-5556",
        "remote_id" => "c3e27406-7435-4183-8e17-8893123c01c9",
        "remote_source" => "mobile"
      },
      %{
        "email" => "sydney2050@hane.com",
        "first_name" => "Dagmar",
        "last_name" => "Prosacco",
        "phone" => "840.337.2105",
        "remote_id" => "7050bf0c-541a-4003-8a3b-fcda0a45dc96",
        "remote_source" => "mobile"
      },
      %{
        "email" => "daija2021@mcdermott.net",
        "first_name" => "Colten",
        "last_name" => "O'Connell",
        "phone" => "221/236-1625",
        "remote_id" => "7e4c90fc-018b-49a6-bd2f-07f7e0b0c1af",
        "remote_source" => "mobile"
      },
      %{
        "email" => "cicero1921@corwin.com",
        "first_name" => "Adell",
        "last_name" => "Jerde",
        "phone" => "461-635-4628",
        "remote_id" => "301ec292-4f43-4199-bee3-ea56169b4ee6",
        "remote_source" => "mobile"
      },
      %{
        "email" => "dagmar.labadie@mcclure.biz",
        "first_name" => "Hilma",
        "last_name" => "Collier",
        "phone" => "(524) 836-3642",
        "remote_id" => "bfe6386c-be2a-481d-b92a-38bf22800073",
        "remote_source" => "mobile"
      },
      %{
        "email" => "saige1935@stracke.biz",
        "first_name" => "Khalil",
        "last_name" => "Romaguera",
        "phone" => "5063786656",
        "remote_id" => "5e683d6d-dd23-4e0c-bf9b-9eebf41b3a84",
        "remote_source" => "mobile"
      },
      %{
        "email" => "kyleigh1953@stoltenberg.info",
        "first_name" => "Leilani",
        "last_name" => "Walter",
        "phone" => "983-369-1752",
        "remote_id" => "0233fb9b-a256-4611-b335-a359f5b6cb5f",
        "remote_source" => "mobile"
      },
      %{
        "email" => "alda.kautzer@schmeler.net",
        "first_name" => "Maxie",
        "last_name" => "Runolfsson",
        "phone" => "(257) 677-4109",
        "remote_id" => "39d4085e-748e-4a3e-80cc-8ffc60d6e655",
        "remote_source" => "mobile"
      },
      %{
        "email" => "kiara1942@dickinson.biz",
        "first_name" => "Forrest",
        "last_name" => "Adams",
        "phone" => "827-818-8938",
        "remote_id" => "283f9ffc-2b3b-4a6c-9f48-04f0b82a2cb6",
        "remote_source" => "mobile"
      },
      %{
        "email" => "flavio1916@collier.net",
        "first_name" => "Wendy",
        "last_name" => "Spinka",
        "phone" => "369/555-2779",
        "remote_id" => "fccc53a6-2f85-4c9b-803b-64012f13923b",
        "remote_source" => "mobile"
      },
      %{
        "email" => "john1916@schultz.biz",
        "first_name" => "Aylin",
        "last_name" => "Koepp",
        "phone" => "4223147987",
        "remote_id" => "0326091c-69ae-40ad-b94c-5a27dad940c7",
        "remote_source" => "mobile"
      },
      %{
        "email" => "boris.osinski@lakin.com",
        "first_name" => "Weldon",
        "last_name" => "Franecki",
        "phone" => "287/592-0457",
        "remote_id" => "77f73458-2af0-441a-9409-62f71e9792c3",
        "remote_source" => "mobile"
      },
      %{
        "email" => "garfield_schaefer@senger.biz",
        "first_name" => "Wilton",
        "last_name" => "Durgan",
        "phone" => "(783) 971-5039",
        "remote_id" => "d2680929-8547-4b86-8a51-d0eb0dbba7ef",
        "remote_source" => "mobile"
      },
      %{
        "email" => "joanie2094@greenfelder.com",
        "first_name" => "Damian",
        "last_name" => "Senger",
        "phone" => "(869) 759-0356",
        "remote_id" => "fc69baf5-9dd1-4c7d-bcd3-b11ed6efa311",
        "remote_source" => "mobile"
      },
      %{
        "email" => "eugenia_muller@hilll.com",
        "first_name" => "Pattie",
        "last_name" => "Koss",
        "phone" => "(345) 505-4492",
        "remote_id" => "100a100d-86f3-4511-a312-05c69b86d56a",
        "remote_source" => "mobile"
      },
      %{
        "email" => "ludwig1951@kihn.biz",
        "first_name" => "Millie",
        "last_name" => "Gibson",
        "phone" => "9085336124",
        "remote_id" => "75a5c7de-13f1-46b5-b81b-25f7af98ec1d",
        "remote_source" => "mobile"
      },
      %{
        "email" => "wade2058@osinski.info",
        "first_name" => "Merlin",
        "last_name" => "Dietrich",
        "phone" => "783/245-5625",
        "remote_id" => "0e13f723-3def-4718-babf-51c379a3b6e0",
        "remote_source" => "mobile"
      },
      %{
        "email" => "evangeline2006@cruickshank.com",
        "first_name" => "Weldon",
        "last_name" => "Wuckert",
        "phone" => "2126219411",
        "remote_id" => "334627d7-4b71-4e10-a3a4-b1bc1d37fb26",
        "remote_source" => "mobile"
      },
      %{
        "email" => "nikki.strosin@conroy.biz",
        "first_name" => "Earnest",
        "last_name" => "Bayer",
        "phone" => "600.287.2589",
        "remote_id" => "5b6f58c3-ba3f-4c4a-93f0-2eff21f08d78",
        "remote_source" => "mobile"
      },
      %{
        "email" => "flossie2080@botsford.biz",
        "first_name" => "Minnie",
        "last_name" => "Gleichner",
        "phone" => "724-935-1972",
        "remote_id" => "d749507b-cb76-4f72-bd85-ff04248cb7f5",
        "remote_source" => "mobile"
      },
      %{
        "email" => "sherwood2077@little.name",
        "first_name" => "Gladys",
        "last_name" => "Corwin",
        "phone" => "3767752148",
        "remote_id" => "e5598203-cf40-4197-94d8-57377e62ea7a",
        "remote_source" => "mobile"
      },
      %{
        "email" => "christophe.kub@kilback.biz",
        "first_name" => "Alessandra",
        "last_name" => "Schneider",
        "phone" => "(667) 891-5932",
        "remote_id" => "e15933c7-7a8d-4dc7-92e9-8eaed1dffa9d",
        "remote_source" => "mobile"
      },
      %{
        "email" => "elliott1914@spinka.net",
        "first_name" => "Ila",
        "last_name" => "Mayert",
        "phone" => "566/541-8752",
        "remote_id" => "078b2a80-b473-410a-baaa-fe7a23edb5f0",
        "remote_source" => "mobile"
      },
      %{
        "email" => "verdie_sipes@hickle.com",
        "first_name" => "Dana",
        "last_name" => "Nienow",
        "phone" => "344.855.7877",
        "remote_id" => "49ea531a-44ea-4f72-895e-379516a1eb9a",
        "remote_source" => "mobile"
      },
      %{
        "email" => "delilah.koepp@olson.com",
        "first_name" => "Alyson",
        "last_name" => "Weimann",
        "phone" => "665-304-4130",
        "remote_id" => "10614cda-8c20-4373-8c51-430d44c8e2f6",
        "remote_source" => "mobile"
      },
      %{
        "email" => "diana.fadel@daugherty.biz",
        "first_name" => "Moshe",
        "last_name" => "Hessel",
        "phone" => "649.413.6174",
        "remote_id" => "00fe6b1e-e1e0-4533-95c4-6dc8e587cea8",
        "remote_source" => "mobile"
      },
      %{
        "email" => "lisette_schiller@vandervort.org",
        "first_name" => "Garrick",
        "last_name" => "Reinger",
        "phone" => "453-667-5919",
        "remote_id" => "7d1f724c-4b68-4a28-8308-07de926f0581",
        "remote_source" => "mobile"
      },
      %{
        "email" => "shakira.johnson@kunze.net",
        "first_name" => "Dan",
        "last_name" => "Auer",
        "phone" => "6095898850",
        "remote_id" => "a1fc51e6-3baf-476d-95b8-59b2496faa60",
        "remote_source" => "mobile"
      },
      %{
        "email" => "antoinette.kub@gerhold.biz",
        "first_name" => "Reilly",
        "last_name" => "Baumbach",
        "phone" => "(584) 778-4864",
        "remote_id" => "10ff1333-4ad1-4be7-a059-72d6041878f6",
        "remote_source" => "mobile"
      },
      %{
        "email" => "betsy_greenholt@johns.biz",
        "first_name" => "Maddison",
        "last_name" => "Walter",
        "phone" => "2217360978",
        "remote_id" => "67a6a9ce-e91a-474d-ae7e-3c0043cace1c",
        "remote_source" => "mobile"
      },
      %{
        "email" => "bernice2006@hahn.name",
        "first_name" => "Delpha",
        "last_name" => "Marvin",
        "phone" => "268/817-0422",
        "remote_id" => "7dd61ed4-0c70-4eab-ab6c-00b7631f095b",
        "remote_source" => "mobile"
      },
      %{
        "email" => "linwood_bernier@vandervort.com",
        "first_name" => "Cassandre",
        "last_name" => "Will",
        "phone" => "249/403-4299",
        "remote_id" => "1f99f97e-7b47-4e17-bc67-64dc787c1a07",
        "remote_source" => "mobile"
      },
      %{
        "email" => "angelina1923@bartell.net",
        "first_name" => "Demetrius",
        "last_name" => "Balistreri",
        "phone" => "402/398-7247",
        "remote_id" => "e5f6b0ac-0330-4658-a783-6d455e842f7d",
        "remote_source" => "mobile"
      },
      %{
        "email" => "robb2074@oberbrunner.biz",
        "first_name" => "Stephania",
        "last_name" => "Johns",
        "phone" => "666-994-5982",
        "remote_id" => "c816aca3-8330-47c6-8e73-a80f6f92da22",
        "remote_source" => "mobile"
      },
      %{
        "email" => "gudrun_bergstrom@hermiston.info",
        "first_name" => "Troy",
        "last_name" => "Dicki",
        "phone" => "(740) 501-8742",
        "remote_id" => "99a5c49a-64c8-4954-83e7-ac29df67f9b0",
        "remote_source" => "mobile"
      },
      %{
        "email" => "neal_jaskolski@zemlak.org",
        "first_name" => "Josianne",
        "last_name" => "Ruecker",
        "phone" => "(859) 669-8291",
        "remote_id" => "59ebf402-d7b0-48b3-9bc4-71239039a910",
        "remote_source" => "mobile"
      },
      %{
        "email" => "annabelle2073@ondricka.info",
        "first_name" => "Quincy",
        "last_name" => "Fay",
        "phone" => "(528) 483-3402",
        "remote_id" => "1e00f6a0-6cc7-4460-92e0-5f2fad918ac7",
        "remote_source" => "mobile"
      },
      %{
        "email" => "athena.leffler@emard.name",
        "first_name" => "Zackery",
        "last_name" => "O'Keefe",
        "phone" => "402.815.6768",
        "remote_id" => "bfc156ee-cf15-4faf-901f-3842ea4d6298",
        "remote_source" => "mobile"
      },
      %{
        "email" => "tremayne2066@waelchi.com",
        "first_name" => "Bo",
        "last_name" => "Hand",
        "phone" => "(907) 316-8101",
        "remote_id" => "0861d220-78df-4482-bdd3-57d7dbe64153",
        "remote_source" => "mobile"
      },
      %{
        "email" => "adrain2009@nienow.biz",
        "first_name" => "Darron",
        "last_name" => "Breitenberg",
        "phone" => "407.866.6570",
        "remote_id" => "0dc475b7-dae8-4de1-935b-08f93d6e49e5",
        "remote_source" => "mobile"
      },
      %{
        "email" => "fernando2016@bradtke.com",
        "first_name" => "Irma",
        "last_name" => "Ankunding",
        "phone" => "8467522417",
        "remote_id" => "ecd733be-48ae-4809-b15a-7d696235df79",
        "remote_source" => "mobile"
      },
      %{
        "email" => "cordelia1950@kiehn.com",
        "first_name" => "Zoey",
        "last_name" => "Erdman",
        "phone" => "(528) 822-2565",
        "remote_id" => "df9e2a71-0ba6-4b12-9f98-4baa28abbe68",
        "remote_source" => "mobile"
      },
      %{
        "email" => "nicola_batz@boehm.biz",
        "first_name" => "Maybelle",
        "last_name" => "Goyette",
        "phone" => "743/988-7680",
        "remote_id" => "1cc42d75-fb68-4cfa-b035-3e16fa339f8c",
        "remote_source" => "mobile"
      },
      %{
        "email" => "wilma1976@kub.name",
        "first_name" => "Eudora",
        "last_name" => "Veum",
        "phone" => "5456244907",
        "remote_id" => "60bc9bae-a140-418d-999b-cd86a8ec1ec9",
        "remote_source" => "mobile"
      },
      %{
        "email" => "helene1940@kunde.net",
        "first_name" => "Reilly",
        "last_name" => "Windler",
        "phone" => "2434493139",
        "remote_id" => "2a094604-ef30-4769-9475-11c37657d28e",
        "remote_source" => "mobile"
      },
      %{
        "email" => "caitlyn2001@leannon.biz",
        "first_name" => "Taurean",
        "last_name" => "Bauch",
        "phone" => "914/699-7355",
        "remote_id" => "12c202d0-4f5e-46b0-a195-ba8e3d0428c1",
        "remote_source" => "mobile"
      },
      %{
        "email" => "kaitlin2060@okuneva.com",
        "first_name" => "Nyah",
        "last_name" => "Marks",
        "phone" => "(360) 578-0975",
        "remote_id" => "c4306f25-de44-4cdc-9fb8-949a1d3025e6",
        "remote_source" => "mobile"
      },
      %{
        "email" => "aracely1948@bayer.name",
        "first_name" => "Emery",
        "last_name" => "Mueller",
        "phone" => "(320) 917-4554",
        "remote_id" => "892e3664-0a5e-4b56-b391-8921c830217c",
        "remote_source" => "mobile"
      },
      %{
        "email" => "ethyl2099@friesen.org",
        "first_name" => "Barry",
        "last_name" => "Beatty",
        "phone" => "357-683-4365",
        "remote_id" => "6e849595-cfd8-4592-a35a-fb4dcc0e46f2",
        "remote_source" => "mobile"
      },
      %{
        "email" => "coy1916@toy.name",
        "first_name" => "Shanel",
        "last_name" => "Koepp",
        "phone" => "659-737-0117",
        "remote_id" => "83f5c534-cf7b-4223-a8b9-165bd3c47b2c",
        "remote_source" => "mobile"
      },
      %{
        "email" => "maximilian.dicki@runte.com",
        "first_name" => "Juana",
        "last_name" => "Cartwright",
        "phone" => "827.615.7535",
        "remote_id" => "017e1d59-223f-48e5-be0c-4af79de4c115",
        "remote_source" => "mobile"
      },
      %{
        "email" => "godfrey1937@bayer.org",
        "first_name" => "Trystan",
        "last_name" => "Murray",
        "phone" => "617/887-2836",
        "remote_id" => "1e4b58b5-de17-438d-a13b-1163fd333011",
        "remote_source" => "mobile"
      },
      %{
        "email" => "chanelle.greenholt@schmidt.net",
        "first_name" => "Dorothy",
        "last_name" => "Heidenreich",
        "phone" => "716-689-7125",
        "remote_id" => "6c73afe3-1563-409a-8dc4-79a4c7d30f96",
        "remote_source" => "mobile"
      },
      %{
        "email" => "pedro2039@muller.com",
        "first_name" => "Joany",
        "last_name" => "Schuppe",
        "phone" => "8557715976",
        "remote_id" => "9dd060ba-67f0-4d8a-b2e0-669a40dc7ca2",
        "remote_source" => "mobile"
      },
      %{
        "email" => "clementine_bosco@schiller.name",
        "first_name" => "Eryn",
        "last_name" => "Cummerata",
        "phone" => "722-933-5777",
        "remote_id" => "c3157a5c-15b4-44ef-8435-25d8490abb85",
        "remote_source" => "mobile"
      },
      %{
        "email" => "frederik.wintheiser@tremblay.com",
        "first_name" => "Silas",
        "last_name" => "Wisoky",
        "phone" => "(455) 295-3172",
        "remote_id" => "c318701f-1551-4865-9841-8d1d1a60ce8e",
        "remote_source" => "mobile"
      },
      %{
        "email" => "scottie2087@abshire.com",
        "first_name" => "Kelly",
        "last_name" => "Robel",
        "phone" => "654/245-5795",
        "remote_id" => "8fa2b715-d263-4fe6-badb-024f1cf59d55",
        "remote_source" => "mobile"
      },
      %{
        "email" => "malinda1951@kozey.net",
        "first_name" => "Shanna",
        "last_name" => "Wiza",
        "phone" => "907/948-1989",
        "remote_id" => "3c22dc9f-bf57-40ae-968c-126cd95ecfd1",
        "remote_source" => "mobile"
      },
      %{
        "email" => "brandi.walsh@donnelly.net",
        "first_name" => "Lorenzo",
        "last_name" => "MacGyver",
        "phone" => "471.717.4647",
        "remote_id" => "15833fd4-92b0-4bc5-8494-19f19298f4d1",
        "remote_source" => "mobile"
      },
      %{
        "email" => "reynold1940@bechtelar.net",
        "first_name" => "Lizzie",
        "last_name" => "Gaylord",
        "phone" => "368-578-3077",
        "remote_id" => "e7e03f48-9f98-4d70-acaf-7d05d4a0c349",
        "remote_source" => "mobile"
      },
      %{
        "email" => "steve_lynch@maggio.info",
        "first_name" => "Nelda",
        "last_name" => "Reynolds",
        "phone" => "2317992354",
        "remote_id" => "4515c7e5-8927-44df-93bd-c9a0107a67f3",
        "remote_source" => "mobile"
      },
      %{
        "email" => "lew_crooks@berge.com",
        "first_name" => "Zelda",
        "last_name" => "Braun",
        "phone" => "363-258-2343",
        "remote_id" => "a65907eb-2c6d-4cbe-8d56-dc80d22955e9",
        "remote_source" => "mobile"
      },
      %{
        "email" => "nola.schoen@buckridge.name",
        "first_name" => "Karina",
        "last_name" => "Zieme",
        "phone" => "4135631122",
        "remote_id" => "138a9762-c891-4ea5-a3dd-0c2f5668d33a",
        "remote_source" => "mobile"
      },
      %{
        "email" => "ryder2049@hahn.com",
        "first_name" => "Jaylin",
        "last_name" => "Dietrich",
        "phone" => "2187249069",
        "remote_id" => "f89d49f3-f840-4a58-aaa5-876503788bbb",
        "remote_source" => "mobile"
      },
      %{
        "email" => "flavie2051@kutch.net",
        "first_name" => "Brooks",
        "last_name" => "Sipes",
        "phone" => "846/559-7416",
        "remote_id" => "75662f1e-aeae-48c4-9531-82d628089038",
        "remote_source" => "mobile"
      },
      %{
        "email" => "dusty1978@lubowitz.name",
        "first_name" => "Lavinia",
        "last_name" => "Koepp",
        "phone" => "(640) 585-5180",
        "remote_id" => "553c35a2-7d72-4d77-b158-feb201eb15e3",
        "remote_source" => "mobile"
      },
      %{
        "email" => "joey.veum@auer.net",
        "first_name" => "Bernadette",
        "last_name" => "Effertz",
        "phone" => "513.429.5099",
        "remote_id" => "5ba4d888-4aaf-4f73-8e24-f49d1af6307c",
        "remote_source" => "mobile"
      },
      %{
        "email" => "pierre.jaskolski@cummerata.info",
        "first_name" => "Merle",
        "last_name" => "Rogahn",
        "phone" => "643/408-3837",
        "remote_id" => "d0dee50c-f452-4cb0-8a82-f48864a12f42",
        "remote_source" => "mobile"
      },
      %{
        "email" => "sim1938@gleichner.net",
        "first_name" => "Darby",
        "last_name" => "Bednar",
        "phone" => "9027667077",
        "remote_id" => "b1b2a02b-2c3e-4ae7-acf8-fc488ab18daa",
        "remote_source" => "mobile"
      }
    ]
  end
end
