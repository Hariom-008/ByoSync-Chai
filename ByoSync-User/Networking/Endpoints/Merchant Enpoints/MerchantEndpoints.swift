//
//  MerchantEndpoints.swift
//  ByoSync
//
//  Created by Hari's Mac on 29.10.2025.
//

import Foundation

struct MerchantEndpoints{
   // static let baseURL = "http://192.168.1.16:7000" 
    static let baseURL = "https://backend-byosync.vercel.app"
    
    struct Auth{
        static let merchantRegister = "\(baseURL)/api/v1/users/merchant-register"
    }
}
