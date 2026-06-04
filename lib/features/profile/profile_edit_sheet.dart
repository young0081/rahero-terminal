import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'profile_data.dart';

/// 弹出编辑个人资料的底部面板。
Future<void> showProfileEditSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surfaceHigh,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ProfileEditSheet(),
  );
}

class _ProfileEditSheet extends ConsumerStatefulWidget {
  const _ProfileEditSheet();

  @override
  ConsumerState<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<_ProfileEditSheet> {
  late final TextEditingController _nickname;
  late final TextEditingController _signature;
  late final TextEditingController _uid;
  late final TextEditingController _favoriteRole;
  late final TextEditingController _region;

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider);
    _nickname = TextEditingController(text: p.nickname);
    _signature = TextEditingController(text: p.signature);
    _uid = TextEditingController(text: p.uid);
    _favoriteRole = TextEditingController(text: p.favoriteRole);
    _region = TextEditingController(text: p.region);
  }

  @override
  void dispose() {
    _nickname.dispose();
    _signature.dispose();
    _uid.dispose();
    _favoriteRole.dispose();
    _region.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = ref.read(profileProvider);
    await ref.read(profileProvider.notifier).save(p.copyWith(
          nickname: _nickname.text.trim(),
          signature: _signature.text.trim(),
          uid: _uid.text.trim(),
          favoriteRole: _favoriteRole.text.trim(),
          region: _region.text.trim(),
        ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppDimens.gapLg, 0, AppDimens.gapLg, AppDimens.gapLg + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimens.gapSm),
            const Text('编辑资料',
                style: TextStyle(
                    color: AppColors.silver,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: AppDimens.gapMd),
            _field('昵称', _nickname, hint: '给自己起个名字'),
            _field('个性签名', _signature, hint: '一句话介绍自己', maxLines: 2),
            _field('游戏 UID', _uid, hint: '可选，连接游戏数据时用', keyboard: TextInputType.number),
            _field('常用角色', _favoriteRole, hint: '可选'),
            _field('所属势力', _region, hint: '可选，如 星炬学院'),
            const SizedBox(height: AppDimens.gapMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: AppDimens.gapSm),
                FilledButton(
                  onPressed: _save,
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {String? hint, int maxLines = 1, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.steel, fontSize: 13)),
          const SizedBox(height: 4),
          TextField(
            controller: c,
            maxLines: maxLines,
            keyboardType: keyboard,
            style: const TextStyle(color: AppColors.silver, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(color: AppColors.textMuted, fontSize: 13),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.gapMd, vertical: AppDimens.gapSm),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                borderSide: const BorderSide(color: AppColors.coolAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
