import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sundayschool_app/utils/app_launcher.dart';

class LinkableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final bool softWrap;
  final TextOverflow overflow;
  final int? maxLines;
  final Color? linkColor;

  const LinkableText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.maxLines,
    this.linkColor,
  });

  @override
  Widget build(BuildContext context) {
    final RegExp urlRegex = RegExp(r"(https?://[^\s]+)");
    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final match in urlRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }

      final url = text.substring(match.start, match.end);

      // Clean up trailing punctuation if the regex captured it incorrectly
      String cleanUrl = url;
      String trailingPunctuation = "";
      while (cleanUrl.isNotEmpty &&
          (cleanUrl.endsWith('.') ||
              cleanUrl.endsWith(',') ||
              cleanUrl.endsWith(')') ||
              cleanUrl.endsWith('?'))) {
        trailingPunctuation = cleanUrl.substring(cleanUrl.length - 1) + trailingPunctuation;
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      spans.add(
        TextSpan(
          text: cleanUrl,
          style: TextStyle(
            color: linkColor ?? Colors.blue.shade700,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.bold,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              AppLauncher.launchURL(cleanUrl);
            },
        ),
      );

      if (trailingPunctuation.isNotEmpty) {
        spans.add(TextSpan(text: trailingPunctuation));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: style,
      textAlign: textAlign,
      textDirection: textDirection,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}
