import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SurgicalRegistryApp());
}

class SurgicalRegistryApp extends StatelessWidget {
  const SurgicalRegistryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سجل البورد الجراحي والمرضى',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF00695C),
        scaffoldBackgroundColor: const Color(0xFFF4F7F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF004D40),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 2,
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const DashboardScreen(),
    );
  }
}

// ==========================================
// 1. نموذج بيانات المريض واللوكبوك (Patient & Logbook Model)
// ==========================================
class PatientRecord {
  final int? id;
  final String mrn;
  final String name;
  final String age;
  final String gender;
  final String phone;
  final String bloodGroup;
  final String admissionDate;

  // بيانات اللوكبوك الجراحي (Board Logbook)
  final String rotation;
  final String consultantName;
  final String surgeonRole; // P | S-TS | S-TU | A
  final String operationMagnitude; // Complex Major | Major | Intermediate | Minor

  // التاريخ المرضي والجراحي
  final String chronicDiseases;
  final String allergies;
  final String currentMedications;
  final String smokingStatus;
  final String pastSurgeries;
  final String pastComplications;

  // الشكوى الحالية والتشخيص
  final String chiefComplaint;
  final String clinicalExam;
  final String labRadiologyNotes;
  final String diagnosis;

  // العملية المقررة
  final String plannedOperation;
  final String operationUrgency;
  final String asaScore;
  final String anesthesiaType;
  final String operationDate;
  final String operationStatus;
  final String operativeNotes;

  // متابعة الردهة والوقاية (Ward Round & Prophylaxis)
  final String drainsInfo;
  final String dvtProphylaxis;
  final String antibioticProphylaxis;

  // الزرع النسيجي والأورام (Histopathology & TNM)
  final String biopsyStatus; // لا يحتاج زرع | بانتظار الزرع (Pending) | ظهرت النتيجة
  final String histopathologyResult;
  final String tnmStaging;

  // بنك الامتحان والملاحظات التشريحية (Viva & Surgical Pearls)
  final bool isStarred;
  final String surgicalPearls;

  // النتيجة النهائية والمتابعة
  final String finalOutcome;
  final String clavienDindoGrade;
  final String dischargeTreatment;
  final String followUpDate;

  // مسارات الصور الطبية (4 أقسام)
  final List<String> radiologyImages;
  final List<String> labImages;
  final List<String> woundImages;
  final List<String> biopsyImages;

  PatientRecord({
    this.id,
    required this.mrn,
    required this.name,
    required this.age,
    required this.gender,
    required this.phone,
    required this.bloodGroup,
    required this.admissionDate,
    required this.rotation,
    required this.consultantName,
    required this.surgeonRole,
    required this.operationMagnitude,
    required this.chronicDiseases,
    required this.allergies,
    required this.currentMedications,
    required this.smokingStatus,
    required this.pastSurgeries,
    required this.pastComplications,
    required this.chiefComplaint,
    required this.clinicalExam,
    required this.labRadiologyNotes,
    required this.diagnosis,
    required this.plannedOperation,
    required this.operationUrgency,
    required this.asaScore,
    required this.anesthesiaType,
    required this.operationDate,
    required this.operationStatus,
    required this.operativeNotes,
    required this.drainsInfo,
    required this.dvtProphylaxis,
    required this.antibioticProphylaxis,
    required this.biopsyStatus,
    required this.histopathologyResult,
    required this.tnmStaging,
    required this.isStarred,
    required this.surgicalPearls,
    required this.finalOutcome,
    required this.clavienDindoGrade,
    required this.dischargeTreatment,
    required this.followUpDate,
    required this.radiologyImages,
    required this.labImages,
    required this.woundImages,
    required this.biopsyImages,
  });

  String displayName(bool anonymized) {
    if (!anonymized) return name;
    final code = mrn.isNotEmpty ? mrn : (id?.toString() ?? 'X');
    return 'مريض #$code ($gender، $age سنة)';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mrn': mrn,
      'name': name,
      'age': age,
      'gender': gender,
      'phone': phone,
      'bloodGroup': bloodGroup,
      'admissionDate': admissionDate,
      'rotation': rotation,
      'consultantName': consultantName,
      'surgeonRole': surgeonRole,
      'operationMagnitude': operationMagnitude,
      'chronicDiseases': chronicDiseases,
      'allergies': allergies,
      'currentMedications': currentMedications,
      'smokingStatus': smokingStatus,
      'pastSurgeries': pastSurgeries,
      'pastComplications': pastComplications,
      'chiefComplaint': chiefComplaint,
      'clinicalExam': clinicalExam,
      'labRadiologyNotes': labRadiologyNotes,
      'diagnosis': diagnosis,
      'plannedOperation': plannedOperation,
      'operationUrgency': operationUrgency,
      'asaScore': asaScore,
      'anesthesiaType': anesthesiaType,
      'operationDate': operationDate,
      'operationStatus': operationStatus,
      'operativeNotes': operativeNotes,
      'drainsInfo': drainsInfo,
      'dvtProphylaxis': dvtProphylaxis,
      'antibioticProphylaxis': antibioticProphylaxis,
      'biopsyStatus': biopsyStatus,
      'histopathologyResult': histopathologyResult,
      'tnmStaging': tnmStaging,
      'isStarred': isStarred ? 1 : 0,
      'surgicalPearls': surgicalPearls,
      'finalOutcome': finalOutcome,
      'clavienDindoGrade': clavienDindoGrade,
      'dischargeTreatment': dischargeTreatment,
      'followUpDate': followUpDate,
      'radiologyImages': jsonEncode(radiologyImages),
      'labImages': jsonEncode(labImages),
      'woundImages': jsonEncode(woundImages),
      'biopsyImages': jsonEncode(biopsyImages),
    };
  }

  factory PatientRecord.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic val) {
      if (val == null || val.toString().isEmpty) return [];
      try {
        return List<String>.from(jsonDecode(val.toString()));
      } catch (_) {
        return [];
      }
    }

    return PatientRecord(
      id: map['id'] as int?,
      mrn: map['mrn'] ?? '',
      name: map['name'] ?? '',
      age: map['age'] ?? '',
      gender: map['gender'] ?? 'ذكر',
      phone: map['phone'] ?? '',
      bloodGroup: map['bloodGroup'] ?? 'O+',
      admissionDate: map['admissionDate'] ?? '',
      rotation: map['rotation'] ?? 'الجراحة العامة',
      consultantName: map['consultantName'] ?? '',
      surgeonRole: map['surgeonRole'] ?? 'P - جراح رئيسي (Performed)',
      operationMagnitude: map['operationMagnitude'] ?? 'Major - كبرى',
      chronicDiseases: map['chronicDiseases'] ?? '',
      allergies: map['allergies'] ?? '',
      currentMedications: map['currentMedications'] ?? '',
      smokingStatus: map['smokingStatus'] ?? 'غير مدخن',
      pastSurgeries: map['pastSurgeries'] ?? '',
      pastComplications: map['pastComplications'] ?? '',
      chiefComplaint: map['chiefComplaint'] ?? '',
      clinicalExam: map['clinicalExam'] ?? '',
      labRadiologyNotes: map['labRadiologyNotes'] ?? '',
      diagnosis: map['diagnosis'] ?? '',
      plannedOperation: map['plannedOperation'] ?? '',
      operationUrgency: map['operationUrgency'] ?? 'مجدولة (باردة)',
      asaScore: map['asaScore'] ?? 'ASA I',
      anesthesiaType: map['anesthesiaType'] ?? 'تخدير عام (GA)',
      operationDate: map['operationDate'] ?? '',
      operationStatus: map['operationStatus'] ?? 'مقررة',
      operativeNotes: map['operativeNotes'] ?? '',
      drainsInfo: map['drainsInfo'] ?? '',
      dvtProphylaxis: map['dvtProphylaxis'] ?? 'غير محدد',
      antibioticProphylaxis: map['antibioticProphylaxis'] ?? '',
      biopsyStatus: map['biopsyStatus'] ?? 'لا يحتاج زرع',
      histopathologyResult: map['histopathologyResult'] ?? '',
      tnmStaging: map['tnmStaging'] ?? '',
      isStarred: (map['isStarred'] == 1 || map['isStarred'] == true),
      surgicalPearls: map['surgicalPearls'] ?? '',
      finalOutcome: map['finalOutcome'] ?? 'قيد المتابعة',
      clavienDindoGrade: map['clavienDindoGrade'] ?? 'لا يوجد (None)',
      dischargeTreatment: map['dischargeTreatment'] ?? '',
      followUpDate: map['followUpDate'] ?? '',
      radiologyImages: parseList(map['radiologyImages']),
      labImages: parseList(map['labImages']),
      woundImages: parseList(map['woundImages']),
      biopsyImages: parseList(map['biopsyImages']),
    );
  }
}

// ==========================================
// 2. إدارة قاعدة البيانات المحلية (SQLite Helper)
// ==========================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('surgical_board_logbook_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE patients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mrn TEXT,
        name TEXT NOT NULL,
        age TEXT,
        gender TEXT,
        phone TEXT,
        bloodGroup TEXT,
        admissionDate TEXT,
        rotation TEXT,
        consultantName TEXT,
        surgeonRole TEXT,
        operationMagnitude TEXT,
        chronicDiseases TEXT,
        allergies TEXT,
        currentMedications TEXT,
        smokingStatus TEXT,
        pastSurgeries TEXT,
        pastComplications TEXT,
        chiefComplaint TEXT,
        clinicalExam TEXT,
        labRadiologyNotes TEXT,
        diagnosis TEXT,
        plannedOperation TEXT,
        operationUrgency TEXT,
        asaScore TEXT,
        anesthesiaType TEXT,
        operationDate TEXT,
        operationStatus TEXT,
        operativeNotes TEXT,
        drainsInfo TEXT,
        dvtProphylaxis TEXT,
        antibioticProphylaxis TEXT,
        biopsyStatus TEXT,
        histopathologyResult TEXT,
        tnmStaging TEXT,
        isStarred INTEGER DEFAULT 0,
        surgicalPearls TEXT,
        finalOutcome TEXT,
        clavienDindoGrade TEXT,
        dischargeTreatment TEXT,
        followUpDate TEXT,
        radiologyImages TEXT,
        labImages TEXT,
        woundImages TEXT,
        biopsyImages TEXT
      )
    ''');
  }

  Future<int> insertPatient(PatientRecord patient) async {
    final db = await instance.database;
    return await db.insert('patients', patient.toMap());
  }

  Future<List<PatientRecord>> getAllPatients() async {
    final db = await instance.database;
    final result = await db.query('patients', orderBy: 'id DESC');
    return result.map((json) => PatientRecord.fromMap(json)).toList();
  }

  Future<int> updatePatient(PatientRecord patient) async {
    final db = await instance.database;
    return await db.update(
      'patients',
      patient.toMap(),
      where: 'id = ?',
      whereArgs: [patient.id],
    );
  }

  Future<int> deletePatient(int id) async {
    final db = await instance.database;
    return await db.delete('patients', where: 'id = ?', whereArgs: [id]);
  }

  static Future<String?> pickAndSaveMedicalImage(ImageSource source, String categoryPrefix) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source, imageQuality: 85);
    if (pickedFile == null) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(appDir.path, 'medical_images'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    final fileName = '${categoryPrefix}_${DateTime.now().millisecondsSinceEpoch}${p.extension(pickedFile.path)}';
    final savedImage = await File(pickedFile.path).copy(p.join(mediaDir.path, fileName));
    return savedImage.path;
  }
}

// ==========================================
// 3. الشاشة الرئيسية ولوحة التحكم (Dashboard & Logbook)
// ==========================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<PatientRecord> _allPatients = [];
  List<PatientRecord> _filteredPatients = [];
  String _searchQuery = '';
  String _selectedFilter = 'الكل';
  bool _isLoading = true;
  bool _isAnonymized = false; // وضع السيمينار وإخفاء الهوية

  @override
  void initState() {
    super.initState();
    _refreshPatients();
  }

  Future<void> _refreshPatients() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllPatients();
    setState(() {
      _allPatients = data;
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    _filteredPatients = _allPatients.where((p) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = p.name.toLowerCase().contains(q) ||
          p.mrn.toLowerCase().contains(q) ||
          p.diagnosis.toLowerCase().contains(q) ||
          p.plannedOperation.toLowerCase().contains(q) ||
          p.consultantName.toLowerCase().contains(q) ||
          p.rotation.toLowerCase().contains(q);

      if (!matchesSearch) return false;
      if (_selectedFilter == 'الكل') return true;
      if (_selectedFilter == 'مقررة') return p.operationStatus == 'مقررة';
      if (_selectedFilter == 'تمت العملية') return p.operationStatus == 'تمت العملية';
      if (_selectedFilter == 'طارئة') return p.operationUrgency.contains('طارئة');
      if (_selectedFilter == 'بانتظار الزرع 🔬') return p.biopsyStatus.contains('بانتظار');
      if (_selectedFilter == 'حالات للامتحان ⭐') return p.isStarred;
      if (_selectedFilter == 'جراح رئيسي (P)') return p.surgeonRole.startsWith('P');
      return true;
    }).toList();
  }

  Future<void> _exportBackupJson() async {
    final list = _allPatients.map((e) => e.toMap()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(list);
    await Clipboard.setData(ClipboardData(text: jsonString));
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    await Printing.sharePdf(bytes: bytes, filename: 'surgical_board_backup.json');
  }

  void _showImportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة نسخة احتياطية (JSON)'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'الصق محتوى ملف الـ JSON الاحتياطي هنا...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              try {
                final List<dynamic> decoded = jsonDecode(controller.text);
                for (var item in decoded) {
                  final map = Map<String, dynamic>.from(item);
                  map.remove('id');
                  await DatabaseHelper.instance.insertPatient(PatientRecord.fromMap(map));
                }
                if (mounted) {
                  Navigator.pop(ctx);
                  _refreshPatients();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم استيراد بيانات اللوكبوك والمرضى بنجاح')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('خطأ في صيغة الكود المنسوخ')),
                );
              }
            },
            child: const Text('استعادة الآن'),
          ),
        ],
      ),
    );
  }

  // توليد تقرير اللوكبوك الإحصائي المجمع للبورد (Consolidation Sheet PDF)
  Future<void> _generateLogbookConsolidationPdf() async {
    if (_filteredPatients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد حالات حالياً لتصدير سجل اللوكبوك')),
      );
      return;
    }

    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    final list = _filteredPatients;
    final total = list.length;
    final roleP = list.where((p) => p.surgeonRole.startsWith('P')).length;
    final roleSTS = list.where((p) => p.surgeonRole.startsWith('S-TS')).length;
    final roleSTU = list.where((p) => p.surgeonRole.startsWith('S-TU')).length;
    final roleA = list.where((p) => p.surgeonRole.startsWith('A')).length;
    final emergencyCount = list.where((p) => p.operationUrgency.contains('طارئة')).length;
    final electiveCount = total - emergencyCount;

    // تجميع العمليات حسب الاسم لحساب أعداد كل عملية
    final Map<String, Map<String, int>> opSummary = {};
    for (var p in list) {
      final opName = p.plannedOperation.trim().isEmpty ? 'غير محدد' : p.plannedOperation.trim();
      opSummary.putIfAbsent(opName, () => {'total': 0, 'P': 0, 'S': 0, 'A': 0});
      opSummary[opName]!['total'] = opSummary[opName]!['total']! + 1;
      if (p.surgeonRole.startsWith('P')) {
        opSummary[opName]!['P'] = opSummary[opName]!['P']! + 1;
      } else if (p.surgeonRole.startsWith('S')) {
        opSummary[opName]!['S'] = opSummary[opName]!['S']! + 1;
      } else {
        opSummary[opName]!['A'] = opSummary[opName]!['A']! + 1;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColors.teal900, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('السجل الجراحي الرسمي والتقرير الإحصائي (Surgical Logbook Consolidation)',
                    style: pw.TextStyle(font: arabicBold, color: PdfColors.white, fontSize: 14)),
                pw.SizedBox(height: 4),
                pw.Text('تاريخ التقرير: ${DateTime.now().toString().split(' ').first} | الفلتر الحالي: $_selectedFilter | إجمالي الحالات: $total',
                    style: pw.TextStyle(font: arabicFont, color: PdfColors.white, fontSize: 10)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // ملخص الأدوار الجراحية
          pw.Text('أولاً: خلاصة الأدوار الجراحية والتصنيف (Summary by Role & Urgency)',
              style: pw.TextStyle(font: arabicBold, fontSize: 12, color: PdfColors.teal900)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                children: [
                  _pdfCell('طارئة (Emergency)', arabicBold),
                  _pdfCell('باردة (Elective)', arabicBold),
                  _pdfCell('مساعد (A)', arabicBold),
                  _pdfCell('إشراف غير مباشر (S-TU)', arabicBold),
                  _pdfCell('إشراف مباشر (S-TS)', arabicBold),
                  _pdfCell('جراح رئيسي (P)', arabicBold),
                  _pdfCell('المجموع الكلي', arabicBold),
                ],
              ),
              pw.TableRow(
                children: [
                  _pdfCell('$emergencyCount', arabicFont),
                  _pdfCell('$electiveCount', arabicFont),
                  _pdfCell('$roleA', arabicFont),
                  _pdfCell('$roleSTU', arabicFont),
                  _pdfCell('$roleSTS', arabicFont),
                  _pdfCell('$roleP', arabicBold),
                  _pdfCell('$total', arabicBold),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),

          // جدول التجميع حسب نوع العملية
          pw.Text('ثانياً: التجميع الإحصائي حسب نوع العملية (Consolidation by Procedure)',
              style: pw.TextStyle(font: arabicBold, fontSize: 12, color: PdfColors.teal900)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                children: [
                  _pdfCell('مساعد (A)', arabicBold),
                  _pdfCell('بإشراف (S-TS/TU)', arabicBold),
                  _pdfCell('جراح رئيسي (P)', arabicBold),
                  _pdfCell('العدد الكلي', arabicBold),
                  _pdfCell('اسم العملية الجراحية (Procedure)', arabicBold),
                ],
              ),
              ...opSummary.entries.map((entry) {
                return pw.TableRow(
                  children: [
                    _pdfCell('${entry.value['A']}', arabicFont),
                    _pdfCell('${entry.value['S']}', arabicFont),
                    _pdfCell('${entry.value['P']}', arabicFont),
                    _pdfCell('${entry.value['total']}', arabicBold),
                    _pdfCell(entry.key, arabicFont),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 14),

          // سجل الحالات التفصيلي
          pw.Text('ثالثاً: السجل التفصيلي للحالات (Detailed Case Log)',
              style: pw.TextStyle(font: arabicBold, fontSize: 12, color: PdfColors.teal900)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                children: [
                  _pdfCell('النتيجة / المضاعفات', arabicBold),
                  _pdfCell('المشرف', arabicBold),
                  _pdfCell('الدور / الحجم', arabicBold),
                  _pdfCell('العملية والتشخيص', arabicBold),
                  _pdfCell('المريض / الملف', arabicBold),
                  _pdfCell('التاريخ', arabicBold),
                ],
              ),
              ...list.map((p) {
                final shortRole = p.surgeonRole.split(' ').first;
                final shortMag = p.operationMagnitude.split(' ').first;
                return pw.TableRow(
                  children: [
                    _pdfCell('${p.finalOutcome} (${p.clavienDindoGrade})', arabicFont),
                    _pdfCell(p.consultantName.isEmpty ? '-' : p.consultantName, arabicFont),
                    _pdfCell('$shortRole / $shortMag', arabicFont),
                    _pdfCell('${p.plannedOperation}\n(${p.diagnosis})', arabicFont),
                    _pdfCell('${p.displayName(_isAnonymized)}\nMRN: ${p.mrn}', arabicFont),
                    _pdfCell(p.operationDate, arabicFont),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('توقيع الاستشاري المشرف (Consultant Signature): ___________________',
                  style: pw.TextStyle(font: arabicBold, fontSize: 11)),
              pw.Text('توقيع طالب البورد (Resident Signature): ___________________',
                  style: pw.TextStyle(font: arabicBold, fontSize: 11)),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Surgical_Board_Logbook.pdf');
  }

  pw.Widget _pdfCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: 9),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _allPatients.length;
    final primarySurgeonCount = _allPatients
        .where((p) => p.surgeonRole.startsWith('P') || p.surgeonRole.startsWith('S'))
        .length;
    final pendingBiopsyCount = _allPatients.where((p) => p.biopsyStatus.contains('بانتظار')).length;
    final starredCount = _allPatients.where((p) => p.isStarred).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل البورد الجراحي والمرضى', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(_isAnonymized ? Icons.visibility_off : Icons.visibility),
            tooltip: 'وضع السيمينار (إخفاء/إظهار هوية المرضى)',
            onPressed: () {
              setState(() => _isAnonymized = !_isAnonymized);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isAnonymized
                      ? 'تم تفعيل وضع السيمينار (إخفاء أسماء وأرقام المرضى)'
                      : 'تم إيقاف وضع السيمينار (إظهار الأسماء الحقيقية)'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'طباعة تقرير اللوكبوك الإحصائي (Logbook PDF)',
            onPressed: _generateLogbookConsolidationPdf,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.import_export),
            onSelected: (val) {
              if (val == 'export') _exportBackupJson();
              if (val == 'import') _showImportDialog();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'export', child: Text('نسخ ومشاركة قاعدة البيانات (JSON)')),
              const PopupMenuItem(value: 'import', child: Text('استعادة نسخة احتياطية')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط الإحصائيات السريعة لطالب البورد
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                _buildStatCard('إجمالي الحالات', totalCount.toString(), Colors.teal.shade700, Icons.people),
                const SizedBox(width: 8),
                _buildStatCard('جراح رئيسي (P/S)', primarySurgeonCount.toString(), Colors.blue.shade800, Icons.medical_services),
                const SizedBox(width: 8),
                _buildStatCard('بانتظار الزرع', pendingBiopsyCount.toString(), Colors.purple.shade700, Icons.biotech),
                const SizedBox(width: 8),
                _buildStatCard('حالات للامتحان', starredCount.toString(), Colors.amber.shade800, Icons.star),
              ],
            ),
          ),

          // شريط البحث
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم، العملية، التشخيص، المشرف، أو الروتيشن...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _applyFilters();
                });
              },
            ),
          ),

          // فلاتر البورد السريعة
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                'الكل',
                'مقررة',
                'تمت العملية',
                'طارئة',
                'بانتظار الزرع 🔬',
                'حالات للامتحان ⭐',
                'جراح رئيسي (P)',
              ].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(filter, style: const TextStyle(fontSize: 12.5)),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedFilter = filter;
                        _applyFilters();
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // قائمة المرضى
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPatients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.medical_information_outlined, size: 72, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'لا توجد حالات مطابقة للبحث أو الفلتر\nاضغط على زر (+) لإضافة حالة جديدة',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredPatients.length,
                        itemBuilder: (ctx, index) {
                          final patient = _filteredPatients[index];
                          final totalPhotos = patient.radiologyImages.length +
                              patient.labImages.length +
                              patient.woundImages.length +
                              patient.biopsyImages.length;
                          final shortRole = patient.surgeonRole.split(' ').first;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PatientDetailsScreen(
                                      patientId: patient.id!,
                                      isAnonymized: _isAnonymized,
                                    ),
                                  ),
                                );
                                _refreshPatients();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: const Color(0xFF004D40),
                                          foregroundColor: Colors.white,
                                          child: Text(shortRole, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  if (patient.isStarred)
                                                    const Padding(
                                                      padding: EdgeInsets.only(left: 4),
                                                      child: Icon(Icons.star, color: Colors.amber, size: 18),
                                                    ),
                                                  Expanded(
                                                    child: Text(
                                                      patient.displayName(_isAnonymized),
                                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                '${patient.rotation} | د. ${patient.consultantName.isEmpty ? "غير محدد" : patient.consultantName} | دم: ${patient.bloodGroup}',
                                                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _buildStatusBadge(patient.operationStatus),
                                      ],
                                    ),
                                    const Divider(height: 16),
                                    _buildInfoLine(Icons.sick_outlined, 'التشخيص:', '${patient.diagnosis} (${patient.chiefComplaint})'),
                                    const SizedBox(height: 4),
                                    _buildInfoLine(
                                      Icons.medical_services_outlined,
                                      'العملية:',
                                      '${patient.plannedOperation} [${patient.operationMagnitude.split(' ').first}]',
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        _buildMiniChip(patient.finalOutcome, Colors.blueGrey.shade50, Colors.blueGrey.shade800),
                                        if (patient.biopsyStatus.contains('بانتظار'))
                                          _buildMiniChip('🔬 بانتظار الزرع النسيجي', Colors.purple.shade50, Colors.purple.shade800),
                                        if (patient.biopsyStatus.contains('ظهرت'))
                                          _buildMiniChip('🔬 الزرع: ${patient.histopathologyResult}', Colors.green.shade50, Colors.green.shade800),
                                        if (totalPhotos > 0)
                                          _buildMiniChip('📷 $totalPhotos صور', Colors.teal.shade50, Colors.teal.shade800),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PatientFormScreen()),
          );
          _refreshPatients();
        },
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('إضافة حالة جديدة'),
      ),
    );
  }

  Widget _buildMiniChip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, color: fg, fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(right: BorderSide(color: color, width: 4)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.orange.shade100;
    Color fg = Colors.orange.shade900;
    if (status == 'تمت العملية') {
      bg = Colors.green.shade100;
      fg = Colors.green.shade900;
    } else if (status == 'مؤجلة') {
      bg = Colors.red.shade100;
      fg = Colors.red.shade900;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInfoLine(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.teal.shade700),
        const SizedBox(width: 6),
        Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Expanded(
          child: Text(
            value.isEmpty ? 'غير مسجل' : value,
            style: const TextStyle(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 4. شاشة إضافة وتعديل ملف المريض واللوكبوك الشامل
// ==========================================
class PatientFormScreen extends StatefulWidget {
  final PatientRecord? existingPatient;
  const PatientFormScreen({super.key, this.existingPatient});

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _mrnCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _admissionDateCtrl;
  late TextEditingController _rotationCtrl;
  late TextEditingController _consultantCtrl;
  late TextEditingController _chronicCtrl;
  late TextEditingController _allergiesCtrl;
  late TextEditingController _medsCtrl;
  late TextEditingController _pastSurgeriesCtrl;
  late TextEditingController _pastCompCtrl;
  late TextEditingController _complaintCtrl;
  late TextEditingController _examCtrl;
  late TextEditingController _labNotesCtrl;
  late TextEditingController _diagnosisCtrl;
  late TextEditingController _operationCtrl;
  late TextEditingController _opDateCtrl;
  late TextEditingController _opNotesCtrl;
  late TextEditingController _drainsCtrl;
  late TextEditingController _antibioticCtrl;
  late TextEditingController _histoResultCtrl;
  late TextEditingController _tnmCtrl;
  late TextEditingController _pearlsCtrl;
  late TextEditingController _dischargeCtrl;
  late TextEditingController _followUpCtrl;

  String _gender = 'ذكر';
  String _bloodGroup = 'O+';
  String _surgeonRole = 'P - جراح رئيسي (Performed)';
  String _opMagnitude = 'Major - كبرى';
  String _smokingStatus = 'غير مدخن';
  String _urgency = 'مجدولة (باردة)';
  String _asaScore = 'ASA I';
  String _anesthesia = 'تخدير عام (GA)';
  String _opStatus = 'مقررة';
  String _dvtProphylaxis = 'ميكانيكي + دوائي (LMWH/Heparin)';
  String _biopsyStatus = 'لا يحتاج زرع';
  bool _isStarred = false;
  String _finalOutcome = 'قيد المتابعة';
  String _clavienGrade = 'لا يوجد (None)';

  List<String> _radiologyImages = [];
  List<String> _labImages = [];
  List<String> _woundImages = [];
  List<String> _biopsyImages = [];

  @override
  void initState() {
    super.initState();
    final p = widget.existingPatient;
    final today = DateTime.now().toString().split(' ').first;

    _mrnCtrl = TextEditingController(text: p?.mrn ?? '');
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _ageCtrl = TextEditingController(text: p?.age ?? '');
    _phoneCtrl = TextEditingController(text: p?.phone ?? '');
    _admissionDateCtrl = TextEditingController(text: p?.admissionDate ?? today);
    _rotationCtrl = TextEditingController(text: p?.rotation ?? 'الجراحة العامة');
    _consultantCtrl = TextEditingController(text: p?.consultantName ?? '');
    _chronicCtrl = TextEditingController(text: p?.chronicDiseases ?? '');
    _allergiesCtrl = TextEditingController(text: p?.allergies ?? '');
    _medsCtrl = TextEditingController(text: p?.currentMedications ?? '');
    _pastSurgeriesCtrl = TextEditingController(text: p?.pastSurgeries ?? '');
    _pastCompCtrl = TextEditingController(text: p?.pastComplications ?? '');
    _complaintCtrl = TextEditingController(text: p?.chiefComplaint ?? '');
    _examCtrl = TextEditingController(text: p?.clinicalExam ?? '');
    _labNotesCtrl = TextEditingController(text: p?.labRadiologyNotes ?? '');
    _diagnosisCtrl = TextEditingController(text: p?.diagnosis ?? '');
    _operationCtrl = TextEditingController(text: p?.plannedOperation ?? '');
    _opDateCtrl = TextEditingController(text: p?.operationDate ?? today);
    _opNotesCtrl = TextEditingController(text: p?.operativeNotes ?? '');
    _drainsCtrl = TextEditingController(text: p?.drainsInfo ?? '');
    _antibioticCtrl = TextEditingController(text: p?.antibioticProphylaxis ?? '');
    _histoResultCtrl = TextEditingController(text: p?.histopathologyResult ?? '');
    _tnmCtrl = TextEditingController(text: p?.tnmStaging ?? '');
    _pearlsCtrl = TextEditingController(text: p?.surgicalPearls ?? '');
    _dischargeCtrl = TextEditingController(text: p?.dischargeTreatment ?? '');
    _followUpCtrl = TextEditingController(text: p?.followUpDate ?? '');

    if (p != null) {
      _gender = p.gender;
      _bloodGroup = p.bloodGroup;
      _surgeonRole = p.surgeonRole;
      _opMagnitude = p.operationMagnitude;
      _smokingStatus = p.smokingStatus;
      _urgency = p.operationUrgency;
      _asaScore = p.asaScore;
      _anesthesia = p.anesthesiaType;
      _opStatus = p.operationStatus;
      _dvtProphylaxis = p.dvtProphylaxis;
      _biopsyStatus = p.biopsyStatus;
      _isStarred = p.isStarred;
      _finalOutcome = p.finalOutcome;
      _clavienGrade = p.clavienDindoGrade;
      _radiologyImages = List<String>.from(p.radiologyImages);
      _labImages = List<String>.from(p.labImages);
      _woundImages = List<String>.from(p.woundImages);
      _biopsyImages = List<String>.from(p.biopsyImages);
    }
  }

  Future<void> _addPhoto(List<String> targetList, String prefix) async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.teal),
              title: const Text('التقاط صورة مباشرة بالكاميرا'),
              onTap: () async {
                Navigator.pop(ctx);
                final path = await DatabaseHelper.pickAndSaveMedicalImage(ImageSource.camera, prefix);
                if (path != null) setState(() => targetList.add(path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('اختيار صورة من استوديو الهاتف'),
              onTap: () async {
                Navigator.pop(ctx);
                final path = await DatabaseHelper.pickAndSaveMedicalImage(ImageSource.gallery, prefix);
                if (path != null) setState(() => targetList.add(path));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;

    final record = PatientRecord(
      id: widget.existingPatient?.id,
      mrn: _mrnCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      age: _ageCtrl.text.trim(),
      gender: _gender,
      phone: _phoneCtrl.text.trim(),
      bloodGroup: _bloodGroup,
      admissionDate: _admissionDateCtrl.text.trim(),
      rotation: _rotationCtrl.text.trim(),
      consultantName: _consultantCtrl.text.trim(),
      surgeonRole: _surgeonRole,
      operationMagnitude: _opMagnitude,
      chronicDiseases: _chronicCtrl.text.trim(),
      allergies: _allergiesCtrl.text.trim(),
      currentMedications: _medsCtrl.text.trim(),
      smokingStatus: _smokingStatus,
      pastSurgeries: _pastSurgeriesCtrl.text.trim(),
      pastComplications: _pastCompCtrl.text.trim(),
      chiefComplaint: _complaintCtrl.text.trim(),
      clinicalExam: _examCtrl.text.trim(),
      labRadiologyNotes: _labNotesCtrl.text.trim(),
      diagnosis: _diagnosisCtrl.text.trim(),
      plannedOperation: _operationCtrl.text.trim(),
      operationUrgency: _urgency,
      asaScore: _asaScore,
      anesthesiaType: _anesthesia,
      operationDate: _opDateCtrl.text.trim(),
      operationStatus: _opStatus,
      operativeNotes: _opNotesCtrl.text.trim(),
      drainsInfo: _drainsCtrl.text.trim(),
      dvtProphylaxis: _dvtProphylaxis,
      antibioticProphylaxis: _antibioticCtrl.text.trim(),
      biopsyStatus: _biopsyStatus,
      histopathologyResult: _histoResultCtrl.text.trim(),
      tnmStaging: _tnmCtrl.text.trim(),
      isStarred: _isStarred,
      surgicalPearls: _pearlsCtrl.text.trim(),
      finalOutcome: _finalOutcome,
      clavienDindoGrade: _clavienGrade,
      dischargeTreatment: _dischargeCtrl.text.trim(),
      followUpDate: _followUpCtrl.text.trim(),
      radiologyImages: _radiologyImages,
      labImages: _labImages,
      woundImages: _woundImages,
      biopsyImages: _biopsyImages,
    );

    if (widget.existingPatient == null) {
      await DatabaseHelper.instance.insertPatient(record);
    } else {
      await DatabaseHelper.instance.updatePatient(record);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingPatient == null ? 'إضافة حالة جديدة للوكبوك' : 'تعديل ملف المريض'),
        actions: [
          IconButton(
            icon: Icon(_isStarred ? Icons.star : Icons.star_border, color: Colors.amber),
            tooltip: 'تمييز كحالة مهمة للامتحان',
            onPressed: () => setState(() => _isStarred = !_isStarred),
          ),
          IconButton(icon: const Icon(Icons.save), onPressed: _savePatient),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _buildSectionCard(
              title: '1. البيانات الشخصية للمريض',
              icon: Icons.person,
              children: [
                _buildTextField(_nameCtrl, 'اسم المريض الرباعي *', required: true),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_ageCtrl, 'العمر *', required: true, isNumber: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(_mrnCtrl, 'رقم الملف (MRN)')),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildDropdown('الجنس', _gender, ['ذكر', 'أنثى'], (v) => setState(() => _gender = v!))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDropdown(
                        'فصيلة الدم',
                        _bloodGroup,
                        ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'],
                        (v) => setState(() => _bloodGroup = v!),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_phoneCtrl, 'رقم الهاتف')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(_admissionDateCtrl, 'تاريخ الدخول')),
                  ],
                ),
              ],
            ),

            _buildSectionCard(
              title: '2. بيانات اللوكبوك الجراحي (Board Logbook)',
              icon: Icons.badge,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildTextField(_rotationCtrl, 'الروتيشن / الردهة (مثال: جراحة عامة، أطفال، صدر)')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(_consultantCtrl, 'اسم الاختصاصي المشرف')),
                  ],
                ),
                _buildDropdown(
                  'دورك في العملية (Surgeon Role)',
                  _surgeonRole,
                  [
                    'P - جراح رئيسي (Performed)',
                    'S-TS - بإشراف مباشر (المشرف معقم)',
                    'S-TU - بإشراف غير مباشر (المشرف بالصالة)',
                    'A - مساعد جراح (Assisted)',
                  ],
                  (v) => setState(() => _surgeonRole = v!),
                ),
                _buildDropdown(
                  'حجم وتصنيف العملية (Magnitude)',
                  _opMagnitude,
                  [
                    'Complex Major - كبرى معقدة',
                    'Major - كبرى',
                    'Intermediate - متوسطة',
                    'Minor - صغرى',
                  ],
                  (v) => setState(() => _opMagnitude = v!),
                ),
              ],
            ),

            _buildSectionCard(
              title: '3. التاريخ المرضي والجراحات السابقة',
              icon: Icons.history_edu,
              children: [
                _buildTextField(_chronicCtrl, 'الأمراض المزمنة (سكري، ضغط، قلب، ربو، كلى...)', maxLines: 2),
                _buildTextField(_allergiesCtrl, 'الحساسية الدوائية أو الغذائية'),
                _buildTextField(_medsCtrl, 'الأدوية المستمرة (خصوصاً مميعات الدم والأسبرين)', maxLines: 2),
                _buildDropdown('حالة التدخين', _smokingStatus, ['غير مدخن', 'مدخن حالي', 'مدخن سابق'], (v) => setState(() => _smokingStatus = v!)),
                _buildTextField(_pastSurgeriesCtrl, 'العمليات الجراحية السابقة وتواريخها', maxLines: 2),
                _buildTextField(_pastCompCtrl, 'مضاعفات جراحية أو تخديرية سابقة'),
              ],
            ),

            _buildSectionCard(
              title: '4. مما يعاني حالياً والتشخيص السريري',
              icon: Icons.medical_information,
              children: [
                _buildTextField(_complaintCtrl, 'الشكوى الرئيسية (مما يعاني المريض حالياً) *', required: true, maxLines: 2),
                _buildTextField(_examCtrl, 'الفحص السريري والعلامات الحيوية', maxLines: 2),
                _buildTextField(_labNotesCtrl, 'ملخص نتائج التحاليل والأشعة والسونار/المفراس', maxLines: 2),
                _buildTextField(_diagnosisCtrl, 'التشخيص الطبي النهائي (Diagnosis) *', required: true),
              ],
            ),

            _buildSectionCard(
              title: '5. تفاصيل العملية الجراحية المقررة',
              icon: Icons.local_hospital,
              children: [
                _buildTextField(_operationCtrl, 'اسم ونوع العملية المقررة *', required: true),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        'تصنيف العملية',
                        _urgency,
                        ['مجدولة (باردة)', 'طارئة (Emergency)', 'مستعجلة (Urgent)'],
                        (v) => setState(() => _urgency = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDropdown(
                        'حالة العملية',
                        _opStatus,
                        ['مقررة', 'تمت العملية', 'مؤجلة'],
                        (v) => setState(() => _opStatus = v!),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        'تصنيف ASA',
                        _asaScore,
                        ['ASA I', 'ASA II', 'ASA III', 'ASA IV', 'ASA V'],
                        (v) => setState(() => _asaScore = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDropdown(
                        'نوع التخدير',
                        _anesthesia,
                        ['تخدير عام (GA)', 'تخدير نصفي (Spinal)', 'تخدير موضعي (Local)', 'تخدير فوق الجافية'],
                        (v) => setState(() => _anesthesia = v!),
                      ),
                    ),
                  ],
                ),
                _buildTextField(_opDateCtrl, 'تاريخ إجراء العملية'),
                _buildTextField(_opNotesCtrl, 'تفاصيل وخطوات العملية (Operative Notes & Findings)', maxLines: 3),
              ],
            ),

            _buildSectionCard(
              title: '6. متابعة الردهة، الدرينات، والوقاية (Ward & Prophylaxis)',
              icon: Icons.vaccines,
              children: [
                _buildTextField(_drainsCtrl, 'الدرينات والصوندات (النوع، العدد، المخرجات اليومية، وموعد الرفع)', maxLines: 2),
                _buildDropdown(
                  'الوقاية من الخثر الوريدي (DVT Prophylaxis)',
                  _dvtProphylaxis,
                  [
                    'ميكانيكي + دوائي (LMWH/Heparin)',
                    'دوائي فقط (Clexane / Heparin)',
                    'ميكانيكي فقط (جوارب ضاغطة / حركية مبكرة)',
                    'لا يحتاج (خطورة منخفضة)',
                  ],
                  (v) => setState(() => _dvtProphylaxis = v!),
                ),
                _buildTextField(_antibioticCtrl, 'خطة الصادات الحيوية (Antibiotic Prophylaxis & Regimen)'),
              ],
            ),

            _buildSectionCard(
              title: '7. متابعة الزرع النسيجي والأورام (Histopathology & TNM)',
              icon: Icons.science,
              children: [
                _buildDropdown(
                  'حالة الزرع النسيجي (Biopsy Status)',
                  _biopsyStatus,
                  ['لا يحتاج زرع', 'بانتظار الزرع (Pending)', 'ظهرت النتيجة (Completed)'],
                  (v) => setState(() => _biopsyStatus = v!),
                ),
                _buildTextField(_histoResultCtrl, 'نتيجة الزرع النسيجي النهائية وحالة الحواف (Margins)', maxLines: 2),
                _buildTextField(_tnmCtrl, 'تصنيف الأورام (TNM Staging) وقرار الـ MDT (إن وجد)'),
              ],
            ),

            _buildSectionCard(
              title: '8. ملاحظات البورد والامتحان (Surgical Pearls & Viva)',
              icon: Icons.school,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تمييز كحالة مهمة للامتحان والمناقشة (⭐ Starred Case)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  value: _isStarred,
                  onChanged: (v) => setState(() => _isStarred = v),
                ),
                _buildTextField(
                  _pearlsCtrl,
                  'الملاحظات التشريحية والدروس الجراحية المستفادة (Anatomical Variations & Viva Notes)',
                  maxLines: 3,
                ),
              ],
            ),

            _buildSectionCard(
              title: '9. الأرشيف الصوري الطبي (4 أقسام)',
              icon: Icons.camera_enhance,
              children: [
                _buildMediaPickerSection('صور الأشعة والمفراس والرنين', _radiologyImages, 'xray'),
                const Divider(),
                _buildMediaPickerSection('صور التحاليل المختبرية والتقارير', _labImages, 'lab'),
                const Divider(),
                _buildMediaPickerSection('صور الجرح والعملية (قبل/أثناء/بعد)', _woundImages, 'wound'),
                const Divider(),
                _buildMediaPickerSection('صور تقرير الزرع النسيجي (Histopathology)', _biopsyImages, 'biopsy'),
              ],
            ),

            _buildSectionCard(
              title: '10. النتيجة النهائية وخطة الخروج',
              icon: Icons.fact_check,
              children: [
                _buildDropdown(
                  'النتيجة النهائية للمريض',
                  _finalOutcome,
                  ['قيد المتابعة', 'شفاء تام بدون مضاعفات', 'تحسن مستمر', 'حدوث مضاعفات بعد العملية', 'تحويل لمركز تخصصي', 'وفاة'],
                  (v) => setState(() => _finalOutcome = v!),
                ),
                _buildDropdown(
                  'تصنيف المضاعفات (Clavien-Dindo)',
                  _clavienGrade,
                  ['لا يوجد (None)', 'Grade I', 'Grade II', 'Grade IIIa', 'Grade IIIb', 'Grade IVa', 'Grade IVb', 'Grade V'],
                  (v) => setState(() => _clavienGrade = v!),
                ),
                _buildTextField(_dischargeCtrl, 'علاج الخروج وتوصيات العناية بالجرح', maxLines: 2),
                _buildTextField(_followUpCtrl, 'موعد المراجعة القادم ورفع الخيوط'),
              ],
            ),

            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _savePatient,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('حفظ الحالة في اللوكبوك', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPickerSection(String label, List<String> imagesList, String prefix) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5))),
            TextButton.icon(
              onPressed: () => _addPhoto(imagesList, prefix),
              icon: const Icon(Icons.add_a_photo, size: 18),
              label: const Text('إرفاق صورة'),
            ),
          ],
        ),
        if (imagesList.isEmpty)
          const Text('لا توجد صور مرفقة في هذا القسم', style: TextStyle(color: Colors.grey, fontSize: 12))
        else
          SizedBox(
            height: 95,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imagesList.length,
              itemBuilder: (ctx, i) {
                final path = imagesList[i];
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(left: 8, top: 6),
                      width: 85,
                      height: 85,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: File(path).existsSync()
                            ? Image.file(File(path), fit: BoxFit.cover)
                            : const Icon(Icons.broken_image),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => imagesList.removeAt(i)),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF004D40)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, {bool required = false, int maxLines = 1, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null : null,
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    final safeValue = items.contains(value) ? value : items.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// ==========================================
// 5. شاشة عرض ملف المريض والأرشيف الصوري والـ PDF
// ==========================================
class PatientDetailsScreen extends StatefulWidget {
  final int patientId;
  final bool isAnonymized;
  const PatientDetailsScreen({super.key, required this.patientId, this.isAnonymized = false});

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  PatientRecord? _patient;
  late bool _anonymized;

  @override
  void initState() {
    super.initState();
    _anonymized = widget.isAnonymized;
    _loadPatient();
  }

  Future<void> _loadPatient() async {
    final all = await DatabaseHelper.instance.getAllPatients();
    try {
      final found = all.firstWhere((p) => p.id == widget.patientId);
      setState(() => _patient = found);
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _toggleStar() async {
    if (_patient == null) return;
    final p = _patient!;
    final updated = PatientRecord.fromMap({
      ...p.toMap(),
      'isStarred': p.isStarred ? 0 : 1,
    });
    await DatabaseHelper.instance.updatePatient(updated);
    _loadPatient();
  }

  Future<void> _quickAddImage(String category) async {
    if (_patient == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.teal),
              title: const Text('التقاط صورة مباشرة بالكاميرا'),
              onTap: () async {
                Navigator.pop(ctx);
                final path = await DatabaseHelper.pickAndSaveMedicalImage(ImageSource.camera, category);
                if (path != null) _saveNewImagePath(category, path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('اختيار من استوديو الهاتف'),
              onTap: () async {
                Navigator.pop(ctx);
                final path = await DatabaseHelper.pickAndSaveMedicalImage(ImageSource.gallery, category);
                if (path != null) _saveNewImagePath(category, path);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNewImagePath(String category, String path) async {
    final p = _patient!;
    final rad = List<String>.from(p.radiologyImages);
    final lab = List<String>.from(p.labImages);
    final wound = List<String>.from(p.woundImages);
    final biopsy = List<String>.from(p.biopsyImages);

    if (category == 'xray') rad.add(path);
    if (category == 'lab') lab.add(path);
    if (category == 'wound') wound.add(path);
    if (category == 'biopsy') biopsy.add(path);

    final updated = PatientRecord.fromMap({
      ...p.toMap(),
      'radiologyImages': jsonEncode(rad),
      'labImages': jsonEncode(lab),
      'woundImages': jsonEncode(wound),
      'biopsyImages': jsonEncode(biopsy),
    });

    await DatabaseHelper.instance.updatePatient(updated);
    _loadPatient();
  }

  void _openFullScreenImage(String imagePath, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(title),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5.0,
              child: Image.file(File(imagePath)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generateAndSharePdf() async {
    if (_patient == null) return;
    final p = _patient!;
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    pw.Widget buildPdfRow(String label, String val) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Expanded(child: pw.Text(val.isEmpty ? '-' : val, textAlign: pw.TextAlign.right, style: pw.TextStyle(font: arabicFont, fontSize: 10.5))),
            pw.SizedBox(width: 8),
            pw.Text(label, style: pw.TextStyle(font: arabicBold, fontSize: 10.5, color: PdfColors.teal900)),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColors.teal800, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('التاريخ: ${p.admissionDate}', style: pw.TextStyle(font: arabicFont, color: PdfColors.white, fontSize: 11)),
                pw.Text('تقرير حالة سريرية وجراحية (Case Report)', style: pw.TextStyle(font: arabicBold, color: PdfColors.white, fontSize: 15)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          buildPdfRow('المريض:', '${p.displayName(_anonymized)} (${p.age} سنة - ${p.gender})'),
          buildPdfRow('رقم الملف وفصيلة الدم:', 'MRN: ${p.mrn} | فصيلة الدم: ${p.bloodGroup}'),
          buildPdfRow('الروتيشن والمشرف:', '${p.rotation} | الإشراف: د. ${p.consultantName}'),
          buildPdfRow('دور الجراح وحجم العملية:', '${p.surgeonRole} | ${p.operationMagnitude}'),
          pw.Divider(),
          buildPdfRow('الأمراض المزمنة والأدوية:', '${p.chronicDiseases} | الأدوية: ${p.currentMedications}'),
          buildPdfRow('العمليات الجراحية السابقة:', p.pastSurgeries),
          pw.Divider(),
          buildPdfRow('الشكوى الرئيسية:', p.chiefComplaint),
          buildPdfRow('الفحص السريري والتحاليل:', '${p.clinicalExam} | ${p.labRadiologyNotes}'),
          buildPdfRow('التشخيص النهائي:', p.diagnosis),
          pw.Divider(),
          buildPdfRow('العملية المجراة:', '${p.plannedOperation} (${p.operationUrgency})'),
          buildPdfRow('التخدير وتاريخ العملية:', '${p.anesthesiaType} (${p.asaScore}) - التاريخ: ${p.operationDate}'),
          buildPdfRow('ملاحظات العملية (Operative Notes):', p.operativeNotes),
          buildPdfRow('الدرينات والوقاية:', 'الدرينات: ${p.drainsInfo} | الوقاية: ${p.dvtProphylaxis}'),
          pw.Divider(),
          buildPdfRow('الزرع النسيجي و TNM:', '${p.biopsyStatus} - ${p.histopathologyResult} (${p.tnmStaging})'),
          buildPdfRow('ملاحظات البورد (Surgical Pearls):', p.surgicalPearls),
          buildPdfRow('النتيجة النهائية:', '${p.finalOutcome} (المضاعفات: ${p.clavienDindoGrade})'),
          buildPdfRow('خطة الخروج والمراجعة:', '${p.dischargeTreatment} | المراجعة: ${p.followUpDate}'),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Case_${p.mrn.isEmpty ? p.id : p.mrn}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    if (_patient == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = _patient!;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.displayName(_anonymized)),
        actions: [
          IconButton(
            icon: Icon(p.isStarred ? Icons.star : Icons.star_border, color: Colors.amber),
            tooltip: 'تمييز للامتحان',
            onPressed: _toggleStar,
          ),
          IconButton(
            icon: Icon(_anonymized ? Icons.visibility_off : Icons.visibility),
            tooltip: 'إخفاء/إظهار الاسم',
            onPressed: () => setState(() => _anonymized = !_anonymized),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير وطباعة PDF',
            onPressed: _generateAndSharePdf,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'تعديل الملف',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PatientFormScreen(existingPatient: p)),
              );
              _loadPatient();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('حذف سجل المريض'),
                  content: const Text('هل أنت متأكد من حذف هذا السجل نهائياً؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('حذف'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await DatabaseHelper.instance.deletePatient(p.id!);
                if (mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: const Color(0xFF004D40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          p.displayName(_anonymized),
                          style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Chip(
                        label: Text(p.operationStatus, style: const TextStyle(fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.amber.shade200,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'العمر: ${p.age} سنة | ${p.gender} | دم: ${p.bloodGroup} | ملف: ${p.mrn}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  if (!_anonymized)
                    Text(
                      'هاتف: ${p.phone} | تاريخ الدخول: ${p.admissionDate}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  const Divider(color: Colors.white24, height: 16),
                  Text(
                    'الروتيشن: ${p.rotation} | المشرف: د. ${p.consultantName.isEmpty ? "غير محدد" : p.consultantName}',
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'الدور: ${p.surgeonRole} | الحجم: ${p.operationMagnitude}',
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),

          // معارض الصور الأربعة
          _buildGalleryCard('صور الأشعة والمفراس والرنين (Radiology)', p.radiologyImages, 'xray', Icons.scanner),
          _buildGalleryCard('صور التحاليل المختبرية (Lab Results)', p.labImages, 'lab', Icons.biotech),
          _buildGalleryCard('صور الجرح والعملية (Wound & Intra-Op)', p.woundImages, 'wound', Icons.healing),
          _buildGalleryCard('صور تقرير الزرع النسيجي (Histopathology)', p.biopsyImages, 'biopsy', Icons.science),

          if (p.surgicalPearls.isNotEmpty || p.isStarred)
            Card(
              color: Colors.amber.shade50,
              margin: const EdgeInsets.only(top: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.school, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('ملاحظات البورد والامتحان (Surgical Pearls & Viva)',
                            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Colors.brown)),
                      ],
                    ),
                    const Divider(),
                    Text(p.surgicalPearls.isEmpty ? 'حالة مميزة للمراجعة الامتحانية' : p.surgicalPearls,
                        style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),

          _buildDetailsCard('الزرع النسيجي والأورام (Histopathology & TNM)', [
            _item('حالة الزرع النسيجي:', p.biopsyStatus),
            _item('نتيجة الزرع والحواف (Margins):', p.histopathologyResult),
            _item('تصنيف TNM وقرار اللجان:', p.tnmStaging),
          ]),

          _buildDetailsCard('الشكوى الحالية والتشخيص', [
            _item('مما يعاني حالياً (الشكوى):', p.chiefComplaint),
            _item('الفحص السريري:', p.clinicalExam),
            _item('ملاحظات التحاليل والأشعة:', p.labRadiologyNotes),
            _item('التشخيص النهائي:', p.diagnosis),
          ]),

          _buildDetailsCard('العملية الجراحية ومتابعة الردهة', [
            _item('اسم ونوع العملية:', p.plannedOperation),
            _item('التصنيف والحالة:', '${p.operationUrgency} | الحالة: ${p.operationStatus}'),
            _item('التخدير وتصنيف ASA:', '${p.anesthesiaType} (${p.asaScore})'),
            _item('تاريخ العملية:', p.operationDate),
            _item('تفاصيل العملية (Operative Notes):', p.operativeNotes),
            _item('متابعة الدرينات (Drains):', p.drainsInfo),
            _item('الوقاية الخثرية (DVT Prophylaxis):', p.dvtProphylaxis),
            _item('الصادات الحيوية (Antibiotics):', p.antibioticProphylaxis),
          ]),

          _buildDetailsCard('التاريخ المرضي والجراحي السابق', [
            _item('الأمراض المزمنة:', p.chronicDiseases),
            _item('الحساسية الدوائية:', p.allergies),
            _item('الأدوية المستمرة:', p.currentMedications),
            _item('التدخين:', p.smokingStatus),
            _item('العمليات الجراحية السابقة:', p.pastSurgeries),
            _item('مضاعفات سابقة:', p.pastComplications),
          ]),

          _buildDetailsCard('النتيجة النهائية والمتابعة', [
            _item('النتيجة النهائية:', p.finalOutcome),
            _item('تصنيف المضاعفات (Clavien-Dindo):', p.clavienDindoGrade),
            _item('علاج الخروج وتوصيات الجرح:', p.dischargeTreatment),
            _item('موعد المراجعة القادم:', p.followUpDate),
          ]),
        ],
      ),
    );
  }

  Widget _buildGalleryCard(String title, List<String> paths, String categoryKey, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(top: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(icon, color: Colors.teal.shade800, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5))),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _quickAddImage(categoryKey),
                  icon: const Icon(Icons.add_a_photo, size: 17),
                  label: const Text('إضافة صورة'),
                ),
              ],
            ),
            if (paths.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('لا توجد صور مرفقة — اضغط "إضافة صورة" للتصوير أو الاختيار من الاستوديو',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey)),
              )
            else
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: paths.length,
                  itemBuilder: (ctx, i) {
                    final imgPath = paths[i];
                    return GestureDetector(
                      onTap: () => _openFullScreenImage(imgPath, title),
                      child: Container(
                        margin: const EdgeInsets.only(left: 10, top: 6),
                        width: 105,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.teal.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: File(imgPath).existsSync()
                              ? Image.file(File(imgPath), fit: BoxFit.cover)
                              : const Icon(Icons.broken_image),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(String sectionTitle, List<Widget> items) {
    return Card(
      margin: const EdgeInsets.only(top: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sectionTitle, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
            const Divider(),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _item(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          Expanded(child: Text(val.isEmpty ? 'غير مسجل' : val, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }
}
