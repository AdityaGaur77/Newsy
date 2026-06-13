// School Hub — role-based school app (student / leadership / admin).
// Single-file Flutter app. Uses SharedPreferences for local persistence so
// it runs offline without a backend. Swap the AppState data layer for a
// real API (Firebase / REST) when wiring to production.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.load();
  runApp(SchoolHubApp(state: state));
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────────────────────────────────────

class Brand {
  static const primary = Color(0xFF1E40AF);
  static const primaryLight = Color(0xFFDBEAFE);
  static const accent = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
  static const success = Color(0xFF059669);
  static const bg = Color(0xFFF7F8FB);
  static const card = Colors.white;
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);

  static Color roleColor(UserRole r) {
    switch (r) {
      case UserRole.admin:
        return danger;
      case UserRole.leadership:
        return accent;
      case UserRole.student:
        return primary;
    }
  }

  static String roleLabel(UserRole r) {
    switch (r) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.leadership:
        return 'Leadership';
      case UserRole.student:
        return 'Student';
    }
  }
}

ThemeData buildTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(seedColor: Brand.primary),
    scaffoldBackgroundColor: Brand.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Brand.card,
      foregroundColor: Brand.text,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Brand.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Brand.border),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Brand.card,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Brand.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Brand.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Brand.primary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Brand.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum UserRole { student, leadership, admin }

UserRole _roleFromString(String s) =>
    UserRole.values.firstWhere((r) => r.name == s, orElse: () => UserRole.student);

class ScheduleItem {
  String id;
  String period;
  String className;
  String teacher;
  String room;
  String time;
  ScheduleItem({
    required this.id,
    required this.period,
    required this.className,
    required this.teacher,
    required this.room,
    required this.time,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'period': period,
        'className': className,
        'teacher': teacher,
        'room': room,
        'time': time,
      };
  factory ScheduleItem.fromJson(Map<String, dynamic> j) => ScheduleItem(
        id: j['id'],
        period: j['period'],
        className: j['className'],
        teacher: j['teacher'],
        room: j['room'],
        time: j['time'],
      );
}

class AppUser {
  String id;
  String name;
  String email;
  String password; // demo only — never store plaintext in real apps
  UserRole role;
  String bio;
  String grade;
  String avatarEmoji;
  bool disabled;
  List<ScheduleItem> schedule;
  DateTime createdAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.bio = '',
    this.grade = '',
    this.avatarEmoji = '🙂',
    this.disabled = false,
    List<ScheduleItem>? schedule,
    DateTime? createdAt,
  })  : schedule = schedule ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'role': role.name,
        'bio': bio,
        'grade': grade,
        'avatarEmoji': avatarEmoji,
        'disabled': disabled,
        'schedule': schedule.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        name: j['name'],
        email: j['email'],
        password: j['password'],
        role: _roleFromString(j['role']),
        bio: j['bio'] ?? '',
        grade: j['grade'] ?? '',
        avatarEmoji: j['avatarEmoji'] ?? '🙂',
        disabled: j['disabled'] ?? false,
        schedule: (j['schedule'] as List? ?? [])
            .map((s) => ScheduleItem.fromJson(Map<String, dynamic>.from(s)))
            .toList(),
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
      );
}

class Announcement {
  String id;
  String authorId;
  String authorName;
  UserRole authorRole;
  String title;
  String body;
  DateTime createdAt;
  bool pinned;
  Announcement({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.title,
    required this.body,
    required this.createdAt,
    this.pinned = false,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'authorRole': authorRole.name,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'pinned': pinned,
      };
  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id'],
        authorId: j['authorId'],
        authorName: j['authorName'],
        authorRole: _roleFromString(j['authorRole']),
        title: j['title'],
        body: j['body'],
        createdAt: DateTime.parse(j['createdAt']),
        pinned: j['pinned'] ?? false,
      );
}

class Flyer {
  String id;
  String authorId;
  String authorName;
  String title;
  String description;
  String emoji; // visual placeholder
  int colorSeed;
  DateTime createdAt;
  Flyer({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.description,
    required this.emoji,
    required this.colorSeed,
    required this.createdAt,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'title': title,
        'description': description,
        'emoji': emoji,
        'colorSeed': colorSeed,
        'createdAt': createdAt.toIso8601String(),
      };
  factory Flyer.fromJson(Map<String, dynamic> j) => Flyer(
        id: j['id'],
        authorId: j['authorId'],
        authorName: j['authorName'],
        title: j['title'],
        description: j['description'],
        emoji: j['emoji'] ?? '📣',
        colorSeed: j['colorSeed'] ?? 0,
        createdAt: DateTime.parse(j['createdAt']),
      );
}

class ResourceLink {
  String id;
  String authorId;
  String title;
  String url;
  String category; // Classroom / Clever / Library / Sports / Other
  String description;
  DateTime createdAt;
  ResourceLink({
    required this.id,
    required this.authorId,
    required this.title,
    required this.url,
    required this.category,
    required this.description,
    required this.createdAt,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'title': title,
        'url': url,
        'category': category,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
      };
  factory ResourceLink.fromJson(Map<String, dynamic> j) => ResourceLink(
        id: j['id'],
        authorId: j['authorId'],
        title: j['title'],
        url: j['url'],
        category: j['category'] ?? 'Other',
        description: j['description'] ?? '',
        createdAt: DateTime.parse(j['createdAt']),
      );
}

class Event {
  String id;
  String title;
  String description;
  DateTime date;
  String location;
  bool ticketed;
  double ticketPrice;
  int ticketsAvailable;
  int ticketsSold;
  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    required this.ticketed,
    required this.ticketPrice,
    required this.ticketsAvailable,
    this.ticketsSold = 0,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        'location': location,
        'ticketed': ticketed,
        'ticketPrice': ticketPrice,
        'ticketsAvailable': ticketsAvailable,
        'ticketsSold': ticketsSold,
      };
  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: j['id'],
        title: j['title'],
        description: j['description'],
        date: DateTime.parse(j['date']),
        location: j['location'],
        ticketed: j['ticketed'] ?? false,
        ticketPrice: (j['ticketPrice'] as num?)?.toDouble() ?? 0,
        ticketsAvailable: j['ticketsAvailable'] ?? 0,
        ticketsSold: j['ticketsSold'] ?? 0,
      );
}

class Ticket {
  String id;
  String eventId;
  String userId;
  String code;
  DateTime purchasedAt;
  Ticket({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.code,
    required this.purchasedAt,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'eventId': eventId,
        'userId': userId,
        'code': code,
        'purchasedAt': purchasedAt.toIso8601String(),
      };
  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
        id: j['id'],
        eventId: j['eventId'],
        userId: j['userId'],
        code: j['code'],
        purchasedAt: DateTime.parse(j['purchasedAt']),
      );
}

class Contact {
  String id;
  String name;
  String title;
  String email;
  String phone;
  String department;
  Contact({
    required this.id,
    required this.name,
    required this.title,
    required this.email,
    required this.phone,
    required this.department,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'title': title,
        'email': email,
        'phone': phone,
        'department': department,
      };
  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
        id: j['id'],
        name: j['name'],
        title: j['title'],
        email: j['email'],
        phone: j['phone'],
        department: j['department'],
      );
}

class AuditEntry {
  String id;
  String actorId;
  String actorName;
  String action;
  DateTime timestamp;
  AuditEntry({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.timestamp,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'actorId': actorId,
        'actorName': actorName,
        'action': action,
        'timestamp': timestamp.toIso8601String(),
      };
  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        id: j['id'],
        actorId: j['actorId'],
        actorName: j['actorName'],
        action: j['action'],
        timestamp: DateTime.parse(j['timestamp']),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// APP STATE (in-memory + persisted to SharedPreferences)
// ─────────────────────────────────────────────────────────────────────────────

String _newId() =>
    DateTime.now().microsecondsSinceEpoch.toString() +
    Random().nextInt(99999).toString();

class AppState extends ChangeNotifier {
  AppUser? currentUser;

  List<AppUser> users = [];
  List<Announcement> announcements = [];
  List<Flyer> flyers = [];
  List<ResourceLink> resources = [];
  List<Event> events = [];
  List<Ticket> tickets = [];
  List<Contact> contacts = [];
  List<AuditEntry> audit = [];

  static const _kKey = 'school_hub_state_v1';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kKey);
    if (raw == null) {
      _seed();
      await save();
      return;
    }
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      users = (j['users'] as List)
          .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      announcements = (j['announcements'] as List)
          .map((e) => Announcement.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      flyers = (j['flyers'] as List)
          .map((e) => Flyer.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      resources = (j['resources'] as List)
          .map((e) => ResourceLink.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      events = (j['events'] as List)
          .map((e) => Event.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      tickets = (j['tickets'] as List)
          .map((e) => Ticket.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      contacts = (j['contacts'] as List)
          .map((e) => Contact.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      audit = (j['audit'] as List)
          .map((e) => AuditEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final activeId = j['currentUserId'] as String?;
      if (activeId != null) {
        currentUser =
            users.cast<AppUser?>().firstWhere((u) => u!.id == activeId, orElse: () => null);
        if (currentUser?.disabled == true) currentUser = null;
      }
    } catch (_) {
      _seed();
      await save();
    }
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    final j = {
      'users': users.map((e) => e.toJson()).toList(),
      'announcements': announcements.map((e) => e.toJson()).toList(),
      'flyers': flyers.map((e) => e.toJson()).toList(),
      'resources': resources.map((e) => e.toJson()).toList(),
      'events': events.map((e) => e.toJson()).toList(),
      'tickets': tickets.map((e) => e.toJson()).toList(),
      'contacts': contacts.map((e) => e.toJson()).toList(),
      'audit': audit.map((e) => e.toJson()).toList(),
      'currentUserId': currentUser?.id,
    };
    await p.setString(_kKey, jsonEncode(j));
  }

  void _seed() {
    final admin = AppUser(
      id: _newId(),
      name: 'Principal Adams',
      email: 'admin@school.edu',
      password: 'admin123',
      role: UserRole.admin,
      bio: 'Head of school administration.',
      grade: 'Staff',
      avatarEmoji: '👔',
    );
    final leader = AppUser(
      id: _newId(),
      name: 'Maya Chen',
      email: 'maya@school.edu',
      password: 'leader123',
      role: UserRole.leadership,
      bio: 'ASB President. Coffee + spirit weeks.',
      grade: '12',
      avatarEmoji: '🎤',
    );
    final student = AppUser(
      id: _newId(),
      name: 'Alex Park',
      email: 'alex@school.edu',
      password: 'student123',
      role: UserRole.student,
      bio: 'Sophomore. Robotics club, runs cross-country.',
      grade: '10',
      avatarEmoji: '🏃',
      schedule: [
        ScheduleItem(id: _newId(), period: '1', className: 'Algebra II', teacher: 'Ms. Reyes', room: '204', time: '8:00 – 8:50'),
        ScheduleItem(id: _newId(), period: '2', className: 'English', teacher: 'Mr. Patel', room: '112', time: '8:55 – 9:45'),
        ScheduleItem(id: _newId(), period: '3', className: 'Biology', teacher: 'Dr. Lee', room: '301', time: '9:50 – 10:40'),
        ScheduleItem(id: _newId(), period: '4', className: 'World History', teacher: 'Mr. Brooks', room: '208', time: '10:45 – 11:35'),
      ],
    );
    users = [admin, leader, student];

    announcements = [
      Announcement(
        id: _newId(),
        authorId: admin.id,
        authorName: admin.name,
        authorRole: UserRole.admin,
        title: 'Welcome back!',
        body: 'New semester starts Monday. Schedules are live in the app.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        pinned: true,
      ),
      Announcement(
        id: _newId(),
        authorId: leader.id,
        authorName: leader.name,
        authorRole: UserRole.leadership,
        title: 'Spirit week 🎉',
        body: 'Mon: Pajama day. Tue: Twin day. Wed: Decades. Thu: Jersey. Fri: Spirit colors!',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    flyers = [
      Flyer(
        id: _newId(),
        authorId: leader.id,
        authorName: leader.name,
        title: 'Homecoming Dance',
        description: 'Friday 7pm in the gym. Tickets \$15 at the door.',
        emoji: '💃',
        colorSeed: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Flyer(
        id: _newId(),
        authorId: leader.id,
        authorName: leader.name,
        title: 'Blood Drive',
        description: 'Wednesday in the library. Sign up at the front desk.',
        emoji: '🩸',
        colorSeed: 3,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];

    resources = [
      ResourceLink(id: _newId(), authorId: admin.id, title: 'Google Classroom', url: 'https://classroom.google.com', category: 'Classroom', description: 'All your classes and assignments.', createdAt: DateTime.now()),
      ResourceLink(id: _newId(), authorId: admin.id, title: 'Clever Portal', url: 'https://clever.com', category: 'Clever', description: 'Single sign-on to school apps.', createdAt: DateTime.now()),
      ResourceLink(id: _newId(), authorId: admin.id, title: 'Library Catalog', url: 'https://library.school.edu', category: 'Library', description: 'Search books and reserve study rooms.', createdAt: DateTime.now()),
      ResourceLink(id: _newId(), authorId: leader.id, title: 'Athletics Schedule', url: 'https://athletics.school.edu', category: 'Sports', description: 'Game schedules and standings.', createdAt: DateTime.now()),
    ];

    events = [
      Event(
        id: _newId(),
        title: 'Varsity Football vs. Lincoln',
        description: 'Home game — wear your spirit colors!',
        date: DateTime.now().add(const Duration(days: 5)),
        location: 'Memorial Stadium',
        ticketed: true,
        ticketPrice: 8.00,
        ticketsAvailable: 500,
      ),
      Event(
        id: _newId(),
        title: 'Spring Musical: Into the Woods',
        description: 'Drama club spring production.',
        date: DateTime.now().add(const Duration(days: 14)),
        location: 'Auditorium',
        ticketed: true,
        ticketPrice: 12.00,
        ticketsAvailable: 200,
      ),
      Event(
        id: _newId(),
        title: 'Parent-Teacher Conferences',
        description: 'Sign up via the office.',
        date: DateTime.now().add(const Duration(days: 21)),
        location: 'Classrooms',
        ticketed: false,
        ticketPrice: 0,
        ticketsAvailable: 0,
      ),
    ];

    contacts = [
      Contact(id: _newId(), name: 'Principal Adams', title: 'Principal', email: 'adams@school.edu', phone: '555-0100', department: 'Admin'),
      Contact(id: _newId(), name: 'Ms. Ortiz', title: 'School Counselor', email: 'ortiz@school.edu', phone: '555-0110', department: 'Counseling'),
      Contact(id: _newId(), name: 'Nurse Kim', title: 'School Nurse', email: 'kim@school.edu', phone: '555-0120', department: 'Health'),
      Contact(id: _newId(), name: 'Coach Rivera', title: 'Athletic Director', email: 'rivera@school.edu', phone: '555-0130', department: 'Athletics'),
    ];

    audit = [
      AuditEntry(id: _newId(), actorId: admin.id, actorName: admin.name, action: 'Seeded initial data', timestamp: DateTime.now()),
    ];
  }

  // ── auth ────────────────────────────────────────────────────────────────
  String? signIn(String email, String password) {
    final match = users.cast<AppUser?>().firstWhere(
          (u) => u!.email.toLowerCase() == email.toLowerCase() && u.password == password,
          orElse: () => null,
        );
    if (match == null) return 'Invalid email or password.';
    if (match.disabled) return 'This account has been disabled by an administrator.';
    currentUser = match;
    _log(match, 'Signed in');
    save();
    notifyListeners();
    return null;
  }

  String? signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    required String grade,
  }) {
    if (users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      return 'An account with that email already exists.';
    }
    // Only allow self-signup as student. Leadership/admin must be promoted by an admin.
    final actualRole = role == UserRole.student ? UserRole.student : UserRole.student;
    final u = AppUser(
      id: _newId(),
      name: name,
      email: email,
      password: password,
      role: actualRole,
      grade: grade,
    );
    users.add(u);
    currentUser = u;
    _log(u, 'Created account');
    save();
    notifyListeners();
    return null;
  }

  void signOut() {
    if (currentUser != null) _log(currentUser!, 'Signed out');
    currentUser = null;
    save();
    notifyListeners();
  }

  // ── profile ─────────────────────────────────────────────────────────────
  void updateProfile({String? name, String? bio, String? grade, String? avatarEmoji}) {
    final u = currentUser;
    if (u == null) return;
    if (name != null) u.name = name;
    if (bio != null) u.bio = bio;
    if (grade != null) u.grade = grade;
    if (avatarEmoji != null) u.avatarEmoji = avatarEmoji;
    _log(u, 'Updated profile');
    save();
    notifyListeners();
  }

  void upsertScheduleItem(ScheduleItem item) {
    final u = currentUser;
    if (u == null) return;
    final i = u.schedule.indexWhere((s) => s.id == item.id);
    if (i >= 0) {
      u.schedule[i] = item;
    } else {
      u.schedule.add(item);
    }
    u.schedule.sort((a, b) => a.period.compareTo(b.period));
    save();
    notifyListeners();
  }

  void removeScheduleItem(String id) {
    currentUser?.schedule.removeWhere((s) => s.id == id);
    save();
    notifyListeners();
  }

  // ── content (leadership + admin) ────────────────────────────────────────
  void postAnnouncement(String title, String body, {bool pinned = false}) {
    final u = currentUser;
    if (u == null || !(u.role == UserRole.leadership || u.role == UserRole.admin)) return;
    announcements.insert(
      0,
      Announcement(
        id: _newId(),
        authorId: u.id,
        authorName: u.name,
        authorRole: u.role,
        title: title,
        body: body,
        createdAt: DateTime.now(),
        pinned: pinned && u.role == UserRole.admin,
      ),
    );
    _log(u, 'Posted announcement: $title');
    save();
    notifyListeners();
  }

  void deleteAnnouncement(String id) {
    final u = currentUser;
    if (u == null) return;
    final a = announcements.firstWhere((x) => x.id == id, orElse: () => Announcement(id: '', authorId: '', authorName: '', authorRole: UserRole.student, title: '', body: '', createdAt: DateTime.now()));
    if (a.id.isEmpty) return;
    if (u.role != UserRole.admin && u.id != a.authorId) return;
    announcements.removeWhere((x) => x.id == id);
    _log(u, 'Deleted announcement: ${a.title}');
    save();
    notifyListeners();
  }

  void postFlyer(String title, String description, String emoji, int colorSeed) {
    final u = currentUser;
    if (u == null || !(u.role == UserRole.leadership || u.role == UserRole.admin)) return;
    flyers.insert(
      0,
      Flyer(
        id: _newId(),
        authorId: u.id,
        authorName: u.name,
        title: title,
        description: description,
        emoji: emoji,
        colorSeed: colorSeed,
        createdAt: DateTime.now(),
      ),
    );
    _log(u, 'Posted flyer: $title');
    save();
    notifyListeners();
  }

  void deleteFlyer(String id) {
    final u = currentUser;
    if (u == null) return;
    final f = flyers.firstWhere((x) => x.id == id, orElse: () => Flyer(id: '', authorId: '', authorName: '', title: '', description: '', emoji: '', colorSeed: 0, createdAt: DateTime.now()));
    if (f.id.isEmpty) return;
    if (u.role != UserRole.admin && u.id != f.authorId) return;
    flyers.removeWhere((x) => x.id == id);
    _log(u, 'Deleted flyer: ${f.title}');
    save();
    notifyListeners();
  }

  void postResource(String title, String url, String category, String description) {
    final u = currentUser;
    if (u == null || !(u.role == UserRole.leadership || u.role == UserRole.admin)) return;
    resources.insert(
      0,
      ResourceLink(
        id: _newId(),
        authorId: u.id,
        title: title,
        url: url,
        category: category,
        description: description,
        createdAt: DateTime.now(),
      ),
    );
    _log(u, 'Posted resource: $title');
    save();
    notifyListeners();
  }

  void deleteResource(String id) {
    final u = currentUser;
    if (u == null) return;
    final r = resources.firstWhere((x) => x.id == id, orElse: () => ResourceLink(id: '', authorId: '', title: '', url: '', category: '', description: '', createdAt: DateTime.now()));
    if (r.id.isEmpty) return;
    if (u.role != UserRole.admin && u.id != r.authorId) return;
    resources.removeWhere((x) => x.id == id);
    _log(u, 'Deleted resource: ${r.title}');
    save();
    notifyListeners();
  }

  // ── events + tickets ────────────────────────────────────────────────────
  void createEvent(Event e) {
    final u = currentUser;
    if (u == null || !(u.role == UserRole.leadership || u.role == UserRole.admin)) return;
    events.add(e);
    events.sort((a, b) => a.date.compareTo(b.date));
    _log(u, 'Created event: ${e.title}');
    save();
    notifyListeners();
  }

  void deleteEvent(String id) {
    final u = currentUser;
    if (u == null || u.role != UserRole.admin) return;
    final e = events.firstWhere((x) => x.id == id, orElse: () => Event(id: '', title: '', description: '', date: DateTime.now(), location: '', ticketed: false, ticketPrice: 0, ticketsAvailable: 0));
    if (e.id.isEmpty) return;
    events.removeWhere((x) => x.id == id);
    tickets.removeWhere((t) => t.eventId == id);
    _log(u, 'Deleted event: ${e.title}');
    save();
    notifyListeners();
  }

  String? buyTicket(String eventId) {
    final u = currentUser;
    if (u == null) return 'You must be signed in.';
    final i = events.indexWhere((e) => e.id == eventId);
    if (i < 0) return 'Event not found.';
    final e = events[i];
    if (!e.ticketed) return 'This event does not require a ticket.';
    if (e.ticketsSold >= e.ticketsAvailable) return 'Sold out.';
    if (tickets.any((t) => t.eventId == eventId && t.userId == u.id)) {
      return 'You already have a ticket for this event.';
    }
    e.ticketsSold += 1;
    final code = 'TKT-${Random().nextInt(999999).toString().padLeft(6, '0')}';
    tickets.add(Ticket(
      id: _newId(),
      eventId: eventId,
      userId: u.id,
      code: code,
      purchasedAt: DateTime.now(),
    ));
    _log(u, 'Bought ticket for: ${e.title}');
    save();
    notifyListeners();
    return null;
  }

  // ── contacts ────────────────────────────────────────────────────────────
  void upsertContact(Contact c) {
    final u = currentUser;
    if (u == null || u.role != UserRole.admin) return;
    final i = contacts.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      contacts[i] = c;
    } else {
      contacts.add(c);
    }
    _log(u, 'Saved contact: ${c.name}');
    save();
    notifyListeners();
  }

  void deleteContact(String id) {
    final u = currentUser;
    if (u == null || u.role != UserRole.admin) return;
    contacts.removeWhere((x) => x.id == id);
    save();
    notifyListeners();
  }

  // ── admin: user management ──────────────────────────────────────────────
  void setUserDisabled(String userId, bool disabled) {
    final u = currentUser;
    if (u == null || u.role != UserRole.admin) return;
    final target = users.firstWhere((x) => x.id == userId, orElse: () => u);
    if (target.id == u.id) return; // never disable yourself
    target.disabled = disabled;
    _log(u, '${disabled ? "Disabled" : "Enabled"} user: ${target.name}');
    save();
    notifyListeners();
  }

  void setUserRole(String userId, UserRole role) {
    final u = currentUser;
    if (u == null || u.role != UserRole.admin) return;
    final target = users.firstWhere((x) => x.id == userId, orElse: () => u);
    if (target.id == u.id) return; // can't demote self
    target.role = role;
    _log(u, 'Set role of ${target.name} to ${Brand.roleLabel(role)}');
    save();
    notifyListeners();
  }

  void deleteUser(String userId) {
    final u = currentUser;
    if (u == null || u.role != UserRole.admin) return;
    if (userId == u.id) return;
    final target = users.firstWhere((x) => x.id == userId, orElse: () => u);
    users.removeWhere((x) => x.id == userId);
    tickets.removeWhere((t) => t.userId == userId);
    _log(u, 'Deleted user: ${target.name}');
    save();
    notifyListeners();
  }

  // ── audit ───────────────────────────────────────────────────────────────
  void _log(AppUser actor, String action) {
    audit.insert(
      0,
      AuditEntry(
        id: _newId(),
        actorId: actor.id,
        actorName: actor.name,
        action: action,
        timestamp: DateTime.now(),
      ),
    );
    if (audit.length > 500) audit = audit.sublist(0, 500);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────────────────────────────────────

class SchoolHubApp extends StatelessWidget {
  final AppState state;
  const SchoolHubApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (_, __) => MaterialApp(
        title: 'School Hub',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: state.currentUser == null ? AuthScreen(state: state) : HomeShell(state: state),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH
// ─────────────────────────────────────────────────────────────────────────────

class AuthScreen extends StatefulWidget {
  final AppState state;
  const AuthScreen({super.key, required this.state});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignup = false;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _grade = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _grade.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    String? err;
    if (_isSignup) {
      err = widget.state.signUp(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        role: UserRole.student,
        grade: _grade.text.trim(),
      );
    } else {
      err = widget.state.signIn(_email.text.trim(), _password.text);
    }
    if (!mounted) return;
    setState(() {
      _error = err;
      _busy = false;
    });
  }

  void _fillDemo(String email, String password) {
    _email.text = email;
    _password.text = password;
    setState(() => _isSignup = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Brand.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text('🏫', style: TextStyle(fontSize: 36)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isSignup ? 'Create your account' : 'School Hub',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Brand.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSignup
                        ? 'New students start here. Leadership and admin roles are assigned by your administrator.'
                        : 'Sign in to see announcements, your schedule, events, and more.',
                    style: const TextStyle(color: Brand.muted),
                  ),
                  const SizedBox(height: 24),
                  if (_isSignup) ...[
                    TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
                    const SizedBox(height: 12),
                    TextField(controller: _grade, decoration: const InputDecoration(labelText: 'Grade (e.g. 10)')),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'School email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Brand.danger)),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_isSignup ? 'Create account' : 'Sign in'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isSignup = !_isSignup),
                    child: Text(_isSignup
                        ? 'Already have an account? Sign in'
                        : "New student? Create an account"),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Demo accounts',
                    style: TextStyle(
                      color: Brand.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _demoBtn('Admin', 'admin@school.edu', 'admin123', UserRole.admin),
                  const SizedBox(height: 8),
                  _demoBtn('Leadership', 'maya@school.edu', 'leader123', UserRole.leadership),
                  const SizedBox(height: 8),
                  _demoBtn('Student', 'alex@school.edu', 'student123', UserRole.student),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _demoBtn(String label, String email, String password, UserRole role) {
    return OutlinedButton(
      onPressed: () => _fillDemo(email, password),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Brand.roleColor(role)),
        foregroundColor: Brand.roleColor(role),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 18, color: Brand.roleColor(role)),
          const SizedBox(width: 8),
          Text('$label · $email'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME SHELL (role-aware bottom nav)
// ─────────────────────────────────────────────────────────────────────────────

class HomeShell extends StatefulWidget {
  final AppState state;
  const HomeShell({super.key, required this.state});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  List<_NavTab> _tabs(AppUser u) {
    final common = <_NavTab>[
      _NavTab(icon: Icons.home_outlined, active: Icons.home, label: 'Home', builder: (_) => HomeFeedScreen(state: widget.state)),
      _NavTab(icon: Icons.event_outlined, active: Icons.event, label: 'Events', builder: (_) => EventsScreen(state: widget.state)),
      _NavTab(icon: Icons.apps_outlined, active: Icons.apps, label: 'Resources', builder: (_) => ResourcesScreen(state: widget.state)),
      _NavTab(icon: Icons.contacts_outlined, active: Icons.contacts, label: 'Contacts', builder: (_) => ContactsScreen(state: widget.state)),
    ];
    switch (u.role) {
      case UserRole.student:
        return [
          common[0],
          _NavTab(icon: Icons.schedule_outlined, active: Icons.schedule, label: 'Schedule', builder: (_) => ScheduleScreen(state: widget.state)),
          common[1],
          common[2],
          common[3],
          _NavTab(icon: Icons.person_outline, active: Icons.person, label: 'Profile', builder: (_) => ProfileScreen(state: widget.state)),
        ];
      case UserRole.leadership:
        return [
          common[0],
          _NavTab(icon: Icons.add_box_outlined, active: Icons.add_box, label: 'Post', builder: (_) => LeadershipPostScreen(state: widget.state)),
          common[1],
          common[2],
          common[3],
          _NavTab(icon: Icons.person_outline, active: Icons.person, label: 'Profile', builder: (_) => ProfileScreen(state: widget.state)),
        ];
      case UserRole.admin:
        return [
          common[0],
          _NavTab(icon: Icons.shield_outlined, active: Icons.shield, label: 'Admin', builder: (_) => AdminDashboard(state: widget.state)),
          common[1],
          common[2],
          common[3],
          _NavTab(icon: Icons.person_outline, active: Icons.person, label: 'Profile', builder: (_) => ProfileScreen(state: widget.state)),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.state.currentUser!;
    final tabs = _tabs(u);
    final idx = _index.clamp(0, tabs.length - 1);
    return Scaffold(
      body: tabs[idx].builder(context),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.active),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _NavTab {
  final IconData icon;
  final IconData active;
  final String label;
  final WidgetBuilder builder;
  _NavTab({required this.icon, required this.active, required this.label, required this.builder});
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class RoleBadge extends StatelessWidget {
  final UserRole role;
  const RoleBadge({super.key, required this.role});
  @override
  Widget build(BuildContext context) {
    final c = Brand.roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        Brand.roleLabel(role).toUpperCase(),
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.subtitle, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Brand.text,
                    )),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: const TextStyle(color: Brand.muted, fontSize: 13)),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String message;
  const EmptyState({super.key, required this.emoji, required this.title, required this.message});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Brand.muted)),
        ],
      ),
    );
  }
}

String _timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${t.month}/${t.day}/${t.year}';
}

String _dateLabel(DateTime t) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final h = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
  final m = t.minute.toString().padLeft(2, '0');
  final ampm = t.hour >= 12 ? 'PM' : 'AM';
  return '${months[t.month - 1]} ${t.day} · $h:$m $ampm';
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME FEED
// ─────────────────────────────────────────────────────────────────────────────

class HomeFeedScreen extends StatelessWidget {
  final AppState state;
  const HomeFeedScreen({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    final u = state.currentUser!;
    final pinned = state.announcements.where((a) => a.pinned).toList();
    final recent = state.announcements.where((a) => !a.pinned).toList();
    final upcoming = state.events.where((e) => e.date.isAfter(DateTime.now())).take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi, ${u.name.split(' ').first} 👋',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Row(
              children: [
                RoleBadge(role: u.role),
                const SizedBox(width: 8),
                Text(u.grade.isEmpty ? '' : 'Grade ${u.grade}',
                    style: const TextStyle(color: Brand.muted, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => state.notifyListeners(),
        child: ListView(
          children: [
            const SectionHeader(title: 'Quick access'),
            SizedBox(
              height: 96,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                children: [
                  _QuickTile(icon: Icons.schedule, label: 'Schedule', color: Brand.primary, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ScheduleScreen(state: state)));
                  }),
                  _QuickTile(icon: Icons.event, label: 'Events', color: Brand.accent, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => EventsScreen(state: state)));
                  }),
                  _QuickTile(icon: Icons.confirmation_num_outlined, label: 'My tickets', color: Brand.success, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => MyTicketsScreen(state: state)));
                  }),
                  _QuickTile(icon: Icons.apps, label: 'Resources', color: Color(0xFF7C3AED), onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ResourcesScreen(state: state)));
                  }),
                  _QuickTile(icon: Icons.contacts, label: 'Contacts', color: Color(0xFF0EA5E9), onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ContactsScreen(state: state)));
                  }),
                ],
              ),
            ),
            if (pinned.isNotEmpty) ...[
              const SectionHeader(title: 'Pinned'),
              for (final a in pinned)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _AnnouncementCard(a: a, state: state),
                ),
            ],
            const SectionHeader(title: 'Announcements'),
            if (recent.isEmpty)
              const EmptyState(emoji: '📭', title: 'No announcements yet', message: 'Posts from leadership and admin will appear here.')
            else
              for (final a in recent)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _AnnouncementCard(a: a, state: state),
                ),
            const SectionHeader(title: 'Upcoming events'),
            if (upcoming.isEmpty)
              const EmptyState(emoji: '📅', title: 'Nothing on the calendar', message: 'Check back soon!')
            else
              for (final e in upcoming)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _EventCard(event: e, state: state),
                ),
            const SectionHeader(title: 'Flyers'),
            if (state.flyers.isEmpty)
              const EmptyState(emoji: '📄', title: 'No flyers', message: 'Leadership can post flyers from the Post tab.')
            else
              SizedBox(
                height: 180,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final f in state.flyers)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _FlyerCard(f: f, state: state),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickTile({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 92,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Brand.card,
            border: Border.all(color: Brand.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement a;
  final AppState state;
  const _AnnouncementCard({required this.a, required this.state});
  @override
  Widget build(BuildContext context) {
    final u = state.currentUser!;
    final canDelete = u.role == UserRole.admin || u.id == a.authorId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (a.pinned)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.push_pin, size: 16, color: Brand.danger),
                  ),
                Expanded(
                  child: Text(a.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => state.deleteAnnouncement(a.id),
                    color: Brand.muted,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(a.body, style: const TextStyle(color: Brand.text, height: 1.4)),
            const SizedBox(height: 10),
            Row(
              children: [
                RoleBadge(role: a.authorRole),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${a.authorName} · ${_timeAgo(a.createdAt)}',
                    style: const TextStyle(color: Brand.muted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FlyerCard extends StatelessWidget {
  final Flyer f;
  final AppState state;
  const _FlyerCard({required this.f, required this.state});

  static const _palette = [
    [Color(0xFFFEF3C7), Color(0xFFFCD34D)],
    [Color(0xFFDBEAFE), Color(0xFF60A5FA)],
    [Color(0xFFFEE2E2), Color(0xFFF87171)],
    [Color(0xFFD1FAE5), Color(0xFF34D399)],
    [Color(0xFFE9D5FF), Color(0xFFA78BFA)],
  ];

  @override
  Widget build(BuildContext context) {
    final pair = _palette[f.colorSeed.abs() % _palette.length];
    final u = state.currentUser!;
    final canDelete = u.role == UserRole.admin || u.id == f.authorId;
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(f.title),
          content: Text('${f.description}\n\nPosted by ${f.authorName} · ${_timeAgo(f.createdAt)}'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      ),
      child: Container(
        width: 230,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: pair, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(f.emoji, style: const TextStyle(fontSize: 28)),
                const Spacer(),
                if (canDelete)
                  InkWell(
                    onTap: () => state.deleteFlyer(f.id),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 18, color: Brand.text),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(f.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Brand.text)),
            const SizedBox(height: 4),
            Text(f.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Brand.text, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCHEDULE
// ─────────────────────────────────────────────────────────────────────────────

class ScheduleScreen extends StatelessWidget {
  final AppState state;
  const ScheduleScreen({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    final u = state.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _editItem(context, null),
          ),
        ],
      ),
      body: u.schedule.isEmpty
          ? const EmptyState(emoji: '🗓️', title: 'No classes yet', message: 'Tap + to add your first period.')
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: u.schedule.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final s = u.schedule[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: Brand.primaryLight,
                      child: Text(s.period, style: const TextStyle(color: Brand.primary, fontWeight: FontWeight.w700)),
                    ),
                    title: Text(s.className, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${s.teacher} · Room ${s.room}\n${s.time}', style: const TextStyle(height: 1.4)),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _editItem(context, s);
                        if (v == 'delete') state.removeScheduleItem(s.id);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _editItem(BuildContext context, ScheduleItem? existing) {
    final period = TextEditingController(text: existing?.period ?? '');
    final cls = TextEditingController(text: existing?.className ?? '');
    final teacher = TextEditingController(text: existing?.teacher ?? '');
    final room = TextEditingController(text: existing?.room ?? '');
    final time = TextEditingController(text: existing?.time ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'Add class' : 'Edit class',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: period, decoration: const InputDecoration(labelText: 'Period (1, 2, ...)')),
            const SizedBox(height: 10),
            TextField(controller: cls, decoration: const InputDecoration(labelText: 'Class name')),
            const SizedBox(height: 10),
            TextField(controller: teacher, decoration: const InputDecoration(labelText: 'Teacher')),
            const SizedBox(height: 10),
            TextField(controller: room, decoration: const InputDecoration(labelText: 'Room')),
            const SizedBox(height: 10),
            TextField(controller: time, decoration: const InputDecoration(labelText: 'Time (e.g. 8:00 – 8:50)')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (cls.text.trim().isEmpty || period.text.trim().isEmpty) return;
                state.upsertScheduleItem(ScheduleItem(
                  id: existing?.id ?? _newId(),
                  period: period.text.trim(),
                  className: cls.text.trim(),
                  teacher: teacher.text.trim(),
                  room: room.text.trim(),
                  time: time.text.trim(),
                ));
                Navigator.pop(ctx);
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EVENTS + TICKETS
// ─────────────────────────────────────────────────────────────────────────────

class EventsScreen extends StatelessWidget {
  final AppState state;
  const EventsScreen({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    final u = state.currentUser!;
    final canCreate = u.role == UserRole.leadership || u.role == UserRole.admin;
    final upcoming = state.events.where((e) => e.date.isAfter(DateTime.now())).toList()..sort((a,b)=>a.date.compareTo(b.date));
    final past = state.events.where((e) => !e.date.isAfter(DateTime.now())).toList()..sort((a,b)=>b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.confirmation_num_outlined),
            tooltip: 'My tickets',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MyTicketsScreen(state: state)),
            ),
          ),
          if (canCreate)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _createEvent(context),
            ),
        ],
      ),
      body: ListView(
        children: [
          const SectionHeader(title: 'Upcoming'),
          if (upcoming.isEmpty)
            const EmptyState(emoji: '📅', title: 'Nothing upcoming', message: 'Check back soon.')
          else
            for (final e in upcoming)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _EventCard(event: e, state: state),
              ),
          if (past.isNotEmpty) ...[
            const SectionHeader(title: 'Past'),
            for (final e in past)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _EventCard(event: e, state: state, past: true),
              ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _createEvent(BuildContext context) {
    final title = TextEditingController();
    final desc = TextEditingController();
    final location = TextEditingController();
    final price = TextEditingController(text: '0');
    final qty = TextEditingController(text: '100');
    DateTime date = DateTime.now().add(const Duration(days: 1));
    bool ticketed = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('New event', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 10),
                TextField(controller: desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 10),
                TextField(controller: location, decoration: const InputDecoration(labelText: 'Location')),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date & time: ${_dateLabel(date)}'),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d == null) return;
                    final t = await showTimePicker(
                      // ignore: use_build_context_synchronously
                      context: ctx, initialTime: TimeOfDay.fromDateTime(date),
                    );
                    setSt(() => date = DateTime(d.year, d.month, d.day, t?.hour ?? 19, t?.minute ?? 0));
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ticketed event'),
                  value: ticketed,
                  onChanged: (v) => setSt(() => ticketed = v),
                ),
                if (ticketed) ...[
                  TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ticket price (\$)')),
                  const SizedBox(height: 10),
                  TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tickets available')),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (title.text.trim().isEmpty) return;
                    state.createEvent(Event(
                      id: _newId(),
                      title: title.text.trim(),
                      description: desc.text.trim(),
                      date: date,
                      location: location.text.trim(),
                      ticketed: ticketed,
                      ticketPrice: double.tryParse(price.text) ?? 0,
                      ticketsAvailable: int.tryParse(qty.text) ?? 0,
                    ));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Create event'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final AppState state;
  final bool past;
  const _EventCard({required this.event, required this.state, this.past = false});
  @override
  Widget build(BuildContext context) {
    final u = state.currentUser!;
    final hasTicket = state.tickets.any((t) => t.eventId == event.id && t.userId == u.id);
    final soldOut = event.ticketed && event.ticketsSold >= event.ticketsAvailable;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: past ? Brand.border : Brand.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_monthAbbr(event.date.month),
                            style: TextStyle(color: past ? Brand.muted : Brand.primary, fontSize: 10, fontWeight: FontWeight.w700)),
                        Text(event.date.day.toString(),
                            style: TextStyle(color: past ? Brand.muted : Brand.primary, fontSize: 18, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${_dateLabel(event.date)} · ${event.location}',
                          style: const TextStyle(color: Brand.muted, fontSize: 12)),
                    ],
                  ),
                ),
                if (u.role == UserRole.admin)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Brand.muted),
                    onPressed: () => state.deleteEvent(event.id),
                  ),
              ],
            ),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(event.description, style: const TextStyle(height: 1.4)),
            ],
            if (event.ticketed) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('\$${event.ticketPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.success, fontSize: 16)),
                  const SizedBox(width: 8),
                  Text('${event.ticketsAvailable - event.ticketsSold} left',
                      style: const TextStyle(color: Brand.muted, fontSize: 12)),
                  const Spacer(),
                  if (past)
                    const Text('Ended', style: TextStyle(color: Brand.muted, fontWeight: FontWeight.w600))
                  else if (hasTicket)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Brand.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 16, color: Brand.success),
                          SizedBox(width: 4),
                          Text('Got ticket', style: TextStyle(color: Brand.success, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: soldOut
                          ? null
                          : () {
                              final err = state.buyTicket(event.id);
                              if (err != null) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket purchased! See My tickets.')));
                              }
                            },
                      child: Text(soldOut ? 'Sold out' : 'Buy ticket'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _monthAbbr(int m) =>
      const ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'][m - 1];
}

class MyTicketsScreen extends StatelessWidget {
  final AppState state;
  const MyTicketsScreen({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    final u = state.currentUser!;
    final mine = state.tickets.where((t) => t.userId == u.id).toList()
      ..sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));
    return Scaffold(
      appBar: AppBar(title: const Text('My tickets')),
      body: mine.isEmpty
          ? const EmptyState(emoji: '🎟️', title: 'No tickets yet', message: 'Buy tickets from the Events tab.')
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: mine.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final t = mine[i];
                final e = state.events.cast<Event?>().firstWhere((ev) => ev!.id == t.eventId, orElse: () => null);
                if (e == null) return const SizedBox.shrink();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_num, size: 36, color: Brand.success),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(_dateLabel(e.date), style: const TextStyle(color: Brand.muted, fontSize: 12)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Brand.primaryLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(t.code,
                                    style: const TextStyle(fontFamily: 'monospace', color: Brand.primary, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESOURCES
// ─────────────────────────────────────────────────────────────────────────────

class ResourcesScreen extends StatelessWidget {
  final AppState state;
  const ResourcesScreen({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    final u = state.currentUser!;
    final canPost = u.role == UserRole.leadership || u.role == UserRole.admin;
    final byCategory = <String, List<ResourceLink>>{};
    for (final r in state.resources) {
      byCategory.putIfAbsent(r.category, () => []).add(r);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resources'),
        actions: [
          if (canPost)
            IconButton(
              icon: const Icon(Icons.add_link),
              onPressed: () => _addResource(context),
            ),
        ],
      ),
      body: state.resources.isEmpty
          ? const EmptyState(emoji: '🔗', title: 'No resources yet', message: 'Leadership or admin can add quick links to Classroom, Clever, library, and more.')
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final entry in byCategory.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                    child: Text(entry.key,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Brand.muted)),
                  ),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    children: [
                      for (final r in entry.value)
                        _ResourceTile(r: r, state: state),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }

  void _addResource(BuildContext context) {
    final title = TextEditingController();
    final url = TextEditingController();
    final desc = TextEditingController();
    String category = 'Classroom';
    const cats = ['Classroom', 'Clever', 'Library', 'Sports', 'Other'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add resource link', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 10),
              TextField(controller: url, decoration: const InputDecoration(labelText: 'URL (https://...)')),
              const SizedBox(height: 10),
              TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description (optional)')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [for (final c in cats) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setSt(() => category = v ?? 'Other'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (title.text.trim().isEmpty || url.text.trim().isEmpty) return;
                  state.postResource(title.text.trim(), url.text.trim(), category, desc.text.trim());
                  Navigator.pop(ctx);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  final ResourceLink r;
  final AppState state;
  const _ResourceTile({required this.r, required this.state});

  IconData _icon() {
    switch (r.category) {
      case 'Classroom': return Icons.school_outlined;
      case 'Clever': return Icons.dashboard_outlined;
      case 'Library': return Icons.menu_book_outlined;
      case 'Sports': return Icons.sports_basketball_outlined;
      default: return Icons.link;
    }
  }

  Color _color() {
    switch (r.category) {
      case 'Classroom': return Brand.primary;
      case 'Clever': return const Color(0xFF7C3AED);
      case 'Library': return const Color(0xFF0EA5E9);
      case 'Sports': return Brand.accent;
      default: return Brand.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = state.currentUser!;
    final canDelete = u.role == UserRole.admin || u.id == r.authorId;
    return InkWell(
      onTap: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(r.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.description.isNotEmpty) Text(r.description),
              const SizedBox(height: 8),
              SelectableText(r.url, style: const TextStyle(color: Brand.primary)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: r.url));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
              },
              child: const Text('Copy link'),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Brand.card,
          border: Border.all(color: Brand.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _color().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon(), color: _color(), size: 20),
                ),
                const Spacer(),
                if (canDelete)
                  InkWell(
                    onTap: () => state.deleteResource(r.id),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.close, size: 16, color: Brand.muted),
                    ),
                  ),
              ],
            ),
            Text(r.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTACTS
// ─────────────────────────────────────────────────────────────────────────────

class ContactsScreen extends StatelessWidget {
  final AppState state;
  const ContactsScreen({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    final u = state.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Important contacts'),
        actions: [
          if (u.role == UserRole.admin)
            IconButton(icon: const Icon(Icons.add), onPressed: () => _editContact(context, null)),
        ],
      ),
      body: state.contacts.isEmpty
          ? const EmptyState(emoji: '☎️', title: 'No contacts', message: 'Admin can add staff and important contacts.')
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: state.contacts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final c = state.contacts[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: Brand.primaryLight,
                      child: Text(c.name.isNotEmpty ? c.name[0] : '?',
                          style: const TextStyle(color: Brand.primary, fontWeight: FontWeight.w700)),
                    ),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${c.title} · ${c.department}\n${c.email} · ${c.phone}',
                        style: const TextStyle(height: 1.4)),
                    isThreeLine: true,
                    trailing: u.role == UserRole.admin
                        ? PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _editContact(context, c);
                              if (v == 'delete') state.deleteContact(c.id);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          )
                        : IconButton(
                            icon: const Icon(Icons.copy, size: 18, color: Brand.muted),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: c.email));
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Email copied')));
                            },
                          ),
                  ),
                );
              },
            ),
    );
  }

  void _editContact(BuildContext context, Contact? existing) {
    final name = TextEditingController(text: existing?.name ?? '');
    final title = TextEditingController(text: existing?.title ?? '');
    final email = TextEditingController(text: existing?.email ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final dept = TextEditingController(text: existing?.department ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing == null ? 'New contact' : 'Edit contact',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 10),
            TextField(controller: dept, decoration: const InputDecoration(labelText: 'Department')),
            const SizedBox(height: 10),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 10),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                state.upsertContact(Contact(
                  id: existing?.id ?? _newId(),
                  name: name.text.trim(),
                  title: title.text.trim(),
                  email: email.text.trim(),
                  phone: phone.text.trim(),
                  department: dept.text.trim(),
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  final AppState state;
  const ProfileScreen({super.key, required this.state});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late final TextEditingController _grade;
  late String _avatar;

  static const _avatars = ['🙂','😎','🤓','🏃','🎤','🎨','⚽','🎸','📚','🤖','🦄','🐱','🐶','👔','🧑‍🎓'];

  @override
  void initState() {
    super.initState();
    final u = widget.state.currentUser!;
    _name = TextEditingController(text: u.name);
    _bio = TextEditingController(text: u.bio);
    _grade = TextEditingController(text: u.grade);
    _avatar = u.avatarEmoji;
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _grade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.state.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => widget.state.signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Brand.primaryLight,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(child: Text(_avatar, style: const TextStyle(fontSize: 48))),
                ),
                const SizedBox(height: 8),
                RoleBadge(role: u.role),
                const SizedBox(height: 4),
                Text(u.email, style: const TextStyle(color: Brand.muted)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Avatar', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final a in _avatars)
                ChoiceChip(
                  label: Text(a, style: const TextStyle(fontSize: 20)),
                  selected: _avatar == a,
                  onSelected: (_) => setState(() => _avatar = a),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Display name')),
          const SizedBox(height: 10),
          TextField(controller: _grade, decoration: const InputDecoration(labelText: 'Grade')),
          const SizedBox(height: 10),
          TextField(
            controller: _bio,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Bio', hintText: 'Tell others about yourself'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              widget.state.updateProfile(
                name: _name.text.trim(),
                bio: _bio.text.trim(),
                grade: _grade.text.trim(),
                avatarEmoji: _avatar,
              );
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
            },
            child: const Text('Save profile'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEADERSHIP: POST
// ─────────────────────────────────────────────────────────────────────────────

class LeadershipPostScreen extends StatelessWidget {
  final AppState state;
  const LeadershipPostScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.campaign_outlined), text: 'Announce'),
              Tab(icon: Icon(Icons.image_outlined), text: 'Flyer'),
              Tab(icon: Icon(Icons.link), text: 'Link'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AnnouncementForm(state: state),
            _FlyerForm(state: state),
            _ResourceForm(state: state),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementForm extends StatefulWidget {
  final AppState state;
  const _AnnouncementForm({required this.state});
  @override
  State<_AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends State<_AnnouncementForm> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _pin = false;
  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.state.currentUser!.role == UserRole.admin;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
        const SizedBox(height: 10),
        TextField(controller: _body, maxLines: 6, decoration: const InputDecoration(labelText: 'Message')),
        if (isAdmin) ...[
          const SizedBox(height: 4),
          SwitchListTile(
            value: _pin,
            onChanged: (v) => setState(() => _pin = v),
            contentPadding: EdgeInsets.zero,
            title: const Text('Pin to top'),
            subtitle: const Text('Pinned posts stay above everything else.'),
          ),
        ],
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.send),
          label: const Text('Post announcement'),
          onPressed: () {
            if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
            widget.state.postAnnouncement(_title.text.trim(), _body.text.trim(), pinned: _pin);
            _title.clear();
            _body.clear();
            setState(() => _pin = false);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posted!')));
          },
        ),
      ],
    );
  }
}

class _FlyerForm extends StatefulWidget {
  final AppState state;
  const _FlyerForm({required this.state});
  @override
  State<_FlyerForm> createState() => _FlyerFormState();
}

class _FlyerFormState extends State<_FlyerForm> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _emoji = '📣';
  int _color = 0;
  static const _emojis = ['📣','🎉','🏈','🎭','🎨','🩸','🍕','📚','🏆','🎤'];
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Flyer title')),
        const SizedBox(height: 10),
        TextField(controller: _desc, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
        const SizedBox(height: 14),
        const Text('Icon', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final e in _emojis)
              ChoiceChip(
                label: Text(e, style: const TextStyle(fontSize: 22)),
                selected: _emoji == e,
                onSelected: (_) => setState(() => _emoji = e),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const Text('Color', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < _FlyerCard._palette.length; i++)
              GestureDetector(
                onTap: () => setState(() => _color = i),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _FlyerCard._palette[i]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _color == i ? Brand.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.send),
          label: const Text('Post flyer'),
          onPressed: () {
            if (_title.text.trim().isEmpty) return;
            widget.state.postFlyer(_title.text.trim(), _desc.text.trim(), _emoji, _color);
            _title.clear();
            _desc.clear();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Flyer posted!')));
          },
        ),
      ],
    );
  }
}

class _ResourceForm extends StatefulWidget {
  final AppState state;
  const _ResourceForm({required this.state});
  @override
  State<_ResourceForm> createState() => _ResourceFormState();
}

class _ResourceFormState extends State<_ResourceForm> {
  final _title = TextEditingController();
  final _url = TextEditingController();
  final _desc = TextEditingController();
  String _category = 'Classroom';
  static const _cats = ['Classroom', 'Clever', 'Library', 'Sports', 'Other'];
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
        const SizedBox(height: 10),
        TextField(controller: _url, decoration: const InputDecoration(labelText: 'URL (https://...)')),
        const SizedBox(height: 10),
        TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [for (final c in _cats) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() => _category = v ?? 'Other'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.send),
          label: const Text('Post link'),
          onPressed: () {
            if (_title.text.trim().isEmpty || _url.text.trim().isEmpty) return;
            widget.state.postResource(_title.text.trim(), _url.text.trim(), _category, _desc.text.trim());
            _title.clear();
            _url.clear();
            _desc.clear();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resource posted!')));
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────

class AdminDashboard extends StatelessWidget {
  final AppState state;
  const AdminDashboard({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people_outline), text: 'Users'),
              Tab(icon: Icon(Icons.insights_outlined), text: 'Overview'),
              Tab(icon: Icon(Icons.history), text: 'Audit'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UsersTab(state: state),
            _OverviewTab(state: state),
            _AuditTab(state: state),
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  final AppState state;
  const _UsersTab({required this.state});
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _filter = '';
  @override
  Widget build(BuildContext context) {
    final me = widget.state.currentUser!;
    final list = widget.state.users
        .where((u) =>
            _filter.isEmpty ||
            u.name.toLowerCase().contains(_filter.toLowerCase()) ||
            u.email.toLowerCase().contains(_filter.toLowerCase()))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search users',
            ),
            onChanged: (v) => setState(() => _filter = v),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final u = list[i];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor: Brand.roleColor(u.role).withValues(alpha: 0.15),
                    child: Text(u.avatarEmoji, style: const TextStyle(fontSize: 18)),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(u.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              decoration: u.disabled ? TextDecoration.lineThrough : null,
                              color: u.disabled ? Brand.muted : Brand.text,
                            )),
                      ),
                      RoleBadge(role: u.role),
                    ],
                  ),
                  subtitle: Text('${u.email}${u.grade.isEmpty ? '' : ' · Grade ${u.grade}'}'),
                  trailing: u.id == me.id
                      ? const Chip(
                          label: Text('You'),
                          backgroundColor: Brand.primaryLight,
                          labelStyle: TextStyle(color: Brand.primary, fontWeight: FontWeight.w700),
                        )
                      : PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'disable') widget.state.setUserDisabled(u.id, !u.disabled);
                            if (v == 'student') widget.state.setUserRole(u.id, UserRole.student);
                            if (v == 'leadership') widget.state.setUserRole(u.id, UserRole.leadership);
                            if (v == 'admin') widget.state.setUserRole(u.id, UserRole.admin);
                            if (v == 'delete') {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Delete user?'),
                                  content: Text('This permanently removes ${u.name}.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                    TextButton(
                                      onPressed: () {
                                        widget.state.deleteUser(u.id);
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Delete', style: TextStyle(color: Brand.danger)),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'disable', child: Text(u.disabled ? 'Re-enable access' : 'Disable access')),
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'student', child: Text('Set role: Student')),
                            const PopupMenuItem(value: 'leadership', child: Text('Set role: Leadership')),
                            const PopupMenuItem(value: 'admin', child: Text('Set role: Admin')),
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'delete', child: Text('Delete user')),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final AppState state;
  const _OverviewTab({required this.state});
  @override
  Widget build(BuildContext context) {
    final totalUsers = state.users.length;
    final students = state.users.where((u) => u.role == UserRole.student).length;
    final leaders = state.users.where((u) => u.role == UserRole.leadership).length;
    final admins = state.users.where((u) => u.role == UserRole.admin).length;
    final disabled = state.users.where((u) => u.disabled).length;
    final revenue = state.tickets.fold<double>(0, (sum, t) {
      final e = state.events.cast<Event?>().firstWhere((ev) => ev!.id == t.eventId, orElse: () => null);
      return sum + (e?.ticketPrice ?? 0);
    });

    Widget stat(String label, String value, IconData icon, Color color) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Brand.muted, fontSize: 12)),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        stat('Total users', '$totalUsers', Icons.people, Brand.primary),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: stat('Students', '$students', Icons.school, Brand.primary)),
          const SizedBox(width: 10),
          Expanded(child: stat('Leaders', '$leaders', Icons.star, Brand.accent)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: stat('Admins', '$admins', Icons.shield, Brand.danger)),
          const SizedBox(width: 10),
          Expanded(child: stat('Disabled', '$disabled', Icons.block, Brand.muted)),
        ]),
        const SizedBox(height: 10),
        stat('Announcements', '${state.announcements.length}', Icons.campaign, Brand.primary),
        const SizedBox(height: 10),
        stat('Events', '${state.events.length}', Icons.event, Brand.accent),
        const SizedBox(height: 10),
        stat('Tickets sold', '${state.tickets.length}', Icons.confirmation_num, Brand.success),
        const SizedBox(height: 10),
        stat('Ticket revenue', '\$${revenue.toStringAsFixed(2)}', Icons.attach_money, Brand.success),
      ],
    );
  }
}

class _AuditTab extends StatelessWidget {
  final AppState state;
  const _AuditTab({required this.state});
  @override
  Widget build(BuildContext context) {
    if (state.audit.isEmpty) {
      return const EmptyState(emoji: '📜', title: 'No activity yet', message: 'User actions show up here.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.audit.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Brand.border),
      itemBuilder: (_, i) {
        final a = state.audit[i];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.circle, size: 8, color: Brand.muted),
          title: Text(a.action, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${a.actorName} · ${_timeAgo(a.timestamp)}',
              style: const TextStyle(color: Brand.muted, fontSize: 12)),
        );
      },
    );
  }
}
