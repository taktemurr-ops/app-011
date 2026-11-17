import 'package:flutter_test/flutter_test.dart';
import 'package:tasarruf_360/core/money.dart';

void main(){
  group('money parsing and savings projections',(){
    test('integer money and cents',(){
      expect(parseMinor('123'),12300);
      expect(parseMinor('123,45'),12345);
      expect(parseMinor('123.45'),12345);
      expect(parseMinor('1.234,56'),123456);
      expect(parseMinor('1,234.56'),123456);
    });
    test('Arabic and Persian numeral input',(){
      expect(parseMinor('١٢٣٫٤٥',locale:'ar'),12345);
      expect(parseMinor('۱۲۳٫۴۵',locale:'ar'),12345);
      expect(parseMinor('١٬٢٣٤٫٥٦',locale:'ar'),123456);
    });
    test('rejects invalid text, negatives, separators, excessive precision',(){
      for(final text in ['', '-1','12.3456','1 2','1,23,4','abc','0','١٢x','999999999999']){
        expect(parseMinor(text),isNull,reason:text);
      }
    });
    test('monthly savings estimate rounds up',(){
      expect(monthlyNeeded(10001,DateTime(2026,3,9),DateTime(2026,1,1)),3334);
      expect(monthlyNeeded(0,DateTime(2026,1),DateTime(2026,1)),0);
      expect(monthlyNeeded(100,DateTime(2025),DateTime(2026)),isNull);
    });
    test('projected completion never divides by zero',(){
      expect(projectedFinish(100,0,DateTime(2026,1)),isNull);
      expect(projectedFinish(100,50,DateTime(2026,1)),DateTime(2026,3));
      expect(projectedFinish(0,0,DateTime(2026,1)),DateTime(2026,1));
    });
  });
}
