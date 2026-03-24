import posthog from "posthog-js";

// Initialize PostHog analytics
// https://posthog.com/docs/libraries/js
posthog.init(POSTHOG_API_KEY, {
  api_host: POSTHOG_API_URL,
  person_profiles: "always" // https://posthog.com/docs/data/anonymous-vs-identified-events
});
