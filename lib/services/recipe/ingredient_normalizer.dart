class IngredientNormalizer {
  static String normalizeDisplayName(String input) {
    return _collapseWhitespace(input);
  }

  static String normalizeCanonicalName(
    String input, {
    bool enablePluralReduction = true,
  }) {
    final collapsed = _collapseWhitespace(input).toLowerCase();
    if (collapsed.isEmpty) {
      return '';
    }

    final withoutAccents = _removeAccents(collapsed);
    if (!enablePluralReduction) {
      return withoutAccents;
    }

    return withoutAccents
        .split(' ')
        .where((token) => token.isNotEmpty)
        .map(_reduceSimplePlural)
        .join(' ');
  }

  static String _collapseWhitespace(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _removeAccents(String input) {
    const replacements = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'æ': 'ae',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'œ': 'oe',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
    };

    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final character = String.fromCharCode(rune);
      buffer.write(replacements[character] ?? character);
    }
    return buffer.toString();
  }

  static String _reduceSimplePlural(String token) {
    if (token.length > 4 && token.endsWith('es')) {
      return token.substring(0, token.length - 2);
    }
    if (token.length > 3 && token.endsWith('s')) {
      return token.substring(0, token.length - 1);
    }
    return token;
  }
}
