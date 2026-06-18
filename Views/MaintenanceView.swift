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
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
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
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(minHeight: 36)
                .background(isSelected ? Color.appAccent : Color.appSurface2)
                .clipShape(Capsule())
                .contentShape(Capsule())
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
        if let miles = record.reminderIntervalMiles {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            let formatted = formatter.string(from: miles as NSNumber) ?? "\(Int(miles))"
            return "Every \(formatted) mi"
        }
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
    @State private var reminderMiles: Double? = nil
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

    private let reminderOptions: [(label: String, miles: Double?)] = [
        ("No reminder", nil),
        ("Every 500 mi", 500),
        ("Every 1,000 mi", 1_000),
        ("Every 2,000 mi", 2_000),
        ("Every 3,000 mi", 3_000),
        ("Every 5,000 mi", 5_000),
        ("Every 10,000 mi", 10_000)
    ]

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 0) {
                AppSheetHeader(
                    title: "Log Maintenance",
                    onCancel: onCancel,
                    isSaveDisabled: type == .custom && title.trimmingCharacters(in: .whitespaces).isEmpty,
                    onSave: {
                        let finalTitle: String
                        if type == .custom {
                            let trimmed = title.trimmingCharacters(in: .whitespaces)
                            finalTitle = trimmed.isEmpty ? "Custom" : trimmed
                        } else {
                            finalTitle = type.displayName
                        }
                        let record = MaintenanceRecord(
                            bikeID: selectedBikeID,
                            type: type,
                            title: finalTitle,
                            date: date,
                            odometerMiles: Double(odometerText),
                            notes: notes.isEmpty ? nil : notes,
                            reminderIntervalDays: nil,
                            reminderIntervalMiles: reminderMiles
                        )
                        onSave(record, receiptPhoto)
                    }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        AppFieldGroup(label: "TYPE") {
                            Menu {
                                ForEach(MaintenanceType.allCases, id: \.self) { t in
                                    Button { type = t } label: {
                                        Label(t.displayName, systemImage: t.iconName)
                                    }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: type.iconName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.appAccent)
                                    Text(type.displayName)
                                        .foregroundStyle(Color.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.textSecondary)
                                }
                                .appFieldChrome()
                            }
                        }

                        if type == .custom {
                            AppFieldGroup(label: "TITLE") {
                                TextField("", text: $title, prompt: .appPrompt("Title"))
                                    .foregroundStyle(Color.textPrimary)
                                    .appFieldChrome()
                            }
                        }

                        AppFieldGroup(label: "DATE") {
                            DatePicker("", selection: $date, displayedComponents: [.date])
                                .labelsHidden()
                                .tint(Color.appAccent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .appFieldChrome()
                        }

                        if !garageStore.bikes.isEmpty {
                            AppFieldGroup(label: "BIKE") {
                                Menu {
                                    Button("No specific bike") { selectedBikeID = nil }
                                    ForEach(garageStore.bikes.filter { !$0.effectiveIsArchived }) { bike in
                                        Button(bike.title) { selectedBikeID = bike.id }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedBikeLabel)
                                            .foregroundStyle(Color.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Color.textSecondary)
                                    }
                                    .appFieldChrome()
                                }
                            }
                        }

                        AppFieldGroup(label: "ODOMETER (OPTIONAL)") {
                            TextField("", text: $odometerText,
                                      prompt: Text("Miles at service").foregroundColor(Color.textGhost))
                                .keyboardType(.decimalPad)
                                .foregroundStyle(Color.textPrimary)
                                .appFieldChrome()
                        }

                        AppFieldGroup(label: "NOTES (OPTIONAL)") {
                            TextField("", text: $notes, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .foregroundStyle(Color.textPrimary)
                                .appFieldChrome()
                        }

                        AppFieldGroup(label: "REMINDER") {
                            Menu {
                                ForEach(reminderOptions.indices, id: \.self) { i in
                                    Button(reminderOptions[i].label) {
                                        reminderMiles = reminderOptions[i].miles
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedReminderLabel)
                                        .foregroundStyle(Color.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.textSecondary)
                                }
                                .appFieldChrome()
                            }
                        }

                        AppFieldGroup(label: "RECEIPT PHOTO (OPTIONAL)") {
                            Button { showPhotoDialog = true } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.appSurface2)
                                        .frame(height: 110)
                                    if let receiptPhoto {
                                        Image(uiImage: receiptPhoto)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 110)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    } else {
                                        VStack(spacing: 6) {
                                            Image(systemName: "doc.text.viewfinder")
                                                .font(.system(size: 22, weight: .semibold))
                                                .foregroundStyle(Color.appAccent)
                                            Text("Add Receipt Photo")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Color.textPrimary)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
        .onChange(of: type) { _, newType in
            if title.isEmpty || MaintenanceType.allCases.map(\.displayName).contains(title) {
                title = newType.displayName
            }
        }
        .onAppear { if title.isEmpty { title = type.displayName } }
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

    private var selectedReminderLabel: String {
        reminderOptions.first(where: { $0.miles == reminderMiles })?.label ?? "No reminder"
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
    @State private var reminderMiles: Double?
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

    private let reminderOptions: [(label: String, miles: Double?)] = [
        ("No reminder", nil),
        ("Every 500 mi", 500),
        ("Every 1,000 mi", 1_000),
        ("Every 2,000 mi", 2_000),
        ("Every 3,000 mi", 3_000),
        ("Every 5,000 mi", 5_000),
        ("Every 10,000 mi", 10_000)
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
        _reminderMiles = State(initialValue: record.reminderIntervalMiles)
    }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 0) {
                AppSheetHeader(
                    title: "Edit Record",
                    onCancel: onCancel,
                    isSaveDisabled: type == .custom && title.trimmingCharacters(in: .whitespaces).isEmpty,
                    onSave: {
                        let finalTitle: String
                        if type == .custom {
                            let trimmed = title.trimmingCharacters(in: .whitespaces)
                            finalTitle = trimmed.isEmpty ? "Custom" : trimmed
                        } else {
                            finalTitle = type.displayName
                        }
                        let updated = MaintenanceRecord(
                            id: record.id, createdAt: record.createdAt,
                            bikeID: selectedBikeID, type: type,
                            title: finalTitle,
                            date: date,
                            odometerMiles: Double(odometerText),
                            notes: notes.isEmpty ? nil : notes,
                            reminderIntervalDays: nil,
                            reminderIntervalMiles: reminderMiles,
                            receiptPhotoFilename: record.receiptPhotoFilename,
                            isArchived: record.isArchived,
                            remoteID: record.remoteID, syncStatus: record.syncStatus
                        )
                        onSave(updated, receiptPhoto)
                    }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        AppFieldGroup(label: "TYPE") {
                            Menu {
                                ForEach(MaintenanceType.allCases, id: \.self) { t in
                                    Button { type = t } label: {
                                        Label(t.displayName, systemImage: t.iconName)
                                    }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: type.iconName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.appAccent)
                                    Text(type.displayName)
                                        .foregroundStyle(Color.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.textSecondary)
                                }
                                .appFieldChrome()
                            }
                        }

                        if type == .custom {
                            AppFieldGroup(label: "TITLE") {
                                TextField("", text: $title, prompt: .appPrompt("Title"))
                                    .foregroundStyle(Color.textPrimary)
                                    .appFieldChrome()
                            }
                        }

                        AppFieldGroup(label: "DATE") {
                            DatePicker("", selection: $date, displayedComponents: [.date])
                                .labelsHidden()
                                .tint(Color.appAccent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .appFieldChrome()
                        }

                        if !garageStore.bikes.isEmpty {
                            AppFieldGroup(label: "BIKE") {
                                Menu {
                                    Button("No specific bike") { selectedBikeID = nil }
                                    ForEach(garageStore.bikes.filter { !$0.effectiveIsArchived }) { bike in
                                        Button(bike.title) { selectedBikeID = bike.id }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedBikeLabel)
                                            .foregroundStyle(Color.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Color.textSecondary)
                                    }
                                    .appFieldChrome()
                                }
                            }
                        }

                        AppFieldGroup(label: "ODOMETER (OPTIONAL)") {
                            TextField("", text: $odometerText, prompt: .appPrompt("Miles at service"))
                                .keyboardType(.decimalPad)
                                .foregroundStyle(Color.textPrimary)
                                .appFieldChrome()
                        }

                        AppFieldGroup(label: "NOTES (OPTIONAL)") {
                            TextField("", text: $notes, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .foregroundStyle(Color.textPrimary)
                                .appFieldChrome()
                        }

                        AppFieldGroup(label: "REMINDER") {
                            Menu {
                                ForEach(reminderOptions.indices, id: \.self) { i in
                                    Button(reminderOptions[i].label) {
                                        reminderMiles = reminderOptions[i].miles
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedReminderLabel)
                                        .foregroundStyle(Color.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.textSecondary)
                                }
                                .appFieldChrome()
                            }
                        }

                        AppFieldGroup(label: "RECEIPT PHOTO (OPTIONAL)") {
                            Button { showPhotoDialog = true } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.appSurface2)
                                        .frame(height: 110)
                                    if let img = receiptPhoto {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 110)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    } else if let url = receiptURL,
                                              let data = try? Data(contentsOf: url),
                                              let img = UIImage(data: data) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 110)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    } else {
                                        VStack(spacing: 6) {
                                            Image(systemName: "doc.text.viewfinder")
                                                .font(.system(size: 22, weight: .semibold))
                                                .foregroundStyle(Color.appAccent)
                                            Text("Replace Receipt Photo")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Color.textPrimary)
                                        }
                                    }
                                }
                                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
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

    private var selectedReminderLabel: String {
        reminderOptions.first(where: { $0.miles == reminderMiles })?.label ?? "No reminder"
    }

    private var selectedBikeLabel: String {
        guard let id = selectedBikeID,
              let bike = garageStore.bikes.first(where: { $0.id == id }) else {
            return "No specific bike"
        }
        return bike.title
    }
}

