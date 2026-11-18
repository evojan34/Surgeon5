import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF08203E),
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SurgicalRegistryApp());
}

// ==========================================
// كلاسات مساعدة آمنة للنسخ من متصفح الهاتف
// ==========================================
class MedicalPhotoItem {
  final String path;
  final String cat;
  MedicalPhotoItem({required this.path, required this.cat});
}

class OpCounter {
  int total = 0;
  int p = 0;
  int s = 0;
  int a = 0;
}

class BaileyChapterPreset {
  final String chapterTitleAr;
  final String chapterTitleEn;
  final String contentAr;
  final String contentEn;

  BaileyChapterPreset({
    required this.chapterTitleAr,
    required this.chapterTitleEn,
    required this.contentAr,
    required this.contentEn,
  });
}

class StudyItem {
  final int? id;
  final String itemType; // flashcard | slide | book_qa
  final String categoryAr;
  final String categoryEn;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final String status; // review | mastered

  StudyItem({
    this.id,
    required this.itemType,
    required this.categoryAr,
    required this.categoryEn,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    required this.status,
  });

  String getCategory(String lang) =>
      lang == 'en' ? (categoryEn.isNotEmpty ? categoryEn : categoryAr) : categoryAr;
  String getTitle(String lang) =>
      lang == 'en' ? (titleEn.isNotEmpty ? titleEn : titleAr) : titleAr;
  String getBody(String lang) =>
      lang == 'en' ? (bodyEn.isNotEmpty ? bodyEn : bodyAr) : bodyAr;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemType': itemType,
      'categoryAr': categoryAr,
      'categoryEn': categoryEn,
      'titleAr': titleAr,
      'titleEn': titleEn,
      'bodyAr': bodyAr,
      'bodyEn': bodyEn,
      'status': status,
    };
  }

  factory StudyItem.fromMap(Map<String, dynamic> map) {
    return StudyItem(
      id: map['id'] as int?,
      itemType: map['itemType'] ?? 'flashcard',
      categoryAr: map['categoryAr'] ?? 'الجراحة العامة',
      categoryEn: map['categoryEn'] ?? 'General Surgery',
      titleAr: map['titleAr'] ?? '',
      titleEn: map['titleEn'] ?? '',
      bodyAr: map['bodyAr'] ?? '',
      bodyEn: map['bodyEn'] ?? '',
      status: map['status'] ?? 'review',
    );
  }
}

// ==========================================
// محرك استخراج النصوص والأسئلة من ملفات PDF و TXT
// ==========================================
class PdfAndBookExtractorService {
  // فك ضغط وقراءة النصوص من داخل ملف PDF مباشرة عبر مكتبة zlib المدمجة
  static Future<String> extractTextFromPdfOrTxtFile(File file) async {
    final ext = p.extension(file.path).toLowerCase();
    if (ext == '.txt' || ext == '.md' || ext == '.json') {
      return await file.readAsString();
    }

    final bytes = await file.readAsBytes();
    final rawLatin = latin1.decode(bytes, allowInvalid: true);
    final extractedChunks = <String>[];

    // 1. البحث عن التدفقات المضغوطة FlateDecode داخل ملف الـ PDF وفك ضغطها
    final streamRegex = RegExp(r'stream[\r\n]+([\s\S]*?)[\r\n]+endstream');
    final matches = streamRegex.allMatches(rawLatin);

    for (final m in matches) {
      final streamContent = m.group(1);
      if (streamContent == null || streamContent.isEmpty) continue;
      try {
        final compressedBytes = latin1.encode(streamContent);
        final decompressed = zlib.decode(compressedBytes);
        final textStream = utf8.decode(decompressed, allowInvalid: true);
        _parsePdfTextOperators(textStream, extractedChunks);
      } catch (_) {
        // إذا لم يكن التدفق مضغوطاً بـ zlib، نحلله مباشرة
        _parsePdfTextOperators(streamContent, extractedChunks);
      }
    }

    // 2. إذا لم نجد تدفقات قياسية، نستخرج النصوص المقروءة بين الأقواس مباشرة
    if (extractedChunks.isEmpty) {
      _parsePdfTextOperators(rawLatin, extractedChunks);
    }

    final joined = extractedChunks
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return joined;
  }

  static void _parsePdfTextOperators(String content, List<String> out) {
    final parenRegex = RegExp(r'\(([^\(\)\\]{3,200})\)');
    for (final match in parenRegex.allMatches(content)) {
      final s = match.group(1)?.trim() ?? '';
      // استبعاد الرموز غير المفهومة وأسماء الخطوط
      if (s.length > 3 &&
          RegExp(r'[a-zA-Z\u0600-\u06FF]{3,}').hasMatch(s) &&
          !s.startsWith('Identity-') &&
          !s.contains('Adobe')) {
        out.add(s);
      }
    }
  }

  // البحث في ذاكرة الهاتف عن ملفات PDF و TXT المتاحة
  static Future<List<File>> scanPhoneForBookFiles() async {
    final foundFiles = <File>[];
    final candidateDirs = <String>[
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Documents',
      '/sdcard/Download',
      '/sdcard/Documents',
    ];

    try {
      final appDoc = await getApplicationDocumentsDirectory();
      candidateDirs.add(appDoc.path);
    } catch (_) {}

    final seenPaths = <String>{};
    for (final dirPath in candidateDirs) {
      try {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          final entities = dir.listSync(recursive: false, followLinks: false);
          for (final ent in entities) {
            if (ent is File) {
              final ext = p.extension(ent.path).toLowerCase();
              if ((ext == '.pdf' || ext == '.txt' || ext == '.md') &&
                  !seenPaths.contains(ent.path)) {
                seenPaths.add(ent.path);
                foundFiles.add(ent);
              }
            }
          }
        }
      } catch (_) {}
    }
    return foundFiles;
  }

  // فصول Bailey & Love 28th الجاهزة للاستيراد وتوليد الأسئلة بضغطة زر
  static List<BaileyChapterPreset> getBailey28BuiltInChapters() {
    return [
      BaileyChapterPreset(
        chapterTitleAr: 'Bailey Ch 68: التهاب البنكرياس الحاد (Acute Pancreatitis)',
        chapterTitleEn: 'Bailey Ch 68: Acute Pancreatitis & Complications',
        contentAr:
            'أسباب التهاب البنكرياس الحاد (GET SMASHED): الحصيات الصفراوية (Gallstones) والكحول يمثلان 80% من الحالات، تليها رضوض البطن، الستيرويدات، النكاف، المناعة الذاتية، لدغة العقرب، فرط شحوم وكالسيوم الدم، ناظور ERCP، والأدوية.\n'
            'تشخيص التهاب البنكرياس الحاد (Atlanta Criteria): يتطلب تحقق شرطين من ثلاثة: 1. ألم شرسوفي حاد ينتشر للظهر. 2. ارتفاع الأميلاز أو الليباز لأكثر من 3 أضعاف الحد الطبيعي. 3. موجودات شعاعية نموذجية في المفراس أو السونار.\n'
            'معايير غلاسكو لشدة التهاب البنكرياس (Modified Glasgow Score - PANCREAS): PaO2 أقل من 8 kPa، العمر أكثر من 55 سنة، الكريات البيض أكثر من 15، الكالسيوم أقل من 2 mmol/L، اليوريا أكثر من 16، إنزيم LDH أكثر من 600، الألبومين أقل من 32، السكر أكثر من 10. وجود 3 علامات أو أكثر يدل على التهاب شديد.\n'
            'الكيسة الكاذبة البنكرياسية (Pancreatic Pseudocyst): تجمع سائل غني بالأميلاز محاط بجدار ليفي غير ظهاري يتشكل بعد 4 أسابيع من النوبة الحادة، ويعالج بالتفجير الداخلي للمعدة (Cystogastrostomy) بالمنظار أو الجراحة إذا تجاوز 6 سم أو استمر لأكثر من 6 أسابيع.',
        contentEn:
            'Etiology of Acute Pancreatitis (GET SMASHED): Gallstones (50%) and Alcohol (25%) account for the majority, followed by Trauma, Steroids, Mumps, Autoimmune, Scorpion venom, Hyperlipidemia/Hypercalcemia, ERCP, and Drugs (Azathioprine).\n'
            'Revised Atlanta Criteria for Diagnosis: Requires at least 2 of 3 features: 1. Acute severe epigastric pain radiating to the back. 2. Serum amylase or lipase >= 3 times upper limit of normal. 3. Characteristic findings on contrast-enhanced CT or ultrasound.\n'
            'Modified Glasgow Prognostic Score (PANCREAS): PaO2 < 8 kPa (60 mmHg), Age > 55 years, Neutrophils (WBC) > 15, Calcium < 2.0 mmol/L, Renal (Urea > 16 mmol/L), Enzymes (LDH > 600 IU/L), Albumin < 32 g/L, Sugar (Glucose > 10 mmol/L). Score >= 3 indicates severe pancreatitis.\n'
            'Pancreatic Pseudocyst Management: A collection of amylase-rich fluid enclosed by a non-epithelialized fibrous wall (>4 weeks after acute attack). Managed by endoscopic or surgical internal drainage (Cystogastrostomy) if symptomatic, infected, or >6 cm.',
      ),
      BaileyChapterPreset(
        chapterTitleAr: 'Bailey Ch 69: التهاب الزائدة الدودية الحاد (Acute Appendicitis)',
        chapterTitleEn: 'Bailey Ch 69: Acute Appendicitis & Alvarado Score',
        contentAr:
            'العلامات السريرية في التهاب الزائدة الحاد: ألم يبدأ حول السرة (حشوي) ثم ينتقل ويستقر في الحفرة الحرقفية اليمنى RIF (جداري)، ويترافق مع فقدان الشهية (Anorexia) وغثيان وحمى خفيفة.\n'
            'علامات الفحص السريري للزائدة: علامة روفزينغ (ألم في RIF عند ضغط LIF)، علامة العضلة القطنية (Psoas sign في الزائدة خلف الأعور Retrocaecal)، وعلامة السدادية (Obturator sign في الزائدة الحوضية Pelvic).\n'
            'مقياس ألفارادو (Alvarado Score - MANTRELS): انتقال الألم (1)، فقدان الشهية (1)، غثيان/تقيؤ (1)، إيلام في RIF (2 نقاط)، إيلام مرتد Rebound (1)، ترفع حروري (1)، ارتفاع الكريات البيض (2 نقاط)، انحراف الصيغة لليسار (1). مجموع 7 أو أكثر يستطب الجراحة.\n'
            'تدبير كتلة الزائدة (Appendix Mass - Ochsner-Sherren Regimen): إذا حضر المريض بعد 3-5 أيام بكتلة محسوسة في RIF بدون علامات التهاب صفاق معمم، يعالج تحفظياً بالسوائل والصادات الحيوية ومراقبة حجم الكتلة والعلامات الحيوية، مع استبعاد الخراج بالمفراس.',
        contentEn:
            'Clinical Presentation of Acute Appendicitis: Periumbilical visceral pain migrating to the Right Iliac Fossa (RIF) within 24 hours, accompanied by anorexia, nausea, and low-grade pyrexia.\n'
            'Special Physical Signs: Rovsing sign (pain in RIF on palpation of LIF), Psoas sign (pain on right hip extension, classic for retrocaecal appendix), Obturator sign (pain on internal rotation of flexed right hip, classic for pelvic appendix).\n'
            'Alvarado Score (MANTRELS - 10 points): Migration of pain (1), Anorexia (1), Nausea/vomiting (1), Tenderness in RIF (2), Rebound tenderness (1), Elevated temperature (1), Leucocytosis (2), Shift to the left (1). Score >= 7 strongly predicts appendicitis.\n'
            'Appendix Mass Management (Ochsner-Sherren Regimen): When a patient presents late (>72h) with a well-circumscribed RIF phlegmon/mass and no generalized peritonitis: initial conservative management with IV fluids, antibiotics, marking mass borders, and CT to drain any abscess.',
      ),
      BaileyChapterPreset(
        chapterTitleAr: 'Bailey Ch 62: القرحة الهضمية المثقوبة والنزف العلوي (Peptic Ulcer)',
        chapterTitleEn: 'Bailey Ch 62: Perforated Peptic Ulcer & Upper GI Bleed',
        contentAr:
            'انثقاب القرحة الهضمية (Perforated Peptic Ulcer): يحدث غالباً في الجدار الأمامي للبصلة الاثني عشرية (Anterior wall of first part of duodenum)، بينما القرحة الخلفية تنزف بتآكل الشريان المعدي الاثني عشري (Gastroduodenal artery).\n'
            'التشخيص الشعاعي لانثقاب القرحة: صورة الصدر بوضعية الوقوف (Erect CXR) تظهر هواءً حراً تحت الحجاب الحاجز في 75% من الحالات؛ وإذا كانت سلبية يجرى مفراس البطن (CT).\n'
            'العملية الجراحية لانثقاب القرحة الاثني عشرية: إنعاش بالسوائل والصادات ومضادات الحموضة وريدياً، ثم غلق الانثقاب برقعة من الثرب الكبير (Graham Omental Patch) بالمنظار أو الفتح، مع غسل البطن الكامل وأخذ خزعة إذا كانت القرحة معدية لنفي الخباثة.',
        contentEn:
            'Anatomical Site of Perforation vs Bleeding: Anterior duodenal ulcers perforate into the peritoneal cavity causing peritonitis, whereas posterior duodenal ulcers erode into the Gastroduodenal Artery (GDA) causing severe upper GI hemorrhage.\n'
            'Radiological Diagnosis of Perforated Viscus: Erect Chest X-ray demonstrates free subdiaphragmatic air (pneumoperitoneum) in ~75% of cases; CT abdomen is the gold standard if CXR is equivocal.\n'
            'Surgical Management of Perforated Duodenal Ulcer: Aggressive resuscitation, IV PPI and antibiotics, followed by Laparoscopic or Open Graham Omental Patch repair, thorough peritoneal lavage, H. pylori eradication, and biopsy of all gastric ulcers to exclude malignancy.',
      ),
      BaileyChapterPreset(
        chapterTitleAr: 'Bailey Ch 56: مضاعفات استئصال الغدة الدرقية (Thyroidectomy Complications)',
        chapterTitleEn: 'Bailey Ch 56: Post-Thyroidectomy Emergencies & Nerve Injury',
        contentAr:
            'الورم الدموي الضاغط بعد استئصال الدرقية (Tension Haematoma): طارئة جراحية تهدد الحياة بالاختناق بسبب وذمة الحنجرة؛ التدبير الفوري على سرير المريض هو فتح خيوط الجلد والعضلات الحزامية وطبقات الجرح فوراً (Scoop out clot) قبل نقل المريض لصالة العمليات لإرقاء النزف.\n'
            'إصابات الأعصاب في جراحة الدرقية: 1. الفرع الخارجي للعصب الحنجري العلوي (EBSLN): يرافق الأوعية الدرقية العلوية ويسبب تغير نبرة الصوت العالية. 2. العصب الحنجري الراجع (RLN): الإصابة أحادية الجانب تسبب بحة صوت، والإصابة ثنائية الجانب تسبب انسداد مجرى الهواء الحاد (Stridor) عند رفع أنبوب التخدير.\n'
            'نقص كالسيوم الدم بعد الدرقية (Hypocalcaemia): يظهر خلال 24-48 ساعة بسبب أذية أو نقص تروية الغدد جارات الدرقية؛ علاماته: خدر حول الفم والأصابع، علامة Chvostek وعلامة Trousseau، ويعالج بغلوكونات الكالسيوم وريدياً مع فيتامين D.',
        contentEn:
            'Post-Thyroidectomy Tension Haematoma: Causes airway obstruction via venous/lymphatic congestion and laryngeal edema. Immediate bedside management: open skin clips, subcuticular sutures, and deep strap muscles at the bedside to evacuate clot before transferring to theatre.\n'
            'Laryngeal Nerve Injuries: 1. External Branch of Superior Laryngeal Nerve (EBSLN): injured during high ligation of superior thyroid vessels -> loss of voice pitch/projection. 2. Recurrent Laryngeal Nerve (RLN): unilateral -> hoarseness; bilateral -> acute stridor and airway obstruction upon extubation.\n'
            'Postoperative Hypoparathyroidism (Hypocalcaemia): Manifests 24-48h post-op with circumoral numbness, carpopedal spasm, positive Chvostek and Trousseau signs. Severe cases (<1.90 mmol/L or symptomatic) require 10 mL of 10% Calcium Gluconate IV slowly.',
      ),
    ];
  }
}

// ==========================================
// قاموس اللغات الشامل 100% (العربية / English / کوردی)
// ==========================================
class L10n {
  static String t(String key, String lang) {
    final bool isEn = lang == 'en';
    final bool isKu = lang == 'ku';
    switch (key) {
      case 'appTitle':
        return isEn
            ? 'Surgical Board Logbook'
            : (isKu ? 'تۆماری بۆردی نەشتەرگەری' : 'سجل البورد الجراحي');
      case 'seminar':
        return isEn ? 'Seminar' : (isKu ? 'سیمینار' : 'سيمينار');
      case 'logbookPdf':
        return isEn ? 'Logbook PDF' : (isKu ? 'لۆگبووک PDF' : 'لوكبوك PDF');
      case 'backup':
        return isEn ? 'Cloud/Sync' : (isKu ? 'هەور/کۆپی' : 'نسخ');
      case 'cases':
        return isEn ? 'Cases' : (isKu ? 'نەخۆشەکان' : 'الحالات');
      case 'surgeonPS':
        return isEn ? 'Surgeon P/S' : (isKu ? 'نەشتەرگەر P/S' : 'جراح P/S');
      case 'biopsy':
        return isEn ? 'Biopsy' : (isKu ? 'زەرع' : 'الزرع');
      case 'exam':
        return isEn ? 'Exam ⭐' : (isKu ? 'تاقیکردنەوە' : 'امتحان');
      case 'searchHint':
        return isEn
            ? 'Search by name, procedure, diagnosis, HPI, supervisor...'
            : (isKu
                ? 'گەڕان بە ناو، نەشتەرگەری، دەستنیشانکردن، سەرپەرشتیار...'
                : 'ابحث بالاسم، العملية، التشخيص، القصة المرضية، المشرف، الروتيشن ...');
      case 'all':
        return isEn ? 'All' : (isKu ? 'هەموو' : 'الكل');
      case 'scheduled':
        return isEn ? 'Scheduled' : (isKu ? 'بڕیارلێدراو' : 'مقررة');
      case 'completed':
        return isEn ? 'Completed' : (isKu ? 'ئەنجامدراو' : 'تمت العملية');
      case 'pendingBiopsy':
        return isEn ? 'Pending Biopsy' : (isKu ? 'چاوەڕوانی زەرع' : 'بانتظار الزرع');
      case 'addNewCase':
        return isEn
            ? 'Add New Case'
            : (isKu ? 'زیادکردنی نەخۆشی نوێ' : 'إضافة حالة جديدة');
      case 'navHome':
        return isEn ? 'Home' : (isKu ? 'سەرەکی' : 'الرئيسية');
      case 'navStudy':
        return isEn ? 'Study & Bailey' : (isKu ? 'خوێندن' : 'الدراسة 🎓');
      case 'navCases':
        return isEn ? 'Rotations' : (isKu ? 'ڕۆتەیشن' : 'الحالات');
      case 'navStats':
        return isEn ? 'Analytics' : (isKu ? 'ئامارەکان' : 'الإحصائيات');
      case 'navSettings':
        return isEn ? 'Settings' : (isKu ? 'ڕێکخستن' : 'الإعدادات');
      case 'diagnosis':
        return isEn ? 'Diagnosis: ' : (isKu ? 'دەستنیشانکردن: ' : 'التشخيص: ');
      case 'hpiShort':
        return isEn ? 'HPI: ' : (isKu ? 'مێژووی نەخۆشی: ' : 'القصة (HPI): ');
      case 'operation':
        return isEn ? 'Operation: ' : (isKu ? 'نەشتەرگەری: ' : 'العملية: ');
      case 'photosAttached':
        return isEn ? 'photos attached' : (isKu ? 'وێنەی هاوپێچ' : 'صور مرفقة');
      case 'tabFlashcards':
        return isEn ? 'Flashcards' : 'الفلاش كارت';
      case 'tabSlides':
        return isEn ? 'Surgical Slides' : 'السلايدات العلمية';
      case 'tabDailyQuiz':
        return isEn ? 'Daily Quiz' : 'اختباري اليومي';
      case 'tabBookReader':
        return isEn ? 'PDF & Book Q&A' : 'قارئ الكتب و PDF';
      case 'tabOsce':
        return isEn ? 'OSCE & Case Viva' : 'محاكي الحالات OSCE';
      case 'addCard':
        return isEn ? 'Add Card / Slide' : 'إضافة كارت / سلايد';
      case 'tapToFlip':
        return isEn ? 'Tap card to reveal answer 💡' : 'اضغط لكشف الجواب 💡';
      case 'mastered':
        return isEn ? 'Mastered ✅' : 'متقن ✅';
      case 'reviewLater':
        return isEn ? 'Review Later 🔄' : 'أراجعه لاحقاً 🔄';
      case 'dailyTarget':
        return isEn ? 'Daily Questions Count:' : 'عدد الأسئلة اليومية:';
      case 'startDailyQuiz':
        return isEn ? 'Generate New Daily Quiz' : 'توليد دفعة أسئلة يومية جديدة';
      default:
        return key;
    }
  }
}

// ==========================================
// الهوية اللونية المطابقة للتصميم + الإضاءة الخلفية
// ==========================================
class AppColors {
  static const Color navyDark = Color(0xFF08203E);
  static const Color navyPrimary = Color(0xFF0D3562);
  static const Color navyAccent = Color(0xFF154C88);
  static const Color bgLight = Color(0xFFF3F6FA);

  static const Color statPurpleBg = Color(0xFFF1EAFF);
  static const Color statPurpleBorder = Color(0xFF6C3CE9);

  static const Color statBlueBg = Color(0xFFE5F2FF);
  static const Color statBlueBorder = Color(0xFF1976D2);

  static const Color statMintBg = Color(0xFFDFF7EE);
  static const Color statMintBorder = Color(0xFF00A86B);

  static const Color statAmberBg = Color(0xFFFFF3DC);
  static const Color statAmberBorder = Color(0xFFF59E0B);

  static const Color pillGreenBg = Color(0xFFD7F5E8);
  static const Color pillGreenText = Color(0xFF0D6832);

  static const Color pillOrangeBg = Color(0xFFFDECC8);
  static const Color pillOrangeText = Color(0xFF7A4100);

  static const Color pillPurpleBg = Color(0xFFEDE7FB);
  static const Color pillPurpleText = Color(0xFF4A2574);

  static const Color roleBadgeBg = Color(0xFFDCE8F8);

  static Color getPrimaryColor(String palette) {
    switch (palette) {
      case 'emerald':
        return const Color(0xFF005B4F);
      case 'burgundy':
        return const Color(0xFF6B1D2F);
      case 'indigo':
        return const Color(0xFF311B92);
      default:
        return navyPrimary;
    }
  }

  static Color getDarkHeaderColor(String palette) {
    switch (palette) {
      case 'emerald':
        return const Color(0xFF003831);
      case 'burgundy':
        return const Color(0xFF420E1B);
      case 'indigo':
        return const Color(0xFF1A0E52);
      default:
        return navyDark;
    }
  }

  static Color getBackgroundColor(String lightMode) {
    switch (lightMode) {
      case 'warm':
        return const Color(0xFFFDF8EC);
      case 'dark':
        return const Color(0xFF0F172A);
      default:
        return bgLight;
    }
  }

  static Color getCardColor(String lightMode) {
    switch (lightMode) {
      case 'warm':
        return const Color(0xFFFFFDF7);
      case 'dark':
        return const Color(0xFF1E293B);
      default:
        return Colors.white;
    }
  }

  static Color getTextColor(String lightMode) {
    return lightMode == 'dark' ? Colors.white : navyDark;
  }
}

class SurgicalRegistryApp extends StatelessWidget {
  const SurgicalRegistryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سجل البورد الجراحي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.navyPrimary,
        scaffoldBackgroundColor: AppColors.bgLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.navyDark,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const MainShellScreen(),
    );
  }
}

// ==========================================
// رسام خط نبض القلب (ECG Wave Painter) تحت العنوان
// ==========================================
class EcgWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF64B5F6).withOpacity(0.85)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final midY = size.height / 2;
    final w = size.width;

    path.moveTo(0, midY);
    path.lineTo(w * 0.35, midY);
    path.lineTo(w * 0.40, midY - 4);
    path.lineTo(w * 0.44, midY + 4);
    path.lineTo(w * 0.48, midY - 14);
    path.lineTo(w * 0.52, midY + 12);
    path.lineTo(w * 0.56, midY - 6);
    path.lineTo(w * 0.60, midY);
    path.lineTo(w, midY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================
// 1. نموذج بيانات المريض واللوكبوك (Patient Model)
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

  final String rotation;
  final String consultantName;
  final String surgeonRole;
  final String operationMagnitude;

  final String chronicDiseases;
  final String allergies;
  final String currentMedications;
  final String smokingStatus;
  final String pastSurgeries;
  final String pastComplications;

  final String chiefComplaint;
  final String hpi;
  final String clinicalExam;
  final String labRadiologyNotes;
  final String diagnosis;

  final String plannedOperation;
  final String operationUrgency;
  final String asaScore;
  final String anesthesiaType;
  final String operationDate;
  final String operationStatus;
  final String operativeNotes;

  final String drainsInfo;
  final String dvtProphylaxis;
  final String antibioticProphylaxis;

  final String biopsyStatus;
  final String histopathologyResult;
  final String tnmStaging;

  final bool isStarred;
  final String surgicalPearls;
  final String vivaQuestion;
  final String vivaAnswer;

  final String finalOutcome;
  final String clavienDindoGrade;
  final String dischargeTreatment;
  final String followUpDate;

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
    required this.hpi,
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
    required this.vivaQuestion,
    required this.vivaAnswer,
    required this.finalOutcome,
    required this.clavienDindoGrade,
    required this.dischargeTreatment,
    required this.followUpDate,
    required this.radiologyImages,
    required this.labImages,
    required this.woundImages,
    required this.biopsyImages,
  });

  String displayName(bool anonymized, [String lang = 'ar']) {
    if (!anonymized) return name;
    final code = mrn.isNotEmpty ? mrn : (id?.toString() ?? 'X');
    return lang == 'en'
        ? 'Patient #$code ($gender, ${age}y)'
        : 'مريض #$code ($gender، $age سنة)';
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
      'hpi': hpi,
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
      'vivaQuestion': vivaQuestion,
      'vivaAnswer': vivaAnswer,
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
      operationMagnitude: map['operationMagnitude'] ?? 'Major',
      chronicDiseases: map['chronicDiseases'] ?? '',
      allergies: map['allergies'] ?? '',
      currentMedications: map['currentMedications'] ?? '',
      smokingStatus: map['smokingStatus'] ?? 'غير مدخن',
      pastSurgeries: map['pastSurgeries'] ?? '',
      pastComplications: map['pastComplications'] ?? '',
      chiefComplaint: map['chiefComplaint'] ?? '',
      hpi: map['hpi'] ?? '',
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
      dvtProphylaxis: map['dvtProphylaxis'] ?? 'ميكانيكي + دوائي (LMWH/Heparin)',
      antibioticProphylaxis: map['antibioticProphylaxis'] ?? '',
      biopsyStatus: map['biopsyStatus'] ?? 'لا يحتاج زرع',
      histopathologyResult: map['histopathologyResult'] ?? '',
      tnmStaging: map['tnmStaging'] ?? '',
      isStarred: (map['isStarred'] == 1 || map['isStarred'] == true),
      surgicalPearls: map['surgicalPearls'] ?? '',
      vivaQuestion: map['vivaQuestion'] ?? '',
      vivaAnswer: map['vivaAnswer'] ?? '',
      finalOutcome: map['finalOutcome'] ?? 'شفاء تام',
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
// 2. إدارة قاعدة البيانات المحلية + بنك Bailey & Love 28th ثنائي اللغة
// ==========================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('surgical_board_logbook_v3.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
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
        hpi TEXT,
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
        vivaQuestion TEXT,
        vivaAnswer TEXT,
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

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await _createBilingualStudyTableAndSeed(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE patients ADD COLUMN hpi TEXT DEFAULT ""');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE patients ADD COLUMN vivaQuestion TEXT DEFAULT ""');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE patients ADD COLUMN vivaAnswer TEXT DEFAULT ""');
      } catch (_) {}
    }
    await _createBilingualStudyTableAndSeed(db);
  }

  Future<void> _createBilingualStudyTableAndSeed(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_bank_v3 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemType TEXT,
        categoryAr TEXT,
        categoryEn TEXT,
        titleAr TEXT,
        titleEn TEXT,
        bodyAr TEXT,
        bodyEn TEXT,
        status TEXT
      )
    ''');

    final existing = await db.query('study_bank_v3');
    if (existing.isEmpty) {
      final initialItems = [
        StudyItem(
          itemType: 'flashcard',
          categoryAr: 'المرارة والكبد (HPB - Bailey Ch 67)',
          categoryEn: 'HPB & Gallbladder (Bailey Ch 67)',
          titleAr: 'ما هي المعايير الثلاثة لتحقيق الرؤية الحرجة للأمان (Critical View of Safety - CVS) لستراسبيرغ في استئصال المرارة بالمنظار؟',
          titleEn: 'What are Strasberg’s 3 criteria for achieving the Critical View of Safety (CVS) in Laparoscopic Cholecystectomy?',
          bodyAr: '1. تنظيف مثلث كالوت (Hepatocystic triangle) بالكامل من الدهون والأنسجة الليفية.\n2. فصل الثلث السفلي من المرارة عن سرير الكبد (Cystic plate).\n3. رؤية هيكلين اثنين فقط يدخلان المرارة مباشرة (Cystic duct & Cystic artery).',
          bodyEn: '1. Clearance of fat and fibrous tissue from the hepatocystic (Calot) triangle.\n2. Separation of the lower third of the gallbladder from the liver bed (cystic plate).\n3. Only two structures are seen entering the gallbladder (cystic duct and cystic artery).',
          status: 'review',
        ),
        StudyItem(
          itemType: 'flashcard',
          categoryAr: 'الغدة الدرقية والفرعية (Bailey Ch 56)',
          categoryEn: 'Thyroid & Parathyroid (Bailey Ch 56)',
          titleAr: 'ما هي حدود مثلث (Beahr’s Triangle) وكيف يساعد في تحديد العصب الحنجري الراجع (RLN)؟',
          titleEn: 'What are the boundaries of Beahr’s Triangle for identifying the Recurrent Laryngeal Nerve (RLN)?',
          bodyAr: '• وحشياً: الشريان السباتي الأصلي (Common carotid artery).\n• أنسياً: القصبة الهوائية (Trachea).\n• علوياً: الشريان الدرقي السفلي (Inferior thyroid artery).\nيمر العصب الحنجري الراجع ضمن هذا المثلث بعمق أو سطح فروع الشريان الدرقي السفلي.',
          bodyEn: '• Laterally: Common carotid artery.\n• Medially: Trachea.\n• Superiorly: Inferior thyroid artery (ITA).\nThe RLN courses within this triangle, passing superficial, deep, or between branches of the ITA.',
          status: 'review',
        ),
        StudyItem(
          itemType: 'flashcard',
          categoryAr: 'جراحة الثدي (Bailey Ch 55)',
          categoryEn: 'Breast Surgery (Bailey Ch 55)',
          titleAr: 'ما هي أركان التقييم الثلاثي (Triple Assessment) لكتلة الثدي وما هي دقة مجموعها؟',
          titleEn: 'What are the components of Triple Assessment for a breast lump and its combined accuracy?',
          bodyAr: '1. التقييم السريري (History & Clinical Examination).\n2. التصوير الشعاعي (Mammography و/أو Ultrasound حسب العمر).\n3. الخزعة النسيجية (Core Needle Biopsy).\nتتجاوز دقتها التشخيصية المجتمعة 99.6%.',
          bodyEn: '1. Clinical assessment (History & Physical exam).\n2. Imaging (Ultrasound <35y, Mammogram + US >=35y).\n3. Pathology (Core needle biopsy / FNAC).\nCombined positive predictive value exceeds 99.6%.',
          status: 'review',
        ),
        StudyItem(
          itemType: 'flashcard',
          categoryAr: 'الطوارئ والإصابات (Bailey Ch 23)',
          categoryEn: 'Trauma & Acute Care (Bailey Ch 23)',
          titleAr: 'ما هو الثلاثي القاتل في الصدمة النزفية (Lethal Triad of Trauma) وما هي مراحل جراحة السيطرة على الضرر (DCS)؟',
          titleEn: 'What is the Lethal Triad of Trauma and the 3 phases of Damage Control Surgery (DCS)?',
          bodyAr: 'الثلاثي القاتل: انخفاض الحرارة (Hypothermia)، الحماض الاستقلابي (Acidosis)، واعتلال التخثر (Coagulopathy).\nمراحل DCS:\n1. جراحة مختصرة لإيقاف النزف والسيطرة على التلوث فقط.\n2. إنعاش في العناية المركزة (ICU) لتصحيح الحرارة والحماض والتخثر.\n3. العودة للصالة للترميم الجراحي النهائي بعد 24-48 ساعة.',
          bodyEn: 'Lethal Triad: Hypothermia, Metabolic Acidosis, Coagulopathy.\nDCS Phases:\n1. Abbreviated laparotomy (arrest hemorrhage & control contamination).\n2. ICU resuscitation (rewarming, correct acidosis & coagulopathy).\n3. Definitive surgical repair (after 24-48h).',
          status: 'review',
        ),
        StudyItem(
          itemType: 'flashcard',
          categoryAr: 'الفتوق وجدار البطن (Bailey Ch 60)',
          categoryEn: 'Abdominal Wall & Hernias (Bailey Ch 60)',
          titleAr: 'ما هي حدود مثلث هيسلباخ (Hesselbach’s Triangle) وما الفرق بين الفتق المغبني المباشر وغير المباشر؟',
          titleEn: 'What are the boundaries of Hesselbach’s Triangle and how does it distinguish Direct vs Indirect Inguinal Hernia?',
          bodyAr: '• وحشياً: الأوعية الشرسوفية السفلية (Inferior epigastric vessels).\n• أنسياً: الحافة الوحشية للعضلة المستقيمة البطنية (Rectus abdominis).\n• سفلياً: الرباط المغبني (Inguinal ligament).\nالفتق المباشر يخرج ضمن المثلث (أنسياً للأوعية)، والغير مباشر يخرج وحشياً للأوعية عبر الحلقة العميقة.',
          bodyEn: '• Laterally: Inferior epigastric vessels.\n• Medially: Lateral border of rectus abdominis.\n• Inferiorly: Inguinal ligament.\nDirect hernias protrude medial to the vessels (inside the triangle); Indirect hernias originate lateral to the vessels via the deep ring.',
          status: 'review',
        ),
        StudyItem(
          itemType: 'flashcard',
          categoryAr: 'القولون والشرج (Bailey Ch 73)',
          categoryEn: 'Colorectal & Anal (Bailey Ch 73)',
          titleAr: 'ما هو تصنيف Hinchey لالتهاب الرتوج القولونية الحاد المثقوب (Complicated Diverticulitis)؟',
          titleEn: 'What is the Hinchey Classification of complicated acute colonic diverticulitis?',
          bodyAr: '• Stage I: خراج حول القولون محصور بالمساريق (Pericolic abscess).\n• Stage II: خراج حوضي أو خلف الصفاق (Pelvic/retroperitoneal abscess).\n• Stage III: التهاب صفاق قيحي معمم (Purulent peritonitis).\n• Stage IV: التهاب صفاق برازي معمم (Faecal peritonitis).',
          bodyEn: '• Stage I: Pericolic or mesenteric abscess.\n• Stage II: Walled-off pelvic or retroperitoneal abscess.\n• Stage III: Generalized purulent peritonitis.\n• Stage IV: Generalized faecal peritonitis.',
          status: 'review',
        ),
        StudyItem(
          itemType: 'slide',
          categoryAr: 'سلايدات المرارة والقنوات الصفراوية (Bailey Ch 67)',
          categoryEn: 'HPB & Biliary Slides (Bailey Ch 67)',
          titleAr: 'متلازمة ميريزي (Mirizzi Syndrome) - التصنيف والتدبير الجراحي',
          titleEn: 'Mirizzi Syndrome: Csendes Classification & Surgical Management',
          bodyAr: '📌 التعريف: انحشار حصاة في جيب هارتمان أو القناة المرارية يسبب انضغاطاً خارجياً أو ناسوراً مع القناة الكبدية المشتركة (CHD).\n'
              '📊 تصنيف Csendes:\n'
              '• Type I: انضغاط خارجي للقناة المشتركة بدون ناسور.\n'
              '• Type II: ناسور يشمل أقل من ثلث محيط القناة المشتركة.\n'
              '• Type III: ناسور يشمل ثلث إلى ثلثي المحيط.\n'
              '• Type IV: تدمير كامل لجدار القناة الكبدية المشتركة.\n'
              '🔪 التدبير الجراحي:\n'
              '• Type I: استئصال مرارة جزئي (Subtotal cholecystectomy).\n'
              '• Type II-III: رأب القناة بقطعة من المرارة حول T-tube أو مفاغرة.\n'
              '• Type IV: مفاغرة كبدية صائمية (Roux-en-Y Hepaticojejunostomy).',
          bodyEn: '📌 Definition: Extrinsic compression or erosion of the Common Hepatic Duct (CHD) by an impacted stone in Hartmann’s pouch or cystic duct.\n'
              '📊 Csendes Classification:\n'
              '• Type I: External compression of CHD without fistula.\n'
              '• Type II: Cholecystobiliary fistula < 1/3 of CHD circumference.\n'
              '• Type III: Fistula involving 1/3 to 2/3 of circumference.\n'
              '• Type IV: Destruction of the entire CHD wall.\n'
              '🔪 Management:\n'
              '• Type I: Fundus-first or Subtotal cholecystectomy.\n'
              '• Type II-III: Cuff repair over T-tube or Hepaticojejunostomy.\n'
              '• Type IV: Roux-en-Y Hepaticojejunostomy.',
          status: 'review',
        ),
        StudyItem(
          itemType: 'slide',
          categoryAr: 'سلايدات الطوارئ والبطن الحاد (Bailey Ch 69)',
          categoryEn: 'Acute Abdomen Slides (Bailey Ch 69)',
          titleAr: 'انسداد الأمعاء الدقيقة والغليظة (Bowel Obstruction Essentials)',
          titleEn: 'Small vs Large Bowel Obstruction: Key Surgical Pearls',
          bodyAr: '📌 الرباعية الكلاسيكية: ألم بطني مغصي، تقيؤ، إمساك مطلق، وتمدد البطن.\n'
              '🔍 الفروقات الشعاعية (AXR / CT):\n'
              '• الأمعاء الدقيقة (SBO): عرى مركزية، خطوط Valvulae conniventes تعبر كامل لمعة الأمعاء، قطر > 3 سم.\n'
              '• الأمعاء الغليظة (LBO): عرى محيطية، Haustra لا تعبر كامل اللمعة، قطر الأعور > 9 سم ينذر بالانثقاب.\n'
              '⚠️ علامات الاختناق (Strangulation): ألم مستمر شديد، تسرع قلب، حماض لاكتيكي، كريات بيض مرتفعة، وعلامات الصفاق -> فتح بطن عاجل.',
          bodyEn: '📌 Cardinal Tetrad: Colicky abdominal pain, Vomiting, Absolute constipation, Abdominal distension.\n'
              '🔍 Radiology (AXR/CT):\n'
              '• Small Bowel (SBO): Central loops, Valvulae conniventes cross full width, diameter > 3 cm.\n'
              '• Large Bowel (LBO): Peripheral loops, Haustra incomplete, Caecal diameter > 9 cm risks perforation.\n'
              '⚠️ Signs of Strangulation: Continuous severe pain, tachycardia, peritonism, leucocytosis, elevated lactate -> Urgent Laparotomy.',
          status: 'review',
        ),
        StudyItem(
          itemType: 'slide',
          categoryAr: 'سلايدات الأساسيات وما حول الجراحة (Bailey Ch 4)',
          categoryEn: 'Perioperative & Principles Slides (Bailey Ch 4)',
          titleAr: 'الوقاية بالصادات وتصنيف الجروح الجراحية (SSI & Wound Classes)',
          titleEn: 'Surgical Site Infection (SSI) & Wound Classification',
          bodyAr: '📊 تصنيف الجروح الجراحية ونسبة الخمج:\n'
              '1. نظيف (Clean - Class I): مثل الفتق والدرقية والثدي (< 2%).\n'
              '2. نظيف ملوث (Clean-Contaminated - Class II): فتح السبيل الهضمي أو الصفراوي أو البولي تحت سيطرة (< 8%).\n'
              '3. ملوث (Contaminated - Class III): انسكاب معوي صريح أو التهاب حاد غير قيحي (15%).\n'
              '4. قذر/مخموج (Dirty/Infected - Class IV): انثقاب حشوي قديم أو خراج قيحي (> 25%).\n'
              '⏱️ توقيت الصاد الوقائي: يُعطى وريدياً خلال 30-60 دقيقة قبل الشق الجراحي.',
          bodyEn: '📊 Wound Classes & SSI Risk:\n'
              '1. Clean (Class I): Hernia, thyroid, breast (< 2%).\n'
              '2. Clean-Contaminated (Class II): Controlled entry into GI/biliary/GU tract (< 8%).\n'
              '3. Contaminated (Class III): Gross spillage, acute non-purulent inflammation (15%).\n'
              '4. Dirty/Infected (Class IV): Perforated viscus, faecal peritonitis, abscess (> 25%).\n'
              '⏱️ Prophylaxis Timing: IV administration within 30-60 minutes prior to skin incision.',
          status: 'review',
        ),
      ];

      for (var item in initialItems) {
        await db.insert('study_bank_v3', item.toMap());
      }
    }
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

  Future<int> insertStudyItem(StudyItem item) async {
    final db = await instance.database;
    return await db.insert('study_bank_v3', item.toMap());
  }

  Future<List<StudyItem>> getAllStudyItems() async {
    final db = await instance.database;
    final result = await db.query('study_bank_v3', orderBy: 'id DESC');
    return result.map((json) => StudyItem.fromMap(json)).toList();
  }

  Future<int> updateStudyItem(StudyItem item) async {
    final db = await instance.database;
    return await db.update(
      'study_bank_v3',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteStudyItem(int id) async {
    final db = await instance.database;
    return await db.delete('study_bank_v3', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> getSetting(String key, String defaultVal) async {
    final db = await instance.database;
    final res = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (res.isEmpty) return defaultVal;
    return (res.first['value'] as String?) ?? defaultVal;
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
// خدمة الخزن السحابي الذكية مع المصحح التلقائي لروابط Firebase Console
// ==========================================
class FirebaseCloudService {
  // تصحيح أي رابط يلصقه المستخدم حتى لو كان رابط console.firebase.google.com
  static String normalizeFirebaseUrl(String rawUrl) {
    String u = rawUrl.trim();
    if (u.isEmpty) {
      return 'https://surgen-5-default-rtdb.firebaseio.com';
    }
    // إذا لصق المستخدم رابط لوحة تحكم المتصفح مثل:
    // console.firebase.google.com/u/0/project/surgen-5/database/surgen-5-default-rtdb/data/~2F
    final consoleMatch = RegExp(r'database/([a-zA-Z0-9\-]+)').firstMatch(u);
    if (consoleMatch != null && u.contains('Data') || (consoleMatch != null && !u.contains('firebaseio.com') && !u.contains('firebasedatabase.app'))) {
      final dbName = consoleMatch.group(1)!;
      return 'https://$dbName.firebaseio.com';
    }

    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      if (u.contains('.firebaseio.com') || u.contains('.firebasedatabase.app')) {
        u = 'https://$u';
      } else {
        u = 'https://$u.firebaseio.com';
      }
    }

    final uri = Uri.tryParse(u);
    if (uri != null && uri.host.isNotEmpty) {
      if (uri.host == 'console.firebase.google.com' && consoleMatch != null) {
        return 'https://${consoleMatch.group(1)!}.firebaseio.com';
      }
      return '${uri.scheme}://${uri.host}';
    }

    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  // تجربة الاتصال التلقائي بالنطاق الأمريكي والأوروبي والآسيوي إذا لزم الأمر
  static List<String> _buildCandidateBaseUrls(String rawUrl) {
    final primary = normalizeFirebaseUrl(rawUrl);
    final candidates = <String>[primary];
    final dbMatch = RegExp(r'https://([a-zA-Z0-9\-]+)\.firebaseio\.com').firstMatch(primary);
    if (dbMatch != null) {
      final dbId = dbMatch.group(1)!;
      candidates.add('https://$dbId.europe-west1.firebasedatabase.app');
      candidates.add('https://$dbId.asia-southeast1.firebasedatabase.app');
    }
    return candidates;
  }

  static Future<String> uploadToFirebase({
    required String dbUrl,
    required String userSecretKey,
    required List<PatientRecord> patients,
    required List<StudyItem> studyItems,
    required Map<String, String> doctorProfile,
  }) async {
    final safeKey = userSecretKey.trim().isEmpty ? 'dr_evan_default' : userSecretKey.trim();
    final payload = {
      'updatedAt': DateTime.now().toIso8601String(),
      'doctorProfile': doctorProfile,
      'patientsCount': patients.length,
      'patients': patients.map((e) => e.toMap()).toList(),
      'studyItems': studyItems.map((e) => e.toMap()).toList(),
    };

    final candidates = _buildCandidateBaseUrls(dbUrl);
    Object? lastError;

    for (final baseUrl in candidates) {
      try {
        final endpoint = Uri.parse('$baseUrl/surgical_board_registry/$safeKey.json');
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 15);
        final request = await client.putUrl(endpoint);
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
        request.add(utf8.encode(jsonEncode(payload)));
        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();
        client.close();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return baseUrl;
        } else {
          lastError = 'HTTP ${response.statusCode}: $responseBody';
        }
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('$lastError');
  }

  static Future<int> restoreFromFirebase({
    required String dbUrl,
    required String userSecretKey,
    required bool replaceExisting,
  }) async {
    final safeKey = userSecretKey.trim().isEmpty ? 'dr_evan_default' : userSecretKey.trim();
    final candidates = _buildCandidateBaseUrls(dbUrl);
    String? responseBody;
    Object? lastError;

    for (final baseUrl in candidates) {
      try {
        final endpoint = Uri.parse('$baseUrl/surgical_board_registry/$safeKey.json');
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 15);
        final request = await client.getUrl(endpoint);
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        client.close();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          responseBody = body;
          break;
        } else {
          lastError = 'HTTP ${response.statusCode}: $body';
        }
      } catch (e) {
        lastError = e;
      }
    }

    if (responseBody == null) {
      throw Exception('$lastError');
    }

    if (responseBody == 'null' || responseBody.trim().isEmpty) {
      return 0;
    }

    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) return 0;

    if (decoded['doctorProfile'] is Map) {
      final prof = Map<String, dynamic>.from(decoded['doctorProfile']);
      for (var entry in prof.entries) {
        await DatabaseHelper.instance.saveSetting(entry.key, entry.value.toString());
      }
    }

    final existingPatients = await DatabaseHelper.instance.getAllPatients();
    if (replaceExisting) {
      for (var old in existingPatients) {
        if (old.id != null) await DatabaseHelper.instance.deletePatient(old.id!);
      }
    }

    int importedCount = 0;
    final rawPatients = decoded['patients'];
    if (rawPatients is List) {
      for (var item in rawPatients) {
        if (item == null) continue;
        final map = Map<String, dynamic>.from(item);
        map.remove('id');
        await DatabaseHelper.instance.insertPatient(PatientRecord.fromMap(map));
        importedCount++;
      }
    }

    final rawStudy = decoded['studyItems'];
    if (rawStudy is List) {
      if (replaceExisting) {
        final oldStudy = await DatabaseHelper.instance.getAllStudyItems();
        for (var s in oldStudy) {
          if (s.id != null) await DatabaseHelper.instance.deleteStudyItem(s.id!);
        }
      }
      for (var item in rawStudy) {
        if (item == null) continue;
        final map = Map<String, dynamic>.from(item);
        map.remove('id');
        await DatabaseHelper.instance.insertStudyItem(StudyItem.fromMap(map));
      }
    }

    return importedCount;
  }
}

// ==========================================
// 3. الهيكل الرئيسي مع الشريط السفلي الخماسي (Main Shell)
// ==========================================
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentTabIndex = 0;
  int _studySubTabIndex = 0; // 0: Flashcards | 1: Slides | 2: Daily Quiz | 3: PDF & Book Q&A | 4: OSCE

  List<PatientRecord> _allPatients = [];
  List<PatientRecord> _filteredPatients = [];
  List<StudyItem> _studyItems = [];

  String _searchQuery = '';
  String _selectedFilter = 'الكل';
  bool _isLoading = true;
  bool _isAnonymized = false;
  bool _isCloudSyncing = false;

  int _currentSlideIndex = 0;
  int _dailyQuestionTarget = 5;
  List<StudyItem> _dailyQuizQuestions = [];
  int _dailyQuizCurrentIdx = 0;
  int _dailyQuizScore = 0;
  bool _dailyQuizShowAnswer = false;

  PatientRecord? _osceCurrentPatient;
  bool _osceRevealAnswer = false;

  // متحكمات قارئ الكتب وملفات الـ PDF
  final TextEditingController _bookTopicCtrl = TextEditingController(text: 'Bailey & Love 28th - Extracted Chapter');
  final TextEditingController _bookFilePathCtrl = TextEditingController();
  final TextEditingController _bookRawTextCtrl = TextEditingController();
  bool _alsoCreateSlideFromBook = true;

  String _residentName = 'د. إيفان إحسان';
  String _residentLevel = 'البورد في الجراحة العامة';
  String _hospitalName = 'المستشفى التعليمي';
  int _boardTargetP = 100;

  String _appLanguage = 'ar';
  String _themePalette = 'navy';
  String _lightingMode = 'light';
  double _bgBrightness = 1.0;

  String _firebaseDbUrl = 'https://surgen-5-default-rtdb.firebaseio.com';
  String _firebaseSecretCode = 'dr_evan_board_logbook';
  String _lastCloudSync = 'لم تتم المزامنة بعد';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllPatients();
    final sItems = await DatabaseHelper.instance.getAllStudyItems();
    final rName = await DatabaseHelper.instance.getSetting('residentName', 'د. إيفان إحسان');
    final rLevel = await DatabaseHelper.instance.getSetting('residentLevel', 'البورد في الجراحة العامة');
    final hName = await DatabaseHelper.instance.getSetting('hospitalName', 'المستشفى التعليمي');
    final targetStr = await DatabaseHelper.instance.getSetting('boardTargetP', '100');
    String fbUrl = await DatabaseHelper.instance.getSetting(
      'firebaseDbUrl',
      'https://surgen-5-default-rtdb.firebaseio.com',
    );
    // تصحيح تلقائي لأي رابط Console أو رابط قديم محفوظ في الجهاز
    if (fbUrl.contains('console.firebase.google.com') || fbUrl.contains('games-242da')) {
      fbUrl = FirebaseCloudService.normalizeFirebaseUrl(fbUrl);
      if (fbUrl.contains('games-242da')) {
        fbUrl = 'https://surgen-5-default-rtdb.firebaseio.com';
      }
      await DatabaseHelper.instance.saveSetting('firebaseDbUrl', fbUrl);
    } else {
      fbUrl = FirebaseCloudService.normalizeFirebaseUrl(fbUrl);
    }

    final fbCode = await DatabaseHelper.instance.getSetting('firebaseSecretCode', 'dr_evan_board_logbook');
    final lastSync = await DatabaseHelper.instance.getSetting('lastCloudSync', 'لم تتم المزامنة بعد');
    final lang = await DatabaseHelper.instance.getSetting('appLanguage', 'ar');
    final palette = await DatabaseHelper.instance.getSetting('themePalette', 'navy');
    final lightMode = await DatabaseHelper.instance.getSetting('lightingMode', 'light');
    final brightStr = await DatabaseHelper.instance.getSetting('bgBrightness', '1.0');
    final dailyQStr = await DatabaseHelper.instance.getSetting('dailyQuestionTarget', '5');

    setState(() {
      _allPatients = data;
      _studyItems = sItems;
      _residentName = rName;
      _residentLevel = rLevel;
      _hospitalName = hName;
      _boardTargetP = int.tryParse(targetStr) ?? 100;
      _firebaseDbUrl = fbUrl;
      _firebaseSecretCode = fbCode;
      _lastCloudSync = lastSync;
      _appLanguage = lang;
      _themePalette = palette;
      _lightingMode = lightMode;
      _bgBrightness = (double.tryParse(brightStr) ?? 1.0).clamp(0.45, 1.0);
      _dailyQuestionTarget = int.tryParse(dailyQStr) ?? 5;
      if (_allPatients.isNotEmpty && _osceCurrentPatient == null) {
        _osceCurrentPatient = _allPatients.first;
      }
      if (_dailyQuizQuestions.isEmpty && _studyItems.isNotEmpty) {
        _generateDailyQuizBatch();
      }
      _applyFilters();
      _isLoading = false;
    });
  }

  void _generateDailyQuizBatch() {
    final pool = List<StudyItem>.from(_studyItems);
    for (var p in _allPatients) {
      if (p.vivaQuestion.trim().isNotEmpty) {
        pool.add(StudyItem(
          itemType: 'case_viva',
          categoryAr: 'حالة سريرية: ${p.diagnosis}',
          categoryEn: 'Clinical Case: ${p.diagnosis}',
          titleAr: p.vivaQuestion,
          titleEn: p.vivaQuestion,
          bodyAr: p.vivaAnswer.isEmpty ? p.surgicalPearls : p.vivaAnswer,
          bodyEn: p.vivaAnswer.isEmpty ? p.surgicalPearls : p.vivaAnswer,
          status: 'review',
        ));
      }
    }
    pool.shuffle(Random());
    setState(() {
      _dailyQuizQuestions = pool.take(_dailyQuestionTarget).toList();
      _dailyQuizCurrentIdx = 0;
      _dailyQuizScore = 0;
      _dailyQuizShowAnswer = false;
    });
  }

  void _applyFilters() {
    _filteredPatients = _allPatients.where((p) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = p.name.toLowerCase().contains(q) ||
          p.mrn.toLowerCase().contains(q) ||
          p.diagnosis.toLowerCase().contains(q) ||
          p.hpi.toLowerCase().contains(q) ||
          p.plannedOperation.toLowerCase().contains(q) ||
          p.consultantName.toLowerCase().contains(q) ||
          p.rotation.toLowerCase().contains(q);

      if (!matchesSearch) return false;
      if (_selectedFilter == 'الكل') return true;
      if (_selectedFilter == 'مقررة') return p.operationStatus == 'مقررة';
      if (_selectedFilter == 'تمت العملية') return p.operationStatus == 'تمت العملية';
      if (_selectedFilter == 'بانتظار الزرع') return p.biopsyStatus.contains('بانتظار');
      if (_selectedFilter == 'امتحان') return p.isStarred;
      return true;
    }).toList();
  }

  void _showAppearanceAndLanguageSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isEn = _appLanguage == 'en';
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      isEn ? '🎨 Customize Colors, Backlight & Language' : '🎨 تخصيص الألوان، الإضاءة الخلفية، واللغة',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navyDark),
                    ),
                  ),
                  const Divider(height: 22),
                  Text(isEn ? '🌐 App & Study Language:' : '🌐 لغة التطبيق والأسئلة:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _choiceBtn('العربية 🇮🇶', _appLanguage == 'ar', () async {
                        await DatabaseHelper.instance.saveSetting('appLanguage', 'ar');
                        setState(() => _appLanguage = 'ar');
                        setSheetState(() {});
                      }),
                      const SizedBox(width: 8),
                      _choiceBtn('English 🇬🇧', _appLanguage == 'en', () async {
                        await DatabaseHelper.instance.saveSetting('appLanguage', 'en');
                        setState(() => _appLanguage = 'en');
                        setSheetState(() {});
                      }),
                      const SizedBox(width: 8),
                      _choiceBtn('کوردی ☀️', _appLanguage == 'ku', () async {
                        await DatabaseHelper.instance.saveSetting('appLanguage', 'ku');
                        setState(() => _appLanguage = 'ku');
                        setSheetState(() {});
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(isEn ? '💡 Background Lighting Mode:' : '💡 نمط الإضاءة الخلفية:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _choiceBtn(isEn ? '☀️ Daylight' : '☀️ نهاري مشرق', _lightingMode == 'light', () async {
                        await DatabaseHelper.instance.saveSetting('lightingMode', 'light');
                        setState(() => _lightingMode = 'light');
                        setSheetState(() {});
                      }),
                      const SizedBox(width: 8),
                      _choiceBtn(isEn ? '📖 Warm Read' : '📖 دافئ للقراءة', _lightingMode == 'warm', () async {
                        await DatabaseHelper.instance.saveSetting('lightingMode', 'warm');
                        setState(() => _lightingMode = 'warm');
                        setSheetState(() {});
                      }),
                      const SizedBox(width: 8),
                      _choiceBtn(isEn ? '🌙 Night Dark' : '🌙 ليلي داكن', _lightingMode == 'dark', () async {
                        await DatabaseHelper.instance.saveSetting('lightingMode', 'dark');
                        setState(() => _lightingMode = 'dark');
                        setSheetState(() {});
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.brightness_6_rounded, color: AppColors.navyPrimary, size: 20),
                      const SizedBox(width: 8),
                      Text(isEn ? 'Brightness:' : 'شدة الإضاءة:',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Expanded(
                        child: Slider(
                          value: _bgBrightness,
                          min: 0.45,
                          max: 1.0,
                          divisions: 11,
                          label: '${(_bgBrightness * 100).round()}%',
                          onChanged: (val) async {
                            setState(() => _bgBrightness = val);
                            setSheetState(() {});
                            await DatabaseHelper.instance.saveSetting('bgBrightness', val.toString());
                          },
                        ),
                      ),
                      Text('${(_bgBrightness * 100).round()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(isEn ? '🎨 Surgical Theme Color:' : '🎨 اللون الرئيسي للتطبيق:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _colorCircle('navy', isEn ? 'Royal Navy' : 'الكحلي الملكي', const Color(0xFF0D3562), setSheetState),
                      _colorCircle('emerald', isEn ? 'Surgical Green' : 'الأخضر الجراحي', const Color(0xFF005B4F), setSheetState),
                      _colorCircle('burgundy', isEn ? 'Burgundy' : 'العنابي الملكي', const Color(0xFF6B1D2F), setSheetState),
                      _colorCircle('indigo', isEn ? 'Academic Indigo' : 'البنفسجي العلمي', const Color(0xFF311B92), setSheetState),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _choiceBtn(String label, bool selected, VoidCallback onTap) {
    final primary = AppColors.getPrimaryColor(_themePalette);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? primary : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? primary : Colors.grey.shade300),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.navyDark,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _colorCircle(String key, String label, Color color, StateSetter setSheetState) {
    final isSelected = _themePalette == key;
    return GestureDetector(
      onTap: () async {
        await DatabaseHelper.instance.saveSetting('themePalette', key);
        setState(() => _themePalette = key);
        setSheetState(() {});
      },
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? Colors.amber : Colors.transparent, width: 3),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 22) : null,
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _performFirebaseUpload() async {
    final isEn = _appLanguage == 'en';
    final cleanUrl = FirebaseCloudService.normalizeFirebaseUrl(_firebaseDbUrl);
    setState(() {
      _firebaseDbUrl = cleanUrl;
      _isCloudSyncing = true;
    });
    await DatabaseHelper.instance.saveSetting('firebaseDbUrl', cleanUrl);

    try {
      final usedUrl = await FirebaseCloudService.uploadToFirebase(
        dbUrl: cleanUrl,
        userSecretKey: _firebaseSecretCode,
        patients: _allPatients,
        studyItems: _studyItems,
        doctorProfile: {
          'residentName': _residentName,
          'residentLevel': _residentLevel,
          'hospitalName': _hospitalName,
          'boardTargetP': _boardTargetP.toString(),
        },
      );
      final nowStr = DateTime.now().toString().substring(0, 16);
      await DatabaseHelper.instance.saveSetting('lastCloudSync', nowStr);
      await DatabaseHelper.instance.saveSetting('firebaseDbUrl', usedUrl);
      setState(() {
        _lastCloudSync = nowStr;
        _firebaseDbUrl = usedUrl;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statMintBorder,
            content: Text(
              isEn
                  ? '☁️ Successfully uploaded ${_allPatients.length} cases & ${_studyItems.length} study cards to Firebase!'
                  : '☁️ تم رفع ${_allPatients.length} حالة و ${_studyItems.length} بطاقة دراسية إلى سحابة Firebase بنجاح!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showFirebaseErrorHelpDialog(e.toString());
      }
    } finally {
      if (mounted) setState(() => _isCloudSyncing = false);
    }
  }

  Future<void> _performFirebaseRestore({required bool replaceExisting}) async {
    final isEn = _appLanguage == 'en';
    final cleanUrl = FirebaseCloudService.normalizeFirebaseUrl(_firebaseDbUrl);
    setState(() {
      _firebaseDbUrl = cleanUrl;
      _isCloudSyncing = true;
    });
    await DatabaseHelper.instance.saveSetting('firebaseDbUrl', cleanUrl);

    try {
      final count = await FirebaseCloudService.restoreFromFirebase(
        dbUrl: cleanUrl,
        userSecretKey: _firebaseSecretCode,
        replaceExisting: replaceExisting,
      );
      final nowStr = DateTime.now().toString().substring(0, 16);
      await DatabaseHelper.instance.saveSetting('lastCloudSync', nowStr);
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.navyPrimary,
            content: Text(
              count > 0
                  ? (isEn
                      ? '☁️ Restored $count cases & study bank from Firebase!'
                      : '☁️ تم استرجاع $count حالة وبطاقات الدراسة من سحابة Firebase بنجاح!')
                  : (isEn
                      ? 'No saved data found under this Secret Key in Firebase yet.'
                      : 'لا توجد بيانات محفوظة تحت هذا الرمز في Firebase حالياً.'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showFirebaseErrorHelpDialog(e.toString());
      }
    } finally {
      if (mounted) setState(() => _isCloudSyncing = false);
    }
  }

  void _showFirebaseErrorHelpDialog(String rawError) {
    final isEn = _appLanguage == 'en';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEn ? '⚠️ Cloud Connection Diagnostics' : '⚠️ تشخيص اتصال سحابة Firebase'),
        content: SingleChildScrollView(
          child: Text(
            isEn
                ? 'Error Details:\n$rawError\n\n'
                  'How to fix "Failed host lookup (errno = 7)" on Android:\n'
                  '1. Turn OFF your VPN app and check your Wi-Fi / Mobile Data.\n'
                  '2. In GitHub, open android/app/src/main/AndroidManifest.xml and make sure this line is right above <application:\n'
                  '<uses-permission android:name="android.permission.INTERNET"/>\n'
                  '3. In Firebase Console -> Realtime Database -> Rules, ensure read & write are set to true.'
                : 'تفاصيل الخطأ:\n$rawError\n\n'
                  'لحل مشكلة (Failed host lookup / errno = 7) في أندرويد:\n'
                  '1. أوقف تشغيل الـ VPN على هاتفك وتأكد من اتصال الإنترنت.\n'
                  '2. في GitHub افتح ملف android/app/src/main/AndroidManifest.xml وتأكد من وجود سطر إذن الإنترنت فوق <application:\n'
                  '<uses-permission android:name="android.permission.INTERNET"/>\n'
                  '3. في موقع Firebase -> Realtime Database -> Rules تأكد أن القراءة والكتابة مضبوطة على true.',
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEn ? 'OK' : 'حسناً')),
        ],
      ),
    );
  }

  void _showBackupMenu() {
    final isEn = _appLanguage == 'en';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEn ? '☁️ Firebase Cloud & Local Backup' : '☁️ الخزن السحابي (Firebase) والنسخ الاحتياطي',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navyDark),
              ),
              const SizedBox(height: 4),
              Text(
                isEn ? 'Last Cloud Sync: $_lastCloudSync' : 'آخر مزامنة سحابية: $_lastCloudSync',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              const Divider(height: 18),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.statBlueBg,
                  child: Icon(Icons.cloud_upload, color: AppColors.statBlueBorder),
                ),
                title: Text(
                  isEn ? 'Upload Data to Firebase Cloud Now' : 'رفع البيانات إلى سحابة Firebase الآن',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isEn
                      ? 'Save all (${_allPatients.length} cases + ${_studyItems.length} study cards) to cloud'
                      : 'حفظ جميع حالاتك (${_allPatients.length} مريض + ${_studyItems.length} كارت) في حسابك السحابي',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _performFirebaseUpload();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.statMintBg,
                  child: Icon(Icons.cloud_download, color: AppColors.statMintBorder),
                ),
                title: Text(
                  isEn ? 'Restore Data from Firebase Cloud' : 'استعادة البيانات من سحابة Firebase',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isEn ? 'Fetch your saved cases & cards from Firebase' : 'جلب بياناتك المحفوظة في Firebase إلى هاتفك',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCloudRestoreConfirmDialog();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.palette_outlined, color: AppColors.statAmberBorder),
                title: Text(
                  isEn
                      ? 'Customize Colors, Backlight & Language (AR / EN / KU)'
                      : 'تخصيص الألوان، الإضاءة الخلفية، واللغات (AR / EN / KU)',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAppearanceAndLanguageSheet();
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file, color: AppColors.navyPrimary),
                title: Text(isEn ? 'Export & Share Local Backup (JSON)' : 'تصدير ومشاركة ملف احتياطي محلي (JSON)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportBackupJson();
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_backup_restore, color: AppColors.statPurpleBorder),
                title: Text(isEn ? 'Restore from Copied JSON Text' : 'استعادة من نص كود (JSON) منسوخ'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showImportDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCloudRestoreConfirmDialog() {
    final isEn = _appLanguage == 'en';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEn ? 'Restore from Firebase Cloud' : 'استعادة من سحابة Firebase'),
        content: Text(
          isEn
              ? 'How would you like to restore from Firebase?\n\n'
                '• Replace All: Replaces current local data with the exact cloud backup.\n'
                '• Merge Cases: Adds cloud cases on top of current cases.'
              : 'كيف ترغب باستعادة الحالات من حسابك في Firebase؟\n\n'
                '• استبدال الكل: يمسح الموجود حالياً ويضع النسخة السحابية المطابقة.\n'
                '• دمج الحالات: يضيف الحالات السحابية فوق الحالات الموجودة.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEn ? 'Cancel' : 'إلغاء')),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performFirebaseRestore(replaceExisting: false);
            },
            child: Text(isEn ? 'Merge Cases' : 'دمج الحالات'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyPrimary, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _performFirebaseRestore(replaceExisting: true);
            },
            child: Text(isEn ? 'Replace All (Recommended)' : 'استبدال الكل (موصى به)'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackupJson() async {
    final list = _allPatients.map((e) => e.toMap()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(list);
    await Clipboard.setData(ClipboardData(text: jsonString));
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    await Printing.sharePdf(bytes: bytes, filename: 'surgical_board_backup.json');
  }

  void _showImportDialog() {
    final isEn = _appLanguage == 'en';
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEn ? 'Restore JSON Backup' : 'استعادة نسخة احتياطية (JSON)'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: isEn ? 'Paste backup JSON content here...' : 'الصق محتوى ملف الـ JSON الاحتياطي هنا...',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEn ? 'Cancel' : 'إلغاء')),
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
                  _loadAllData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEn ? 'Backup imported successfully!' : 'تم استيراد بيانات اللوكبوك والمرضى بنجاح')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isEn ? 'Invalid JSON format' : 'خطأ في صيغة الكود المنسوخ')),
                );
              }
            },
            child: Text(isEn ? 'Restore Now' : 'استعادة الآن'),
          ),
        ],
      ),
    );
  }

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

    final Map<String, OpCounter> opSummary = {};
    for (var p in list) {
      final opName = p.plannedOperation.trim().isEmpty ? 'غير محدد' : p.plannedOperation.trim();
      final counter = opSummary.putIfAbsent(opName, () => OpCounter());
      counter.total += 1;
      if (p.surgeonRole.startsWith('P')) {
        counter.p += 1;
      } else if (p.surgeonRole.startsWith('S')) {
        counter.s += 1;
      } else {
        counter.a += 1;
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
            decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF08203E), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('السجل الجراحي الرسمي والتقرير الإحصائي (Surgical Logbook Consolidation)',
                    style: pw.TextStyle(font: arabicBold, color: PdfColors.white, fontSize: 13)),
                pw.SizedBox(height: 4),
                pw.Text('الطبيب المقيم: $_residentName | $_residentLevel | $_hospitalName',
                    style: pw.TextStyle(font: arabicFont, color: PdfColors.white, fontSize: 10)),
                pw.Text('تاريخ التقرير: ${DateTime.now().toString().split(' ').first} | إجمالي الحالات: $total',
                    style: pw.TextStyle(font: arabicFont, color: PdfColors.grey300, fontSize: 9.5)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text('أولاً: خلاصة الأدوار الجراحية والتصنيف (Summary by Role & Urgency)',
              style: pw.TextStyle(font: arabicBold, fontSize: 11.5)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue50),
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
          pw.SizedBox(height: 12),
          pw.Text('ثانياً: التجميع الإحصائي حسب نوع العملية (Consolidation by Procedure)',
              style: pw.TextStyle(font: arabicBold, fontSize: 11.5)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue50),
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
                    _pdfCell('${entry.value.a}', arabicFont),
                    _pdfCell('${entry.value.s}', arabicFont),
                    _pdfCell('${entry.value.p}', arabicFont),
                    _pdfCell('${entry.value.total}', arabicBold),
                    _pdfCell(entry.key, arabicFont),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text('ثالثاً: السجل التفصيلي للحالات (Detailed Case Log)',
              style: pw.TextStyle(font: arabicBold, fontSize: 11.5)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                children: [
                  _pdfCell('النتيجة', arabicBold),
                  _pdfCell('المشرف', arabicBold),
                  _pdfCell('الدور / الحجم', arabicBold),
                  _pdfCell('العملية والتشخيص', arabicBold),
                  _pdfCell('المريض', arabicBold),
                  _pdfCell('التاريخ', arabicBold),
                ],
              ),
              ...list.map((p) {
                final shortRole = p.surgeonRole.split(' ').first;
                final shortMag = p.operationMagnitude.split(' ').first;
                return pw.TableRow(
                  children: [
                    _pdfCell(p.finalOutcome, arabicFont),
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
          pw.SizedBox(height: 22),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('توقيع الاستشاري المشرف: ___________________',
                  style: pw.TextStyle(font: arabicBold, fontSize: 10.5)),
              pw.Text('توقيع الطبيب المقيم ($_residentName): ___________________',
                  style: pw.TextStyle(font: arabicBold, fontSize: 10.5)),
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
        style: pw.TextStyle(font: font, fontSize: 8.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = _appLanguage != 'en';
    final bgColor = AppColors.getBackgroundColor(_lightingMode);
    final dimOverlayOpacity = (1.0 - _bgBrightness).clamp(0.0, 0.55);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: bgColor,
            body: SafeArea(
              child: Column(
                children: [
                  _buildTopSurgicalHeader(),
                  if (_isCloudSyncing)
                    const LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: AppColors.statBlueBg,
                      color: AppColors.statMintBorder,
                    ),
                  Expanded(
                    child: IndexedStack(
                      index: _currentTabIndex,
                      children: [
                        _buildMainDashboardTab(),
                        _buildStudyAndVivaHubTab(),
                        _buildCasesByRotationTab(),
                        _buildStatisticsAnalyticsTab(),
                        _buildSettingsProfileTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: _buildCustomBottomNavBar(),
          ),
          if (dimOverlayOpacity > 0.01)
            IgnorePointer(
              child: Container(
                color: Colors.black.withOpacity(dimOverlayOpacity),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopSurgicalHeader() {
    final primary = AppColors.getPrimaryColor(_themePalette);
    final darkHeader = AppColors.getDarkHeaderColor(_themePalette);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            darkHeader,
            primary,
            primary.withOpacity(0.88),
          ],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _showAppearanceAndLanguageSheet,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          L10n.t('appTitle', _appLanguage),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.brightness_6_rounded, color: Colors.amberAccent, size: 18),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 20,
                    width: 170,
                    child: CustomPaint(painter: EcgWavePainter()),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 46,
            width: 1.5,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white38,
          ),
          _buildHeaderSquareButton(
            label: L10n.t('seminar', _appLanguage),
            iconWidget: Icon(
              _isAnonymized ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.white,
              size: 22,
            ),
            onTap: () {
              setState(() => _isAnonymized = !_isAnonymized);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isAnonymized
                      ? (_appLanguage == 'en' ? 'Seminar Mode ON: Patient names hidden' : 'وضع السيمينار مفعّل: تم إخفاء أسماء المرضى')
                      : (_appLanguage == 'en' ? 'Patient real names shown' : 'تم إظهار الأسماء الحقيقية للمرضى')),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          _buildHeaderSquareButton(
            label: L10n.t('logbookPdf', _appLanguage),
            iconWidget: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'PDF',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            onTap: _generateLogbookConsolidationPdf,
          ),
          const SizedBox(width: 6),
          _buildHeaderSquareButton(
            label: L10n.t('backup', _appLanguage),
            iconWidget: const Icon(Icons.copy_all_rounded, color: Colors.white, size: 22),
            onTap: _showBackupMenu,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSquareButton({
    required String label,
    required Widget iconWidget,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 62,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 24, child: Center(child: iconWidget)),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainDashboardTab() {
    final totalCount = _allPatients.length;
    final primarySurgeonCount = _allPatients
        .where((p) => p.surgeonRole.startsWith('P') || p.surgeonRole.startsWith('S'))
        .length;
    final pendingBiopsyCount = _allPatients.where((p) => p.biopsyStatus.contains('بانتظار')).length;
    final starredCount = _allPatients.where((p) => p.isStarred).length;
    final primaryColor = AppColors.getPrimaryColor(_themePalette);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            children: [
              Row(
                children: [
                  _buildColoredStatCard(
                    count: totalCount.toString(),
                    label: L10n.t('cases', _appLanguage),
                    bgColor: AppColors.statPurpleBg,
                    bottomBorderColor: AppColors.statPurpleBorder,
                    icon: Icons.groups_rounded,
                    iconColor: AppColors.statPurpleBorder,
                    onTap: () => setState(() {
                      _selectedFilter = 'الكل';
                      _applyFilters();
                    }),
                  ),
                  const SizedBox(width: 8),
                  _buildColoredStatCard(
                    count: primarySurgeonCount.toString(),
                    label: L10n.t('surgeonPS', _appLanguage),
                    bgColor: AppColors.statBlueBg,
                    bottomBorderColor: AppColors.statBlueBorder,
                    icon: Icons.colorize_rounded,
                    iconColor: AppColors.statBlueBorder,
                    onTap: () => setState(() {
                      _selectedFilter = 'الكل';
                      _applyFilters();
                    }),
                  ),
                  const SizedBox(width: 8),
                  _buildColoredStatCard(
                    count: pendingBiopsyCount.toString(),
                    label: L10n.t('biopsy', _appLanguage),
                    bgColor: AppColors.statMintBg,
                    bottomBorderColor: AppColors.statMintBorder,
                    icon: Icons.biotech_rounded,
                    iconColor: const Color(0xFF1F4E5B),
                    onTap: () => setState(() {
                      _selectedFilter = 'بانتظار الزرع';
                      _applyFilters();
                    }),
                  ),
                  const SizedBox(width: 8),
                  _buildColoredStatCard(
                    count: starredCount.toString(),
                    label: L10n.t('exam', _appLanguage),
                    bgColor: AppColors.statAmberBg,
                    bottomBorderColor: AppColors.statAmberBorder,
                    icon: Icons.star_rounded,
                    iconColor: AppColors.statAmberBorder,
                    onTap: () => setState(() {
                      _selectedFilter = 'امتحان';
                      _applyFilters();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.getCardColor(_lightingMode),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.blueGrey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  style: TextStyle(color: AppColors.getTextColor(_lightingMode)),
                  decoration: InputDecoration(
                    hintText: L10n.t('searchHint', _appLanguage),
                    hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13.5),
                    prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 24),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _applyFilters();
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterPill(
                      filterKey: 'الكل',
                      displayLabel: L10n.t('all', _appLanguage),
                      icon: Icons.grid_view_rounded,
                      iconColor: _selectedFilter == 'الكل' ? Colors.white : primaryColor,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      filterKey: 'مقررة',
                      displayLabel: L10n.t('scheduled', _appLanguage),
                      icon: Icons.calendar_month_rounded,
                      iconColor: _selectedFilter == 'مقررة' ? Colors.white : primaryColor,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      filterKey: 'تمت العملية',
                      displayLabel: L10n.t('completed', _appLanguage),
                      icon: Icons.check_circle_rounded,
                      iconColor: _selectedFilter == 'تمت العملية' ? Colors.white : const Color(0xFF00A86B),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      filterKey: 'بانتظار الزرع',
                      displayLabel: L10n.t('pendingBiopsy', _appLanguage),
                      icon: Icons.biotech_rounded,
                      iconColor: _selectedFilter == 'بانتظار الزرع' ? Colors.white : AppColors.statPurpleBorder,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      filterKey: 'امتحان',
                      displayLabel: L10n.t('exam', _appLanguage),
                      icon: Icons.star_rounded,
                      iconColor: _selectedFilter == 'امتحان' ? Colors.white : AppColors.statAmberBorder,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_filteredPatients.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.getCardColor(_lightingMode),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.medical_services_outlined, size: 56, color: Colors.blueGrey.shade200),
                      const SizedBox(height: 10),
                      Text(
                        _appLanguage == 'en'
                            ? 'No patient cases recorded in this filter yet.\nTap "+ Add New Case" below to start.'
                            : 'لا توجد حالات مسجلة ضمن هذا التصنيف حالياً\nاضغط على زر "إضافة حالة جديدة" بالأسفل للبدء',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.blueGrey, fontSize: 14.5),
                      ),
                    ],
                  ),
                )
              else
                ..._filteredPatients.map((patient) => _buildSurgicalPatientCard(patient)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              Expanded(child: Container(height: 1.2, color: Colors.blueGrey.shade200)),
              const SizedBox(width: 12),
              InkWell(
                borderRadius: BorderRadius.circular(32),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PatientFormScreen(appLanguage: _appLanguage)),
                  );
                  _loadAllData();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.getDarkHeaderColor(_themePalette), primaryColor],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add, color: primaryColor, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        L10n.t('addNewCase', _appLanguage),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 1.2, color: Colors.blueGrey.shade200)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColoredStatCard({
    required String count,
    required String label,
    required Color bgColor,
    required Color bottomBorderColor,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              bottom: BorderSide(color: bottomBorderColor, width: 4.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(height: 4),
              Text(
                count,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navyDark,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String filterKey,
    required String displayLabel,
    required IconData icon,
    required Color iconColor,
  }) {
    final isSelected = _selectedFilter == filterKey;
    final primary = AppColors.getPrimaryColor(_themePalette);
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterKey;
          _applyFilters();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primary : AppColors.getCardColor(_lightingMode),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? primary : Colors.blueGrey.shade100,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: primary.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: iconColor),
            const SizedBox(width: 6),
            Text(
              displayLabel,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.getTextColor(_lightingMode),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurgicalPatientCard(PatientRecord patient) {
    final totalPhotos = patient.radiologyImages.length +
        patient.labImages.length +
        patient.woundImages.length +
        patient.biopsyImages.length;
    final shortRole = patient.surgeonRole.split(' ').first;
    final shortMag = patient.operationMagnitude.split(' ').first;
    final primary = AppColors.getPrimaryColor(_themePalette);
    final textColor = AppColors.getTextColor(_lightingMode);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(_lightingMode),
        borderRadius: BorderRadius.circular(20),
        border: Border(
          right: BorderSide(color: primary, width: 5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PatientDetailsScreen(
                patientId: patient.id!,
                isAnonymized: _isAnonymized,
                appLanguage: _appLanguage,
              ),
            ),
          );
          _loadAllData();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusGreenBadge(patient.operationStatus),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            patient.displayName(_isAnonymized, _appLanguage),
                            style: TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (patient.isStarred) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 22),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.roleBadgeBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '( $shortRole )',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: AppColors.navyDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '${patient.rotation}   |   Dr. ${patient.consultantName.isEmpty ? "-" : patient.consultantName}   |   ${patient.bloodGroup}',
                  style: TextStyle(
                    color: textColor.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: Colors.blueGrey.shade100),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.medical_information_outlined, size: 19, color: primary),
                  const SizedBox(width: 6),
                  Text(
                    L10n.t('diagnosis', _appLanguage),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${patient.diagnosis} (${patient.chiefComplaint})',
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (patient.hpi.trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.subject_rounded, size: 18, color: Colors.teal.shade700),
                    const SizedBox(width: 6),
                    Text(
                      L10n.t('hpiShort', _appLanguage),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.teal.shade700,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        patient.hpi,
                        style: TextStyle(
                          fontSize: 13,
                          color: textColor.withOpacity(0.85),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.colorize_rounded, size: 19, color: primary),
                  const SizedBox(width: 6),
                  Text(
                    L10n.t('operation', _appLanguage),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${patient.plannedOperation} [$shortMag]',
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildBottomCardPill(
                      text: patient.finalOutcome,
                      icon: Icons.monitor_heart_rounded,
                      bgColor: AppColors.pillGreenBg,
                      textColor: AppColors.pillGreenText,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildBottomCardPill(
                      text: patient.biopsyStatus.contains('بانتظار')
                          ? (_appLanguage == 'en' ? 'Pending Biopsy' : 'بانتظار الزرع')
                          : (patient.biopsyStatus.contains('ظهرت')
                              ? (_appLanguage == 'en' ? 'Completed' : 'ظهرت النتيجة')
                              : (_appLanguage == 'en' ? 'No Biopsy' : 'لا يحتاج زرع')),
                      icon: Icons.biotech_rounded,
                      bgColor: AppColors.pillOrangeBg,
                      textColor: AppColors.pillOrangeText,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildBottomCardPill(
                      text: '$totalPhotos ${L10n.t("photosAttached", _appLanguage)}',
                      icon: Icons.photo_library_outlined,
                      bgColor: AppColors.pillPurpleBg,
                      textColor: AppColors.pillPurpleText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusGreenBadge(String status) {
    Color bg = AppColors.pillGreenBg;
    Color fg = const Color(0xFF00875A);
    IconData ic = Icons.check_circle_rounded;

    if (status == 'مقررة') {
      bg = AppColors.statAmberBg;
      fg = const Color(0xFFB45309);
      ic = Icons.schedule_rounded;
    } else if (status == 'مؤجلة') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      ic = Icons.pause_circle_filled_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, size: 16, color: fg),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCardPill({
    required String text,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: textColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // التبويب الثاني: ركن الدراسة والـ Bailey 28th والفلاش كارت والسلايدات وقارئ الكتب PDF
  // ==========================================
  Widget _buildStudyAndVivaHubTab() {
    final primary = AppColors.getPrimaryColor(_themePalette);
    final flashcards = _studyItems.where((e) => e.itemType == 'flashcard' || e.itemType == 'book_qa').toList();
    final slides = _studyItems.where((e) => e.itemType == 'slide').toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStudySubTabChip(0, '🃏 ${L10n.t("tabFlashcards", _appLanguage)} (${flashcards.length})', Icons.style_outlined),
                const SizedBox(width: 8),
                _buildStudySubTabChip(1, '🎞️ ${L10n.t("tabSlides", _appLanguage)} (${slides.length})', Icons.slideshow_rounded),
                const SizedBox(width: 8),
                _buildStudySubTabChip(2, '🎯 ${L10n.t("tabDailyQuiz", _appLanguage)} ($_dailyQuestionTarget)', Icons.quiz_outlined),
                const SizedBox(width: 8),
                _buildStudySubTabChip(3, '📖 ${L10n.t("tabBookReader", _appLanguage)}', Icons.picture_as_pdf_rounded),
                const SizedBox(width: 8),
                _buildStudySubTabChip(4, '🩺 ${L10n.t("tabOsce", _appLanguage)}', Icons.medical_services_outlined),
              ],
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _studySubTabIndex,
            children: [
              _buildFlashcardsSubView(flashcards, primary),
              _buildSlidesCarouselSubView(slides, primary),
              _buildDailyQuizSubView(primary),
              _buildBookReaderExtractorSubView(primary),
              _buildOsceSimulatorSubView(primary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudySubTabChip(int index, String label, IconData icon) {
    final isSelected = _studySubTabIndex == index;
    final primary = AppColors.getPrimaryColor(_themePalette);
    return GestureDetector(
      onTap: () => setState(() => _studySubTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? primary : AppColors.getCardColor(_lightingMode),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isSelected ? primary : Colors.blueGrey.shade100),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: isSelected ? Colors.white : primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.getTextColor(_lightingMode),
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashcardsSubView(List<StudyItem> flashcards, Color primary) {
    final isEn = _appLanguage == 'en';
    final masteredCount = flashcards.where((e) => e.status == 'mastered').length;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.statPurpleBg, borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Bailey & Love 28th Flashcards & My Cards' : 'بطاقات Bailey & Love 28th وكارتاتي الخاصة',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navyDark),
                    ),
                    Text(
                      isEn ? 'Mastered: $masteredCount of ${flashcards.length} cards' : 'المتقن: $masteredCount من أصل ${flashcards.length} بطاقة',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.statPurpleBorder),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.statPurpleBorder, foregroundColor: Colors.white),
                onPressed: () => _showAddCustomCardOrSlideDialog('flashcard'),
                icon: const Icon(Icons.add, size: 18),
                label: Text(L10n.t('addCard', _appLanguage)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...flashcards.map((item) => _FlashcardInteractiveWidget(
              item: item,
              lang: _appLanguage,
              cardBgColor: AppColors.getCardColor(_lightingMode),
              textColor: AppColors.getTextColor(_lightingMode),
              onStatusToggle: (newStatus) async {
                final updated = StudyItem(
                  id: item.id,
                  itemType: item.itemType,
                  categoryAr: item.categoryAr,
                  categoryEn: item.categoryEn,
                  titleAr: item.titleAr,
                  titleEn: item.titleEn,
                  bodyAr: item.bodyAr,
                  bodyEn: item.bodyEn,
                  status: newStatus,
                );
                await DatabaseHelper.instance.updateStudyItem(updated);
                _loadAllData();
              },
              onDelete: () async {
                if (item.id != null) {
                  await DatabaseHelper.instance.deleteStudyItem(item.id!);
                  _loadAllData();
                }
              },
            )),
      ],
    );
  }

  Widget _buildSlidesCarouselSubView(List<StudyItem> slides, Color primary) {
    final isEn = _appLanguage == 'en';
    if (slides.isEmpty) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: () => _showAddCustomCardOrSlideDialog('slide'),
          icon: const Icon(Icons.add),
          label: Text(isEn ? 'Add First Surgical Slide' : 'إضافة أول سلايد جراحي'),
        ),
      );
    }

    final safeIdx = _currentSlideIndex.clamp(0, slides.length - 1);
    final currentSlide = slides[safeIdx];

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isEn ? '🎞️ Slide ${safeIdx + 1} of ${slides.length}' : '🎞️ سلايد ${safeIdx + 1} من أصل ${slides.length}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.getTextColor(_lightingMode)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
              onPressed: () => _showAddCustomCardOrSlideDialog('slide'),
              icon: const Icon(Icons.add, size: 18),
              label: Text(isEn ? 'New Slide' : 'إضافة سلايد'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.getDarkHeaderColor(_themePalette), primary],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: Colors.amberAccent, borderRadius: BorderRadius.circular(14)),
                child: Text(
                  currentSlide.getCategory(_appLanguage),
                  style: const TextStyle(color: AppColors.navyDark, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                currentSlide.getTitle(_appLanguage),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(color: Colors.white30, height: 24),
              Text(
                currentSlide.getBody(_appLanguage),
                style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: safeIdx > 0 ? () => setState(() => _currentSlideIndex = safeIdx - 1) : null,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
              label: Text(isEn ? 'Previous Slide' : 'السلايد السابق'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () async {
                if (currentSlide.id != null) {
                  await DatabaseHelper.instance.deleteStudyItem(currentSlide.id!);
                  setState(() => _currentSlideIndex = 0);
                  _loadAllData();
                }
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
              onPressed: safeIdx < slides.length - 1 ? () => setState(() => _currentSlideIndex = safeIdx + 1) : null,
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              label: Text(isEn ? 'Next Slide' : 'السلايد التالي'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDailyQuizSubView(Color primary) {
    final isEn = _appLanguage == 'en';
    final cardColor = AppColors.getCardColor(_lightingMode);
    final textColor = AppColors.getTextColor(_lightingMode);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.statBlueBg, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    L10n.t('dailyTarget', _appLanguage),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navyDark),
                  ),
                  Wrap(
                    spacing: 6,
                    children: [3, 5, 10, 15, 20].map((numQ) {
                      final isSel = _dailyQuestionTarget == numQ;
                      return ChoiceChip(
                        label: Text('$numQ'),
                        selected: isSel,
                        onSelected: (_) async {
                          await DatabaseHelper.instance.saveSetting('dailyQuestionTarget', numQ.toString());
                          setState(() => _dailyQuestionTarget = numQ);
                          _generateDailyQuizBatch();
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                  onPressed: _generateDailyQuizBatch,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(L10n.t('startDailyQuiz', _appLanguage)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_dailyQuizQuestions.isEmpty)
          const Center(child: Text('No questions available'))
        else if (_dailyQuizCurrentIdx >= _dailyQuizQuestions.length)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 64),
                const SizedBox(height: 10),
                Text(
                  isEn
                      ? 'Daily Target Completed! Score: $_dailyQuizScore / ${_dailyQuizQuestions.length}'
                      : 'أتممت ورد الأسئلة اليومي بنجاح! نتيجتك: $_dailyQuizScore من ${_dailyQuizQuestions.length}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _generateDailyQuizBatch,
                  child: Text(isEn ? 'Start Another Round' : 'بدء جولة يومية جديدة'),
                ),
              ],
            ),
          )
        else ...[
          Builder(builder: (ctx) {
            final qItem = _dailyQuizQuestions[_dailyQuizCurrentIdx];
            return Card(
              color: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Chip(
                            label: Text(qItem.getCategory(_appLanguage), style: const TextStyle(fontSize: 11.5)),
                            backgroundColor: AppColors.statPurpleBg,
                          ),
                        ),
                        Text(
                          '${_dailyQuizCurrentIdx + 1} / ${_dailyQuizQuestions.length}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '❓ ${qItem.getTitle(_appLanguage)}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 16),
                    if (!_dailyQuizShowAnswer)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.statAmberBorder, foregroundColor: Colors.white),
                          onPressed: () => setState(() => _dailyQuizShowAnswer = true),
                          icon: const Icon(Icons.visibility),
                          label: Text(isEn ? 'Show Model Answer' : 'إظهار الجواب النموذجي'),
                        ),
                      )
                    else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.pillGreenBg, borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          qItem.getBody(_appLanguage),
                          style: const TextStyle(fontSize: 14, color: AppColors.navyDark, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => setState(() {
                                _dailyQuizCurrentIdx++;
                                _dailyQuizShowAnswer = false;
                              }),
                              icon: const Icon(Icons.close, color: Colors.red),
                              label: Text(isEn ? 'Missed It' : 'أحتاج مراجعتها'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.statMintBorder, foregroundColor: Colors.white),
                              onPressed: () => setState(() {
                                _dailyQuizScore++;
                                _dailyQuizCurrentIdx++;
                                _dailyQuizShowAnswer = false;
                              }),
                              icon: const Icon(Icons.check),
                              label: Text(isEn ? 'Got It Right (+1)' : 'أجبتها بشكل صحيح (+1)'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  // 4. قارئ ملفات الـ PDF والكتب من الهاتف + مكتبة فصول Bailey & Love 28th
  Widget _buildBookReaderExtractorSubView(Color primary) {
    final isEn = _appLanguage == 'en';
    final cardColor = AppColors.getCardColor(_lightingMode);
    final textColor = AppColors.getTextColor(_lightingMode);
    final presets = PdfAndBookExtractorService.getBailey28BuiltInChapters();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.statMintBg, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEn
                    ? '📖 Load PDF / Book File from Phone & Auto-Extract Q&A'
                    : '📖 تحميل ملف PDF أو كتاب من الهاتف واستخراج أسئلة وأجوبة وسلايدات',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.navyDark),
              ),
              const SizedBox(height: 4),
              Text(
                isEn
                    ? '1. Tap "Browse Phone PDF / Book Files" to scan your phone for PDF/TXT files and extract text.\n'
                      '2. Or tap any built-in Bailey & Love 28th chapter below to instantly generate bilingual Q&A cards & slides!'
                    : '1. اضغط على زر (تصفح وتحميل ملف PDF أو كتاب من الهاتف) لقراءة ملفات الـ PDF والنصوص من ذاكرة هاتفك.\n'
                      '2. أو اختر أياً من فصول Bailey & Love 28th المدمجة بالأسفل لتوليد أسئلة وسلايدات الفصل فوراً!',
                style: const TextStyle(fontSize: 12, color: AppColors.pillGreenText, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // أزرار استعراض ملفات الـ PDF من الهاتف + مكتبة فصول Bailey 28th
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _openPhonePdfScannerSheet,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: Text(
                    isEn
                        ? '📂 Browse & Load PDF / TXT Book File from Phone'
                        : '📂 تصفح وتحميل ملف PDF أو TXT من ذاكرة الهاتف',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isEn
                    ? '⚡ Built-in Bailey & Love 28th High-Yield Chapters (Tap to Load & Extract):'
                    : '⚡ فصول Bailey & Love 28th الجاهزة (اضغط لتحميل الفصل واستخراج أسئلته):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: presets.map((ch) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ActionChip(
                        backgroundColor: AppColors.statBlueBg,
                        avatar: const Icon(Icons.menu_book_rounded, size: 16, color: AppColors.navyPrimary),
                        label: Text(
                          isEn ? ch.chapterTitleEn : ch.chapterTitleAr,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navyDark),
                        ),
                        onPressed: () {
                          setState(() {
                            _bookTopicCtrl.text = isEn ? ch.chapterTitleEn : ch.chapterTitleAr;
                            _bookRawTextCtrl.text = isEn ? ch.contentEn : ch.contentAr;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEn
                                    ? 'Chapter loaded! Tap "Extract Q&A Cards Automatically" below.'
                                    : 'تم تحميل الفصل! اضغط الآن على زر "استخراج أسئلة وكارتات تلقائياً" بالأسفل.',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 22),
              TextField(
                controller: _bookTopicCtrl,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: isEn ? 'Chapter / Book Topic Name' : 'اسم الفصل أو الكتاب (مثال: Acute Pancreatitis - Bailey 28th)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bookFilePathCtrl,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: isEn
                            ? 'Direct File Path (/sdcard/Download/book.pdf)'
                            : 'مسار ملف الـ PDF أو النص في الهاتف (/sdcard/Download/file.pdf)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _loadFileFromPath(_bookFilePathCtrl.text.trim()),
                    icon: const Icon(Icons.file_open_rounded),
                    label: Text(isEn ? 'Load File' : 'قراءة الملف'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bookRawTextCtrl,
                maxLines: 7,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: isEn
                      ? 'Extracted PDF Text / Paste Chapter Text Here...'
                      : 'النص المستخرج من ملف الـ PDF أو الفصل المنسوخ يظهر هنا...',
                  border: const OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  isEn
                      ? 'Also generate a Summary Slide in Slides Tab'
                      : 'إنشاء سلايد ملخص شامل أيضاً في قسم السلايدات العلمية',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                ),
                value: _alsoCreateSlideFromBook,
                onChanged: (v) => setState(() => _alsoCreateSlideFromBook = v),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        setState(() => _bookRawTextCtrl.text = data!.text!);
                      }
                    },
                    icon: const Icon(Icons.paste_rounded, size: 18),
                    label: Text(isEn ? 'Paste Clipboard' : 'لصق من الحافظة'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statMintBorder,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _extractQuestionsFromBookText(
                        _bookTopicCtrl.text.trim(),
                        _bookRawTextCtrl.text.trim(),
                      ),
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(
                        isEn ? 'Extract Q&A Cards Automatically' : 'استخراج أسئلة وكارتات تلقائياً',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openPhonePdfScannerSheet() async {
    final isEn = _appLanguage == 'en';
    final files = await PdfAndBookExtractorService.scanPhoneForBookFiles();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEn
                    ? '📂 PDF & Book Files Found on Phone (${files.length})'
                    : '📂 ملفات الـ PDF والكتب الموجودة في الهاتف (${files.length})',
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.navyDark),
              ),
              const SizedBox(height: 4),
              Text(
                isEn
                    ? 'Tap any PDF or TXT file from your Download/Documents folder to extract its text and generate questions:'
                    : 'اضغط على أي ملف PDF أو TXT في مجلد التنزيلات أو المستندات لاستخراج النصوص وتوليد الأسئلة منه:',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              const Divider(),
              if (files.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    isEn
                        ? 'No .pdf or .txt files were automatically listed due to Android storage privacy. You can type the file path directly or copy text from your PDF reader app (Xodo) and tap "Paste Clipboard"!'
                        : 'لم يتمكن النظام من عرض قائمة الملفات تلقائياً بسبب صلاحيات الخصوصية في أندرويد الحديث؛ يمكنك كتابة مسار الملف يدوياً أو نسخ النص من تطبيق قارئ الـ PDF لديك (مثل Xodo) والضغط على زر "لصق من الحافظة" ليتم توليد الأسئلة فوراً!',
                    style: const TextStyle(fontSize: 13, color: AppColors.navyDark),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: files.length,
                    itemBuilder: (ctx, i) {
                      final f = files[i];
                      final name = p.basename(f.path);
                      final isPdf = name.toLowerCase().endsWith('.pdf');
                      return ListTile(
                        leading: Icon(
                          isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                          color: isPdf ? Colors.red : AppColors.navyPrimary,
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        subtitle: Text(f.path, style: const TextStyle(fontSize: 11)),
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _bookFilePathCtrl.text = f.path;
                            _bookTopicCtrl.text = name.replaceAll('.pdf', '').replaceAll('.txt', '');
                          });
                          _loadFileFromPath(f.path);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadFileFromPath(String path) async {
    final isEn = _appLanguage == 'en';
    if (path.isEmpty) return;
    try {
      final f = File(path);
      if (!await f.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEn ? 'File not found at: $path' : 'لم يتم العثور على الملف في المسار: $path')),
          );
        }
        return;
      }

      final extracted = await PdfAndBookExtractorService.extractTextFromPdfOrTxtFile(f);
      if (extracted.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEn
                    ? 'This PDF appears to be scanned images or encrypted. Copy text from Xodo PDF reader and tap Paste Clipboard!'
                    : 'هذا الـ PDF يبدو أنه مصور كصور (Scanned) أو مشفر؛ افتحه بتطبيق Xodo وانسخ الفقرة المطلوبة ثم اضغط "لصق من الحافظة"!',
              ),
            ),
          );
        }
        return;
      }

      setState(() {
        _bookRawTextCtrl.text = extracted;
        _bookTopicCtrl.text = p.basenameWithoutExtension(f.path);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statMintBorder,
            content: Text(
              isEn
                  ? '✅ File loaded! Tap "Extract Q&A Cards Automatically" to generate questions.'
                  : '✅ تم استخراج النص من ملف الـ PDF بنجاح! اضغط الآن على "استخراج أسئلة وكارتات تلقائياً".',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _extractQuestionsFromBookText(String topic, String rawText) async {
    final isEn = _appLanguage == 'en';
    if (rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn
                ? 'Please load a PDF/Book file, select a Bailey chapter, or paste text first!'
                : 'يرجى اختيار فصل من فصول Bailey أعلاه أو تحميل ملف PDF أو لصق نص أولاً!',
          ),
        ),
      );
      return;
    }

    final safeTopic = topic.isEmpty ? 'Bailey & Love 28th Note' : topic;

    final blocks = rawText
        .split(RegExp(r'(\n\s*\n|\n(?=[•\-\d]+\.)|(?<=\.)\s+(?=[A-Zأ-ي]))'))
        .map((s) => s.trim())
        .where((s) => s.length > 30)
        .toList();

    if (blocks.isEmpty && rawText.length > 15) {
      blocks.add(rawText);
    }

    int createdCount = 0;
    final slideBullets = <String>[];

    for (int i = 0; i < blocks.length && i < 18; i++) {
      final chunk = blocks[i];
      String qAr = 'ما هي النقاط الجراحية الأساسية حول ($safeTopic - نقطة ${i + 1})؟';
      String qEn = 'What are the key surgical pearls regarding ($safeTopic - Point ${i + 1})?';

      if (chunk.contains(':')) {
        final parts = chunk.split(':');
        final head = parts.first.trim();
        if (head.length > 3 && head.length < 100) {
          qAr = 'وضّح بالتفصيل الجراحي: $head ($safeTopic)؟';
          qEn = 'Explain in surgical detail: $head ($safeTopic)?';
        }
      }

      await DatabaseHelper.instance.insertStudyItem(
        StudyItem(
          itemType: 'flashcard',
          categoryAr: '📖 $safeTopic',
          categoryEn: '📖 $safeTopic',
          titleAr: qAr,
          titleEn: qEn,
          bodyAr: chunk,
          bodyEn: chunk,
          status: 'review',
        ),
      );
      slideBullets.add('• $chunk');
      createdCount++;
    }

    if (_alsoCreateSlideFromBook && slideBullets.isNotEmpty) {
      await DatabaseHelper.instance.insertStudyItem(
        StudyItem(
          itemType: 'slide',
          categoryAr: '🎞️ ملخص كتاب: $safeTopic',
          categoryEn: '🎞️ Book Slide: $safeTopic',
          titleAr: 'ملخص النقاط الجراحية: $safeTopic',
          titleEn: 'Surgical Summary Slide: $safeTopic',
          bodyAr: slideBullets.take(6).join('\n\n'),
          bodyEn: slideBullets.take(6).join('\n\n'),
          status: 'review',
        ),
      );
    }

    await _loadAllData();
    _generateDailyQuizBatch();
    setState(() => _studySubTabIndex = 0);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statMintBorder,
          content: Text(
            isEn
                ? '✨ Generated $createdCount Q&A Flashcards & Summary Slide from "$safeTopic"!'
                : '✨ تم استخراج وتوليد $createdCount سؤال وجواب (فلاش كارت) مع سلايد ملخص من "$safeTopic" بنجاح!',
          ),
        ),
      );
    }
  }

  Widget _buildOsceSimulatorSubView(Color primary) {
    final isEn = _appLanguage == 'en';
    if (_allPatients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            isEn
                ? 'Add at least 1 patient case in the app to run the interactive OSCE Simulator from your real cases.'
                : 'أضف حالة مريض واحدة على الأقل في التطبيق ليعمل محاكي الـ OSCE التفاعلي من حالاتك الحقيقية.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blueGrey),
          ),
        ),
      );
    }

    final p = _osceCurrentPatient ?? _allPatients.first;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.statBlueBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? '🩺 OSCE & Clinical Viva Simulator' : '🩺 محاكي الـ OSCE والـ Viva السريري',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navyDark),
                    ),
                    Text(
                      isEn
                          ? 'Review the clinical presentation and guess the diagnosis & procedure before revealing'
                          : 'اقرأ معطيات المريض وحاول معرفة التشخيص والعملية قبل كشف الجواب',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.navyPrimary),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                onPressed: () {
                  final rnd = Random();
                  setState(() {
                    _osceCurrentPatient = _allPatients[rnd.nextInt(_allPatients.length)];
                    _osceRevealAnswer = false;
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(isEn ? 'Random Case' : 'حالة عشوائية'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: AppColors.getCardColor(_lightingMode),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p.gender}, ${p.age}y — ${p.rotation}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primary),
                ),
                const Divider(height: 20),
                _osceLine(isEn ? 'Chief Complaint:' : 'الشكوى الرئيسية (Chief Complaint):', p.chiefComplaint),
                _osceLine(isEn ? 'History of Present Illness (HPI):' : 'القصة المرضية التفصيلية (HPI):', p.hpi),
                _osceLine(isEn ? 'Past Medical & Surgical History:' : 'التاريخ المرضي والجراحي:', '${p.chronicDiseases} | ${p.pastSurgeries}'),
                _osceLine(isEn ? 'Clinical Examination:' : 'الفحص السريري (Clinical Exam):', p.clinicalExam),
                _osceLine(isEn ? 'Labs & Imaging:' : 'نتائج التحاليل والأشعة:', p.labRadiologyNotes),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _osceRevealAnswer ? Colors.orange.shade800 : AppColors.statMintBorder,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => setState(() => _osceRevealAnswer = !_osceRevealAnswer),
                    icon: Icon(_osceRevealAnswer ? Icons.visibility_off : Icons.lightbulb_outline),
                    label: Text(
                      _osceRevealAnswer
                          ? (isEn ? 'Hide Answer' : 'إخفاء الجواب')
                          : (isEn ? 'Reveal True Diagnosis & Surgical Plan' : 'كشف التشخيص والقرار الجراحي الحقيقي'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                  ),
                ),
                if (_osceRevealAnswer) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.pillGreenBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.statMintBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('✅ ${p.diagnosis}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.pillGreenText)),
                        const SizedBox(height: 6),
                        Text('🔪 ${p.plannedOperation} (${p.operationUrgency})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navyDark)),
                        if (p.operativeNotes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('📋 ${p.operativeNotes}', style: const TextStyle(fontSize: 13)),
                        ],
                        if (p.vivaQuestion.isNotEmpty) ...[
                          const Divider(),
                          Text('❓ Viva: ${p.vivaQuestion}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('💡 ${p.vivaAnswer}', style: const TextStyle(fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _osceLine(String title, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
          Text(
            val.trim().isEmpty ? '-' : val,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.getTextColor(_lightingMode)),
          ),
        ],
      ),
    );
  }

  void _showAddCustomCardOrSlideDialog(String defaultType) {
    final isEn = _appLanguage == 'en';
    String itemType = defaultType;
    final catCtrl = TextEditingController(text: isEn ? 'Bailey & Love - General Surgery' : 'Bailey & Love - الجراحة العامة');
    final qCtrl = TextEditingController();
    final aCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(isEn ? 'Add Custom Flashcard or Slide' : 'إضافة فلاش كارت أو سلايد بنفسي'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: itemType,
                  decoration: InputDecoration(labelText: isEn ? 'Type' : 'النوع', border: const OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(value: 'flashcard', child: Text(isEn ? '🃏 Q&A Flashcard' : '🃏 بطاقة سؤال وجواب (فلاش كارت)')),
                    DropdownMenuItem(value: 'slide', child: Text(isEn ? '🎞️ Surgical Study Slide' : '🎞️ سلايد علمي (شرح ونقاط)')),
                  ],
                  onChanged: (v) => setDlg(() => itemType = v!),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: catCtrl,
                  decoration: InputDecoration(labelText: isEn ? 'Chapter / Topic' : 'الفصل / الموضوع', border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: itemType == 'flashcard' ? (isEn ? 'Question' : 'السؤال') : (isEn ? 'Slide Title' : 'عنوان السلايد'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: aCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: itemType == 'flashcard' ? (isEn ? 'Answer' : 'الجواب النموذجي') : (isEn ? 'Slide Bullet Points' : 'محتوى ونقاط السلايد'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEn ? 'Cancel' : 'إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (qCtrl.text.trim().isEmpty) return;
                await DatabaseHelper.instance.insertStudyItem(
                  StudyItem(
                    itemType: itemType,
                    categoryAr: catCtrl.text.trim(),
                    categoryEn: catCtrl.text.trim(),
                    titleAr: qCtrl.text.trim(),
                    titleEn: qCtrl.text.trim(),
                    bodyAr: aCtrl.text.trim(),
                    bodyEn: aCtrl.text.trim(),
                    status: 'review',
                  ),
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadAllData();
                }
              },
              child: Text(isEn ? 'Save' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCasesByRotationTab() {
    final Map<String, List<PatientRecord>> grouped = {};
    for (var p in _allPatients) {
      final rot = p.rotation.trim().isEmpty ? 'الجراحة العامة' : p.rotation.trim();
      grouped.putIfAbsent(rot, () => []);
      grouped[rot]!.add(p);
    }

    if (grouped.isEmpty) {
      return Center(
        child: Text(
          _appLanguage == 'en'
              ? 'No cases recorded to group by surgical rotation yet'
              : 'لا توجد حالات مسجلة لتصنيفها حسب الروتيشن بعد',
          style: const TextStyle(color: Colors.blueGrey),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text(
          _appLanguage == 'en'
              ? 'Cases Archive Grouped by Surgical Rotation'
              : 'أرشيف الحالات مقسماً حسب الروتيشن الجراحي',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextColor(_lightingMode)),
        ),
        const SizedBox(height: 10),
        ...grouped.entries.map((entry) {
          return Card(
            color: AppColors.getCardColor(_lightingMode),
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.statBlueBg,
                child: Text('${entry.value.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navyPrimary)),
              ),
              title: Text(entry.key,
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextColor(_lightingMode))),
              subtitle: Text(
                'P: ${entry.value.where((e) => e.surgeonRole.startsWith("P")).length} | S: ${entry.value.where((e) => e.surgeonRole.startsWith("S")).length}',
                style: const TextStyle(fontSize: 12),
              ),
              children: entry.value.map((p) {
                return ListTile(
                  title: Text(p.displayName(_isAnonymized, _appLanguage),
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextColor(_lightingMode))),
                  subtitle: Text('${p.plannedOperation} — ${p.diagnosis}'),
                  trailing: Text(p.operationDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientDetailsScreen(
                          patientId: p.id!,
                          isAnonymized: _isAnonymized,
                          appLanguage: _appLanguage,
                        ),
                      ),
                    );
                    _loadAllData();
                  },
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatisticsAnalyticsTab() {
    final isEn = _appLanguage == 'en';
    final total = _allPatients.length;
    final pCount = _allPatients.where((p) => p.surgeonRole.startsWith('P')).length;
    final sCount = _allPatients.where((p) => p.surgeonRole.startsWith('S')).length;
    final aCount = _allPatients.where((p) => p.surgeonRole.startsWith('A')).length;

    final complexMajor = _allPatients.where((p) => p.operationMagnitude.contains('Complex')).length;
    final major = _allPatients.where((p) => p.operationMagnitude.startsWith('Major')).length;
    final intermediate = _allPatients.where((p) => p.operationMagnitude.contains('Intermediate')).length;
    final minor = _allPatients.where((p) => p.operationMagnitude.contains('Minor')).length;

    final progress = (_boardTargetP > 0) ? (pCount / _boardTargetP).clamp(0.0, 1.0) : 0.0;
    final cardColor = AppColors.getCardColor(_lightingMode);
    final textColor = AppColors.getTextColor(_lightingMode);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: const Border(right: BorderSide(color: AppColors.statBlueBorder, width: 5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEn
                    ? 'Board Target Progress (Primary Surgeon - P)'
                    : 'مؤشر إنجاز متطلبات البورد (جراح رئيسي P)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEn
                        ? 'Completed: $pCount of $_boardTargetP operations'
                        : 'المنجز: $pCount عملية من أصل $_boardTargetP',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                  ),
                  Text('${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.statBlueBorder)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: AppColors.statBlueBg,
                  color: AppColors.statBlueBorder,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEn ? 'Operations by Surgeon Role' : 'توزيع العمليات حسب دورك الجراحي (Surgeon Role)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
              ),
              const Divider(),
              _buildStatRowItem('P - Performed (Primary Surgeon)', pCount, total, AppColors.statBlueBorder, textColor),
              _buildStatRowItem('S - Supervised (S-TS / S-TU)', sCount, total, AppColors.statMintBorder, textColor),
              _buildStatRowItem('A - Assisted', aCount, total, AppColors.statAmberBorder, textColor),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEn ? 'Operations by Magnitude' : 'توزيع العمليات حسب الحجم (Magnitude)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
              ),
              const Divider(),
              _buildStatRowItem('Complex Major', complexMajor, total, AppColors.statPurpleBorder, textColor),
              _buildStatRowItem('Major', major, total, AppColors.navyPrimary, textColor),
              _buildStatRowItem('Intermediate', intermediate, total, AppColors.statMintBorder, textColor),
              _buildStatRowItem('Minor', minor, total, Colors.blueGrey, textColor),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.getPrimaryColor(_themePalette),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _generateLogbookConsolidationPdf,
          icon: const Icon(Icons.picture_as_pdf),
          label: Text(
            isEn
                ? 'Export Official Consolidation Logbook (PDF)'
                : 'تصدير جدول اللوكبوك الإحصائي الرسمي (PDF)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRowItem(String label, int count, int total, Color color, Color textColor) {
    final pct = total > 0 ? ((count / total) * 100).toStringAsFixed(0) : '0';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: textColor)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Text('$count ($pct%)', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsProfileTab() {
    final isEn = _appLanguage == 'en';
    final nameCtrl = TextEditingController(text: _residentName);
    final levelCtrl = TextEditingController(text: _residentLevel);
    final hospCtrl = TextEditingController(text: _hospitalName);
    final targetCtrl = TextEditingController(text: _boardTargetP.toString());
    final fbUrlCtrl = TextEditingController(text: _firebaseDbUrl);
    final fbCodeCtrl = TextEditingController(text: _firebaseSecretCode);
    final cardColor = AppColors.getCardColor(_lightingMode);
    final textColor = AppColors.getTextColor(_lightingMode);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: const Border(right: BorderSide(color: AppColors.statAmberBorder, width: 5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isEn ? '🎨 Colors, Backlight & Languages' : '🎨 الألوان، الإضاءة الخلفية، واللغات',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showAppearanceAndLanguageSheet,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: Text(isEn ? 'Control Panel' : 'لوحة التحكم'),
                  ),
                ],
              ),
              const Divider(),
              Row(
                children: [
                  _choiceBtn('العربية 🇮🇶', _appLanguage == 'ar', () async {
                    await DatabaseHelper.instance.saveSetting('appLanguage', 'ar');
                    setState(() => _appLanguage = 'ar');
                  }),
                  const SizedBox(width: 8),
                  _choiceBtn('English 🇬🇧', _appLanguage == 'en', () async {
                    await DatabaseHelper.instance.saveSetting('appLanguage', 'en');
                    setState(() => _appLanguage = 'en');
                  }),
                  const SizedBox(width: 8),
                  _choiceBtn('کوردی ☀️', _appLanguage == 'ku', () async {
                    await DatabaseHelper.instance.saveSetting('appLanguage', 'ku');
                    setState(() => _appLanguage = 'ku');
                  }),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: const Border(right: BorderSide(color: AppColors.statMintBorder, width: 5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_done, color: AppColors.statMintBorder),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEn
                          ? 'Cloud Storage Settings (Firebase Realtime DB)'
                          : 'إعدادات الخزن السحابي (Firebase Realtime DB)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isEn ? 'Last Successful Sync: $_lastCloudSync' : 'آخر مزامنة ناجحة: $_lastCloudSync',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              const Divider(height: 20),
              TextField(
                controller: fbUrlCtrl,
                textDirection: TextDirection.ltr,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: isEn
                      ? 'Firebase Realtime Database URL'
                      : 'رابط قاعدة بيانات Firebase (Realtime Database URL)',
                  hintText: 'https://surgen-5-default-rtdb.firebaseio.com',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fbCodeCtrl,
                textDirection: TextDirection.ltr,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: isEn
                      ? 'Your Secret Sync Key (to sync across devices)'
                      : 'الرمز السري لحسابك (لمزامنة بياناتك بين أجهزتك)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statBlueBorder,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onPressed: () async {
                        final clean = FirebaseCloudService.normalizeFirebaseUrl(fbUrlCtrl.text);
                        fbUrlCtrl.text = clean;
                        _firebaseDbUrl = clean;
                        _firebaseSecretCode = fbCodeCtrl.text.trim();
                        await DatabaseHelper.instance.saveSetting('firebaseDbUrl', clean);
                        await DatabaseHelper.instance.saveSetting('firebaseSecretCode', _firebaseSecretCode);
                        await _performFirebaseUpload();
                      },
                      icon: const Icon(Icons.cloud_upload, size: 19),
                      label: Text(isEn ? 'Save & Upload' : 'حفظ ورفع للسحابة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onPressed: () async {
                        final clean = FirebaseCloudService.normalizeFirebaseUrl(fbUrlCtrl.text);
                        fbUrlCtrl.text = clean;
                        _firebaseDbUrl = clean;
                        _firebaseSecretCode = fbCodeCtrl.text.trim();
                        await DatabaseHelper.instance.saveSetting('firebaseDbUrl', clean);
                        await DatabaseHelper.instance.saveSetting('firebaseSecretCode', _firebaseSecretCode);
                        _showCloudRestoreConfirmDialog();
                      },
                      icon: const Icon(Icons.cloud_download, size: 19),
                      label: Text(isEn ? 'Restore from Cloud' : 'استعادة من السحابة'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEn
                    ? 'Resident Profile (Appears on Official PDF Reports & Discharge Rx)'
                    : 'بيانات الطبيب المقيم (تظهر في تقارير الـ PDF وشهادة الخروج)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
              ),
              const Divider(height: 20),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: isEn ? 'Resident Doctor Name' : 'اسم الطبيب المقيم',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: levelCtrl,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: isEn ? 'Training Level / Specialty (e.g. General Surgery Board)' : 'المرحلة / الاختصاص (مثال: بورد جراحة عامة - R3)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: hospCtrl,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: isEn ? 'Hospital / Training Center' : 'المستشفى / المركز التدريبي',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: targetCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: isEn ? 'Target Primary Surgeon (P) Operations' : 'العدد المستهدف لعمليات الجراح الرئيسي (P)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.getPrimaryColor(_themePalette),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    final clean = FirebaseCloudService.normalizeFirebaseUrl(fbUrlCtrl.text);
                    await DatabaseHelper.instance.saveSetting('residentName', nameCtrl.text.trim());
                    await DatabaseHelper.instance.saveSetting('residentLevel', levelCtrl.text.trim());
                    await DatabaseHelper.instance.saveSetting('hospitalName', hospCtrl.text.trim());
                    await DatabaseHelper.instance.saveSetting('boardTargetP', targetCtrl.text.trim());
                    await DatabaseHelper.instance.saveSetting('firebaseDbUrl', clean);
                    await DatabaseHelper.instance.saveSetting('firebaseSecretCode', fbCodeCtrl.text.trim());
                    _loadAllData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEn ? 'Doctor profile & cloud settings saved!' : 'تم حفظ إعدادات الطبيب والسحابة بنجاح',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: Text(isEn ? 'Save Doctor Profile' : 'حفظ بيانات الطبيب'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomBottomNavBar() {
    final items = [
      {'label': L10n.t('navHome', _appLanguage), 'icon': Icons.home_rounded},
      {'label': L10n.t('navStudy', _appLanguage), 'icon': Icons.school_rounded},
      {'label': L10n.t('navCases', _appLanguage), 'icon': Icons.folder_rounded},
      {'label': L10n.t('navStats', _appLanguage), 'icon': Icons.bar_chart_rounded},
      {'label': L10n.t('navSettings', _appLanguage), 'icon': Icons.settings_rounded},
    ];

    final cardColor = AppColors.getCardColor(_lightingMode);

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final isSelected = _currentTabIndex == i;
          final color = isSelected
              ? const Color(0xFF0066CC)
              : (_lightingMode == 'dark' ? Colors.white70 : const Color(0xFF475569));

          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _currentTabIndex = i),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0066CC).withOpacity(0.10) : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(items[i]['icon'] as IconData, color: color, size: 24),
                    const SizedBox(height: 3),
                    Text(
                      items[i]['label'] as String,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 3,
                      width: isSelected ? 38 : 0,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0066CC),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ==========================================
// ودجت البطاقة الدراسية التفاعلية (Tap to Flip Flashcard)
// ==========================================
class _FlashcardInteractiveWidget extends StatefulWidget {
  final StudyItem item;
  final String lang;
  final Color cardBgColor;
  final Color textColor;
  final ValueChanged<String> onStatusToggle;
  final VoidCallback onDelete;

  const _FlashcardInteractiveWidget({
    required this.item,
    required this.lang,
    required this.cardBgColor,
    required this.textColor,
    required this.onStatusToggle,
    required this.onDelete,
  });

  @override
  State<_FlashcardInteractiveWidget> createState() => _FlashcardInteractiveWidgetState();
}

class _FlashcardInteractiveWidgetState extends State<_FlashcardInteractiveWidget> {
  bool _isAnswerVisible = false;

  @override
  Widget build(BuildContext context) {
    final isMastered = widget.item.status == 'mastered';
    final isEn = widget.lang == 'en';

    return Card(
      color: widget.cardBgColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isMastered ? AppColors.statMintBorder : AppColors.statPurpleBorder.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _isAnswerVisible = !_isAnswerVisible),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.statPurpleBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.item.getCategory(widget.lang),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.statPurpleBorder,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _isAnswerVisible
                            ? (isEn ? 'Tap to hide' : 'اضغط للإخفاء')
                            : L10n.t('tapToFlip', widget.lang),
                        style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        onPressed: widget.onDelete,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '❓ ${widget.item.getTitle(widget.lang)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: widget.textColor),
              ),
              if (_isAnswerVisible) ...[
                const Divider(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.pillGreenBg.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.item.getBody(widget.lang),
                    style: const TextStyle(fontSize: 13.5, color: AppColors.navyDark, height: 1.45),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => widget.onStatusToggle('review'),
                        icon: const Icon(Icons.refresh_rounded, size: 17),
                        label: Text(L10n.t('reviewLater', widget.lang), style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMastered ? AppColors.statMintBorder : Colors.blueGrey,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => widget.onStatusToggle('mastered'),
                        icon: const Icon(Icons.check_circle_outline, size: 17),
                        label: Text(L10n.t('mastered', widget.lang), style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. شاشة إضافة وتعديل ملف المريض الشاملة (10 أقسام كاملة + HPI + Viva + ترجمة كاملة)
// ==========================================
class PatientFormScreen extends StatefulWidget {
  final PatientRecord? existingPatient;
  final String appLanguage;

  const PatientFormScreen({
    super.key,
    this.existingPatient,
    this.appLanguage = 'ar',
  });

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
  late TextEditingController _hpiCtrl;
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
  late TextEditingController _vivaQCtrl;
  late TextEditingController _vivaACtrl;
  late TextEditingController _dischargeCtrl;
  late TextEditingController _followUpCtrl;

  String _gender = 'ذكر';
  String _bloodGroup = 'O+';
  String _surgeonRole = 'P - جراح رئيسي (Performed)';
  String _opMagnitude = 'Major';
  String _smokingStatus = 'غير مدخن';
  String _urgency = 'مجدولة (باردة)';
  String _asaScore = 'ASA I';
  String _anesthesia = 'تخدير عام (GA)';
  String _opStatus = 'تمت العملية';
  String _dvtProphylaxis = 'ميكانيكي + دوائي (LMWH/Heparin)';
  String _biopsyStatus = 'بانتظار الزرع (Pending)';
  bool _isStarred = false;
  String _finalOutcome = 'شفاء تام';
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
    _rotationCtrl = TextEditingController(
      text: p?.rotation ?? (widget.appLanguage == 'en' ? 'General Surgery' : 'الجراحة العامة'),
    );
    _consultantCtrl = TextEditingController(text: p?.consultantName ?? '');
    _chronicCtrl = TextEditingController(text: p?.chronicDiseases ?? '');
    _allergiesCtrl = TextEditingController(text: p?.allergies ?? '');
    _medsCtrl = TextEditingController(text: p?.currentMedications ?? '');
    _pastSurgeriesCtrl = TextEditingController(text: p?.pastSurgeries ?? '');
    _pastCompCtrl = TextEditingController(text: p?.pastComplications ?? '');
    _complaintCtrl = TextEditingController(text: p?.chiefComplaint ?? '');
    _hpiCtrl = TextEditingController(text: p?.hpi ?? '');
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
    _vivaQCtrl = TextEditingController(text: p?.vivaQuestion ?? '');
    _vivaACtrl = TextEditingController(text: p?.vivaAnswer ?? '');
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

  void _applyQuickTemplate(String title, String diag, String op, String mag, String notes) {
    setState(() {
      _diagnosisCtrl.text = diag;
      _operationCtrl.text = op;
      _opMagnitude = mag;
      _opNotesCtrl.text = notes;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.appLanguage == 'en' ? 'Template "$title" applied!' : 'تم إدراج قالب "$title" بنجاح',
        ),
      ),
    );
  }

  void _insertSocratesTemplate() {
    final isEn = widget.appLanguage == 'en';
    final socrates = isEn
        ? '• Site: \n• Onset & Duration: \n• Character & Radiation: \n• Associated Symptoms: \n• Exacerbating / Relieving Factors: \n• Severity (1-10): '
        : '• الموضع (Site): \n• البداية والمدة (Onset & Duration): \n• طبيعة الألم والانتشار (Character & Radiation): \n• الأعراض المرافقة (Associated Symptoms): \n• العوامل المفاقمة والمخففة (Exacerbating/Relieving): \n• الشدة (Severity): ';
    setState(() {
      if (_hpiCtrl.text.trim().isEmpty) {
        _hpiCtrl.text = socrates;
      } else {
        _hpiCtrl.text = '${_hpiCtrl.text}\n$socrates';
      }
    });
  }

  Future<void> _addPhoto(List<String> targetList, String prefix) async {
    final isEn = widget.appLanguage == 'en';
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.navyPrimary),
              title: Text(isEn ? 'Take Photo with Camera' : 'التقاط صورة مباشرة بالكاميرا'),
              onTap: () async {
                Navigator.pop(ctx);
                final path = await DatabaseHelper.pickAndSaveMedicalImage(ImageSource.camera, prefix);
                if (path != null) setState(() => targetList.add(path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.statBlueBorder),
              title: Text(isEn ? 'Choose from Phone Gallery' : 'اختيار صورة من استوديو الهاتف'),
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
      hpi: _hpiCtrl.text.trim(),
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
      vivaQuestion: _vivaQCtrl.text.trim(),
      vivaAnswer: _vivaACtrl.text.trim(),
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
    final isEn = widget.appLanguage == 'en';

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existingPatient == null
                ? (isEn ? 'Add New Surgical Case' : 'إضافة حالة جديدة')
                : (isEn ? 'Edit Patient Case' : 'تعديل ملف المريض'),
          ),
          actions: [
            IconButton(
              icon: Icon(_isStarred ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber),
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
              Card(
                color: AppColors.statBlueBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn
                            ? '⚡ Quick Operative Templates (One-Tap Fill):'
                            : '⚡ قوالب العمليات الجاهزة (تعبئة سريعة):',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyDark),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _templateChip(
                              'Lap. Cholecystectomy',
                              isEn ? 'Calculous Cholecystitis' : 'التهاب المرارة الحصوي',
                              'Lap. Cholecystectomy',
                              'Major',
                              '4-port laparoscopy, Calot triangle dissected, Critical View of Safety achieved, cystic duct & artery clipped and divided.',
                            ),
                            _templateChip(
                              'Lap. Appendectomy',
                              isEn ? 'Acute Appendicitis' : 'التهاب الزائدة الدودية الحاد',
                              'Lap. Appendectomy',
                              'Intermediate',
                              '3-port laparoscopy, inflamed appendix identified, mesoappendix controlled, base ligated with endoloop.',
                            ),
                            _templateChip(
                              'Inguinal Hernia (Mesh)',
                              isEn ? 'Inguinal Hernia' : 'فتق مغبني',
                              'Lichtenstein Mesh Hernioplasty',
                              'Intermediate',
                              'Inguinal canal opened, sac identified and reduced, polypropylene mesh fixed to inguinal ligament and conjoint tendon.',
                            ),
                            _templateChip(
                              'Total Thyroidectomy',
                              isEn ? 'Multinodular Goitre (MNG)' : 'تضخم الغدة الدرقية متعدد العقد',
                              'Total Thyroidectomy',
                              'Complex Major',
                              'Collar incision, superior & inferior thyroid vessels ligated, bilateral RLN and parathyroids identified and preserved.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildSectionCard(
                title: isEn ? '1. Patient Demographics' : '1. البيانات الشخصية للمريض',
                icon: Icons.person,
                children: [
                  _buildTextField(_nameCtrl, isEn ? 'Patient Full Name *' : 'اسم المريض الرباعي *', required: true),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_ageCtrl, isEn ? 'Age *' : 'العمر *', required: true, isNumber: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(_mrnCtrl, isEn ? 'File Number (MRN)' : 'رقم الملف (MRN)')),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          isEn ? 'Gender' : 'الجنس',
                          _gender,
                          ['ذكر', 'أنثى', 'Male', 'Female'],
                          (v) => setState(() => _gender = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDropdown(
                          isEn ? 'Blood Group' : 'فصيلة الدم',
                          _bloodGroup,
                          ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'],
                          (v) => setState(() => _bloodGroup = v!),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_phoneCtrl, isEn ? 'Phone Number' : 'رقم الهاتف')),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(_admissionDateCtrl, isEn ? 'Admission Date' : 'تاريخ الدخول')),
                    ],
                  ),
                ],
              ),
              _buildSectionCard(
                title: isEn ? '2. Board Logbook Details' : '2. بيانات اللوكبوك الجراحي (Board Logbook)',
                icon: Icons.badge,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          _rotationCtrl,
                          isEn ? 'Surgical Rotation (General, Peds...)' : 'الروتيشن (الجراحة العامة، أطفال...)',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          _consultantCtrl,
                          isEn ? 'Supervisor Consultant' : 'الاختصاصي المشرف (مثال: سامر)',
                        ),
                      ),
                    ],
                  ),
                  _buildDropdown(
                    isEn ? 'Surgeon Role' : 'دورك في العملية (Surgeon Role)',
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
                    isEn ? 'Operation Magnitude' : 'حجم وتصنيف العملية (Magnitude)',
                    _opMagnitude,
                    ['Complex Major', 'Major', 'Intermediate', 'Minor'],
                    (v) => setState(() => _opMagnitude = v!),
                  ),
                ],
              ),
              _buildSectionCard(
                title: isEn ? '3. Past Medical & Surgical History' : '3. التاريخ المرضي والجراحات السابقة',
                icon: Icons.history_edu,
                children: [
                  _buildTextField(
                    _chronicCtrl,
                    isEn ? 'Chronic Diseases (DM, HTN, IHD, Asthma...)' : 'الأمراض المزمنة (سكري، ضغط، قلب، ربو...)',
                    maxLines: 2,
                  ),
                  _buildTextField(_allergiesCtrl, isEn ? 'Drug / Food Allergies' : 'الحساسية الدوائية'),
                  _buildTextField(
                    _medsCtrl,
                    isEn ? 'Current Medications & Anticoagulants' : 'الأدوية المستمرة ومميعات الدم',
                    maxLines: 2,
                  ),
                  _buildDropdown(
                    isEn ? 'Smoking Status' : 'التدخين',
                    _smokingStatus,
                    ['غير مدخن', 'مدخن حالي', 'مدخن سابق', 'Non-smoker', 'Smoker', 'Ex-smoker'],
                    (v) => setState(() => _smokingStatus = v!),
                  ),
                  _buildTextField(
                    _pastSurgeriesCtrl,
                    isEn ? 'Past Surgical Operations' : 'العمليات الجراحية السابقة',
                    maxLines: 2,
                  ),
                  _buildTextField(
                    _pastCompCtrl,
                    isEn ? 'Previous Surgical / Anesthetic Complications' : 'مضاعفات جراحية أو تخديرية سابقة',
                  ),
                ],
              ),
              _buildSectionCard(
                title: isEn
                    ? '4. Chief Complaint, HPI & Clinical Diagnosis'
                    : '4. الشكوى، القصة المرضية (HPI)، والتشخيص السريري',
                icon: Icons.medical_information,
                children: [
                  _buildTextField(
                    _complaintCtrl,
                    isEn ? 'Chief Complaint *' : 'الشكوى الرئيسية (مما يعاني حالياً) *',
                    required: true,
                    maxLines: 2,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isEn
                              ? 'History of Present Illness (HPI):'
                              : 'القصة المرضية التفصيلية (History of Present Illness):',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.navyPrimary),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _insertSocratesTemplate,
                        icon: const Icon(Icons.bolt, size: 16),
                        label: Text(
                          isEn ? 'Insert SOCRATES' : 'قالب SOCRATES',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  _buildTextField(
                    _hpiCtrl,
                    isEn
                        ? 'Detailed HPI (onset, course, duration, pain character, associated symptoms...)'
                        : 'تفاصيل الـ HPI (بداية الأعراض، تطورها، طبيعة الألم، الأعراض المرافقة...)',
                    maxLines: 4,
                  ),
                  _buildTextField(
                    _examCtrl,
                    isEn ? 'Clinical Examination & Vital Signs' : 'الفحص السريري والعلامات الحيوية',
                    maxLines: 2,
                  ),
                  _buildTextField(
                    _labNotesCtrl,
                    isEn ? 'Lab Results & Ultrasound / CT Summary' : 'نتائج التحاليل والأشعة والسونار/المفراس',
                    maxLines: 2,
                  ),
                  _buildTextField(
                    _diagnosisCtrl,
                    isEn ? 'Final Diagnosis *' : 'التشخيص النهائي (Diagnosis) *',
                    required: true,
                  ),
                ],
              ),
              _buildSectionCard(
                title: isEn ? '5. Planned Operation Details' : '5. تفاصيل العملية الجراحية المقررة',
                icon: Icons.local_hospital,
                children: [
                  _buildTextField(
                    _operationCtrl,
                    isEn ? 'Planned Operation Name *' : 'اسم ونوع العملية المقررة *',
                    required: true,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          isEn ? 'Urgency' : 'تصنيف العملية',
                          _urgency,
                          ['مجدولة (باردة)', 'طارئة (Emergency)', 'مستعجلة (Urgent)'],
                          (v) => setState(() => _urgency = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDropdown(
                          isEn ? 'Operation Status' : 'حالة العملية',
                          _opStatus,
                          ['تمت العملية', 'مقررة', 'مؤجلة'],
                          (v) => setState(() => _opStatus = v!),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          'ASA Score',
                          _asaScore,
                          ['ASA I', 'ASA II', 'ASA III', 'ASA IV', 'ASA V'],
                          (v) => setState(() => _asaScore = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDropdown(
                          isEn ? 'Anesthesia Type' : 'نوع التخدير',
                          _anesthesia,
                          ['تخدير عام (GA)', 'تخدير نصفي (Spinal)', 'تخدير موضعي (Local)'],
                          (v) => setState(() => _anesthesia = v!),
                        ),
                      ),
                    ],
                  ),
                  _buildTextField(_opDateCtrl, isEn ? 'Operation Date' : 'تاريخ العملية'),
                  _buildTextField(
                    _opNotesCtrl,
                    isEn ? 'Operative Notes & Intra-op Findings' : 'تفاصيل وخطوات العملية (Operative Notes)',
                    maxLines: 3,
                  ),
                ],
              ),
              _buildSectionCard(
                title: isEn ? '6. Ward Round, Drains & Prophylaxis' : '6. متابعة الردهة، الدرينات، والوقاية',
                icon: Icons.vaccines,
                children: [
                  _buildTextField(
                    _drainsCtrl,
                    isEn ? 'Drains & Tubes (Type, Count, Daily Output)' : 'الدرينات والصوندات (النوع، العدد، المخرجات اليومية)',
                    maxLines: 2,
                  ),
                  _buildDropdown(
                    isEn ? 'DVT Prophylaxis' : 'الوقاية الخثرية (DVT Prophylaxis)',
                    _dvtProphylaxis,
                    [
                      'ميكانيكي + دوائي (LMWH/Heparin)',
                      'دوائي فقط (Clexane / Heparin)',
                      'ميكانيكي فقط',
                      'لا يحتاج (خطورة منخفضة)',
                    ],
                    (v) => setState(() => _dvtProphylaxis = v!),
                  ),
                  _buildTextField(
                    _antibioticCtrl,
                    isEn ? 'Antibiotic Prophylaxis & Regimen' : 'خطة الصادات الحيوية (Antibiotic Prophylaxis)',
                  ),
                ],
              ),
              _buildSectionCard(
                title: isEn ? '7. Histopathology & Oncology (TNM)' : '7. متابعة الزرع النسيجي والأورام (Histopathology)',
                icon: Icons.biotech,
                children: [
                  _buildDropdown(
                    isEn ? 'Biopsy Status' : 'حالة الزرع النسيجي',
                    _biopsyStatus,
                    ['بانتظار الزرع (Pending)', 'ظهرت النتيجة (Completed)', 'لا يحتاج زرع'],
                    (v) => setState(() => _biopsyStatus = v!),
                  ),
                  _buildTextField(
                    _histoResultCtrl,
                    isEn ? 'Histopathology Result & Margins Status' : 'نتيجة الزرع النسيجي وحالة الحواف (Margins)',
                    maxLines: 2,
                  ),
                  _buildTextField(
                    _tnmCtrl,
                    isEn ? 'TNM Staging & MDT Decision' : 'تصنيف الأورام (TNM Staging) وقرار الـ MDT',
                  ),
                ],
              ),
              _buildSectionCard(
                title: isEn ? '8. Board Pearls & Bedside Viva Question' : '8. ملاحظات البورد وسؤال الـ Viva على المريض',
                icon: Icons.school,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      isEn ? 'Mark as Important Exam Case (⭐ Starred Case)' : 'تمييز كحالة مهمة للامتحان (⭐ Starred Case)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    value: _isStarred,
                    onChanged: (v) => setState(() => _isStarred = v),
                  ),
                  _buildTextField(
                    _vivaQCtrl,
                    isEn
                        ? '❓ Bedside / Intra-op Viva Question asked on this patient'
                        : '❓ سؤال انسألت بيه بالردهة/العمليات على هذه الحالة (Viva Question)',
                    maxLines: 2,
                  ),
                  _buildTextField(
                    _vivaACtrl,
                    isEn
                        ? '💡 Model Viva Answer (automatically added to your Daily Quiz)'
                        : '💡 الجواب النموذجي للسؤال (يُحفظ تلقائياً في اختباراتك اليومية)',
                    maxLines: 3,
                  ),
                  _buildTextField(
                    _pearlsCtrl,
                    isEn
                        ? '📌 Anatomical Variations & Surgical Pearls Learned'
                        : '📌 الملاحظات التشريحية والدروس الجراحية المستفادة',
                    maxLines: 3,
                  ),
                ],
              ),
              _buildSectionCard(
                title: isEn ? '9. Medical Media Archive (4 Albums)' : '9. الأرشيف الصوري الطبي (4 أقسام)',
                icon: Icons.camera_enhance,
                children: [
                  _buildMediaPickerSection(isEn ? 'Radiology, CT & MRI Images' : 'صور الأشعة والمفراس والرنين', _radiologyImages, 'xray'),
                  const Divider(),
                  _buildMediaPickerSection(isEn ? 'Lab Results & Reports' : 'صور التحاليل المختبرية والتقارير', _labImages, 'lab'),
                  const Divider(),
                  _buildMediaPickerSection(isEn ? 'Wound & Operative Photos (Pre/Intra/Post)' : 'صور الجرح والعملية (قبل/أثناء/بعد)', _woundImages, 'wound'),
                  const Divider(),
                  _buildMediaPickerSection(isEn ? 'Histopathology Biopsy Reports' : 'صور تقرير الزرع النسيجي (Biopsy)', _biopsyImages, 'biopsy'),
                ],
              ),
              _buildSectionCard(
                title: isEn ? '10. Final Outcome & Discharge Plan' : '10. النتيجة النهائية وخطة الخروج',
                icon: Icons.fact_check,
                children: [
                  _buildDropdown(
                    isEn ? 'Final Outcome' : 'النتيجة النهائية للمريض',
                    _finalOutcome,
                    ['شفاء تام', 'تحسن مستمر', 'قيد المتابعة', 'حدوث مضاعفات', 'تحويل لمركز تخصصي', 'وفاة'],
                    (v) => setState(() => _finalOutcome = v!),
                  ),
                  _buildDropdown(
                    isEn ? 'Complications (Clavien-Dindo Grade)' : 'تصنيف المضاعفات (Clavien-Dindo)',
                    _clavienGrade,
                    ['لا يوجد (None)', 'Grade I', 'Grade II', 'Grade IIIa', 'Grade IIIb', 'Grade IVa', 'Grade IVb', 'Grade V'],
                    (v) => setState(() => _clavienGrade = v!),
                  ),
                  _buildTextField(
                    _dischargeCtrl,
                    isEn ? 'Discharge Medications & Wound Care Instructions' : 'علاج الخروج وتوصيات العناية بالجرح',
                    maxLines: 2,
                  ),
                  _buildTextField(
                    _followUpCtrl,
                    isEn ? 'Next Follow-up & Suture Removal Date' : 'موعد المراجعة القادم ورفع الخيوط',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _savePatient,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    isEn ? 'Save Case to Board Logbook' : 'حفظ الحالة في سجل البورد',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _templateChip(String label, String diag, String op, String mag, String notes) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ActionChip(
        backgroundColor: Colors.white,
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navyPrimary)),
        onPressed: () => _applyQuickTemplate(label, diag, op, mag, notes),
      ),
    );
  }

  Widget _buildMediaPickerSection(String label, List<String> imagesList, String prefix) {
    final isEn = widget.appLanguage == 'en';
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
              label: Text(isEn ? 'Attach Photo' : 'إرفاق صورة'),
            ),
          ],
        ),
        if (imagesList.isEmpty)
          Text(
            isEn ? 'No photos attached in this section' : 'لا توجد صور مرفقة في هذا القسم',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          )
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
                        border: Border.all(color: Colors.blueGrey.shade200),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.navyPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.navyDark)),
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

  Widget _buildTextField(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    int maxLines = 1,
    bool isNumber = false,
  }) {
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
        validator: required
            ? (v) => (v == null || v.trim().isEmpty)
                ? (widget.appLanguage == 'en' ? 'This field is required' : 'هذا الحقل مطلوب')
                : null
            : null,
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
// 5. شاشة عرض ملف المريض التفصيلي + HPI + شهادة الخروج + المقارنة البصرية
// ==========================================
class PatientDetailsScreen extends StatefulWidget {
  final int patientId;
  final bool isAnonymized;
  final String appLanguage;

  const PatientDetailsScreen({
    super.key,
    required this.patientId,
    this.isAnonymized = false,
    this.appLanguage = 'ar',
  });

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
    final isEn = widget.appLanguage == 'en';
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.navyPrimary),
              title: Text(isEn ? 'Take Photo with Camera' : 'التقاط صورة مباشرة بالكاميرا'),
              onTap: () async {
                Navigator.pop(ctx);
                final path = await DatabaseHelper.pickAndSaveMedicalImage(ImageSource.camera, category);
                if (path != null) _saveNewImagePath(category, path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.statBlueBorder),
              title: Text(isEn ? 'Choose from Phone Gallery' : 'اختيار من استوديو الهاتف'),
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
          appBar: AppBar(backgroundColor: Colors.black, title: Text(title)),
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

  void _openVisualComparisonTool() {
    if (_patient == null) return;
    final p = _patient!;
    final isEn = widget.appLanguage == 'en';
    final List<MedicalPhotoItem> allImgs = [
      ...p.woundImages.map((e) => MedicalPhotoItem(path: e, cat: isEn ? 'Wound' : 'جرح وعملية')),
      ...p.radiologyImages.map((e) => MedicalPhotoItem(path: e, cat: isEn ? 'Radiology' : 'أشعة ومفراس')),
      ...p.labImages.map((e) => MedicalPhotoItem(path: e, cat: isEn ? 'Labs' : 'تحاليل')),
      ...p.biopsyImages.map((e) => MedicalPhotoItem(path: e, cat: isEn ? 'Biopsy' : 'زرع نسيجي')),
    ];

    if (allImgs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn
                ? 'Please attach at least 2 photos inside the patient file to run the Before/After Visual Comparison tool'
                : 'يرجى إرفاق صورتين على الأقل داخل ملف المريض لتشغيل أداة المقارنة البصرية (قبل / بعد)',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisualComparisonScreen(
          patientName: p.displayName(_anonymized, widget.appLanguage),
          images: allImgs,
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
            pw.Expanded(
              child: pw.Text(
                val.isEmpty ? '-' : val,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: arabicFont, fontSize: 10.5),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(label, style: pw.TextStyle(font: arabicBold, fontSize: 10.5, color: PdfColor.fromInt(0xFF0D3562))),
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
            decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF08203E), borderRadius: pw.BorderRadius.circular(8)),
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
          buildPdfRow('الشكوى الرئيسية (Chief Complaint):', p.chiefComplaint),
          buildPdfRow('القصة المرضية التفصيلية (HPI):', p.hpi),
          buildPdfRow('الفحص السريري والتحاليل:', '${p.clinicalExam} | ${p.labRadiologyNotes}'),
          buildPdfRow('التشخيص النهائي:', p.diagnosis),
          pw.Divider(),
          buildPdfRow('العملية المجراة:', '${p.plannedOperation} (${p.operationUrgency})'),
          buildPdfRow('التخدير وتاريخ العملية:', '${p.anesthesiaType} (${p.asaScore}) - التاريخ: ${p.operationDate}'),
          buildPdfRow('ملاحظات العملية (Operative Notes):', p.operativeNotes),
          buildPdfRow('الدرينات والوقاية:', 'الدرينات: ${p.drainsInfo} | الوقاية: ${p.dvtProphylaxis}'),
          pw.Divider(),
          buildPdfRow('الزرع النسيجي و TNM:', '${p.biopsyStatus} - ${p.histopathologyResult} (${p.tnmStaging})'),
          buildPdfRow('ملاحظات البورد والـ Viva:', '${p.surgicalPearls} | ${p.vivaQuestion}'),
          buildPdfRow('النتيجة النهائية:', '${p.finalOutcome} (المضاعفات: ${p.clavienDindoGrade})'),
          buildPdfRow('خطة الخروج والمراجعة:', '${p.dischargeTreatment} | المراجعة: ${p.followUpDate}'),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Case_${p.mrn.isEmpty ? p.id : p.mrn}.pdf');
  }

  Future<void> _generateDischargeCertificatePdf() async {
    if (_patient == null) return;
    final p = _patient!;
    final rName = await DatabaseHelper.instance.getSetting('residentName', 'د. إيفان إحسان');
    final rLevel = await DatabaseHelper.instance.getSetting('residentLevel', 'البورد في الجراحة العامة');
    final hName = await DatabaseHelper.instance.getSetting('hospitalName', 'المستشفى التعليمي');

    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    pw.Widget infoBox(String title, String content, {PdfColor? bgColor}) {
      return pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: bgColor ?? PdfColor.fromInt(0xFFF5F7FA),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(title, style: pw.TextStyle(font: arabicBold, fontSize: 11.5, color: PdfColor.fromInt(0xFF08203E))),
            pw.SizedBox(height: 4),
            pw.Text(
              content.trim().isEmpty ? 'حسب إرشادات الطبيب المعالج' : content,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: arabicFont, fontSize: 11),
            ),
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
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF0D3562),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(hName, style: pw.TextStyle(font: arabicBold, color: PdfColors.white, fontSize: 12)),
                    pw.Text('قسم: ${p.rotation}', style: pw.TextStyle(font: arabicFont, color: PdfColors.grey300, fontSize: 10)),
                    pw.Text('تاريخ الإصدار: ${DateTime.now().toString().split(' ').first}',
                        style: pw.TextStyle(font: arabicFont, color: PdfColors.grey300, fontSize: 9.5)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('شهادة خروج مريض وخطة العلاج',
                        style: pw.TextStyle(font: arabicBold, color: PdfColors.white, fontSize: 16)),
                    pw.Text('Surgical Discharge Summary & Prescription',
                        style: pw.TextStyle(font: arabicFont, color: PdfColors.white, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromInt(0xFF0D3562), width: 1),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('رقم الملف (MRN): ${p.mrn.isEmpty ? "-" : p.mrn}', style: pw.TextStyle(font: arabicBold, fontSize: 10.5)),
                    pw.Text('العمر / الجنس: ${p.age} سنة - ${p.gender}', style: pw.TextStyle(font: arabicBold, fontSize: 10.5)),
                    pw.Text('اسم المريض: ${p.name}', style: pw.TextStyle(font: arabicBold, fontSize: 11.5)),
                  ],
                ),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('حالة الخروج: ${p.finalOutcome}', style: pw.TextStyle(font: arabicBold, fontSize: 10.5, color: PdfColor.fromInt(0xFF0D6832))),
                    pw.Text('تاريخ العملية: ${p.operationDate}', style: pw.TextStyle(font: arabicFont, fontSize: 10.5)),
                    pw.Text('تاريخ الدخول: ${p.admissionDate}', style: pw.TextStyle(font: arabicFont, fontSize: 10.5)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          infoBox('التشخيص الطبي النهائي (Final Diagnosis):', p.diagnosis, bgColor: PdfColors.blue50),
          infoBox('التداخل الجراحي الذي أُجري للمريض (Procedure Performed):',
              '${p.plannedOperation} — (${p.anesthesiaType})', bgColor: PdfColors.blue50),
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFE8F5E9),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColor.fromInt(0xFF2E7D32), width: 1.2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('علاج الخروج وتوصيات العناية بالجرح (Discharge Medications & Wound Care):',
                    style: pw.TextStyle(font: arabicBold, fontSize: 12, color: PdfColor.fromInt(0xFF1B5E20))),
                pw.Divider(),
                pw.Text(
                  p.dischargeTreatment.trim().isEmpty
                      ? '1. الالتزام بمواعيد المضادات الحيوية والمسكنات الموصوفة.\n2. الحفاظ على نظافة وجفاف الجرح وتبديل الضماد حسب التعليمات.'
                      : p.dischargeTreatment,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: arabicFont, fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (p.drainsInfo.trim().isNotEmpty)
            infoBox('تعليمات متابعة الدرينات / الصوندات (Drains Care):', p.drainsInfo),
          infoBox(
            'موعد المراجعة القادم ورفع الخيوط / متابعة الزرع النسيجي:',
            'موعد المراجعة: ${p.followUpDate.isEmpty ? "بعد أسبوع واحد في العيادة الاستشارية" : p.followUpDate}   |   حالة الزرع النسيجي: ${p.biopsyStatus}',
            bgColor: PdfColor.fromInt(0xFFFFF8E1),
          ),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFFFEBEE),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE53935)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('علامات تستوجب مراجعة الطوارئ أو الاتصال بالطبيب فوراً (Warning Signs):',
                    style: pw.TextStyle(font: arabicBold, fontSize: 10.5, color: PdfColor.fromInt(0xFFB71C1C))),
                pw.SizedBox(height: 3),
                pw.Text(
                  '• ارتفاع شديد في درجة الحرارة أو قشعريرة.\n'
                  '• احمرار متزايد، تورم، أو خروج إفرازات/نزف مستمر من موضع الجرح.\n'
                  '• ألم شديد لا يستجيب للمسكنات، أو تقيؤ مستمر، أو ضيق في التنفس.',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: arabicFont, fontSize: 9.5, color: PdfColor.fromInt(0xFFB71C1C)),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('الاختصاصي المشرف', style: pw.TextStyle(font: arabicBold, fontSize: 10.5)),
                  pw.Text('د. ${p.consultantName.isEmpty ? "___________________" : p.consultantName}',
                      style: pw.TextStyle(font: arabicFont, fontSize: 10.5)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('الطبيب المعالج ($rLevel)', style: pw.TextStyle(font: arabicBold, fontSize: 10.5)),
                  pw.Text('$rName — التوقيع: ________________', style: pw.TextStyle(font: arabicFont, fontSize: 10.5)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Discharge_${p.name}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_patient == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = _patient!;
    final isEn = widget.appLanguage == 'en';
    final totalImagesCount = p.radiologyImages.length +
        p.labImages.length +
        p.woundImages.length +
        p.biopsyImages.length;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.displayName(_anonymized, widget.appLanguage)),
          actions: [
            IconButton(
              icon: Icon(p.isStarred ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber),
              tooltip: isEn ? 'Star for Exam' : 'تمييز للامتحان',
              onPressed: _toggleStar,
            ),
            IconButton(
              icon: const Icon(Icons.compare, color: Colors.cyanAccent),
              tooltip: isEn ? 'Before / After Comparison' : 'المقارنة البصرية (قبل / بعد)',
              onPressed: _openVisualComparisonTool,
            ),
            IconButton(
              icon: const Icon(Icons.fact_check, color: Colors.greenAccent),
              tooltip: isEn ? 'Discharge Summary PDF' : 'شهادة خروج المريض (Discharge PDF)',
              onPressed: _generateDischargeCertificatePdf,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: isEn ? 'Full Case Report PDF' : 'تقرير الحالة الكامل (Case PDF)',
              onPressed: _generateAndSharePdf,
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: isEn ? 'Edit Case' : 'تعديل الملف',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PatientFormScreen(existingPatient: p, appLanguage: widget.appLanguage),
                  ),
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
                    title: Text(isEn ? 'Delete Patient Record' : 'حذف سجل المريض'),
                    content: Text(isEn ? 'Are you sure you want to delete this record?' : 'هل أنت متأكد من حذف هذا السجل نهائياً؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(isEn ? 'Cancel' : 'إلغاء'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(isEn ? 'Delete' : 'حذف'),
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
              color: AppColors.navyPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                            p.displayName(_anonymized, widget.appLanguage),
                            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Chip(
                          label: Text(p.operationStatus, style: const TextStyle(fontWeight: FontWeight.bold)),
                          backgroundColor: AppColors.pillGreenBg,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isEn
                          ? 'Age: ${p.age}y | ${p.gender} | Blood: ${p.bloodGroup} | MRN: ${p.mrn}'
                          : 'العمر: ${p.age} سنة | ${p.gender} | دم: ${p.bloodGroup} | ملف: ${p.mrn}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    if (!_anonymized)
                      Text(
                        isEn
                            ? 'Phone: ${p.phone} | Admission: ${p.admissionDate}'
                            : 'هاتف: ${p.phone} | تاريخ الدخول: ${p.admissionDate}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    const Divider(color: Colors.white24, height: 16),
                    Text(
                      isEn
                          ? 'Rotation: ${p.rotation} | Supervisor: Dr. ${p.consultantName.isEmpty ? "-" : p.consultantName}'
                          : 'الروتيشن: ${p.rotation} | المشرف: د. ${p.consultantName.isEmpty ? "غير محدد" : p.consultantName}',
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isEn
                          ? 'Role: ${p.surgeonRole} | Magnitude: ${p.operationMagnitude}'
                          : 'الدور: ${p.surgeonRole} | الحجم: ${p.operationMagnitude}',
                      style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statMintBorder,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _generateDischargeCertificatePdf,
                      icon: const Icon(Icons.fact_check, size: 19),
                      label: Text(
                        isEn ? 'Discharge Rx PDF' : 'شهادة خروج المريض PDF',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statPurpleBorder,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _openVisualComparisonTool,
                      icon: const Icon(Icons.compare, size: 19),
                      label: Text(
                        isEn ? 'Visual Compare ($totalImagesCount)' : 'مقارنة بصرية ($totalImagesCount صور)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildGalleryCard(
              isEn ? 'Radiology, CT & MRI Images' : 'صور الأشعة والمفراس والرنين (Radiology)',
              p.radiologyImages,
              'xray',
              Icons.scanner,
            ),
            _buildGalleryCard(
              isEn ? 'Laboratory Results (Lab Results)' : 'صور التحاليل المختبرية (Lab Results)',
              p.labImages,
              'lab',
              Icons.biotech,
            ),
            _buildGalleryCard(
              isEn ? 'Wound & Intra-Op Photos' : 'صور الجرح والعملية (Wound & Intra-Op)',
              p.woundImages,
              'wound',
              Icons.healing,
            ),
            _buildGalleryCard(
              isEn ? 'Histopathology Biopsy Reports' : 'صور تقرير الزرع النسيجي (Histopathology)',
              p.biopsyImages,
              'biopsy',
              Icons.science,
            ),
            if (p.surgicalPearls.isNotEmpty || p.vivaQuestion.isNotEmpty || p.isStarred)
              Card(
                color: AppColors.statAmberBg,
                margin: const EdgeInsets.only(top: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.school, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            isEn
                                ? 'Board Pearls & Bedside Viva Question'
                                : 'ملاحظات البورد وسؤال الـ Viva على الحالة',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.brown),
                          ),
                        ],
                      ),
                      const Divider(),
                      if (p.vivaQuestion.isNotEmpty) ...[
                        Text(
                          '❓ ${isEn ? "Viva Question:" : "سؤال الـ Viva:"} ${p.vivaQuestion}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '💡 ${isEn ? "Model Answer:" : "الجواب النموذجي:"} ${p.vivaAnswer}',
                          style: const TextStyle(fontSize: 13.5),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (p.surgicalPearls.isNotEmpty)
                        Text(
                          '📌 ${isEn ? "Surgical Pearls:" : "الدروس الجراحية:"} ${p.surgicalPearls}',
                          style: const TextStyle(fontSize: 14),
                        ),
                    ],
                  ),
                ),
              ),
            _buildDetailsCard(
              isEn ? 'Chief Complaint, HPI & Diagnosis' : 'الشكوى، القصة المرضية (HPI)، والتشخيص',
              [
                _item(isEn ? 'Chief Complaint:' : 'الشكوى الرئيسية (Chief Complaint):', p.chiefComplaint),
                _item(isEn ? 'History of Present Illness (HPI):' : 'القصة المرضية التفصيلية (HPI):', p.hpi),
                _item(isEn ? 'Clinical Exam:' : 'الفحص السريري:', p.clinicalExam),
                _item(isEn ? 'Labs & Imaging Notes:' : 'ملاحظات التحاليل والأشعة:', p.labRadiologyNotes),
                _item(isEn ? 'Final Diagnosis:' : 'التشخيص النهائي:', p.diagnosis),
              ],
            ),
            _buildDetailsCard(
              isEn ? 'Histopathology & Oncology (TNM)' : 'الزرع النسيجي والأورام (Histopathology & TNM)',
              [
                _item(isEn ? 'Biopsy Status:' : 'حالة الزرع النسيجي:', p.biopsyStatus),
                _item(isEn ? 'Biopsy Result & Margins:' : 'نتيجة الزرع والحواف (Margins):', p.histopathologyResult),
                _item(isEn ? 'TNM Staging & MDT:' : 'تصنيف TNM وقرار اللجان:', p.tnmStaging),
              ],
            ),
            _buildDetailsCard(
              isEn ? 'Surgical Operation & Ward Care' : 'العملية الجراحية ومتابعة الردهة',
              [
                _item(isEn ? 'Procedure Name:' : 'اسم ونوع العملية:', p.plannedOperation),
                _item(isEn ? 'Urgency & Status:' : 'التصنيف والحالة:', '${p.operationUrgency} | ${p.operationStatus}'),
                _item(isEn ? 'Anesthesia & ASA:' : 'التخدير وتصنيف ASA:', '${p.anesthesiaType} (${p.asaScore})'),
                _item(isEn ? 'Operation Date:' : 'تاريخ العملية:', p.operationDate),
                _item(isEn ? 'Operative Notes:' : 'تفاصيل العملية (Operative Notes):', p.operativeNotes),
                _item(isEn ? 'Drains Tracker:' : 'متابعة الدرينات (Drains):', p.drainsInfo),
                _item(isEn ? 'DVT Prophylaxis:' : 'الوقاية الخثرية (DVT Prophylaxis):', p.dvtProphylaxis),
                _item(isEn ? 'Antibiotics:' : 'الصادات الحيوية (Antibiotics):', p.antibioticProphylaxis),
              ],
            ),
            _buildDetailsCard(
              isEn ? 'Past Medical & Surgical History' : 'التاريخ المرضي والجراحي السابق',
              [
                _item(isEn ? 'Chronic Diseases:' : 'الأمراض المزمنة:', p.chronicDiseases),
                _item(isEn ? 'Allergies:' : 'الحساسية الدوائية:', p.allergies),
                _item(isEn ? 'Current Medications:' : 'الأدوية المستمرة:', p.currentMedications),
                _item(isEn ? 'Smoking:' : 'التدخين:', p.smokingStatus),
                _item(isEn ? 'Past Surgeries:' : 'العمليات الجراحية السابقة:', p.pastSurgeries),
                _item(isEn ? 'Past Complications:' : 'مضاعفات سابقة:', p.pastComplications),
              ],
            ),
            _buildDetailsCard(
              isEn ? 'Final Outcome & Follow-up' : 'النتيجة النهائية والمتابعة',
              [
                _item(isEn ? 'Final Outcome:' : 'النتيجة النهائية:', p.finalOutcome),
                _item(isEn ? 'Complications (Clavien-Dindo):' : 'تصنيف المضاعفات (Clavien-Dindo):', p.clavienDindoGrade),
                _item(isEn ? 'Discharge Treatment:' : 'علاج الخروج وتوصيات الجرح:', p.dischargeTreatment),
                _item(isEn ? 'Next Follow-up Date:' : 'موعد المراجعة القادم:', p.followUpDate),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryCard(String title, List<String> paths, String categoryKey, IconData icon) {
    final isEn = widget.appLanguage == 'en';
    return Card(
      margin: const EdgeInsets.only(top: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      Icon(icon, color: AppColors.navyPrimary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5))),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _quickAddImage(categoryKey),
                  icon: const Icon(Icons.add_a_photo, size: 17),
                  label: Text(isEn ? 'Add Photo' : 'إضافة صورة'),
                ),
              ],
            ),
            if (paths.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  isEn
                      ? 'No photos attached yet — tap "Add Photo" to capture or pick from gallery'
                      : 'لا توجد صور مرفقة — اضغط "إضافة صورة" للتصوير أو الاختيار من الاستوديو',
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
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
                          border: Border.all(color: Colors.blueGrey.shade200),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sectionTitle,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.navyDark),
            ),
            const Divider(),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _item(String label, String val) {
    final isEn = widget.appLanguage == 'en';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.navyPrimary),
          ),
          Expanded(
            child: Text(
              val.isEmpty ? (isEn ? 'Not recorded' : 'غير مسجل') : val,
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 6. شاشة المقارنة البصرية التفاعلية الكاملة (قبل / بعد العملية - Before & After)
// ==========================================
class VisualComparisonScreen extends StatefulWidget {
  final String patientName;
  final List<MedicalPhotoItem> images;

  const VisualComparisonScreen({
    super.key,
    required this.patientName,
    required this.images,
  });

  @override
  State<VisualComparisonScreen> createState() => _VisualComparisonScreenState();
}

class _VisualComparisonScreenState extends State<VisualComparisonScreen> {
  int _beforeIndex = 0;
  int _afterIndex = 1;
  bool _isSliderMode = true;
  double _sliderPosition = 0.5;

  @override
  void initState() {
    super.initState();
    if (widget.images.length > 1) {
      _beforeIndex = 0;
      _afterIndex = widget.images.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final beforeImg = widget.images[_beforeIndex];
    final afterImg = widget.images[_afterIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF0A1118),
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        title: Text('Before / After: ${widget.patientName}', style: const TextStyle(fontSize: 15.5)),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.amberAccent),
            onPressed: () => setState(() => _isSliderMode = !_isSliderMode),
            icon: Icon(_isSliderMode ? Icons.grid_view_rounded : Icons.compare),
            label: Text(_isSliderMode ? 'Side-by-Side' : 'Split Slider'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _isSliderMode
                  ? _buildInteractiveSliderView(beforeImg.path, afterImg.path)
                  : _buildSideBySideView(beforeImg.path, afterImg.path),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            decoration: const BoxDecoration(
              color: Color(0xFF122338),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThumbnailSelectorRow(
                  title: '1. Pre-Op / Before Image:',
                  selectedIndex: _beforeIndex,
                  badgeColor: Colors.orange,
                  onSelect: (idx) => setState(() => _beforeIndex = idx),
                ),
                const SizedBox(height: 10),
                _buildThumbnailSelectorRow(
                  title: '2. Post-Op / After Image:',
                  selectedIndex: _afterIndex,
                  badgeColor: AppColors.statMintBorder,
                  onSelect: (idx) => setState(() => _afterIndex = idx),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveSliderView(String beforePath, String afterPath) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final splitX = maxW * _sliderPosition;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _sliderPosition = (details.localPosition.dx / maxW).clamp(0.05, 0.95);
            });
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.black,
                  child: File(afterPath).existsSync()
                      ? Image.file(File(afterPath), fit: BoxFit.contain)
                      : const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 64)),
                ),
                ClipRect(
                  clipper: _HorizontalSplitClipper(splitX),
                  child: Container(
                    color: Colors.black,
                    child: File(beforePath).existsSync()
                        ? Image.file(File(beforePath), fit: BoxFit.contain)
                        : const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 64)),
                  ),
                ),
                Positioned(
                  left: splitX - 18,
                  top: 0,
                  bottom: 0,
                  child: SizedBox(
                    width: 36,
                    height: maxH,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(width: 2.5, color: Colors.white),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.navyPrimary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
                          ),
                          child: const Icon(Icons.compare, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _overlayLabel('Pre-Op (قبل)', Colors.orange.shade800),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _overlayLabel('Post-Op (بعد)', AppColors.statMintBorder),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSideBySideView(String beforePath, String afterPath) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.black,
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5.0,
                    child: File(beforePath).existsSync()
                        ? Image.file(File(beforePath), fit: BoxFit.contain)
                        : const Icon(Icons.broken_image, color: Colors.white54),
                  ),
                ),
                Positioned(top: 8, right: 8, child: _overlayLabel('Pre-Op (قبل)', Colors.orange.shade800)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.black,
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5.0,
                    child: File(afterPath).existsSync()
                        ? Image.file(File(afterPath), fit: BoxFit.contain)
                        : const Icon(Icons.broken_image, color: Colors.white54),
                  ),
                ),
                Positioned(top: 8, right: 8, child: _overlayLabel('Post-Op (بعد)', AppColors.statMintBorder)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _overlayLabel(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg.withOpacity(0.88), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildThumbnailSelectorRow({
    required String title,
    required int selectedIndex,
    required Color badgeColor,
    required ValueChanged<int> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SizedBox(
          height: 66,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.images.length,
            itemBuilder: (ctx, i) {
              final item = widget.images[i];
              final isSelected = i == selectedIndex;
              return GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  width: 66,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? badgeColor : Colors.white24,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        File(item.path).existsSync()
                            ? Image.file(File(item.path), fit: BoxFit.cover)
                            : const Icon(Icons.broken_image, color: Colors.white),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              item.cat,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 8.5),
                            ),
                          ),
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
    );
  }
}

class _HorizontalSplitClipper extends CustomClipper<Rect> {
  final double splitWidth;
  _HorizontalSplitClipper(this.splitWidth);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, splitWidth, size.height);

  @override
  bool shouldReclip(covariant _HorizontalSplitClipper oldClipper) => oldClipper.splitWidth != splitWidth;
}
