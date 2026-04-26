// Dart imports:
import 'dart:math';

// Package imports:
import 'package:http/http.dart' as http;

/// Contribution from [adarshvijayanp] - [Buy me a coffee](https://www.instagram.com/adarshvijayanp)

/// Extension methods for a notNull check [dynamic].
///
/// dynamic is a keyword to assign a value in a variable with no type checking.
extension NotNullExtensions<E> on dynamic {

  /// Returns `true` if it's `notnull`.
  bool get isNotNull  => this != null ? true : false;

}

/// Extension methods for a nullable check [Object].
///
/// Object is the parent class of all classes in Dart and it can be used as a data type with type checking
extension NullableObjectExtensions<E> on Object? {

  /// Returns `true` if  `int`.
  bool get isInt => this is int;

  /// Returns `true` if `String`.
  bool get isString => this is String;

  /// Returns `true` if `http.Response`.
  bool get isHttpResponse => this is http.Response;

  /// Returns `true` if `http.StreamedResponse`.
  bool get isHttpStreamedResponse => this is http.StreamedResponse;

}

/// Extension methods for a nullable [String].
extension NullableStringExtensions<E> on String? {

  /// Returns `true` if this string is `null` or `empty`.
  bool get isNullOrEmpty {
    return this?.isEmpty ?? true;
  }

  /// Returns `true` if this string is not `null` and `not empty`.
  bool get isNotNullNorEmpty {
    return this?.isNotEmpty ?? false;
  }

  /// Returns `true` if this string is `null` or `blank`.
  bool get isNullOrBlank {
    return this?.trim().isEmpty ?? true;
  }

  /// Returns `true` if this string is not `null` and `not blank`.
  bool get isNotNullNorBlank {
    return this?.trim().isNotEmpty ?? false;
  }
}


/// Extension methods for a [String].
extension StringExtensions<E> on String {

  /// Converts first character in this string to upper case.
  ///
  /// If the first character of the string is already in upper case,
  /// this method returns `this`.
  ///
  /// Example:
  /// ```
  /// 'alphabet'.firstToUpper(); // 'Alphabet'
  /// 'ABC'.firstToUpper();      // 'ABC
  /// ```
  ///
  /// This function uses `toUpperCase()`, that uses
  /// the language independent Unicode mapping and thus only
  /// works in some languages.
  String firstToUpper() =>
      isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : this;

  /// Converts first character in this string to lower case.
  ///
  /// If the first character of the string is already in lower case,
  /// this method returns `this`.
  ///
  /// Example:
  /// ```
  /// 'Alphabet'.firstToLower(); // 'alphabet'
  /// 'ABC'.firstToLower();      // 'aBC'
  /// 'abc'.firstToLower();      // 'abc'
  /// ```
  ///
  /// This function uses `toLowerCase()`, that uses
  /// the language independent Unicode mapping and thus only
  /// works in some languages.
  String firstToLower() =>
      isNotEmpty ? '${this[0].toLowerCase()}${substring(1)}' : this;

  /// Splits string by chunks with specified [size].
  ///
  /// If string is empty than empty [Iterable] will be returned.
  ///
  /// If [size] less or equal 0, that [ArgumentError] will be raised.
  Iterable<String> chunks(int size) sync* {
    if (isEmpty) return;

    if (size <= 0) {
      throw ArgumentError.value(size, 'size', 'Should be more than zero');
    }

    final total = length;
    if (total <= size) {
      yield this;
    } else {
      var start = 0;
      do {
        final end = start + size;
        yield substring(start, min(end, total));
        start = end;
      } while (start < total);
    }
  }
}

