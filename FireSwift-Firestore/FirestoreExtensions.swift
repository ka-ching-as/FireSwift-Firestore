//
//  FirebaseExtensions.swift
//  SwiftyFirebase
//
//  Created by Morten Bek Ditlevsen on 26/07/2018.
//  Copyright © 2018 Ka-ching. All rights reserved.
//

import Foundation
import FirebaseFirestore
import FireSwift_DecodeResult
import FireSwift_StructureCoding
import FireSwift_Paths
import Result

public enum EncodeError: Error {
    case expectingDictionaryEncodedData
}

// A small helper to wrap a completion block from Firestore calls to a block taking a Result
private func wrap<T>(_ s: @escaping ((Result<T, AnyError>) -> Void)) -> (T?, Error?) -> Void {
    return { t, error in
        if let t = t {
            s(.success(t))
        } else if let error = error {
            s(.failure(AnyError(error)))
        } else {
            fatalError("Expecting either result or error to be set.")
        }
    }
}

extension QuerySnapshot {
    func decoded<T>(using decoder: StructureDecoder = .init()) -> DecodeResult<[T]> where T: Decodable {
        do {
            let data = documents.map { $0.data() }
            let d = try decoder.decode([T].self, from: data)
            return .success(d)
        } catch {
            return .failure(.conversionError(error))
        }
    }
}

extension DocumentSnapshot {
    func decoded<T>(using decoder: StructureDecoder = .init()) -> DecodeResult<T> where T: Decodable {
        guard exists, let data = data() else {
            return .failure(.noValuePresent)
        }
        do {
            let d = try decoder.decode(T.self, from: data)
            return .success(d)
        } catch {
            return .failure(.conversionError(error))
        }
    }
}

public extension DocumentReference {
    func observeSingleEvent<T>(using decoder: StructureDecoder = .init(),
                               with block: @escaping (DecodeResult<T>) -> Void)
        where T: Decodable {
            getDocument(completion: wrap { result in
                switch result {
                case .success(let v):
                    block(v.decoded(using: decoder))
                case .failure(let e):
                    block(.failure(.internalError(e.error)))
                }
            })
    }


    func observe<T>(using decoder: StructureDecoder = .init(),
                    with block: @escaping (DecodeResult<T>) -> Void) -> ListenerRegistration
        where T: Decodable {
            let registration = addSnapshotListener(wrap { result in
                switch result {
                case .success(let v):
                    block(v.decoded(using: decoder))
                case .failure(let e):
                    block(.failure(.internalError(e.error)))
                }
            })
            return registration
    }

    func setValue<T>(_ value: T, using encoder: StructureEncoder = .init()) throws where T: Encodable {
        let data = try encoder.encode(value)
        guard let dict = data as? [String: Any] else {
            throw EncodeError.expectingDictionaryEncodedData
        }
        self.setData(dict)
    }
}

public extension CollectionReference {
    public func observeSingleEvent<T>(using decoder: StructureDecoder = .init(),
                                      with block: @escaping (DecodeResult<[T]>) -> Void)
        where T: Decodable {
            getDocuments(completion: wrap { result in
                switch result {
                case .success(let v):
                    block(v.decoded(using: decoder))
                case .failure(let e):
                    block(.failure(.internalError(e.error)))
                }
            })
    }

    /**
     Creates an `Observable` representing the stream of changes to a value from the Realtime Database

     - Parameter decoder: An optional custom configured StructureDecoder instance to use for decoding.

     - Returns: An `Observable` of the requested generic type wrapped in a `DecodeResult`.
     */
    public func observe<T>(using decoder: StructureDecoder = .init(),
                           with block: @escaping (DecodeResult<[T]>) -> Void) -> ListenerRegistration
        where T: Decodable {
            let registration = addSnapshotListener(wrap { result in
                switch result {
                case .success(let v):
                    block(v.decoded(using: decoder))
                case .failure(let e):
                    block(.failure(.internalError(e.error)))
                }
            })
            return registration
    }

}

public extension Firestore {

    func observeSingleEvent<T>(at path: Path<T>,
                               using decoder: StructureDecoder = .init(),
                               with block: @escaping (DecodeResult<T>) -> Void)
        where T: Decodable {
            return self[path].observeSingleEvent(using: decoder,
                                                 with: block)
    }

    func observe<T>(at path: Path<T>,
                    using decoder: StructureDecoder = .init(),
                    with block: @escaping (DecodeResult<T>) -> Void) -> ListenerRegistration
        where T: Decodable {
            return self[path].observe(using: decoder,
                                      with: block)
    }

    // MARK: Observing Collection Paths
    public func observeSingleEvent<T>(at path: Path<T>.Collection,
                                      using decoder: StructureDecoder = .init(),
                                      with block: @escaping (DecodeResult<[T]>) -> Void)
        where T: Decodable {
            return self[path].observeSingleEvent(using: decoder,
                                                 with: block)
    }

    public func observe<T>(at path: Path<T>.Collection,
                           using decoder: StructureDecoder = .init(),
                           with block: @escaping (DecodeResult<[T]>) -> Void) -> ListenerRegistration
        where T: Decodable {
            return self[path].observe(using: decoder,
                                      with: block)
    }

    // MARK: Adding and Setting
    public func setValue<T>(at path: Path<T>, value: T, using encoder: StructureEncoder = .init()) throws where T: Encodable {
        try self[path].setValue(value, using: encoder)
    }

    public func addValue<T>(at path: Path<T>.Collection, value: T, using encoder: StructureEncoder = .init()) throws where T: Encodable {
        let docRef = self[path].document()
        try docRef.setValue(value, using: encoder)
    }

    subscript<T>(path: Path<T>) -> DocumentReference {
        return document(path.rendered)
    }

    subscript<T>(path: Path<T>.Collection) -> CollectionReference {
        return collection(path.rendered)
    }
}
