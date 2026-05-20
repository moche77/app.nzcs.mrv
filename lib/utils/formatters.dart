import 'package:intl/intl.dart';

class Fmt {
  static final _num = NumberFormat('#,##0.##');
  static final _num4 = NumberFormat('#,##0.0000');
  static final _pct = NumberFormat('#,##0.00');
  static final _date = DateFormat('yyyy-MM-dd');
  static final _dateTime = DateFormat('yyyy-MM-dd HH:mm');

  static String num2(double v) => _num.format(v);
  static String num4(double v) => _num4.format(v);
  static String pct(double v) => '${_pct.format(v)}%';
  static String pctRatio(double v) => '${_pct.format(v * 100)}%';
  static String date(DateTime d) => _date.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);
  static String monthLabel(String yyyymm) {
    final parts = yyyymm.split('-');
    if (parts.length != 2) return yyyymm;
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
    return DateFormat('MMM yyyy').format(dt);
  }
}
