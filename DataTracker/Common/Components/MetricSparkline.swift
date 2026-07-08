import SwiftUI

struct MetricSparkline: View {
    let data: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard data.count > 1 else { return }
                
                let stepX = geometry.size.width / CGFloat(data.count - 1)
                let minVal = data.min() ?? 0
                let maxVal = data.max() ?? 1
                let range = maxVal - minVal
                
                let points = data.enumerated().map { index, value in
                    let x = CGFloat(index) * stepX
                    let y = geometry.size.height - (CGFloat(value - minVal) / CGFloat(range == 0 ? 1 : range)) * geometry.size.height
                    return CGPoint(x: x, y: y)
                }
                
                path.move(to: points[0])
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(
                LinearGradient(
                    colors: [color, color.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        MetricSparkline(data: [10, 20, 15, 30, 25, 40, 35], color: Theme.primary)
            .frame(width: 100, height: 40)
    }
}
