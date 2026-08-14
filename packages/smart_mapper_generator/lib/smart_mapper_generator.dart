import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/smart_mapper_generator.dart';

/// Creates the shared-part builder used by `build_runner`.
Builder smartMapperBuilder(BuilderOptions options) =>
    SharedPartBuilder([SmartMapperGenerator()], 'smart_mapper');
