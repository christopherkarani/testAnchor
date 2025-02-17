//
//  BlendLendingPoolClient.swift
//  deposit test
//
//  Created by Chris Karani on 15/02/2025.
//

import Foundation
import stellarsdk


struct TestNetContractAddress {
    static let XLM: String = "CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC"
    static let USDC: String = "CAQCFVLOBK5GIULPNZRGATJJMIZL5BSP7X5YJVMGCPTUEPFM4AVSRCJU"
}

enum SoroTransactionStatus: String {
    case pending, failed, success, notFound
}

/// A client for interacting with the Blend lending pool on Soroban.
class BlendLendingPoolClient {
    private let sdk: StellarSDK
    private let sorobanServer: SorobanServer
    private let sourceAccount: KeyPair
    private let network: Network
    private let contractID = "CAZSVHNUMHVC6O5I7M2IVK2EC34CSSLCPAVHZ3MN6YRTT2LOTXXJT3AX"
    
    private var lastTransactionHash: String?

    /// Initializes the client.
    /// - Parameters:
    ///   - sourceAccount: The KeyPair of the account depositing USDC.
    ///   - horizonURL: The Horizon server URL.
    ///   - network: The Stellar network (e.g. .testnet or .public).
    ///   - sorobanEndpoint: The endpoint URL of the Soroban-RPC server.
    init(sourceAccount: KeyPair, horizonURL: URL, network: Network, sorobanEndpoint: String) {
        self.sourceAccount = sourceAccount
        self.sdk = StellarSDK(withHorizonUrl: horizonURL.absoluteString)
        self.sorobanServer = SorobanServer(endpoint: sorobanEndpoint)
        self.network = network
    }
    
    func convertToStroops(amountString: String) -> UInt64? {
        guard let amount = Double(amountString) else {
            return nil
        }
        // Multiply by 10^7 to convert to stroops
        let stroops = amount * 10_000_000
        return UInt64(stroops)
    }
    
    /// Creates a trustline for a given asset.
    /// - Parameters:
    ///   - assetCode: The asset code (e.g. "USDC").
    ///   - issuer: The issuing account (for example, "GATALTGTWIOT6BUDBCZM3Q4OQ4BO2COLOAZ7IYSKPLC2PMSOPPGF5V56").
    ///   - completion: Completion handler returning either a successful TransactionResponse or an Error.
    func createTrustline(assetCode: String,
                         issuer: KeyPair,
                         completion: @escaping (Result<TransactionResponse, Error>) -> Void) {
        // Fetch current account details (needed for constructing a valid transaction).
        sdk.accounts.getAccountDetails(accountId: sourceAccount.accountId) { [weak self] response in
            guard let self = self else { return }
            switch response {
            case .success(let accountResponse):
                do {
                    // Construct the asset object.
                    let asset = Asset(type: AssetType.ASSET_TYPE_CREDIT_ALPHANUM4, code: assetCode, issuer: issuer)
                    // Create a ChangeTrustOperation for the asset.
                    let changeTrustOp = try ChangeTrustOperation.init(sourceAccountId: sourceAccount.accountId, asset: .init(type: AssetType.ASSET_TYPE_CREDIT_ALPHANUM4, code: assetCode, issuer: .init(accountId: "GATALTGTWIOT6BUDBCZM3Q4OQ4BO2COLOAZ7IYSKPLC2PMSOPPGF5V56"))!)
                    // Build a transaction with the ChangeTrustOperation.
                    let transaction = try Transaction(sourceAccount: accountResponse,
                                                      operations: [changeTrustOp],
                                                      memo: Memo.none)
                    // Sign the transaction with your source account.
                    try transaction.sign(keyPair: self.sourceAccount, network: network)
                    // Submit the transaction to the network.
                    self.sdk.transactions.submitTransaction(transaction: transaction) { result in
                        switch result {
                        case .success(let txResponse):
                            completion(.success(txResponse))
                        case .failure(let error):
                            completion(.failure(error))
                        case .destinationRequiresMemo(destinationAccountId: let destinationAccountId):
                            break
                        }
                    }
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func checkTransactionStatus() async throws -> SoroTransactionStatus  {
        // Call the Soroban RPC server's function to retrieve transaction status.
        guard let txHash = lastTransactionHash else {
            return SoroTransactionStatus.pending
        }
        let response = await sorobanServer.getTransaction(transactionHash: txHash)
        guard case let .success(transaction) = response else {
            fatalError()
        }

        
        switch transaction.status {
        case "SUCCESS":
            return SoroTransactionStatus.success
        case "NOT_FOUND":
            return SoroTransactionStatus.notFound
        case "FAILED":
            return SoroTransactionStatus.failed
        default:
            return SoroTransactionStatus.pending
        }
    }
    
    
    

    
    /// Deposits USDC into the Blend lending pool using the "submit" function.
    /// The contract expects a Request struct with:
    ///   - request_type: UInt32 (1 indicates deposit)
    ///   - address: Address (the pool's address)
    ///   - amount: i128 (deposit amount in stroops)
    /// And then, submit(from: address, spender: address, to: address, requests: vec<Request>).
    func depositUSDC(amount: String) async throws -> SendTransactionResponse {
        // Set deposit request type to 1 (for deposit)
        let depositRequestType: UInt32 = 1
        
        // Define pool's address string (this should be the pool's public key as an XDR address)
        let poolAddressString = TestNetContractAddress.USDC
        
        // Create XDR address objects for the pool and source account.
        guard let poolAddressXDR = try? SCAddressXDR(contractId: poolAddressString),
              let sourceAddressXDR = try? SCAddressXDR(accountId: sourceAccount.accountId)
        else {
            throw NSError(domain: "BlendLendingPoolClient", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create address XDR."])
        }
        
        // Build XDR values for the Request struct:
        // 1. request_type: u32
        // 2. address: Address (pool address in this example)
        // 3. amount: i128 (deposit amount in stroops)
        let requestTypeArg = SCValXDR.u32(depositRequestType)
        let addressArg = SCValXDR.address(poolAddressXDR)
        
        // Convert the deposit amount (as a string) to stroops.
        guard let depositStroops = convertToStroops(amountString: amount) else {
            throw NSError(domain: "BlendLendingPoolClient", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid deposit amount."])
        }
        // Create an i128 from the deposit value: hi = 0, lo = depositStroops.
        let int128Value = Int128PartsXDR(hi: 0, lo: depositStroops)
        let amountArg = SCValXDR.i128(int128Value)
        
        // Construct the Request map with keys "address", "amount", and "request_type".
        let requestMap = SCValXDR.map([
            SCMapEntryXDR(key: .symbol("address"), val: addressArg),
            SCMapEntryXDR(key: .symbol("amount"), val: amountArg),
            SCMapEntryXDR(key: .symbol("request_type"), val: requestTypeArg)
        ])
        
        // Wrap the Request map in a vector (vec<Request>).
        let requestsVector = SCValXDR.vec([requestMap])
        
        // Construct function arguments for submit(from:spender:to:requests:)
        // "from" and "spender" are the source address; "to" is the pool's address.
        let fromArg = SCValXDR.address(sourceAddressXDR)
        let spenderArg = SCValXDR.address(sourceAddressXDR)
        let toArg = SCValXDR.address(poolAddressXDR)
        
        let functionArguments = [fromArg, spenderArg, toArg, requestsVector]
        
        // Fetch current account details from Horizon.
        let accountDetailsResponse = await sdk.accounts.getAccountDetails(accountId: sourceAccount.accountId)
        guard case let .success(accountResponse) = accountDetailsResponse else {
            throw NSError(domain: "BlendLendingPoolClient", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to fetch account details."])
        }
        
        // Create the operation for the contract call.
        let operation = try InvokeHostFunctionOperation.forInvokingContract(
            contractId: contractID,
            functionName: "submit",
            functionArguments: functionArguments)
        
        // Build the transaction.
        let transaction = try Transaction(sourceAccount: accountResponse,
                                          operations: [operation],
                                          memo: Memo.none)
        
        // Simulate the transaction to obtain Soroban transaction data and resource fee.
        let simulateRequest = SimulateTransactionRequest(transaction: transaction)
        let simulateResponse = await sorobanServer.simulateTransaction(simulateTxRequest: simulateRequest)
        guard case let .success(simulateResult) = simulateResponse else {
            throw NSError(domain: "BlendLendingPoolClient", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Transaction simulation failed."])
        }
        
       
        dump(simulateResult)
        guard let txData = simulateResult.transactionData,
              let resourceFee = simulateResult.minResourceFee
        else {
            throw NSError(domain: "BlendLendingPoolClient", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Simulation did not return required data."])
        }
        
        // Update transaction with simulation data and resource fee.
        transaction.setSorobanTransactionData(data: txData)
        transaction.addResourceFee(resourceFee: resourceFee)
        transaction.setSorobanAuth(auth: simulateResult.sorobanAuth)
        
        // Sign the transaction.
        try transaction.sign(keyPair: self.sourceAccount, network: self.network)
        
        // Submit the transaction.
        let sendTxResponse = await self.sorobanServer.sendTransaction(transaction: transaction)
        guard case let .success(sendTxResult) = sendTxResponse else {
            throw NSError(domain: "BlendLendingPoolClient", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Transaction submission failed."])
        }
        
        // Store the transaction hash for future status checks.
        lastTransactionHash = sendTxResult.transactionId
        print("Transaction Hash: ", lastTransactionHash ?? "none")
        
        return sendTxResult
    }
}

