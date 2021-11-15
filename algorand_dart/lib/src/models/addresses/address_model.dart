import 'dart:convert';
import 'dart:typed_data';

import 'package:algorand_dart/src/crypto/crypto.dart' as crypto;
import 'package:algorand_dart/src/exceptions/exceptions.dart';
import 'package:algorand_dart/src/models/models.dart';
import 'package:algorand_dart/src/utils/crypto_utils.dart';
import 'package:algorand_dart/src/utils/utils.dart';
import 'package:base32/base32.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:equatable/equatable.dart';

class Address extends Equatable {
  /// The length of the public key
  static const PUBLIC_KEY_LENGTH = 32;

  /// The length of the Algorand checksum.
  static const CHECKSUM_BYTE_LENGTH = 4;

  /// Prefix for signing TEAL program data
  static const PROGDATA_SIGN_PREFIX = 'ProgData';

  /// Prefix for signing bytes
  static const BYTES_SIGN_PREFIX = 'MX';

  /// Prefix for hashing application ID
  static const APP_ID_PREFIX = 'appID';

  /// The public key, in bytes
  final Uint8List publicKey;

  /// The encoded Algorand address.
  final String encodedAddress;

  Address({required this.publicKey})
      : encodedAddress = encodeAddress(publicKey);

  /// Create a new Address from a given Algorand address.
  /// This decodes the uppercased Algorand address to its raw bytes and
  /// validating the address.
  ///
  /// Throws [AlgorandException] if unable to decode the address.
  Address.fromAlgorandAddress({required String address})
      : this(publicKey: decodeAddress(address));

  /// Encode a public key to a human-readable representation, with a 4-byte
  /// checksum appended at the end, using SHA512/256.
  ///
  ///  Note that string representations of addresses generated by different SDKs
  ///  may not be compatible.
  static String encodeAddress(Uint8List publicKey) {
    // Sanitize public key length
    if (publicKey.length != PUBLIC_KEY_LENGTH) {
      throw AlgorandException(
          message: 'Public key is an invalid address. Wrong length');
    }

    // Compute the hash using sha512/256
    final digest = sha512256.convert(publicKey);
    final hashBytes = Uint8List.fromList(digest.bytes);

    // Take the last 4 bytes and append to addr
    final checksum = hashBytes.sublist(hashBytes.length - 4);

    final addr = base32.encode(Uint8List.fromList(publicKey + checksum));
    return addr.trimPadding();
  }

  /// Decode an encoded, uppercased Algorand address to a public key.
  ///
  /// Throws an [AlgorandException] when the address cannot be decoded.
  static Uint8List decodeAddress(String address) {
    // Decode the address
    final addressBytes = base32.decode(address);

    // Sanity length check
    if (addressBytes.length != PUBLIC_KEY_LENGTH + CHECKSUM_BYTE_LENGTH) {
      throw AlgorandException(
          message: 'Input string is an invalid address. Wrong length');
    }

    // Find the public key & checksum
    final publicKey = addressBytes.sublist(0, PUBLIC_KEY_LENGTH);
    final checksum = addressBytes.sublist(
        PUBLIC_KEY_LENGTH, PUBLIC_KEY_LENGTH + CHECKSUM_BYTE_LENGTH);

    // Compute the expected checksum
    final computedChecksum = sha512256
        .convert(publicKey)
        .bytes
        .sublist(PUBLIC_KEY_LENGTH - CHECKSUM_BYTE_LENGTH);

    if (!const ListEquality().equals(computedChecksum, checksum)) {
      throw AlgorandException(
          message: 'Invalid Algorand address. Checksums do not match.');
    }

    return publicKey;
  }

  /// Get the escrow address of an application.
  /// Returns the address corresponding to that application's escrow account.
  static Address forApplication(int applicationId) {
    // Prepend the prefix
    final prefix = utf8.encode(APP_ID_PREFIX);

    // Merge the byte arrays
    final buffer = Uint8List.fromList([
      ...prefix,
      ...BigIntEncoder.encodeUint64(BigInt.from(applicationId)),
    ]);

    final digest = sha512256.convert(buffer);

    return Address(publicKey: Uint8List.fromList(digest.bytes));
  }

  /// Check if the given address is a valid Algorand address.
  static bool isAlgorandAddress(String address) {
    try {
      decodeAddress(address);
      return true;
    } catch (ex) {
      return false;
    }
  }

  /// Creates Signature compatible with ed25519verify TEAL opcode from data and
  /// contract address (program hash).
  Future<crypto.Signature> sign({
    required Account account,
    required Uint8List data,
  }) async {
    final rawAddress = Uint8List.fromList(publicKey);

    // Prepend the prefix
    final progDataBytes = utf8.encode(PROGDATA_SIGN_PREFIX);

    // Merge the byte arrays
    final buffer = Uint8List.fromList([
      ...progDataBytes,
      ...rawAddress,
      ...data,
    ]);

    return await account.sign(buffer);
  }

  /// Verifies that the signature for the message is valid for the public key.
  /// The message should have been prepended with "MX" when signing.
  Future<bool> verify(Uint8List message, crypto.Signature signature) async {
    final publicKey = toVerifyKey();

    // Prepend the prefix
    final signBytes = utf8.encode(BYTES_SIGN_PREFIX);

    // Merge the byte arrays
    final buffer = Uint8List.fromList([
      ...signBytes,
      ...message,
    ]);

    return await Ed25519().verify(
      buffer,
      signature: Signature(
        signature.bytes,
        publicKey: publicKey,
      ),
    );
  }

  /// Returns a copy of the public key address.
  Uint8List toBytes() => Uint8List.fromList(publicKey);

  /// Returns address' public key in a form suitable for verification.
  PublicKey toVerifyKey() {
    return SimplePublicKey(
      publicKey,
      type: KeyPairType.ed25519,
    );
  }

  @override
  List<Object?> get props => [...publicKey];
}