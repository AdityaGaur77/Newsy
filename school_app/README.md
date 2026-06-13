# School Hub

A Flutter school app with role-based permissions for **students**, **leadership**, and **admins**.

## What's inside

- **Students** can sign up, build a profile (avatar, bio, grade), edit their class schedule, browse announcements + flyers + resource links, see upcoming events, buy tickets to games/shows, and contact important staff.
- **Leadership** can post announcements, flyers (with custom emoji + color), resource links (Classroom, Clever, Library, Sports, Other), and create events.
- **Admins** can do everything leadership can, plus pin announcements, manage users (disable access, promote/demote roles, delete accounts), manage the contacts directory, delete any content, view an audit log, and see school-wide stats (counts, ticket revenue).

Everything is persisted locally via `shared_preferences`, so the app works offline as a demo. Swap `AppState`'s data layer for a real backend (Firebase, REST) when you're ready to ship.

## Run it

```bash
cd school_app
flutter pub get
flutter run
```

## Demo accounts

The app seeds three accounts on first launch:

| Role        | Email                | Password     |
|-------------|----------------------|--------------|
| Admin       | admin@school.edu     | admin123     |
| Leadership  | maya@school.edu      | leader123    |
| Student     | alex@school.edu      | student123   |

New signups always start as **Student** — only an admin can promote someone to leadership or admin.

## Tour

- **Home** — Quick-access tiles, pinned + recent announcements, upcoming events, flyer carousel.
- **Schedule** (students) — Add / edit / delete class periods.
- **Post** (leadership) — Tabs for Announcements, Flyers, and Links.
- **Admin** (admins) — Users tab (disable / change role / delete), Overview tab (stats + revenue), Audit tab (action log).
- **Events** — Browse upcoming/past, buy tickets, see "Got ticket" badge if you already bought one.
- **Resources** — Grid of links grouped by category (Classroom, Clever, Library, Sports, Other).
- **Contacts** — Important staff with email + phone; admins can edit/add.
- **Profile** — Avatar picker, bio, grade, sign out.

## Security notes (for when you wire up a real backend)

- Passwords are stored in plaintext in `SharedPreferences` for demo purposes only. Use Firebase Auth or a hashed-password backend in production.
- Role promotion happens on the client. Enforce it server-side via security rules.
- The audit log is local-only; persist it in your backend so it survives reinstalls.
