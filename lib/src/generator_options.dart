import 'package:bdd_widget_test/src/util/fs.dart';
import 'package:bdd_widget_test/src/util/isolate_helper.dart';
import 'package:yaml/yaml.dart';

const _defaultTestMethodName = 'testWidgets';
const _defaultTesterType = 'WidgetTester';
const _defaultTesterName = 'tester';
const _stepFolderName = './step';

class GeneratorOptions {
  const GeneratorOptions({
    String? testMethodName,
    List<String>? externalSteps,
    String? stepFolderName,
    String? testerType,
    String? testerName,
    this.include,
    this.additionalImports = const [],
    this.additionalContext = const [],
    this.skipBindingInitialization = false,
  })  : stepFolder = stepFolderName ?? _stepFolderName,
        testMethodName = testMethodName ?? _defaultTestMethodName,
        testerType = testerType ?? _defaultTesterType,
        testerName = testerName ?? _defaultTesterName,
        externalSteps = externalSteps ?? const [];

  factory GeneratorOptions.fromMap(Map<String, dynamic> json) =>
      GeneratorOptions(
        testMethodName: json['testMethodName'] as String?,
        testerType: json['testerType'] as String?,
        testerName: json['testerName'] as String?,
        externalSteps: (json['externalSteps'] as List?)?.cast<String>(),
        stepFolderName: json['stepFolderName'] as String?,
        include: switch (json['include']) {
          final String str => [str],
          final List<dynamic> list => list.cast<String>(),
          null => null,
          _ => throw UnimplementedError(),
        },
        additionalImports:
            (json['additionalImports'] as List?)?.cast<String>() ?? [],
        additionalContext:
            (json['additionalContext'] as List?)?.cast<String>() ?? [],
        skipBindingInitialization: json['skipBindingInitialization'] == true,
      );

  final String stepFolder;
  final String testMethodName;
  final String testerType;
  final String testerName;
  final List<String>? include;
  final List<String> externalSteps;
  final List<String> additionalImports;
  final List<String> additionalContext;
  final bool skipBindingInitialization;
}

Future<GeneratorOptions> flattenOptions(GeneratorOptions options) async {
  if (options.include?.isEmpty ?? true) {
    return options;
  }
  var resultOptions = options;
  for (final include in resultOptions.include!) {
    final includedOptions = await _readFromPackage(include);
    final newOptions = merge(resultOptions, includedOptions);
    resultOptions = await flattenOptions(newOptions);
  }

  return resultOptions;
}

Future<GeneratorOptions> _readFromPackage(String packageUri) async {
  final uri = await resolvePackageUri(
    Uri.parse(packageUri),
  );
  if (uri == null) {
    throw Exception('Could not read $packageUri');
  }
  return readFromUri(uri);
}

GeneratorOptions readFromUri(Uri uri) {
  final rawYaml = fs.file(uri).readAsStringSync();
  final doc = loadYamlNode(rawYaml) as YamlMap;
  return GeneratorOptions(
    testMethodName: doc['testMethodName'] as String?,
    testerType: doc['testerType'] as String?,
    testerName: doc['testerName'] as String?,
    externalSteps: (doc['externalSteps'] as List?)?.cast<String>(),
    stepFolderName: doc['stepFolderName'] as String?,
    include: doc['include'] is String
        ? [(doc['include'] as String)]
        : (doc['include'] as YamlList?)?.value.cast<String>(),
  );
}

GeneratorOptions merge(GeneratorOptions a, GeneratorOptions b) =>
    GeneratorOptions(
      testMethodName: a.testMethodName != _defaultTestMethodName
          ? a.testMethodName
          : b.testMethodName,
      testerType:
          a.testerType != _defaultTesterType ? a.testerType : b.testerType,
      testerName:
          a.testerName != _defaultTesterName ? a.testerName : b.testerName,
      stepFolderName:
          a.stepFolder != _stepFolderName ? a.stepFolder : b.stepFolder,
      externalSteps: [...a.externalSteps, ...b.externalSteps],
      include: b.include,
    );
