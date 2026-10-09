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

  /// Description, or the stream's host for stations without one.
  String get subtitle =>
      description.isNotEmpty ? description : (Uri.tryParse(url)?.host ?? url);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'description': description,
    'hashtag': ?hashtag,
    'link': ?link,
  };

  factory Station.fromJson(Map<String, dynamic> json) => Station(
    id: json['id'] as String,
    name: json['name'] as String,
    url: json['url'] as String,
    description: json['description'] as String? ?? '',
    hashtag: json['hashtag'] as String?,
    link: json['link'] as String?,
  );
}
