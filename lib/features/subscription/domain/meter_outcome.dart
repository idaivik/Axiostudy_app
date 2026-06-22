/// Client mapping of the server `consume_meter` outcomes to UI states
/// (BILLING_BUCKET1_BUILD_PROMPT.md §2.2, usage_meters.sql reason codes).
///
/// Every metered AI surface returns one of four outcomes; this is the single
/// place the client interprets them so each feature isn't re-inventing the
/// 402 / cap / ok branching. [GenerationResult] (practice) predates this and
/// stays as-is; new surfaces (narrative, breakdown) use [MeterOutcome].
enum MeterStatus {
  /// Allowed — render the feature.
  ok,

  /// 7-day trial AI hard-lock. The user is already paying, so this is NOT the
  /// paywall — show "unlocks when your trial converts".
  trialLocked,

  /// Free / lapsed, or the tier isn't entitled to this meter → open the paywall.
  noEntitlement,

  /// Monthly cap hit → feature-specific message (often a Pro upsell).
  capReached,

  /// Transient / network / unexpected — show a soft retry, never a wall.
  error,
}

class MeterOutcome {
  final MeterStatus status;

  /// Credits left this cycle when the server reported one (null when not metered
  /// or not provided).
  final int? remaining;

  /// Effective plan the server resolved ('basic' | 'pro' | 'free').
  final String? plan;

  /// Cycle cap + usage for this meter (from the read-only `meter_status` peek;
  /// null on the consume path, which only reports `remaining`).
  final int? limit;
  final int? used;

  /// When the monthly cycle rolls over (from `meter_status`).
  final DateTime? resetsAt;

  const MeterOutcome(
    this.status, {
    this.remaining,
    this.plan,
    this.limit,
    this.used,
    this.resetsAt,
  });

  bool get ok => status == MeterStatus.ok;
  bool get isTrialLocked => status == MeterStatus.trialLocked;
  bool get isNoEntitlement => status == MeterStatus.noEntitlement;
  bool get isCapReached => status == MeterStatus.capReached;
  bool get isError => status == MeterStatus.error;

  /// Map a server reason code (+ ok flag) to a [MeterStatus]. Folds in the
  /// legacy reason aliases the generation path used.
  factory MeterOutcome.fromReason(
    String? reason, {
    bool ok = false,
    int? remaining,
    String? plan,
    int? limit,
    int? used,
    DateTime? resetsAt,
  }) {
    final status = ok
        ? MeterStatus.ok
        : switch (reason) {
            'trial_ai_locked' => MeterStatus.trialLocked,
            'no_entitlement' || 'free_plan_no_generation' =>
              MeterStatus.noEntitlement,
            'cap_reached' || 'monthly_cap_reached' => MeterStatus.capReached,
            _ => MeterStatus.error,
          };
    return MeterOutcome(status,
        remaining: remaining,
        plan: plan,
        limit: limit,
        used: used,
        resetsAt: resetsAt);
  }

  /// Parse a `consume_meter` jsonb result, a metered edge-function body, or a
  /// `meter_status` peek (`{ ok, reason?, remaining?, plan?, limit?, used?,
  /// resets_at? }`).
  factory MeterOutcome.fromJson(Map<String, dynamic> j) =>
      MeterOutcome.fromReason(
        j['reason'] as String?,
        ok: j['ok'] == true,
        remaining: (j['remaining'] as num?)?.toInt(),
        plan: j['plan'] as String?,
        limit: (j['limit'] as num?)?.toInt(),
        used: (j['used'] as num?)?.toInt(),
        resetsAt: DateTime.tryParse(j['resets_at'] as String? ?? ''),
      );
}
