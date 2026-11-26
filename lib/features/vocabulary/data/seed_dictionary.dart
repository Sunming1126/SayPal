import '../models/vocab_models.dart';
import '../domain/vocabulary_repository.dart';

/// 离线演示词典：覆盖 MVP 演示脚本里出现的高频词。
/// 真实链路中该服务由服务端词典/翻译接口实现。
final class SeedWordDictionary implements WordLookupService {
  static const Map<String, List<String>> _entries = <String, List<String>>{
    'hello': ['你好', 'int. 打招呼用语', 'Hello, nice to meet you!|你好，很高兴认识你！'],
    'hi': ['嗨', 'int. 你好', 'Hi, everyone!|嗨，大家好！'],
    'teacher': ['老师', 'n. 教师', 'My teacher is kind.|我的老师很和善。'],
    'school': ['学校', 'n. 学校', 'I go to school by bus.|我坐公交车上学。'],
    'class': ['班级；课', 'n. 班级；课堂', 'We have an English class.|我们有一节英语课。'],
    'friend': ['朋友', 'n. 朋友', 'Tom is my friend.|汤姆是我的朋友。'],
    'name': ['名字', 'n. 名字', 'What is your name?|你叫什么名字？'],
    'play': ['玩；播放', 'v. 玩；进行（运动）', 'Let us play football.|我们踢足球吧。'],
    'like': ['喜欢', 'v. 喜欢', 'I like apples.|我喜欢苹果。'],
    'coffee': ['咖啡', 'n. 咖啡', 'A cup of coffee, please.|请给我一杯咖啡。'],
    'milk': ['牛奶', 'n. 牛奶', 'I drink milk every day.|我每天喝牛奶。'],
    'water': ['水', 'n. 水', 'May I have some water?|可以给我一些水吗？'],
    'hot': ['热的；辣的', 'adj. 热的；烫的', 'The soup is hot.|汤很烫。'],
    'cold': ['冷的', 'adj. 冷的；冰的', 'I want cold water.|我想要冰水。'],
    'large': ['大杯；大的', 'adj. 大的', 'I want a large pizza.|我要一个大披萨。'],
    'medium': ['中杯；中等的', 'adj. 中等的', 'A medium juice, please.|请给我一杯中杯果汁。'],
    'small': ['小杯；小的', 'adj. 小的', 'Just a small one.|就要小杯的。'],
    'ice': ['冰', 'n. 冰；冰块', 'No ice, please.|请不要加冰。'],
    'order': ['点单；订购', 'v./n. 点单', 'Can I order now?|我现在可以点单吗？'],
    'pay': ['付款', 'v. 支付', 'I will pay by phone.|我用手机付款。'],
    'ticket': ['票', 'n. 票', 'Two tickets, please.|请给我两张票。'],
    'bus': ['公交车', 'n. 公交车', 'The bus is coming.|公交车来了。'],
    'station': ['车站', 'n. 车站', 'Where is the station?|车站在哪里？'],
    'stop': ['站；停止', 'n. 车站；v. 停止', 'Get off at the next stop.|下一站下车。'],
    'supermarket': ['超市', 'n. 超市', 'Let us go to the supermarket.|我们去超市吧。'],
    'apple': ['苹果', 'n. 苹果', 'This apple is sweet.|这个苹果很甜。'],
    'banana': ['香蕉', 'n. 香蕉', 'Monkeys love bananas.|猴子爱香蕉。'],
    'how': ['怎样；如何', 'adv. 怎样', 'How are you?|你好吗？'],
    'much': ['许多；多少', 'adv. 多少（钱）', 'How much is it?|多少钱？'],
    'many': ['许多', 'adj. 许多的', 'How many books?|多少本书？'],
    'thank': ['感谢', 'v. 感谢', 'Thank you very much.|非常感谢。'],
    'please': ['请', 'int. 请', 'Please sit down.|请坐。'],
    'want': ['想要', 'v. 想要', 'I want a hamburger.|我想要一个汉堡。'],
    'give': ['给', 'v. 给', 'Please give me the book.|请把书给我。'],
    'me': ['我', 'pron. 我（宾格）', 'Help me, please.|请帮帮我。'],
    'you': ['你；你们', 'pron. 你', 'You did a great job!|你做得真棒！'],
    'today': ['今天', 'n. 今天', 'Today is Monday.|今天是星期一。'],
    'morning': ['早晨', 'n. 早晨', 'Good morning!|早上好！'],
    'afternoon': ['下午', 'n. 下午', 'Good afternoon!|下午好！'],
    'food': ['食物', 'n. 食物', 'The food is tasty.|食物很好吃。'],
    'eat': ['吃', 'v. 吃', 'Let us eat together.|我们一起吃吧。'],
    'drink': ['喝', 'v. 喝', 'What do you want to drink?|你想喝什么？'],
    'buy': ['买', 'v. 买', 'I want to buy a gift.|我想买份礼物。'],
    'find': ['找到', 'v. 找到', 'I cannot find my pen.|我找不到我的笔了。'],
    'look': ['看', 'v. 看', 'Look at that bird!|看那只鸟！'],
    'nice': ['好的；友好的', 'adj. 好的；令人愉快的', 'Have a nice day!|祝你今天愉快！'],
    'good': ['好的', 'adj. 好的', 'Good job!|做得好！'],
    'great': ['很棒的', 'adj. 极好的', 'That is great!|那太棒了！'],
    'welcome': ['欢迎', 'v./int. 欢迎', 'Welcome to our school!|欢迎来到我们学校！'],
    'family': ['家庭；家人', 'n. 家庭', 'I love my family.|我爱我的家人。'],
    'father': ['爸爸；父亲', 'n. 父亲', 'My father is kind.|我的爸爸很善良。'],
    'mother': ['妈妈；母亲', 'n. 母亲', 'My mother is a teacher.|我的妈妈是一名老师。'],
    'doctor': ['医生', 'n. 医生', 'My father is a doctor.|我的爸爸是一名医生。'],
    'student': ['学生', 'n. 学生', 'I am a student.|我是一名学生。'],
    'dinner': ['晚餐', 'n. 晚餐', 'We have dinner together.|我们一起吃晚饭。'],
    'weekend': ['周末', 'n. 周末', 'We go for walks on weekends.|我们周末去散步。'],
    'zoo': ['动物园', 'n. 动物园', 'We went to the zoo.|我们去了动物园。'],
    'bird': ['鸟', 'n. 鸟', 'The bird is in the tree.|鸟在树上。'],
    'bear': ['熊', 'n. 熊', 'The bear is very big.|这只熊很大。'],
    'tiger': ['老虎', 'n. 老虎', 'The tiger is strong.|老虎很强壮。'],
    'monkey': ['猴子', 'n. 猴子', 'The monkey can climb.|猴子会爬树。'],
    'panda': ['熊猫', 'n. 熊猫', 'The panda is eating bamboo.|熊猫正在吃竹子。'],
    'bamboo': ['竹子', 'n. 竹子', 'Pandas like bamboo.|熊猫喜欢竹子。'],
    'colorful': ['多彩的', 'adj. 多彩的', 'The seasons are colorful.|四季是多彩的。'],
    'season': ['季节', 'n. 季节', 'Spring is a season.|春天是一个季节。'],
    'spring': ['春天', 'n. 春天', 'It is warm in spring.|春天很暖和。'],
    'summer': ['夏天', 'n. 夏天', 'I love summer.|我喜欢夏天。'],
    'autumn': ['秋天', 'n. 秋天', 'Autumn is cool.|秋天很凉爽。'],
    'winter': ['冬天', 'n. 冬天', 'Winter is cold.|冬天很冷。'],
    'favorite': [
      '最喜欢的',
      'adj. 最喜欢的',
      'Summer is my favorite season.|夏天是我最喜欢的季节。'
    ],
  };

  @override
  WordLookupResult? lookup(String word) {
    final String key = word.toLowerCase().trim();
    final List<String>? entry = _entries[key];
    if (entry == null) {
      return null;
    }
    final List<String> example = entry[2].split('|');
    return WordLookupResult(
      word: key,
      meaningZh: entry[0],
      phonetic: entry[1],
      exampleEn: example[0],
      exampleZh: example.length > 1 ? example[1] : null,
    );
  }

  /// 供调试：词典是否收录（测试用）。
  bool contains(String word) => _entries.containsKey(word.toLowerCase().trim());
}
