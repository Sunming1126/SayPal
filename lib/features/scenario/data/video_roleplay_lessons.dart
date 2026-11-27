import '../../realtime/voice/conversation_context.dart';

class VideoRoleplayLesson {
  const VideoRoleplayLesson({
    required this.id,
    required this.title,
    required this.englishTitle,
    required this.learnerRole,
    required this.aiRole,
    required this.situation,
    required this.opening,
    required this.objectives,
  });

  final String id;
  final String title;
  final String englishTitle;
  final String learnerRole;
  final String aiRole;
  final String situation;
  final String opening;
  final List<String> objectives;

  String get asset => 'assets/videos/scenario/$id.mp4';
  String get catalogId => 'video-$id';
  String get route => '/scenario/video-practice/$id';

  ConversationContext toContext() => ConversationContext(
    kind: ConversationKind.roleplay,
    catalogId: catalogId,
    title: title,
    learnerRole: learnerRole,
    aiRole: aiRole,
    situation: situation,
    objectives: objectives,
  );
}

const videoRoleplayLessons = [
  VideoRoleplayLesson(
    id: 'teachers-office',
    title: '寻找教师办公室',
    englishTitle: "Looking for the Teachers’ Office",
    learnerRole: 'A student looking for the teachers’ office',
    aiRole: 'A teacher in the school hallway',
    situation:
        'In the video a student asks where the teachers’ office is '
        'and checks the right room. Role-play this exchange. Give one simple '
        'direction or prompt at a time.',
    opening: 'Hi! Where are you trying to go?',
    objectives: [
      'Ask where the teachers’ office is.',
      'Check whether you found the right room.',
      'Thank the teacher for helping.',
    ],
  ),
  VideoRoleplayLesson(
    id: 'meet-robin',
    title: '认识机器人 Robin',
    englishTitle: 'Meet Robin the Robot',
    learnerRole: 'A student introducing Robin',
    aiRole: 'A classmate meeting Robin',
    situation:
        'The video introduces Robin, a short but strong robot. He can '
        'speak Chinese, helps clean, and can be strict. Ask the learner to '
        'introduce Robin and describe things he does in the video.',
    opening: 'Hi! What is the robot’s name?',
    objectives: [
      'Introduce Robin by name.',
      'Describe Robin using two adjectives from the video.',
      'Say one thing Robin can do.',
    ],
  ),
  VideoRoleplayLesson(
    id: 'clever-rat',
    title: '机智的小老鼠',
    englishTitle: 'The Silly Snake and the Clever Rat',
    learnerRole: 'A student retelling the story',
    aiRole: 'A classmate asking about the story',
    situation:
        'In the video a hungry snake catches a rat. The rat talks to '
        'the snake and wants it to let him go. Ask how the rat talks his way '
        'out, one question at a time.',
    opening: 'What animals did you see in the story?',
    objectives: [
      'Name the two animals in the story.',
      'Say why the snake grabbed the rat.',
      'Retell how the rat tried to get away.',
    ],
  ),
  VideoRoleplayLesson(
    id: 'favorite-animal',
    title: '我最喜欢的动物',
    englishTitle: 'My Favorite Animal',
    learnerRole: 'A visitor at the aquarium',
    aiRole: 'A friend looking at penguins',
    situation:
        'The video shows a penguin and asks which animal is your '
        'favorite and why. Start by the penguin tank, then ask the learner '
        'about their favorite animal and what they like about it.',
    opening: 'Look at the penguin! What’s your favorite animal?',
    objectives: [
      'Name the animal shown in the video.',
      'Say which animal is your favorite.',
      'Give one reason you like that animal.',
    ],
  ),
];
