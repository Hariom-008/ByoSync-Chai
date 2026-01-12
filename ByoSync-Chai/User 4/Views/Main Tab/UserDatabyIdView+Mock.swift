//
//  UserDatabyIdView+Mock.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 19.12.2025.
//

import Foundation
#if DEBUG
import Foundation

enum MockDecode {
    static func decode<T: Decodable>(_ type: T.Type, json: String) -> T {
        let data = Data(json.utf8)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            fatalError("Mock decode failed for \(T.self): \(error)")
        }
    }
}

extension UserByIdDTO {
    static var mock: UserByIdDTO {
        let json = """
        {
          "_id": "usr_123456",
          "email": "ayaan.khan@byosync.dev",
          "firstName": "Ayaan",
          "lastName": "Khan",
          "phoneNumber": "+91 98765 43210",
          "salt": "salt_demo",
          "faceToken": "face_token_demo",
          "wallet": 1250.75,
          "chai": 2,
          "referralCode": "BYO-7H2K9",
          "transactionCoins": 310,
          "noOfTransactions": 42,
          "noOfTransactionsReceived": 18,
          "profilePic": "https://i.pravatar.cc/300?img=12",
          "devices": ["dev_abc123"],
          "emailVerified": true,
          "createdAt": "2024-06-18T10:12:30Z",
          "updatedAt": "2025-01-02T12:00:00Z",
          "__v": 0
        }
        """
        return MockDecode.decode(UserByIdDTO.self, json: json)
    }
}

extension DeviceByIdDTO {
    static var mockPrimary: DeviceByIdDTO {
        let json = """
        {
          "_id": "dev_abc123",
          "deviceKey": "device_key_demo",
          "deviceName": "iPhone 15 Pro",
          "user": "usr_123456",
          "isPrimary": true,
          "createdAt": "2024-06-18T10:12:30Z",
          "updatedAt": "2025-01-02T12:00:00Z",
          "__v": 0
        }
        """
        return MockDecode.decode(DeviceByIdDTO.self, json: json)
    }
}
#endif


