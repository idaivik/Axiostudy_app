/// A single entry on the feature-voting board (Bucket 2 §3b).
///
/// Built from a `get_feature_requests()` RPC row, which already carries the
/// aggregate [voteCount] and the calling user's [hasVoted] flag — so the client
/// never N+1s per row.
class FeatureRequest {
  final String id;
  final String title;
  final String? description;
  final String status; // open | planned | shipped | closed
  final DateTime createdAt;
  final int voteCount;
  final bool hasVoted;

  const FeatureRequest({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.createdAt,
    required this.voteCount,
    required this.hasVoted,
  });

  factory FeatureRequest.fromJson(Map<String, dynamic> json) {
    return FeatureRequest(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'open',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      hasVoted: json['has_voted'] as bool? ?? false,
    );
  }

  FeatureRequest copyWith({int? voteCount, bool? hasVoted}) => FeatureRequest(
        id: id,
        title: title,
        description: description,
        status: status,
        createdAt: createdAt,
        voteCount: voteCount ?? this.voteCount,
        hasVoted: hasVoted ?? this.hasVoted,
      );
}
