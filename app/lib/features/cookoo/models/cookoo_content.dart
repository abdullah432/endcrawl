/// The COOKOO studio card in Settings: four slides about the studio that
/// makes LastReel, each leading to a short "tell us your idea" form.
///
/// Copy is fixed by the design handoff — no claims or numbers beyond what
/// is written here.
library;

/// One of the studio's apps, as it appears on a slide.
class CookooApp {
  final String name;
  final String asset;
  const CookooApp(this.name, this.asset);

  static const planformer = CookooApp('Planformer', 'assets/images/cookoo/planformer.png');
  static const happyKosher = CookooApp('HappyKosher', 'assets/images/cookoo/happykosher.png');
  static const autosaurus = CookooApp('Autosaurus', 'assets/images/cookoo/autosaurus.png');
}

/// What the person needs — the first question on the contact form.
enum CookooNeed {
  newApp('new_app', 'A new app'),
  business('business', 'Software for my business'),
  help('help', 'Help with my app'),
  notSure('not_sure', 'Not sure yet');

  final String wire;
  final String label;
  const CookooNeed(this.wire, this.label);
}

/// Budget ranges, matching the cookoo.dev form.
enum CookooBudget {
  notSure('not_sure', 'Not sure yet'),
  lt5k('lt5k', r'Under $5,000'),
  k5to15('5k_15k', r'$5,000–$15,000'),
  k15to30('15k_30k', r'$15,000–$30,000'),
  gt30k('gt30k', r'$30,000+');

  final String wire;
  final String label;
  const CookooBudget(this.wire, this.label);
}

class CookooSlide {
  /// `s1`…`s4` — the contact form's `source` and the analytics key.
  final String id;
  final String headline;

  /// The app the slide is about; null on the track-record slide.
  final CookooApp? app;
  final String? category;
  final String? result;
  final List<String> tags;
  final String footer;

  /// The case study the footer links to, if it links anywhere.
  final String? caseSlug;

  /// Preselected on the contact form when it is opened from this slide.
  final CookooNeed need;

  const CookooSlide({
    required this.id,
    required this.headline,
    required this.footer,
    this.app,
    this.category,
    this.result,
    this.tags = const [],
    this.caseSlug,
    this.need = CookooNeed.newApp,
  });
}

/// The track-record rows on slide 1.
const cookooTrackRecord = [
  (CookooApp.planformer, 'Building app'),
  (CookooApp.happyKosher, 'Food delivery in New York'),
  (CookooApp.autosaurus, 'Driving test practice'),
];

const cookooSlides = [
  CookooSlide(id: 's1', headline: 'We build apps people use and pay for.', footer: '+ MAASER, TEXTCRAWL AND MORE'),
  CookooSlide(
    id: 's2',
    app: CookooApp.planformer,
    category: 'CONSTRUCTION',
    headline: 'One team. Six platforms. Designed, built and run by us.',
    result: 'Thousands of dollars a month in recurring revenue.',
    footer: 'SEE THE FULL STORY · COOKOO.DEV/CASES',
    caseSlug: 'planformer',
  ),
  CookooSlide(
    id: 's3',
    app: CookooApp.happyKosher,
    category: 'FOOD DELIVERY · NEW YORK',
    headline: 'A delivery service with four apps, built and run by us.',
    tags: ['Customer app', 'Restaurant app', 'Web + admin'],
    footer: 'SEE THE FULL STORY · COOKOO.DEV/CASES',
    caseSlug: 'happykosher',
  ),
  CookooSlide(
    id: 's4',
    app: CookooApp.autosaurus,
    category: 'LEARNING · DRIVING THEORY',
    headline: 'Driving theory, turned into a game people keep playing.',
    tags: ['1,400+ questions', 'Live races', 'Leagues'],
    footer: 'SEE THE FULL STORY · COOKOO.DEV/CASES',
    caseSlug: 'autosaurus',
  ),
];
