import '../utils/api_helpers.dart';

class LinkPreview {
  static final RegExp _bookPath = RegExp(r'^/b/([0-9a-fA-F]{32})/?$');

  final String url;
  final String siteName;
  final String title;
  final String? description;
  final String? imageUrl;
  final String kind;
  final double? price;

  const LinkPreview({
    required this.url,
    required this.siteName,
    required this.title,
    this.description,
    this.imageUrl,
    this.kind = 'web',
    this.price,
  });

  bool get isBook => kind == 'book' && bookToken != null;

  String? get bookToken {
    final match = _bookPath.firstMatch(Uri.tryParse(url)?.path ?? '');
    return match?.group(1)?.toLowerCase();
  }

  static LinkPreview? tryParse(Object? json) {
    if (json is! Map) return null;
    final title = '${json['title'] ?? ''}'.trim();
    final url = '${json['url'] ?? ''}'.trim();
    if (title.isEmpty || url.isEmpty) return null;
    final description = '${json['description'] ?? ''}'.trim();
    return LinkPreview(
      url: url,
      siteName: '${json['site_name'] ?? ''}'.trim(),
      title: title,
      description: description.isEmpty ? null : description,
      imageUrl: resolveAssetUrl(json['image_url']),
      kind: json['kind'] == 'book' ? 'book' : 'web',
      price: json['price'] == null ? null : parseDouble(json['price']),
    );
  }
}
