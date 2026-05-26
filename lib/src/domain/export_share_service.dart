import 'package:share_plus/share_plus.dart';

class ExportShareService {
  const ExportShareService();

  Future<void> shareFile(String path) async {
    await Share.shareXFiles([XFile(path)]);
  }
}
