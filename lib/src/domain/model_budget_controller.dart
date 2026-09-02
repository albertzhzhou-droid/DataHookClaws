class ModelBudgetDecision {
  const ModelBudgetDecision.allowed() : allowed = true, reason = '';

  const ModelBudgetDecision.denied(this.reason) : allowed = false;

  final bool allowed;
  final String reason;
}

class ModelBudgetSnapshot {
  const ModelBudgetSnapshot({
    required this.callsInWindow,
    required this.maxCallsPerMinute,
    required this.cooldownUntil,
    required this.timeout,
    required this.maxTokens,
  });

  final int callsInWindow;
  final int maxCallsPerMinute;
  final DateTime? cooldownUntil;
  final Duration timeout;
  final int maxTokens;
}

class ModelBudgetController {
  ModelBudgetController({
    int maxCallsPerMinute = 6,
    Duration timeout = const Duration(seconds: 3),
    int maxTokens = 256,
    Duration failureCooldown = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : maxCallsPerMinute = maxCallsPerMinute < 0 ? 6 : maxCallsPerMinute,
       timeout = timeout <= Duration.zero
           ? const Duration(seconds: 3)
           : timeout,
       maxTokens = maxTokens <= 0 ? 256 : maxTokens,
       failureCooldown = failureCooldown <= Duration.zero
           ? const Duration(seconds: 30)
           : failureCooldown,
       _clock = clock ?? DateTime.now;

  final int maxCallsPerMinute;
  final Duration timeout;
  final int maxTokens;
  final Duration failureCooldown;
  final DateTime Function() _clock;
  final List<DateTime> _callTimes = [];
  DateTime? _cooldownUntil;

  ModelBudgetDecision evaluate(String query) {
    final now = _clock();
    _prune(now);
    if (query.trim().length < 2) {
      return const ModelBudgetDecision.denied('Query is too short.');
    }
    final cooldown = _cooldownUntil;
    if (cooldown != null && now.isBefore(cooldown)) {
      return const ModelBudgetDecision.denied('Model budget is cooling down.');
    }
    if (_callTimes.length >= maxCallsPerMinute) {
      return const ModelBudgetDecision.denied('Model call rate limit reached.');
    }
    return const ModelBudgetDecision.allowed();
  }

  void recordCall() {
    final now = _clock();
    _prune(now);
    _callTimes.add(now);
  }

  void recordFailure() {
    _cooldownUntil = _clock().add(failureCooldown);
  }

  ModelBudgetSnapshot snapshot() {
    final now = _clock();
    _prune(now);
    return ModelBudgetSnapshot(
      callsInWindow: _callTimes.length,
      maxCallsPerMinute: maxCallsPerMinute,
      cooldownUntil: _cooldownUntil,
      timeout: timeout,
      maxTokens: maxTokens,
    );
  }

  void _prune(DateTime now) {
    _callTimes.removeWhere(
      (time) => now.difference(time) >= const Duration(minutes: 1),
    );
    final cooldown = _cooldownUntil;
    if (cooldown != null && !now.isBefore(cooldown)) {
      _cooldownUntil = null;
    }
  }
}
