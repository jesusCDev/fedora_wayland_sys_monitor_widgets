
## 2026-09-01 — "journal clean" is not "it works"
- Reported the notify widget verified after a clean plasmashell journal; its model had zero rows the whole time (distro `@other` history blacklist). A clean log proves the QML parsed, nothing more. Before saying verified, push one real event through the data path and read the result back (row count, a rendered value) — through the widget's own DataSource to a scratch file if nothing else is observable.
- `console.warn` from a plasmoid never reached journald here. Don't burn restarts on it; log to a file via the executable DataSource from the start.
- When wrapping a library model, read its filter/count code before trusting defaults: KDE's `unreadNotificationsCount` skips active rows and `lastRead` is process-wide — both silently wrong for a second bell.

## 2026-09-02 — a role name is not the rule
- Counted "unread" from KDE's `ReadRole` because the name matched. It's a per-row flag the stock toast sets; the real rule (`Notifications::updateCount`) is `!read && created > lastRead`. Result: popup close never dimmed anything and nobody noticed for a round. When copying a library's derived value, copy the function that derives it, not the role that sounds like it.
- Proved it the cheap way this time: a temp Timer resetting `lastRead` plus the recount debug line showed `nu` drop to 0 in the log. Keep that pattern for state that only user clicks normally change.

## 2026-09-13 — a symptom report is not a spec
- "The alerts aren't going away" (2026-09-02) got a 60-minute auto-dismiss sweep built on a guess; the user meant the transfers widget's progress bars. When a report could name two or more things, one AskUserQuestion with the candidates costs seconds; a feature on the wrong reading cost a round trip plus its removal.
- Cutting a block with a substring search for `"    }\n"` matched the inner 8-space brace first and left a dangling `}` (syntax error at reload). Cut whole functions by regex anchored at line start, or just Edit the exact text.
- Synthetic KDE job views over D-Bus (`org.kde.JobViewServer.requestView` + `org.kde.JobViewV2` calls from one persistent connection) reproduce Dolphin/browser transfer behaviour without touching files; keep `scratchpad/twojobs.py`-style scripts for job widgets.
