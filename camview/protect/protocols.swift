//
//  protocols.swift
//  camview
//
//  Created by Peter Richardson on 6/30/25.
//


protocol CustomCSVConvertible {
    static var csvHeader: String { get }
    func csvDescription() -> String
}

protocol ProtectAPIObject: Decodable, Comparable, Identifiable, CustomCSVConvertible, CustomStringConvertible {
    static var v1APIPath: String { get }
}
