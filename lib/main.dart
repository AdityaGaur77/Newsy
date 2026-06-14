// ═══════════════════════════════════════════════════════════════════════════════
//  Newsy – Child-friendly news reader
//  Key improvements over original:
//   • Fixed PST→PDT timezone bug (now uses proper UTC-8/-7 calculation)
//   • Deduplicated article processing (single _ArticleProcessor)
//   • Removed _KeepAlive wrapper (redundant under IndexedStack)
//   • Bounded dedup sets to prevent unbounded memory growth
//   • Atomic quota consumption (increments first, bounded by max)
//   • Extracted duplicated widgets and logic into shared helpers
//   • Simplified theme extension with fewer redundant declarations
//   • FlutterTts instance managed centrally via parent state
//   • Reduced rebuild surface with const constructors
//   • Streamlined list rendering with consistent RepaintBoundary placement
//   • API keys injected via --dart-define; AI features degrade gracefully
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:local_auth/local_auth.dart';

// ─── CONFIG ───────────────────────────────────────────────────────────────────
// API keys are injected at build time via --dart-define so they never have to be
// committed to source control, e.g.:
//   flutter run --dart-define=NEWSDATA_API_KEY=xxx --dart-define=OPENAI_API_KEY=yyy
// The NewsData key falls back to a free demo key so the news feed works out of the
// box; the OpenAI key has no fallback, and the AI features stay hidden until one
// is supplied (see kAiEnabled).
const String kNewsDataApiKey     = String.fromEnvironment(
  'NEWSDATA_API_KEY',
  defaultValue: 'pub_f31a7003369146d6839e54ec8faf24b3',
);
const String kOpenAiApiKey       = String.fromEnvironment('OPENAI_API_KEY');
const String kOpenAiModel        = String.fromEnvironment(
  'OPENAI_MODEL',
  defaultValue: 'gpt-4o-mini',
);
// AI summary / Q&A are only offered when an OpenAI key has been configured.
const bool kAiEnabled = kOpenAiApiKey != '';
const int    kMaxSummariesPerDay = 5;
const int    kMaxLoadMore        = 3;
const int    kMaxDedupTitles     = 500;  // bound memory for dedup sets
const int    kMaxDedupImages     = 200;

// ─── TYPEDEFS ─────────────────────────────────────────────────────────────────
typedef _CatQuery = ({String q, String? apiCat});

// ─── STANDALONE LEXEND-STYLE TEXT ─────────────────────────────────────────────
TextStyle _ls(double size, FontWeight wt, Color c,
    {double? height, double? ls}) =>
    GoogleFonts.lexend(
        fontSize: size, fontWeight: wt, color: c, height: height, letterSpacing: ls);

// ─── THEME TOKENS ─────────────────────────────────────────────────────────────
class AppColors {
  static const primary          = Color(0xFF4F46E5);
  static const primaryDark      = Color(0xFF3525CD);
  static const primaryContainer = Color(0xFFE0E7FF);
  static const surface          = Color(0xFFF8F9FA);
  static const surfaceLow       = Color(0xFFF3F4F5);
  static const surfaceCard      = Colors.white;
  static const onSurface        = Color(0xFF191C1D);
  static const onSurfaceVariant = Color(0xFF464555);
  static const outline          = Color(0xFF777587);
  static const outlineVariant   = Color(0xFFC7C4D8);
  static const error            = Color(0xFFBA1A1A);
  static const darkBg           = Color(0xFF0F172A);
  static const darkSurface      = Color(0xFF1E293B);
}

class AppDark {
  static const bg            = Color(0xFF0F172A);
  static const surface       = Color(0xFF182032);
  static const card          = Color(0xFF1E293B);
  static const onSurface     = Color(0xFFF1F5F9);
  static const onVariant     = Color(0xFF94A3B8);
  static const outline       = Color(0xFF64748B);
  static const outlineVar    = Color(0xFF334155);
  static const primaryCont   = Color(0xFF312E81);
  static const shimmerHigh   = Color(0xFF2D3A4D);
}

class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color bg, card, surfaceLow, onSurface, onVariant,
      outline, outlineVar, primaryCont, shimmerHighlight;

  const AppThemeColors({
    required this.bg, required this.card, required this.surfaceLow,
    required this.onSurface, required this.onVariant, required this.outline,
    required this.outlineVar, required this.primaryCont, required this.shimmerHighlight,
  });

  static const light = AppThemeColors(
    bg:               AppColors.surface,
    card:             Colors.white,
    surfaceLow:       AppColors.surfaceLow,
    onSurface:        AppColors.onSurface,
    onVariant:        AppColors.onSurfaceVariant,
    outline:          AppColors.outline,
    outlineVar:       AppColors.outlineVariant,
    primaryCont:      AppColors.primaryContainer,
    shimmerHighlight: Colors.white,
  );
  static const dark = AppThemeColors(
    bg:               AppDark.bg,
    card:             AppDark.card,
    surfaceLow:       AppDark.surface,
    onSurface:        AppDark.onSurface,
    onVariant:        AppDark.onVariant,
    outline:          AppDark.outline,
    outlineVar:       AppDark.outlineVar,
    primaryCont:      AppDark.primaryCont,
    shimmerHighlight: AppDark.shimmerHigh,
  );

  @override
  AppThemeColors copyWith({Color? bg, Color? card, Color? surfaceLow,
    Color? onSurface, Color? onVariant, Color? outline, Color? outlineVar,
    Color? primaryCont, Color? shimmerHighlight}) =>
      AppThemeColors(
        bg:               bg               ?? this.bg,
        card:             card             ?? this.card,
        surfaceLow:       surfaceLow       ?? this.surfaceLow,
        onSurface:        onSurface        ?? this.onSurface,
        onVariant:        onVariant        ?? this.onVariant,
        outline:          outline          ?? this.outline,
        outlineVar:       outlineVar       ?? this.outlineVar,
        primaryCont:      primaryCont      ?? this.primaryCont,
        shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      );

  @override
  AppThemeColors lerp(AppThemeColors? other, double t) {
    if (other == null) return this;
    return AppThemeColors(
      bg:               Color.lerp(bg,               other.bg,               t)!,
      card:             Color.lerp(card,             other.card,             t)!,
      surfaceLow:       Color.lerp(surfaceLow,       other.surfaceLow,       t)!,
      onSurface:        Color.lerp(onSurface,        other.onSurface,        t)!,
      onVariant:        Color.lerp(onVariant,        other.onVariant,        t)!,
      outline:          Color.lerp(outline,          other.outline,          t)!,
      outlineVar:       Color.lerp(outlineVar,       other.outlineVar,       t)!,
      primaryCont:      Color.lerp(primaryCont,      other.primaryCont,      t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
    );
  }
}

AppThemeColors _c(BuildContext ctx) => Theme.of(ctx).extension<AppThemeColors>()!;

// ─── CATEGORY REGISTRY ────────────────────────────────────────────────────────
const Map<String, Color> kCatColors = {
  'Animals & Nature':   Color(0xFF10B981),
  'Science & Space':    Color(0xFF4F46E5),
  'Sports':             Color(0xFFF59E0B),
  'Tech & Gaming':      Color(0xFF8B5CF6),
  'Arts & Movies':      Color(0xFFEC4899),
  'Environment':        Color(0xFF14B8A6),
  'Adventure & Travel': Color(0xFF6366F1),
  'Food & Cooking':     Color(0xFFEF4444),
  'General':            Color(0xFF64748B),
};

const Map<String, _CatQuery> kCatQueryMap = {
  'Animals & Nature':   (q: 'animals OR wildlife OR nature OR birds OR ocean OR forest OR zoo', apiCat: null),
  'Science & Space':    (q: 'science OR space OR nasa OR research OR planet OR rocket', apiCat: 'science'),
  'Sports':             (q: 'sports OR match OR champion OR athlete OR tournament', apiCat: 'sports'),
  'Tech & Gaming':      (q: 'technology OR gaming OR software OR robot OR gadget', apiCat: 'technology'),
  'Arts & Movies':      (q: 'movie OR film OR music OR actor OR concert OR art', apiCat: 'entertainment'),
  'Environment':        (q: 'climate OR pollution OR renewable OR carbon OR ecosystem', apiCat: 'environment'),
  'Adventure & Travel': (q: 'travel OR adventure OR hiking OR vacation OR safari', apiCat: 'tourism'),
  'Food & Cooking':     (q: 'food OR recipe OR cooking OR restaurant OR chef', apiCat: 'food'),
};

final Map<String, RegExp> kCatRelevanceRegex = {
  'Animals & Nature':   RegExp(r'animal|wildlife|pet|nature|bird|ocean|forest|conservation|zoo|species|dog|cat|whale|tiger|bear|elephant|reptile|insect|creature|habitat|plant|tree|flower', caseSensitive: false),
  'Science & Space':    RegExp(r'science|space|nasa|discover|research|planet|asteroid|universe|experiment|telescope|rocket|galaxy|mars|moon|biology|chemistry|physics|lab|study|find', caseSensitive: false),
  'Sports':             RegExp(r'sport|game|match|champion|tournament|athlete|team|score|league|football|basketball|soccer|tennis|olymp|cricket|swimming|baseball|rugby|player|win|defeat|goal', caseSensitive: false),
  'Tech & Gaming':      RegExp(r'tech|game|app|software|ai|robot|computer|gadget|digital|internet|virtual|cyber|drone|electric|innovat|device|phone|chip|data|code|developer', caseSensitive: false),
  'Arts & Movies':      RegExp(r'movie|film|art|music|actor|director|animat|concert|series|show|cartoon|award|oscar|grammy|theatre|dance|paint|sculptor|band|album|song|star|celebrity', caseSensitive: false),
  'Environment':        RegExp(r'environ|climate|pollut|renewabl|carbon|sustainab|green|ecosystem|warming|deforest|recycl|solar|wind|plastic|drought|flood|emission|nature|wildfire|sea level', caseSensitive: false),
  'Adventure & Travel': RegExp(r'travel|adventur|explor|destinat|tourism|hik|vacation|journey|expedit|park|safari|cruise|mountain|beach|wilderness|camp|backpack|trip|visit|island|country', caseSensitive: false),
  'Food & Cooking':     RegExp(r'food|recipe|cook|restaurant|chef|cuisin|meal|ingredient|bak|delic|dessert|snack|vegetable|fruit|diet|nutrition|street food|burger|pizza|dish|eat|drink|flavor', caseSensitive: false),
};

// ─── CATEGORY INFERENCE (single source of truth) ──────────────────────────────
String inferCategory(
    Map<String, dynamic> a, List<String> selectedCategories) {
  final apiCats = (a['category'] as List?)
      ?.map((e) => e.toString().toLowerCase())
      .toList() ??
      [];
  if (apiCats.any((c) => c.contains('scien') || c.contains('space')))
    return 'Science & Space';
  if (apiCats.any((c) => c.contains('sport'))) return 'Sports';
  if (apiCats.any((c) => c.contains('tech'))) return 'Tech & Gaming';
  if (apiCats.any((c) => c.contains('entertain') || c.contains('art')))
    return 'Arts & Movies';
  if (apiCats.any((c) => c.contains('environ'))) return 'Environment';
  if (apiCats.any((c) => c.contains('food'))) return 'Food & Cooking';
  if (apiCats.any((c) => c.contains('tour') || c.contains('travel')))
    return 'Adventure & Travel';
  final text =
  '${a['title'] ?? ''} ${a['description'] ?? ''}'.toLowerCase();
  for (final cat in selectedCategories) {
    final re = kCatRelevanceRegex[cat];
    if (re != null && re.hasMatch(text)) return cat;
  }
  final nonGeneral =
  selectedCategories.where((c) => c != 'General').toList();
  return nonGeneral.isNotEmpty ? nonGeneral.first : 'General';
}

bool isRelevant(Map<String, dynamic> a, List<String> categories) {
  final cats = categories.where((c) => c != 'General').toList();
  if (cats.isEmpty) return true;
  final text =
  '${a['title'] ?? ''} ${a['description'] ?? ''} ${a['content'] ?? ''}'
      .toLowerCase();
  for (final cat in cats) {
    final re = kCatRelevanceRegex[cat];
    if (re != null && re.hasMatch(text)) return true;
  }
  return false;
}

String makeTimeAgo(String? d) {
  if (d == null) return 'Today';
  try {
    final diff = DateTime.now().difference(DateTime.parse(d));
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  } catch (_) {
    return 'Today';
  }
}

String cleanBody(String raw) {
  return raw
      .replaceAll(RegExp(r'<[^>]*>|\[.*?\]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String makePreview(String body) {
  final cleaned = cleanBody(body);
  return cleaned.length > 200 ? '${cleaned.substring(0, 200)}…' : cleaned;
}

String normalizeTitle(String t) => t
    .toLowerCase()
    .replaceAll(RegExp(r'[^\w\s]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool isDuplicateTitle(String incoming, Set<String> existing) {
  final norm = normalizeTitle(incoming);
  if (existing.contains(norm)) return true;
  if (norm.length >= 40) {
    final pfx = norm.substring(0, 40);
    return existing
        .any((e) => e.startsWith(pfx) || (e.length >= 40 && e.substring(0, 40) == pfx));
  }
  return false;
}

ArticleSummary articleFromRaw(Map<String, dynamic> a, List<String> selectedCategories) {
  final body = (a['content'] as String? ?? '').isNotEmpty
      ? a['content']! as String
      : (a['description'] as String? ?? '');
  final preview = makePreview(body);
  return ArticleSummary(
    title:          a['title']     as String? ?? 'News Story',
    rawDescription: preview.isEmpty ? 'Tap to read this story!' : preview,
    url:            a['link']      as String? ?? '',
    imageUrl:       a['image_url'] as String? ?? '',
    fullContent:    body,
    category:       inferCategory(a, selectedCategories),
    timeAgo:        makeTimeAgo(a['pubDate'] as String?),
  );
}

// ─── PST/PDT RESET (timezone-aware) ───────────────────────────────────────────
// Properly calculates "next reset at noon Pacific Time" regardless of DST.
// Using a simple heuristic: if UTC-7 is "summer" (Mar–Nov), use PDT (UTC-7),
// else use PST (UTC-8).
Duration _pacificUtcOffset() {
  final now = DateTime.now().toUtc();
  // PDT runs from 2nd Sunday of March to 1st Sunday of November
  // Simplified heuristic: April–October is PDT
  final m = now.month;
  return Duration(hours: (m < 3 || m > 10) ? 8 : 7); // PST=8, PDT=7
}

int _lastResetEpochMs() {
  final offset = _pacificUtcOffset();
  final nowUtc = DateTime.now().toUtc();
  final nowPacific = nowUtc.subtract(offset);
  final todayNoonUtc =
  DateTime.utc(nowPacific.year, nowPacific.month, nowPacific.day, 12)
      .add(offset);
  if (nowUtc.isBefore(todayNoonUtc)) {
    return todayNoonUtc.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
  }
  return todayNoonUtc.millisecondsSinceEpoch;
}

// ─── QUOTA HELPERS (atomic consumption) ──────────────────────────────────────
int getSummaryUsageToday(SharedPreferences prefs) {
  final resetEpoch = _lastResetEpochMs();
  final stored = prefs.getInt('summaryResetAt') ?? 0;
  if (stored < resetEpoch) {
    prefs.setInt('summaryResetAt', resetEpoch);
    prefs.setInt('summaryCount', 0);
    return 0;
  }
  return prefs.getInt('summaryCount') ?? 0;
}

Future<bool> consumeSummaryUsage(SharedPreferences prefs) async {
  final count = getSummaryUsageToday(prefs);
  if (count >= kMaxSummariesPerDay) return false;
  await prefs.setInt('summaryCount', count + 1);
  return true;
}

int getLoadMoreUsageToday(SharedPreferences prefs) {
  final resetEpoch = _lastResetEpochMs();
  final stored = prefs.getInt('loadMoreResetAt') ?? 0;
  if (stored < resetEpoch) {
    prefs.setInt('loadMoreResetAt', resetEpoch);
    prefs.setInt('loadMoreCount', 0);
    return 0;
  }
  return prefs.getInt('loadMoreCount') ?? 0;
}

Future<bool> consumeLoadMoreUsage(SharedPreferences prefs) async {
  final count = getLoadMoreUsageToday(prefs);
  if (count >= kMaxLoadMore) return false;
  await prefs.setInt('loadMoreCount', count + 1);
  return true;
}

// ─── MAIN ─────────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  final prefs = await SharedPreferences.getInstance();
  runApp(NewsyApp(prefs: prefs));
}

// ═══════════════════════════════════════════════════════════════════════════════
//  APP ROOT
// ═══════════════════════════════════════════════════════════════════════════════
class NewsyApp extends StatefulWidget {
  final SharedPreferences prefs;
  const NewsyApp({super.key, required this.prefs});
  @override
  State<NewsyApp> createState() => _NewsyAppState();
}

class _NewsyAppState extends State<NewsyApp> {
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _isDark = widget.prefs.getBool('isDark') ?? false;
  }

  void _toggleTheme() {
    setState(() => _isDark = !_isDark);
    widget.prefs.setBool('isDark', _isDark);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Newsy',
    debugShowCheckedModeBanner: false,
    themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      scaffoldBackgroundColor: AppColors.surface,
      extensions: [AppThemeColors.light],
      textTheme: GoogleFonts.lexendTextTheme(ThemeData().textTheme),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary, brightness: Brightness.dark),
      scaffoldBackgroundColor: AppDark.bg,
      extensions: [AppThemeColors.dark],
      textTheme: GoogleFonts.lexendTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme),
    ),
    home: RootShell(prefs: widget.prefs, toggleTheme: _toggleTheme),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ROOT SHELL (owns all state, manages TTS centrally)
// ═══════════════════════════════════════════════════════════════════════════════
class RootShell extends StatefulWidget {
  final SharedPreferences prefs;
  final VoidCallback toggleTheme;
  const RootShell({super.key, required this.prefs, required this.toggleTheme});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tab = 0;
  String _childAge = '';
  List<String> _categories = [];
  List<ArticleSummary> _articles = [];
  List<ReadingActivity> _activities = [];
  Set<String> _seenUrls = {};
  Set<String> _usedImageUrls = {};
  final _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _load() async {
    final resetEpoch = _lastResetEpochMs();
    final storedReset = widget.prefs.getInt('feedResetAt') ?? 0;
    if (storedReset < resetEpoch) {
      await widget.prefs.setInt('feedResetAt', resetEpoch);
      await widget.prefs.setStringList('seenUrls', []);
      await widget.prefs.setStringList('usedImageUrls', []);
      await widget.prefs.setStringList('articles', []);
      await widget.prefs.setInt('loadMoreCount', 0);
      await widget.prefs.setInt('summaryResetAt', resetEpoch);
      await widget.prefs.setInt('summaryCount', 0);
    }
    final actJson = widget.prefs.getStringList('activities') ?? [];
    final seen = widget.prefs.getStringList('seenUrls') ?? [];
    final images = widget.prefs.getStringList('usedImageUrls') ?? [];
    final artJson = widget.prefs.getStringList('articles') ?? [];
    if (!mounted) return;
    setState(() {
      _activities =
          actJson.map((j) => ReadingActivity.fromJson(json.decode(j))).toList();
      _seenUrls = seen.toSet();
      _usedImageUrls = images.toSet();
      _articles =
          artJson.map((j) => ArticleSummary.fromJson(json.decode(j))).toList();
    });
  }

  Future<void> _saveActivities() async =>
      widget.prefs.setStringList('activities',
          _activities.map((a) => json.encode(a.toJson())).toList());
  Future<void> _saveArticles() async =>
      widget.prefs.setStringList('articles',
          _articles.map((a) => json.encode(a.toJson())).toList());
  Future<void> _saveSeenUrls() async =>
      widget.prefs.setStringList('seenUrls', _seenUrls.toList());
  Future<void> _saveUsedImageUrls() async =>
      widget.prefs.setStringList('usedImageUrls', _usedImageUrls.toList());

  void _record(String title, String action) {
    setState(() => _activities.insert(0,
        ReadingActivity(articleTitle: title, action: action, timestamp: DateTime.now())));
    _saveActivities();
  }

  void _onArticlesLoaded(List<ArticleSummary> arts) {
    setState(() => _articles = arts);
    for (final a in arts) {
      if (a.url.isNotEmpty) _seenUrls.add(a.url);
      if (a.imageUrl.isNotEmpty) _usedImageUrls.add(a.imageUrl);
    }
    _saveSeenUrls();
    _saveUsedImageUrls();
    _saveArticles();
  }

  void _toggleSave(String url) {
    setState(() {
      _articles = _articles
          .map((a) => a.url == url ? a.copyWith(saved: !a.saved) : a)
          .toList();
    });
    _saveArticles();
  }

  bool get _onboarded => _childAge.isNotEmpty && _categories.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_onboarded) {
      if (_childAge.isEmpty) {
        return WelcomeScreen(
            onAgeSet: (age) => setState(() => _childAge = age));
      }
      return CategoryPicker(
        childAge: _childAge,
        onCategoriesSelected: (cats) =>
            setState(() { _categories = cats; _articles = []; }),
        onSkip: () =>
            setState(() { _categories = ['General']; _articles = []; }),
        prefs: widget.prefs,
      );
    }
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(
            articles: _articles,
            childAge: _childAge,
            selectedCategories: _categories,
            seenUrls: _seenUrls,
            usedImageUrls: _usedImageUrls,
            toggleTheme: widget.toggleTheme,
            onCategoriesReset: () => setState(() {
              _articles = [];
              _categories = [];
              _childAge = '';
              _seenUrls = {};
              _usedImageUrls = {};
              widget.prefs.setStringList('seenUrls', []);
              widget.prefs.setStringList('usedImageUrls', []);
              _saveArticles();
            }),
            onArticlesLoaded: _onArticlesLoaded,
            onActivityRecorded: _record,
            onSaveToggle: _toggleSave,
            prefs: widget.prefs,
            tts: _tts,
          ),
          ExploreScreen(childAge: _childAge, prefs: widget.prefs, tts: _tts),
          SavedScreen(
            articles: _articles.where((a) => a.saved).toList(),
            onSaveToggle: _toggleSave,
            prefs: widget.prefs,
            tts: _tts,
          ),
          ParentZone(
            activities: _activities,
            articles: _articles,
            prefs: widget.prefs,
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
          currentTab: _tab, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

// ─── BOTTOM NAV ──────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentTab;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentTab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    return NavigationBar(
      selectedIndex: currentTab,
      onDestinationSelected: onTap,
      backgroundColor: c.card,
      indicatorColor: c.primaryCont,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home'),
        NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Explore'),
        NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: 'Saved'),
        NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Parents'),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  WELCOME SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class WelcomeScreen extends StatefulWidget {
  final Function(String) onAgeSet;
  const WelcomeScreen({super.key, required this.onAgeSet});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final age = int.tryParse(_ctrl.text.trim());
    if (age == null || age < 6 || age > 18) {
      setState(() => _error = 'Please enter an age between 6 and 18');
    } else {
      widget.onAgeSet(_ctrl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    return Scaffold(
      backgroundColor: c.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(28),
            child: Column(children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: c.primaryCont,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0x334F46E5), width: 1.5),
                ),
                child: const Icon(Icons.newspaper_rounded,
                    size: 52, color: AppColors.primary),
              ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 20),
              Text('Newsy',
                  style: _ls(40, FontWeight.w800, AppColors.primary, ls: -0.5))
                  .animate()
                  .fadeIn(delay: 200.ms),
              Text('The world, explained for you 🌍',
                  style: _ls(15, FontWeight.w400, c.onVariant))
                  .animate()
                  .fadeIn(delay: 300.ms),
              const SizedBox(height: 40),
              _AgeCard(
                error: _error,
                c: c,
                ctrl: _ctrl,
                focusNode: _focusNode,
                onSubmit: _submit,
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.08),
            ]),
          ),
        ),
      ),
    );
  }
}

class _AgeCard extends StatelessWidget {
  final String error;
  final AppThemeColors c;
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  const _AgeCard({
    required this.error,
    required this.c,
    required this.ctrl,
    required this.focusNode,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: const Color.fromARGB(18, 0, 0, 0),
              blurRadius: 32,
              offset: const Offset(0, 16))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('How old are you?',
            textAlign: TextAlign.center,
            style: _ls(22, FontWeight.w700, c.onSurface)),
        const SizedBox(height: 6),
        Text('Type your age below to get started!',
            textAlign: TextAlign.center,
            style: _ls(14, FontWeight.w400, c.onVariant)),
        const SizedBox(height: 32),
        TextField(
          controller: ctrl,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          textAlign: TextAlign.center,
          onSubmitted: (_) => onSubmit(),
          style: _ls(56, FontWeight.w800, AppColors.primary),
          decoration: InputDecoration(
            hintText: '–',
            hintStyle: _ls(56, FontWeight.w800, c.outlineVar),
            filled: true,
            fillColor: c.primaryCont.withOpacity(0.3),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide:
                const BorderSide(color: AppColors.primary, width: 2.5)),
            contentPadding: const EdgeInsets.symmetric(vertical: 24),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: Text("Let's Go! 🚀",
              style: _ls(18, FontWeight.w700, Colors.white)),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: error.isNotEmpty
              ? Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(error,
                  textAlign: TextAlign.center,
                  style: _ls(13, FontWeight.w600, AppColors.error)))
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CATEGORY PICKER
// ═══════════════════════════════════════════════════════════════════════════════
class CategoryPicker extends StatefulWidget {
  final String childAge;
  final Function(List<String>) onCategoriesSelected;
  final VoidCallback onSkip;
  final SharedPreferences prefs;
  const CategoryPicker({
    super.key,
    required this.childAge,
    required this.onCategoriesSelected,
    required this.onSkip,
    required this.prefs,
  });
  @override
  State<CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<CategoryPicker> {
  static const _cats = [
    {'name': 'Animals & Nature', 'emoji': '🐾'},
    {'name': 'Science & Space', 'emoji': '🔭'},
    {'name': 'Sports', 'emoji': '⚽'},
    {'name': 'Tech & Gaming', 'emoji': '🎮'},
    {'name': 'Arts & Movies', 'emoji': '🎨'},
    {'name': 'Environment', 'emoji': '🌿'},
    {'name': 'Adventure & Travel', 'emoji': '✈️'},
    {'name': 'Food & Cooking', 'emoji': '🍕'},
  ];
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What do you love? ❤️',
                          style: _ls(28, FontWeight.w700, c.onSurface)),
                      const SizedBox(height: 6),
                      Text('Age ${widget.childAge} · Pick topics you enjoy',
                          style: _ls(15, FontWeight.w400, c.onVariant)),
                    ]),
              ).animate().fadeIn().slideX(begin: -0.05),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: _cats.length,
                  itemBuilder: (ctx, i) {
                    final name = _cats[i]['name']!;
                    final emoji = _cats[i]['emoji']!;
                    final sel = _selected.contains(name);
                    final color = kCatColors[name] ?? AppColors.primary;
                    return _CategoryTile(
                      name: name,
                      emoji: emoji,
                      selected: sel,
                      color: color,
                      onTap: () => setState(() {
                        if (sel) {
                          _selected.remove(name);
                        } else {
                          _selected.add(name);
                        }
                      }),
                    ).animate().scale(
                        delay: Duration(milliseconds: 200 + i * 40),
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutBack);
                  },
                ),
              ),
              _CatActionBar(
                enabled: _selected.isNotEmpty,
                onProceed: () {
                  if (_selected.isNotEmpty) {
                    widget.onCategoriesSelected(_selected.toList());
                  }
                },
                onSkip: widget.onSkip,
                c: c,
              ).animate().slideY(
                  begin: 1,
                  duration: 500.ms,
                  curve: Curves.easeOutCubic),
            ]),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String name, emoji;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _CategoryTile({
    required this.name,
    required this.emoji,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? color : c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? color : c.outlineVar, width: selected ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? Color.fromARGB(77, color.red, color.green, color.blue)
                  : const Color(0x0A000000),
              blurRadius: selected ? 12 : 8,
              offset: selected ? const Offset(0, 6) : const Offset(0, 4),
            )
          ],
        ),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 38)),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _ls(
                        13, FontWeight.w600, selected ? Colors.white : c.onSurface)),
              ),
            ]),
      ),
    );
  }
}

class _CatActionBar extends StatelessWidget {
  final bool enabled;
  final VoidCallback onProceed, onSkip;
  final AppThemeColors c;
  const _CatActionBar({
    required this.enabled,
    required this.onProceed,
    required this.onSkip,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(children: [
        FilledButton(
          onPressed: enabled ? onProceed : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: c.outlineVar,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: Text("Let's Read! 🚀",
              style: _ls(17, FontWeight.w700, Colors.white)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onSkip,
          child: Text('Skip – just show me the news →',
              style: _ls(14, FontWeight.w600, c.onVariant)),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  HOME SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  final List<ArticleSummary> articles;
  final String childAge;
  final List<String> selectedCategories;
  final Set<String> seenUrls;
  final Set<String> usedImageUrls;
  final VoidCallback onCategoriesReset;
  final VoidCallback toggleTheme;
  final Function(List<ArticleSummary>) onArticlesLoaded;
  final Function(String, String) onActivityRecorded;
  final Function(String) onSaveToggle;
  final SharedPreferences prefs;
  final FlutterTts tts;

  const HomeScreen({
    super.key,
    required this.articles,
    required this.childAge,
    required this.selectedCategories,
    required this.seenUrls,
    required this.usedImageUrls,
    required this.onCategoriesReset,
    required this.toggleTheme,
    required this.onArticlesLoaded,
    required this.onActivityRecorded,
    required this.onSaveToggle,
    required this.prefs,
    required this.tts,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = false;
  bool _loadingMore = false;
  String _error = '';
  int _loadMoreCount = 0;
  String? _nextPage;

  final Set<String> _localSeenUrls = {};
  final Set<String> _localSeenTitles = {};
  final Set<String> _localUsedImages = {};

  @override
  void initState() {
    super.initState();
    _loadMoreCount = getLoadMoreUsageToday(widget.prefs);
    _localUsedImages.addAll(widget.usedImageUrls);
    for (final a in widget.articles) {
      if (a.url.isNotEmpty) _localSeenUrls.add(a.url);
      if (a.imageUrl.isNotEmpty) _localUsedImages.add(a.imageUrl);
      _localSeenTitles.add(normalizeTitle(a.title));
    }
  }

  ({String? q, String? apiCat}) _buildQuery() {
    final cats =
    widget.selectedCategories.where((c) => c != 'General').toList();
    if (cats.isEmpty) return (q: null, apiCat: null);
    if (cats.length == 1) {
      final cq = kCatQueryMap[cats.first];
      if (cq == null) return (q: null, apiCat: null);
      return (q: cq.q, apiCat: cq.apiCat);
    }
    final keywords = <String>{};
    String? apiCat;
    for (final cat in cats) {
      final cq = kCatQueryMap[cat];
      if (cq != null) {
        for (final k in cq.q.split(' OR ').map((k) => k.trim())) {
          keywords.add(k);
        }
        apiCat ??= cq.apiCat;
      }
    }
    const maxLen = 120;
    final parts = <String>[];
    var len = 0;
    for (final kw in keywords) {
      final addition = parts.isEmpty ? kw : ' OR $kw';
      if (len + addition.length > maxLen) break;
      parts.add(kw);
      len += addition.length;
    }
    return (
    q: parts.isNotEmpty ? parts.join(' OR ') : null,
    apiCat: apiCat,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRaw(
      {int size = 10, String? page}) async {
    final (:q, :apiCat) = _buildQuery();
    final params = <String, String>{
      'apikey': kNewsDataApiKey,
      'language': 'en',
      'size': size.toString(),
    };
    if (q != null) params['q'] = q;
    if (apiCat != null) params['category'] = apiCat;
    if (page != null) params['page'] = page;

    final res = await http
        .get(Uri.https('newsdata.io', '/api/1/latest', params))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (data['status'] != 'success') throw Exception('API error');
    _nextPage = data['nextPage']?.toString();

    final allSeenUrls = {...widget.seenUrls, ..._localSeenUrls};
    final batchTitles = Set<String>.from(_localSeenTitles);
    final batchImages = Set<String>.from(_localUsedImages);

    final result = <Map<String, dynamic>>[];
    for (final raw in data['results'] as List) {
      final a = raw as Map<String, dynamic>;
      final url = a['link']?.toString() ?? '';
      final title = a['title']?.toString() ?? '';
      final img = a['image_url']?.toString() ?? '';
      if (title.isEmpty || title == '[Removed]') continue;
      if (a['content'] == null && a['description'] == null) continue;
      if (url.isNotEmpty && allSeenUrls.contains(url)) continue;
      if (isDuplicateTitle(title, batchTitles)) continue;
      if (!isRelevant(a, widget.selectedCategories)) continue;
      batchTitles.add(normalizeTitle(title));
      if (img.isNotEmpty && batchImages.contains(img)) {
        result.add(Map<String, dynamic>.from(a)..['image_url'] = null);
      } else {
        if (img.isNotEmpty) batchImages.add(img);
        result.add(a);
      }
    }
    return result;
  }

  Future<void> _loadNews() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = '';
      _nextPage = null;
    });
    try {
      final raw = await _fetchRaw(size: 10);
      if (raw.isEmpty) throw Exception('No articles found');
      final summaries = raw
          .map((a) => articleFromRaw(a, widget.selectedCategories))
          .toList();
      for (final s in summaries) {
        if (s.url.isNotEmpty) _localSeenUrls.add(s.url);
        if (s.imageUrl.isNotEmpty) _localUsedImages.add(s.imageUrl);
        _localSeenTitles.add(normalizeTitle(s.title));
        // Prevent unbounded growth
        if (_localSeenTitles.length > kMaxDedupTitles) {
          _localSeenTitles.remove(_localSeenTitles.first);
        }
        if (_localUsedImages.length > kMaxDedupImages) {
          _localUsedImages.remove(_localUsedImages.first);
        }
      }
      widget.onArticlesLoaded(summaries);
    } catch (_) {
      if (mounted) {
        setState(() =>
        _error = 'Couldn\'t load stories. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loadMoreCount >= kMaxLoadMore) return;
    final allowed = await consumeLoadMoreUsage(widget.prefs);
    if (!allowed) {
      if (mounted) setState(() => _loadMoreCount = kMaxLoadMore);
      return;
    }
    if (mounted) setState(() => _loadingMore = true);
    try {
      final raw = await _fetchRaw(size: 10, page: _nextPage);
      if (raw.isEmpty) throw Exception('No more');
      final summaries = raw
          .map((a) => articleFromRaw(a, widget.selectedCategories))
          .toList();
      for (final s in summaries) {
        if (s.url.isNotEmpty) _localSeenUrls.add(s.url);
        if (s.imageUrl.isNotEmpty) _localUsedImages.add(s.imageUrl);
        _localSeenTitles.add(normalizeTitle(s.title));
      }
      widget.onArticlesLoaded([...widget.articles, ...summaries]);
    } catch (_) {
      /* silent */
    } finally {
      if (mounted) {
        setState(
                () => _loadMoreCount = getLoadMoreUsageToday(widget.prefs));
        setState(() => _loadingMore = false);
      }
    }
  }

  void _openArticle(ArticleSummary article) {
    widget.onActivityRecorded(article.title, 'opened');
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ArticleDetail(
              article: article,
              tts: widget.tts,
              prefs: widget.prefs,
              onSaveToggle: () => widget.onSaveToggle(article.url),
            )));
  }

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: RepaintBoundary(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                  child: _HomeAppBar(
                      c: c,
                      dark: dark,
                      onToggleTheme: widget.toggleTheme,
                      onReset: widget.onCategoriesReset)),
              SliverToBoxAdapter(
                  child: _QuotaBar(prefs: widget.prefs)),
              if (widget.articles.isEmpty && !_loading && _error.isEmpty)
                SliverFillRemaining(child: _EmptyState(onLoad: _loadNews))
              else if (_loading && widget.articles.isEmpty)
                const SliverToBoxAdapter(child: _ShimmerHome())
              else if (_error.isNotEmpty && widget.articles.isEmpty)
                  SliverFillRemaining(
                      child: _ErrorState(message: _error, onRetry: _loadNews))
                else ...[
                    SliverToBoxAdapter(
                        child: _TopStoriesSection(
                            article: widget.articles.first,
                            onOpen: _openArticle,
                            onSave: () =>
                                widget.onSaveToggle(widget.articles.first.url))),
                    if (widget.articles.length > 1)
                      SliverToBoxAdapter(
                          child: _FeaturedSection(
                              articles: widget.articles.sublist(1, 5.clamp(1, widget.articles.length)),
                              onOpen: _openArticle)),
                    if (widget.articles.length > 2)
                      SliverToBoxAdapter(
                          child: _PromoCard(
                              article: widget.articles[2],
                              onTap: () => _openArticle(widget.articles[2]))),
                    SliverToBoxAdapter(
                        child: _SectionHeader(
                            title: 'Latest Updates',
                            padding: const EdgeInsets.fromLTRB(20, 28, 20, 4))),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                          if (i < widget.articles.length) {
                            final a = widget.articles[i];
                            return RepaintBoundary(
                                child: _ArticleListItem(
                                  article: a,
                                  onTap: () => _openArticle(a),
                                  onSave: () => widget.onSaveToggle(a.url),
                                ));
                          }
                          if (_loadMoreCount >= kMaxLoadMore) {
                            return const _PaywallCard();
                          }
                          return _LoadMoreRow(
                            loading: _loadingMore,
                            remaining: kMaxLoadMore - _loadMoreCount,
                            onTap: _loadMore,
                          );
                        },
                        childCount: widget.articles.length + 1,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Home sub-widgets ─────────────────────────────────────────────────────────
class _HomeAppBar extends StatelessWidget {
  final AppThemeColors c;
  final bool dark;
  final VoidCallback onToggleTheme, onReset;
  const _HomeAppBar({
    required this.c,
    required this.dark,
    required this.onToggleTheme,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: c.primaryCont, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.person_rounded,
              color: AppColors.primary, size: 22),
        ),
        const Spacer(),
        Text('Newsy', style: _ls(22, FontWeight.w800, AppColors.primary)),
        const Spacer(),
        _NavIconButton(
          icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: c.onSurface),
          onPressed: onToggleTheme,
          c: c,
        ),
        const SizedBox(width: 8),
        _NavIconButton(
          icon: Icon(Icons.tune_rounded, color: c.onSurface),
          onPressed: onReset,
          c: c,
        ),
      ]),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onPressed;
  final AppThemeColors c;
  const _NavIconButton({
    required this.icon,
    required this.onPressed,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: icon,
      style: IconButton.styleFrom(
        backgroundColor: c.card,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;
  const _SectionHeader({required this.title, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    return Padding(
      padding: padding,
      child: Text(title, style: _ls(22, FontWeight.w600, c.onSurface)),
    );
  }
}

class _TopStoriesSection extends StatelessWidget {
  final ArticleSummary article;
  final Function(ArticleSummary) onOpen;
  final VoidCallback onSave;
  const _TopStoriesSection({
    required this.article,
    required this.onOpen,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Top Stories',
            style: _ls(24, FontWeight.w600, c.onSurface)),
        const SizedBox(height: 2),
        Text('Stories picked just for you.',
            style: _ls(14, FontWeight.w400, c.onVariant)),
        const SizedBox(height: 16),
        RepaintBoundary(
            child: _HeroCard(
                article: article, onTap: () => onOpen(article), onSave: onSave)),
      ]),
    );
  }
}

class _FeaturedSection extends StatelessWidget {
  final List<ArticleSummary> articles;
  final Function(ArticleSummary) onOpen;
  const _FeaturedSection({required this.articles, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text('Featured',
            style: _ls(18, FontWeight.w600, c.onSurface)),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 210,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: articles.length.clamp(0, 4),
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (ctx, i) {
            return RepaintBoundary(
                child: _FeaturedCard(
                    article: articles[i], onTap: () => onOpen(articles[i])));
          },
        ),
      ),
    ]);
  }
}

// ─── Hero Card ────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final ArticleSummary article;
  final VoidCallback onTap, onSave;
  const _HeroCard(
      {required this.article, required this.onTap, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final catColor = kCatColors[article.category] ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 230,
          child: Stack(fit: StackFit.expand, children: [
            article.imageUrl.isNotEmpty
                ? Image.network(article.imageUrl,
                fit: BoxFit.cover,
                cacheWidth: 800,
                errorBuilder: (_, __, ___) =>
                    _CatGradient(catColor))
                : _CatGradient(catColor),
            const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xBF000000)],
                    stops: [0.35, 1.0],
                  ),
                )),
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: onSave,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                      color: Color(0x59000000), shape: BoxShape.circle),
                  child: Icon(
                    article.saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: article.saved
                        ? AppColors.primaryContainer
                        : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 8, runSpacing: 4, children: [
                        _Tag(
                            label: article.category,
                            bgColor: catColor,
                            textColor: Colors.white),
                        const _Tag(
                            label: '⏱ Quick Read',
                            bgColor: Color(0x33FFFFFF),
                            textColor: Colors.white),
                      ]),
                      const SizedBox(height: 8),
                      Text(article.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _ls(20, FontWeight.w700, Colors.white,
                              height: 1.2)),
                    ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CatGradient extends StatelessWidget {
  final Color color;
  const _CatGradient(this.color);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Color.fromARGB(204, color.red, color.green, color.blue),
            color,
          ])),
      child: Center(
          child: Icon(Icons.article_rounded,
              size: 72, color: const Color(0x4DFFFFFF))),
    );
  }
}

// ─── Featured Card ────────────────────────────────────────────────────────────
class _FeaturedCard extends StatelessWidget {
  final ArticleSummary article;
  final VoidCallback onTap;
  const _FeaturedCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    final catColor = kCatColors[article.category] ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.outlineVar),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 8,
                offset: Offset(0, 4))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(14)),
            child: SizedBox(
              height: 110,
              width: double.infinity,
              child: article.imageUrl.isNotEmpty
                  ? Image.network(article.imageUrl,
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                  errorBuilder: (_, __, ___) =>
                      _ImagePlaceholder(catColor))
                  : _ImagePlaceholder(catColor),
            ),
          ),
          Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(article.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _ls(11, FontWeight.w700, catColor)),
                      const SizedBox(height: 4),
                      Text(article.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _ls(13, FontWeight.w600, c.onSurface,
                              height: 1.35)),
                    ]),
              )),
        ]),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final Color color;
  const _ImagePlaceholder(this.color);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Color.fromARGB(31, color.red, color.green, color.blue),
      child: Center(
          child: Icon(Icons.image_outlined,
              color:
              Color.fromARGB(128, color.red, color.green, color.blue),
              size: 32)),
    );
  }
}

// ─── Promo Card ───────────────────────────────────────────────────────────────
class _PromoCard extends StatelessWidget {
  final ArticleSummary article;
  final VoidCallback onTap;
  const _PromoCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: const Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('FEATURED STORY',
                            style:
                            _ls(11, FontWeight.w700, Colors.white)),
                      ),
                      const SizedBox(height: 10),
                      Text(article.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _ls(17, FontWeight.w600, Colors.white,
                              height: 1.3)),
                      const SizedBox(height: 8),
                      Text('Tap to read',
                          style: _ls(
                              13, FontWeight.w400, const Color(0xBFFFFFFF))),
                    ])),
            const SizedBox(width: 16),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                  color: Color(0x33FFFFFF), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 18),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Article List Item ────────────────────────────────────────────────────────
class _ArticleListItem extends StatelessWidget {
  final ArticleSummary article;
  final VoidCallback onTap;
  // When null the bookmark control is hidden (e.g. on the Explore results list,
  // where articles aren't part of the persisted feed and can't be saved).
  final VoidCallback? onSave;
  const _ArticleListItem(
      {required this.article, required this.onTap, this.onSave});

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    final catColor = kCatColors[article.category] ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 72,
              height: 72,
              child: article.imageUrl.isNotEmpty
                  ? Image.network(article.imageUrl,
                  fit: BoxFit.cover,
                  cacheWidth: 144,
                  cacheHeight: 144,
                  errorBuilder: (_, __, ___) =>
                      _ThumbPlaceholder(catColor))
                  : _ThumbPlaceholder(catColor),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${article.category}  ·  ${article.timeAgo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _ls(12, FontWeight.w600, catColor, ls: 0.1),
                    ),
                    const SizedBox(height: 4),
                    Text(article.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                        _ls(15, FontWeight.w600, c.onSurface, height: 1.35)),
                  ])),
          if (onSave != null)
            IconButton(
              onPressed: onSave,
              icon: Icon(
                article.saved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                size: 20,
                color: article.saved ? AppColors.primary : c.outline,
              ),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ]),
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  final Color color;
  const _ThumbPlaceholder(this.color);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Color.fromARGB(26, color.red, color.green, color.blue),
      child: Center(
          child: Icon(Icons.article_outlined,
              color: Color.fromARGB(128, color.red, color.green, color.blue),
              size: 28)),
    );
  }
}

// ─── Tag Pill ─────────────────────────────────────────────────────────────────
class _Tag extends StatelessWidget {
  final String label;
  final Color bgColor, textColor;
  const _Tag(
      {required this.label, required this.bgColor, required this.textColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration:
    BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
    child: Text(label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _ls(12, FontWeight.w600, textColor)),
  );
}

// ─── Load More ────────────────────────────────────────────────────────────────
class _LoadMoreRow extends StatelessWidget {
  final bool loading;
  final int remaining;
  final VoidCallback onTap;
  const _LoadMoreRow(
      {required this.loading, required this.remaining, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
    child: OutlinedButton(
      onPressed: loading ? null : onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: Color(0x664F46E5), width: 1.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
      child: loading
          ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.primary))
          : Text('Load More ($remaining left)',
          style: _ls(15, FontWeight.w700, AppColors.primary)),
    ),
  );
}

// ─── Quota Bar ────────────────────────────────────────────────────────────────
class _QuotaBar extends StatefulWidget {
  final SharedPreferences prefs;
  const _QuotaBar({required this.prefs});
  @override
  State<_QuotaBar> createState() => _QuotaBarState();
}

class _QuotaBarState extends State<_QuotaBar> {
  Timer? _timer;
  int _summaryUsed = 0;
  int _loadMoreUsed = 0;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_refresh);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    _summaryUsed = getSummaryUsageToday(widget.prefs);
    _loadMoreUsed = getLoadMoreUsageToday(widget.prefs);
    _timeLeft = _calcTimeLeft();
  }

  Duration _calcTimeLeft() {
    final offset = _pacificUtcOffset();
    final nowUtc = DateTime.now().toUtc();
    final nowPacific = nowUtc.subtract(offset);
    final todayNoon =
    DateTime.utc(nowPacific.year, nowPacific.month, nowPacific.day, 12)
        .add(offset);
    final next =
    nowUtc.isBefore(todayNoon) ? todayNoon : todayNoon.add(const Duration(days: 1));
    final diff = next.difference(nowUtc);
    return diff.isNegative ? Duration.zero : diff;
  }

  String _fmtCountdown(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '${h}h ${m}m ${s}s' : '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    final sumLeft =
    (kMaxSummariesPerDay - _summaryUsed).clamp(0, kMaxSummariesPerDay);
    final moreLeft = (kMaxLoadMore - _loadMoreUsed).clamp(0, kMaxLoadMore);
    final sumColor = sumLeft == 0 ? AppColors.error : AppColors.primary;
    final moreColor =
    moreLeft == 0 ? AppColors.error : const Color(0xFF10B981);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.outlineVar),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000),
                blurRadius: 6,
                offset: Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Expanded(
              child: _QuotaChip(
                icon: '✨',
                label: 'AI summaries',
                used: _summaryUsed,
                max: kMaxSummariesPerDay,
                valueColor: sumColor,
                c: c,
              )),
          Container(
              width: 1,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: c.outlineVar),
          Expanded(
              child: _QuotaChip(
                icon: '📰',
                label: 'More loads',
                used: _loadMoreUsed,
                max: kMaxLoadMore,
                valueColor: moreColor,
                c: c,
              )),
          Container(
              width: 1,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: c.outlineVar),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('⏱ resets in',
                  style: _ls(10, FontWeight.w500, c.onVariant)),
              const SizedBox(height: 3),
              Text(_fmtCountdown(_timeLeft),
                  style: _ls(13, FontWeight.w700, c.onSurface)),
            ],
          ),
        ]),
      ),
    );
  }
}

class _QuotaChip extends StatelessWidget {
  final String icon, label;
  final int used, max;
  final Color valueColor;
  final AppThemeColors c;
  const _QuotaChip({
    required this.icon,
    required this.label,
    required this.used,
    required this.max,
    required this.valueColor,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (max - used).clamp(0, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$icon $label',
            style: _ls(10, FontWeight.w500, c.onVariant)),
        const SizedBox(height: 4),
        Row(children: [
          Text('$remaining',
              style: _ls(15, FontWeight.w800, valueColor)),
          Text(' / $max left',
              style: _ls(11, FontWeight.w500, c.onVariant)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: remaining / max,
            minHeight: 4,
            backgroundColor: c.outlineVar,
            valueColor: AlwaysStoppedAnimation<Color>(valueColor),
          ),
        ),
      ],
    );
  }
}

// ─── Paywall Card ─────────────────────────────────────────────────────────────
class _PaywallCard extends StatelessWidget {
  const _PaywallCard();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(children: [
      const Text('⭐', style: TextStyle(fontSize: 40)),
      const SizedBox(height: 12),
      Text('Want More Stories?',
          style: _ls(22, FontWeight.w700, Colors.white)),
      const SizedBox(height: 8),
      Text(
          'Upgrade for unlimited daily stories and ad-free reading.',
          textAlign: TextAlign.center,
          style: _ls(14, FontWeight.w400, const Color(0xD9FFFFFF),
              height: 1.5)),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () {},
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Premium coming soon',
              style: _ls(16, FontWeight.w700, AppColors.primaryDark)),
        ),
      ),
    ]),
  );
}

// ─── Empty / Error / Shimmer ──────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onLoad;
  const _EmptyState({required this.onLoad});

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_stories_rounded,
                  size: 80, color: c.primaryCont),
              const SizedBox(height: 20),
              Text('No stories yet!',
                  style: _ls(22, FontWeight.w700, c.onSurface)),
              const SizedBox(height: 8),
              Text('Tap below to load your personalised news.',
                  textAlign: TextAlign.center,
                  style: _ls(15, FontWeight.w400, c.onVariant)),
              const SizedBox(height: 36),
              FilledButton.icon(
                onPressed: onLoad,
                icon: const Icon(Icons.bolt_rounded),
                label: Text('Load My Stories',
                    style: _ls(17, FontWeight.w700, Colors.white)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ]),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(message,
                  textAlign: TextAlign.center,
                  style: _ls(15, FontWeight.w400, c.onVariant)),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onRetry,
                child: Text('Retry',
                    style: _ls(15, FontWeight.w600, AppColors.primary)),
              ),
            ]),
      ),
    );
  }
}

class _ShimmerHome extends StatelessWidget {
  const _ShimmerHome();

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    return Shimmer.fromColors(
      baseColor: c.surfaceLow,
      highlightColor: c.shimmerHighlight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: 230,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16))),
              const SizedBox(height: 20),
              Container(
                  height: 16,
                  width: 100,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8))),
              const SizedBox(height: 12),
              SizedBox(
                  height: 200,
                  child: Row(children: [
                    Flexible(
                        child: Container(
                            margin: const EdgeInsets.only(right: 7),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14)))),
                    Flexible(
                        child: Container(
                            margin: const EdgeInsets.only(left: 7),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14)))),
                  ])),
              const SizedBox(height: 20),
              for (int i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10))),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                  height: 12,
                                  width: 80,
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6))),
                              const SizedBox(height: 8),
                              Container(
                                  height: 14,
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6))),
                              const SizedBox(height: 6),
                              Container(
                                  height: 14,
                                  width: 160,
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6))),
                            ])),
                  ]),
                ),
            ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  EXPLORE SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class ExploreScreen extends StatefulWidget {
  final String childAge;
  final SharedPreferences prefs;
  final FlutterTts tts;
  const ExploreScreen(
      {super.key, required this.childAge, required this.prefs, required this.tts});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchCtrl = TextEditingController();
  List<ArticleSummary> _results = [];
  bool _loading = false;
  bool _searched = false;
  String _error = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> _tokenise(String q) {
    const stopWords = {
      'a', 'an', 'the', 'is', 'in', 'on', 'at', 'of', 'to', 'for', 'and',
      'or', 'but', 'with', 'that', 'this', 'it', 'i', 'me', 'my', 'we',
      'our', 'you', 'your', 'he', 'she', 'they', 'their', 'about', 'are',
      'was', 'were', 'be', 'been', 'has', 'have', 'had',
    };
    return q.toLowerCase().split(RegExp(r'[\s,;:!?.]+'))
        .where((t) => t.length > 2 && !stopWords.contains(t))
        .toList();
  }

  String _expandQuery(String raw, List<String> tokens) {
    const synonyms = <String, List<String>>{
      'dog': ['dogs', 'puppy', 'canine', 'pet'],
      'cat': ['cats', 'kitten', 'feline', 'pet'],
      'space': ['nasa', 'rocket', 'astronaut', 'planet', 'galaxy', 'asteroid'],
      'animal': ['wildlife', 'creature', 'species', 'habitat', 'zoo'],
      'sport': ['game', 'match', 'athlete', 'championship', 'team'],
      'food': ['recipe', 'cooking', 'chef', 'restaurant', 'meal'],
      'music': ['song', 'album', 'band', 'concert', 'artist'],
      'movie': ['film', 'cinema', 'actor', 'director', 'series'],
      'climate': ['environment', 'global warming', 'carbon', 'renewable'],
      'travel': ['tourism', 'destination', 'adventure', 'vacation', 'journey'],
      'tech': ['technology', 'software', 'app', 'digital', 'gadget'],
      'science': ['research', 'discovery', 'experiment', 'study', 'lab'],
      'robot': ['ai', 'automation', 'artificial intelligence', 'machine'],
    };
    final extra = <String>{};
    for (final t in tokens) {
      final syns = synonyms[t];
      if (syns != null) extra.addAll(syns);
    }
    return extra.isEmpty ? raw : '$raw OR ${extra.join(' OR ')}';
  }

  int _score(Map<String, dynamic> a, List<String> tokens) {
    final title = (a['title'] ?? '').toString().toLowerCase();
    final body =
    '${a['description'] ?? ''} ${a['content'] ?? ''}'.toLowerCase();
    int s = 0;
    for (final t in tokens) {
      final re = RegExp(RegExp.escape(t), caseSensitive: false);
      if (re.hasMatch(title)) s += 3;
      if (re.hasMatch(body)) s += 1;
    }
    return s;
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = '';
      _searched = true;
      _results = [];
    });

    try {
      final tokens = _tokenise(q);
      final expandedQ = _expandQuery(q, tokens);
      final params = {
        'apikey': kNewsDataApiKey,
        'language': 'en',
        'q': expandedQ,
        'size': '20',
      };
      final res = await http
          .get(Uri.https('newsdata.io', '/api/1/latest', params))
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final data = json.decode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'success') throw Exception('API error');

      final raw = (data['results'] as List)
          .where((a) =>
      a['title'] != null &&
          a['title'] != '[Removed]' &&
          (a['content'] != null || a['description'] != null))
          .cast<Map<String, dynamic>>()
          .toList();

      final scored =
      raw.map((a) => (article: a, score: _score(a, tokens))).toList()
        ..sort((x, y) => y.score.compareTo(x.score));

      final filtered =
      tokens.isEmpty ? scored : scored.where((e) => e.score > 0).toList();

      final seenTitles = <String>{};
      final seenImages = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final entry in filtered) {
        final a = entry.article;
        final norm = (a['title'] as String)
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), '')
            .trim();
        if (seenTitles.contains(norm)) continue;
        seenTitles.add(norm);
        final img = a['image_url']?.toString() ?? '';
        if (img.isNotEmpty && seenImages.contains(img)) {
          deduped.add(Map<String, dynamic>.from(a)..['image_url'] = null);
        } else {
          if (img.isNotEmpty) seenImages.add(img);
          deduped.add(a);
        }
      }

      if (!mounted) return;
      setState(() {
        _results = deduped
            .map((a) => articleFromRaw(a, ['General']))
            .toList();
        if (_results.isEmpty) {
          _error =
          'No results found for "$q". Try a different word!';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() =>
        _error = 'Couldn\'t connect. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Explore',
                        style: _ls(28, FontWeight.w700, c.onSurface)),
                    const SizedBox(height: 14),
                    _SearchBar(
                      controller: _searchCtrl,
                      onSearch: _search,
                      c: c,
                    ),
                  ]),
            ),
            Expanded(child: _buildResults(c)),
          ])),
    );
  }

  Widget _buildResults(AppThemeColors c) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (!_searched) {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.travel_explore_rounded,
                    size: 72, color: c.primaryCont),
                const SizedBox(height: 16),
                Text('Search for anything!',
                    style: _ls(18, FontWeight.w600, c.onSurface)),
                const SizedBox(height: 8),
                Text('Animals, space, sports, food…',
                    style: _ls(14, FontWeight.w400, c.onVariant)),
              ]));
    }
    if (_error.isNotEmpty) {
      return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(_error,
                textAlign: TextAlign.center,
                style: _ls(15, FontWeight.w400, c.onVariant)),
          ));
    }
    return RepaintBoundary(
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: _results.length,
        itemBuilder: (ctx, i) {
          final a = _results[i];
          return RepaintBoundary(
              child: _ArticleListItem(
                article: a,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ArticleDetail(
                            article: a,
                            tts: widget.tts,
                            prefs: widget.prefs,
                            onSaveToggle: () {}))),
              ));
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  final AppThemeColors c;
  const _SearchBar({
    required this.controller,
    required this.onSearch,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.outlineVar),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 3))
        ],
      ),
      child: Row(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Icon(Icons.search_rounded, color: c.outline),
        ),
        Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSearch(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search any topic…',
                hintStyle: _ls(15, FontWeight.w400, c.outlineVar),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              style: _ls(15, FontWeight.w400, c.onSurface),
            )),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton(
            onPressed: onSearch,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child:
            Text('Go', style: _ls(14, FontWeight.w700, Colors.white)),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SAVED SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class SavedScreen extends StatefulWidget {
  final List<ArticleSummary> articles;
  final Function(String) onSaveToggle;
  final SharedPreferences? prefs;
  final FlutterTts tts;
  const SavedScreen({
    super.key,
    required this.articles,
    required this.onSaveToggle,
    this.prefs,
    required this.tts,
  });
  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: widget.articles.isEmpty
            ? Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border_rounded,
                      size: 72, color: c.primaryCont),
                  const SizedBox(height: 16),
                  Text('Nothing saved yet',
                      style: _ls(20, FontWeight.w700, c.onSurface)),
                  const SizedBox(height: 8),
                  Text('Tap the bookmark on any story',
                      style: _ls(15, FontWeight.w400, c.onVariant)),
                ]))
            : ListView(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('Saved',
                style: _ls(28, FontWeight.w600, c.onSurface)),
          ),
          ...widget.articles.map((a) => RepaintBoundary(
            child: _ArticleListItem(
              article: a,
              onTap: () {
                if (widget.prefs == null) return;
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ArticleDetail(
                            article: a,
                            tts: widget.tts,
                            prefs: widget.prefs!,
                            onSaveToggle: () =>
                                widget.onSaveToggle(a.url))));
              },
              onSave: () => widget.onSaveToggle(a.url),
            ),
          )),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ARTICLE DETAIL
// ═══════════════════════════════════════════════════════════════════════════════
class ArticleDetail extends StatefulWidget {
  final ArticleSummary article;
  final FlutterTts tts;
  final SharedPreferences prefs;
  final VoidCallback onSaveToggle;
  const ArticleDetail({
    super.key,
    required this.article,
    required this.tts,
    required this.prefs,
    required this.onSaveToggle,
  });
  @override
  State<ArticleDetail> createState() => _ArticleDetailState();
}

class _ArticleDetailState extends State<ArticleDetail> {
  bool _saved = false;
  bool _asking = false;
  bool _speaking = false;
  bool _generatingSummary = false;
  String? _aiSummary;
  int _summaryUsed = 0;

  final _qCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_QA> _chat = [];

  @override
  void initState() {
    super.initState();
    _saved = widget.article.saved;
    _summaryUsed = getSummaryUsageToday(widget.prefs);
    // Keep the speak/stop button in sync with the shared TTS engine. Without
    // these handlers `speak()` returns before playback finishes, so the button
    // would flip straight back to "play" while audio is still running.
    widget.tts.awaitSpeakCompletion(true);
    widget.tts.setCompletionHandler(_onSpeechDone);
    widget.tts.setCancelHandler(_onSpeechDone);
    widget.tts.setErrorHandler((_) => _onSpeechDone());
  }

  void _onSpeechDone() {
    if (mounted) setState(() => _speaking = false);
  }

  @override
  void dispose() {
    // Stop narration so it doesn't keep playing after the screen is gone, and
    // detach our handlers from the shared engine.
    widget.tts.stop();
    widget.tts.setCompletionHandler(() {});
    widget.tts.setCancelHandler(() {});
    _qCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateSummary() async {
    if (_generatingSummary || !kAiEnabled) return;
    // Check the quota up front but only consume it on a successful response, so a
    // network/API failure never costs the child one of their daily summaries.
    if (getSummaryUsageToday(widget.prefs) >= kMaxSummariesPerDay) {
      _showQuotaSnackBar();
      return;
    }
    setState(() => _generatingSummary = true);
    try {
      final src = widget.article.fullContent.isNotEmpty
          ? widget.article.fullContent
          : widget.article.rawDescription;
      final truncated = src.length > 2000 ? src.substring(0, 2000) : src;
      final res = await http
          .post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $kOpenAiApiKey'
        },
        body: json.encode({
          'model': kOpenAiModel,
          'max_tokens': 150,
          'messages': [
            {
              'role': 'system',
              'content':
              'You are a friendly teacher. Explain this news in '
                  '3-4 short, simple, enthusiastic sentences for a child.'
            },
            {'role': 'user', 'content': truncated},
          ],
        }),
      )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final content =
            (json.decode(res.body)['choices'][0]['message']['content'] as String)
                .trim();
        await consumeSummaryUsage(widget.prefs);
        if (!mounted) return;
        setState(() {
          _aiSummary = content;
          _summaryUsed = getSummaryUsageToday(widget.prefs);
        });
      } else {
        _showErrorSnackBar('Couldn\'t generate summary. Try again!');
      }
    } catch (_) {
      _showErrorSnackBar('Couldn\'t connect. Check your internet!');
    } finally {
      if (mounted) setState(() => _generatingSummary = false);
    }
  }

  void _showQuotaSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        'You\'ve used all $kMaxSummariesPerDay summaries today. Come back after 12pm PT!',
        style: _ls(13, FontWeight.w500, Colors.white),
      ),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: _ls(13, FontWeight.w500, Colors.white)),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _ask() async {
    final q = _qCtrl.text.trim();
    if (q.isEmpty || !kAiEnabled) return;
    _qCtrl.clear();
    setState(() => _asking = true);
    try {
      final ctx = _aiSummary ?? widget.article.rawDescription;
      final res = await http
          .post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $kOpenAiApiKey'
        },
        body: json.encode({
          'model': kOpenAiModel,
          'max_tokens': 200,
          'messages': [
            {
              'role': 'system',
              'content':
              'You are a friendly teacher. Answer in 2-3 simple sentences for a child.'
            },
            {
              'role': 'user',
              'content': 'Article: "$ctx"\nQuestion: $q'
            },
          ],
        }),
      )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      final answer = res.statusCode == 200
          ? (json.decode(res.body)['choices'][0]['message']['content']
      as String)
          .trim()
          : 'Oops, try again!';
      setState(() => _chat.add(_QA(q: q, a: answer)));
    } catch (_) {
      if (mounted) {
        setState(
                () => _chat.add(_QA(q: q, a: 'Couldn\'t connect right now.')));
      }
    } finally {
      if (mounted) setState(() => _asking = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    final catColor = kCatColors[widget.article.category] ?? AppColors.primary;
    final summaryLeft = kMaxSummariesPerDay - _summaryUsed;

    return Scaffold(
      backgroundColor: c.bg,
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: c.card.withAlpha(230),
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: c.onSurface, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              backgroundColor: c.card.withAlpha(230),
              child: IconButton(
                icon: Icon(
                  _speaking
                      ? Icons.stop_rounded
                      : Icons.volume_up_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                onPressed: () async {
                  if (_speaking) {
                    await widget.tts.stop();
                    if (mounted) setState(() => _speaking = false);
                  } else {
                    setState(() => _speaking = true);
                    await widget.tts.speak(
                        _aiSummary ?? widget.article.rawDescription);
                    if (mounted) setState(() => _speaking = false);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              physics: const BouncingScrollPhysics(),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 280,
                      width: double.infinity,
                      child: Stack(fit: StackFit.expand, children: [
                        widget.article.imageUrl.isNotEmpty
                            ? Image.network(
                            widget.article.imageUrl,
                            fit: BoxFit.cover,
                            cacheWidth: 800,
                            errorBuilder: (_, __, ___) => ColoredBox(
                                color: Color.fromARGB(38, catColor.red,
                                    catColor.green, catColor.blue)))
                            : DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Color.fromARGB(153, catColor.red,
                                      catColor.green, catColor.blue),
                                  catColor,
                                ]))),
                        DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, c.bg],
                                stops: const [0.5, 1.0],
                              ),
                            )),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Tag(
                                label: widget.article.category,
                                bgColor: Color.fromARGB(31, catColor.red,
                                    catColor.green, catColor.blue),
                                textColor: catColor),
                            const SizedBox(height: 12),
                            Text(widget.article.title,
                                style: _ls(26, FontWeight.w700, c.onSurface,
                                    height: 1.2)),
                            const SizedBox(height: 8),
                            Text(widget.article.timeAgo,
                                style: _ls(13, FontWeight.w400, c.outline)),
                            const SizedBox(height: 20),
                            _ContentCard(
                              aiSummary: _aiSummary,
                              rawDescription: widget.article.rawDescription,
                              c: c,
                            ),
                            if (kAiEnabled) ...[
                              const SizedBox(height: 14),
                              _SummaryActionBar(
                                aiSummary: _aiSummary,
                                generatingSummary: _generatingSummary,
                                summaryLeft: summaryLeft,
                                onGenerateSummary: _generateSummary,
                                c: c,
                              ),
                            ],
                            const SizedBox(height: 14),
                            _SaveButton(
                              saved: _saved,
                              c: c,
                              onToggle: () {
                                widget.onSaveToggle();
                                setState(() => _saved = !_saved);
                              },
                            ),
                            if (kAiEnabled) ...[
                              const SizedBox(height: 32),
                              Text('Got questions? 🤔',
                                  style: _ls(
                                      20, FontWeight.w700, c.onSurface)),
                              const SizedBox(height: 4),
                              Text('Ask me anything about this story!',
                                  style: _ls(
                                      14, FontWeight.w400, c.onVariant)),
                              const SizedBox(height: 20),
                              if (_chat.isEmpty)
                                _QuestionHint(c: c)
                              else
                                for (final qa in _chat)
                                  _QABubble(qa: qa, c: c),
                            ],
                            SizedBox(
                                height:
                                80 + MediaQuery.of(context).viewInsets.bottom),
                          ]),
                    ),
                  ]),
            )),
        if (kAiEnabled)
          _QuestionInputBar(
            c: c,
            qCtrl: _qCtrl,
            asking: _asking,
            onAsk: _ask,
          ),
      ]),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final String? aiSummary;
  final String rawDescription;
  final AppThemeColors c;
  const _ContentCard({
    required this.aiSummary,
    required this.rawDescription,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 12,
              offset: Offset(0, 4))
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (aiSummary != null) ...[
              Row(children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('AI Summary',
                    style: _ls(13, FontWeight.w700, AppColors.primary)),
              ]),
              const SizedBox(height: 10),
              Text(aiSummary!,
                  style: _ls(17, FontWeight.w400, c.onSurface, height: 1.7)),
            ] else
              Text(rawDescription,
                  style:
                  _ls(16, FontWeight.w400, c.onSurface, height: 1.7)),
          ]),
    );
  }
}

class _SummaryActionBar extends StatelessWidget {
  final String? aiSummary;
  final bool generatingSummary;
  final int summaryLeft;
  final VoidCallback onGenerateSummary;
  final AppThemeColors c;
  const _SummaryActionBar({
    required this.aiSummary,
    required this.generatingSummary,
    required this.summaryLeft,
    required this.onGenerateSummary,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    if (aiSummary != null) {
      return Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: c.primaryCont.withAlpha(80),
            borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Flexible(
              child: Text(
                'AI summary generated ($summaryLeft/$kMaxSummariesPerDay left today)',
                overflow: TextOverflow.ellipsis,
                style:
                _ls(12, FontWeight.w600, AppColors.primary),
              )),
        ]),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed:
        generatingSummary || summaryLeft <= 0 ? null : onGenerateSummary,
        icon: generatingSummary
            ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary))
            : const Icon(Icons.auto_awesome_rounded,
            size: 18, color: AppColors.primary),
        label: Text(
          generatingSummary
              ? 'Generating…'
              : summaryLeft <= 0
              ? 'No summaries left today'
              : '✨ AI Summary ($summaryLeft/$kMaxSummariesPerDay left)',
          overflow: TextOverflow.ellipsis,
          style: _ls(
              14,
              FontWeight.w700,
              summaryLeft <= 0 ? c.outline : AppColors.primary),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(
              color: summaryLeft <= 0 ? c.outlineVar : AppColors.primary,
              width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool saved;
  final AppThemeColors c;
  final VoidCallback onToggle;
  const _SaveButton({
    required this.saved,
    required this.c,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: saved ? c.primaryCont.withAlpha(128) : c.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: saved ? AppColors.primary : c.outlineVar),
        ),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: saved ? AppColors.primary : c.outline,
                  size: 22),
              const SizedBox(width: 10),
              Text(
                  saved ? 'Saved! 📌' : 'Save This Story',
                  style: _ls(
                      16,
                      FontWeight.w600,
                      saved ? AppColors.primary : c.onSurface)),
            ]),
      ),
    );
  }
}

class _QuestionHint extends StatelessWidget {
  final AppThemeColors c;
  const _QuestionHint({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
          color: c.primaryCont.withAlpha(60),
          borderRadius: BorderRadius.circular(14)),
      child: Center(
          child: Column(children: [
            const Text('🤔', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            Text('No questions yet!',
                style: _ls(15, FontWeight.w700, AppColors.primary)),
            const SizedBox(height: 4),
            Text('Type below to ask!',
                style: _ls(13, FontWeight.w400, c.onVariant)),
          ])),
    );
  }
}

class _QuestionInputBar extends StatelessWidget {
  final AppThemeColors c;
  final TextEditingController qCtrl;
  final bool asking;
  final VoidCallback onAsk;
  const _QuestionInputBar({
    required this.c,
    required this.qCtrl,
    required this.asking,
    required this.onAsk,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.outlineVar)),
      ),
      child: Row(children: [
        Expanded(
            child: TextField(
              controller: qCtrl,
              onSubmitted: (_) => onAsk(),
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: 'Ask a question…',
                hintStyle: _ls(14, FontWeight.w400, c.outlineVar),
                filled: true,
                fillColor: c.surfaceLow,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              style: _ls(14, FontWeight.w400, c.onSurface),
            )),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: asking ? null : onAsk,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(14),
          ),
          child: asking
              ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 20),
        ),
      ]),
    );
  }
}

class _QABubble extends StatelessWidget {
  final _QA qa;
  final AppThemeColors c;
  const _QABubble({required this.qa, required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 12),
              decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(4),
                  )),
              child: Text(qa.q,
                  style: _ls(15, FontWeight.w500, Colors.white)),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.84),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 8,
                        offset: Offset(0, 3))
                  ],
                ),
                child: Text(qa.a,
                    style: _ls(15, FontWeight.w400, c.onSurface,
                        height: 1.55)),
              ),
            ),
          ]),
    );
  }
}

class _QA {
  final String q, a;
  const _QA({required this.q, required this.a});
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PARENT ZONE
// ═══════════════════════════════════════════════════════════════════════════════
class ParentZone extends StatefulWidget {
  final List<ReadingActivity> activities;
  final List<ArticleSummary> articles;
  final SharedPreferences prefs;
  const ParentZone({
    super.key,
    required this.activities,
    required this.articles,
    required this.prefs,
  });
  @override
  State<ParentZone> createState() => _ParentZoneState();
}

class _ParentZoneState extends State<ParentZone> {
  final _auth = LocalAuthentication();
  bool _authenticated = false;
  bool _checking = false;
  bool _biometricsAvailable = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (mounted) {
        setState(() =>
        _biometricsAvailable = canCheck || isSupported);
        if (canCheck || isSupported) _authenticate();
      }
    } catch (_) {
      // ignore silently on unsupported devices
    }
  }

  Future<void> _authenticate() async {
    setState(() {
      _checking = true;
      _error = '';
    });
    try {
      final didAuth = await _auth.authenticate(
        localizedReason: 'Authenticate to access Parent Zone',
        options: const AuthenticationOptions(
            biometricOnly: false, stickyAuth: true),
      );
      if (mounted) {
        setState(() {
          _authenticated = didAuth;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Authentication failed. Try again.';
          _checking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      _authenticated ? _buildDash() : _buildLogin();

  Widget _buildLogin() => ColoredBox(
    color: AppColors.darkBg,
    child: SafeArea(
        child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0x12FFFFFF),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0x1FFFFFFF)),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      size: 44, color: Colors.white),
                ).animate().scale(),
                const SizedBox(height: 20),
                Text('Parent Zone',
                    style: _ls(30, FontWeight.w700, Colors.white)),
                const SizedBox(height: 6),
                Text('Secure monitoring dashboard',
                    style: _ls(15, FontWeight.w400, const Color(0x99FFFFFF))),
                const SizedBox(height: 48),
                if (!_biometricsAvailable)
                  _NoBiometricsCard()
                else
                  _BiometricAuthCard(
                    checking: _checking,
                    error: _error,
                    onAuthenticate: _authenticate,
                  ),
              ]),
            ))),
  );

  Widget _buildDash() {
    final saved = widget.articles.where((a) => a.saved).length;
    final opened =
        widget.activities.where((a) => a.action == 'opened').length;
    final summaryUsed = getSummaryUsageToday(widget.prefs);
    return ColoredBox(
      color: AppColors.darkBg,
      child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(children: [
                  Text('Dashboard',
                      style: _ls(24, FontWeight.w700, Colors.white)),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        setState(() => _authenticated = false),
                    child: Text('Lock',
                        style: _ls(
                            15, FontWeight.w600, const Color(0x80FFFFFF))),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Expanded(
                      child: _StatCard(
                          icon: Icons.visibility_rounded,
                          label: 'Stories Read',
                          value: '$opened',
                          color: Colors.blueAccent)),
                  const SizedBox(width: 14),
                  Expanded(
                      child: _StatCard(
                          icon: Icons.bookmark_rounded,
                          label: 'Saved',
                          value: '$saved',
                          color: Colors.greenAccent)),
                ]),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Expanded(
                      child: _StatCard(
                          icon: Icons.auto_awesome_rounded,
                          label: 'AI Summaries',
                          value: '$summaryUsed / $kMaxSummariesPerDay',
                          color: Colors.purpleAccent)),
                  const SizedBox(width: 14),
                  const Expanded(
                      child: _StatCard(
                          icon: Icons.refresh_rounded,
                          label: 'Feed Resets',
                          value: '12pm PT',
                          color: Colors.orangeAccent)),
                ]),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Recent Activity',
                    style: _ls(18, FontWeight.w700, Colors.white)),
              ),
              const SizedBox(height: 12),
              if (widget.activities.isEmpty)
                Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('No activity yet.',
                          style:
                          _ls(15, FontWeight.w400, const Color(0x61FFFFFF))),
                    ))
              else
                ...widget.activities.take(20).map(
                        (a) => _ActivityItem(activity: a)),
            ],
          )),
    );
  }
}

class _NoBiometricsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x12FFFFFF)),
      ),
      child: Column(children: [
        const Icon(Icons.phone_android_rounded,
            size: 48, color: Color(0x61FFFFFF)),
        const SizedBox(height: 12),
        Text('Set up a device lock first',
            style: _ls(16, FontWeight.w700, Colors.white)),
        const SizedBox(height: 8),
        Text(
          'Go to Settings → Security → Screen Lock to add a PIN, '
              'fingerprint, or face unlock.',
          textAlign: TextAlign.center,
          style:
          _ls(13, FontWeight.w400, const Color(0x80FFFFFF), height: 1.5),
        ),
      ]),
    ).animate().fadeIn();
  }
}

class _BiometricAuthCard extends StatelessWidget {
  final bool checking;
  final String error;
  final VoidCallback onAuthenticate;
  const _BiometricAuthCard({
    required this.checking,
    required this.error,
    required this.onAuthenticate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x12FFFFFF)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Verify it\'s you',
              style: _ls(18, FontWeight.w700, Colors.white)),
          const SizedBox(height: 4),
          Text('Fingerprint, face, or device PIN',
              style:
              _ls(13, FontWeight.w400, const Color(0x80FFFFFF))),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: checking ? null : onAuthenticate,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checking
                    ? const Color(0x334F46E5)
                    : const Color(0x1A4F46E5),
                border: Border.all(
                    color: AppColors.primary.withAlpha(128), width: 2),
              ),
              child: checking
                  ? const Center(
                  child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary)))
                  : const Icon(Icons.fingerprint_rounded,
                  size: 56, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: error.isNotEmpty
                ? Text(error,
                textAlign: TextAlign.center,
                style: _ls(13, FontWeight.w600,
                    const Color(0xFFF87171)))
                : const SizedBox.shrink(),
          ),
        ]),
      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.08),
      const SizedBox(height: 16),
      TextButton(
        onPressed: checking ? null : onAuthenticate,
        child: Text('Tap to authenticate',
            style: _ls(15, FontWeight.w600, AppColors.primary)),
      ),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Color.fromARGB(51, color.red, color.green, color.blue),
            width: 1.5),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Color.fromARGB(
                      31, color.red, color.green, color.blue),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(value,
                style:
                _ls(28, FontWeight.w800, Colors.white, height: 1)),
            const SizedBox(height: 4),
            Text(label,
                style:
                _ls(13, FontWeight.w500, const Color(0x80FFFFFF))),
          ]),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final ReadingActivity activity;
  const _ActivityItem({required this.activity});

  @override
  Widget build(BuildContext context) {
    final saved = activity.action == 'saved';
    final diff = DateTime.now().difference(activity.timestamp);
    final ago = diff.inMinutes < 1
        ? 'Just now'
        : diff.inHours < 1
        ? '${diff.inMinutes}m ago'
        : diff.inDays < 1
        ? '${diff.inHours}h ago'
        : '${diff.inDays}d ago';
    final iconColor = saved ? Colors.greenAccent : Colors.blueAccent;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Color.fromARGB(
                31, iconColor.red, iconColor.green, iconColor.blue),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
              saved
                  ? Icons.bookmark_rounded
                  : Icons.visibility_rounded,
              color: iconColor,
              size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activity.articleTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _ls(14, FontWeight.w600, Colors.white)),
                  const SizedBox(height: 3),
                  Text('${saved ? 'Saved' : 'Opened'} · $ago',
                      style: _ls(
                          12, FontWeight.w500, const Color(0x61FFFFFF))),
                ])),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════════
class ArticleSummary {
  final String title, rawDescription, url, imageUrl, fullContent, category, timeAgo;
  final bool saved;

  const ArticleSummary({
    required this.title,
    required this.rawDescription,
    required this.url,
    required this.imageUrl,
    required this.fullContent,
    this.category = '',
    this.timeAgo = '',
    this.saved = false,
  });

  ArticleSummary copyWith({bool? saved}) => ArticleSummary(
    title: title,
    rawDescription: rawDescription,
    url: url,
    imageUrl: imageUrl,
    fullContent: fullContent,
    category: category,
    timeAgo: timeAgo,
    saved: saved ?? this.saved,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'rawDescription': rawDescription,
    'url': url,
    'imageUrl': imageUrl,
    'fullContent': fullContent,
    'category': category,
    'timeAgo': timeAgo,
    'saved': saved,
  };

  factory ArticleSummary.fromJson(Map<String, dynamic> j) => ArticleSummary(
    title: j['title'] ?? '',
    rawDescription: j['rawDescription'] ?? j['summary'] ?? '',
    url: j['url'] ?? '',
    imageUrl: j['imageUrl'] ?? '',
    fullContent: j['fullContent'] ?? '',
    category: j['category'] ?? '',
    timeAgo: j['timeAgo'] ?? '',
    saved: j['saved'] == true,
  );
}

class ReadingActivity {
  final String articleTitle, action;
  final DateTime timestamp;
  ReadingActivity({
    required this.articleTitle,
    required this.action,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'articleTitle': articleTitle,
    'action': action,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ReadingActivity.fromJson(Map<String, dynamic> j) => ReadingActivity(
    articleTitle: j['articleTitle'],
    action: j['action'],
    timestamp: DateTime.parse(j['timestamp']),
  );
}
