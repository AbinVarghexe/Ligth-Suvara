import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:sundayschool_app/models/custom_field.dart';
import 'package:sundayschool_app/utils/downloads_helper.dart';

class ExcelRegistrationHelper {
  /// Generates an Excel template matching the active program fields.
  /// Mandatory fields are marked with '*' in column headers.
  static Future<String?> generateAndDownloadTemplate({
    required String programName,
    required String targetAudience,
    required List<CustomField> activeFields,
  }) async {
    try {
      final sanitizedProgramName = programName
          .replaceAll(RegExp(r'[^\w\s\-]'), '')
          .replaceAll(' ', '_');

      var excel = Excel.createExcel();
      String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      Sheet sheet = excel[defaultSheet];

      // Build Header Row
      List<CellValue> headers = [];
      for (var field in activeFields) {
        String name = field.name;
        if (field.isMandatory) {
          name += ' *';
        } else {
          name += ' (Optional)';
        }
        headers.add(TextCellValue(name));
      }
      sheet.appendRow(headers);

      final List<int>? fileBytes = excel.encode();
      if (fileBytes == null || fileBytes.isEmpty) return null;

      final fileName = '${sanitizedProgramName}_${targetAudience}_template.xlsx';

      final savedPath = await DownloadsHelper.saveToDownloads(
        Uint8List.fromList(fileBytes),
        fileName,
      );

      return savedPath;
    } catch (e) {
      debugPrint('Error generating template: $e');
      return null;
    }
  }

  /// Parses uploaded excel bytes into a list of field value maps matching CustomField IDs.
  static ExcelParseResult parseUploadedExcel({
    required List<int> bytes,
    required List<CustomField> activeFields,
  }) {
    List<Map<String, String>> parsedRecords = [];
    List<String> warnings = [];

    try {
      try {
        var excel = Excel.decodeBytes(bytes);
        if (excel.tables.isNotEmpty) {
          var tableKey = excel.tables.keys.first;
          var table = excel.tables[tableKey];
          if (table != null && table.rows.isNotEmpty) {
            // Process XLSX table
            var headerRow = table.rows.first;
            Map<int, CustomField> columnIndexToField = {};

            for (int i = 0; i < headerRow.length; i++) {
              final cell = headerRow[i];
              if (cell == null || cell.value == null) continue;
              final headerText = cell.value.toString().trim().toLowerCase();

              for (var field in activeFields) {
                final fieldNameClean = field.name.trim().toLowerCase();
                if (headerText == fieldNameClean ||
                    headerText == '$fieldNameClean *' ||
                    headerText == '$fieldNameClean (optional)' ||
                    headerText.startsWith(fieldNameClean)) {
                  columnIndexToField[i] = field;
                  break;
                }
              }
            }

            if (columnIndexToField.isNotEmpty) {
              for (int r = 1; r < table.rows.length; r++) {
                var row = table.rows[r];
                if (row.isEmpty) continue;

                bool isEmptyRow = true;
                for (var cell in row) {
                  if (cell != null &&
                      cell.value != null &&
                      cell.value.toString().trim().isNotEmpty) {
                    isEmptyRow = false;
                    break;
                  }
                }
                if (isEmptyRow) continue;

                Map<String, String> record = {};
                bool missingMandatory = false;
                String missingFieldName = '';

                for (var entry in columnIndexToField.entries) {
                  int colIndex = entry.key;
                  CustomField field = entry.value;

                  String cellValue = '';
                  if (colIndex < row.length &&
                      row[colIndex] != null &&
                      row[colIndex]!.value != null) {
                    cellValue = row[colIndex]!.value.toString().trim();
                  }

                  if (field.isMandatory && cellValue.isEmpty) {
                    missingMandatory = true;
                    missingFieldName = field.name;
                    break;
                  }

                  record[field.id] = cellValue;
                }

                for (var field in activeFields) {
                  if (!record.containsKey(field.id)) {
                    record[field.id] = '';
                  }
                }

                if (r == 1 &&
                    (record.values.contains('Sample Text') ||
                        record.values.contains('9876543210'))) {
                  continue;
                }

                if (missingMandatory) {
                  warnings.add(
                      'Row ${r + 1} skipped: Mandatory field "$missingFieldName" was empty.');
                  continue;
                }

                parsedRecords.add(record);
              }

              return ExcelParseResult(
                records: parsedRecords,
                warnings: warnings,
              );
            }
          }
        }
      } catch (_) {
        // Fallback to CSV parsing below
      }

      // CSV Fallback Parsing
      final String content = String.fromCharCodes(bytes);
      final List<String> lines = content
          .split(RegExp(r'\r?\n'))
          .where((l) => l.trim().isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        return ExcelParseResult(records: [], warnings: ['The file is empty.']);
      }

      final List<String> rawHeaders = lines.first.split(',');
      Map<int, CustomField> csvColToField = {};

      for (int i = 0; i < rawHeaders.length; i++) {
        final headerText =
            rawHeaders[i].replaceAll('"', '').trim().toLowerCase();

        for (var field in activeFields) {
          final fieldNameClean = field.name.trim().toLowerCase();
          if (headerText == fieldNameClean ||
              headerText == '$fieldNameClean *' ||
              headerText == '$fieldNameClean (optional)' ||
              headerText.startsWith(fieldNameClean)) {
            csvColToField[i] = field;
            break;
          }
        }
      }

      if (csvColToField.isEmpty) {
        return ExcelParseResult(
          records: [],
          warnings: [
            'Could not match column headers to program fields. Please use the downloaded template.'
          ],
        );
      }

      for (int r = 1; r < lines.length; r++) {
        final rowCells = lines[r].split(',');
        Map<String, String> record = {};
        bool missingMandatory = false;
        String missingFieldName = '';

        for (var entry in csvColToField.entries) {
          int colIndex = entry.key;
          CustomField field = entry.value;

          String cellValue = '';
          if (colIndex < rowCells.length) {
            cellValue = rowCells[colIndex].replaceAll('"', '').trim();
          }

          if (field.isMandatory && cellValue.isEmpty) {
            missingMandatory = true;
            missingFieldName = field.name;
            break;
          }

          record[field.id] = cellValue;
        }

        for (var field in activeFields) {
          if (!record.containsKey(field.id)) {
            record[field.id] = '';
          }
        }

        if (missingMandatory) {
          warnings.add(
              'Row ${r + 1} skipped: Mandatory field "$missingFieldName" was empty.');
          continue;
        }

        parsedRecords.add(record);
      }

      return ExcelParseResult(
        records: parsedRecords,
        warnings: warnings,
      );
    } catch (e) {
      debugPrint('Error parsing file: $e');
      warnings.add('Error reading file: ${e.toString()}');
    }

    return ExcelParseResult(
      records: parsedRecords,
      warnings: warnings,
    );
  }
}

class ExcelParseResult {
  final List<Map<String, String>> records;
  final List<String> warnings;

  ExcelParseResult({
    required this.records,
    required this.warnings,
  });
}
