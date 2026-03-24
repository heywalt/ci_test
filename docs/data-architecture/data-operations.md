# Amby Data Operations

This document catalogs every operation the application exposes, organized by
the entity each operation primarily acts on. For each operation, we document
the route, HTTP method, what the operation does in plain English, and which
secondary entities are read or written as side effects.

## Conventions

- **Primary entity** is the entity the caller intends to act on.
- **Secondary entities** are other entities that the system reads or writes as
  a consequence of the operation. These are listed as `reads` or `writes`.
- Routes prefixed with `/api` are JSON API endpoints authenticated via JWT.
- Routes prefixed with `/auth` are browser-based OAuth flows.
- Routes with no prefix are browser-based LiveView pages or actions.
- All `/api` routes (except Apple Sign-In) require authentication via the
  `api_authenticated` pipeline.

---

## Contact

The contact is the central entity in Amby. Most API operations revolve around
creating, reading, updating, and enriching contacts.

### List contacts

| | |
|:--|:--|
| **Route** | `GET /api/contacts` |
| **Description** | Returns a paginated list of the authenticated user's contacts. Supports filtering by hidden status and returning all contacts unpaginated when `page=all`. Preloads tags, notes, and enrichment data. |
| **Primary entity** | Contact |
| **Secondary reads** | Tag, Note, Enrichment, UnifiedContact |
| **Secondary writes** | (none) |

### List top contacts

| | |
|:--|:--|
| **Route** | `GET /api/contacts/top-contacts` |
| **Description** | Returns the user's contacts ranked by propensity to transact (PTT score), highlighting the contacts most likely to buy or sell in the near future. |
| **Primary entity** | Contact |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Get contact

| | |
|:--|:--|
| **Route** | `GET /api/contacts/:id` |
| **Description** | Returns a single contact with all associated data preloaded, including tags, notes, enrichment details, and unified contact data. |
| **Primary entity** | Contact |
| **Secondary reads** | Tag, Note, Enrichment, UnifiedContact |
| **Secondary writes** | (none) |

### Get contact PTT history

| | |
|:--|:--|
| **Route** | `GET /api/contacts/:id/ptt` |
| **Description** | Returns the historical time series of propensity-to-transact scores for a contact, showing how the score has changed over time. |
| **Primary entity** | Contact |
| **Secondary reads** | PttScore |
| **Secondary writes** | (none) |

### Create contact

| | |
|:--|:--|
| **Route** | `POST /api/contacts` |
| **Description** | Creates a new contact for the authenticated user. Dispatches a CQRS command to the LeadAggregate, which produces events that build the contact projection and trigger enrichment workflows. |
| **Primary entity** | Contact |
| **Secondary reads** | (none) |
| **Secondary writes** | UnifiedContact (find or create), ContactCreation (projection), ContactEvent |

### Bulk create contacts

| | |
|:--|:--|
| **Route** | `POST /api/bulk/contacts` |
| **Description** | Accepts a batch of contacts and dispatches creation events asynchronously. Returns 202 Accepted immediately. Used for phone contact imports and CSV uploads. |
| **Primary entity** | Contact |
| **Secondary reads** | (none) |
| **Secondary writes** | UnifiedContact, ContactCreation, ContactEvent (all created asynchronously) |

### Bulk upsert contacts

| | |
|:--|:--|
| **Route** | `PUT /api/bulk/contacts` |
| **Description** | Accepts a batch of contacts and creates or updates each one based on whether a matching contact already exists. Returns 202 Accepted immediately. Used for syncing phone contacts where some may already exist. |
| **Primary entity** | Contact |
| **Secondary reads** | (none) |
| **Secondary writes** | UnifiedContact, ContactCreation, ContactEvent (all created asynchronously) |

### Update contact

| | |
|:--|:--|
| **Route** | `PUT /api/contacts/:id` |
| **Description** | Updates a contact's attributes (name, phone, email, address, birthday, etc.). Dispatches a CQRS command that produces update events, which rebuild the contact projection. |
| **Primary entity** | Contact |
| **Secondary reads** | (none) |
| **Secondary writes** | ContactEvent |

### Delete contact

| | |
|:--|:--|
| **Route** | `DELETE /api/contacts/:id` |
| **Description** | Deletes a contact and its associated data. Dispatches a CQRS command that produces a deletion event. The contact projection is removed and a ContactCreation record with type `delete` is written for analytics. |
| **Primary entity** | Contact |
| **Secondary reads** | (none) |
| **Secondary writes** | ContactCreation (type: delete), ContactEvent |

---

## Contact Address

Addresses are managed separately from the main contact update flow because
enrichment may produce multiple candidate addresses that the user needs to
choose between.

### List possible addresses

| | |
|:--|:--|
| **Route** | `GET /api/contacts/:contact_id/addresses` |
| **Description** | Returns all candidate addresses for a contact, sourced from enrichment providers (Endato, Faraday, Trestle). The user can review these and select the correct one. |
| **Primary entity** | PossibleAddress |
| **Secondary reads** | Contact, Enrichment |
| **Secondary writes** | (none) |

### Select an address

| | |
|:--|:--|
| **Route** | `PUT /api/contacts/:contact_id/addresses` |
| **Description** | Selects one of the enrichment-provided addresses as the contact's current address. Dispatches a CQRS `select_address` command that updates the contact projection with the chosen address. |
| **Primary entity** | Contact |
| **Secondary reads** | PossibleAddress |
| **Secondary writes** | ContactEvent |

### Set a custom address

| | |
|:--|:--|
| **Route** | `POST /api/contacts/:contact_id/addresses` |
| **Description** | Sets a manually-entered address as the contact's current address, bypassing the enrichment-provided candidates. Dispatches a CQRS `select_address` command. |
| **Primary entity** | Contact |
| **Secondary reads** | (none) |
| **Secondary writes** | ContactEvent |

---

## Contact Event

Contact events form the activity timeline shown on the contact detail screen.

### List contact events

| | |
|:--|:--|
| **Route** | `GET /api/contacts/:contact_id/events` |
| **Description** | Returns the chronological list of events for a contact (creation, emails sent, notes added, etc.). |
| **Primary entity** | ContactEvent |
| **Secondary reads** | Contact |
| **Secondary writes** | (none) |

### Create contact event

| | |
|:--|:--|
| **Route** | `POST /api/contacts/:contact_id/events` |
| **Description** | Manually creates an event entry on a contact's timeline. If note parameters are included, a Note is also created and linked to the event. |
| **Primary entity** | ContactEvent |
| **Secondary reads** | Contact |
| **Secondary writes** | Note (if note params provided) |

---

## Contact Interaction

Contact interactions are higher-level engagement records used for analytics.

### List contact interactions

| | |
|:--|:--|
| **Route** | `GET /api/contact-interactions/:contact_id` |
| **Description** | Returns the interaction history for a contact, including creation, invitation, and correspondence events. Used to calculate engagement metrics. |
| **Primary entity** | ContactInteraction |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

---

## Note

Notes are free-text annotations attached to contacts. They have both
contact-scoped and user-scoped endpoints.

### List all user notes

| | |
|:--|:--|
| **Route** | `GET /api/notes` |
| **Description** | Returns all notes across all of the authenticated user's contacts, ordered by recency. |
| **Primary entity** | Note |
| **Secondary reads** | Contact |
| **Secondary writes** | (none) |

### Get note

| | |
|:--|:--|
| **Route** | `GET /api/notes/:id` |
| **Description** | Returns a single note by ID. |
| **Primary entity** | Note |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Update note

| | |
|:--|:--|
| **Route** | `PUT /api/notes/:id` |
| **Description** | Updates the text content of an existing note. |
| **Primary entity** | Note |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### List contact notes

| | |
|:--|:--|
| **Route** | `GET /api/contacts/:contact_id/notes` |
| **Description** | Returns all notes for a specific contact. |
| **Primary entity** | Note |
| **Secondary reads** | Contact |
| **Secondary writes** | (none) |

### Create contact note

| | |
|:--|:--|
| **Route** | `POST /api/contacts/:contact_id/notes` |
| **Description** | Creates a new note attached to a contact. |
| **Primary entity** | Note |
| **Secondary reads** | Contact |
| **Secondary writes** | (none) |

---

## Feedback

Feedback records capture user assessments of enrichment data quality.

### Create feedback

| | |
|:--|:--|
| **Route** | `POST /api/contacts/:id/feedback` |
| **Description** | Submits feedback about the quality or accuracy of a contact's enrichment data. Used to evaluate enrichment provider performance over time. |
| **Primary entity** | Feedback |
| **Secondary reads** | Contact |
| **Secondary writes** | (none) |

---

## Tag

Tags are user-defined labels for categorizing contacts.

### List tags

| | |
|:--|:--|
| **Route** | `GET /api/tags` |
| **Description** | Returns all tags owned by the authenticated user. |
| **Primary entity** | Tag |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Get tag

| | |
|:--|:--|
| **Route** | `GET /api/tags/:id` |
| **Description** | Returns a single tag by ID. |
| **Primary entity** | Tag |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Create tag

| | |
|:--|:--|
| **Route** | `POST /api/tags` |
| **Description** | Creates a new tag with a name and color for the authenticated user. |
| **Primary entity** | Tag |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Update tag

| | |
|:--|:--|
| **Route** | `PUT /api/tags/:id` |
| **Description** | Updates a tag's name or color. Changes are reflected on all contacts that use this tag. |
| **Primary entity** | Tag |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Delete tag

| | |
|:--|:--|
| **Route** | `DELETE /api/tags/:id` |
| **Description** | Deletes a tag and removes it from all contacts it was applied to. |
| **Primary entity** | Tag |
| **Secondary reads** | (none) |
| **Secondary writes** | ContactTag (deleted via cascade) |

---

## Contact Tag

Contact tags manage the many-to-many relationship between contacts and tags.

### Apply tag to contact

| | |
|:--|:--|
| **Route** | `POST /api/contacts/:contact_id/tags` |
| **Description** | Associates an existing tag with a contact. |
| **Primary entity** | ContactTag |
| **Secondary reads** | Contact, Tag |
| **Secondary writes** | (none) |

### Remove tag from contact

| | |
|:--|:--|
| **Route** | `DELETE /api/contacts/:contact_id/tags/:tag_id` |
| **Description** | Removes the association between a tag and a contact. The tag itself is not deleted. |
| **Primary entity** | ContactTag |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

---

## Task

Tasks are to-do items, optionally linked to contacts.

### List tasks

| | |
|:--|:--|
| **Route** | `GET /api/tasks` |
| **Description** | Returns all tasks for the authenticated user, including system-generated and user-created tasks. |
| **Primary entity** | Task |
| **Secondary reads** | Contact (if linked) |
| **Secondary writes** | (none) |

### Create task

| | |
|:--|:--|
| **Route** | `POST /api/tasks` |
| **Description** | Creates a new task with a description, optional due date, priority, reminder time, and optional contact association. Sets `created_by` to `user`. |
| **Primary entity** | Task |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Update task

| | |
|:--|:--|
| **Route** | `PUT /api/tasks/:id` |
| **Description** | Updates a task's description, due date, priority, or reminder time. |
| **Primary entity** | Task |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Complete task

| | |
|:--|:--|
| **Route** | `PUT /api/tasks/:id/complete` |
| **Description** | Marks a task as completed and records the completion timestamp. |
| **Primary entity** | Task |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Uncomplete task

| | |
|:--|:--|
| **Route** | `PUT /api/tasks/:id/uncomplete` |
| **Description** | Reopens a previously completed task by clearing the completion flag and timestamp. |
| **Primary entity** | Task |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Delete task

| | |
|:--|:--|
| **Route** | `DELETE /api/tasks/:id` |
| **Description** | Deletes a task. |
| **Primary entity** | Task |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

---

## User

User operations manage the authenticated user's own account.

### Get current user

| | |
|:--|:--|
| **Route** | `GET /api/user` |
| **Description** | Returns the authenticated user's profile, including name, email, tier, type, and subscription status. |
| **Primary entity** | User |
| **Secondary reads** | Subscription |
| **Secondary writes** | (none) |

### Update current user

| | |
|:--|:--|
| **Route** | `PUT /api/user` |
| **Description** | Updates the authenticated user's profile fields (name, bio, company, avatar, phone, type). |
| **Primary entity** | User |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Delete current user

| | |
|:--|:--|
| **Route** | `DELETE /api/user` |
| **Description** | Permanently deletes the authenticated user's account and all associated data (contacts, tags, tasks, external accounts, etc.). This is irreversible. |
| **Primary entity** | User |
| **Secondary reads** | (none) |
| **Secondary writes** | Contact, Tag, Task, ExternalAccount, Subscription, FcmToken, Session (all deleted via cascade) |

---

## FCM Token

FCM tokens register mobile devices for push notifications.

### Register device

| | |
|:--|:--|
| **Route** | `POST /api/user/fcm-tokens` |
| **Description** | Registers a mobile device's Firebase Cloud Messaging token so the system can send push notifications to it. |
| **Primary entity** | FcmToken |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Update device token

| | |
|:--|:--|
| **Route** | `PUT /api/user/fcm-tokens/:id` |
| **Description** | Updates a device's FCM token. Firebase periodically rotates tokens, requiring the app to report the new value. |
| **Primary entity** | FcmToken |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Unregister device

| | |
|:--|:--|
| **Route** | `DELETE /api/user/fcm-tokens/:id` |
| **Description** | Removes a device's FCM token, stopping push notifications to that device. |
| **Primary entity** | FcmToken |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

---

## External Account

External accounts manage OAuth connections to third-party services.

### List external accounts

| | |
|:--|:--|
| **Route** | `GET /api/external-accounts` |
| **Description** | Returns all external service connections (Google, SkySlope) for the authenticated user. |
| **Primary entity** | ExternalAccount |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Connect external account (mobile)

| | |
|:--|:--|
| **Route** | `POST /api/external-accounts` |
| **Description** | Creates an external account connection from a mobile app's OAuth flow. Accepts the access token, refresh token, and provider details. |
| **Primary entity** | ExternalAccount |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Disconnect external account

| | |
|:--|:--|
| **Route** | `DELETE /api/external-accounts/:id` |
| **Description** | Removes an external service connection, stopping all sync activity (email, calendar) for that account. |
| **Primary entity** | ExternalAccount |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Connect external account (web)

| | |
|:--|:--|
| **Route** | `GET /auth/:provider` |
| **Description** | Initiates the OAuth flow for connecting an external account from the web UI. Redirects the user to the provider's authorization page. Supported providers: `google`, `skyslope`. |
| **Primary entity** | ExternalAccount |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### External account OAuth callback

| | |
|:--|:--|
| **Route** | `GET /auth/:provider/callback` |
| **Description** | Handles the OAuth callback after the user authorizes the external service. Creates or updates the ExternalAccount with the received tokens. |
| **Primary entity** | ExternalAccount |
| **Secondary reads** | Session, User |
| **Secondary writes** | (none) |

---

## Subscription

Subscription operations manage billing through external payment providers.

### Create Stripe checkout session

| | |
|:--|:--|
| **Route** | `POST /api/stripe/checkout-session` |
| **Description** | Creates a Stripe checkout session and returns the checkout URL. The user is redirected to Stripe's hosted payment page to complete their subscription purchase. |
| **Primary entity** | Subscription |
| **Secondary reads** | User |
| **Secondary writes** | (none; Subscription is created/updated via webhook after payment completes) |

### RevenueCat webhook

| | |
|:--|:--|
| **Route** | `POST /webhooks/revenue-cat` |
| **Description** | Receives purchase and renewal events from RevenueCat (which aggregates Apple and Google in-app purchases). On `INITIAL_PURCHASE` or `RENEWAL` events, creates or updates the user's subscription record. Other event types are logged and ignored. |
| **Primary entity** | Subscription |
| **Secondary reads** | User |
| **Secondary writes** | (none) |

---

## Calendar

Calendar operations read and write events in the user's synced Google
Calendar.

### List today's events

| | |
|:--|:--|
| **Route** | `GET /api/calendar/events` |
| **Description** | Returns today's calendar events from the user's synced Google Calendar, with any matching Amby contacts attached. Used to populate the agenda view. |
| **Primary entity** | Calendar |
| **Secondary reads** | ExternalAccount, Contact |
| **Secondary writes** | (none) |

### Create appointment

| | |
|:--|:--|
| **Route** | `POST /api/calendar/:calendar_id/appointment` |
| **Description** | Creates a new event in the user's Google Calendar via the Google Calendar API. Requires an active Google external account connection. |
| **Primary entity** | Calendar |
| **Secondary reads** | ExternalAccount |
| **Secondary writes** | (none; event is created in Google Calendar, not in the local database) |

---

## Email

Email operations send messages through the user's connected Gmail account.

### Send email

| | |
|:--|:--|
| **Route** | `POST /api/email` |
| **Description** | Sends an email through the user's connected Gmail account via the Gmail API. The send operation is queued as a background job. |
| **Primary entity** | (none; email is an external side effect) |
| **Secondary reads** | ExternalAccount |
| **Secondary writes** | (none; email is sent via Gmail API, not stored locally) |

---

## Search

Search operations query the TypeSense full-text search index.

### Search contacts (v1)

| | |
|:--|:--|
| **Route** | `GET /api/search` |
| **Description** | Searches the user's contacts by name, email, or phone using TypeSense full-text search. Returns matching contacts. |
| **Primary entity** | Contact (via search index) |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Search contacts (v2)

| | |
|:--|:--|
| **Route** | `GET /api/v2/search` |
| **Description** | Enhanced contact search with support for filters, sort ordering, and location-based search. Returns results from TypeSense with richer metadata. |
| **Primary entity** | Contact (via search index) |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

---

## Enrichment Report

The enrichment report summarizes how many of a user's contacts have been
enriched and the quality of that data.

### Get enrichment report

| | |
|:--|:--|
| **Route** | `GET /api/enrichment-report` |
| **Description** | Returns aggregate statistics about the user's contact enrichment status: how many contacts are enriched, data quality distribution, and provider coverage. |
| **Primary entity** | Enrichment |
| **Secondary reads** | Contact |
| **Secondary writes** | (none) |

---

## AI Conversation

AI conversation operations power the in-app chat assistant.

### Query AI

| | |
|:--|:--|
| **Route** | `POST /api/ai/query` |
| **Description** | Sends a message to the AI assistant and receives a response. Supports three modes: (1) starting a new conversation that is persisted, (2) continuing an existing conversation with full message history, or (3) a stateless one-off query with no persistence. Optionally includes contact context. Supports streaming responses via Server-Sent Events. |
| **Primary entity** | Conversation |
| **Secondary reads** | Contact (if contact context provided), ConversationMessage (if continuing) |
| **Secondary writes** | ConversationMessage (user message and AI response saved) |

### Get AI usage

| | |
|:--|:--|
| **Route** | `GET /api/ai/usage` |
| **Description** | Returns the authenticated user's AI token usage for the current month and their monthly limit. Used to display remaining AI capacity in the UI. |
| **Primary entity** | Conversation |
| **Secondary reads** | ConversationMessage |
| **Secondary writes** | (none) |

---

## Document (SkySlope)

Document operations read real estate transaction files from the user's
connected SkySlope account.

### List documents

| | |
|:--|:--|
| **Route** | `GET /api/documents` |
| **Description** | Returns the list of real estate transaction files from the user's connected SkySlope account. |
| **Primary entity** | (external: SkySlope document) |
| **Secondary reads** | ExternalAccount |
| **Secondary writes** | (none) |

### Get document

| | |
|:--|:--|
| **Route** | `GET /api/documents/:id` |
| **Description** | Returns a single SkySlope document by ID. |
| **Primary entity** | (external: SkySlope document) |
| **Secondary reads** | ExternalAccount |
| **Secondary writes** | (none) |

### Get document envelopes

| | |
|:--|:--|
| **Route** | `GET /api/documents/:id/envelopes` |
| **Description** | Returns the signing envelopes associated with a SkySlope document, showing signature status and signer details. |
| **Primary entity** | (external: SkySlope document) |
| **Secondary reads** | ExternalAccount |
| **Secondary writes** | (none) |

---

## AI Text Message (HumanLoop)

### Generate text message

| | |
|:--|:--|
| **Route** | `GET /api/human-loop/text-message/:contact_id` |
| **Description** | Uses the HumanLoop AI service to generate a suggested text message for a contact. The AI considers the contact's profile, enrichment data, and relationship history to craft a personalized message. |
| **Primary entity** | Contact |
| **Secondary reads** | Enrichment |
| **Secondary writes** | (none) |

---

## Image Upload

### Get signed upload URL

| | |
|:--|:--|
| **Route** | `GET /api/upload/:scope/:extension` |
| **Description** | Generates a signed URL for direct file upload to Google Cloud Storage. The client uses this URL to upload an image (e.g., profile photo) without routing the file through the application server. |
| **Primary entity** | (none; infrastructure operation) |
| **Secondary reads** | (none) |
| **Secondary writes** | (none; file is uploaded directly to GCS by the client) |

---

## Authentication

Authentication operations manage user login and session lifecycle.

### Login page

| | |
|:--|:--|
| **Route** | `GET /login` |
| **Description** | Renders the login page with Auth0 sign-in options. |
| **Primary entity** | (none; UI only) |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Initiate Auth0 login

| | |
|:--|:--|
| **Route** | `GET /auth/auth0` |
| **Description** | Redirects the user to Auth0's hosted login page to authenticate. |
| **Primary entity** | (none; redirect only) |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

### Auth0 callback

| | |
|:--|:--|
| **Route** | `GET /auth/auth0/callback` |
| **Description** | Handles the OAuth callback from Auth0 after successful authentication. Finds or creates the User record, creates a Session, and redirects to the app. |
| **Primary entity** | User |
| **Secondary reads** | (none) |
| **Secondary writes** | Session |

### Logout

| | |
|:--|:--|
| **Route** | `DELETE /logout` |
| **Description** | Logs the user out by clearing the local session and redirecting to Auth0's logout endpoint to clear the Auth0 session. |
| **Primary entity** | Session |
| **Secondary reads** | (none) |
| **Secondary writes** | (deleted) |

### Apple Sign-In (stub)

| | |
|:--|:--|
| **Route** | `GET /api/apple-sign-in`, `POST /api/apple-sign-in` |
| **Description** | Stub endpoints for Apple Sign-In notifications. Currently logs the payload and returns 204. Not yet fully implemented. |
| **Primary entity** | (none) |
| **Secondary reads** | (none) |
| **Secondary writes** | (none) |

---

## LiveView Pages

These are browser-based pages rendered via Phoenix LiveView. They do not
expose a JSON API but do read and write domain entities through user
interactions.

### Contact list

| | |
|:--|:--|
| **Route** | `GET /` or `GET /contacts` |
| **Description** | The main contact list view. Displays the user's contacts with search, filtering by tags, and sorting. |
| **Primary entity** | Contact |
| **Secondary reads** | Tag, Enrichment |

### Contact detail

| | |
|:--|:--|
| **Route** | `GET /contacts/:id` |
| **Description** | The contact detail view. Shows all information about a contact including enrichment data, timeline, notes, tags, tasks, and possible addresses. Supports inline editing. |
| **Primary entity** | Contact |
| **Secondary reads** | Tag, Note, ContactEvent, Task, Enrichment, PossibleAddress, Highlight |

### Agenda

| | |
|:--|:--|
| **Route** | `GET /agenda` |
| **Description** | The agenda view. Shows today's calendar events, upcoming tasks, and contacts needing attention. |
| **Primary entity** | Task |
| **Secondary reads** | Calendar, Contact |

### Settings

| | |
|:--|:--|
| **Route** | `GET /settings` |
| **Description** | The user settings page. Allows editing profile information, managing external account connections, and viewing subscription status. |
| **Primary entity** | User |
| **Secondary reads** | ExternalAccount, Subscription |

---

## Admin Pages

Admin pages are restricted to users with `is_admin: true`.

### Admin dashboard

| | |
|:--|:--|
| **Route** | `GET /manage` |
| **Description** | The admin dashboard showing system-wide metrics and user activity. |
| **Primary entity** | User |
| **Secondary reads** | Contact, Subscription |

### Admin user detail

| | |
|:--|:--|
| **Route** | `GET /manage/users/:id` |
| **Description** | Admin view of a specific user's account, including their contacts, subscription status, and activity. |
| **Primary entity** | User |
| **Secondary reads** | Contact, Subscription, ExternalAccount |

### Admin contact detail

| | |
|:--|:--|
| **Route** | `GET /manage/contacts/:id` |
| **Description** | Admin view of a specific contact with full enrichment data and unified contact details. |
| **Primary entity** | Contact |
| **Secondary reads** | Enrichment, UnifiedContact, Providers.Endato, Providers.Faraday, Providers.Gravatar, Providers.Jitter |
