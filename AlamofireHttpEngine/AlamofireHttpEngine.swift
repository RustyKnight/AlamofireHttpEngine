//
//  HttpEngine.swift
//  ShoutOutAPI
//
//  Created by Shane Whitehead on 10/10/18.
//  Copyright © 2018 KaiZen. All rights reserved.
//

import Foundation
import Alamofire
import Hydra
import Cadmus
import HttpEngineCore

public enum HTTPEngineError: Error {
	case invalidURL(url: String)
}

public typealias ProgressMonitor = (Double) -> Void

extension Alamofire.Request {
	public func debugLog() -> Self {
		debugPrint(self)
		return self
	}
}

public class AlamofireHttpEngine: HttpEngine {
	
	let url: URL
	let parameters: [String: String]?
	let headers: [String: String]?
	let credentials: HttpEngineCore.Credentials?
	let progressMonitor: ProgressMonitor?
	let processQueue: DispatchQueue
	
	public init(url: URL,
							parameters: [String: String]? = nil,
							headers: [String: String]? = nil,
							credentials: HttpEngineCore.Credentials? = nil,
							progressMonitor: ProgressMonitor? = nil,
							processQueue: DispatchQueue = DispatchQueue.global(qos: .userInitiated)) {
		self.url = url
		self.headers = headers
		self.parameters = parameters
		self.credentials = credentials
		self.progressMonitor = progressMonitor
		self.processQueue = processQueue
	}
	
	internal func process(_ response: DataResponse<Data>, then fulfill: (Data?) -> Void, fail: (Error) -> Void) {
		if let httpResponse = response.response {
			log(debug: "Server responded to request made to \(url) with: \(httpResponse.statusCode) - \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
		} else {
			log(warning: "Unable to determine server response to request made to \(url)")
		}
		
		switch response.result {
		case .success(let data): fulfill(data)
		case .failure(let error):
			log(error: "Request to \(url) failed with \(error)")
			fail(error)
		}
	}
	
	public func get() -> Promise<Data?> {
		return execute(using: .get)
	}
	
	public func get(data: Data) -> Promise<Data?> {
		return execute(data: data, using: .get)
	}
	
	public func put(data: Data) -> Promise<Data?> {
		return execute(data: data, using: .put)
	}
	
	public func put() -> Promise<Data?> {
		return execute(using: .put)
	}
	
	public func post(data: Data) -> Promise<Data?> {
		return execute(data: data, using: .post)
	}
	
	public func post() -> Promise<Data?> {
		return execute(using: .post)
	}
	
	public func delete() -> Promise<Data?> {
		return execute(using: .delete)
	}
	
	internal func execute(using method: HTTPMethod) -> Promise<Data?> {
		log(debug: "\(method) - \(self.url)")
		return Promise<Data?>(in: .userInitiated, { (fulfill, fail, _) in
			Alamofire.request(self.url,
												method: method,
												parameters: nil,
												encoding: URLEncoding.default,
												headers: self.headers)
				.authenticate(with: self.credentials)
				.debugLog()
				//.validate()
				.downloadProgress { progress in
					self.progressMonitor?(progress.fractionCompleted)
				}.responseData(queue: self.processQueue,
											 completionHandler: { (response) in
												self.process(response, then: fulfill, fail: fail)
				})
		})
	}
	
	internal func execute(data: Data, using method: HTTPMethod) -> Promise<Data?> {
		log(debug: "\(method) data - \(self.url)")
		return Promise<Data?>(in: .userInitiated, { (fulfill, fail, _) in
			Alamofire.upload(data,
											 to: self.url,
											 method: method,
											 headers: self.headers)
				.authenticate(with: self.credentials)
				//.validate()
				.debugLog()
				.uploadProgress(queue: self.processQueue,
												closure: { (progress) in
													self.progressMonitor?(progress.fractionCompleted)
				}).downloadProgress { progress in
					self.progressMonitor?(progress.fractionCompleted)
				}.responseData(queue: self.processQueue,
											 completionHandler: { (response) in
												self.process(response, then: fulfill, fail: fail)
				})
		})
	}
	
}

extension Request {
	func authenticate(with credentials: Credentials?) -> Self {
		guard let credentials = credentials else {
			return self
		}
		return authenticate(user: credentials.userName, password: credentials.password)
	}
}
