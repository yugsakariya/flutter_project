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

  // Fetch company info from Firestore profile collection
  static Future<Map<String, dynamic>> _getCompanyInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('profile')
          .doc(user?.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'companyName': data['company'] ?? 'VINAYAK TRADERS',
          'address': data['address'] ?? 'A-151, NEW SARDAR MARKET YARD, NATIONAL\nGONDAL - 360311, Mo.: 9605310450',
          'gstin': data['gstin'] ?? '24AAFFE7098EA1ZO',
          'apmc': data['apmc'] ?? '1395',
        };
      }
    } catch (e) {
      print('Error fetching company info: $e');
    }
    return {
      'companyName': 'VINAYAK TRADERS',
      'address': 'A-151, NEW SARDAR MARKET YARD, NATIONAL\nGONDAL - 360311, Mo.: 9605310450',
      'gstin': '24AAFFE7098EA1ZO',
      'apmc': '1395',
    };
  }

  // Get actual Downloads folder path
  static Future<String?> _getDownloadsPath() async {
    if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } else {
      // For Android - try to access public Downloads folder
      try {
        // Method 1: Direct path to public Downloads
        Directory downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          return downloadsDir.path;
        }

        // Method 2: Alternative Downloads path
        downloadsDir = Directory('/storage/emulated/0/Downloads');
        if (await downloadsDir.exists()) {
          return downloadsDir.path;
        }

        // Method 3: Fallback to external storage + Downloads folder
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
    }

    // Final fallback to documents directory
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Request storage permissions for Android
  static Future<bool> _requestStoragePermission() async {
    if (Platform.isIOS) return true;

    // Check for storage permission
    var permission = Permission.storage;
    if (await permission.isGranted) {
      return true;
    }

    var status = await permission.request();
    if (status.isGranted) {
      return true;
    }

    // Try MANAGE_EXTERNAL_STORAGE for newer Android versions
    permission = Permission.manageExternalStorage;
    status = await permission.request();
    return status.isGranted;
  }

  // Main PDF generation method
  static Future<Map<String, dynamic>> generateGSTVoucher({
    required Map<String, dynamic> billData,
  }) async {
    try {
      // Request storage permission first
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        throw Exception('Storage permission denied. Please grant permission to save PDF.');
      }

      final pdf = pw.Document();
      final companyInfo = await _getCompanyInfo();

      // Build the PDF page
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
                _buildTotalsSection(billData),
                pw.SizedBox(height: 20),
                _buildFooter(companyInfo),
              ],
            );
          },
        ),
      );

      final fileName = 'GST_Voucher_${billData['billNumber'] ?? DateTime.now().millisecondsSinceEpoch}.pdf';
      final pdfBytes = await pdf.save();

      // Get Downloads folder path
      final downloadsPath = await _getDownloadsPath();
      if (downloadsPath == null) {
        throw Exception('Could not access Downloads folder');
      }

      // Save PDF to Downloads folder
      final file = File('$downloadsPath/$fileName');
      await file.writeAsBytes(pdfBytes);

      print('PDF saved to Downloads folder: ${file.path}');

      return {
        'success': true,
        'downloadStatus': 'PDF saved to Downloads folder successfully',
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

  // Build PDF header section
  static pw.Widget _buildHeader(Map<String, dynamic> companyInfo) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 1),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            color: PdfColors.grey300,
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Text(
              'GST Payment Voucher',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: [
                pw.Text(
                  companyInfo['companyName'] ?? 'VINAYAK TRADERS',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  companyInfo['address'] ?? 'Company Address',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build bill information section
  static pw.Widget _buildBillInfo(Map<String, dynamic> billData, Map<String, dynamic> companyInfo) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('APMC No.: ${companyInfo['apmc']}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('GSTIN No.: ${companyInfo['gstin']}', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Voucher No.: ${billData['billNumber'] ?? 'N/A'}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Voucher Date: ${_formatDate(billData['date'])}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Village: DHANDHUSAR', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  // Build items table
  static pw.Widget _buildItemsTable(Map<String, dynamic> billData) {
    final items = billData['items'] as List<dynamic>? ?? [];

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
        5: const pw.FlexColumnWidth(2),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell('Party Name', isHeader: true),
            _buildTableCell('Product', isHeader: true),
            _buildTableCell('HSN Code', isHeader: true),
            _buildTableCell('Qty', isHeader: true),
            _buildTableCell('Rate', isHeader: true),
            _buildTableCell('Amount', isHeader: true),
          ],
        ),
        // Data rows
        ...items.map((item) {
          final quantity = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
          final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
          final amount = quantity * price;

          return pw.TableRow(
            children: [
              _buildTableCell(billData['customerName'] ?? 'N/A'),
              _buildTableCell(item['name'] ?? 'N/A'),
              _buildTableCell('0603'), // HSN code for cumin
              _buildTableCell('${quantity.toStringAsFixed(1)}'),
              _buildTableCell('Rs.${price.toStringAsFixed(2)}'),
              _buildTableCell('Rs.${amount.toStringAsFixed(2)}'),
            ],
          );
        }).toList(),
      ],
    );
  }

  // Build table cell
  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // Build totals section
  static pw.Widget _buildTotalsSection(Map<String, dynamic> billData) {
    final subtotal = (billData['subtotal'] as num?)?.toDouble() ?? 0.0;
    final tax = (billData['tax'] as num?)?.toDouble() ?? 0.0;
    final total = (billData['total'] as num?)?.toDouble() ?? 0.0;
    final cgst = tax / 2;
    final sgst = tax / 2;

    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Tax Payable under Reverse Charge',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Text('Taxable Value', style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(width: 20),
                      pw.Text('CGST', style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(width: 40),
                      pw.Text('SGST', style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(width: 40),
                      pw.Text('Invoice Total', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 80,
                        child: pw.Text('Rs.${subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                      ),
                      pw.Container(
                        width: 60,
                        child: pw.Column(
                          children: [
                            pw.Text('Rate: 2.5%', style: const pw.TextStyle(fontSize: 8)),
                            pw.Text('Amount: Rs.${cgst.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                      ),
                      pw.Container(
                        width: 60,
                        child: pw.Column(
                          children: [
                            pw.Text('Rate: 2.5%', style: const pw.TextStyle(fontSize: 8)),
                            pw.Text('Amount: Rs.${sgst.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                      ),
                      pw.Text('Rs.${total.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          pw.Container(
            width: 1,
            height: 80,
            color: PdfColors.black,
          ),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              height: 80,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text('VINAYAK TRADERS',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 20),
                  pw.Text('(Authorised Signature)', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build footer section
  static pw.Widget _buildFooter(Map<String, dynamic> companyInfo) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Text(
        '${companyInfo['companyName']} Pvt Ltd',
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // Format date utility
  static String _formatDate(dynamic date) {
    try {
      if (date == null) return DateFormat('dd/MM/yyyy').format(DateTime.now());
      if (date is Timestamp) {
        return DateFormat('dd/MM/yyyy').format(date.toDate());
      }
      if (date is DateTime) {
        return DateFormat('dd/MM/yyyy').format(date);
      }
      return DateFormat('dd/MM/yyyy').format(DateTime.now());
    } catch (e) {
      return DateFormat('dd/MM/yyyy').format(DateTime.now());
    }
  }
}
