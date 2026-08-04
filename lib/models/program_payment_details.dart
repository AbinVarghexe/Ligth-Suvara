class ProgramPaymentDetails {
  final bool isRequired;
  final double registrationFee;
  final int advancePercentage;
  final String advanceType; // 'percentage' | 'fixed'
  final double advanceValue;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String ifscCode;
  final String qrCodeUrl;

  ProgramPaymentDetails({
    required this.isRequired,
    required this.registrationFee,
    required this.advancePercentage,
    required this.advanceType,
    required this.advanceValue,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.ifscCode,
    required this.qrCodeUrl,
  });

  factory ProgramPaymentDetails.fromMap(Map<String, dynamic> map) {
    final isReq = map['isRequired'] ?? false;
    final regFee = (map['registrationFee'] ?? 0).toDouble();
    final advType = map['advanceType'] ?? 'percentage';
    
    // For fallback/backward compatibility:
    final int legacyPercentage = map['advancePercentage'] ?? 100;
    final double advValue = (map['advanceValue'] ?? legacyPercentage).toDouble();
    final int finalPercentage = advType == 'percentage' ? advValue.toInt() : 100;

    return ProgramPaymentDetails(
      isRequired: isReq,
      registrationFee: regFee,
      advancePercentage: finalPercentage,
      advanceType: advType,
      advanceValue: advValue,
      bankName: map['bankName'] ?? '',
      accountName: map['accountName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      ifscCode: map['ifscCode'] ?? '',
      qrCodeUrl: map['qrCodeUrl'] ?? '',
    );
  }
}
