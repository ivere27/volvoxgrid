// VolvoxGridView.swift
//
// SwiftUI bridge over `VolvoxGridUIView`. Drop the view into a SwiftUI
// hierarchy, hand it a client + grid id, and it renders the engine
// output as its content.
//
// Construction note: the client + gridId need to outlive the view's
// lifecycle. Hold them in a `@StateObject` ViewModel or `@State`
// container in the parent; don't construct a fresh client on every
// SwiftUI body re-evaluation.

#if canImport(SwiftUI)
import SwiftUI

#if canImport(UIKit)
import UIKit

@available(iOS 13.0, tvOS 13.0, *)
public struct VolvoxGridView: UIViewRepresentable {

    public let client: VolvoxGridClient
    public let gridId: Int64

    public init(client: VolvoxGridClient, gridId: Int64) {
        self.client = client
        self.gridId = gridId
    }

    public func makeUIView(context: Context) -> VolvoxGridUIView {
        let view = VolvoxGridUIView(frame: .zero)
        view.bind(client: client, gridId: gridId)
        return view
    }

    public func updateUIView(_ view: VolvoxGridUIView, context: Context) {
        if view.client !== client || view.gridId != gridId {
            view.bind(client: client, gridId: gridId)
        }
    }

    public static func dismantleUIView(_ view: VolvoxGridUIView, coordinator: ()) {
        view.unbind()
    }
}
#elseif canImport(AppKit)
import AppKit

@available(macOS 10.15, *)
public struct VolvoxGridView: NSViewRepresentable {

    public let client: VolvoxGridClient
    public let gridId: Int64

    public init(client: VolvoxGridClient, gridId: Int64) {
        self.client = client
        self.gridId = gridId
    }

    public func makeNSView(context: Context) -> VolvoxGridNSView {
        let view = VolvoxGridNSView(frame: .zero)
        view.bind(client: client, gridId: gridId)
        return view
    }

    public func updateNSView(_ view: VolvoxGridNSView, context: Context) {
        if view.client !== client || view.gridId != gridId {
            view.bind(client: client, gridId: gridId)
        }
    }

    public static func dismantleNSView(_ view: VolvoxGridNSView, coordinator: ()) {
        view.unbind()
    }
}
#endif

#endif
