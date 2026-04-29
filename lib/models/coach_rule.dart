class RuleCondition {
  final String field;
  final String op;
  final Object? value;

  const RuleCondition({
    required this.field,
    required this.op,
    required this.value,
  });
}

class Rule {
  final String id;
  final String description;
  final String event;
  final List<RuleCondition> conditions;
  final int priority;
  final int cooldownSeconds;
  final String cooldownTopic;
  final String aiIntent;
  final String promptTemplate;
  final List<String> exampleOutputs;
  final String fallbackMessage;
  final String followupPolicy;

  const Rule({
    required this.id,
    required this.description,
    required this.event,
    required this.conditions,
    required this.priority,
    this.cooldownSeconds = 0,
    this.cooldownTopic = '',
    this.aiIntent = '',
    this.promptTemplate = '',
    this.exampleOutputs = const [],
    this.fallbackMessage = '',
    this.followupPolicy = 'none',
  });
}
