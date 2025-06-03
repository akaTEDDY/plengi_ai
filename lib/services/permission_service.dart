import 'package:flutter/material.dart';

class PermissionInfo {
  final String name;
  final String description;
  final bool isRequired;
  final String permissionType;

  const PermissionInfo({
    required this.name,
    required this.description,
    required this.permissionType,
    this.isRequired = true,
  });
}

class PermissionService {
  static final List<PermissionInfo> requiredPermissions = [
    const PermissionInfo(
      name: '위치 권한',
      description: '사용자의 위치 기반 서비스 제공 및 주변 정보 표시',
      permissionType: 'location',
    ),
  ];

  static final List<PermissionInfo> optionalPermissions = [
    const PermissionInfo(
      name: '알림 권한',
      description: '위치 기반 서비스 상태 및 중요 알림 수신',
      permissionType: 'notification',
      isRequired: false,
    ),
    // Android 10+ 백그라운드 위치 권한은 별도 요청 시 고려
    // const PermissionInfo(
    //   name: '백그라운드 위치 권한',
    //   description: '앱이 백그라운드에 있을 때도 위치 기반 서비스 제공',
    //   permissionType: 'background_location',
    //   isRequired: false,
    // ),
  ];

  static Future<bool> showPermissionDialog(
    BuildContext context,
    // showSettingsButton 매개변수는 더 이상 사용하지 않음
    // bool showSettingsButton = true,
  ) async {
    // 필수 및 선택 권한 목록을 결합
    final targetPermissions = [...requiredPermissions, ...optionalPermissions];

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          // 이미지와 유사한 제목 적용
          title: const Text('권한 수신 동의 안내'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이미지와 유사한 설명 문구 추가
                const Text('앱 사용을 위해 다음 권한에 동의하고 혜택을 받아보시겠어요?'),
                const SizedBox(height: 16),
                // 선택 권한 정보 (카운트는 동적으로 표시하지 않음)
                // const Text('선택 권한'),
                // const SizedBox(height: 8),

                // 권한 목록 표시 (이미지의 [수신 항목]과 유사하게)
                const Text('[필요 권한 항목]'),
                const SizedBox(height: 4),
                ...targetPermissions.asMap().entries.map((entry) {
                  int index = entry.key;
                  PermissionInfo permission = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      '${index + 1}. ${permission.name}: ${permission.description}',
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),

                // 이미지 하단의 안내 문구 추가
                const Text(
                  '* 권한 동의 변경은 앱 설정에서 변경 가능합니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            // 이미지와 동일한 버튼 구성 및 문구 적용
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // '다음에 하기'는 false 반환
              },
              child: const Text('다음에 하기'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // '예'는 true 반환
              },
              child: const Text('예'),
            ),
            // '자세히 보기' 또는 '설정으로 이동' 버튼은 필요시 추가
            // 현재는 '다음에 하기' 선택 시 main.dart에서 설정 이동 옵션을 제공
          ],
        );
      },
    );

    return result ?? false; // 다이얼로그가 닫히면 false 반환
  }
}
