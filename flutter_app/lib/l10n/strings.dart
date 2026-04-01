enum AppLang { en, kz, ru }

class AppStrings {
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
  final String tradition;
  final String technology;
  final String mastery;
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
  final String premiumOnly;
  final String startPractice;
  final String practiceAgain;
  final String continueLabel;
  final String totalLessons;
  final String currentKui;
  final String score;
  final String combo;
  final String by;
  final String level;
  final String perfect;
  final String good;
  final String miss;
  final String restartTooltip;
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
  final String subscription;
  final String subscriptionSub;
  final String notifications;
  final String notificationsSub;
  final String saveChanges;
  final String precisionTuner;
  final String startListening;
  final String playAString;
  final String perfectTune;
  final String tuneDown;
  final String tightenSlightly;
  final String upperString;
  final String lowerString;
  final String reference;
  final String badgeFastFingers;
  final String badgeTraditionKeeper;
  final String badgePerfectAdai;
  final String badgeEarlyBird;
  final String locked;
  // ML integration strings
  final String aiAnalysis;
  final String timing;
  final String consistency;
  final String chordDetected;
  final String aiPowered;
  final String mlServiceOnline;
  final String mlServiceOffline;
  final String scoreSaved;

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
    required this.premiumOnly,
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
    required this.subscription,
    required this.subscriptionSub,
    required this.notifications,
    required this.notificationsSub,
    required this.saveChanges,
    required this.precisionTuner,
    required this.startListening,
    required this.playAString,
    required this.perfectTune,
    required this.tuneDown,
    required this.tightenSlightly,
    required this.upperString,
    required this.lowerString,
    required this.reference,
    required this.badgeFastFingers,
    required this.badgeTraditionKeeper,
    required this.badgePerfectAdai,
    required this.badgeEarlyBird,
    required this.locked,
    required this.aiAnalysis,
    required this.timing,
    required this.consistency,
    required this.chordDetected,
    required this.aiPowered,
    required this.mlServiceOnline,
    required this.mlServiceOffline,
    required this.scoreSaved,
  });

  // ─── English ──────────────────────────────────────────────────────
  static const en = AppStrings(
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
    premiumOnly: 'Authorized Only',
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
    subscription: 'Subscription',
    subscriptionSub: 'Pro Plan, Billing History',
    notifications: 'Notifications',
    notificationsSub: 'Practice reminders, News',
    saveChanges: 'Save Changes',
    precisionTuner: 'Precision Tuner',
    startListening: 'Start Listening',
    playAString: 'Play a string...',
    perfectTune: 'Perfect!',
    tuneDown: 'Tune down',
    tightenSlightly: 'Tighten slightly',
    upperString: 'Upper String',
    lowerString: 'Lower String',
    reference: 'Reference',
    badgeFastFingers: 'Fast Fingers',
    badgeTraditionKeeper: 'Tradition Keeper',
    badgePerfectAdai: 'Perfect Adai',
    badgeEarlyBird: 'Early Bird',
    locked: 'Locked',
    aiAnalysis: 'AI Analysis',
    timing: 'Timing',
    consistency: 'Consistency',
    chordDetected: 'Chord Detected',
    aiPowered: 'AI Powered',
    mlServiceOnline: 'ML Service Online',
    mlServiceOffline: 'ML Service Offline',
    scoreSaved: 'Score saved to server',
  );

  // ─── Kazakh ───────────────────────────────────────────────────────
  static const kz = AppStrings(
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
    premiumOnly: 'Тек авторизацияланған пайдаланушылар',
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
    subscription: 'Жазылым',
    subscriptionSub: 'Pro жоспар, Төлем тарихы',
    notifications: 'Хабарландырулар',
    notificationsSub: 'Жаттығу еске салғыштары, Жаңалықтар',
    saveChanges: 'Сақтау',
    precisionTuner: 'Дәл тюнер',
    startListening: 'Тыңдауды бастау',
    playAString: 'Ішекті тартыңыз...',
    perfectTune: 'Тамаша!',
    tuneDown: 'Бұрауды босатыңыз',
    tightenSlightly: 'Аздап қатайтыңыз',
    upperString: 'Жоғарғы ішек',
    lowerString: 'Төменгі ішек',
    reference: 'Анықтама',
    badgeFastFingers: 'Жылдам саусақтар',
    badgeTraditionKeeper: 'Дәстүр сақтаушы',
    badgePerfectAdai: 'Тамаша Адай',
    badgeEarlyBird: 'Ерте құс',
    locked: 'Жабық',
    aiAnalysis: 'ЖИ талдауы',
    timing: 'Уақыт',
    consistency: 'Тұрақтылық',
    chordDetected: 'Аккорд анықталды',
    aiPowered: 'ЖИ қуаты',
    mlServiceOnline: 'ML қызметі желіде',
    mlServiceOffline: 'ML қызметі қолжетімсіз',
    scoreSaved: 'Ұпай серверге сақталды',
  );

  // ─── Russian ──────────────────────────────────────────────────────
  static const ru = AppStrings(
    appTitle: 'Күйшім',
    appSubtitle: 'Освойте древнее искусство домбры с помощью ИИ в реальном времени.',
    startPlaying: 'Начать играть',
    signIn: 'Войти',
    createAccount: 'Создать аккаунт',
    backendOffline: 'Сервер недоступен — только гостевой режим',
    signingIn: 'Вход...',
    creating: 'Создание...',
    username: 'Имя пользователя',
    email: 'Эл. почта',
    password: 'Пароль',
    newPassword: 'Новый пароль',
    forgotPassword: 'Забыли пароль?',
    resetPassword: 'Сбросить пароль',
    resetting: 'Сброс...',
    resetPasswordDesc: 'Введите имя пользователя и email для подтверждения личности',
    passwordResetDone: 'Пароль сброшен!',
    passwordResetDoneDesc: 'Ваш пароль успешно обновлён. Теперь вы можете войти с новым паролем.',
    signInNow: 'Войти сейчас',
    back: '← Назад',
    backToSignIn: '← Вернуться ко входу',
    tradition: 'Традиция',
    technology: 'Технология',
    mastery: 'Мастерство',
    libraryTitle: 'Библиотека Күйшім',
    welcomeBack: 'С возвращением',
    guestAccess: 'Гостевой доступ: 1 урок доступен',
    beginner: 'Начинающий',
    pro: 'Продвинутый',
    completed: 'Завершено',
    inProgress: 'В процессе',
    newLabel: 'Новый',
    noLessonsFound: 'Уроки не найдены',
    beginnerHint: 'Уроки для начинающих появятся здесь после загрузки с сервера.',
    proHint: 'Уроки для продвинутых появятся здесь после загрузки с сервера.',
    premiumOnly: 'Только авторизованные пользователи',
    startPractice: 'Начать практику',
    practiceAgain: 'Повторить',
    continueLabel: 'Продолжить',
    totalLessons: 'всего уроков',
    currentKui: 'Текущий күй',
    score: 'Баллы',
    combo: 'Комбо',
    by: 'Автор',
    level: 'Уровень',
    perfect: 'Отлично',
    good: 'Хорошо',
    miss: 'Промах',
    restartTooltip: 'Начать сначала',
    performanceRank: 'Ранг исполнения',
    finalScore: 'Итоговый балл',
    analysis: 'Анализ',
    smartSuggestion: 'Умная подсказка',
    saveProgress: 'Хотите сохранить прогресс?',
    saveProgressDesc: 'Создайте аккаунт для отслеживания мастерства.',
    nextLesson: 'Следующий урок',
    restart: 'Заново',
    menu: 'Меню',
    share: 'Поделиться',
    rank: 'Ранг',
    progressTo: 'Прогресс до',
    guestProfileHint: 'Ваш путь начинается здесь. Сыграйте первый күй, чтобы открыть статистику и отслеживать прогресс.',
    startLearning: 'Начать обучение',
    logOut: 'Выйти',
    detailedAnalytics: 'Детальная аналитика',
    avgBpm: 'Средний BPM',
    accuracy: 'Точность',
    yourAchievements: 'Ваши достижения',
    playToUnlock: 'Играйте, чтобы открыть',
    activityTracker: 'Трекер активности',
    totalHours: 'Всего часов',
    streak: 'Серия',
    days: 'Дней',
    accountSettings: 'Настройки аккаунта',
    profileDetails: 'Профиль',
    profileDetailsSub: 'Имя, Аватар, О себе',
    security: 'Безопасность',
    securitySub: 'Пароль, 2FA, Сессии',
    subscription: 'Подписка',
    subscriptionSub: 'Pro план, История платежей',
    notifications: 'Уведомления',
    notificationsSub: 'Напоминания о практике, Новости',
    saveChanges: 'Сохранить',
    precisionTuner: 'Точный тюнер',
    startListening: 'Начать слушать',
    playAString: 'Ударьте по струне...',
    perfectTune: 'Отлично!',
    tuneDown: 'Ослабьте колок',
    tightenSlightly: 'Немного подтяните',
    upperString: 'Верхняя струна',
    lowerString: 'Нижняя струна',
    reference: 'Справка',
    badgeFastFingers: 'Быстрые пальцы',
    badgeTraditionKeeper: 'Хранитель традиций',
    badgePerfectAdai: 'Идеальный Адай',
    badgeEarlyBird: 'Ранняя пташка',
    locked: 'Закрыто',
    aiAnalysis: 'ИИ Анализ',
    timing: 'Ритм',
    consistency: 'Стабильность',
    chordDetected: 'Обнаружен аккорд',
    aiPowered: 'На основе ИИ',
    mlServiceOnline: 'ML сервис в сети',
    mlServiceOffline: 'ML сервис недоступен',
    scoreSaved: 'Результат сохранён на сервере',
  );

  static AppStrings get(AppLang lang) {
    switch (lang) {
      case AppLang.en:
        return en;
      case AppLang.kz:
        return kz;
      case AppLang.ru:
        return ru;
    }
  }

  /// Returns the label to show on the toggle button (the *current* language).
  static String langLabel(AppLang lang) {
    switch (lang) {
      case AppLang.en:
        return '🇬🇧 EN';
      case AppLang.kz:
        return '🇰🇿 KZ';
      case AppLang.ru:
        return '🇷🇺 RU';
    }
  }
}
