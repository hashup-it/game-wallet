import 'package:algorand_dart/src/api/responses.dart';
import 'package:algorand_dart/src/models/models.dart';
import 'package:algorand_dart/src/services/api_service.dart';
import 'package:dio/dio.dart' as dio;

part 'account_service_impl.dart';

//@RestApi()
abstract class AccountService extends ApiService {
  factory AccountService(dio.Dio dio, {String baseUrl}) = _AccountService;

  /// Algod
  //@GET("/v2/accounts/{address}")
  Future<AccountInformation> getAccountByAddress(
    /*@Path('address')*/ String address,
  );

  //@GET("/v2/accounts")
  Future<SearchAccountsResponse> searchAccounts(
    Map<String, dynamic> queryParameters,
  );

  //@GET("/v2/accounts/{accountId}")
  Future<AccountResponse> getAccountById(
    /*@Path('accountId')*/ String accountId, {
    /*@Query('round')*/ int? round,
  });

  //@GET("/v2/assets/{assetId}/balances")
  Future<SearchAccountsResponse> searchAccountsWithBalance(
    /*@Path('assetId')*/ int assetId,
    Map<String, dynamic> queryParameters,
  );
}
