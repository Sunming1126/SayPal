import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/theme_course.dart';

class ThemeCourseRepository {
  Future<List<ThemeCourse>> loadCourses() async {
    final Map<String, dynamic> raw = jsonDecode(
      await rootBundle.loadString('assets/content/tutor_courses.json'),
    ) as Map<String, dynamic>;
    return (raw['courses'] as List<dynamic>)
        .map((dynamic item) =>
            ThemeCourse.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
