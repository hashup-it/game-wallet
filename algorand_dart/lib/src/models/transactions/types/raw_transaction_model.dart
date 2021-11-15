import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:algorand_dart/src/models/models.dart';
import 'package:algorand_dart/src/utils/crypto_utils.dart';
import 'package:algorand_dart/src/utils/encoders/msgpack_encoder.dart';
import 'package:algorand_dart/src/utils/serializers/address_serializer.dart';
import 'package:algorand_dart/src/utils/serializers/base32_serializer.dart';
import 'package:algorand_dart/src/utils/serializers/byte_array_serializer.dart';
import 'package:algorand_dart/src/utils/transformers/address_transformer.dart';
import 'package:algorand_dart/src/utils/utils.dart';
import 'package:base32/base32.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'raw_transaction_model.g.dart';

/// A raw serializable transaction class, used to generate transactions to
/// broadcast to the network.
///
/// Algorand's msgpack encoding follows to following rules -
///  1. Every integer must be encoded to the smallest type possible
///  (0-255->8bit, 256-65535->16bit, etx)
///  2. All fields names must be sorted
///  3. All empty and 0 fields should be omitted
///  4. Every positive number must be encoded as uint
///  5. Binary blob should be used for binary data and string for strings
@JsonSerializable(fieldRename: FieldRename.kebab)
class RawTransaction extends Equatable {
  /// The prefix for a transaction.
  static const TX_PREFIX = 'TX';

  /// The minimum transaction fees (in micro algos).
  static const MIN_TX_FEE_UALGOS = 1000;

  /// Paid by the sender to the FeeSink to prevent denial-of-service.
  /// The minimum fee on Algorand is currently 1000 microAlgos.
  /// This field cannot be combined with flat fee.
  @JsonKey(name: 'fee')
  int? fee;

  /// The first round for when the transaction is valid.
  /// If the transaction is sent prior to this round it will be rejected by
  /// the network.
  @JsonKey(name: 'fv')
  final int? firstValid;

  /// The hash of the genesis block of the network for which the transaction
  /// is valid. See the genesis hash for MainNet, TestNet, and BetaNet.
  @JsonKey(name: 'gh')
  @NullableByteArraySerializer()
  final Uint8List? genesisHash;

  /// The ending round for which the transaction is valid.
  /// After this round, the transaction will be rejected by the network.
  @JsonKey(name: 'lv')
  final int? lastValid;

  /// The address of the account that pays the fee and amount.
  @JsonKey(name: 'snd')
  @AddressSerializer()
  final Address? sender;

  /// Specifies the type of transaction.
  /// This value is automatically generated using any of the developer tools.
  @JsonKey(name: 'type')
  final String? type;

  /// The human-readable string that identifies the network for the transaction.
  /// The genesis ID is found in the genesis block.
  ///
  /// See the genesis ID for MainNet, TestNet, and BetaNet.
  @JsonKey(name: 'gen')
  final String? genesisId;

  /// The group specifies that the transaction is part of a group and, if so,
  /// specifies the hash of the transaction group.
  ///
  /// Assign a group ID to a transaction through the workflow described in
  /// the Atomic Transfers Guide.
  @JsonKey(name: 'grp')
  @Base32Serializer()
  Uint8List? group;

  /// A lease enforces mutual exclusion of transactions.
  /// If this field is nonzero, then once the transaction is confirmed,
  /// it acquires the lease identified by the (Sender, Lease) pair of the
  /// transaction until the LastValid round passes.
  ///
  /// While this transaction possesses the lease, no other transaction
  /// specifying this lease can be confirmed.
  ///
  /// A lease is often used in the context of Algorand Smart Contracts to
  /// prevent replay attacks.
  ///
  /// Read more about Algorand Smart Contracts and see the
  /// Delegate Key Registration TEAL template for an example implementation of
  /// leases.
  ///
  /// Leases can also be used to safeguard against unintended duplicate spends.
  @JsonKey(name: 'lx')
  @NullableByteArraySerializer()
  Uint8List? lease;

  /// Any data up to 1000 bytes.
  @JsonKey(name: 'note')
  @NullableByteArraySerializer()
  final Uint8List? note;

  /// Specifies the authorized address.
  /// This address will be used to authorize all future transactions.
  /// TODO Change key
  @JsonKey(name: 'rekey')
  final String? rekeyTo;

  RawTransaction({
    required this.fee,
    required this.firstValid,
    required this.genesisHash,
    required this.lastValid,
    required this.sender,
    required this.type,
    required this.genesisId,
    required this.group,
    required this.lease,
    required this.note,
    required this.rekeyTo,
  });

  /// Export the transaction to a file.
  /// This creates a new File with the given filePath and streams the encoded
  /// transaction to it.
  Future<File> export(String filePath) async {
    return File(filePath).writeAsBytes(getEncodedTransaction());
  }

  /// Assign a group id to this transaction.
  /// GroupId is the id generated by the SDK.
  ///
  /// This is used for Atomic Transfers.
  void assignGroupId(Uint8List groupId) {
    group = groupId;
  }

  /// Sets the transaction fee according to feePerByte * estimateTxSize.
  Future setFeeByFeePerByte(int feePerByte) async {
    fee = feePerByte;
    fee = await FeeCalculator.calculateFeePerByte(this, feePerByte);
  }

  /// Sign the transaction with the given account.
  ///
  /// If the SK's corresponding address is different than the txn sender's,
  /// the SK's corresponding address will be assigned as AuthAddr.
  Future<SignedTransaction> sign(Account account) async {
    // Get the encoded transaction
    final encodedTransaction = getEncodedTransaction();

    // Sign the transaction with secret key
    final signature = await Ed25519().sign(
      encodedTransaction,
      keyPair: account.keyPair,
    );

    // Create the signed transaction with signature
    final signedTransaction = SignedTransaction(
      signature: Uint8List.fromList(signature.bytes),
      transaction: this,
    );

    // Set the auth address
    if (sender != account.address) {
      signedTransaction.authAddress = account.address;
    }

    return signedTransaction;
  }

  /// Get the encoded representation of the transaction with a prefix suitable
  /// for signing.
  Uint8List getEncodedTransaction() {
    // Encode transaction as msgpack
    final encodedTx = Encoder.encodeMessagePack(toMessagePack());

    // Prepend the transaction prefix
    final txBytes = utf8.encode(TX_PREFIX);

    // Merge the byte arrays
    return Uint8List.fromList([...txBytes, ...encodedTx]);
  }

  /// Get the transaction id.
  /// The encoded transaction is hashed using sha512/256 and base32 encoded.
  ///
  /// Returns the id of the transaction.
  String get id {
    final txBytes = sha512256.convert(getEncodedTransaction()).bytes;

    // Encode with Base32
    return base32.encode(Uint8List.fromList(txBytes)).trimPadding();
  }

  /// Get the binary representation of the transaction id.
  /// The encoded transaction is hashed using sha512/256 without base32 encoding
  ///
  /// Returns the raw id of the transaction.
  Uint8List get rawId =>
      Uint8List.fromList(sha512256.convert(getEncodedTransaction()).bytes);

  factory RawTransaction.fromJson(Map<String, dynamic> json) =>
      _$RawTransactionFromJson(json);

  /// Get the base64-encoded representation of the transaction..
  String toBase64() => base64Encode(Encoder.encodeMessagePack(toMessagePack()));

  /// Get the bytes of this transaction.
  Uint8List toBytes() =>
      Uint8List.fromList(Encoder.encodeMessagePack(toMessagePack()));

  Map<String, dynamic> toJson() => _$RawTransactionToJson(this);

  Map<String, dynamic> toMessagePack() => <String, dynamic>{
        'fee': fee,
        'fv': firstValid,
        'gh': genesisHash,
        'lv': lastValid,
        'snd': const AddressTransformer().toMessagePack(sender),
        'type': type,
        'gen': genesisId,
        'grp': group,
        'lx': lease,
        'note': note,
        'rekey': rekeyTo,
      };

  @override
  List<Object?> get props => [
        fee,
        firstValid,
        genesisHash,
        lastValid,
        sender,
        type,
        genesisId,
        group,
        lease,
        note,
        rekeyTo,
      ];
}
