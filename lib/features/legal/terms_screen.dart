import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/error_message.dart';

/// 이용약관 시행일. 약관을 바꾸면 이 날짜와 아래 내용을 함께 고친다(docs/policies/terms.txt 와 같게).
const termsEffectiveDate = '2026년 10월 19일';

const _operator = AppConstants.operatorName;
const _email = AppConstants.contactEmail;

const _articles = <(String, List<String>)>[
  ('제1조 (목적)', [
    '이 약관은 $_operator(이하 "운영자")이 제공하는 매일재라 앱(이하 "서비스")을 이용하는 데 필요한 운영자와 이용자의 권리, 의무, 책임을 정합니다.',
  ]),
  ('제2조 (서비스 내용)', [
    '1. 서비스는 이용자가 체중, 눈바디 사진, 식단, 운동을 기록하고, 초대한 그룹 멤버와 기록을 나누며 서로 응원하는 기능을 제공합니다.',
    '2. 기록에 따라 포인트와 연속 출석(스트릭)이 쌓입니다. 포인트는 서비스 안에서만 쓰는 표시이며 현금이나 다른 재화로 바꿀 수 없습니다.',
    '3. 운영자는 서비스의 내용을 바꾸거나 일부를 그만둘 수 있습니다. 이용자에게 중요한 변경은 앱 안에서 미리 알립니다.',
  ]),
  ('제3조 (가입과 계정)', [
    '1. 만 14세 이상이면 아이디와 비밀번호를 만들어 가입할 수 있습니다.',
    '2. 이용자는 자기 계정과 비밀번호를 스스로 관리합니다. 다른 사람에게 계정을 빌려주거나 다른 사람의 계정을 쓰면 안 됩니다.',
    '3. 다른 사람을 사칭하거나 오해를 일으키는 아이디와 닉네임은 쓸 수 없습니다.',
  ]),
  ('제4조 (그룹과 공유)', [
    '1. 이용자가 올린 체중, 사진, 식단, 운동 기록, 댓글은 같은 그룹 멤버에게 보입니다. 그룹 밖의 사람에게는 공개되지 않습니다.',
    '2. 그룹에 새로 들어온 멤버는 그 그룹 멤버들의 이전 기록도 볼 수 있습니다.',
    '3. 초대 코드는 함께할 사람에게만 알려 주세요. 방장은 초대 코드를 바꾸고 멤버를 내보낼 수 있습니다. 내보내진 멤버는 같은 그룹에 다시 들어올 수 없습니다.',
  ]),
  ('제5조 (올리면 안 되는 내용)', [
    '다음과 같은 사진, 글, 댓글은 올릴 수 없습니다.',
    '1. 성적인 노출이나 음란한 내용',
    '2. 다른 사람을 괴롭히거나, 모욕하거나, 차별하거나, 위협하는 내용',
    '3. 다른 사람의 동의 없이 그 사람이 나온 사진이나 개인정보',
    '4. 폭력, 자해, 극단적인 다이어트나 섭식 장애를 부추기는 내용',
    '5. 광고, 홍보, 스팸, 같은 내용을 반복해서 올리는 행위',
    '6. 불법이거나 다른 사람의 권리(저작권, 초상권 등)를 침해하는 내용',
  ]),
  ('제6조 (신고, 차단, 조치)', [
    '1. 이용자는 멤버 방이나 사진·댓글 화면에서 문제가 되는 멤버, 사진, 댓글을 신고할 수 있습니다. 신고한 사람은 상대에게 알려지지 않습니다.',
    '2. 이용자는 다른 멤버를 차단할 수 있습니다. 차단하면 그 멤버의 사진과 댓글이 보이지 않고, 그 멤버는 나를 찌를 수 없습니다.',
    '3. 운영자는 신고를 받으면 확인하고, 제5조를 어긴 내용을 지우거나, 계정 이용을 제한하거나, 계정을 해지할 수 있습니다.',
    '4. 이용자는 자기 댓글과 자기 사진에 달린 댓글을 지울 수 있습니다.',
  ]),
  ('제7조 (건강 정보에 관한 안내)', [
    '1. 서비스의 BMI, 체중 변화, 운동 볼륨, 증량 제안 같은 정보는 기록을 돕기 위한 참고용이며 의학적 진단이나 처방이 아닙니다.',
    '2. 건강 상태가 걱정되거나 식단·운동을 크게 바꾸려면 의사나 전문가와 먼저 상담하세요.',
    '3. 운동은 자신의 몸 상태에 맞게 하세요. 서비스의 제안을 따르다 다쳐도 운영자의 고의나 중대한 과실이 없으면 운영자는 책임지지 않습니다.',
  ]),
  ('제8조 (회원 탈퇴)', [
    '1. 이용자는 언제든 앱의 마이페이지 > 회원 탈퇴에서 탈퇴할 수 있습니다.',
    '2. 탈퇴하면 이용자의 기록, 사진, 댓글, 포인트, 스트릭이 바로 지워지고 되돌릴 수 없습니다. 그룹에서는 나가게 되고, 방장이면 다음 멤버가 방장이 됩니다.',
    '3. 앱을 쓸 수 없는 경우에는 $_email 로 탈퇴를 요청할 수 있습니다.',
  ]),
  ('제9조 (책임의 한계)', [
    '1. 운영자는 천재지변, 통신 장애, 서버 업체의 장애처럼 운영자가 막을 수 없는 일로 서비스를 제공하지 못하면 책임지지 않습니다.',
    '2. 이용자가 올린 내용에 대한 책임은 그것을 올린 이용자에게 있습니다.',
    '3. 서비스는 무료로 제공되며, 운영자는 법이 허용하는 범위에서 서비스 이용으로 생긴 간접적인 손해에 책임지지 않습니다.',
  ]),
  ('제10조 (약관의 변경)', [
    '운영자가 약관을 바꾸면 시행일 7일 전부터 앱 안에서 알립니다. 이용자에게 불리한 변경은 30일 전부터 알립니다. 바뀐 약관에 동의하지 않으면 탈퇴할 수 있습니다.',
  ]),
  ('제11조 (준거법과 분쟁)', [
    '이 약관은 대한민국 법을 따릅니다. 서비스와 관련한 분쟁은 민사소송법에 따른 관할 법원에서 다룹니다.',
  ]),
];

/// 이용약관. 웹에 올리지 않고 앱 안에 그대로 담는다. 로그인 전(가입 화면)에서도 열린다.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('이용약관')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, AppSpacing.page * 2),
        children: [
          const Text('시행일: $termsEffectiveDate', style: AppText.label),
          for (final (title, lines) in _articles) ...[
            const SizedBox(height: 20),
            Text(title, style: AppText.title),
            const SizedBox(height: 6),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line, style: AppText.body.copyWith(height: 1.5)),
              ),
          ],
          const SizedBox(height: 24),
          const Text('문의: $_email', style: AppText.label),
        ],
      ),
    );
  }
}

/// 개인정보처리방침(웹 페이지)을 브라우저로 연다.
Future<void> openPrivacyPolicy(BuildContext context) async {
  try {
    final ok = await launchUrl(Uri.parse(AppConstants.privacyPolicyUrl), mode: LaunchMode.externalApplication);
    if (!ok) throw StateError('브라우저를 열 수 없어요.');
  } catch (error) {
    if (context.mounted) showErrorSnack(context, error);
  }
}

/// 가입 화면과 마이페이지에 두는 [이용약관] · [개인정보처리방침] 링크 한 줄.
class PolicyLinks extends StatelessWidget {
  const PolicyLinks({super.key, required this.onTerms});

  final VoidCallback onTerms;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: AppColors.muted,
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(style: style, onPressed: onTerms, child: const Text('이용약관')),
        const Text('·', style: TextStyle(color: AppColors.faint)),
        TextButton(style: style, onPressed: () => openPrivacyPolicy(context), child: const Text('개인정보처리방침')),
      ],
    );
  }
}
