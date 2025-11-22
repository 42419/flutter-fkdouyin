class AwemeExtractResult {
  final String? awemeId;
  final String? shortLink;
  final String? userProfileUrl;
  final bool needsRedirect;
  AwemeExtractResult({this.awemeId,this.shortLink,this.userProfileUrl,this.needsRedirect=false});
}

class AwemeExtractor {
  static final _idRegex = RegExp(r'^\d{18,19}$');
  static final _urlPatterns = <RegExp>[
    RegExp(r'aweme_id=(\d{18,19})'),
    RegExp(r'video\/(\d{18,19})'),
    RegExp(r'(\d{18,19})\?'),
    RegExp(r'(\d{18,19})/?$'),
  ];
  static final _shortLinkRegex = RegExp(r'https://v\.douyin\.com/[a-zA-Z0-9_-]+');
  static final _userProfileRegex = RegExp(r'https://www\.douyin\.com/user/[^/?]+');
  static final _possibleIdRegex = RegExp(r'(\d{18,19})');

  static AwemeExtractResult parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return AwemeExtractResult();
    if (_idRegex.hasMatch(trimmed)) {
      return AwemeExtractResult(awemeId: trimmed);
    }
    for (final p in _urlPatterns) {
      final m = p.firstMatch(trimmed);
      if (m != null) {
        return AwemeExtractResult(awemeId: m.group(1));
      }
    }
    final shortM = _shortLinkRegex.firstMatch(trimmed);
    if (shortM != null) {
      final link = shortM.group(0)!.replaceAll(RegExp(r'/$'), '');
      return AwemeExtractResult(shortLink: link, needsRedirect: true);
    }
    final userM = _userProfileRegex.firstMatch(trimmed);
    if (userM != null) {
      return AwemeExtractResult(userProfileUrl: userM.group(0));
    }
    final possible = _possibleIdRegex.firstMatch(trimmed);
    if (possible != null) {
      return AwemeExtractResult(awemeId: possible.group(1));
    }
    return AwemeExtractResult();
  }
}
