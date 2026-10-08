class Station {
  const Station({
    required this.id,
    required this.name,
    required this.url,
    required this.description,
    this.hashtag,
    this.link,
  });

  final String id;
  final String name;
  final String url;
  final String description;
  final String? hashtag;

  /// Donation / homepage link, if the station has one.
  final String? link;

  /// Shareable web link that opens this station on fm.aux.eco.
  String? get shareUrl =>
      hashtag == null ? null : 'https://fm.aux.eco/#$hashtag';
}
