import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportGenerator {
  static Future<String> generateReport(Map<String, dynamic> reportData) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    // Extract data
    final from = reportData['from'] as DateTime;
    final to = reportData['to'] as DateTime;
    final transactions = reportData['transactions'] as List;
    final totalPurchase = reportData['totalPurchase'] as double;
    final totalSales = reportData['totalSales'] as double;
    final type = reportData['type'] as String;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            // Header
            _buildHeader(font, fontBold, from, to, type),
            pw.SizedBox(height: 20),

            // Summary
            _buildSummary(font, fontBold, totalPurchase, totalSales, type),
            pw.SizedBox(height: 20),

            // Transactions Table
            _buildTransactionsTable(font, fontBold, transactions),
          ];
        },
      ),
    );

    // Save PDF
    final output = await getExternalStorageDirectory();
    final file = File('${output?.path}/inventory_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    
    return file.path;
  }

  static pw.Widget _buildHeader(pw.Font font, pw.Font fontBold, DateTime from, DateTime to, String type) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Inventory Management Report',
          style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.blue900),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Period: ${DateFormat('dd/MM/yyyy').format(from)} - ${DateFormat('dd/MM/yyyy').format(to)}',
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
                pw.Text(
                  'Type: $type',
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
          ],
        ),
        pw.Divider(thickness: 2, color: PdfColors.blue900),
      ],
    );
  }

  static pw.Widget _buildSummary(pw.Font font, pw.Font fontBold, double totalPurchase, double totalSales, String type) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'Summary',
            style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.blue900),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              if (type == 'Both' || type == 'Purchase')
                _buildSummaryCard(font, fontBold, 'Total Purchase', '₹${totalPurchase.toStringAsFixed(2)}', PdfColors.green),
              if (type == 'Both' || type == 'Sale')
                _buildSummaryCard(font, fontBold, 'Total Sales', '₹${totalSales.toStringAsFixed(2)}', PdfColors.red),
              if (type == 'Both')
                _buildSummaryCard(font, fontBold, 'Net Profit', '₹${(totalSales - totalPurchase).toStringAsFixed(2)}', 
                  totalSales - totalPurchase >= 0 ? PdfColors.blue : PdfColors.red),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryCard(pw.Font font, pw.Font fontBold, String title, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(title, style: pw.TextStyle(font: font, fontSize: 12)),
        pw.SizedBox(height: 5),
        pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 14, color: color)),
      ],
    );
  }

  static pw.Widget _buildTransactionsTable(pw.Font font, pw.Font fontBold, List transactions) {
    final headers = ['Date', 'Type', 'Party', 'Products', 'Quantity', 'Amount'];
    
    List<List<String>> tableData = [];
    
    for (var transaction in transactions) {
      try {
        final type = transaction['type']?.toString() ?? 'Unknown';
        final party = transaction['party']?.toString() ?? 'Unknown';
        final products = transaction['product'] as List? ?? [];
        
        String date = 'N/A';
        if (transaction['timestamp'] != null) {
          try {
            final timestamp = transaction['timestamp'];
            if (timestamp.runtimeType.toString().contains('Timestamp')) {
              date = DateFormat('dd/MM/yyyy').format(timestamp.toDate());
            }
          } catch (e) {
            // Keep default date
          }
        }

        String productsText = '';
        int totalQuantity = 0;
        double totalAmount = 0.0;

        for (var product in products) {
          if (product != null && product is Map) {
            final productName = product['product']?.toString() ?? 'Unknown';
            final quantity = (product['quantity'] as num?)?.toInt() ?? 0;
            final unitPrice = (product['unitPrice'] as num?)?.toDouble() ?? 0.0;
            
            if (productsText.isNotEmpty) productsText += ', ';
            productsText += productName;
            totalQuantity += quantity;
            totalAmount += quantity * unitPrice;
          }
        }

        if (productsText.length > 20) {
          productsText = '${productsText.substring(0, 17)}...';
        }

        tableData.add([
          date,
          type,
          party.length > 15 ? '${party.substring(0, 12)}...' : party,
          productsText,
          '$totalQuantity kg',
          '₹${totalAmount.toStringAsFixed(2)}',
        ]);
      } catch (e) {
        // Skip this transaction if there's an error
        continue;
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Transactions Details',
          style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.blue900),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FixedColumnWidth(80),
            1: const pw.FixedColumnWidth(60),
            2: const pw.FixedColumnWidth(80),
            3: const pw.FixedColumnWidth(100),
            4: const pw.FixedColumnWidth(60),
            5: const pw.FixedColumnWidth(80),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blue50),
              children: headers.map((header) => pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  header,
                  style: pw.TextStyle(font: fontBold, fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
              )).toList(),
            ),
            // Data rows
            ...tableData.map((row) => pw.TableRow(
              children: row.map((cell) => pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  cell,
                  style: pw.TextStyle(font: font, fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              )).toList(),
            )),
          ],
        ),
        if (tableData.isEmpty)
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.all(20),
            child: pw.Text(
              'No transactions found for the selected criteria.',
              style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey600),
            ),
          ),
      ],
    );
  }
}

// Helper class for PDF fonts
class PdfGoogleFonts {
  static Future<pw.Font> nunitoRegular() async {
    return pw.Font.ttf(await rootBundle.load("assets/fonts/Nunito-Regular.ttf"));
  }

  static Future<pw.Font> nunitoBold() async {
    return pw.Font.ttf(await rootBundle.load("assets/fonts/Nunito-Bold.ttf"));
  }

  // Fallback to built-in fonts if custom fonts are not available
  static pw.Font nunitoRegularFallback() => pw.Font.helvetica();
  static pw.Font nunitoBoldFallback() => pw.Font.helveticaBold();
}

// Enhanced version with error handling
class ReportGeneratorFallback {
  static Future<String> generateReport(Map<String, dynamic> reportData) async {
    final pdf = pw.Document();

    // Use built-in fonts as fallback
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    // Extract data
    final from = reportData['from'] as DateTime;
    final to = reportData['to'] as DateTime;
    final transactions = reportData['transactions'] as List;
    final totalPurchase = reportData['totalPurchase'] as double;
    final totalSales = reportData['totalSales'] as double;
    final type = reportData['type'] as String;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            // Header
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Inventory Management Report',
                  style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.blue900),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Period: ${DateFormat('dd/MM/yyyy').format(from)} - ${DateFormat('dd/MM/yyyy').format(to)}',
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
                pw.Text(
                  'Type: $type',
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
                pw.Text(
                  'Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700),
                ),
                pw.Divider(thickness: 2, color: PdfColors.blue900),
              ],
            ),
            pw.SizedBox(height: 20),

            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Summary',
                    style: pw.TextStyle(font: fontBold, fontSize: 16),
                  ),
                  pw.SizedBox(height: 10),
                  if (type == 'Both' || type == 'Purchase')
                    pw.Text('Total Purchase: ₹${totalPurchase.toStringAsFixed(2)}'),
                  if (type == 'Both' || type == 'Sale')
                    pw.Text('Total Sales: ₹${totalSales.toStringAsFixed(2)}'),
                  if (type == 'Both')
                    pw.Text('Net: ₹${(totalSales - totalPurchase).toStringAsFixed(2)}'),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Simple transactions list
            pw.Text(
              'Transactions (${transactions.length})',
              style: pw.TextStyle(font: fontBold, fontSize: 16),
            ),
            pw.SizedBox(height: 10),
            ...transactions.take(50).map((transaction) {
              try {
                final type = transaction['type']?.toString() ?? 'Unknown';
                final party = transaction['party']?.toString() ?? 'Unknown';
                final products = transaction['product'] as List? ?? [];
                
                double totalAmount = 0.0;
                for (var product in products) {
                  if (product != null && product is Map) {
                    final quantity = (product['quantity'] as num?)?.toInt() ?? 0;
                    final unitPrice = (product['unitPrice'] as num?)?.toDouble() ?? 0.0;
                    totalAmount += quantity * unitPrice;
                  }
                }

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Text(
                    '$type - $party - ₹${totalAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(font: font, fontSize: 10),
                  ),
                );
              } catch (e) {
                return pw.Container();
              }
            }).toList(),
          ];
        },
      ),
    );

    try {
      // Try external storage first
      final output = await getExternalStorageDirectory();
      final file = File('${output?.path}/inventory_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      return file.path;
    } catch (e) {
      // Fallback to app documents directory
      final output = await getApplicationDocumentsDirectory();
      final file = File('${output.path}/inventory_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      return file.path;
    }
  }
}