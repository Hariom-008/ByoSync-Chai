//
//  HashValueTesting.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 11.11.2025.
//

import Foundation
import SwiftUI

struct HashValueTesting:View {
    private let cryptoManager = CryptoManager()
    private let hashGenerator = HMACGenerator.self
    let name = "Hariom"
    let deviceKey = "123456"
    @State var encryptedName: String = ""
    @State var DeviceKeyHash :String = ""
    @State var decryptedName: String = ""
    var body: some View {
        VStack{
            Text("Encrypted Name : \(encryptedName)")
            Text("Device Key HASH :\(DeviceKeyHash)")
            Text("Decrypted Name : \(decryptedName)")
            
            Button{
                calculateEncryptionAndHmac()
            }label: {
                Text("Calculate")
            }
            
            Button{
                decryptValue()
            }label: {
                Text("Decrypt")
            }
        }
        
    }
    func calculateEncryptionAndHmac(){
        encryptedName = cryptoManager.encrypt(text: name) ?? "nil"
        DeviceKeyHash = hashGenerator.generateHMAC(jsonString: deviceKey)
        print("Encrypted Name : \(encryptedName)")
        print("Device Key HASH :\(DeviceKeyHash)")
    }
    func decryptValue(){
        decryptedName = cryptoManager.decrypt(encryptedData: encryptedName) ?? "nil decryption"
        print("Decrypted Name : \(decryptedName)")
    }
}
