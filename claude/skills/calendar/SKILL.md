---
name: calendar
description: Stephen's family calendar system and the rules for managing it — creating events/reminders from booking confirmations, coordinating a family of 5 via shared calendars and invites, and keeping the whole thing dead simple. Use whenever the conversation involves calendars, scheduling, events, reminders, invites, availability/free-busy, travel or booking confirmations (hotels, rental cars, flights), iCal/subscription feeds, or the eventual Proton Calendar migration. Holds the account, calendar IDs, guest conventions, reminder defaults, and connector gotchas so the agent acts consistently.
---

# Calendar

Manage Stephen's family calendars with the Google Calendar connector. The goal is
always the same: **dead simple, easy to maintain.** Prefer fewer calendars,
subscribed feeds over hand entry, and one clear rule for where things go.

## The one rule that governs everything

> **Needs someone else to act → `Family`. Just Stephen → his personal calendar or a feed.**

Design principle behind it: **one calendar per _audience_, not per _topic_.**
Fitness, Master's coursework, and meetups are all "just Stephen" — they share an
audience (family sees free/busy only), so they live together on his personal
calendar, separated by color/emoji, **not** split into separate calendars.

## Accounts and calendars (the durable facts)

- Google account: **stephen.froeber@gmail.com** (the Claude.ai Google connectors
  are authorized here — not `drawthemoral@gmail.com`, which is a shared vendor
  inbox used only for bookings).
- **`Family`** — shared household coordination calendar. This is the default
  target for anything requiring coordination.
  ID: `family11313292835949769365@group.calendar.google.com`
- **Primary personal** — Stephen's own stuff (fitness / college / meetups),
  shared to Christine as free/busy only.
  ID: `stephen.froeber@gmail.com`
- Everything else in the account (kids' sports, Final Surge, Secular Buddhist
  Network, CNCF, Volunteer TA) is a **read-only subscription feed** — reference
  layers, never write to them.

## Category handling (on the personal calendar)

Encode category in the **event title**, not just color — titles survive the
Proton migration and every client; Google color IDs do not. Suggested prefixes:
- `🏋️` fitness · `🎓` college/Master's · `👥` meetups/groups

Prefer **subscribed iCal feeds** wherever a source system publishes one (Final
Surge for training, the Master's LMS for deadlines, Meetup/group calendars) —
zero maintenance. Only hand-enter what has no feed, or what must block family
visibility (races, travel, long wind-sport sessions).

## Family guests

Guest email convention: **`<firstname>.froeber@gmail.com`** —
christine, kylie, killian, knightly. (Note: on vendor confirmations Christine's
contact often shows as `drawthemoral@gmail.com`; her calendar guest address is
`christine.froeber@gmail.com`.) Whole-family trips → invite all four. Otherwise
invite only the people who need to act.

## Defaults when creating events

- **Reminders:** popup at **1 day (1440 min)** and **1 hour (60 min)** before.
  Extend earlier when travel time makes an hour insufficient. Pass via
  `overrideReminders`.
- **Timezone:** always set `timeZone` explicitly. Currently **America/Chicago**;
  after the move to the Netherlands, **Europe/Amsterdam**. Existing events with a
  proper timezone shift correctly on their own.
- **Duration:** for point-in-time actions (car pickup, hotel check-in, an
  appointment) use a short ~30-min block, not a multi-day span.
- **Two separate actions → two separate events.** A rental's pickup and return,
  or a hotel's check-in and check-out, are distinct events — never one block
  spanning the whole stay.
- Put the useful specifics in the description: confirmation/order number, vendor,
  driver, price + "pay at counter" vs prepaid, and a support phone number.

## Workflow: turning a confirmation into events

1. Read the confirmation (PDF/email). Extract each dated action and its exact
   local time.
2. Confirm anything ambiguous before creating — especially **missing times**
   (e.g. hotels often list only dates; standard Hilton-style defaults are 3 PM
   check-in / 11 AM check-out, but ask), and which calendar.
3. Create one event per action with the defaults above.
4. Report back with a table of what was created and flag any assumptions.

## Connector notes / gotchas

- The Google connectors are Claude.ai first-party tools, surfaced as **deferred**
  `mcp__claude_ai_Google_Calendar__*` (and `_Gmail_`, `_Google_Drive_`). Load
  schemas via `ToolSearch` before calling. `list_calendars` returns IDs;
  `create_event` / `update_event` / `delete_event` do the work. There is **no
  create-calendar / change-sharing tool** — those are one-time clicks Stephen
  does in the Calendar UI.
- **Google Meet auto-attach:** the connector may attach a Meet URL even when
  `addGoogleMeetUrl` is not set (a per-calendar "automatically add Meet" default).
  It's noise on travel/logistics events. To avoid it, Stephen can disable that in
  Calendar settings; to remove after the fact, use `update_event`.

## Proton migration (later)

Keeping owned calendars few + everything else as feeds makes migration trivial:
export the 2 owned calendars to `.ics`, import to Proton; re-subscribe feeds by
URL. This is why title-based (not color-based) categorization matters.
