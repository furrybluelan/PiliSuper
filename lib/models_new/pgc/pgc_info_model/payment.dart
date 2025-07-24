import 'package:PiliPlus/models_new/pgc/pgc_info_model/pay_type.dart';

class Payment {
  int? discount;
  PayType? payType;
  String? price;
  String? promotion;
  String? tip;
  int? viewStartTime;
  int? vipDiscount;
  String? vipFirstPromotion;
  String? vipPrice;
  String? vipPromotion;

  Payment({
    this.discount,
    this.payType,
    this.price,
    this.promotion,
    this.tip,
    this.viewStartTime,
    this.vipDiscount,
    this.vipFirstPromotion,
    this.vipPrice,
    this.vipPromotion,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    discount: json['discount'] as int?,
    payType: json['pay_type'] == null
        ? null
        : PayType.fromJson(json['pay_type'] as Map<String, dynamic>),
    price: json['price'] as String?,
    promotion: json['promotion'] as String?,
    tip: json['tip'] as String?,
    viewStartTime: json['view_start_time'] as int?,
    vipDiscount: json['vip_discount'] as int?,
    vipFirstPromotion: json['vip_first_promotion'] as String?,
    vipPrice: json['vip_price'] as String?,
    vipPromotion: json['vip_promotion'] as String?,
  );
}
