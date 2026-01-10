//
//  LocalEnrollment.swift
//  ML-Testing
//
//  Created by Hari's Mac on 09.12.2025.
//

import Foundation
import Alamofire

//ERROR: Simple error for Insuffiecient Data
enum LocalEnrollmentError: Error {
    case noLocalEnrollment
    case insufficientMatchedFrames(matched: Int, required: Int)
}
