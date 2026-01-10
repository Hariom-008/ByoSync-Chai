//
//  AdminEndpoints.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 02.01.2026.
//

import Foundation

struct AdminEndpoints{
    static let baseURL = "https://backendapi.byosync.in"
    
   static let login = "\(baseURL)/api/v1/admin/admin-login"
    
    
    struct Delete{
        static let deleteFaceID = "\(baseURL)/api/v1/admin/delete-user-face-id"
        static let deleteUserAccount = "\(baseURL)/api/v1/users/delete-user-account"
    }
}
