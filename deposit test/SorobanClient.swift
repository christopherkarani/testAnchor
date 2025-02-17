//
//  SorobanClient.swift
//  deposit test
//
//  Created by Chris Karani on 15/02/2025.
//

import Foundation
import stellarsdk

/// A client for invoking Soroban smart contract functions using the Stellar iOS SDK.
class SorobanContractClient {
    private let sdk: StellarSDK
    private let sorobanServer: SorobanServer
    private let sourceAccount: KeyPair
    private let network: Network
    
    /// Initializes the client.
    /// - Parameters:
    ///   - sourceAccount: The KeyPair of the account sending the transaction.
    ///   - horizonURL: The Horizon server URL (e.g. for testnet).
    ///   - network: The Stellar network (e.g. .testnet).
    ///   - sorobanEndpoint: The endpoint URL of the Soroban-RPC server.
    init(sourceAccount: KeyPair, horizonURL: URL, network: Network, sorobanEndpoint: String) {
        self.sourceAccount = sourceAccount
        self.sdk = StellarSDK(withHorizonUrl: horizonURL.absoluteString)
        self.sorobanServer = SorobanServer(endpoint: sorobanEndpoint)
        self.network = network
    }
    
    /// Invokes a smart contract function on Soroban.
    ///
    /// The method:
    /// 1. Fetches the source account details needed for transaction creation.
    /// 2. Builds an InvokeHostFunctionOperation to call the specified contract function.
    /// 3. Creates and simulates the transaction to obtain transaction data and resource fee.
    /// 4. Signs and submits the transaction.
    ///
    /// - Parameters:
    ///   - contractId: The identifier of the deployed contract.
    ///   - functionName: The name of the function to invoke.
    ///   - functionArguments: An array of arguments (SCValXDR) to pass to the function.
    /// - Returns: A TransactionResponse with details about the submitted transaction.
    func invokeContract(contractId: String,
                        functionName: String,
                        functionArguments: [SCValXDR]) async throws -> SendTransactionResponse {
        // Step 1: Retrieve account details (needed for sequence number, etc.)
        let accountResult = await sdk.accounts.getAccountDetails(accountId: sourceAccount.accountId)
        let accountResponse: AccountResponse
        switch accountResult {
        case .success(let account):
            accountResponse = account
        case .failure(let error):
            throw error
        }
        
        // Step 2: Build the operation for invoking the contract.
        let operation = try InvokeHostFunctionOperation.forInvokingContract(
            contractId: contractId,
            functionName: functionName,
            functionArguments: functionArguments)
        
        // Create the transaction with the operation.
        let transaction = try Transaction(sourceAccount: accountResponse,
                                          operations: [operation],
                                          memo: Memo.none)
        
        // Step 3: Simulate the transaction to get the required soroban transaction data and resource fee.
        let simulateRequest = SimulateTransactionRequest(transaction: transaction)
        let simulateResult = await sorobanServer.simulateTransaction(simulateTxRequest: simulateRequest)
        let simulateResponse: SimulateTransactionResponse
        switch simulateResult {
        case .success(let response):
            simulateResponse = response
        case .failure(let error):
            throw error
        }
        
        // Ensure that simulation provided both transaction data and a resource fee.
        guard let txData = simulateResponse.transactionData,
              let resourceFee = simulateResponse.minResourceFee else {
            throw NSError(domain: "SorobanContractClient", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Simulation response missing required data."])
        }
        
        // Set simulation data on the transaction.
        transaction.setSorobanTransactionData(data: txData)
        transaction.addResourceFee(resourceFee: resourceFee)
        
        // Step 4: Sign the transaction using the source account’s key.
        try transaction.sign(keyPair: sourceAccount, network: network)
        
        // Submit the transaction to the Soroban RPC server.
        let sendResult = await sorobanServer.sendTransaction(transaction: transaction)
        switch sendResult {
        case .success(let sendResponse):
            return sendResponse
        case .failure(let error):
            throw error
        }
    }
}
