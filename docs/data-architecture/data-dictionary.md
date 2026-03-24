# Amby Data Dictionary

This document defines the structure, content, and variable definitions for
every persisted entity in the Amby domain model. It is intended to enable any
team member -- current or future -- to understand what each piece of data
represents, how it is constrained, and where it fits in the overall system.

## Conventions

- **Primary keys** are UUIDs (`binary_id`) unless noted otherwise.
- **Timestamps**: every table includes `inserted_at` and `updated_at`
  (UTC datetimes) unless noted otherwise.
- **Required** means the field must be present for a valid changeset.
- **Allowed values** lists every value the system accepts; any other value
  is rejected at the application layer.
- **Units** are stated where the raw number is not self-evident.

## Custom Types

| Type | Module | Description |
|:-----|:-------|:------------|
| TenDigitPhone | `Repo.Types.TenDigitPhone` | A normalized 10-digit United States phone number, stored without country code or formatting characters. Example: `5551234567`. |

---

## Account and Authentication

### User

**Module:** `WaltUi.Account.User`
**Table:** `users`

A user is a real estate professional who has signed up for an Amby account.
Users are the top-level tenant in the system: almost every other entity
belongs to a user. A user authenticates via Auth0 and may optionally connect
external accounts (Google, SkySlope) to sync email and calendar data. Users
exist on one of two tiers -- freemium or premium -- which gate access to
enrichment and AI features.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `auth_uid` | Auth0 User ID | string | no | any | | | The unique identifier assigned by Auth0 when the user first authenticates. Used to match incoming OAuth callbacks to internal user records. |
| `email` | Email Address | string | yes | valid email | | | The user's primary email address. Used for login identification and system notifications. |
| `first_name` | First Name | string | no | any | | | The user's given name, displayed in the UI and used in outbound communications. |
| `last_name` | Last Name | string | no | any | | | The user's family name. |
| `phone` | Phone Number | string | no | any | | | The user's own phone number, used for display purposes. Not normalized to TenDigitPhone. |
| `bio` | Biography | string | no | any | | | A free-text self-description the user can set for their profile. |
| `company_name` | Company Name | string | no | any | | | The name of the brokerage or company the user works for. |
| `avatar` | Avatar URL | string | no | valid URL | | | A URL pointing to the user's profile picture. May come from Auth0, Gravatar, or direct upload. |
| `is_admin` | Administrator Flag | boolean | no | true, false | | | When true, the user has access to the admin dashboard at `/manage`. |
| `tier` | Subscription Tier | enum | no | `freemium`, `premium` | `freemium` | | Controls which features are available. Premium users get enrichment, AI scoring, and additional integrations. |
| `type` | Professional Role | enum | no | `agent`, `loan_officer`, `title`, `other` | | | The user's role in the real estate industry. Used to tailor the UI experience and enrichment priorities. |
| `contact_count` | Contact Count | integer | no | >= 0 | | contacts | A computed (virtual) field that holds the number of contacts the user owns. Not persisted to the database. |

**Associations:**

- `has_many :calendars` -> Calendar
- `has_many :contacts` -> Contact
- `has_many :external_accounts` -> ExternalAccount
- `has_many :fcm_tokens` -> FcmToken
- `has_one :subscription` -> Subscription

---

### Session

**Module:** `WaltUi.Account.Session`
**Table:** `sessions`

A session represents an active authentication session for a user. When a user
logs in through Auth0, the system creates a session record that stores the raw
authentication payload and an expiration timestamp. Sessions are checked on
every request to verify the user is still authenticated.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `auth_data` | Authentication Payload | map | no | any JSON | | | The raw authentication data returned by Auth0 at login time. Contains tokens, scopes, and provider metadata. |
| `expires_at` | Expiration Time | naive_datetime | yes | any valid datetime | | | The point in time after which this session is no longer valid. Requests made after this time require re-authentication. |

**Associations:**

- `belongs_to :user` -> User

---

### External Account

**Module:** `WaltUi.ExternalAccounts.ExternalAccount`
**Table:** `external_accounts`

An external account is an OAuth connection between an Amby user and a
third-party service like Google or SkySlope. It stores the OAuth tokens
needed to access the third-party API on the user's behalf. For Google
accounts, this enables Gmail email syncing and Google Calendar integration.
The system uses the stored refresh token to obtain new access tokens when the
current one expires.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `access_token` | Access Token | string | yes | any | | | The current OAuth access token used to make API calls to the external service. Rotated automatically when it expires. |
| `refresh_token` | Refresh Token | string | yes | any | | | The long-lived OAuth refresh token used to obtain new access tokens without requiring the user to re-authenticate. |
| `email` | Account Email | string | no | valid email | | | The email address associated with the external account. May differ from the user's Amby email. |
| `expires_at` | Token Expiration | utc_datetime_usec | yes | any valid datetime | | | The point in time when the current access token expires and must be refreshed. |
| `gmail_history_id` | Gmail History ID | string | no | any | | | A cursor provided by the Gmail API that tracks the last synced position. Used for incremental sync so the system only fetches new messages. |
| `historical_sync_metadata` | Historical Sync Metadata | map | no | any JSON | `%{}` | | Tracks the progress of initial historical email/calendar sync. Stores page tokens, date ranges, and completion status for backfill jobs. |
| `provider` | Provider | enum | yes | `google`, `skyslope` | | | Which external service this account connects to. |
| `provider_user_id` | Provider User ID | string | no | any | | | The unique identifier for the user within the external service's system. |
| `token_source` | Token Source Platform | enum | yes | `android`, `ios`, `web` | | | Which platform the user used to authorize the connection. Affects how token refresh works because each platform uses different OAuth flows. |

**Associations:**

- `belongs_to :user` -> User

---

## Contacts

### Contact

**Module:** `WaltUi.Projections.Contact`
**Table:** `projection_contacts`
**Primary key:** externally assigned UUID (no autogenerate)

A contact is a person in a user's professional network -- typically a client,
lead, or referral partner. This is the central entity in the Amby domain
model. Contacts are created via manual entry, phone contact import, or CSV
upload. Each contact belongs to exactly one user, but multiple users' contacts
that share the same phone number are linked through a unified contact record
for cross-user enrichment.

As a CQRS projection (read model), this record is derived from events
produced by the `LeadAggregate`. Its ID is assigned by the aggregate, not
auto-generated by the database.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `first_name` | First Name | string | no | any | | | The contact's given name. |
| `last_name` | Last Name | string | no | any | | | The contact's family name. |
| `email` | Primary Email | string | no | valid email | | | The contact's primary email address. Displayed prominently on the contact detail screen. |
| `phone` | Phone Number (Raw) | string | yes | any | | | The phone number as originally entered or imported. May contain formatting characters like parentheses, dashes, or a country code. |
| `standard_phone` | Phone Number (Normalized) | TenDigitPhone | no | 10-digit US number | | | The phone number cleaned and normalized to a 10-digit format. Used for matching contacts to unified records and enrichment data. |
| `avatar` | Avatar URL | string | no | valid URL | | | A URL to the contact's profile picture, typically sourced from Gravatar or manual upload. |
| `birthday` | Birthday | date | no | any valid date | | | The contact's date of birth. Used for birthday reminders and age calculation. |
| `anniversary` | Anniversary | date | no | any valid date | | | A personally significant date for the contact, such as a wedding anniversary. Used for automated reminder tasks. |
| `date_of_home_purchase` | Home Purchase Date | date | no | any valid date | | | The date the contact most recently purchased a home. Used in propensity-to-transact scoring and lifecycle marketing. |
| `street_1` | Street Address Line 1 | string | no | any | | | The primary line of the contact's mailing address. |
| `street_2` | Street Address Line 2 | string | no | any | | | The secondary address line (apartment, suite, unit). |
| `city` | City | string | no | any | | | The city portion of the contact's address. |
| `state` | State | string | no | any | | | The state or territory portion of the contact's address. Typically a two-letter abbreviation. |
| `zip` | ZIP Code | string | no | any | | | The postal code portion of the contact's address. |
| `latitude` | Latitude | decimal | no | -90.0 to 90.0 | | degrees | The geographic latitude of the contact's address, obtained via geocoding. Used for map display and proximity features. |
| `longitude` | Longitude | decimal | no | -180.0 to 180.0 | | degrees | The geographic longitude of the contact's address. |
| `ptt` | Propensity to Transact | integer | no | 0 to 100 | | score | A composite score indicating how likely the contact is to buy or sell a home in the near future. Higher values mean higher likelihood. Derived from Faraday data and adjusted by the Jitter AI model. |
| `is_favorite` | Favorite Flag | boolean | no | true, false | | | When true, the contact appears in the user's favorites list for quick access. |
| `is_hidden` | Hidden Flag | boolean | no | true, false | `false` | | When true, the contact is excluded from the main contact list but not deleted. Used for contacts the user does not want to see but may need later. |
| `remote_id` | External System ID | string | no | any | | | The identifier for this contact in the system it was imported from (e.g., a phone contact ID or CRM record ID). |
| `remote_source` | External System Name | string | no | any | | | The name of the system this contact was imported from (e.g., "google_contacts", "csv"). |
| `enrichment_id` | Enrichment ID | binary_id | no | valid UUID | | | Foreign key linking to the merged enrichment projection that contains combined demographic and property data for this contact. |
| `user_id` | Owner User ID | binary_id | yes | valid UUID | | | Foreign key to the user who owns this contact. |
| `enrichment` | Enrichment Data | map | no | any | | | A virtual (non-persisted) field used to hold preloaded enrichment data at query time. |
| `is_showcased` | Showcased Flag | boolean | no | true, false | | | A virtual (non-persisted) field indicating whether this contact has been selected for the contact showcase feature. |

**Embedded collections:**

- `phone_numbers` -> list of PhoneNumber (all known phone numbers with labels)
- `emails` -> list of Email (all known email addresses with labels)

**Associations:**

- `belongs_to :unified_contact` -> UnifiedContact
- `has_many :events` -> ContactEvent
- `has_many :notes` -> Note
- `many_to_many :tags` -> Tag (through `contact_tags`)

---

### Phone Number (embedded)

**Module:** `WaltUi.Projections.Contact.PhoneNumber`
**Storage:** embedded JSON array within `projection_contacts`

A phone number is a labeled phone entry for a contact. Contacts often have
multiple phone numbers (mobile, home, work) imported from phone contacts. Each
entry carries a label describing its purpose and the raw and normalized forms
of the number. Phone numbers with commercial area codes (800, 888, etc.) are
rejected during validation.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `label` | Label | string | yes | any (e.g., "mobile", "home", "work") | | | A human-readable category describing what this phone number is used for. |
| `phone` | Phone Number | string | yes | any non-commercial number | | | The phone number as provided. Validated to reject toll-free and premium-rate area codes (800, 833, 844, 855, 866, 877, 888, 900). |
| `standard_phone` | Normalized Phone | string | no | 10-digit US number | | | The phone number cleaned to a standard 10-digit format for matching and deduplication. |

---

### Email (embedded)

**Module:** `WaltUi.Projections.Contact.Email`
**Storage:** embedded JSON array within `projection_contacts`

An email is a labeled email address for a contact. Like phone numbers,
contacts often have multiple email addresses (personal, work) imported from
phone contacts or entered manually.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `label` | Label | string | yes | any (e.g., "work", "personal") | | | A human-readable category describing what this email address is used for. |
| `email` | Email Address | string | yes | valid email | | | The email address. |

---

### Contact Event

**Module:** `WaltUi.Contacts.ContactEvent`
**Table:** `contact_events`

A contact event is a timestamped record of something noteworthy that happened
involving a contact. Events include things like creation, invitation, email
correspondence, and note additions. They form an activity timeline that is
displayed on the contact detail screen so the user can see a chronological
history of interactions.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `event` | Event Description | string | yes | any | | | A human-readable description of what occurred (e.g., "Contact created", "Email sent"). |
| `type` | Event Type | string | yes | any | | | A category string that classifies the event for filtering and icon display on the timeline. |

**Associations:**

- `belongs_to :contact` -> Contact
- `belongs_to :note` -> Note (optional; present when the event was triggered by adding a note)

---

### Highlight

**Module:** `WaltUi.Contacts.Highlight`
**Table:** `contact_highlights`

A highlight is a join record that marks a contact as highlighted for a
specific user. Highlighted contacts receive special visual treatment in the
UI, drawing the user's attention to contacts that may need follow-up. This
entity has no data fields of its own -- its existence is the signal.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| (none) | | | | | | | This entity has no data fields. The relationship between user and contact is the data. |

**Associations:**

- `belongs_to :contact` -> Contact
- `belongs_to :user` -> User

---

### Note

**Module:** `WaltUi.Directory.Note`
**Table:** `notes`

A note is a free-text annotation that a user attaches to a contact. Notes
serve as the user's private CRM journal -- recording meeting summaries, client
preferences, property interests, or any other information the user wants to
remember about a contact.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `note` | Note Content | string | yes | any | | | The free-text body of the note. Supports plain text. |

**Associations:**

- `belongs_to :contact` -> Contact

---

### Feedback

**Module:** `WaltUi.Feedbacks.Feedback`
**Table:** `feedbacks`

A feedback record captures a user's qualitative assessment of a contact's
enrichment data. When users see enrichment results they consider inaccurate or
unhelpful, they can submit feedback. This data is used to evaluate enrichment
provider quality over time.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `comment` | Comment | string | no | any | | | An optional free-text explanation of what the user found wrong or unhelpful about the enrichment data. |

**Associations:**

- `belongs_to :contact` -> Contact

---

## Tags

### Tag

**Module:** `WaltUi.Tags.Tag`
**Table:** `tags`

A tag is a user-defined label that can be applied to one or more contacts for
categorization and filtering. Each user creates their own set of tags (e.g.,
"Buyer", "Seller", "Hot Lead", "Past Client"). Tags have a color for visual
distinction in the UI. The relationship between tags and contacts is
many-to-many, managed through the `contact_tags` join table.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `name` | Tag Name | string | yes | any | | | The display name of the tag. Should be short and descriptive. |
| `color` | Tag Color | string | yes | any (typically hex color) | | | The color used to render the tag pill in the UI. |

**Associations:**

- `belongs_to :user` -> User
- `many_to_many :contacts` -> Contact (through `contact_tags`)

---

### Contact Tag

**Module:** `WaltUi.ContactTags.ContactTag`
**Table:** `contact_tags`

A contact tag is the join record that associates a tag with a contact. It also
records which user created the association. This is a structural entity that
exists to support the many-to-many relationship between contacts and tags.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `contact_id` | Contact ID | binary_id | yes | valid UUID | | | Foreign key to the contact being tagged. |

**Associations:**

- `belongs_to :user` -> User
- `belongs_to :tag` -> Tag

---

## Tasks

### Task

**Module:** `WaltUi.Tasks.Task`
**Table:** `tasks`

A task is a to-do item that a user needs to complete, optionally linked to a
specific contact. Tasks can be created manually by the user or automatically
by the system (e.g., birthday reminders, follow-up prompts after a period of
inactivity). Each task has a priority level and optional due date and reminder
time. Tasks use soft deletion rather than hard deletion so that historical
task completion data is preserved for analytics.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `description` | Description | string | yes | any | | | A human-readable description of what needs to be done. |
| `is_complete` | Completed Flag | boolean | no | true, false | `false` | | Whether the user has marked this task as finished. |
| `is_deleted` | Deleted Flag | boolean | no | true, false | `false` | | Soft-delete flag. When true, the task is hidden from the UI but retained in the database. |
| `is_expired` | Expired Flag | boolean | no | true, false | `false` | | Whether the task has passed its due date without being completed. Set by a background job. |
| `due_at` | Due Date | naive_datetime | no | any valid datetime | | | The date and time by which the task should be completed. |
| `completed_at` | Completion Time | utc_datetime_usec | no | any valid datetime | | | The exact moment the user marked the task as complete. Null if not yet completed. |
| `remind_at` | Reminder Time | utc_datetime_usec | no | any valid datetime | | | The date and time at which a push notification should be sent to remind the user about this task. |
| `created_by` | Creator Type | enum | yes | `system`, `user` | | | Whether the task was created manually by the user or automatically by the system (e.g., birthday reminder, follow-up prompt). |
| `priority` | Priority Level | enum | no | `none`, `low`, `medium`, `high` | `none` | | The urgency level of the task. Affects sort order in the task list UI. |

**Associations:**

- `belongs_to :user` -> User
- `belongs_to :contact` -> Contact

---

## Unified Records and Providers

The unified record layer solves a key problem: when multiple Amby users have
the same person in their contacts, the system should only enrich that person
once. Unified contacts group per-user contact records by normalized phone
number. Each unified contact has at most one record from each enrichment
provider (Endato, Faraday, Gravatar, Jitter), storing the raw data returned
by that provider's API.

### Unified Contact

**Module:** `WaltUi.UnifiedRecords.Contact`
**Table:** `unified_contacts`

A unified contact is a phone-number-keyed record that groups all per-user
contacts who share the same phone number. It serves as the anchor point for
enrichment data -- rather than enriching each user's copy of a contact
separately, the system enriches the unified contact once and shares the
results. This avoids redundant API calls to enrichment providers and ensures
consistency.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `phone` | Canonical Phone Number | TenDigitPhone | yes | 10-digit US number | | | The normalized phone number that all linked contacts share. This is the deduplication key. |
| `faraday_mismatch` | Faraday Mismatch Flag | string | no | any | | | When set, indicates that the Faraday enrichment data does not match the contact's identity (e.g., the phone number resolved to a different person). Used to flag unreliable enrichment results. |

**Associations:**

- `has_one :endato` -> Providers.Endato
- `has_one :faraday` -> Providers.Faraday
- `has_one :gravatar` -> Providers.Gravatar
- `has_one :jitter` -> Providers.Jitter
- `has_many :contacts` -> Contact

---

### Provider: Endato

**Module:** `WaltUi.Providers.Endato`
**Table:** `provider_endato`

An Endato provider record stores the raw identity data returned by the Endato
people-search API for a unified contact. Endato is the primary source for
verifying a contact's real name, age, and current mailing address based on
their phone number. This data feeds into the merged enrichment projection.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `first_name` | First Name | string | no | any | | | The contact's given name as reported by Endato. |
| `last_name` | Last Name | string | no | any | | | The contact's family name as reported by Endato. |
| `middle_name` | Middle Name | string | no | any | | | The contact's middle name as reported by Endato. |
| `email` | Email Address | string | no | valid email | | | An email address associated with this phone number in Endato's records. |
| `phone` | Phone Number | TenDigitPhone | no | 10-digit US number | | | The phone number used to look up this record. |
| `age` | Age | integer | no | >= 0 | | years | The contact's age as reported by Endato. |
| `street_1` | Street Address Line 1 | string | no | any | | | The primary line of the contact's most recent known address. |
| `street_2` | Street Address Line 2 | string | no | any | | | The secondary address line. |
| `city` | City | string | no | any | | | The city of the contact's most recent known address. |
| `state` | State | string | no | any | | | The state of the contact's most recent known address. |
| `zip` | ZIP Code | string | no | any | | | The postal code of the contact's most recent known address. |

**Associations:**

- `belongs_to :unified_contact` -> UnifiedContact

---

### Provider: Faraday

**Module:** `WaltUi.Providers.Faraday`
**Table:** `provider_faraday`

A Faraday provider record stores the raw demographic, financial, property,
and behavioral data returned by the Faraday API for a unified contact.
Faraday (via its Trestle integration) is the richest data source in the
system, providing over 70 fields covering household composition, property
details, financial indicators, social media activity, and lifestyle
attributes. This data is the primary input to propensity-to-transact scoring.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `first_name` | First Name | string | no | any | | | The contact's given name as reported by Faraday. |
| `last_name` | Last Name | string | no | any | | | The contact's family name as reported by Faraday. |
| `email` | Email Address | string | no | valid email | | | An email address associated with this person in Faraday's records. |
| `phone` | Phone Number | string | no | any | | | The phone number used to look up this record. Stored as a plain string in this provider table. |
| `address` | Street Address | string | no | any | | | The full street address as a single string. |
| `city` | City | string | no | any | | | City portion of the address. |
| `state` | State | string | no | any | | | State portion of the address. |
| `postcode` | Postal Code | string | no | any | | | ZIP or postal code. Named `postcode` to match Faraday's API response format. |
| `age` | Age | integer | no | >= 0 | | years | Estimated age of the contact. |
| `date_of_birth` | Date of Birth | string | no | any | | | The contact's date of birth as a string. Format varies by provider. |
| `education` | Education Level | string | no | any | | | The highest level of education attained (e.g., "High School", "Bachelor's", "Graduate"). |
| `occupation` | Occupation | string | no | any | | | The contact's current or most recent occupation. |
| `marital_status` | Marital Status | string | no | any | | | Current marital status (e.g., "Single", "Married", "Divorced"). |
| `match_type` | Match Type | string | no | any | | | How Faraday matched the phone number to this person's record. Indicates match confidence. |
| `homeowner_status` | Homeowner Status | string | no | any | | | Whether the contact owns or rents their residence. |
| `property_type` | Property Type | string | no | any | | | The type of property at the contact's address (e.g., "Single Family", "Condo", "Townhouse"). |
| `zoning_type` | Zoning Type | string | no | any | | | The zoning classification of the contact's property (e.g., "Residential", "Commercial"). |
| `household_income` | Household Income | integer | no | >= 0 | | US dollars | Estimated annual household income. |
| `household_size` | Household Size | integer | no | >= 1 | | persons | The total number of people living in the household. |
| `number_of_adults` | Number of Adults | integer | no | >= 0 | | persons | The number of adults (18+) in the household. |
| `number_of_children` | Number of Children | integer | no | >= 0 | | persons | The number of children (under 18) in the household. |
| `number_of_bedrooms` | Number of Bedrooms | integer | no | >= 0 | | rooms | The number of bedrooms in the contact's home. |
| `number_of_bathrooms` | Number of Bathrooms | integer | no | >= 0 | | rooms | The number of bathrooms in the contact's home. |
| `credit_rating` | Credit Rating | integer | no | any | | score | An estimated credit score or rating for the contact. |
| `net_worth` | Net Worth | integer | no | any | | US dollars | Estimated net worth of the contact. |
| `mortgage_liability` | Mortgage Liability | integer | no | >= 0 | | US dollars | The outstanding balance on the contact's mortgage. |
| `home_equity_loan_amount` | Home Equity Loan Amount | integer | no | >= 0 | | US dollars | The amount of any home equity loan or line of credit. |
| `latest_mortgage_amount` | Latest Mortgage Amount | integer | no | >= 0 | | US dollars | The principal amount of the most recent mortgage. |
| `latest_mortgage_interest_rate` | Mortgage Interest Rate | float | no | 0.0 to 100.0 | | percent | The interest rate on the most recent mortgage. |
| `percent_equity` | Percent Equity | integer | no | 0 to 100 | | percent | The estimated percentage of the home's value that the contact owns outright. |
| `target_home_market_value` | Estimated Home Value | integer | no | >= 0 | | US dollars | The estimated current market value of the contact's home. |
| `building_value` | Building Value | integer | no | >= 0 | | US dollars | The assessed value of the building structure (excluding land). |
| `living_area` | Living Area | integer | no | >= 0 | | square feet | The total interior living space of the home. |
| `lot_area` | Lot Area | integer | no | >= 0 | | square feet | The total area of the property lot. |
| `lot_size_in_acres` | Lot Size | float | no | >= 0.0 | | acres | The property lot size expressed in acres. |
| `basement_area` | Basement Area | integer | no | >= 0 | | square feet | The total area of the basement, if present. |
| `garage_spaces` | Garage Spaces | integer | no | >= 0 | | spaces | The number of vehicles the garage can accommodate. |
| `year_built` | Year Built | integer | no | any valid year | | year | The year the home was originally constructed. |
| `vehicle_make` | Vehicle Make | string | no | any | | | The manufacturer of the contact's primary vehicle. |
| `vehicle_model` | Vehicle Model | string | no | any | | | The model name of the contact's primary vehicle. |
| `vehicle_year` | Vehicle Year | integer | no | any valid year | | year | The model year of the contact's primary vehicle. |
| `length_of_residence` | Length of Residence | integer | no | >= 0 | | years | How long the contact has lived at their current address. A key signal for propensity to move. |
| `average_commute_time` | Average Commute Time | integer | no | >= 0 | | minutes | The average one-way commute time to work. |
| `premover_rank` | Pre-Mover Rank | integer | no | any | | rank | A proprietary Faraday score indicating how likely the contact is to move in the near future. Lower values indicate higher likelihood. |
| `probability_to_have_hot_tub` | Hot Tub Probability | integer | no | 0 to 100 | | score | A modeled probability that the contact's property includes a hot tub. Used as a lifestyle indicator. |
| `propensity_percentile` | Propensity Percentile | float | no | 0.0 to 100.0 | | percentile | The contact's percentile ranking in Faraday's propensity-to-transact model. |
| `propensity_to_transact` | Propensity to Transact (Raw) | float | no | 0.0 to 1.0 | | probability | The raw probability score from Faraday's model indicating likelihood of a real estate transaction. |
| `latitude` | Latitude | float | no | -90.0 to 90.0 | | degrees | Geographic latitude of the contact's address. |
| `longitude` | Longitude | float | no | -180.0 to 180.0 | | degrees | Geographic longitude of the contact's address. |
| `affluency` | Affluency Flag | boolean | no | true, false | | | Whether the contact is classified as affluent based on income and asset indicators. |
| `has_basement` | Has Basement | boolean | no | true, false | | | Whether the contact's home has a basement. |
| `has_pool` | Has Pool | boolean | no | true, false | | | Whether the contact's property has a swimming pool. |
| `has_pet` | Has Pet | boolean | no | true, false | | | Whether the household has a pet. |
| `has_children_in_household` | Has Children | boolean | no | true, false | | | Whether there are children under 18 in the household. |
| `interest_in_grandchildren` | Interest in Grandchildren | boolean | no | true, false | | | Whether the contact has expressed or been modeled as having interest in grandchildren. A lifecycle indicator. |
| `is_active_on_social_media` | Active on Social Media | boolean | no | true, false | | | Whether the contact is active on any social media platform. |
| `is_facebook_user` | Facebook User | boolean | no | true, false | | | Whether the contact has a Facebook account. |
| `is_instagram_user` | Instagram User | boolean | no | true, false | | | Whether the contact has an Instagram account. |
| `is_twitter_user` | Twitter/X User | boolean | no | true, false | | | Whether the contact has a Twitter/X account. |
| `likes_travel` | Likes Travel | boolean | no | true, false | | | Whether the contact has been modeled as having an interest in travel. |
| `liquid_resources` | Liquid Resources | string | no | any | | | A categorical indicator of the contact's liquid assets (e.g., "Low", "Medium", "High"). |
| `wealth_resources` | Wealth Resources | string | no | any | | | A categorical indicator of the contact's total wealth. |
| `date_newly_married` | Date Newly Married | string | no | any | | | Approximate date the contact was recently married. A life event trigger for real estate activity. |
| `date_newly_single` | Date Newly Single | string | no | any | | | Approximate date the contact became single (divorce or separation). A life event trigger. |
| `date_empty_nester` | Date Became Empty Nester | string | no | any | | | Approximate date the last child left the household. Often triggers downsizing. |
| `date_of_income_change` | Date of Income Change | string | no | any | | | Approximate date of a significant income change. |
| `date_of_latest_mortgage` | Date of Latest Mortgage | string | no | any | | | The origination date of the most recent mortgage. |
| `date_of_first_childbirth` | Date of First Childbirth | string | no | any | | | Approximate date of the first child's birth. A life event trigger. |
| `date_of_home_equity_loan` | Date of Home Equity Loan | string | no | any | | | The origination date of a home equity loan. |
| `date_retired` | Date Retired | string | no | any | | | Approximate date the contact retired. A life event trigger. |

**Associations:**

- `belongs_to :unified_contact` -> UnifiedContact

---

### Provider: Gravatar

**Module:** `WaltUi.Providers.Gravatar`
**Table:** `provider_gravatar`

A Gravatar provider record stores the avatar URL retrieved from the Gravatar
service for a unified contact's email address. Gravatar provides globally
recognized avatars -- if a contact has a Gravatar profile, their photo is used
as the contact's avatar in the Amby UI.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `email` | Email Address | string | no | valid email | | | The email address used to query Gravatar's API. |
| `url` | Avatar URL | string | no | valid URL | | | The URL of the Gravatar image. Rendered as the contact's profile picture when no other avatar is available. |

**Associations:**

- `belongs_to :unified_contact` -> UnifiedContact

---

### Provider: Jitter

**Module:** `WaltUi.Providers.Jitter`
**Table:** `provider_jitter`

A Jitter provider record stores the AI-adjusted propensity-to-transact score
for a unified contact. Jitter is an internal AI model (powered by OpenAI /
Vertex AI) that takes the raw Faraday propensity score and adjusts it based on
additional signals like recent life events, market conditions, and agent
feedback. The result is a more accurate prediction of when a contact might
buy or sell a home.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `ptt` | Propensity to Transact | integer | no | 0 to 100 | | score | The AI-adjusted propensity-to-transact score. Higher values indicate higher likelihood of a near-term real estate transaction. This score is what users ultimately see on the contact detail screen. |

**Associations:**

- `belongs_to :unified_contact` -> UnifiedContact

---

## Projections (CQRS Read Models)

Projections are read-optimized views of data that are built by processing
event streams. Their IDs are assigned by the event-sourced aggregates (not
auto-generated by the database). When the system replays events, projections
are rebuilt from scratch. The Contact projection is documented above in the
Contacts section. The remaining projections are documented here.

### Enrichment

**Module:** `WaltUi.Projections.Enrichment`
**Table:** `projection_enrichments`
**Primary key:** externally assigned UUID (no autogenerate)

An enrichment projection is the merged, user-facing view of all provider data
for a single contact. When a contact is enriched, the system pulls data from
Endato, Faraday, Gravatar, and Jitter, then combines the best available value
for each field into this single record. This is the enrichment data that users
actually see on the contact detail screen. All fields are stored as strings
for display uniformity, regardless of the provider's native types.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `full_name` | Full Name | string | no | any | | | The contact's complete name, assembled from provider data. |
| `first_name` | First Name | string | no | any | | | Given name from enrichment providers. |
| `last_name` | Last Name | string | no | any | | | Family name from enrichment providers. |
| `date_of_birth` | Date of Birth | string | no | any | | | Date of birth as a display string. |
| `age` | Age | string | no | any | | | Age as a display string. |
| `education` | Education Level | string | no | any | | | Highest education level attained. |
| `occupation` | Occupation | string | no | any | | | Current or most recent occupation. |
| `marital_status` | Marital Status | string | no | any | | | Current marital status. |
| `date_newly_married` | Date Newly Married | string | no | any | | | Approximate date of recent marriage. |
| `date_newly_single` | Date Newly Single | string | no | any | | | Approximate date of becoming single. |
| `homeowner_status` | Homeowner Status | string | no | any | | | Whether the contact owns or rents. |
| `household_income` | Household Income | string | no | any | | | Estimated annual household income as a display string. |
| `income_change_date` | Income Change Date | string | no | any | | | Date of a significant income change. |
| `liquid_resources` | Liquid Resources | string | no | any | | | Categorical liquid asset indicator. |
| `net_worth` | Net Worth | string | no | any | | | Estimated net worth as a display string. |
| `affluency` | Affluency | string | no | any | | | Affluency classification as a display string. |
| `mortgage_liability` | Mortgage Liability | string | no | any | | | Outstanding mortgage balance as a display string. |
| `home_equity_loan_date` | Home Equity Loan Date | string | no | any | | | Date of home equity loan origination. |
| `home_equity_loan_amount` | Home Equity Loan Amount | string | no | any | | | Home equity loan amount as a display string. |
| `latest_mortgage_amount` | Latest Mortgage Amount | string | no | any | | | Most recent mortgage principal as a display string. |
| `latest_mortgage_date` | Latest Mortgage Date | string | no | any | | | Origination date of the most recent mortgage. |
| `latest_mortgage_interest_rate` | Mortgage Interest Rate | string | no | any | | | Mortgage interest rate as a display string. |
| `percent_equity` | Percent Equity | string | no | any | | | Home equity percentage as a display string. |
| `target_home_market_value` | Estimated Home Value | string | no | any | | | Estimated market value of the home as a display string. |
| `property_type` | Property Type | string | no | any | | | Type of property (e.g., "Single Family"). |
| `zoning_type` | Zoning Type | string | no | any | | | Property zoning classification. |
| `number_of_bedrooms` | Number of Bedrooms | string | no | any | | | Bedroom count as a display string. |
| `number_of_bathrooms` | Number of Bathrooms | string | no | any | | | Bathroom count as a display string. |
| `year_built` | Year Built | string | no | any | | | Construction year as a display string. |
| `lot_size_in_acres` | Lot Size | string | no | any | | | Lot size in acres as a display string. |
| `living_area` | Living Area | string | no | any | | | Interior living area as a display string. |
| `lot_area` | Lot Area | string | no | any | | | Total lot area as a display string. |
| `basement_area` | Basement Area | string | no | any | | | Basement area as a display string. |
| `garage_spaces` | Garage Spaces | string | no | any | | | Number of garage spaces as a display string. |
| `has_basement` | Has Basement | boolean | no | true, false | | | Whether the home has a basement. |
| `has_pool` | Has Pool | boolean | no | true, false | | | Whether the property has a pool. |
| `length_of_residence` | Length of Residence | string | no | any | | | How long the contact has lived at their current address. |
| `average_commute_time` | Average Commute Time | string | no | any | | | Average commute time as a display string. |
| `probability_to_have_hot_tub` | Hot Tub Probability | string | no | any | | | Modeled hot tub probability as a display string. |
| `vehicle_make` | Vehicle Make | string | no | any | | | Primary vehicle manufacturer. |
| `vehicle_model` | Vehicle Model | string | no | any | | | Primary vehicle model. |
| `vehicle_year` | Vehicle Year | string | no | any | | | Primary vehicle model year. |
| `is_twitter_user` | Twitter/X User | boolean | no | true, false | | | Whether the contact has a Twitter/X account. |
| `is_facebook_user` | Facebook User | boolean | no | true, false | | | Whether the contact has a Facebook account. |
| `is_instagram_user` | Instagram User | boolean | no | true, false | | | Whether the contact has an Instagram account. |
| `is_active_on_social_media` | Active on Social Media | boolean | no | true, false | | | Whether the contact is active on social media. |
| `likes_travel` | Likes Travel | boolean | no | true, false | | | Whether the contact has an interest in travel. |
| `has_children_in_household` | Has Children | boolean | no | true, false | | | Whether there are children in the household. |
| `number_of_children` | Number of Children | string | no | any | | | Child count as a display string. |
| `first_child_birthdate` | First Child Birthdate | string | no | any | | | Date of the first child's birth. |
| `has_pet` | Has Pet | boolean | no | true, false | | | Whether the household has a pet. |
| `interest_in_grandchildren` | Interest in Grandchildren | string | no | any | | | Grandchildren interest indicator as a display string. |
| `date_empty_nester` | Date Became Empty Nester | string | no | any | | | Approximate date the last child left. |
| `date_retired` | Date Retired | string | no | any | | | Approximate retirement date. |

---

### Endato Projection

**Module:** `WaltUi.Projections.Endato`
**Table:** `projection_enrichments_endato`
**Primary key:** externally assigned UUID (no autogenerate)

The Endato projection is the read-model form of the raw Endato provider data.
It is built from events when a contact's Endato enrichment completes. It adds
quality metadata that tracks how well the Endato results matched the original
contact data, and stores multiple associated addresses rather than just the
primary one.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `first_name` | First Name | string | no | any | | | Given name from Endato. |
| `last_name` | Last Name | string | no | any | | | Family name from Endato. |
| `phone` | Phone Number | TenDigitPhone | yes | 10-digit US number | | | The normalized phone number that was used for the Endato lookup. |
| `emails` | Email Addresses | array of string | no | valid emails | `[]` | | All email addresses Endato associates with this phone number. |
| `quality_metadata` | Quality Metadata | map | no | any JSON | | | Match confidence and quality indicators from Endato, used to assess how reliable the returned data is. |

**Embedded collections:**

- `addresses` -> list of Address (all addresses Endato associates with this person)

---

### Endato Address (embedded)

**Module:** `WaltUi.Projections.Endato.Address`
**Storage:** embedded JSON array within `projection_enrichments_endato`

An Endato address is one of potentially many addresses that Endato associates
with a phone number. The collection typically includes current and previous
addresses, allowing the system to track address history and identify possible
current locations.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `street_1` | Street Address Line 1 | string | yes | any | | | Primary address line. |
| `street_2` | Street Address Line 2 | string | no | any | | | Secondary address line (apt, suite, unit). |
| `city` | City | string | yes | any | | | City name. |
| `state` | State | string | yes | any | | | State abbreviation. |
| `zip` | ZIP Code | string | yes | any | | | Postal code. |

---

### Faraday Projection

**Module:** `WaltUi.Projections.Faraday`
**Table:** `projection_enrichments_faraday`
**Primary key:** externally assigned UUID (no autogenerate)

The Faraday projection is the read-model form of the raw Faraday provider
data. It contains all the same fields as `Providers.Faraday` (see the
Provider: Faraday section above for full field definitions), plus the
following additional field:

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `quality_metadata` | Quality Metadata | map | no | any JSON | | | Match confidence and quality indicators used to assess how reliably Faraday matched the phone number to the correct person. |

---

### Trestle Projection

**Module:** `WaltUi.Projections.Trestle`
**Table:** `projection_enrichments_trestle`
**Primary key:** externally assigned UUID (no autogenerate)

The Trestle projection stores identity and address data from the Trestle data
provider. Trestle provides an alternative identity verification source to
Endato, including alternate names the contact may be known by and an
approximate age range rather than an exact age.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `first_name` | First Name | string | no | any | | | Given name from Trestle. |
| `last_name` | Last Name | string | no | any | | | Family name from Trestle. |
| `age_range` | Age Range | string | no | any | | | An approximate age range (e.g., "30-35") rather than an exact age. |
| `phone` | Phone Number | TenDigitPhone | yes | 10-digit US number | | | The normalized phone number used for the Trestle lookup. |
| `emails` | Email Addresses | array of string | no | valid emails | `[]` | | All email addresses Trestle associates with this phone number. |
| `alternate_names` | Alternate Names | array of string | no | any | `[]` | | Other names this person may be known by (maiden names, nicknames, etc.). |
| `quality_metadata` | Quality Metadata | map | no | any JSON | | | Match confidence and quality indicators from Trestle. |

**Embedded collections:**

- `addresses` -> list of Address (all addresses Trestle associates with this person)

---

### Trestle Address (embedded)

**Module:** `WaltUi.Projections.Trestle.Address`
**Storage:** embedded JSON array within `projection_enrichments_trestle`

A Trestle address follows the same structure as an Endato address. See the
Endato Address section above for field definitions.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `street_1` | Street Address Line 1 | string | yes | any | | | Primary address line. |
| `street_2` | Street Address Line 2 | string | no | any | | | Secondary address line. |
| `city` | City | string | yes | any | | | City name. |
| `state` | State | string | yes | any | | | State abbreviation. |
| `zip` | ZIP Code | string | yes | any | | | Postal code. |

---

### Gravatar Projection

**Module:** `WaltUi.Projections.Gravatar`
**Table:** `projection_enrichments_gravatar`
**Primary key:** externally assigned UUID (no autogenerate)

The Gravatar projection is the read-model form of the Gravatar provider data.
It stores the email-to-avatar mapping in a format optimized for querying by
the contact detail screen.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `email` | Email Address | string | yes | valid email | | | The email address used to query Gravatar. |
| `url` | Avatar URL | string | yes | valid URL | | | The URL of the Gravatar profile image. |

---

### Jitter Projection

**Module:** `WaltUi.Projections.Jitter`
**Table:** `projection_jitters`
**Primary key:** externally assigned UUID (no autogenerate)

The Jitter projection is the read-model form of the AI-adjusted
propensity-to-transact score. It is the final, user-facing score that appears
on the contact detail screen.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `ptt` | Propensity to Transact | integer | yes | 0 to 100 | | score | The AI-adjusted propensity-to-transact score. This is the final score shown to users, after the Jitter AI model has refined the raw Faraday score. |

---

### Possible Address

**Module:** `WaltUi.Projections.PossibleAddress`
**Table:** `projection_possible_addresses`
**Primary key:** externally assigned UUID (no autogenerate)

A possible address is a candidate mailing address for a contact, derived from
enrichment data. When multiple enrichment providers return different addresses,
the system stores each as a possible address linked to the enrichment record.
Users can review these and select the correct one.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `enrichment_id` | Enrichment ID | binary_id | yes | valid UUID | | | Foreign key to the enrichment projection this address was derived from. |
| `street_1` | Street Address Line 1 | string | yes | any | | | Primary address line. |
| `street_2` | Street Address Line 2 | string | no | any | | | Secondary address line. |
| `city` | City | string | yes | any | | | City name. |
| `state` | State | string | yes | any | | | State abbreviation. |
| `zip` | ZIP Code | string | yes | any | | | Postal code. |

---

### PTT Score

**Module:** `WaltUi.Projections.PttScore`
**Table:** `projection_ptt_scores`

A PTT score record is a point-in-time snapshot of a contact's
propensity-to-transact score. The system stores a new record each time the
score changes, creating a historical time series. This enables the UI to show
score trends over time and helps the team evaluate whether the scoring models
are improving.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `contact_id` | Contact ID | binary_id | yes | valid UUID | | | Foreign key to the contact whose score was recorded. |
| `occurred_at` | Occurred At | naive_datetime | yes | any valid datetime | | | The point in time when this score was calculated. |
| `score` | Score | integer | yes | 0 to 100 | | score | The propensity-to-transact score at this point in time. |
| `score_type` | Score Source | enum | yes | `jitter`, `ptt` | | | Which scoring system produced this value. `ptt` is the raw Faraday score; `jitter` is the AI-adjusted score. |

---

### Contact Creation

**Module:** `WaltUi.Projections.ContactCreation`
**Table:** `projection_contact_creations`

A contact creation record tracks each time a user adds or removes a contact
from their account. These records are used for analytics -- specifically, to
chart contact growth over time and identify usage trends. Each record
represents a single create or delete event on a specific date.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `date` | Event Date | date | yes | any valid date | | | The date the contact was created or deleted. |
| `type` | Event Type | enum | yes | `create`, `delete` | | | Whether this record represents a contact being added or removed. |
| `user_id` | User ID | binary_id | yes | valid UUID | | | The user who created or deleted the contact. |

---

### Contact Interaction

**Module:** `WaltUi.Projections.ContactInteraction`
**Table:** `projection_contact_interactions`

A contact interaction records a meaningful touchpoint between a user and a
contact. These are higher-level than contact events -- they represent
significant interactions like creating a contact, sending an invitation, or
having email correspondence. They are used to calculate engagement metrics
and surface contacts who may need attention.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `activity_type` | Activity Type | enum | yes | `contact_created`, `contact_invited`, `contact_corresponded` | | | The category of interaction that occurred. |
| `contact_id` | Contact ID | binary_id | yes | valid UUID | | | The contact involved in this interaction. |
| `metadata` | Interaction Metadata | map | no | any JSON | | | Additional context about the interaction (e.g., email subject line, invitation method). |
| `occurred_at` | Occurred At | naive_datetime | yes | any valid datetime | | | When the interaction took place. |

---

### Contact Showcase

**Module:** `WaltUi.Projections.ContactShowcase`
**Table:** `projection_contact_showcases`

A contact showcase record marks a contact as being featured in the showcase
view. The showcase highlights contacts with the best enrichment data quality,
giving users a curated view of their most data-rich contacts. Contacts are
classified as "best" (highest enrichment quality) or "lesser" (good but not
top-tier).

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `contact_id` | Contact ID | binary_id | yes | valid UUID | | | The contact being showcased. |
| `enrichment_type` | Enrichment Quality Tier | enum | yes | `best`, `lesser` | | | Whether this contact has the best available enrichment data or a lesser but still notable quality. |
| `user_id` | User ID | binary_id | yes | valid UUID | | | The user whose showcase this contact appears in. |

---

## Subscriptions and Billing

### Subscription

**Module:** `WaltUi.Subscriptions.Subscription`
**Table:** `subscriptions`

A subscription represents a user's paid plan. Amby supports purchases through
three payment providers: Apple (for iOS in-app purchases), Google (for
Android), and Stripe (for web). Each user has at most one active subscription.
The subscription controls access to premium features like enrichment and
AI-adjusted scoring. When a subscription expires, the user reverts to the
freemium tier.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `store` | Payment Provider | enum | yes | `apple`, `google`, `stripe` | | | Which app store or payment processor handles billing for this subscription. |
| `store_customer_id` | Provider Customer ID | string | no | any | | | The unique customer identifier within the payment provider's system (e.g., Stripe customer ID). |
| `store_subscription_id` | Provider Subscription ID | string | no | any | | | The unique subscription identifier within the payment provider's system. Used to look up subscription status. |
| `expires_on` | Expiration Date | date | no | any valid date | | | The date the current billing period ends. The system checks this to determine if the user still has premium access. |
| `type` | Billing Interval | enum | no | `monthly`, `yearly` | `monthly` | | How often the subscription renews. Yearly subscriptions are offered at a discount. |

**Associations:**

- `belongs_to :user` -> User

---

## Calendars

### Calendar

**Module:** `WaltUi.Calendars.Calendar`
**Table:** `calendars`

A calendar represents a synced calendar from an external provider (currently
only Google Calendar). When a user connects their Google account, the system
discovers their calendars and creates a record for each one. Calendar data is
used to populate the agenda view, show upcoming meetings on contact detail
screens, and enable scheduling features.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `name` | Calendar Name | string | yes | any | | | The display name of the calendar (e.g., "Work", "Personal"). Synced from Google Calendar. |
| `color` | Display Color | string | no | any (typically hex) | | | The color used to render events from this calendar in the Amby UI. Synced from Google Calendar. |
| `source` | Source Provider | enum | yes | `google` | | | Which calendar service this calendar was imported from. Currently only Google is supported. |
| `source_id` | Provider Calendar ID | string | yes | any | | | The unique identifier for this calendar within Google Calendar's system. Used for API sync operations. |
| `timezone` | Timezone | string | no | IANA timezone ID | | | The default timezone for events on this calendar (e.g., "America/New_York"). |

**Associations:**

- `belongs_to :user` -> User

---

## Notifications

### FCM Token

**Module:** `WaltUi.Notifications.FcmToken`
**Table:** `fcm_tokens`

An FCM token is a Firebase Cloud Messaging device token that identifies a
specific mobile device for push notifications. When a user installs the Amby
mobile app and grants notification permissions, the app registers its FCM
token with the server. The system uses these tokens to deliver push
notifications for task reminders, new enrichment results, and other
time-sensitive alerts. A user may have multiple tokens (one per device).

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `token` | Device Token | string | yes | any (unique) | | | The Firebase Cloud Messaging token that uniquely identifies a device for push notification delivery. Tokens are rotated periodically by Firebase and must be updated when they change. |

**Associations:**

- `belongs_to :user` -> User

---

## Conversations (AI Chat)

### Conversation

**Module:** `WaltUi.Conversations.Conversation`
**Table:** `conversations`

A conversation is an AI chat session between a user and the Amby assistant.
Users can ask the AI questions about their contacts, get suggestions for
follow-up actions, or generate text messages. Each conversation tracks its
cumulative token usage for cost monitoring.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `title` | Conversation Title | string | yes | any (max 255 characters) | | | A short title summarizing the conversation topic. May be auto-generated from the first message. |
| `user_id` | User ID | binary_id | yes | valid UUID | | | The user who initiated the conversation. |
| `total_input_tokens` | Total Input Tokens | integer | no | >= 0 | `0` | tokens | The cumulative number of input tokens consumed across all messages in this conversation. Used for cost tracking. |
| `total_output_tokens` | Total Output Tokens | integer | no | >= 0 | `0` | tokens | The cumulative number of output tokens generated across all messages in this conversation. Used for cost tracking. |

**Associations:**

- `has_many :messages` -> ConversationMessage

---

### Conversation Message

**Module:** `WaltUi.Conversations.ConversationMessage`
**Table:** `conversation_messages`
**Timestamps:** `inserted_at` only (no `updated_at` -- messages are immutable)

A conversation message is a single turn in an AI chat conversation. Each
message is either from the user (a question or instruction) or from the AI
model (a response). Messages are append-only and never edited after creation.

| Variable | Human-Readable Name | Type | Required | Allowed Values | Default | Units | Definition |
|:---------|:-------------------|:-----|:--------:|:---------------|:-------:|:------|:-----------|
| `role` | Sender Role | enum | yes | `user`, `model` | | | Who produced this message. `user` is a human-authored message; `model` is an AI-generated response. |
| `content` | Message Content | string | yes | any | | | The full text of the message. |
| `input_tokens` | Input Tokens | integer | no | >= 0 | | tokens | The number of input tokens consumed when generating the AI response for this turn. Null for user messages. |
| `output_tokens` | Output Tokens | integer | no | >= 0 | | tokens | The number of output tokens generated for this turn. Null for user messages. |

**Associations:**

- `belongs_to :conversation` -> Conversation

---

## Entity Relationship Overview

```
User
 ├── has_many Contacts (projection_contacts)
 │    ├── has_many ContactEvents
 │    ├── has_many Notes
 │    ├── many_to_many Tags (via contact_tags)
 │    ├── has_many Tasks
 │    ├── has_many Feedbacks
 │    ├── has_many Highlights
 │    └── belongs_to UnifiedContact
 │         ├── has_one Providers.Endato
 │         ├── has_one Providers.Faraday
 │         ├── has_one Providers.Gravatar
 │         └── has_one Providers.Jitter
 ├── has_many Calendars
 ├── has_many ExternalAccounts
 ├── has_many FcmTokens
 ├── has_many Tags
 ├── has_one Subscription
 └── has_many Sessions
```

---

## Glossary

| Term | Definition |
|:-----|:-----------|
| Aggregate | In CQRS/Event Sourcing, the domain object that handles commands and produces events. In Amby, the `LeadAggregate` manages contact commands. |
| Enrichment | The process of augmenting a contact's basic information (name, phone) with demographic, financial, property, and behavioral data from external providers. |
| Projection | A read-optimized database record built by processing a stream of events. Projections are eventually consistent with the event store. |
| Provider | An external data service (Endato, Faraday, Gravatar) that supplies enrichment data. Provider records store the raw API response. |
| Propensity to Transact (PTT) | A score from 0 to 100 predicting how likely a contact is to buy or sell a home in the near future. Derived from Faraday data and refined by the Jitter AI model. |
| Unified Contact | A phone-number-keyed record that deduplicates contacts across users. Enrichment data is attached to the unified contact and shared with all users who have that phone number in their contacts. |
| TenDigitPhone | A custom Ecto type that normalizes US phone numbers to exactly 10 digits with no formatting. |
