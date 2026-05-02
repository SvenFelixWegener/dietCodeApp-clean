internal import SwiftUI

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

struct DiaryView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var vm = DiaryViewModel()
    let token: String

    @State private var selectedDate = Date()
    @State private var expandedMeals = Set(mealTypes)
    @State private var isScannerSheetPresented = false

    private var selectedDateString: String {
        dateFormatter.string(from: selectedDate)
    }

    private var kcalConsumed: Double {
        allEntries.reduce(0) { $0 + $1.kcal }
    }

    private var proteinConsumed: Double {
        allEntries.reduce(0) { $0 + $1.protein }
    }

    private var allEntries: [MealEntry] {
        guard let day = vm.day else { return [] }
        return mealTypes.flatMap { day.meals[$0] ?? [] }
    }

    var body: some View {
        NavigationStack {
            List {
                DailySummaryCard(
                    consumedKcal: kcalConsumed,
                    kcalGoal: 2500,
                    consumedProtein: proteinConsumed,
                    proteinGoal: 130
                )
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)

                Section("Datum") {
                    DatePicker("Tag", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .onChange(of: selectedDate) { _ in
                            Task { await vm.load(container: container, token: token, date: selectedDateString) }
                        }
                }

                if vm.day != nil {
                    Section("Mahlzeiten") {
                        ForEach(mealTypes, id: \.self) { meal in
                            MealAccordionSection(
                                mealName: meal,
                                entries: vm.day?.meals[meal] ?? [],
                                isExpanded: expandedMeals.contains(meal),
                                onToggle: { toggleMeal(meal) },
                                onDelete: { offsets in vm.deleteEntries(at: offsets, meal: meal) }
                            )
                        }
                    }

                    Section("Produkt hinzufügen") {
                        Picker("Mahlzeit", selection: $vm.addMealSelection) {
                            ForEach(mealTypes, id: \.self) { Text($0) }
                        }

                        TextField("Suche", text: $vm.searchTerm)
                        Button("Barcode scannen") {
                            isScannerSheetPresented = true
                        }

                        Button("Suchen") {
                            Task { await vm.searchProducts(container: container, token: token) }
                        }

                        ForEach(vm.searchResults) { product in
                            Button {
                                vm.addProduct(product)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(product.productName)
                                    Text("\(Int(product.kcalPer100g)) kcal / 100g")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Section {
                        Button("Speichern") {
                            Task { await vm.save(container: container, token: token) }
                        }
                        .disabled(vm.isSaving)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tagebuch")
            .task {
                await vm.load(container: container, token: token, date: selectedDateString)
            }
            .alert(
                "Fehler",
                isPresented: Binding(
                    get: { vm.errorMessage != nil },
                    set: { _ in vm.errorMessage = nil }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .sheet(isPresented: $isScannerSheetPresented) {
                BarcodeScannerView(
                    onCodeScanned: { barcode in
                        isScannerSheetPresented = false
                        Task {
                            await vm.applyScannedBarcode(barcode, container: container, token: token)
                        }
                    },
                    onClose: {
                        isScannerSheetPresented = false
                    }
                )
            }
            .overlay {
                if vm.isLoading || vm.isSaving {
                    ProgressView()
                }
            }
        }
    }

    private func toggleMeal(_ meal: String) {
        if expandedMeals.contains(meal) {
            expandedMeals.remove(meal)
        } else {
            expandedMeals.insert(meal)
        }
    }
}

private struct DailySummaryCard: View {
    let consumedKcal: Double
    let kcalGoal: Double
    let consumedProtein: Double
    let proteinGoal: Double

    private var remainingKcal: Double { max(0, kcalGoal - consumedKcal) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Heute")
                .font(.headline)

            HStack(alignment: .center, spacing: 16) {
                Gauge(value: min(consumedKcal, kcalGoal), in: 0...kcalGoal) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryCircular)
                .tint(.blue)
                .frame(width: 86, height: 86)

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Int(consumedKcal)) kcal")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Verbleibend: \(Int(remainingKcal)) kcal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Ziel: \(Int(kcalGoal)) kcal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Protein")
                    Spacer()
                    Text("\(Int(consumedProtein)) / \(Int(proteinGoal)) g")
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: min(consumedProtein, proteinGoal), total: proteinGoal)
                    .tint(.green)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

private struct MealAccordionSection: View {
    let mealName: String
    let entries: [MealEntry]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: (IndexSet) -> Void

    var body: some View {
        DisclosureGroup(isExpanded: Binding(get: { isExpanded }, set: { _ in onToggle() })) {
            if entries.isEmpty {
                Text("Keine Einträge")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(entries) { entry in
                    MealEntryRow(entry: entry)
                }
                .onDelete(perform: onDelete)
            }
        } label: {
            HStack {
                Text(mealName)
                Spacer()
                Text("\(entries.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MealEntryRow: View {
    let entry: MealEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.food)
            Text("\(Int(entry.grams)) g · \(Int(entry.kcal)) kcal · \(Int(entry.protein)) g Protein")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
