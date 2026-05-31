import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../services/report_service.dart';

const _reasons = ['스팸', '욕설 / 혐오 표현', '부적절한 콘텐츠', '기타'];

Future<void> showReportSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
}) async {
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Text(
                      '신고 사유를 선택해주세요',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  const Divider(height: 1),
                  ..._reasons.asMap().entries.map((e) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            title: Text(e.value),
                            onTap: () async {
                              Navigator.pop(context);
                              try {
                                await ReportService().report(
                                  targetType: targetType,
                                  targetId: targetId,
                                  reason: e.value,
                                );
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        '신고가 접수됐어요. 검토 후 조치할게요 🐾'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              } catch (err) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text('신고 실패: $err'),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                          if (e.key < _reasons.length - 1)
                            const Divider(height: 1),
                        ],
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                onTap: () => Navigator.pop(context),
                title: const Text(
                  '취소',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
