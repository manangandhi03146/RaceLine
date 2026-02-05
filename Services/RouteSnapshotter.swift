//
//  RouteSnapshotter.swift
//  MotorcycleTrackShare
//
//  Created by Manan Gandhi on 1/14/26.
//

import Foundation
import MapKit
import UIKit

enum RouteSnapshotter {
    static func makeRouteImage(route: [RidePoint],
                               size: CGSize = CGSize(width: 520, height: 520)) async -> UIImage? {
        guard route.count >= 2 else { return nil }

        let coords = route.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        let region = regionThatFits(coords: coords)

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.mapType = .standard
        options.showsBuildings = false

        let snapshotter = MKMapSnapshotter(options: options)

        do {
            let snap = try await snapshotter.start()
            let base = snap.image

            // Draw the polyline on top of the snapshot
            let renderer = UIGraphicsImageRenderer(size: size)
            let out = renderer.image { ctx in
                base.draw(at: .zero)

                let points = coords.map { snap.point(for: $0) }

                // Route style
                ctx.cgContext.setLineWidth(6)
                ctx.cgContext.setLineJoin(.round)
                ctx.cgContext.setLineCap(.round)

                // Shadow so it pops on the map
                ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 1),
                                        blur: 4,
                                        color: UIColor.black.withAlphaComponent(0.5).cgColor)

                // White route line (simple + clean)
                ctx.cgContext.setStrokeColor(UIColor.white.cgColor)

                ctx.cgContext.beginPath()
                ctx.cgContext.move(to: points[0])
                for p in points.dropFirst() { ctx.cgContext.addLine(to: p) }
                ctx.cgContext.strokePath()

                // Start/end dots (optional)
                if let start = points.first, let end = points.last {
                    ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
                    ctx.cgContext.setFillColor(UIColor.white.cgColor)
                    ctx.cgContext.fillEllipse(in: CGRect(x: start.x - 5, y: start.y - 5, width: 10, height: 10))
                    ctx.cgContext.fillEllipse(in: CGRect(x: end.x - 5, y: end.y - 5, width: 10, height: 10))
                }
            }

            return out
        } catch {
            print("Route snapshot failed:", error)
            return nil
        }
    }

    // Compute a padded region that contains all coordinates
    private static func regionThatFits(coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        var minLat = coords[0].latitude
        var maxLat = coords[0].latitude
        var minLon = coords[0].longitude
        var maxLon = coords[0].longitude

        for c in coords {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)

        // Add padding so line isn’t on the edge
        let latDelta = max(0.002, (maxLat - minLat) * 1.6)
        let lonDelta = max(0.002, (maxLon - minLon) * 1.6)

        return MKCoordinateRegion(center: center,
                                  span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
    }
}
