import SwiftUI
import UIKit

enum ShareBackgroundMode: String, CaseIterable, Identifiable {
    case fill = "Fill"
    case fit = "Fit"
    var id: String { rawValue }
}

struct ShareCardView: View {
    let background: UIImage
    let summary: RideSummary
    let title: String
    let route: [RidePoint]

    let mode: ShareBackgroundMode
    let tightPadding: Bool
    let textColor: Color
    let routeColor: Color

    var body: some View {
        GeometryReader { geo in
            let canvas = geo.size
            let imgSize = background.size

            // Visible rect where the "real" photo is shown
            let visibleRect: CGRect = {
                switch mode {
                case .fill:
                    return CGRect(origin: .zero, size: canvas)
                case .fit:
                    // scaledToFit rect
                    let scale = min(canvas.width / imgSize.width, canvas.height / imgSize.height)
                    let w = imgSize.width * scale
                    let h = imgSize.height * scale
                    let x = (canvas.width - w) / 2
                    let y = (canvas.height - h) / 2
                    return CGRect(x: x, y: y, width: w, height: h)
                }
            }()

            let side = canvas.width * 0.05
            let topSafe = canvas.height * (tightPadding ? 0.045 : 0.06)
            let bottomSafe = canvas.height * (tightPadding ? 0.075 : 0.10)

            let titleSize = max(16, canvas.width * 0.075)
            let subtitleSize = max(9, canvas.width * 0.038)
            let statLabelSize = max(8, canvas.width * 0.035)
            let statValueSize = max(14, canvas.width * 0.065)
            let brandSize = max(7, canvas.width * 0.032)

            let headerHeight = canvas.height * 0.18
            let footerHeight = canvas.height * 0.28
            let rightColumnWidth = canvas.width * 0.38

            let routeRect = CGRect(
                x: visibleRect.minX,
                y: visibleRect.minY + topSafe + headerHeight,
                width: visibleRect.width,
                height: max(1, visibleRect.height - topSafe - bottomSafe - headerHeight - footerHeight)
            )

            ZStack {
                // Blur-fill background (so Fit mode doesn't show black bars)
                Image(uiImage: background)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 18)
                    .overlay(Color.black.opacity(0.20))
                    .frame(width: canvas.width, height: canvas.height)
                    .clipped()

                // Main image
                Group {
                    if mode == .fill {
                        Image(uiImage: background)
                            .resizable()
                            .scaledToFill()
                            .frame(width: canvas.width, height: canvas.height)
                            .clipped()
                    } else {
                        Image(uiImage: background)
                            .resizable()
                            .scaledToFit()
                            .frame(width: canvas.width, height: canvas.height)
                    }
                }

                // Gradient only over the visible photo rect (so overlays are readable)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.35), .clear, Color.black.opacity(0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: visibleRect.width, height: visibleRect.height)
                    .position(x: visibleRect.midX, y: visibleRect.midY)

                // Route trace drawn only between the top and bottom text blocks
                RouteTraceOverlay(
                    route: route,
                    drawRect: routeRect,
                    contentInsets: EdgeInsets(top: 0, leading: side, bottom: 0, trailing: side),
                    color: routeColor
                )
                .allowsHitTesting(false)

                // Text overlay constrained to visible photo rect (prevents cut-off with Fit)
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: titleSize, weight: .bold, design: .default))
                        Text(dateText(summary.startTime))
                            .font(.system(size: subtitleSize, weight: .semibold, design: .default))
                            .opacity(0.9)
                    }
                    .frame(height: headerHeight, alignment: .topLeading)

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            statText("Distance",
                                     String(format: "%.1f mi", summary.distanceMi),
                                     labelSize: statLabelSize,
                                     valueSize: statValueSize)
                            Spacer()
                            statText("Time",
                                     summary.durationText,
                                     labelSize: statLabelSize,
                                     valueSize: statValueSize,
                                     alignment: .trailing,
                                     textAlignment: .trailing)
                                .frame(width: rightColumnWidth, alignment: .trailing)
                        }

                        HStack {
                            statText("Max Speed",
                                     String(format: "%.1f mph", summary.maxSpeedMph),
                                     labelSize: statLabelSize,
                                     valueSize: statValueSize)
                            Spacer()
                            statText("Max Lean",
                                     String(format: "%.0f°", summary.maxAbsLeanDeg),
                                     labelSize: statLabelSize,
                                     valueSize: statValueSize,
                                     alignment: .trailing,
                                     textAlignment: .trailing)
                                .frame(width: rightColumnWidth, alignment: .trailing)
                        }

                        Text("MotorcycleTrackShare")
                            .font(.system(size: brandSize, weight: .semibold, design: .default))
                            .opacity(0.85)
                            .padding(.top, 2)
                    }
                    .frame(height: footerHeight, alignment: .bottomLeading)
                }
                .foregroundStyle(textColor)
                .shadow(color: .black.opacity(0.75), radius: 3, x: 0, y: 1)
                .padding(.leading, side)
                .padding(.trailing, side)
                .padding(.top, topSafe)
                .padding(.bottom, bottomSafe)
                .frame(width: visibleRect.width, height: visibleRect.height, alignment: .topLeading)
                .position(x: visibleRect.midX, y: visibleRect.midY)
            }
            .frame(width: canvas.width, height: canvas.height)
            .clipped()
        }
    }

    private func statText(_ label: String,
                          _ value: String,
                          labelSize: CGFloat,
                          valueSize: CGFloat,
                          alignment: HorizontalAlignment = .leading,
                          textAlignment: TextAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(.system(size: labelSize, weight: .semibold, design: .default))
                .opacity(0.9)
                .multilineTextAlignment(textAlignment)
            Text(value)
                .font(.system(size: valueSize, weight: .bold, design: .default))
                .multilineTextAlignment(textAlignment)
        }
    }

    private func dateText(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }
}

// MARK: - Route trace overlay

private struct RouteTraceOverlay: View {
    let route: [RidePoint]
    let drawRect: CGRect
    let contentInsets: EdgeInsets
    let color: Color

    var body: some View {
        GeometryReader { _ in
            if route.count >= 2 {
                let pts = normalize(route: route, in: drawRect, insets: contentInsets)

                Path { p in
                    p.move(to: pts[0])
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(color.opacity(0.95),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .shadow(color: .black.opacity(0.55), radius: 6, x: 0, y: 2)

                // start/end dots
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                    .position(pts.first!)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)

                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                    .position(pts.last!)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            }
        }
    }

    private func normalize(route: [RidePoint], in rect: CGRect, insets: EdgeInsets) -> [CGPoint] {
        let lats = route.map { $0.lat }
        let lons = route.map { $0.lon }

        var minLat = lats.min() ?? 0
        var maxLat = lats.max() ?? 0
        var minLon = lons.min() ?? 0
        var maxLon = lons.max() ?? 0

        if abs(maxLat - minLat) < 0.000001 { maxLat = minLat + 0.000001 }
        if abs(maxLon - minLon) < 0.000001 { maxLon = minLon + 0.000001 }

        let x0 = rect.minX + insets.leading
        let x1 = rect.maxX - insets.trailing
        let y0 = rect.minY + insets.top
        let y1 = rect.maxY - insets.bottom

        let w = max(1, x1 - x0)
        let h = max(1, y1 - y0)

        return route.map { pt in
            let xNorm = (pt.lon - minLon) / (maxLon - minLon)
            let yNorm = 1.0 - (pt.lat - minLat) / (maxLat - minLat)
            return CGPoint(x: x0 + CGFloat(xNorm) * w,
                           y: y0 + CGFloat(yNorm) * h)
        }
    }
}
