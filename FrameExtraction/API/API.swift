//
//  API.swift
//  FrameExtraction
//
//  Created by Duc Nguyen Viet on 2/28/19.
//  Copyright © 2019 bRo. All rights reserved.
//

import Foundation
import Alamofire

let baseURL = "http://192.168.0.204/API"

class API: NSObject {
    static let shared = API()
    
    func callApi(endpoint: String, params: [String: Any], success : @escaping (_ result: Data?) -> Void, error: @escaping (Error) -> Void) {
//        Alamofire.request(baseURL + endpoint, method: .post).responseJSON { response in
//            guard let _ = response.result.value else {
//                error(response.result.error!)
//                return
//            }
//            success(response.data)
//        }
        
//        Alamofire.request(baseURL + endpoint, method: .post, parameters: ["data": params], encoding: JSONEncoding.default, headers: nil).responseJSON { response in
//            guard let _ = response.result.value else {
//                error(response.result.error!)
//                return
//            }
//            success(response.data)
//        }
        
        var request = URLRequest(url: URL(string: baseURL + endpoint)!)
        
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try! JSONSerialization.data(withJSONObject: params, options: [])
        
        Alamofire.request(request).responseString { (response) in
            guard let _ = response.result.value else {
                error(response.result.error!)
                return
            }
            success(response.data)
        }
    }
}
