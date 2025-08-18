import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportGenerator {
  /// Generates a PDF report for transactions.
  ///
  /// [reportData] is a Map with keys:
  /// - "from": DateTime - report start date
  /// - "to": DateTime - report end date
  /// - "product": String - product name or "All Products"
  /// - "transactions": List<dynamic> - list of transactions data
  /// - "totalPurchase": double - total purchase amount
  /// - "totalSales": double - total sales amount
  /// - "type": String - filter type: "Purchase", "Sales", "Both"
  ///
  /// Returns the local file path of the saved PDF.
  static Future<String> generateReport(Map<String, dynamic> reportData) async {
    try {
      final pdf = pw.Document();

      final fromDate = reportData['from'] as DateTime;
      final toDate = reportData['to'] as DateTime;
      final product = reportData['product'] as String;
      final transactions = reportData['transactions'] as List<dynamic>;
      final totalPurchase = reportData['totalPurchase'] as double;
      final totalSales = reportData['totalSales'] as double;
      final type = (reportData['type'] ?? 'Both') as String;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
          build: (context) {
            return [
              pw.Center(
                child: pw.Text(
                  'Transaction Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Report Details',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Date Range: ${DateFormat('dd/MM/yyyy').format(fromDate)} - ${DateFormat('dd/MM/yyyy').format(toDate)}'),
                    pw.Text('Product: $product'),
                    pw.Text('Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Transactions Table
              if (transactions.isNotEmpty) ...[
                pw.Text(
                  'Transactions',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColors.indigo,
                  ),
                  cellStyle: pw.TextStyle(fontSize: 10),
                  headers: [
                    "Date",
                    "Product",
                    "Quantity",
                    "Unit Price",
                    "Type",
                    "Amount"
                  ],
                  data: transactions.map((tx) {
                    try {
                      final timestamp = tx['timestamp']; // Use timestamp for date
                      DateTime dt;
                      if (timestamp is DateTime) {
                        dt = timestamp;
                      } else if (timestamp != null && timestamp.runtimeType.toString().contains('Timestamp')) {
                        dt = timestamp.toDate();
                      } else {
                        dt = DateTime.now();
                      }

                      final qty = (tx['quantity'] as int? ?? 0);
                      final unitPrice = (tx['unitPrice'] as num?)?.toDouble() ?? 0.0;
                      final amount = qty * unitPrice;

                      return [
                        DateFormat('dd-MM-yyyy').format(dt),
                        (tx['product'] ?? '').toString(),
                        qty.toString(),
                        'Rs.${unitPrice.toStringAsFixed(2)}',
                        (tx['type'] ?? '').toString(),
                        'Rs.${amount.toStringAsFixed(2)}',
                      ];
                    } catch (e) {
                      return [
                        'Error', 'Error', '0', 'Rs.0.00', 'Error', 'Rs.0.00',
                      ];
                    }
                  }).toList(),
                ),
              ] else ...[
                pw.Center(
                  child: pw.Text(
                    'No transactions found for the selected criteria.',
                    style: pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic),
                  ),
                ),
              ],

              pw.SizedBox(height: 30),

              // --- Adaptive Summary Section! ---
              pw.Container(
                padding: pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: () {
                  List<pw.Widget> summaryWidgets = [
                    pw.Text(
                      'Summary',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                  ];
                  if (type == 'Purchase') {
                    summaryWidgets.add(
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total Purchase:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text('Rs.${totalPurchase.toStringAsFixed(2)}', style: pw.TextStyle(color: PdfColors.red)),
                        ],
                      ),
                    );
                  } else if (type == 'Sale') {  // Change from 'Sales' to 'Sale'
                    summaryWidgets.add(
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total Sales:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text('Rs.${totalSales.toStringAsFixed(2)}', style: pw.TextStyle(color: PdfColors.green)),
                        ],
                      ),
                    );
                  }
                  else {
                    summaryWidgets.addAll([
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total Purchase:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text('Rs.${totalPurchase.toStringAsFixed(2)}', style: pw.TextStyle(color: PdfColors.red)),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total Sales:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text('Rs.${totalSales.toStringAsFixed(2)}', style: pw.TextStyle(color: PdfColors.green)),
                        ],
                      ),
                      pw.Divider(thickness: 2),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Net Total:',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
                          ),
                          pw.Text(
                            'Rs.${(totalSales - totalPurchase).toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 16,
                              color: (totalSales - totalPurchase) >= 0
                                  ? PdfColors.green
                                  : PdfColors.red,
                            ),
                          ),
                        ],
                      ),
                    ]);
                  }
                  return pw.Column(children: summaryWidgets);
                }(),
              )
              // --- End Summary Section ---
            ];
          },
        ),
      );

      // Save the PDF
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${outputDir.path}/transaction_report_$timestamp.pdf');
      await file.writeAsBytes(await pdf.save());
      return file.path;
    } catch (e) {
      print("Error in PDF generation: $e");
      rethrow;
    }
  }
}
