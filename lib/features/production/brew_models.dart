class BrewCktOption {
  const BrewCktOption({
    required this.uid,
    required this.name,
    required this.organizationUid,
    required this.capacity,
  });

  final String uid;
  final String name;
  final String organizationUid;
  final double capacity;

  factory BrewCktOption.fromJson(Map<String, dynamic> json) => BrewCktOption(
        uid: json['uid']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        organizationUid: json['organizationUid']?.toString() ?? '',
        capacity: _brewDouble(json['capacity']),
      );
}

class BrewRecipeOption {
  const BrewRecipeOption({
    required this.organizationUid,
    required this.productUid,
    required this.productName,
    required this.batchVolume,
    required this.portionSize,
    required this.specificationUid,
    required this.specificationName,
  });

  final String organizationUid;
  final String productUid;
  final String productName;
  final double batchVolume;
  final double portionSize;
  final String specificationUid;
  final String specificationName;

  String get key => '$productUid|$specificationUid|$batchVolume';

  factory BrewRecipeOption.fromJson(Map<String, dynamic> json) =>
      BrewRecipeOption(
        organizationUid: json['organizationUid']?.toString() ?? '',
        productUid: json['productUid']?.toString() ?? '',
        productName: json['productName']?.toString() ?? '',
        batchVolume: _brewDouble(json['batchVolume'] ?? json['portionSize']),
        portionSize: _brewDouble(json['portionSize']) > 0
            ? _brewDouble(json['portionSize'])
            : 2000,
        specificationUid: json['specificationUid']?.toString() ?? '',
        specificationName: json['specificationName']?.toString() ?? '',
      );
}

class BrewOptions {
  const BrewOptions({required this.ckts, required this.recipes});

  final List<BrewCktOption> ckts;
  final List<BrewRecipeOption> recipes;

  factory BrewOptions.fromJson(Map<String, dynamic> json) => BrewOptions(
        ckts: (json['ckts'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) =>
                BrewCktOption.fromJson(Map<String, dynamic>.from(item)))
            .where((item) => item.uid.isNotEmpty)
            .toList(),
        recipes: (json['recipes'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) =>
                BrewRecipeOption.fromJson(Map<String, dynamic>.from(item)))
            .where((item) =>
                item.productUid.isNotEmpty &&
                item.specificationUid.isNotEmpty &&
                item.batchVolume > 0)
            .toList(),
      );
}

class BrewStandard {
  const BrewStandard({
    this.mashPh = 0,
    this.waterQuantity = 0,
    this.waterTemperature = 0,
    this.mashPauses = const [],
  });

  final double mashPh;
  final double waterQuantity;
  final double waterTemperature;
  final List<Map<String, dynamic>> mashPauses;

  bool get hasValues =>
      mashPh > 0 ||
      waterQuantity > 0 ||
      waterTemperature > 0 ||
      mashPauses.isNotEmpty;

  factory BrewStandard.fromJson(Map<String, dynamic> json) => BrewStandard(
        mashPh: _brewDouble(json['mashPh']),
        waterQuantity: _brewDouble(json['waterQuantity']),
        waterTemperature: _brewDouble(json['waterTemperature']),
        mashPauses: _brewRows(json['mashPauses']),
      );
}

class BrewPortion {
  const BrewPortion({
    required this.id,
    required this.number,
    required this.portionNumber,
    required this.status,
    required this.plannedVolume,
    required this.actualVolume,
    this.brewDate,
    this.startedAt,
    this.finishedAt,
    this.responsibleName = '',
    this.specificationName = '',
    this.mashPh = 0,
    this.waterQuantity = 0,
    this.waterTemperature = 0,
    this.mashTunVolume = 0,
    this.iodineTestAt,
    this.boilStartedAt,
    this.boilFinishedAt,
    this.plannedBoilMinutes = 0,
    this.preBoilVolume = 0,
    this.preBoilScaleVolume = 0,
    this.preBoilDensity = 0,
    this.postBoilDensity = 0,
    this.whirlpoolVolume = 0,
    this.wortTemperature = 0,
    this.coldWortDensity = 0,
    this.actualCktName = '',
    this.comment = '',
    this.materials = const [],
    this.mashPauses = const [],
    this.filtrationSteps = const [],
    this.additions = const [],
    this.operations = const [],
  });

  final String id;
  final String number;
  final int portionNumber;
  final String status;
  final double plannedVolume;
  final double actualVolume;
  final DateTime? brewDate;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String responsibleName;
  final String specificationName;
  final double mashPh;
  final double waterQuantity;
  final double waterTemperature;
  final double mashTunVolume;
  final DateTime? iodineTestAt;
  final DateTime? boilStartedAt;
  final DateTime? boilFinishedAt;
  final double plannedBoilMinutes;
  final double preBoilVolume;
  final double preBoilScaleVolume;
  final double preBoilDensity;
  final double postBoilDensity;
  final double whirlpoolVolume;
  final double wortTemperature;
  final double coldWortDensity;
  final String actualCktName;
  final String comment;
  final List<Map<String, dynamic>> materials;
  final List<Map<String, dynamic>> mashPauses;
  final List<Map<String, dynamic>> filtrationSteps;
  final List<Map<String, dynamic>> additions;
  final List<Map<String, dynamic>> operations;

  factory BrewPortion.fromJson(Map<String, dynamic> json) => BrewPortion(
        id: json['id']?.toString() ?? '',
        number: json['number']?.toString() ?? '',
        portionNumber:
            int.tryParse(json['portionNumber']?.toString() ?? '') ?? 0,
        status: json['status']?.toString() ?? '',
        plannedVolume: _brewDouble(json['plannedVolume']),
        actualVolume: _brewDouble(json['actualVolume']),
        brewDate: _brewDate(json['brewDate']),
        startedAt: _brewDate(json['startedAt']),
        finishedAt: _brewDate(json['finishedAt']),
        responsibleName: json['responsibleName']?.toString() ?? '',
        specificationName: json['specificationName']?.toString() ?? '',
        mashPh: _brewDouble(json['mashPh']),
        waterQuantity: _brewDouble(json['waterQuantity']),
        waterTemperature: _brewDouble(json['waterTemperature']),
        mashTunVolume: _brewDouble(json['mashTunVolume']),
        iodineTestAt: _brewDate(json['iodineTestAt']),
        boilStartedAt: _brewDate(json['boilStartedAt']),
        boilFinishedAt: _brewDate(json['boilFinishedAt']),
        plannedBoilMinutes: _brewDouble(json['plannedBoilMinutes']),
        preBoilVolume: _brewDouble(json['preBoilVolume']),
        preBoilScaleVolume: _brewDouble(json['preBoilScaleVolume']),
        preBoilDensity: _brewDouble(json['preBoilDensity']),
        postBoilDensity: _brewDouble(json['postBoilDensity']),
        whirlpoolVolume: _brewDouble(json['whirlpoolVolume']),
        wortTemperature: _brewDouble(json['wortTemperature']),
        coldWortDensity: _brewDouble(json['coldWortDensity']),
        actualCktName: json['actualCktName']?.toString() ?? '',
        comment: json['comment']?.toString() ?? '',
        materials: _brewRows(json['materials']),
        mashPauses: _brewRows(json['mashPauses']),
        filtrationSteps: _brewRows(json['filtrationSteps']),
        additions: _brewRows(json['additions']),
        operations: _brewRows(json['operations']),
      );
}

class BrewPortionUpdate {
  const BrewPortionUpdate({
    required this.id,
    this.mashStartedAt,
    required this.mashPh,
    required this.waterQuantity,
    required this.waterTemperature,
    required this.mashTunVolume,
    this.iodineTestAt,
    this.boilStartedAt,
    this.boilFinishedAt,
    required this.plannedBoilMinutes,
    required this.preBoilVolume,
    required this.preBoilScaleVolume,
    required this.preBoilDensity,
    required this.postBoilDensity,
    required this.whirlpoolVolume,
    required this.wortTemperature,
    required this.comment,
    required this.materials,
    required this.mashPauses,
    required this.filtrationSteps,
    required this.additions,
    required this.operations,
  });

  final String id;
  final DateTime? mashStartedAt;
  final double mashPh;
  final double waterQuantity;
  final double waterTemperature;
  final double mashTunVolume;
  final DateTime? iodineTestAt;
  final DateTime? boilStartedAt;
  final DateTime? boilFinishedAt;
  final double plannedBoilMinutes;
  final double preBoilVolume;
  final double preBoilScaleVolume;
  final double preBoilDensity;
  final double postBoilDensity;
  final double whirlpoolVolume;
  final double wortTemperature;
  final String comment;
  final List<Map<String, dynamic>> materials;
  final List<Map<String, dynamic>> mashPauses;
  final List<Map<String, dynamic>> filtrationSteps;
  final List<Map<String, dynamic>> additions;
  final List<Map<String, dynamic>> operations;

  Map<String, dynamic> toJson(String action) => {
        'id': id,
        'action': action,
        'mashStartedAt': mashStartedAt?.toIso8601String(),
        'mashPh': mashPh,
        'waterQuantity': waterQuantity,
        'waterTemperature': waterTemperature,
        'mashTunVolume': mashTunVolume,
        'iodineTestAt': iodineTestAt?.toIso8601String(),
        'boilStartedAt': boilStartedAt?.toIso8601String(),
        'boilFinishedAt': boilFinishedAt?.toIso8601String(),
        'plannedBoilMinutes': plannedBoilMinutes,
        'preBoilVolume': preBoilVolume,
        'preBoilScaleVolume': preBoilScaleVolume,
        'preBoilDensity': preBoilDensity,
        'postBoilDensity': postBoilDensity,
        'whirlpoolVolume': whirlpoolVolume,
        'wortTemperature': wortTemperature,
        'comment': comment.trim(),
        'materials': materials,
        'mashPauses': mashPauses,
        'filtrationSteps': filtrationSteps,
        'additions': additions,
        'operations': operations,
      };
}

class BrewPassport {
  const BrewPassport({
    required this.id,
    required this.number,
    required this.batchNumber,
    required this.organizationUid,
    required this.organizationName,
    required this.productUid,
    required this.productName,
    required this.cktUid,
    required this.cktName,
    required this.plannedVolume,
    required this.portionSize,
    required this.portionCount,
    required this.status,
    required this.createdAt,
    this.plannedBottlingDate,
    this.specificationUid = '',
    this.specificationName = '',
    this.responsibleName = '',
    this.actualVolume = 0,
    this.finalDensity = 0,
    this.startedAt,
    this.finishedAt,
    this.comment = '',
    this.standard = const BrewStandard(),
    this.portions = const [],
  });

  final String id;
  final String number;
  final String batchNumber;
  final String organizationUid;
  final String organizationName;
  final String productUid;
  final String productName;
  final String cktUid;
  final String cktName;
  final double plannedVolume;
  final double portionSize;
  final int portionCount;
  final DateTime? plannedBottlingDate;
  final String specificationUid;
  final String specificationName;
  final String status;
  final String responsibleName;
  final double actualVolume;
  final double finalDensity;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String comment;
  final BrewStandard standard;
  final List<BrewPortion> portions;

  factory BrewPassport.fromJson(Map<String, dynamic> json) => BrewPassport(
        id: json['id']?.toString() ?? '',
        number: json['number']?.toString() ?? '',
        batchNumber: json['batchNumber']?.toString() ?? '',
        organizationUid: json['organizationUid']?.toString() ?? '',
        organizationName: json['organizationName']?.toString() ?? '',
        productUid: json['productUid']?.toString() ?? '',
        productName: json['productName']?.toString() ?? '',
        cktUid: json['cktUid']?.toString() ?? '',
        cktName: json['cktName']?.toString() ?? '',
        plannedVolume: _brewDouble(json['plannedVolume']),
        portionSize: _brewDouble(json['portionSize']),
        portionCount: int.tryParse(json['portionCount']?.toString() ?? '') ?? 0,
        plannedBottlingDate: _brewDate(json['plannedBottlingDate']),
        specificationUid: json['specificationUid']?.toString() ?? '',
        specificationName: json['specificationName']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        responsibleName: json['responsibleName']?.toString() ?? '',
        actualVolume: _brewDouble(json['actualVolume']),
        finalDensity: _brewDouble(json['finalDensity']),
        createdAt: _brewDate(json['createdAt']) ?? DateTime.now(),
        startedAt: _brewDate(json['startedAt']),
        finishedAt: _brewDate(json['finishedAt']),
        comment: json['comment']?.toString() ?? '',
        standard: json['brewStandard'] is Map
            ? BrewStandard.fromJson(
                Map<String, dynamic>.from(json['brewStandard'] as Map),
              )
            : const BrewStandard(),
        portions: (json['portions'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => BrewPortion.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList(),
      );
}

class CreateBrewPassportDraft {
  const CreateBrewPassportDraft({
    required this.organizationUid,
    required this.productUid,
    required this.cktUid,
    required this.specificationUid,
    required this.plannedVolume,
    required this.portionSize,
    required this.portionCount,
    this.plannedBottlingDate,
    this.comment = '',
  });

  final String organizationUid;
  final String productUid;
  final String cktUid;
  final String specificationUid;
  final double plannedVolume;
  final double portionSize;
  final int portionCount;
  final DateTime? plannedBottlingDate;
  final String comment;

  Map<String, dynamic> toJson() => {
        'organizationUid': organizationUid,
        'productUid': productUid,
        'cktUid': cktUid,
        'specificationUid': specificationUid,
        'plannedVolume': plannedVolume,
        'portionSize': portionSize,
        'portionCount': portionCount,
        if (plannedBottlingDate != null)
          'plannedBottlingDate':
              plannedBottlingDate!.toIso8601String().substring(0, 10),
        'comment': comment.trim(),
      };
}

List<Map<String, dynamic>> _brewRows(dynamic value) =>
    (value as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

double _brewDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}

DateTime? _brewDate(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}
