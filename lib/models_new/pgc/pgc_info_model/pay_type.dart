class PayType {
  int? allowDiscount;
  int? allowPack;
  int? allowTicket;
  int? allowTimeLimit;
  int? allowVipDiscount;
  int? forbidBb;

  PayType({
    this.allowDiscount,
    this.allowPack,
    this.allowTicket,
    this.allowTimeLimit,
    this.allowVipDiscount,
    this.forbidBb,
  });

  factory PayType.fromJson(Map<String, dynamic> json) => PayType(
    allowDiscount: json['allow_discount'] as int?,
    allowPack: json['allow_pack'] as int?,
    allowTicket: json['allow_ticket'] as int?,
    allowTimeLimit: json['allow_time_limit'] as int?,
    allowVipDiscount: json['allow_vip_discount'] as int?,
    forbidBb: json['forbid_bb'] as int?,
  );
}
