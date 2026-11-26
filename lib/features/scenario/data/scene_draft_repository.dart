import 'dart:convert';
import 'dart:io';
import '../../../core/config/app_config.dart';
import '../../../core/config/service_endpoint.dart';
import '../models/practice_catalog.dart';

abstract interface class SceneDraftRepository {
  Future<CustomSceneDraft> generate(SceneDraftSeed seed);
}

class LocalSceneDraftApi implements SceneDraftRepository {
  LocalSceneDraftApi({String? baseUrl})
      : _baseUrl =
            baseUrl ?? AppConfig.instance.apiBaseUrl;
  final String _baseUrl;
  @override
  Future<CustomSceneDraft> generate(SceneDraftSeed seed) async {
    final SceneDraftSeed trimmed = SceneDraftSeed(
      learnerRole: seed.learnerRole.trim(),
      aiRole: seed.aiRole.trim(),
      situation: seed.situation.trim(),
    );
    final uri = resolveServiceEndpoint(_baseUrl, 'scene-draft');
    if (uri == null || !uri.hasScheme) return _fallback(trimmed);
    final client = HttpClient();
    try {
      final request =
          await client.postUrl(uri).timeout(const Duration(seconds: 10));
      request.headers.contentType = ContentType.json;
      const token = AppConfig.chatToken;
      if (token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      final idea = '练习者是${trimmed.learnerRole}，老师扮演${trimmed.aiRole}。'
          '情景：${trimmed.situation}';
      request.write(jsonEncode({
        ...trimmed.toJson(),
        'idea': String.fromCharCodes(idea.runes.take(160)),
      }));
      final response =
          await request.close().timeout(const Duration(seconds: 20));
      final body = await utf8.decodeStream(response);
      if (response.statusCode != 200) return _fallback(trimmed);
      return CustomSceneDraft.fromJson(
          jsonDecode(body) as Map<String, dynamic>);
    } catch (_) {
      return _fallback(trimmed);
    } finally {
      client.close(force: true);
    }
  }

  CustomSceneDraft _fallback(SceneDraftSeed seed) {
    final String idea = seed.situation;
    final bool ticket = RegExp(r'售票|买票|车票|门票').hasMatch(idea);
    final bool food = RegExp(r'点餐|餐厅|披萨|外卖').hasMatch(idea);
    final String title = ticket
        ? (idea.isEmpty ? '售票处买票' : idea)
        : food
            ? (idea.isEmpty ? '餐厅点餐' : idea)
            : (idea.isEmpty ? '我的专属情景' : idea);
    final String learnerRole = seed.learnerRole;
    final String aiRole = seed.aiRole;
    final String situation = ticket
        ? '你在售票处礼貌地询问并购买一张票，只使用虚构信息。'
        : food
            ? '你在餐厅礼貌地点餐，练习食物和数量表达。'
            : '请围绕“$title”进行一段自然、安全的英语对话。';
    return CustomSceneDraft(
      id: 'local-draft-${DateTime.now().microsecondsSinceEpoch}',
      title: title.length > 40 ? title.substring(0, 40) : title,
      learnerRole: learnerRole,
      aiRole: aiRole,
      situation: situation,
      objectives: ticket
          ? const <String>['礼貌打招呼', '询问票价或时间', '说谢谢并告别']
          : food
              ? const <String>['礼貌打招呼', '说出想要的食物', '确认并感谢对方']
              : const <String>['用英语打招呼', '说出自己的需求', '礼貌地结束对话'],
      createdAt: DateTime.now(),
    );
  }
}
