// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Payment _$PaymentFromJson(Map<String, dynamic> json) => Payment(
      receiver: json['receiver'] as String,
      amount: json['amount'] as int,
      closeAmount: json['close-amount'] as int?,
      closeRemainderTo: json['close-remainder-to'] as String?,
    );

Map<String, dynamic> _$PaymentToJson(Payment instance) => <String, dynamic>{
      'receiver': instance.receiver,
      'amount': instance.amount,
      'close-amount': instance.closeAmount,
      'close-remainder-to': instance.closeRemainderTo,
    };
