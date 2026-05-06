class MeditationTrack {
  final String id;
  final String label;
  final String category;
  final String subCategory;
  final String displayCategory;
  final String assetPath;
  final int? durationSeconds;
  final String? durationLabel;
  final String? author;
  final String? license;
  final String? sourceUrl;
  final bool isRoyaltyFree;
  final bool contentIdRegistered;
  final bool isAiGenerated;
  final bool isActive;
  final int sortOrder;

  const MeditationTrack({
    required this.id,
    required this.label,
    required this.category,
    this.subCategory = '',
    this.displayCategory = '',
    required this.assetPath,
    this.durationSeconds,
    this.durationLabel,
    this.author,
    this.license,
    this.sourceUrl,
    this.isRoyaltyFree = true,
    this.contentIdRegistered = false,
    this.isAiGenerated = false,
    this.isActive = true,
    this.sortOrder = 0,
  });

  MeditationTrack copyWith({
    bool? isActive,
    int? sortOrder,
  }) {
    return MeditationTrack(
      id: id,
      label: label,
      category: category,
      subCategory: subCategory,
      displayCategory: displayCategory,
      assetPath: assetPath,
      durationSeconds: durationSeconds,
      durationLabel: durationLabel,
      author: author,
      license: license,
      sourceUrl: sourceUrl,
      isRoyaltyFree: isRoyaltyFree,
      contentIdRegistered: contentIdRegistered,
      isAiGenerated: isAiGenerated,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
