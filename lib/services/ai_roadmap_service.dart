/// Local "AI" pipeline: keyword extraction, goal analysis, gaps, roadmap + resources.
/// Swap this class for an HTTP call to your LLM / backend when ready.
class AiRoadmapService {
  static const _techKeywords = {
    'flutter', 'dart', 'android', 'kotlin', 'swift', 'ios', 'java', 'python',
    'javascript', 'typescript', 'react', 'node', 'sql', 'firebase', 'aws',
    'gcp', 'docker', 'kubernetes', 'git', 'machine learning', 'ml', 'ai',
    'data science', 'pandas', 'tensorflow', 'pytorch', 'c++', 'c#', 'go', 'rust',
    'system design', 'algorithms', 'dsa', 'oop', 'rest', 'graphql', 'testing',
  };

  AiAnalysis analyze({
    required String resumeText,
    required List<String> userSkills,
    required List<String> interests,
    required String careerGoals,
  }) {
    final text = '${resumeText.toLowerCase()} ${userSkills.join(' ').toLowerCase()}';
    final extracted = <String>{};
    for (final k in _techKeywords) {
      if (text.contains(k)) extracted.add(k);
    }
    extracted.addAll(userSkills.map((e) => e.toLowerCase().trim()).where((e) => e.isNotEmpty));

    final target = _inferTargetRole(careerGoals, interests, userSkills);
    final goalAnalysis = careerGoals.trim().isEmpty
        ? 'Career goal not specified; inferred focus: $target based on interests and skills.'
        : 'Primary objective: $careerGoals. Inferred target direction: $target.';

    final required = _skillsForRole(target);
    final have = extracted;
    final gaps = required.difference(have).take(8).toList();

    final milestones = <String>[
      'Beginner — Foundations for $target: core syntax, tooling, and delivery of a small project.',
      'Intermediate — ${gaps.isNotEmpty ? "Close gaps in: ${gaps.take(3).join(', ')}" : "Deepen system design and production practices"}; contribute to team-sized features.',
      'Advanced — End-to-end ownership, performance, security, mentoring, and interview-ready depth.',
    ];

    final resources = <String>[
      'https://developer.mozilla.org/en-US/docs/Learn (web fundamentals)',
      'https://leetcode.com/ (DSA practice)',
      'https://www.systemdesignprimer.com/ (system design)',
      'https://firebase.google.com/docs (Firebase — fits this app stack)',
    ];

    if (target.toLowerCase().contains('data') || target.toLowerCase().contains('ml')) {
      resources.add('https://www.kaggle.com/learn (intro ML)');
    }

    final timeline = gaps.isEmpty
        ? 'Approx. 3–6 months to reach interview-ready intermediate, depending on weekly hours.'
        : 'Approx. 4–8 months with focused work on: ${gaps.take(4).join(', ')}.';

    return AiAnalysis(
      extractedSkills: extracted.toList(),
      goalAnalysis: goalAnalysis,
      skillGaps: gaps,
      targetRole: target,
      milestones: milestones,
      resources: resources,
      timeline: timeline,
    );
  }

  String _inferTargetRole(String goals, List<String> interests, List<String> skills) {
    final g = '${goals.toLowerCase()} ${interests.join(' ').toLowerCase()}';
    if (g.contains('data') || g.contains('analyst')) return 'Data Analyst';
    if (g.contains('ml') || g.contains('machine')) return 'ML Engineer';
    if (g.contains('mobile') || g.contains('flutter')) return 'Mobile Engineer (Flutter)';
    if (g.contains('frontend') || g.contains('react')) return 'Frontend Engineer';
    if (g.contains('backend') || g.contains('api')) return 'Backend Engineer';
    if (g.contains('devops') || g.contains('cloud')) return 'DevOps / Cloud Engineer';
    if (skills.any((s) => s.toLowerCase().contains('flutter'))) return 'Mobile Engineer (Flutter)';
    return 'Software Engineer';
  }

  Set<String> _skillsForRole(String role) {
    final r = role.toLowerCase();
    if (r.contains('data analyst')) return {'sql', 'pandas', 'excel', 'statistics', 'visualization'};
    if (r.contains('ml')) return {'python', 'tensorflow', 'pandas', 'ml', 'algorithms'};
    if (r.contains('mobile') || r.contains('flutter')) return {'flutter', 'dart', 'git', 'rest', 'testing'};
    if (r.contains('frontend')) return {'javascript', 'react', 'typescript', 'testing', 'git'};
    if (r.contains('backend')) return {'python', 'java', 'sql', 'rest', 'system design', 'docker'};
    if (r.contains('devops')) return {'docker', 'kubernetes', 'aws', 'git', 'python'};
    return {'algorithms', 'system design', 'git', 'testing', 'oop'};
  }
}

class AiAnalysis {
  AiAnalysis({
    required this.extractedSkills,
    required this.goalAnalysis,
    required this.skillGaps,
    required this.targetRole,
    required this.milestones,
    required this.resources,
    required this.timeline,
  });

  final List<String> extractedSkills;
  final String goalAnalysis;
  final List<String> skillGaps;
  final String targetRole;
  final List<String> milestones;
  final List<String> resources;
  final String timeline;
}
