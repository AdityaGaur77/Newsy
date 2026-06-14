# School Hub

A Flutter school app with role-based permissions for **students**, **leadership**, and **admins**.

## What's inside

- **Students** can sign up, build a profile (avatar, bio, grade), browse announcements + flyers + resource links, see upcoming events, buy tickets to games/shows, and contact important staff.
- **Leadership** can post announcements (with a color tag), flyers (custom emoji + gradient), resource links (Classroom, Clever, Library, Sports, Other), and create events.
- **Admins** can do everything leadership can, plus pin announcements, manage users (disable access, promote/demote roles, delete accounts), manage the contacts directory, delete any content, view an audit log, and see school-wide stats (counts, ticket revenue).

The UI is a neo-brutalist sticker-book aesthetic — chunky 2px borders, hard offset shadows, vivid accents (purple / lime / pink / sky / sun), and big bold type. A **dark mode toggle** is available in every screen's app bar and on the Profile page.

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

- **Home** — Hero card with greeting, quick-jump tiles, pinned + recent announcements (sticker cards), upcoming events (ticket-stub style), tilted flyer carousel.
- **Post** (leadership) — Tabs for Announcements, Flyers, and Links.
- **Admin** (admins) — Users tab (disable / change role / delete), Stats tab (counts + ticket revenue), Audit tab (action log).
- **Events** — Browse upcoming/past, buy tickets, see "Got it" badge if you already bought one.
- **Hub** (Resources) — Color-coded tiles grouped by category (Classroom, Clever, Library, Sports, Other).
- **People** (Contacts) — Important staff with email + phone; admins can edit/add.
- **Me** (Profile) — Avatar picker, bio, grade, dark-mode toggle, sign out.

## Security notes (for when you wire up a real backend)

- Passwords are stored in plaintext in `SharedPreferences` for demo purposes only. Use Firebase Auth or a hashed-password backend in production.
- Role promotion happens on the client. Enforce it server-side via security rules.
- The audit log is local-only; persist it in your backend so it survives reinstalls.
