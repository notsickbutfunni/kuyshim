/// Localization strings.
/// Supports Kazakh (kz), English (en), and Russian (ru).
library;

class AppStrings {
  // ── Onboarding ─────────────────────────────────────────────
  final String appTitle;
  final String appSubtitle;
  final String startPlaying;
  final String signIn;
  final String createAccount;
  final String backendOffline;
  final String signingIn;
  final String creating;
  final String username;
  final String email;
  final String password;
  final String newPassword;
  final String forgotPassword;
  final String resetPassword;
  final String resetting;
  final String resetPasswordDesc;
  final String passwordResetDone;
  final String passwordResetDoneDesc;
  final String signInNow;
  final String back;
  final String backToSignIn;
  final String loginFailed;
  final String registrationFailed;
  final String resetFailed;
  final String tradition;
  final String technology;
  final String mastery;

  // ── Library ────────────────────────────────────────────────
  final String libraryTitle;
  final String welcomeBack;
  final String guestAccess;
  final String beginner;
  final String pro;
  final String completed;
  final String inProgress;
  final String newLabel;
  final String noLessonsFound;
  final String beginnerHint;
  final String proHint;
  final String signInToPlay;
  final String startPractice;
  final String practiceAgain;
  final String continueLabel;
  final String totalLessons;

  // ── Game ───────────────────────────────────────────────────
  final String currentKui;
  final String score;
  final String combo;
  final String by;
  final String level;
  final String perfect;
  final String good;
  final String miss;
  final String restartTooltip;

  // ── Results ────────────────────────────────────────────────
  final String performanceRank;
  final String finalScore;
  final String analysis;
  final String smartSuggestion;
  final String saveProgress;
  final String saveProgressDesc;
  final String nextLesson;
  final String restart;
  final String menu;
  final String share;

  // ── Profile ────────────────────────────────────────────────
  final String rank;
  final String progressTo;
  final String guestProfileHint;
  final String startLearning;
  final String logOut;
  final String detailedAnalytics;
  final String avgBpm;
  final String accuracy;
  final String yourAchievements;
  final String playToUnlock;
  final String activityTracker;
  final String totalHours;
  final String streak;
  final String days;
  final String accountSettings;
  final String profileDetails;
  final String profileDetailsSub;
  final String security;
  final String securitySub;
  final String notifications;
  final String notificationsSub;
  final String saveChanges;
  final String language;
  final String languageSub;

  // ── Tuner / Recognition ────────────────────────────────────
  final String precisionTuner;
  final String startListening;
  final String playAString;
  final String perfectTune;
  final String tuneDown;
  final String tightenSlightly;
  final String upperString;
  final String lowerString;
  final String bottomString;
  final String topString;
  final String reference;
  final String kuiRecognition;
  final String tapToRecognize;
  final String recording;
  final String analyzingAudio;
  final String chordDetected;
  final String confidence;
  final String topPredictions;
  final String mlOffline;
  final String tryAgain;
  final String recordingSeconds;
  final String noMicrophone;

  // ── Badges ─────────────────────────────────────────────────
  final String badgeFirstSteps;
  final String badgeLearner;
  final String badgeTalent;
  final String badgeKuishi;
  final String locked;

  // ── Dialog / Modes ─────────────────────────────────────────
  final String selectMode;
  final String trainingMode;
  final String trainingModeDesc;
  final String competitiveMode;
  final String competitiveModeDesc;
  final String storyMode;
  final String storyModeDesc;
  final String startTraining;
  final String onlineOnly;
  final String newToDombra;
  final String alreadyKnowDombra;

  // ── Calibration ────────────────────────────────────────────
  final String dombraTuning;
  final String dombraTuningSub;
  final String calibrateNow;
  final String calibrationComplete;
  final String playOpenBass;
  final String playOpenTreble;
  final String resetCalibration;
  final String standardTuning;
  final String centsSharp;
  final String centsFlat;
  final String calibrating;

  // ── Game Countdown ─────────────────────────────────────────
  final String getReady;

  // ── General / Actions ──────────────────────────────────────
  final String cancel;
  final String done;

  // ── Localized lesson titles (keyed by lesson ID) ──────────
  /// Returns localized lesson title for a given lesson ID.
  /// Falls back to the original title if ID not found.
  final Map<String, String> lessonTitles;
  final Map<String, String> lessonDescriptions;
  final Map<String, String> lessonComposers;

  // ── Learning Path ───────────────────────────────────────────
  final String learningPath;
  final String module;
  final String theBasics;
  final String masterFoundation;
  final String upstrokes;
  final String learnAlternatePicking;
  final String donePercentage;
  final String songTag;
  final String skillTag;
  final String videoTag;
  final String videoIntroTitle;
  final String videoIntroDescription;
  final String watchVideo;
  final String skipVideo;
  final Map<String, String> learnNodeTitles;
  final Map<String, String> learnNodeDescriptions;
  final Map<String, String> learnNodeStories;

  const AppStrings({
    required this.appTitle,
    required this.appSubtitle,
    required this.startPlaying,
    required this.signIn,
    required this.createAccount,
    required this.backendOffline,
    required this.signingIn,
    required this.creating,
    required this.username,
    required this.email,
    required this.password,
    required this.newPassword,
    required this.forgotPassword,
    required this.resetPassword,
    required this.resetting,
    required this.resetPasswordDesc,
    required this.passwordResetDone,
    required this.passwordResetDoneDesc,
    required this.signInNow,
    required this.back,
    required this.backToSignIn,
    required this.loginFailed,
    required this.registrationFailed,
    required this.resetFailed,
    required this.tradition,
    required this.technology,
    required this.mastery,
    required this.libraryTitle,
    required this.welcomeBack,
    required this.guestAccess,
    required this.beginner,
    required this.pro,
    required this.completed,
    required this.inProgress,
    required this.newLabel,
    required this.noLessonsFound,
    required this.beginnerHint,
    required this.proHint,
    required this.signInToPlay,
    required this.startPractice,
    required this.practiceAgain,
    required this.continueLabel,
    required this.totalLessons,
    required this.currentKui,
    required this.score,
    required this.combo,
    required this.by,
    required this.level,
    required this.perfect,
    required this.good,
    required this.miss,
    required this.restartTooltip,
    required this.performanceRank,
    required this.finalScore,
    required this.analysis,
    required this.smartSuggestion,
    required this.saveProgress,
    required this.saveProgressDesc,
    required this.nextLesson,
    required this.restart,
    required this.menu,
    required this.share,
    required this.rank,
    required this.progressTo,
    required this.guestProfileHint,
    required this.startLearning,
    required this.logOut,
    required this.detailedAnalytics,
    required this.avgBpm,
    required this.accuracy,
    required this.yourAchievements,
    required this.playToUnlock,
    required this.activityTracker,
    required this.totalHours,
    required this.streak,
    required this.days,
    required this.accountSettings,
    required this.profileDetails,
    required this.profileDetailsSub,
    required this.security,
    required this.securitySub,
    required this.notifications,
    required this.notificationsSub,
    required this.saveChanges,
    required this.language,
    required this.languageSub,
    required this.precisionTuner,
    required this.startListening,
    required this.playAString,
    required this.perfectTune,
    required this.tuneDown,
    required this.tightenSlightly,
    required this.upperString,
    required this.lowerString,
    required this.bottomString,
    required this.topString,
    required this.reference,
    required this.kuiRecognition,
    required this.tapToRecognize,
    required this.recording,
    required this.analyzingAudio,
    required this.chordDetected,
    required this.confidence,
    required this.topPredictions,
    required this.mlOffline,
    required this.tryAgain,
    required this.recordingSeconds,
    required this.noMicrophone,
    required this.badgeFirstSteps,
    required this.badgeLearner,
    required this.badgeTalent,
    required this.badgeKuishi,
    required this.locked,
    required this.selectMode,
    required this.trainingMode,
    required this.trainingModeDesc,
    required this.competitiveMode,
    required this.competitiveModeDesc,
    required this.storyMode,
    required this.storyModeDesc,
    required this.startTraining,
    required this.onlineOnly,
    required this.newToDombra,
    required this.alreadyKnowDombra,
    required this.dombraTuning,
    required this.dombraTuningSub,
    required this.calibrateNow,
    required this.calibrationComplete,
    required this.playOpenBass,
    required this.playOpenTreble,
    required this.resetCalibration,
    required this.standardTuning,
    required this.centsSharp,
    required this.centsFlat,
    required this.calibrating,
    required this.getReady,
    required this.cancel,
    required this.done,
    this.lessonTitles = const {},
    this.lessonDescriptions = const {},
    this.lessonComposers = const {},
    required this.learningPath,
    required this.module,
    required this.theBasics,
    required this.masterFoundation,
    required this.upstrokes,
    required this.learnAlternatePicking,
    required this.donePercentage,
    required this.songTag,
    required this.skillTag,
    required this.videoTag,
    required this.videoIntroTitle,
    required this.videoIntroDescription,
    required this.watchVideo,
    required this.skipVideo,
    this.learnNodeTitles = const {},
    this.learnNodeDescriptions = const {},
    this.learnNodeStories = const {},
  });
}

// ═══════════════════════════════════════════════════════════════
// ENGLISH
// ═══════════════════════════════════════════════════════════════
const AppStrings en = AppStrings(
  appTitle: 'Kuyshim',
  appSubtitle: 'Master the ancient art of the Dombra with real-time AI feedback.',
  startPlaying: 'Start Playing',
  signIn: 'Sign In',
  createAccount: 'Create Account',
  backendOffline: 'Backend offline — guest mode only',
  signingIn: 'Signing in...',
  creating: 'Creating...',
  username: 'Username',
  email: 'Email',
  password: 'Password',
  newPassword: 'New Password',
  forgotPassword: 'Forgot Password?',
  resetPassword: 'Reset Password',
  resetting: 'Resetting...',
  resetPasswordDesc: 'Enter your username and email to verify your identity',
  passwordResetDone: 'Password Reset!',
  passwordResetDoneDesc: 'Your password has been updated successfully. You can now sign in with your new password.',
  signInNow: 'Sign In Now',
  back: '← Back',
  backToSignIn: '← Back to Sign In',
  loginFailed: 'Login failed',
  registrationFailed: 'Registration failed',
  resetFailed: 'Password reset failed',
  tradition: 'Tradition',
  technology: 'Technology',
  mastery: 'Mastery',
  libraryTitle: 'Kuyshim Library',
  welcomeBack: 'Welcome back',
  guestAccess: 'Guest Access: 1 Lesson Available',
  beginner: 'Beginner',
  pro: 'Pro',
  completed: 'Completed',
  inProgress: 'In Progress',
  newLabel: 'New',
  noLessonsFound: 'No lessons found',
  beginnerHint: 'Beginner lessons will appear here once loaded from the server.',
  proHint: 'Pro lessons will appear here once loaded from the server.',
  signInToPlay: 'Sign in to play',
  startPractice: 'Start Practice',
  practiceAgain: 'Practice Again',
  continueLabel: 'Continue',
  totalLessons: 'total lessons',
  currentKui: 'Current Küi',
  score: 'Score',
  combo: 'Combo',
  by: 'by',
  level: 'Level',
  perfect: 'Perfect',
  good: 'Good',
  miss: 'Miss',
  restartTooltip: 'Restart from beginning',
  performanceRank: 'Performance Rank',
  finalScore: 'Final Score',
  analysis: 'Analysis',
  smartSuggestion: 'Smart Suggestion',
  saveProgress: 'Want to save this progress?',
  saveProgressDesc: 'Create an account to track your mastery.',
  nextLesson: 'Next Lesson',
  restart: 'Restart',
  menu: 'Menu',
  share: 'Share',
  rank: 'Rank',
  progressTo: 'Progress to',
  guestProfileHint: 'Your journey begins here. Play your first küi to unlock stats and track your progress.',
  startLearning: 'Start Learning',
  logOut: 'Log Out',
  detailedAnalytics: 'Detailed Analytics',
  avgBpm: 'Avg BPM',
  accuracy: 'Accuracy',
  yourAchievements: 'Your Achievements',
  playToUnlock: 'Play to unlock',
  activityTracker: 'Activity Tracker',
  totalHours: 'Total Hours',
  streak: 'Streak',
  days: 'Days',
  accountSettings: 'Account Settings',
  profileDetails: 'Profile Details',
  profileDetailsSub: 'Name, Avatar, Bio',
  security: 'Security',
  securitySub: 'Password, 2FA, Sessions',
  notifications: 'Notifications',
  notificationsSub: 'Practice reminders, News',
  saveChanges: 'Save Changes',
  language: 'Language',
  languageSub: 'Change application language',
  precisionTuner: 'Precision Tuner',
  startListening: 'Start Listening',
  playAString: 'Play a string...',
  perfectTune: 'Perfect!',
  tuneDown: 'Tune down',
  tightenSlightly: 'Tighten slightly',
  upperString: 'Upper String',
  lowerString: 'Lower String',
  bottomString: 'Bottom String (Астыңғы ішек)',
  topString: 'Top String (Үстіңгі ішек)',
  reference: 'Reference',
  kuiRecognition: 'Küi Recognition',
  tapToRecognize: 'Tap to recognize',
  recording: 'Recording...',
  analyzingAudio: 'Analyzing audio...',
  chordDetected: 'Chord Detected',
  confidence: 'Confidence',
  topPredictions: 'Top Predictions',
  mlOffline: 'ML service offline',
  tryAgain: 'Try Again',
  recordingSeconds: 'seconds',
  noMicrophone: 'Microphone not available',
  badgeFirstSteps: 'First Steps',
  badgeLearner: 'Learner',
  badgeTalent: 'Talent',
  badgeKuishi: 'Küishi',
  locked: 'Locked',
  selectMode: 'Select Mode',
  trainingMode: 'Learning Mode',
  trainingModeDesc: 'Waits until you play\nthe correct notes',
  competitiveMode: 'Competitive',
  competitiveModeDesc: 'Real game with\nfinal scores',
  storyMode: 'Story',
  storyModeDesc: 'History and culture\nof this küy',
  startTraining: 'Start Training',
  onlineOnly: 'Online only',
  newToDombra: 'I am new to Dombra',
  alreadyKnowDombra: 'I already know how to play',
  dombraTuning: 'Dombra Tuning',
  dombraTuningSub: 'Calibrate your instrument',
  calibrateNow: 'Calibrate Now',
  calibrationComplete: 'Calibration Complete!',
  playOpenBass: 'Play your top string — Үстіңгі ішек (D3)',
  playOpenTreble: 'Play your bottom string — Астыңғы ішек (G3)',
  resetCalibration: 'Reset to Standard',
  standardTuning: 'Standard Tuning — Оң бұрау (G3-D3)',
  centsSharp: 'cents sharp',
  centsFlat: 'cents flat',
  calibrating: 'Listening...',
  getReady: 'GET READY',
  cancel: 'Cancel',
  done: 'Done',
  lessonTitles: {
    'b1': 'Ak Zhunis',
    'b2': 'Ken Zhailau',
    'b3': 'Saryzhailau',
    'b4': 'Kelinshek Kuyi',
    'b5': 'Kozimnin Karasy',
  },
  lessonDescriptions: {
    'b1': 'A gentle küi that praises Ak Zhunis. Develops strumming technique.',
    'b2': 'A calm küi depicting the beauty of the vast steppe.',
    'b3': 'A shertpe küi conveying the elegance of Saryzhailau.',
    'b4': 'A light and playful küi. Perfect for beginners.',
    'b5': 'A simplified version of Abai\'s famous song.',
  },
  lessonComposers: {
    'b1': 'Folk küi',
    'b2': 'Folk küi',
    'b3': 'Tattimbet Kazangapuly',
    'b4': 'Folk küi',
    'b5': 'Abai Kunanbayuly',
  },
  learningPath: 'Learning Path',
  module: 'MODULE',
  theBasics: 'The Basics',
  masterFoundation: 'Master the foundation of Dombra play',
  upstrokes: 'Upstrokes',
  learnAlternatePicking: 'Learn alternate picking techniques',
  donePercentage: '% Done',
  songTag: 'SONG',
  skillTag: 'SKILL',
  videoTag: 'VIDEO',
  videoIntroTitle: 'How Notes Work',
  videoIntroDescription: 'Watch a short video explaining how the digital notes and tuner work.',
  watchVideo: 'Watch Video',
  skipVideo: 'Skip',
  learnNodeTitles: {
    'node_1_meet': 'Meet Your Dombra',
    'node_2_frets': 'First Frets',
    'node_3_erkem_1': 'Erkem-ai: Measure 1',
    'node_3_erkem_2': 'Erkem-ai: Measure 2',
    'node_3_erkem_3': 'Erkem-ai: Measure 3',
    'node_3_erkem_4': 'Erkem-ai: Measure 4',
    'node_3_erkem_full': 'Erkem-ai: Full Song',
    'node_4_upstrokes': 'Upstrokes',
    'node_5_kenes': 'Kenes',
  },
  learnNodeDescriptions: {
    'node_1_meet': 'Learn to play the open strings (D3 and G3).',
    'node_2_frets': 'Press the 2nd and 4th frets on the bottom string.',
    'node_3_erkem_1': 'Learn the first measure of Erkem-ai.',
    'node_3_erkem_2': 'Learn the second measure of Erkem-ai.',
    'node_3_erkem_3': 'Learn the third measure of Erkem-ai.',
    'node_3_erkem_4': 'Learn the fourth measure of Erkem-ai.',
    'node_3_erkem_full': 'Play the complete version of Erkem-ai!',
    'node_4_upstrokes': 'Learn alternate picking: down-up-down-up.',
    'node_5_kenes': 'A traditional song to practice your upstrokes.',
  },
  learnNodeStories: {
    'node_3_erkem_1': 'In the vast steppes, nomads carried their culture through music. "Erkem-ai" is a gentle melody often played for loved ones. Let\'s play it together.',
    'node_3_erkem_2': 'In the vast steppes, nomads carried their culture through music. "Erkem-ai" is a gentle melody often played for loved ones. Let\'s play it together.',
    'node_3_erkem_3': 'In the vast steppes, nomads carried their culture through music. "Erkem-ai" is a gentle melody often played for loved ones. Let\'s play it together.',
    'node_3_erkem_4': 'In the vast steppes, nomads carried their culture through music. "Erkem-ai" is a gentle melody often played for loved ones. Let\'s play it together.',
    'node_3_erkem_full': 'You have learned all the pieces! Now combine them to play the complete "Erkem-ai" and feel the spirit of the steppes.',
    'node_5_kenes': '"Kenes" means council or conversation. This piece mimics a lively discussion between elders. Use your newly learned upstrokes to keep up the pace!',
  },
);

// ═══════════════════════════════════════════════════════════════
// KAZAKH
// ═══════════════════════════════════════════════════════════════
const AppStrings kz = AppStrings(
  appTitle: 'Күйшім',
  appSubtitle: 'Домбыра өнерін жасанды интеллект көмегімен меңгеріңіз.',
  startPlaying: 'Ойнауды бастау',
  signIn: 'Кіру',
  createAccount: 'Тіркелу',
  backendOffline: 'Сервер қолжетімсіз — тек қонақ режимі',
  signingIn: 'Кіру...',
  creating: 'Тіркелу...',
  username: 'Пайдаланушы аты',
  email: 'Электрондық пошта',
  password: 'Құпия сөз',
  newPassword: 'Жаңа құпия сөз',
  forgotPassword: 'Құпия сөзді ұмыттыңыз ба?',
  resetPassword: 'Құпия сөзді қалпына келтіру',
  resetting: 'Қалпына келтіру...',
  resetPasswordDesc: 'Жеке басыңызды растау үшін пайдаланушы атын және электрондық поштаны енгізіңіз',
  passwordResetDone: 'Құпия сөз қалпына келтірілді!',
  passwordResetDoneDesc: 'Құпия сөзіңіз сәтті жаңартылды. Енді жаңа құпия сөзбен кіре аласыз.',
  signInNow: 'Қазір кіру',
  back: '← Артқа',
  backToSignIn: '← Кіру бетіне',
  loginFailed: 'Кіру сәтсіз аяқталды',
  registrationFailed: 'Тіркелу сәтсіз аяқталды',
  resetFailed: 'Құпия сөзді қалпына келтіру сәтсіз',
  tradition: 'Дәстүр',
  technology: 'Технология',
  mastery: 'Шеберлік',
  libraryTitle: 'Күйшім кітапханасы',
  welcomeBack: 'Қайтадан қош келдіңіз',
  guestAccess: 'Қонақ режимі: 1 сабақ қолжетімді',
  beginner: 'Бастаушы',
  pro: 'Кәсіби',
  completed: 'Аяқталды',
  inProgress: 'Орындалуда',
  newLabel: 'Жаңа',
  noLessonsFound: 'Сабақтар табылмады',
  beginnerHint: 'Бастаушы сабақтар серверден жүктелген соң осында пайда болады.',
  proHint: 'Кәсіби сабақтар серверден жүктелген соң осында пайда болады.',
  signInToPlay: 'Ойнау үшін кіріңіз',
  startPractice: 'Жаттығуды бастау',
  practiceAgain: 'Қайта жаттығу',
  continueLabel: 'Жалғастыру',
  totalLessons: 'барлық сабақтар',
  currentKui: 'Ағымдағы күй',
  score: 'Ұпай',
  combo: 'Комбо',
  by: 'Орындаушы',
  level: 'Деңгей',
  perfect: 'Тамаша',
  good: 'Жақсы',
  miss: 'Өткізіп жіберу',
  restartTooltip: 'Басынан бастау',
  performanceRank: 'Орындау деңгейі',
  finalScore: 'Жалпы ұпай',
  analysis: 'талдау',
  smartSuggestion: 'Ақылды кеңес',
  saveProgress: 'Нәтижені сақтағыңыз келе ме?',
  saveProgressDesc: 'Жетістіктеріңізді бақылау үшін тіркеліңіз.',
  nextLesson: 'Келесі сабақ',
  restart: 'Қайта бастау',
  menu: 'Мәзір',
  share: 'Бөлісу',
  rank: 'Дәреже',
  progressTo: 'Деңгейге дейін',
  guestProfileHint: 'Сіздің саяхатыңыз осы жерден басталады. Статистиканы ашу үшін бірінші күйді ойнаңыз.',
  startLearning: 'Үйренуді бастау',
  logOut: 'Шығу',
  detailedAnalytics: 'Толық аналитика',
  avgBpm: 'Орт. BPM',
  accuracy: 'Дәлдік',
  yourAchievements: 'Сіздің жетістіктеріңіз',
  playToUnlock: 'Ашу үшін ойнаңыз',
  activityTracker: 'Белсенділік',
  totalHours: 'Жалпы сағат',
  streak: 'Серия',
  days: 'Күн',
  accountSettings: 'Аккаунт баптаулары',
  profileDetails: 'Профиль',
  profileDetailsSub: 'Аты, Аватар, Био',
  security: 'Қауіпсіздік',
  securitySub: 'Құпия сөз, 2FA, Сессиялар',
  notifications: 'Хабарландырулар',
  notificationsSub: 'Жаттығу еске салғыштары, Жаңалықтар',
  saveChanges: 'Сақтау',
  language: 'Тіл',
  languageSub: 'Қосымша тілін өзгерту',
  precisionTuner: 'Дәл тюнер',
  startListening: 'Тыңдауды бастау',
  playAString: 'Ішекті тартыңыз...',
  perfectTune: 'Тамаша!',
  tuneDown: 'Бұрауды босатыңыз',
  tightenSlightly: 'Аздап қатайтыңыз',
  upperString: 'Жоғарғы ішек',
  lowerString: 'Төменгі ішек',
  bottomString: 'Астыңғы ішек (әуен ішегі)',
  topString: 'Үстіңгі ішек (бұрау ішегі)',
  reference: 'Анықтама',
  kuiRecognition: 'Күй тану',
  tapToRecognize: 'Тану үшін басыңыз',
  recording: 'Жазып алу...',
  analyzingAudio: 'Аудио талданып жатыр...',
  chordDetected: 'Аккорд анықталды',
  confidence: 'Сенімділік',
  topPredictions: 'Үздік болжамдар',
  mlOffline: 'ML сервисі қолжетімсіз',
  tryAgain: 'Қайталау',
  recordingSeconds: 'секунд',
  noMicrophone: 'Микрофон қолжетімсіз',
  badgeFirstSteps: 'Тәй-тәй',
  badgeLearner: 'Үйренуші',
  badgeTalent: 'Өнерпаз',
  badgeKuishi: 'Күйші',
  locked: 'Жабық',
  selectMode: 'Режимді таңдаңыз',
  trainingMode: 'Үйрену режимі',
  trainingModeDesc: 'Ноталарды дұрыс\nбасқанша күтеді',
  competitiveMode: 'Жарыс',
  competitiveModeDesc: 'Ұпай саналатын\nнағыз ойын',
  storyMode: 'Тарих',
  storyModeDesc: 'Күйдің тарихы\nмен мәдениеті',
  startTraining: 'Жаттығуды бастау',
  onlineOnly: 'Тек онлайн',
  newToDombra: 'Мен домбыра тарта алмаймын',
  alreadyKnowDombra: 'Мен домбыра тарта аламын',
  dombraTuning: 'Домбыра баптау',
  dombraTuningSub: 'Аспапты калибрлеу',
  calibrateNow: 'Калибрлеу',
  calibrationComplete: 'Калибрлеу аяқталды!',
  playOpenBass: 'Үстіңгі ішекті тартыңыз (D3)',
  playOpenTreble: 'Астыңғы ішекті тартыңыз (G3)',
  resetCalibration: 'Стандартқа қайтару',
  standardTuning: 'Оң бұрау (G3-D3)',
  centsSharp: 'цент жоғары',
  centsFlat: 'цент төмен',
  calibrating: 'Тыңдалуда...',
  getReady: 'ДАЙЫНДАЛЫҢЫЗ',
  cancel: 'Болдырмау',
  done: 'Дайын',
  lessonTitles: {
    'b1': 'Ақ жүніс',
    'b2': 'Кең жайлау',
    'b3': 'Сарыжайлау',
    'b4': 'Келіншек күйі',
    'b5': 'Көзімнің қарасы',
  },
  lessonDescriptions: {
    'b1': 'Ақ жүністі жырлайтын жеңіл күй. Қағу техникасын дамытады.',
    'b2': 'Кең жайлаудың сұлулығын суреттейтін тыныш күй.',
    'b3': 'Сарыжайлаудың көркемдігін жеткізетін шертпе күй.',
    'b4': 'Жеңіл әрі ойнақы күй. Бастауыштарға өте қолайлы.',
    'b5': 'Абайдың әйгілі әнінің оңайлатылған нұсқасы.',
  },
  lessonComposers: {
    'b1': 'Халық күйі',
    'b2': 'Халық күйі',
    'b3': 'Тәттімбет Қазанғапұлы',
    'b4': 'Халық күйі',
    'b5': 'Абай Құнанбайұлы',
  },
  learningPath: 'Оқу жолы',
  module: 'МОДУЛЬ',
  theBasics: 'Негіздер',
  masterFoundation: 'Домбыра тартудың негіздерін меңгеріңіз',
  upstrokes: 'Жоғары қағыс',
  learnAlternatePicking: 'Алмазек қағу техникасын үйреніңіз',
  donePercentage: '% Дайын',
  songTag: 'КҮЙ',
  skillTag: 'ДАҒДЫ',
  videoTag: 'БЕЙНЕ',
  videoIntroTitle: 'Ноталар қалай жұмыс істейді',
  videoIntroDescription: 'Сандық ноталар мен тюнердің қалай жұмыс істейтінін түсіндіретін қысқа бейнені көріңіз.',
  watchVideo: 'Бейнені көру',
  skipVideo: 'Өткізіп жіберу',
  learnNodeTitles: {
    'node_1_meet': 'Домбырамен танысу',
    'node_2_frets': 'Алғашқы пернелер',
    'node_3_erkem_1': 'Еркем-ай: 1-такт',
    'node_3_erkem_2': 'Еркем-ай: 2-такт',
    'node_3_erkem_3': 'Еркем-ай: 3-такт',
    'node_3_erkem_4': 'Еркем-ай: 4-такт',
    'node_3_erkem_full': 'Еркем-ай: Толық күй',
    'node_4_upstrokes': 'Жоғары қағыс',
    'node_5_kenes': 'Кеңес',
  },
  learnNodeDescriptions: {
    'node_1_meet': 'Ашық ішектерді тартуды үйреніңіз (D3 және G3).',
    'node_2_frets': 'Астыңғы ішекте 2-ші және 4-ші пернелерді басыңыз.',
    'node_3_erkem_1': 'Еркем-айдың бірінші тактісін үйреніңіз.',
    'node_3_erkem_2': 'Еркем-айдың екінші тактісін үйреніңіз.',
    'node_3_erkem_3': 'Еркем-айдың үшінші тактісін үйреніңіз.',
    'node_3_erkem_4': 'Еркем-айдың төртінші тактісін үйреніңіз.',
    'node_3_erkem_full': 'Еркем-ай күйінің толық нұсқасын ойнаңыз!',
    'node_4_upstrokes': 'Алмазек қағуды үйреніңіз: төмен-жоғары-төмен-жоғары.',
    'node_5_kenes': 'Жоғары қағысты жаттықтыру үшін дәстүрлі күй.',
  },
  learnNodeStories: {
    'node_3_erkem_1': 'Ұлан-ғайыр далада көшпенділер мәдениетін музыка арқылы жеткізген. "Еркем-ай" - жақындарына арналған нәзік әуен. Бірге ойнап көрейік.',
    'node_3_erkem_2': 'Ұлан-ғайыр далада көшпенділер мәдениетін музыка арқылы жеткізген. "Еркем-ай" - жақындарына арналған нәзік әуен. Бірге ойнап көрейік.',
    'node_3_erkem_3': 'Ұлан-ғайыр далада көшпенділер мәдениетін музыка арқылы жеткізген. "Еркем-ай" - жақындарына арналған нәзік әуен. Бірге ойнап көрейік.',
    'node_3_erkem_4': 'Ұлан-ғайыр далада көшпенділер мәдениетін музыка арқылы жеткізген. "Еркем-ай" - жақындарына арналған нәзік әуен. Бірге ойнап көрейік.',
    'node_3_erkem_full': 'Сіз барлық бөліктерді үйрендіңіз! Енді оларды біріктіріп, толық "Еркем-ай" күйін ойнаңыз.',
    'node_5_kenes': '"Кеңес" - ақсақалдардың қызу пікірталасын бейнелейтін күй. Оны жаңа үйренген қағыстарыңызбен ойнап көріңіз!',
  },
);

// ═══════════════════════════════════════════════════════════════
// RUSSIAN
// ═══════════════════════════════════════════════════════════════
const AppStrings ru = AppStrings(
  appTitle: 'Күйшім',
  appSubtitle: 'Освойте древнее искусство домбры с помощью ИИ в реальном времени.',
  startPlaying: 'Начать играть',
  signIn: 'Войти',
  createAccount: 'Создать аккаунт',
  backendOffline: 'Сервер недоступен — только гостевой режим',
  signingIn: 'Вход...',
  creating: 'Создание...',
  username: 'Имя пользователя',
  email: 'Электронная почта',
  password: 'Пароль',
  newPassword: 'Новый пароль',
  forgotPassword: 'Забыли пароль?',
  resetPassword: 'Сбросить пароль',
  resetting: 'Сброс...',
  resetPasswordDesc: 'Введите имя пользователя и email для подтверждения личности',
  passwordResetDone: 'Пароль сброшен!',
  passwordResetDoneDesc: 'Ваш пароль был успешно обновлён. Теперь вы можете войти с новым паролем.',
  signInNow: 'Войти сейчас',
  back: '← Назад',
  backToSignIn: '← Вернуться ко входу',
  loginFailed: 'Ошибка входа',
  registrationFailed: 'Ошибка регистрации',
  resetFailed: 'Ошибка сброса пароля',
  tradition: 'Традиция',
  technology: 'Технология',
  mastery: 'Мастерство',
  libraryTitle: 'Библиотека Күйшім',
  welcomeBack: 'С возвращением',
  guestAccess: 'Гостевой режим: доступен 1 урок',
  beginner: 'Начинающий',
  pro: 'Продвинутый',
  completed: 'Завершено',
  inProgress: 'В процессе',
  newLabel: 'Новый',
  noLessonsFound: 'Уроки не найдены',
  beginnerHint: 'Уроки для начинающих появятся здесь после загрузки с сервера.',
  proHint: 'Продвинутые уроки появятся здесь после загрузки с сервера.',
  signInToPlay: 'Войдите, чтобы играть',
  startPractice: 'Начать практику',
  practiceAgain: 'Повторить',
  continueLabel: 'Продолжить',
  totalLessons: 'всего уроков',
  currentKui: 'Текущий күй',
  score: 'Очки',
  combo: 'Комбо',
  by: 'Автор',
  level: 'Уровень',
  perfect: 'Отлично',
  good: 'Хорошо',
  miss: 'Промах',
  restartTooltip: 'Начать сначала',
  performanceRank: 'Оценка исполнения',
  finalScore: 'Итоговый счёт',
  analysis: 'Анализ',
  smartSuggestion: 'Умная подсказка',
  saveProgress: 'Хотите сохранить прогресс?',
  saveProgressDesc: 'Создайте аккаунт для отслеживания мастерства.',
  nextLesson: 'Следующий урок',
  restart: 'Заново',
  menu: 'Меню',
  share: 'Поделиться',
  rank: 'Ранг',
  progressTo: 'До уровня',
  guestProfileHint: 'Ваш путь начинается здесь. Сыграйте первый күй, чтобы открыть статистику.',
  startLearning: 'Начать обучение',
  logOut: 'Выход',
  detailedAnalytics: 'Подробная аналитика',
  avgBpm: 'Ср. BPM',
  accuracy: 'Точность',
  yourAchievements: 'Ваши достижения',
  playToUnlock: 'Играйте для разблокировки',
  activityTracker: 'Активность',
  totalHours: 'Всего часов',
  streak: 'Серия',
  days: 'Дней',
  accountSettings: 'Настройки аккаунта',
  profileDetails: 'Профиль',
  profileDetailsSub: 'Имя, Аватар, Био',
  security: 'Безопасность',
  securitySub: 'Пароль, 2FA, Сессии',
  notifications: 'Уведомления',
  notificationsSub: 'Напоминания, Новости',
  saveChanges: 'Сохранить',
  language: 'Язык',
  languageSub: 'Изменить язык приложения',
  precisionTuner: 'Точный тюнер',
  startListening: 'Начать прослушивание',
  playAString: 'Сыграйте на струне...',
  perfectTune: 'Идеально!',
  tuneDown: 'Ослабьте',
  tightenSlightly: 'Немного подтяните',
  upperString: 'Верхняя струна',
  lowerString: 'Нижняя струна',
  bottomString: 'Нижняя струна (Астыңғы ішек)',
  topString: 'Верхняя струна (Үстіңгі ішек)',
  reference: 'Эталон',
  kuiRecognition: 'Распознавание Күй',
  tapToRecognize: 'Нажмите для распознавания',
  recording: 'Запись...',
  analyzingAudio: 'Анализ аудио...',
  chordDetected: 'Аккорд определён',
  confidence: 'Уверенность',
  topPredictions: 'Лучшие предсказания',
  mlOffline: 'ML сервис недоступен',
  tryAgain: 'Повторить',
  recordingSeconds: 'секунд',
  noMicrophone: 'Микрофон недоступен',
  badgeFirstSteps: 'Первые шаги',
  badgeLearner: 'Ученик',
  badgeTalent: 'Талант',
  badgeKuishi: 'Кюйши',
  locked: 'Закрыто',
  selectMode: 'Выберите режим',
  trainingMode: 'Режим обучения',
  trainingModeDesc: 'Ждет, пока вы сыграете\nправильные ноты',
  competitiveMode: 'Соревновательный',
  competitiveModeDesc: 'Настоящая игра\nс результатами',
  storyMode: 'История',
  storyModeDesc: 'История и культура\nэтого күя',
  startTraining: 'Начать обучение',
  onlineOnly: 'Только онлайн',
  newToDombra: 'Я не умею играть на домбре',
  alreadyKnowDombra: 'Я умею играть на домбре',
  dombraTuning: 'Настройка домбры',
  dombraTuningSub: 'Калибровка инструмента',
  calibrateNow: 'Калибровать',
  calibrationComplete: 'Калибровка завершена!',
  playOpenBass: 'Сыграйте верхнюю струну — Үстіңгі ішек (D3)',
  playOpenTreble: 'Сыграйте нижнюю струну — Астыңғы ішек (G3)',
  resetCalibration: 'Сбросить настройку',
  standardTuning: 'Стандартный строй — Оң бұрау (G3-D3)',
  centsSharp: 'центов выше',
  centsFlat: 'центов ниже',
  calibrating: 'Слушаю...',
  getReady: 'ПРИГОТОВЬТЕСЬ',
  cancel: 'Отмена',
  done: 'Готово',
  lessonTitles: {
    'b1': 'Ак Жунис',
    'b2': 'Кең жайлау',
    'b3': 'Сарыжайлау',
    'b4': 'Келіншек күйі',
    'b5': 'Көзімнің қарасы',
  },
  lessonDescriptions: {
    'b1': 'Лёгкий күй, воспевающий Ак Жунис. Развивает технику боя.',
    'b2': 'Спокойный күй, описывающий красоту бескрайней степи.',
    'b3': 'Шертпе-күй, передающий изящество Сарыжайлау.',
    'b4': 'Лёгкий и игривый күй. Идеально подходит для начинающих.',
    'b5': 'Упрощённая версия знаменитой песни Абая.',
  },
  lessonComposers: {
    'b1': 'Народный күй',
    'b2': 'Народный күй',
    'b3': 'Таттимбет Казангапулы',
    'b4': 'Фольклорный кюй',
    'b5': 'Абай Кунанбаев',
  },
  learningPath: 'Путь обучения',
  module: 'МОДУЛЬ',
  theBasics: 'Основы',
  masterFoundation: 'Освойте основы игры на домбре',
  upstrokes: 'Удары вверх',
  learnAlternatePicking: 'Изучите технику переменного штриха',
  donePercentage: '% Готово',
  songTag: 'КЮЙ',
  skillTag: 'НАВЫК',
  videoTag: 'ВИДЕО',
  videoIntroTitle: 'Как работают ноты',
  videoIntroDescription: 'Посмотрите короткое видео о том, как работают цифровые ноты и тюнер.',
  watchVideo: 'Смотреть видео',
  skipVideo: 'Пропустить',
  learnNodeTitles: {
    'node_1_meet': 'Знакомство с домброй',
    'node_2_frets': 'Первые лады',
    'node_3_erkem_1': 'Еркем-ай: Такт 1',
    'node_3_erkem_2': 'Еркем-ай: Такт 2',
    'node_3_erkem_3': 'Еркем-ай: Такт 3',
    'node_3_erkem_4': 'Еркем-ай: Такт 4',
    'node_3_erkem_full': 'Еркем-ай: Полный кюй',
    'node_4_upstrokes': 'Удары вверх (Жоғары қағыс)',
    'node_5_kenes': 'Кеңес',
  },
  learnNodeDescriptions: {
    'node_1_meet': 'Научитесь играть на открытых струнах (D3 и G3).',
    'node_2_frets': 'Нажмите на 2-й и 4-й лады на нижней струне.',
    'node_3_erkem_1': 'Выучите первый такт Еркем-ай.',
    'node_3_erkem_2': 'Выучите второй такт Еркем-ай.',
    'node_3_erkem_3': 'Выучите третий такт Еркем-ай.',
    'node_3_erkem_4': 'Выучите четвертый такт Еркем-ай.',
    'node_3_erkem_full': 'Сыграйте полную версию кюя Еркем-ай!',
    'node_4_upstrokes': 'Изучите переменный штрих: вниз-вверх-вниз-вверх.',
    'node_5_kenes': 'Традиционный кюй для отработки ударов вверх.',
  },
  learnNodeStories: {
    'node_3_erkem': 'В бескрайних степях кочевники передавали свою культуру через музыку. "Еркем-ай" - нежная мелодия, часто исполняемая для близких. Давайте сыграем вместе.',
    'node_5_kenes': '"Кеңес" означает совет или разговор. Это произведение имитирует оживленную дискуссию старейшин. Используйте новые удары вверх, чтобы не отставать!',
  },
);

final Map<String, AppStrings> allStrings = {
  'en': en,
  'kz': kz,
  'ru': ru,
};

/// Convenience extension for localized lesson field access.
/// Falls back to the original lesson value if no translation exists.
extension LocalizedLesson on AppStrings {
  String lessonTitle(String id, String fallback) =>
      lessonTitles[id] ?? fallback;
  String lessonDescription(String id, String fallback) =>
      lessonDescriptions[id] ?? fallback;
  String lessonComposer(String id, String fallback) =>
      lessonComposers[id] ?? fallback;
}
