import '../../../core/theme/app_theme.dart';
import '../models/scenario_models.dart';

/// 离线种子情景：咖啡厅 / 超市结账 / 买票。
const List<LifeScenario> kSeedScenarios = <LifeScenario>[
  LifeScenario(
    id: 'coffee',
    title: '咖啡厅',
    emoji: '☕',
    color: AppColors.primary,
    introZh: '在咖啡厅点一杯喜欢的饮品，完成三个小任务。',
    tasks: <ScenarioTask>[
      ScenarioTask(
        id: 'coffee-1',
        titleZh: '说明要买咖啡',
        aiTextEn: 'Welcome! What can I get for you?',
        aiTextZh: '欢迎光临！你想买点什么？',
        suggestions: <String>['I want to buy a coffee.', 'A coffee, please.'],
        keywords: <String>['coffee'],
      ),
      ScenarioTask(
        id: 'coffee-2',
        titleZh: '选择合适的尺寸和温度',
        aiTextEn: 'Sure! What size? Hot or iced?',
        aiTextZh: '好的！要什么尺寸？热的还是冰的？',
        suggestions: <String>['A large hot coffee.', 'A small iced coffee.'],
        keywords: <String>['large|small|medium', 'hot|iced'],
      ),
      ScenarioTask(
        id: 'coffee-3',
        titleZh: '结账离开',
        aiTextEn: 'Here is your coffee. Anything else?',
        aiTextZh: '这是您的咖啡。还需要别的吗？',
        suggestions: <String>['No, thank you. Goodbye!', 'How much is it?'],
        keywords: <String>['thank|how much'],
      ),
    ],
  ),
  LifeScenario(
    id: 'supermarket',
    title: '超市结账',
    emoji: '🛒',
    color: AppColors.accent,
    introZh: '在超市买东西并完成结账，完成三个小任务。',
    tasks: <ScenarioTask>[
      ScenarioTask(
        id: 'supermarket-1',
        titleZh: '说明要买的东西',
        aiTextEn: 'Hello! Did you find everything?',
        aiTextZh: '你好！东西都找到了吗？',
        suggestions: <String>['Yes, I want to buy apples.', 'I found everything.'],
        keywords: <String>['buy|found'],
      ),
      ScenarioTask(
        id: 'supermarket-2',
        titleZh: '询问价格',
        aiTextEn: 'Great! Do you want to know the price?',
        aiTextZh: '很好！你想知道价格吗？',
        suggestions: <String>['How much is it?', 'How much are the apples?'],
        keywords: <String>['how much'],
      ),
      ScenarioTask(
        id: 'supermarket-3',
        titleZh: '完成结账',
        aiTextEn: 'That will be ten yuan. How will you pay?',
        aiTextZh: '一共十元。你想怎么付款？',
        suggestions: <String>['I will pay by phone.', 'Here is the money.'],
        keywords: <String>['pay|money'],
      ),
    ],
  ),
  LifeScenario(
    id: 'tickets',
    title: '买票',
    emoji: '🎟️',
    color: AppColors.success,
    introZh: '在售票处买票，完成三个小任务。',
    tasks: <ScenarioTask>[
      ScenarioTask(
        id: 'tickets-1',
        titleZh: '说明要买票',
        aiTextEn: 'Hi! How can I help you?',
        aiTextZh: '你好！需要帮忙吗？',
        suggestions: <String>['I want to buy two tickets.', 'Two tickets, please.'],
        keywords: <String>['ticket'],
      ),
      ScenarioTask(
        id: 'tickets-2',
        titleZh: '说明时间去哪里',
        aiTextEn: 'Sure! For which show or place?',
        aiTextZh: '好的！是哪场演出或去哪里？',
        suggestions: <String>['For the zoo, please.', 'The museum at three.'],
        keywords: <String>['zoo|museum|three|please'],
      ),
      ScenarioTask(
        id: 'tickets-3',
        titleZh: '付款拿票离开',
        aiTextEn: 'Here are your tickets. Have fun!',
        aiTextZh: '这是您的票，祝您愉快！',
        suggestions: <String>['Thank you very much!', 'Thanks! Bye!'],
        keywords: <String>['thank'],
      ),
    ],
  ),
];

/// 按 id 找情景。
LifeScenario? findScenario(String id) {
  for (final LifeScenario scenario in kSeedScenarios) {
    if (scenario.id == id) {
      return scenario;
    }
  }
  return null;
}
