defmodule CQRS.Router do
  use Commanded.Commands.Router

  alias CQRS.Enrichments
  alias CQRS.Leads
  alias CQRS.Meetings

  middleware CQRS.Middleware.CommandValidation

  dispatch [
             Enrichments.Commands.EnrichWithEndato,
             Enrichments.Commands.EnrichWithFaraday,
             Enrichments.Commands.EnrichWithTrestle,
             Enrichments.Commands.Jitter,
             Enrichments.Commands.RequestEnrichment,
             Enrichments.Commands.RequestProviderEnrichment,
             Enrichments.Commands.CompleteProviderEnrichment,
             Enrichments.Commands.RequestEnrichmentComposition,
             Enrichments.Commands.CompleteEnrichmentComposition,
             Enrichments.Commands.Reset
           ],
           to: Enrichments.EnrichmentAggregate,
           identity: :id,
           lifespan: Enrichments.EnrichmentAggregate.Lifespan

  dispatch [
             Leads.Commands.Create,
             Leads.Commands.Delete,
             Leads.Commands.JitterPtt,
             Leads.Commands.Update,
             Leads.Commands.Unify,
             Leads.Commands.InviteContact,
             Leads.Commands.ResetPttHistory,
             Leads.Commands.Correspond,
             Leads.Commands.SelectAddress
           ],
           to: Leads.LeadAggregate,
           identity: :id,
           lifespan: Leads.LeadAggregate.Lifespan

  dispatch [Meetings.Commands.Create],
    to: Meetings.MeetingAggregate,
    identity: :id,
    lifespan: Meetings.MeetingAggregate.Lifespan
end
