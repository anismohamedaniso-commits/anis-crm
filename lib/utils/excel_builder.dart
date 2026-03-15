import 'package:excel/excel.dart';
import 'package:anis_crm/models/lead.dart';

/// Builds a styled multi-sheet Excel workbook from leads data.
/// Returns the raw bytes of the .xlsx file.
List<int> buildLeadsExcel(List<LeadModel> leads) {
  final excel = Excel.createExcel();

  // ── Remove default Sheet1 ──
  excel.rename('Sheet1', 'Summary');

  _buildSummarySheet(excel, leads);
  _buildAllLeadsSheet(excel, leads);
  _buildByStatusSheet(excel, leads);
  _buildBySourceSheet(excel, leads);

  excel.setDefaultSheet('Summary');
  return excel.save()!;
}

// ══════════════════════════════════════════════════════════════
// Helpers
// ══════════════════════════════════════════════════════════════

const _orange = 'FFFF7600'; // brand primary – ARGB
const _white = 'FFFFFFFF';
const _darkText = 'FF1A1A2E';
const _headerBg = 'FFFF7600';
const _altRowBg = 'FFF7F7F7';

CellStyle _header() => CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString(_headerBg),
      fontColorHex: ExcelColor.fromHexString(_white),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

CellStyle _kpiLabel() => CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString(_darkText),
    );

CellStyle _kpiValue() => CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Right,
      fontColorHex: ExcelColor.fromHexString(_orange),
    );

/// Converts a hex color like '#2196F3' or '2196F3' to ARGB string 'FF2196F3'
ExcelColor _argb(String hex) {
  final clean = hex.replaceAll('#', '');
  final full = clean.length == 6 ? 'FF$clean' : clean;
  return ExcelColor.fromHexString(full);
}

/// Light pastel tint of a hex color (mix toward white ~20% opacity)
ExcelColor _lightTint(String hex) {
  final clean = hex.replaceAll('#', '').toUpperCase();
  // Convert to int, blend with white (FFFFFF) at 15% strength → light pastel
  final r = int.parse(clean.substring(0, 2), radix: 16);
  final g = int.parse(clean.substring(2, 4), radix: 16);
  final b = int.parse(clean.substring(4, 6), radix: 16);
  final tr = (r * 0.2 + 255 * 0.8).round().clamp(0, 255);
  final tg = (g * 0.2 + 255 * 0.8).round().clamp(0, 255);
  final tb = (b * 0.2 + 255 * 0.8).round().clamp(0, 255);
  final hex2 =
      'FF${tr.toRadixString(16).padLeft(2, '0').toUpperCase()}${tg.toRadixString(16).padLeft(2, '0').toUpperCase()}${tb.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  return ExcelColor.fromHexString(hex2);
}

String _statusColor(LeadStatus s) {
  switch (s) {
    case LeadStatus.fresh:
      return '2196F3';
    case LeadStatus.interested:
      return '4CAF50';
    case LeadStatus.followUp:
      return 'FF9800';
    case LeadStatus.noAnswer:
      return 'FFC107';
    case LeadStatus.converted:
      return '9C27B0';
    case LeadStatus.notInterested:
      return 'F44336';
    case LeadStatus.closed:
      return '607D8B';
  }
}

String _statusLabel(LeadStatus s) {
  switch (s) {
    case LeadStatus.fresh:
      return 'Fresh';
    case LeadStatus.interested:
      return 'Interested';
    case LeadStatus.followUp:
      return 'Follow Up';
    case LeadStatus.noAnswer:
      return 'No Answer';
    case LeadStatus.converted:
      return 'Converted';
    case LeadStatus.notInterested:
      return 'Not Interested';
    case LeadStatus.closed:
      return 'Closed';
  }
}

String _sourceLabel(LeadSource s) {
  switch (s) {
    case LeadSource.whatsapp: return 'WhatsApp';
    case LeadSource.instagram: return 'Instagram';
    case LeadSource.facebook: return 'Facebook';
    case LeadSource.linkedin: return 'LinkedIn';
    case LeadSource.tiktok: return 'TikTok';
    case LeadSource.web: return 'Website';
    case LeadSource.email: return 'Email';
    case LeadSource.phone: return 'Phone';
    case LeadSource.manual: return 'Manual';
    case LeadSource.imported: return 'Imported';
    case LeadSource.zapier: return 'Zapier';
  }
}

void _w(Sheet s, String addr, dynamic value, {CellStyle? style}) {
  final c = s.cell(CellIndex.indexByString(addr));
  if (value is String) {
    c.value = TextCellValue(value);
  } else if (value is int) {
    c.value = IntCellValue(value);
  } else if (value is double) {
    c.value = DoubleCellValue(value);
  }
  if (style != null) c.cellStyle = style;
}

String _colLetter(int col) {
  String result = '';
  int n = col + 1;
  while (n > 0) {
    n--;
    result = String.fromCharCode(65 + n % 26) + result;
    n ~/= 26;
  }
  return result;
}

String _addr(int col, int row) => '${_colLetter(col)}$row';

// ══════════════════════════════════════════════════════════════
// Sheet 1: Summary
// ══════════════════════════════════════════════════════════════

void _buildSummarySheet(Excel excel, List<LeadModel> leads) {
  final sheet = excel['Summary'];

  final total = leads.length;
  final converted = leads.where((l) => l.status == LeadStatus.converted).length;
  final rate = total > 0 ? (converted / total * 100) : 0.0;
  final totalRevenue = leads
      .where((l) => l.dealValue != null && l.status == LeadStatus.converted)
      .fold(0.0, (s, l) => s + l.dealValue!);
  final avgDeal = converted > 0 ? totalRevenue / converted : 0.0;
  final now = DateTime.now();

  // Title
  _w(sheet, 'A1', 'TICK & TALK — LEADS REPORT',
      style: CellStyle(
        bold: true,
        fontSize: 16,
        fontColorHex: ExcelColor.fromHexString(_white),
        backgroundColorHex: ExcelColor.fromHexString(_headerBg),
        horizontalAlign: HorizontalAlign.Left,
      ));

  _w(sheet, 'A2', 'Generated: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      style: CellStyle(italic: true, fontColorHex: ExcelColor.fromHexString('FF888888')));

  // KPI rows
  final kpis = [
    ['Total Leads', total],
    ['Converted', converted],
    ['Conversion Rate (%)', double.parse(rate.toStringAsFixed(2))],
    ['Total Revenue (EGP)', double.parse(totalRevenue.toStringAsFixed(2))],
    ['Avg Deal Value (EGP)', double.parse(avgDeal.toStringAsFixed(2))],
    ['Active Leads', leads.where((l) => [LeadStatus.fresh, LeadStatus.interested, LeadStatus.followUp, LeadStatus.noAnswer].contains(l.status)).length],
    ['Follow-ups Today', leads.where((l) => l.nextFollowupAt != null && _isToday(l.nextFollowupAt!)).length],
    ['Overdue Follow-ups', leads.where((l) => l.nextFollowupAt != null && l.nextFollowupAt!.isBefore(now) && !_isToday(l.nextFollowupAt!)).length],
  ];

  _w(sheet, 'A4', 'METRIC', style: _header());
  _w(sheet, 'B4', 'VALUE', style: _header());

  for (var i = 0; i < kpis.length; i++) {
    final row = i + 5;
    final isAlt = i % 2 == 1;
    final rowBg = isAlt ? _altRowBg : 'FFFFFFFF';
    final labelStyle = CellStyle(
      bold: false,
      backgroundColorHex: ExcelColor.fromHexString(rowBg),
      fontColorHex: ExcelColor.fromHexString(_darkText),
    );
    final valueStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString(rowBg),
      fontColorHex: ExcelColor.fromHexString(_orange),
      horizontalAlign: HorizontalAlign.Right,
    );
    _w(sheet, 'A$row', kpis[i][0] as String, style: labelStyle);
    _w(sheet, 'B$row', kpis[i][1], style: valueStyle);
  }

  // By Status section
  final statusRows = LeadStatus.values.map((s) {
    final count = leads.where((l) => l.status == s).length;
    return [s, count];
  }).where((r) => (r[1] as int) > 0).toList();

  _w(sheet, 'A14', 'BY STATUS', style: _header());
  _w(sheet, 'B14', 'COUNT', style: _header());
  _w(sheet, 'C14', '%', style: _header());

  for (var i = 0; i < statusRows.length; i++) {
    final s = statusRows[i][0] as LeadStatus;
    final count = statusRows[i][1] as int;
    final pct = total > 0 ? (count / total * 100) : 0.0;
    final row = i + 15;
    final hex = _statusColor(s);
    _w(sheet, 'A$row', _statusLabel(s),
        style: CellStyle(
          bold: true,
          backgroundColorHex: _argb(hex),
          fontColorHex: ExcelColor.fromHexString(_white),
        ));
    _w(sheet, 'B$row', count,
        style: CellStyle(
          backgroundColorHex: _lightTint(hex),
          horizontalAlign: HorizontalAlign.Center,
          bold: true,
        ));
    _w(sheet, 'C$row', double.parse(pct.toStringAsFixed(1)),
        style: CellStyle(
          backgroundColorHex: _lightTint(hex),
          horizontalAlign: HorizontalAlign.Center,
        ));
  }

  // Set column widths
  sheet.setColumnWidth(0, 28);
  sheet.setColumnWidth(1, 18);
  sheet.setColumnWidth(2, 10);
}

bool _isToday(DateTime dt) {
  final now = DateTime.now();
  return dt.year == now.year && dt.month == now.month && dt.day == now.day;
}

// ══════════════════════════════════════════════════════════════
// Sheet 2: All Leads
// ══════════════════════════════════════════════════════════════

void _buildAllLeadsSheet(Excel excel, List<LeadModel> leads) {
  final sheet = excel['All Leads'];
  final headers = ['#', 'Name', 'Status', 'Source', 'Campaign', 'Phone', 'Email', 'Deal Value (EGP)', 'Assigned To', 'Created', 'Last Contacted', 'Next Follow-up'];

  // Header row
  for (var i = 0; i < headers.length; i++) {
    _w(sheet, _addr(i, 1), headers[i], style: _header());
  }

  for (var i = 0; i < leads.length; i++) {
    final l = leads[i];
    final row = i + 2;
    final hex = _statusColor(l.status);
    final lightBg = _lightTint(hex);
    final rowStyle = CellStyle(backgroundColorHex: lightBg, fontColorHex: ExcelColor.fromHexString(_darkText));
    final statusStyle = CellStyle(
      backgroundColorHex: _argb(hex),
      fontColorHex: ExcelColor.fromHexString(_white),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    _w(sheet, _addr(0, row), i + 1, style: rowStyle);
    _w(sheet, _addr(1, row), l.name, style: rowStyle);
    _w(sheet, _addr(2, row), _statusLabel(l.status), style: statusStyle);
    _w(sheet, _addr(3, row), _sourceLabel(l.source), style: rowStyle);
    _w(sheet, _addr(4, row), l.campaign ?? '', style: rowStyle);
    _w(sheet, _addr(5, row), l.phone ?? '', style: rowStyle);
    _w(sheet, _addr(6, row), l.email ?? '', style: rowStyle);
    _w(sheet, _addr(7, row), l.dealValue != null ? double.parse(l.dealValue!.toStringAsFixed(2)) : 0.0, style: rowStyle);
    _w(sheet, _addr(8, row), l.assignedToName ?? '', style: rowStyle);
    _w(sheet, _addr(9, row), _fmtDate(l.createdAt), style: rowStyle);
    _w(sheet, _addr(10, row), l.lastContactedAt != null ? _fmtDate(l.lastContactedAt!) : '', style: rowStyle);
    _w(sheet, _addr(11, row), l.nextFollowupAt != null ? _fmtDate(l.nextFollowupAt!) : '', style: rowStyle);
  }

  // Column widths
  sheet.setColumnWidth(0, 5);   // #
  sheet.setColumnWidth(1, 24);  // Name
  sheet.setColumnWidth(2, 16);  // Status
  sheet.setColumnWidth(3, 14);  // Source
  sheet.setColumnWidth(4, 16);  // Campaign
  sheet.setColumnWidth(5, 16);  // Phone
  sheet.setColumnWidth(6, 24);  // Email
  sheet.setColumnWidth(7, 18);  // Deal Value
  sheet.setColumnWidth(8, 18);  // Assigned To
  sheet.setColumnWidth(9, 14);  // Created
  sheet.setColumnWidth(10, 16); // Last Contacted
  sheet.setColumnWidth(11, 16); // Next Follow-up
}

// ══════════════════════════════════════════════════════════════
// Sheet 3: By Status
// ══════════════════════════════════════════════════════════════

void _buildByStatusSheet(Excel excel, List<LeadModel> leads) {
  final sheet = excel['By Status'];
  final total = leads.length;

  _w(sheet, 'A1', 'STATUS', style: _header());
  _w(sheet, 'B1', 'COUNT', style: _header());
  _w(sheet, 'C1', '% OF TOTAL', style: _header());
  _w(sheet, 'D1', 'REVENUE (EGP)', style: _header());

  var row = 2;
  for (final s in LeadStatus.values) {
    final group = leads.where((l) => l.status == s).toList();
    if (group.isEmpty) continue;
    final count = group.length;
    final revenue = group.fold(0.0, (acc, l) => acc + (l.dealValue ?? 0));
    final pct = total > 0 ? (count / total * 100) : 0.0;
    final hex = _statusColor(s);

    _w(sheet, 'A$row', _statusLabel(s),
        style: CellStyle(
          bold: true,
          backgroundColorHex: _argb(hex),
          fontColorHex: ExcelColor.fromHexString(_white),
        ));
    _w(sheet, 'B$row', count,
        style: CellStyle(
          backgroundColorHex: _lightTint(hex),
          horizontalAlign: HorizontalAlign.Center,
          bold: true,
        ));
    _w(sheet, 'C$row', double.parse(pct.toStringAsFixed(1)),
        style: CellStyle(
          backgroundColorHex: _lightTint(hex),
          horizontalAlign: HorizontalAlign.Center,
        ));
    _w(sheet, 'D$row', double.parse(revenue.toStringAsFixed(2)),
        style: CellStyle(
          backgroundColorHex: _lightTint(hex),
          horizontalAlign: HorizontalAlign.Right,
        ));
    row++;
  }

  sheet.setColumnWidth(0, 18);
  sheet.setColumnWidth(1, 10);
  sheet.setColumnWidth(2, 14);
  sheet.setColumnWidth(3, 18);
}

// ══════════════════════════════════════════════════════════════
// Sheet 4: By Source
// ══════════════════════════════════════════════════════════════

void _buildBySourceSheet(Excel excel, List<LeadModel> leads) {
  final sheet = excel['By Source'];
  final total = leads.length;

  _w(sheet, 'A1', 'SOURCE', style: _header());
  _w(sheet, 'B1', 'COUNT', style: _header());
  _w(sheet, 'C1', '% OF TOTAL', style: _header());

  final bySource = <LeadSource, int>{};
  for (final l in leads) {
    bySource[l.source] = (bySource[l.source] ?? 0) + 1;
  }

  final sourceColors = {
    LeadSource.whatsapp: '25D366',
    LeadSource.instagram: 'E1306C',
    LeadSource.facebook: '1877F2',
    LeadSource.linkedin: '0A66C2',
    LeadSource.tiktok: '333333',
    LeadSource.web: '607D8B',
    LeadSource.email: '4285F4',
    LeadSource.phone: '34A853',
    LeadSource.manual: 'FF7600',
    LeadSource.imported: '9E9E9E',
  };

  final sorted = bySource.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  var row = 2;
  for (final e in sorted) {
    final pct = total > 0 ? (e.value / total * 100) : 0.0;
    final hex = sourceColors[e.key] ?? '9E9E9E';

    _w(sheet, 'A$row', _sourceLabel(e.key),
        style: CellStyle(
          bold: true,
          backgroundColorHex: _argb(hex),
          fontColorHex: ExcelColor.fromHexString(_white),
        ));
    _w(sheet, 'B$row', e.value,
        style: CellStyle(
          backgroundColorHex: _lightTint(hex),
          horizontalAlign: HorizontalAlign.Center,
          bold: true,
        ));
    _w(sheet, 'C$row', double.parse(pct.toStringAsFixed(1)),
        style: CellStyle(
          backgroundColorHex: _lightTint(hex),
          horizontalAlign: HorizontalAlign.Center,
        ));
    row++;
  }

  sheet.setColumnWidth(0, 16);
  sheet.setColumnWidth(1, 10);
  sheet.setColumnWidth(2, 14);
}

String _fmtDate(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
