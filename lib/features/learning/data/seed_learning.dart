import '../../../core/theme/app_theme.dart';
import '../models/learning_models.dart';

/// 离线种子课程：校园 / 餐厅 / 公交站 三个场景。
/// 校园场景含一条完整可玩的课程链；其余场景为后续解锁的占位课程。
const List<LearningScene> kSeedLearningScenes = <LearningScene>[
  LearningScene(
    id: 'campus',
    title: '校园',
    emoji: '🏫',
    color: AppColors.primary,
    lessons: <Lesson>[
      Lesson(
        id: 'campus-01',
        title: '在操场上打招呼',
        coverEmoji: '👋',
        descriptionZh: '学会用英语和同学老师问好、介绍自己',
        steps: <LessonStep>[
          LessonStep(
            aiTextEn: 'Hello! I am your teacher. What is your name?',
            aiTextZh: '你好！我是你的老师。你叫什么名字？',
            suggestions: <String>['My name is Amy.', 'My name is Ben.'],
            keywords: <String>['my name'],
          ),
          LessonStep(
            aiTextEn: 'Nice to meet you! How are you today?',
            aiTextZh: '很高兴认识你！你今天怎么样？',
            suggestions: <String>['I am fine, thank you.', 'I am great!'],
            keywords: <String>['i am'],
          ),
          LessonStep(
            aiTextEn: 'Let us play on the playground! What do you like?',
            aiTextZh: '我们去操场玩吧！你喜欢玩什么？',
            suggestions: <String>['I like to play football.', 'I like the slide.'],
            keywords: <String>['i like'],
          ),
        ],
      ),
      Lesson(
        id: 'campus-02',
        title: '向老师借文具',
        coverEmoji: '✏️',
        descriptionZh: '学会礼貌地向老师借东西',
        steps: <LessonStep>[
          LessonStep(
            aiTextEn: 'Do you need some help?',
            aiTextZh: '你需要帮忙吗？',
            suggestions: <String>['May I borrow a pencil?', 'Yes, please.'],
            keywords: <String>['may i'],
          ),
          LessonStep(
            aiTextEn: 'Of course! Here you are.',
            aiTextZh: '当然可以！给你。',
            suggestions: <String>['Thank you very much!', 'Thanks a lot!'],
            keywords: <String>['thank'],
          ),
        ],
      ),
    ],
  ),
  LearningScene(
    id: 'restaurant',
    title: '餐厅',
    emoji: '🍽️',
    color: AppColors.accent,
    lessons: <Lesson>[
      Lesson(
        id: 'restaurant-01',
        title: '点一份喜欢的食物',
        coverEmoji: '🍔',
        descriptionZh: '学会用英语点餐',
        steps: <LessonStep>[
          LessonStep(
            aiTextEn: 'Welcome! What would you like to eat?',
            aiTextZh: '欢迎光临！你想吃什么？',
            suggestions: <String>['I want a hamburger.', 'I want some noodles.'],
            keywords: <String>['i want'],
          ),
          LessonStep(
            aiTextEn: 'Good choice! Anything to drink?',
            aiTextZh: '好选择！要喝的吗？',
            suggestions: <String>['Milk, please.', 'Some water, please.'],
            keywords: <String>['please'],
          ),
        ],
      ),
    ],
  ),
  LearningScene(
    id: 'bus-stop',
    title: '公交站',
    emoji: '🚌',
    color: AppColors.success,
    lessons: <Lesson>[
      Lesson(
        id: 'bus-stop-01',
        title: '问问公交车路线',
        coverEmoji: '🚏',
        descriptionZh: '学会问路和乘坐公交车',
        steps: <LessonStep>[
          LessonStep(
            aiTextEn: 'Hi! Do you need the bus?',
            aiTextZh: '你好！你要坐公交车吗？',
            suggestions: <String>['Yes, where is the bus stop?', 'Yes, I do.'],
            keywords: <String>['bus'],
          ),
          LessonStep(
            aiTextEn: 'It is over there. Which line do you need?',
            aiTextZh: '就在那边。你要坐几路车？',
            suggestions: <String>['Line 2, please.', 'I need line 10.'],
            keywords: <String>['line'],
          ),
        ],
      ),
    ],
  ),
];
