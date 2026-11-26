import '../../../core/theme/app_theme.dart';
import '../models/chat_persona.dart';

/// 预置角色（演示）。真实链路中 demoScriptEn 会被服务端 Agent 替代。
const List<ChatPersona> kSeedPersonas = <ChatPersona>[
  ChatPersona(
    id: 'blue-bot',
    name: '小蓝',
    emoji: '🤖',
    voiceLabel: '活泼童声',
    personalityZh: '好奇又爱提问的小机器人，喜欢聊有趣的事',
    color: AppColors.primary,
    demoScriptEn: <ChatDemoTurn>[
      ChatDemoTurn(
        aiText: 'Hello! I am Blue. What is your name?',
        aiTextZh: '你好！我是小蓝。你叫什么名字呀？',
        suggestions: <String>['My name is Amy.', 'Hi, I am Tom.'],
      ),
      ChatDemoTurn(
        aiText: 'Nice to meet you! What do you like to play?',
        aiTextZh: '很高兴认识你！你喜欢玩什么呢？',
        suggestions: <String>['I like to play football.', 'I like to play games.'],
      ),
      ChatDemoTurn(
        aiText: 'That sounds fun! Do you like animals?',
        aiTextZh: '听起来真有趣！你喜欢小动物吗？',
        suggestions: <String>['Yes, I like pandas.', 'No, I like robots.'],
      ),
      ChatDemoTurn(
        aiText: 'Great talking with you! See you next time!',
        aiTextZh: '和你聊天真开心！下次见！',
        suggestions: <String>['See you!', 'Bye bye, Blue!'],
      ),
    ],
  ),
  ChatPersona(
    id: 'luna-teacher',
    name: '露娜老师',
    emoji: '👩‍🏫',
    voiceLabel: '温柔女声',
    personalityZh: '耐心的英语老师，会慢慢说、多鼓励',
    color: AppColors.success,
    demoScriptEn: <ChatDemoTurn>[
      ChatDemoTurn(
        aiText: 'Good morning! How are you today?',
        aiTextZh: '早上好！你今天过得怎么样？',
        suggestions: <String>['I am fine, thank you!', 'I am happy today.'],
      ),
      ChatDemoTurn(
        aiText: 'Wonderful! What did you eat this morning?',
        aiTextZh: '真棒！你早上吃了什么呢？',
        suggestions: <String>['I ate bread and milk.', 'I ate an egg.'],
      ),
      ChatDemoTurn(
        aiText: 'Yummy! Bread and milk give you energy.',
        aiTextZh: '好好吃！面包和牛奶会给你能量。',
        suggestions: <String>['Yes! I love milk.', 'I want to eat more.'],
      ),
      ChatDemoTurn(
        aiText: 'You did great today. Keep talking with me!',
        aiTextZh: '今天你表现得很棒，继续和我聊天吧！',
        suggestions: <String>['OK! Thank you, teacher!', 'I will!'],
      ),
    ],
  ),
  ChatPersona(
    id: 'mike-friend',
    name: '麦克',
    emoji: '🐻',
    voiceLabel: '阳光男声',
    personalityZh: '爱讲笑话的小伙伴，喜欢夸张和冒险',
    color: AppColors.accent,
    demoScriptEn: <ChatDemoTurn>[
      ChatDemoTurn(
        aiText: 'Hey friend! I climbed a big hill today!',
        aiTextZh: '嘿，朋友！我今天爬了一座大山！',
        suggestions: <String>['Wow, that is cool!', 'Are you tired?'],
      ),
      ChatDemoTurn(
        aiText: 'A little tired, but I saw a rainbow!',
        aiTextZh: '有一点点累，但我看到了彩虹！',
        suggestions: <String>['A rainbow? So pretty!', 'I want to see it too.'],
      ),
      ChatDemoTurn(
        aiText: 'Where do you want to go for an adventure?',
        aiTextZh: '你想去哪里冒险呢？',
        suggestions: <String>['I want to go to the sea.', 'The forest!'],
      ),
      ChatDemoTurn(
        aiText: 'Let us plan it together. Talk soon!',
        aiTextZh: '我们一起计划吧。回聊！',
        suggestions: <String>['OK, see you!', 'Deal!'],
      ),
    ],
  ),
];
