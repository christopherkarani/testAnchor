//
//  depositView.swift
//  deposit test
//
//  Created by Chris Karani on 14/02/2025.
//

import SwiftUI
import stellarsdk

// Define the deposit types.
enum DepositType: String, CaseIterable, Identifiable {
    case mobileMoney = "Mobile Money"
    case paybill = "Paybill"
    
    var id: String { self.rawValue }
}

struct DepositView: View {
    @State private var depositType: DepositType = .mobileMoney
    @State private var amount: String = ""
    @State private var mobileNumber: String = ""
    @State private var paybillNumber: String = ""
    @State private var paybillAccount: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Deposit Details")) {
                    // Deposit type selection.
                    Picker("Deposit Type", selection: $depositType) {
                        ForEach(DepositType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // Deposit amount input.
                    TextField("Amount (USDC)", text: $amount)
                        .keyboardType(.decimalPad)
                }
                
                // Conditional fields based on deposit type.
                if depositType == .mobileMoney {
                    Section(header: Text("Mobile Money Details")) {
                        TextField("Mobile Number", text: $mobileNumber)
                            .keyboardType(.phonePad)
                    }
                } else if depositType == .paybill {
                    Section(header: Text("Paybill Details")) {
                        TextField("Paybill Number", text: $paybillNumber)
                            .keyboardType(.numberPad)
                        TextField("Account Number", text: $paybillAccount)
                            .keyboardType(.numberPad)
                    }
                }
                
                // Submit button to trigger the deposit process.
                Section {
                    Button(action: {
                       // initiateDeposit()
                        Task {
                            await initiateDeposit()
                        }
                        
                    }) {
                        Text("Submit Deposit")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Deposit Funds")
        }
    }
    let domain = "testanchor.stellar.org"
   // let clickpesadomain = "connect.clickpesa.com"
    let userAccountId = "GDL4EC5LSXLI4SQAGZOBEOEFG6CPHKWV4TR6LG6LPBASPR5V3WGXRIUC"
    let userSeed = "SAG2Z5YXJTMCLBXHFKG34VBHHPHYSU4BTRZZGZDDXY3NWJLIRDB5MX5J"
    
    func authentication() async throws -> String {
        let responseEnum = await WebAuthenticator.from(domain: domain, network: .testnet)
        switch responseEnum {
        case .success(let webAuthenticator):
            let keyPair = try KeyPair(secretSeed: self.userSeed)
            let userAccountId = keyPair.accountId
            let signers: [KeyPair] = [keyPair]
            
            print("Getting token")
            let jwtResponseEnum = await webAuthenticator.jwtToken(forUserAccount: userAccountId, signers: signers)
           
            
            switch jwtResponseEnum {
            case .success(let jwtToken):
                print("JWT received: \(jwtToken)")
                return jwtToken
            case .failure(let error):
                print("Error getting JWT token: \(error)")
                throw error
            }
        case .failure(let error):
            print("Failed to initialize WebAuthenticator: \(error.localizedDescription)")
            throw error
        }
    }
    
//    func withdraw(token: String, transferService: TransferServerService) async throws -> WithdrawResponse {
//        
//       
//        var request = WithdrawRequest(
//            type: "mobile_money",
//            assetCode: "USDC",
//            jwt: token
//        )
//        request.amount = "1000000"
//        request.lang = "en"
//        request.countryCode = "KE"
//        request.account = userAccountId
//        
//        let responseEnum = await transferService.withdraw(request: request)
//        switch responseEnum {
//        case .success(response: let response):
//            print("response: ", response)
//        case .failure(error: let error):
//            dump(error)
//        }
//        guard case let .success(response) = responseEnum else {
//            throw NSError(domain: "withdraw", code: 0, userInfo: nil) as Swift.Error
//        }
//        return response
//    }
    
    func withdraw(token: String, transferService: TransferServerService) async throws -> WithdrawResponse {
        
       
        var request = WithdrawRequest(
            type: "bank_account",
            assetCode: "SRT",
            jwt: token
        )
//        request.amount = "1000000"
//        request.lang = "en"
//        request.countryCode = "KE"
//        request.account = userAccountId
        
        request.amount = "1000000"
        request.dest = "19293845"
        request.extraFields = [
            "bank_account_number": "1223456785",
            "bank_number": "123345667",
            
        ]
     //   dump(transferService.info())
     //   dump(request)
        let responseEnum = await transferService.withdraw(request: request)
        switch responseEnum {
        case .success(response: let response):
            print("response: ", response)
        case .failure(error: let error):
            print(error)
           // dump(error)
        }
        guard case let .success(response) = responseEnum else {
            throw NSError(domain: "withdraw", code: 0, userInfo: nil) as Swift.Error
        }
        return response
    }
    
    func initiateDeposit() async {
        do {
            // Get the transfer service
            let service = try await getTrasnferService()
            
            // Get the info about the service
            guard case let .success(info) = await service.info() else {
                print("Failed to fetch service info.")
                return
            }
            
            
            
            // Access the deposit asset (e.g., "KES" asset)
            if let asset = info.deposit?["KES"] {
                let requiresAuth = asset.authenticationRequired ?? false
                
                // If authentication is required, proceed to get the JWT
                if requiresAuth {
                    let jwtToken = try await authentication()  // Fetch JWT token
                    
                    // Proceed with the withdrawal or deposit after authentication
                    let response = try await withdraw(token: jwtToken, transferService: service)
                    print("Extra Info: \(response.extraInfo)")
                } else {
                    print("No authentication required.")
                }
            }
            
            if let asset = info.deposit?["SRT"] {
                let requiresAuth = asset.authenticationRequired ?? false
                
                // If authentication is required, proceed to get the JWT
                if requiresAuth {
                    let jwtToken = try await authentication()  // Fetch JWT token
                    
                    // Proceed with the withdrawal or deposit after authentication
                    let response = try await withdraw(token: jwtToken, transferService: service)
                    print("Extra Info: \(response.extraInfo)")
                } else {
                    print("No authentication required.")
                }
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    func getTrasnferService() async throws -> TransferServerService {
        print("Transfer Server Service")
        let responseEnum = await TransferServerService.forDomain(domain: "https://testanchor.stellar.org")
   //     let responseEnumCP = await TransferServerService.forDomain(domain: "https://connect.clickpesa.com")
        guard case let .success(response) = responseEnum else {
            throw NSError(domain: "getTrasnferService", code: 0, userInfo: nil) as Swift.Error
        }
        print("Transfer Server Service Done")
        return response
    }
}



struct DepositView_Previews: PreviewProvider {
    static var previews: some View {
        DepositView()
    }
}
