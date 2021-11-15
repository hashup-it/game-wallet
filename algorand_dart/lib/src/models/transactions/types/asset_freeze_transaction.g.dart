// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_freeze_transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssetFreezeTransaction _$AssetFreezeTransactionFromJson(
        Map<String, dynamic> json) =>
    AssetFreezeTransaction(
      freezeAddress: const AddressSerializer().fromJson(json['fadd']),
      assetId: json['faid'] as int?,
      freeze: json['afrz'] as bool?,
      fee: json['fee'] as int?,
      firstValid: json['fv'] as int?,
      genesisHash: const NullableByteArraySerializer().fromJson(json['gh']),
      lastValid: json['lv'] as int?,
      sender: const AddressSerializer().fromJson(json['snd']),
      type: json['type'] as String?,
      genesisId: json['gen'] as String?,
      group: const Base32Serializer().fromJson(json['grp']),
      lease: const NullableByteArraySerializer().fromJson(json['lx']),
      note: const NullableByteArraySerializer().fromJson(json['note']),
      rekeyTo: json['rekey'] as String?,
    );

Map<String, dynamic> _$AssetFreezeTransactionToJson(
        AssetFreezeTransaction instance) =>
    <String, dynamic>{
      'fee': instance.fee,
      'fv': instance.firstValid,
      'gh': const NullableByteArraySerializer().toJson(instance.genesisHash),
      'lv': instance.lastValid,
      'snd': const AddressSerializer().toJson(instance.sender),
      'type': instance.type,
      'gen': instance.genesisId,
      'grp': const Base32Serializer().toJson(instance.group),
      'lx': const NullableByteArraySerializer().toJson(instance.lease),
      'note': const NullableByteArraySerializer().toJson(instance.note),
      'rekey': instance.rekeyTo,
      'fadd': const AddressSerializer().toJson(instance.freezeAddress),
      'faid': instance.assetId,
      'afrz': instance.freeze,
    };
