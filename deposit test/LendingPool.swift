//
//  LendingPool.swift
//  deposit test
//
//  Created by Chris Karani on 15/02/2025.
//

import SwiftUI
import stellarsdk

class ViewModel: ObservableObject {
    let sourceAccount: KeyPair = try! .init(secretSeed: "SAG2Z5YXJTMCLBXHFKG34VBHHPHYSU4BTRZZGZDDXY3NWJLIRDB5MX5J")
    
    let client = BlendLendingPoolClient(
        sourceAccount: try! .init(secretSeed: "SAG2Z5YXJTMCLBXHFKG34VBHHPHYSU4BTRZZGZDDXY3NWJLIRDB5MX5J"),
        horizonURL: URL(string: StellarSDK.testNetUrl)!,
        network: .testnet,
        sorobanEndpoint: "https://soroban-testnet.stellar.org")
    
    func createTrustline() {
        client.createTrustline(assetCode: "USDC", issuer: try! .init(accountId: "GATALTGTWIOT6BUDBCZM3Q4OQ4BO2COLOAZ7IYSKPLC2PMSOPPGF5V56")) { response in
            switch response {
            case .success(let result):
                print("Done")
            case .failure(let error):
                print("Error Setting Ttrustline: ", error)
            }
        }
    }
    
    func depositFunds() async {
        
        do {
            let _ = try await client.depositUSDC(amount: "10")
        } catch {
            print("Error: ", error)
        }
       
        
    }
    
    func checkTransactionStatus() async {
        let status = try! await client.checkTransactionStatus()
        print("Status: ", status.rawValue)
     //   status.rawValue
    }
    
    
}

struct DepositWithdrawView: View {
    enum Action: String, CaseIterable {
        case deposit = "Deposit"
        case withdraw = "Withdraw"
    }
    
    @StateObject private var viewModel = ViewModel()
    @State private var selectedAction: Action = .deposit
    @State private var amount: String = ""
    @State private var poolBalance: Double = 1000.00 // Example starting balance
    @State private var apr: Double = 5.25            // Example APR percentage
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header with Lending Pool Info
           
                    // Top Header
                    Text("Lending Pool")
                        .font(.custom("AvenirNext-Bold", size: 34))
                        .padding(.top, 20)

                    // Pool Information Card
                    VStack(spacing: 16) {
                        HStack {
                            Text("Pool Balance")
                                .font(.custom("AvenirNext-Medium", size: 18))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("$\(poolBalance, specifier: "%.2f")")
                                .font(.custom("AvenirNext-Medium", size: 18))
                                .monospacedDigit()
                                .foregroundColor(.primary)
                        }
                        HStack {
                            Text("APR")
                                .font(.custom("AvenirNext-Medium", size: 18))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(apr, specifier: "%.2f")%")
                                .font(.custom("AvenirNext-Medium", size: 18))
                                .monospacedDigit()
                                .foregroundColor(.primary)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 16)
                
                // Segmented Control for Action Selection
                Picker("Action", selection: $selectedAction) {
                    ForEach(Action.allCases, id: \.self) { action in
                        Text(action.rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 24)
                
                // Amount Input Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter Amount")
                        .font(.custom("AvenirNext-Regular", size: 16))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)
                    
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                        .font(.custom("AvenirNext-Regular", size: 20))
                        .monospacedDigit()
                        .padding(.horizontal, 24)
                }
                
                // Action Button
                Button(action: {
                    if selectedAction == .deposit {
                        Task{
                            await viewModel.depositFunds()
                        }
                       
                    } else {
                        withdrawFunds()
                    }
                }) {
                    Text(selectedAction == .deposit ? "Deposit Funds" : "Withdraw Funds")
                        .font(.custom("AvenirNext-DemiBold", size: 20))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedAction == .deposit ? Color.green : Color.blue)
                        .cornerRadius(12)
                        .shadow(color: (selectedAction == .deposit ? Color.green : Color.blue).opacity(0.4),
                                radius: 6, x: 0, y: 3)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                
                Button(action: {
                    Task{
                        await viewModel.checkTransactionStatus()
                    }
                    
                }) {
                    Text("Check Status")
                        .font(.custom("AvenirNext-DemiBold", size: 20))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedAction == .deposit ? Color.green : Color.blue)
                        .cornerRadius(12)
                        .shadow(color: (selectedAction == .deposit ? Color.green : Color.blue).opacity(0.4),
                                radius: 6, x: 0, y: 3)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                
                Button(action: {
                   // Task{
                         viewModel.createTrustline()
                   // }
                    
                }) {
                    Text("Create trustline")
                        .font(.custom("AvenirNext-DemiBold", size: 20))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedAction == .deposit ? Color.green : Color.blue)
                        .cornerRadius(12)
                        .shadow(color: (selectedAction == .deposit ? Color.green : Color.blue).opacity(0.4),
                                radius: 6, x: 0, y: 3)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                Spacer()
            }
            .navigationBarHidden(true)
            .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        }
    }
    
    // MARK: - Dummy Business Logic
    
    
    private func withdrawFunds() {
        guard let amountValue = Double(amount), amountValue <= poolBalance else { return }
        poolBalance -= amountValue
        amount = ""
    }
}

struct DepositWithdrawView_Previews: PreviewProvider {
    static var previews: some View {
        DepositWithdrawView()
    }
}


