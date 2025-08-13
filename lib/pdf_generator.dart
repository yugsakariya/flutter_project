import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PDFGenerator {
  static final user = FirebaseAuth.instance.currentUser;

  // 1) Firestore: Fetch company profile safely
  static Future<Map<String, dynamic>> _getCompanyInfo() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('profile')
          .where('user', isEqualTo: user?.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
        return {
          'companyName': data['company'] ?? 'VINAYAK TRADERS',
          'address': data['address'] ??
              'A-151, NEW SARDAR MARKET YARD, NATIONAL\nGONDAL - 360311, Mo.: 9605310450',
          'gstin': data['gstin'] ?? '24AAFFE7098EA1ZO',
          'apmc': data['apmc'] ?? '1395',
        };
      }
    } catch (e) {
      print('Error fetching company info: $e');
    }

    // Safe defaults
    return {
      'companyName': 'VINAYAK TRADERS',
      'address':
      'A-151, NEW SARDAR MARKET YARD, NATIONAL\nGONDAL - 360311, Mo.: 9605310450',
      'gstin': '24AAFFE7098EA1ZO',
      'apmc': '1395',
    };
  }

  // 2) Storage: Get a Downloads-capable path
  static Future<String> _getDownloadsPath() async {
    if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } else {
      try {
        // Method 1
        Directory downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) return downloadsDir.path;

        // Method 2
        downloadsDir = Directory('/storage/emulated/0/Downloads');
        if (await downloadsDir.exists()) return downloadsDir.path;

        // Method 3
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final downloadsSubDir = Directory('${externalDir.path}/Downloads');
          if (!await downloadsSubDir.exists()) {
            await downloadsSubDir.create(recursive: true);
          }
          return downloadsSubDir.path;
        }
      } catch (e) {
        print('Error accessing Downloads folder: $e');
      }

      // Final fallback
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  // 3) Permissions (Android)
  static Future<bool> _requestStoragePermission() async {
    if (Platform.isIOS) return true;

    // Storage permission first
    var permission = Permission.storage;
    if (await permission.isGranted) return true;

    var status = await permission.request();
    if (status.isGranted) return true;

    // For Android 11+
    permission = Permission.manageExternalStorage;
    status = await permission.request();
    return status.isGranted;
  }

  // 4) Public method to generate the PDF
  static Future<Map<String, dynamic>> generateGSTVoucher({
    required Map<String, dynamic> billData,
  }) async {
    try {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        throw Exception(
            'Storage permission denied. Please grant permission to save PDF.');
      }

      final pdf = pw.Document();
      final companyInfo = await _getCompanyInfo();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(companyInfo),
                pw.SizedBox(height: 10),
                _buildBillInfo(billData, companyInfo),
                pw.SizedBox(height: 15),
                _buildItemsTable(billData),
                pw.SizedBox(height: 15),
                _buildTotalsSection(billData, companyInfo),
                pw.SizedBox(height: 20),
                _buildFooter(companyInfo),
              ],
            );
          },
        ),
      );

      final fileName =
          'GST_Voucher_${billData['billNumber'] ?? DateTime.now().millisecondsSinceEpoch}.pdf';
      final pdfBytes = await pdf.save();

      final downloadsPath = await _getDownloadsPath();
      if (downloadsPath.isEmpty) {
        throw Exception('Could not access Downloads folder');
      }

      final file = File('$downloadsPath/$fileName');
      await file.writeAsBytes(pdfBytes);

      print('PDF saved to: ${file.path}');
      return {
        'success': true,
        'downloadStatus': 'PDF saved successfully',
        'localPath': file.path,
        'fileName': fileName,
        'actualLocation': file.path,
      };
    } catch (e) {
      print('PDF generation error: $e');
      return {
        'success': false,
        'error': 'PDF generation failed: $e',
      };
    }
  }

  // 5) UI Blocks — refined visual design

  // Header
  static pw.Widget _buildHeader(Map companyInfo) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            color: PdfColors.grey300,
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            child: pw.Text(
              'GST Payment Voucher',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  (companyInfo['companyName'] ?? 'VINAYAK TRADERS')
                      .toString()
                      .toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  companyInfo['address'] ?? 'Company Address',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Bill Info
  static pw.Widget _buildBillInfo(
      Map<String, dynamic> billData, Map companyInfo) {
    pw.Widget labelValue(String label, String value) => pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 80,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    );

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                labelValue('APMC No.', (companyInfo['apmc'] ?? '—').toString()),
                pw.SizedBox(height: 4),
                labelValue('GSTIN', (companyInfo['gstin'] ?? '—').toString()),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                labelValue('Bill No.',
                    (billData['billNumber'] ?? 'N/A').toString()),
                pw.SizedBox(height: 4),
                labelValue('Bill Date', _formatDate(billData['date'])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Items Table
  static pw.Widget _buildItemsTable(Map<String, dynamic> billData) {
    final items = (billData['items'] as List?) ?? [];

    pw.Widget cell(String text,
        {bool isHeader = false,
          pw.Alignment align = pw.Alignment.centerLeft}) {
      return pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight:
            isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    final header = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: [
        cell('Party Name', isHeader: true),
        cell('Product', isHeader: true),
        cell('HSN', isHeader: true),
        cell('Qty', isHeader: true, align: pw.Alignment.centerRight),
        cell('Rate', isHeader: true, align: pw.Alignment.centerRight),
        cell('Amount', isHeader: true, align: pw.Alignment.centerRight),
      ],
    );

    final rows = <pw.TableRow>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i] as Map? ?? {};
      final quantity =
          double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
      final amount = quantity * price;

      rows.add(
        pw.TableRow(
          decoration:
          i.isEven ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
          children: [
            cell((billData['customerName'] ?? 'N/A').toString()),
            cell((item['name'] ?? 'N/A').toString()),
            cell('0603'),
            cell(quantity.toStringAsFixed(1),
                align: pw.Alignment.centerRight),
            cell('Rs.${price.toStringAsFixed(2)}',
                align: pw.Alignment.centerRight),
            cell('Rs.${amount.toStringAsFixed(2)}',
                align: pw.Alignment.centerRight),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.6),
        1: pw.FlexColumnWidth(2.2),
        2: pw.FlexColumnWidth(1.1),
        3: pw.FlexColumnWidth(1.1),
        4: pw.FlexColumnWidth(1.4),
        5: pw.FlexColumnWidth(1.6),
      },
      children: [header, ...rows],
    );
  }

  // Totals + Signature
  static pw.Widget _buildTotalsSection(
      Map<String, dynamic> billData, Map companyInfo) {

    final subtotal = (billData['subtotal'] as num?)?.toDouble() ?? 0.0;
    // final tax = (billData['tax'] as num?)?.toDouble() ?? 0.0; // Original tax value, if needed for other calculations

    // Calculate actual CGST and SGST at 2.5% each of taxable value
    final cgst = subtotal * 0.025; // 2.5% of taxable value
    final sgst = subtotal * 0.025; // 2.5% of taxable value
    final calculatedTax = cgst + sgst; // This is the correct total tax based on subtotal

    // Use provided total or calculate it
    final providedTotal = (billData['total'] as num?)?.toDouble();
    final total = providedTotal ?? (subtotal + calculatedTax);

    pw.Widget kv(String k, String v, {bool bold=false}) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(k, style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        )),
        pw.Text(v, style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        )),
      ],
    );

    final left = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Tax Summary (RCM)',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        kv('Taxable Value', 'Rs.${subtotal.toStringAsFixed(2)}'),
        pw.SizedBox(height: 4),
        kv('CGST (2.5%)', 'Rs.${cgst.toStringAsFixed(2)}'),
        pw.SizedBox(height: 4),
        kv('SGST (2.5%)', 'Rs.${sgst.toStringAsFixed(2)}'),
        pw.Divider(color: PdfColors.grey600, thickness: 0.6),
        kv('Invoice Total', 'Rs.${total.toStringAsFixed(2)}', bold: true),
      ],
    );

    final right = pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.SizedBox(height: 4),
        pw.Text(
          (companyInfo['companyName'] ?? 'VINAYAK TRADERS').toString(),
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 24),
        pw.Text('(Authorised Signature)',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ],
    );

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(flex: 3, child: left),
          pw.Container(width: 1, height: 90, color: PdfColors.grey600),
          pw.SizedBox(width: 10),
          pw.Expanded(flex: 2, child: right),
        ],
      ),
    );
  }


  // Footer
  static pw.Widget _buildFooter(Map companyInfo) {
    final name = (companyInfo['companyName'] ?? 'VINAYAK TRADERS').toString();
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey600, width: 0.8),
        ),
      ),
      child: pw.Text(
        name,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800),
      ),
    );
  }

  // Utils
  static String _formatDate(dynamic date) {
    try {
      if (date == null) {
        return DateFormat('dd/MM/yyyy').format(DateTime.now());
      }
      if (date is Timestamp) {
        return DateFormat('dd/MM/yyyy').format(date.toDate());
      }
      if (date is DateTime) {
        return DateFormat('dd/MM/yyyy').format(date);
      }
      return DateFormat('dd/MM/yyyy').format(DateTime.now());
    } catch (_) {
      return DateFormat('dd/MM/yyyy').format(DateTime.now());
    }
  }
}
