import SwiftUI
import UIKit

struct MaintenanceView: View {
    @ObservedObject var maintenanceStore: MaintenanceStore
    @ObservedObject var garageStore: GarageStore

    @State private var showAddSheet = false
    @State private var editingRecord: MaintenanceRecord?
    @State private var selectedBikeFilter: UUID? = nil

    private var filteredRecords: [MaintenanceRecord] {
        let active = maintenanceStore.records.filter { !$0.effectiveIsArchived }
        guard let filterID = selectedBikeFilter else { return active }
        return active.filter { $0.bikeID == filterID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Due soon banner
                    let dueSoon = maintenanceStore.dueSoonRecords(withinDays: 14)
                    if !dueSoon.isEmpty {
                        dueSoonBanner(dueSoon)
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                    }

                    // Bike filter
                    if garageStore.bikes.count > 1 {
                        bikeFilterRow
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                    }

                    if filteredRecords.isEmpty {
                        EmptyStateView(
                            icon: "wrench.and.screwdriver",
                            title: "No Maintenance Records",
                            message: "Log an oil change, tire swap, or any service to track your bike's health."
                        )
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredRecords) { record in
                                MaintenanceRecordRow(
                                    record: record,
                                    bikeName: bikeName(for: record.bikeID),
                                    receiptURL: maintenanceStore.receiptPhotoURL(for: record)
                                ) {
                                    editingRecord = record
                                } onDelete: {
                                    _ = maintenanceStore.deleteRecord(id: record.id)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 120)
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { maintenanceHeader }
            .background(Color.appBg)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddSheet) {
                AddMaintenanceSheet(garageStore: garageStore) { record, photo in
                    _ = maintenanceStore.addRecord(record, photo: photo)
                    showAddSheet = false
                } onCancel: {
                    showAddSheet = false
                }
            }
            .sheet(item: $editingRecord) { record in
                EditMaintenanceSheet(
                    record: record,
                    receiptURL: maintenanceStore.receiptPhotoURL(for: record),
                    garageStore: garageStore
                ) { updated, photo in
                    var finalRecord = updated
                    if let photo,
                       let data = photo.jpegData(compressionQuality: 0.8) {
                        // Write photo ourselves since updateRecord doesn't handle it
                        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let folder = docs.appendingPathComponent("maintenance/\(record.id.uuidString)")
                        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        try? data.write(to: folder.appendingPathComponent("receipt.jpg"), options: [.atomic])
                        finalRecord = MaintenanceRecord(
                            id: updated.id, createdAt: updated.createdAt, bikeID: updated.bikeID,
                            type: updated.type, title: updated.title, date: updated.date,
                            odometerMiles: updated.odometerMiles, notes: updated.notes,
                            reminderIntervalDays: updated.reminderIntervalDays,
                            reminderIntervalMiles: updated.reminderIntervalMiles,
                            receiptPhotoFilename: "receipt.jpg", isArchived: updated.isArchived,
                            remoteID: updated.remoteID, syncStatus: updated.syncStatus
                        )
                    }
                    _ = maintenanceStore.updateRecord(finalRecord)
                    editingRecord = nil
                } onCancel: {
                    editingRecord = nil
                }
            }
        }
    }

    private var maintenanceHeader: some View {
        HStack {
            Text("Maintenance")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Button { showAddSheet = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.appBg)
    }

    @ViewBuilder
    private func dueSoonBanner(_ records: [MaintenanceRecord]) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(records.count) item\(records.count == 1 ? "" : "s") due soon")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(records.prefix(2).map(\.title).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var bikeFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", id: nil)
                ForEach(garageStore.bikes.filter { !$0.effectiveIsArchived }) { bike in
                    filterChip(label: bike.title, id: bike.id)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterChip(label: String, id: UUID?) -> some View {
        let isSelected = selectedBikeFilter == id
        return Button { selectedBikeFilter = id } label: {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : Color.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.appAccent : Color.appSurface2)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func bikeName(for bikeID: UUID?) -> String? {
        guard let bikeID else { return nil }
        return garageStore.bikes.first(where: { $0.id == bikeID })?.title
    }
}

// MARK: - Record Row

private struct MaintenanceRecordRow: View {
    let record: MaintenanceRecord
    let bikeName: String?
    let receiptURL: URL?
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    private var isDue: Bool { record.isDateReminderDue() }

    private var dueBadge: String? {
        guard let days = record.daysTilDue() else { return nil }
        if days < 0 { return "Overdue" }
        if days == 0 { return "Due today" }
        return "Due in \(days)d"
    }

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isDue ? Color.orange.opacity(0.18) : Color.appSurface2)
                        .frame(width: 44, height: 44)
                    Image(systemName: record.type.iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isDue ? .orange : Color.appAccent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(record.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        if let badge = dueBadge {
                            Text(badge)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isDue ? .white : Color.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(isDue ? Color.red : Color.orange.opacity(0.18))
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 8) {
                        Text(formattedDate(record.date))
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                        if let bike = bikeName {
                            Text("·")
                                .foregroundStyle(Color.textGhost)
                            Text(bike)
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(1)
                        }
                        if let odometer = record.odometerMiles {
                            Text("·")
                                .foregroundStyle(Color.textGhost)
                            Text(String(format: "%.0f mi", odometer))
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }

                    if let notes = record.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(Color.textTertiary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit") { onEdit() }
            Button("Delete", role: .destructive) { showDeleteConfirm = true }
        }
        .confirmationDialog("Delete this record?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

// MARK: - Add Sheet

private struct AddMaintenanceSheet: View {
    @ObservedObject var garageStore: GarageStore
    let onSave: (MaintenanceRecord, UIImage?) -> Void
    let onCancel: () -> Void

    @State private var type: MaintenanceType = .oilChange
    @State private var title = ""
    @State private var date = Date()
    @State private var selectedBikeID: UUID?
    @State private var odometerText = ""
    @State private var notes = ""
    @State private var reminderDays: Int? = nil
    @State private var receiptPhoto: UIImage?
    @State private var showPhotoDialog = false
    @State private var photoSource: PhotoPickerSource?

    private enum PhotoPickerSource: String, Identifiable {
        case camera, library
        var id: String { rawValue }
        var sourceType: UIImagePickerController.SourceType {
            self == .camera ? .camera : .photoLibrary
        }
    }

    private let reminderOptions: [(label: String, days: Int?)] = [
        ("No reminder", nil),
        ("30 days", 30),
        ("60 days", 60),
        ("90 days", 90),
        ("6 months", 180),
        ("1 year", 365)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Log Maintenance")
                    .font(.headline)
                    .padding(.top, 4)

                // Type
                Picker("Type", selection: $type) {
                    ForEach(MaintenanceType.allCases, id: \.self) { t in
                        Label(t.displayName, systemImage: t.iconName).tag(t)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: type) { _, newType in
                    if title.isEmpty || MaintenanceType.allCases.map(\.displayName).contains(title) {
                        title = newType.displayName
                    }
                }
                .onAppear { if title.isEmpty { title = type.displayName } }

                // Title
                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)

                // Date
                DatePicker("Date", selection: $date, displayedComponents: [.date])
                    .foregroundStyle(Color.textPrimary)

                // Bike
                if !garageStore.bikes.isEmpty {
                    Menu {
                        Button("No specific bike") { selectedBikeID = nil }
                        ForEach(garageStore.bikes.filter { !$0.effectiveIsArchived }) { bike in
                            Button(bike.title) { selectedBikeID = bike.id }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bike")
                                    .font(.caption)
                                    .foregroundStyle(Color.textSecondary)
                                Text(selectedBikeLabel)
                                    .foregroundStyle(Color.textPrimary)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.appSurface2)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                // Odometer
                TextField("Odometer at service (miles, optional)", text: $odometerText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)

                // Notes
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .textFieldStyle(.roundedBorder)

                // Reminder
                Picker("Reminder", selection: Binding(
                    get: { reminderOptions.firstIndex(where: { $0.days == reminderDays }) ?? 0 },
                    set: { reminderDays = reminderOptions[$0].days }
                )) {
                    ForEach(reminderOptions.indices, id: \.self) { i in
                        Text(reminderOptions[i].label).tag(i)
                    }
                }
                .pickerStyle(.menu)

                // Receipt photo
                Button { showPhotoDialog = true } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 80)
                        if let receiptPhoto {
                            Image(uiImage: receiptPhoto)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 80)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.viewfinder")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.appAccent)
                                Text("Add Receipt Photo (optional)")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)

                HStack {
                    Button("Cancel") { onCancel() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Save") {
                        let record = MaintenanceRecord(
                            bikeID: selectedBikeID,
                            type: type,
                            title: title.isEmpty ? type.displayName : title,
                            date: date,
                            odometerMiles: Double(odometerText),
                            notes: notes.isEmpty ? nil : notes,
                            reminderIntervalDays: reminderDays
                        )
                        onSave(record, receiptPhoto)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appAccent)
                    .disabled(title.isEmpty && type == .custom)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
        .confirmationDialog("Receipt Photo", isPresented: $showPhotoDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { photoSource = .camera }
            }
            Button("Choose from Library") { photoSource = .library }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $photoSource) { src in
            UIKitImagePicker(sourceType: src.sourceType) { receiptPhoto = $0 }
                .ignoresSafeArea()
        }
    }

    private var selectedBikeLabel: String {
        guard let id = selectedBikeID,
              let bike = garageStore.bikes.first(where: { $0.id == id }) else {
            return "No specific bike"
        }
        return bike.title
    }
}

// MARK: - Edit Sheet

private struct EditMaintenanceSheet: View {
    let record: MaintenanceRecord
    let receiptURL: URL?
    @ObservedObject var garageStore: GarageStore
    let onSave: (MaintenanceRecord, UIImage?) -> Void
    let onCancel: () -> Void

    @State private var type: MaintenanceType
    @State private var title: String
    @State private var date: Date
    @State private var selectedBikeID: UUID?
    @State private var odometerText: String
    @State private var notes: String
    @State private var reminderDays: Int?
    @State private var receiptPhoto: UIImage?
    @State private var showPhotoDialog = false
    @State private var photoSource: PhotoPickerSource?

    private enum PhotoPickerSource: String, Identifiable {
        case camera, library
        var id: String { rawValue }
        var sourceType: UIImagePickerController.SourceType {
            self == .camera ? .camera : .photoLibrary
        }
    }

    private let reminderOptions: [(label: String, days: Int?)] = [
        ("No reminder", nil),
        ("30 days", 30),
        ("60 days", 60),
        ("90 days", 90),
        ("6 months", 180),
        ("1 year", 365)
    ]

    init(record: MaintenanceRecord, receiptURL: URL?, garageStore: GarageStore,
         onSave: @escaping (MaintenanceRecord, UIImage?) -> Void,
         onCancel: @escaping () -> Void) {
        self.record = record
        self.receiptURL = receiptURL
        self.garageStore = garageStore
        self.onSave = onSave
        self.onCancel = onCancel
        _type = State(initialValue: record.type)
        _title = State(initialValue: record.title)
        _date = State(initialValue: record.date)
        _selectedBikeID = State(initialValue: record.bikeID)
        _odometerText = State(initialValue: record.odometerMiles.map { String(format: "%.0f", $0) } ?? "")
        _notes = State(initialValue: record.notes ?? "")
        _reminderDays = State(initialValue: record.reminderIntervalDays)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Edit Record")
                        .font(.headline)
                        .padding(.top, 4)
                    Spacer()
                    Button("Save") {
                        let updated = MaintenanceRecord(
                            id: record.id, createdAt: record.createdAt,
                            bikeID: selectedBikeID, type: type,
                            title: title.isEmpty ? type.displayName : title,
                            date: date,
                            odometerMiles: Double(odometerText),
                            notes: notes.isEmpty ? nil : notes,
                            reminderIntervalDays: reminderDays,
                            reminderIntervalMiles: record.reminderIntervalMiles,
                            receiptPhotoFilename: record.receiptPhotoFilename,
                            isArchived: record.isArchived,
                            remoteID: record.remoteID, syncStatus: record.syncStatus
                        )
                        onSave(updated, receiptPhoto)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                }

                Picker("Type", selection: $type) {
                    ForEach(MaintenanceType.allCases, id: \.self) { t in
                        Label(t.displayName, systemImage: t.iconName).tag(t)
                    }
                }
                .pickerStyle(.menu)

                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)

                DatePicker("Date", selection: $date, displayedComponents: [.date])
                    .foregroundStyle(Color.textPrimary)

                if !garageStore.bikes.isEmpty {
                    Menu {
                        Button("No specific bike") { selectedBikeID = nil }
                        ForEach(garageStore.bikes.filter { !$0.effectiveIsArchived }) { bike in
                            Button(bike.title) { selectedBikeID = bike.id }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bike")
                                    .font(.caption)
                                    .foregroundStyle(Color.textSecondary)
                                Text(selectedBikeLabel)
                                    .foregroundStyle(Color.textPrimary)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.appSurface2)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                TextField("Odometer at service (miles, optional)", text: $odometerText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)

                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .textFieldStyle(.roundedBorder)

                Picker("Reminder", selection: Binding(
                    get: { reminderOptions.firstIndex(where: { $0.days == reminderDays }) ?? 0 },
                    set: { reminderDays = reminderOptions[$0].days }
                )) {
                    ForEach(reminderOptions.indices, id: \.self) { i in
                        Text(reminderOptions[i].label).tag(i)
                    }
                }
                .pickerStyle(.menu)

                // Receipt photo
                Button { showPhotoDialog = true } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 80)
                        if let img = receiptPhoto {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 80)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else if let url = receiptURL,
                                  let data = try? Data(contentsOf: url),
                                  let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 80)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.viewfinder")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.appAccent)
                                Text("Add Receipt Photo (optional)")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)

                Button("Cancel") { onCancel() }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
        .confirmationDialog("Receipt Photo", isPresented: $showPhotoDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { photoSource = .camera }
            }
            Button("Choose from Library") { photoSource = .library }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $photoSource) { src in
            UIKitImagePicker(sourceType: src.sourceType) { receiptPhoto = $0 }
                .ignoresSafeArea()
        }
    }

    private var selectedBikeLabel: String {
        guard let id = selectedBikeID,
              let bike = garageStore.bikes.first(where: { $0.id == id }) else {
            return "No specific bike"
        }
        return bike.title
    }
}
