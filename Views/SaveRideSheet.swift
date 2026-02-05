import SwiftUI

struct SaveRideSheet: View {
    @Binding var name: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Name your ride")
                .font(.headline)

            TextField("e.g. Night ride to Rutgers", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { onCancel() }
                    .buttonStyle(.bordered)

                Spacer()

                Button("Save Ride") { onSave() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
