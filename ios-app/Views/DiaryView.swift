internal import SwiftUI
import PhotosUI

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "de_DE")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

private let dayDisplayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "de_DE")
    formatter.dateFormat = "d. MMM"
    return formatter
}()

struct DiaryView: View {
    let token: String
    var body: some View { DiaryDashboardView(token: token) }
}

struct DiaryDashboardView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var vm = DiaryViewModel()
    let token: String

    @State private var selectedDate = Date()
    @State private var expandedMeals = Set(mealTypes)
    @State private var isQuickAddPresented = false
    @State private var editingEntry: EntryEditContext?

    private var selectedDateString: String { dateFormatter.string(from: selectedDate) }
    private var entries: [MealEntry] { mealTypes.flatMap { vm.day?.meals[$0] ?? [] } }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: 16) {
                    header
                    SummaryHeroCard(consumedKcal: entries.reduce(0) { $0 + $1.kcal }, kcalGoal: 2500, consumedProtein: entries.reduce(0) { $0 + $1.protein }, proteinGoal: 130)

                    ForEach(mealTypes, id: \.self) { meal in
                        MealDashboardCard(mealName: meal, entries: vm.day?.meals[meal] ?? [], isExpanded: expandedMeals.contains(meal), onToggle: { toggleMeal(meal) }, onAdd: { vm.addMealSelection = meal; isQuickAddPresented = true }, onDeleteEntry: { vm.deleteEntry($0.id, meal: meal) }, onDuplicateEntry: { vm.duplicateEntry($0.id, meal: meal) }, onEditEntry: { editingEntry = EntryEditContext(meal: meal, entry: $0) })
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))

            FloatingAddButton { isQuickAddPresented = true }
                .padding(.trailing, 22)
                .padding(.bottom, 24)
        }
        .navigationTitle("Tagebuch")
        .task { await vm.load(container: container, token: token, date: selectedDateString) }
        .sheet(isPresented: $isQuickAddPresented) { QuickAddSheet(token: token, vm: vm, selectedMeal: $vm.addMealSelection).environmentObject(container) }
        .sheet(item: $editingEntry) { context in
            PortionEditorSheet(title: context.entry.food, grams: context.entry.grams, kcalPer100g: context.entry.kcal * 100 / max(context.entry.grams, 1), proteinPer100g: context.entry.protein * 100 / max(context.entry.grams, 1), actionTitle: "Speichern") { vm.updateEntry(context.entry.id, meal: context.meal, grams: $0) }
        }
        .alert("Fehler", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) { Button("OK", role: .cancel) {} } message: { Text(vm.errorMessage ?? "") }
        .overlay { if vm.isLoading || vm.isSaving || vm.isAnalyzingIngredients { ProgressView("Zutaten werden analysiert …") } }
    }

    private var header: some View {
        HStack {
            Button { shiftDate(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            DateSelectorPill(date: selectedDate)
            Spacer()
            Button { shiftDate(1) } label: { Image(systemName: "chevron.right") }
        }
    }

    private func shiftDate(_ days: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectedDate = next
        Task { await vm.load(container: container, token: token, date: selectedDateString) }
    }

    private func toggleMeal(_ meal: String) { expandedMeals.formSymmetricDifference([meal]) }
}

struct DateSelectorPill: View {
    let date: Date
    var body: some View {
        Text("\(Calendar.current.isDateInToday(date) ? "Heute" : "Tag") · \(dayDisplayFormatter.string(from: date))")
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color(.systemBackground)).shadow(color: .black.opacity(0.06), radius: 6, y: 2))
    }
}

struct SummaryHeroCard: View { let consumedKcal: Double; let kcalGoal: Double; let consumedProtein: Double; let proteinGoal: Double
    var body: some View { VStack(alignment: .leading, spacing: 16) { HStack(spacing: 16) { CalorieProgressRing(consumed: consumedKcal, goal: kcalGoal); VStack(alignment: .leading, spacing: 6) { Text("\(Int(consumedKcal)) kcal").font(.system(size: 34, weight: .bold, design: .rounded)); Text("\(Int(max(0, kcalGoal - consumedKcal))) kcal verbleibend").foregroundStyle(.secondary); Text("Ziel: \(Int(kcalGoal)) kcal").font(.subheadline).foregroundStyle(.secondary) } }; MacroProgressBar(title: "Protein", current: consumedProtein, goal: proteinGoal, color: .green) }.padding(20).background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.07), radius: 10, y: 4)) }
}
struct CalorieProgressRing: View { let consumed: Double; let goal: Double; var body: some View { ZStack { Circle().stroke(Color.blue.opacity(0.15), lineWidth: 14); Circle().trim(from: 0, to: min(1, consumed / max(goal, 1))).stroke(LinearGradient(colors: [Color.blue.opacity(0.7), .blue], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 14, lineCap: .round)).rotationEffect(.degrees(-90)) }.frame(width: 92, height: 92) } }
struct MacroProgressBar: View { let title: String; let current: Double; let goal: Double; let color: Color; var body: some View { VStack(alignment: .leading, spacing: 6) { HStack { Text(title).font(.subheadline.weight(.semibold)); Spacer(); Text("\(Int(current)) / \(Int(goal)) g").font(.caption).foregroundStyle(.secondary) }; ProgressView(value: min(current, goal), total: goal).tint(color) } } }

struct MealDashboardCard: View {
    let mealName: String; let entries: [MealEntry]; let isExpanded: Bool
    let onToggle: () -> Void; let onAdd: () -> Void
    let onDeleteEntry: (MealEntry) -> Void; let onDuplicateEntry: (MealEntry) -> Void; let onEditEntry: (MealEntry) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { VStack(alignment: .leading, spacing: 2) { Text(mealName).font(.headline); Text("\(entries.count) Einträge · \(Int(entries.reduce(0){$0+$1.kcal})) kcal").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button(action: onAdd) { Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(.blue) } }
                .contentShape(Rectangle()).onTapGesture(perform: onToggle)
            if isExpanded {
                if entries.isEmpty { Text("Noch keine Einträge").font(.callout).foregroundStyle(.secondary) }
                else {
                    ForEach(Dictionary(grouping: entries, by: { $0.groupId ?? $0.id }).keys.sorted(), id: \.self) { key in
                        let items = Dictionary(grouping: entries, by: { $0.groupId ?? $0.id })[key] ?? []
                        if let first = items.first, first.groupType == "ai_ingredients", items.count > 1 {
                            AIIngredientGroupCard(entries: items, onDeleteGroup: { items.forEach(onDeleteEntry) }, onEditEntry: onEditEntry)
                        } else {
                            ForEach(items) { entry in FoodEntryRow(entry: entry).onTapGesture { onEditEntry(entry) }.contextMenu { Button("Duplizieren") { onDuplicateEntry(entry) }; Button("Löschen", role: .destructive) { onDeleteEntry(entry) } } }
                        }
                    }
                }
            }
        }.padding(16).background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 8, y: 3))
    }
}
struct FoodEntryRow: View { let entry: MealEntry; var body: some View { HStack { VStack(alignment: .leading) { Text(entry.food); Text("\(Int(entry.grams)) g · \(Int(entry.protein)) g Protein").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(Int(entry.kcal)) kcal").font(.subheadline.weight(.semibold)) } } }
struct FloatingAddButton: View { let action: () -> Void; var body: some View { Button(action: action) { Image(systemName: "plus").font(.system(size: 20, weight: .bold)).foregroundStyle(.white).frame(width: 58, height: 58).background(Circle().fill(Color.blue).shadow(color: .blue.opacity(0.35), radius: 12, y: 5)) } } }

struct QuickAddSheet: View {
    @EnvironmentObject private var container: AppContainer
    let token: String
    @ObservedObject var vm: DiaryViewModel
    @Binding var selectedMeal: String
    @State private var selectedProduct: Product?
    @State private var isScannerShown = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showAnalysisReview = false

    var body: some View {
        NavigationStack {
            FoodSearchView(vm: vm, token: token, onBarcodeTap: { isScannerShown = true }) { selectedProduct = $0 }
                .navigationTitle("Quick Add")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Picker("Mahlzeit", selection: $selectedMeal) { ForEach(mealTypes, id: \.self) { Text($0) } }.pickerStyle(.menu) }
                    ToolbarItem(placement: .topBarLeading) { PhotosPicker(selection: $selectedPhoto, matching: .images) { Label("Zutatenliste fotografieren", systemImage: "camera") } }
                }
                .onChange(of: selectedPhoto) { _ in
                    Task {
                        if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                            await vm.analyzeIngredientsImage(container: container, token: token, imageData: data)
                            showAnalysisReview = vm.ingredientAnalysis != nil
                        }
                    }
                }
        }
        .sheet(item: $selectedProduct) { product in PortionEditorSheet(title: product.productName, grams: 100, kcalPer100g: product.kcalPer100g, proteinPer100g: product.proteinPer100g, actionTitle: "Hinzufügen") { vm.addProduct(product, grams: $0) }.presentationDetents([.medium]) }
        .sheet(isPresented: $showAnalysisReview) { if let analysis = vm.ingredientAnalysis { IngredientAnalysisReviewSheet(vm: vm, analysis: analysis, selectedMeal: $selectedMeal) } }
        .sheet(isPresented: $isScannerShown) { BarcodeScannerView(onCodeScanned: { code in isScannerShown = false; Task { await vm.applyScannedBarcode(code, container: container, token: token) } }, onClose: { isScannerShown = false }) }
    }
}

struct FoodSearchView: View {
    @EnvironmentObject private var container: AppContainer
    @ObservedObject var vm: DiaryViewModel
    let token: String
    let onBarcodeTap: () -> Void
    let onSelect: (Product) -> Void
    var body: some View { List { Section { TextField("Suche nach Produkt", text: $vm.searchTerm).textInputAutocapitalization(.never).autocorrectionDisabled().onChange(of: vm.searchTerm) { _ in Task { try? await Task.sleep(nanoseconds: 300_000_000); await vm.searchProducts(container: container, token: token) } }; Button("Barcode scannen", action: onBarcodeTap) }; Section("Ergebnisse") { ForEach(vm.searchResults) { FoodSearchResultRow(product: $0).onTapGesture { onSelect($0) } } } } }
}
struct FoodSearchResultRow: View { let product: Product; var body: some View { VStack(alignment: .leading, spacing: 4) { Text(product.productName); HStack { Text("\(Int(product.kcalPer100g)) kcal / 100g").font(.caption).foregroundStyle(.secondary); Text("Protein \(Int(product.proteinPer100g))g").font(.caption2.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Color.green.opacity(0.15))).foregroundStyle(.green) } } } }

struct PortionEditorSheet: View { let title: String; @State var grams: Double; let kcalPer100g: Double; let proteinPer100g: Double; let actionTitle: String; let onSubmit: (Double) -> Void; @Environment(\.dismiss) private var dismiss
    var body: some View { VStack(alignment: .leading, spacing: 16) { Text(title).font(.headline); HStack { Text("Menge"); Spacer(); Text("\(Int(grams)) g").foregroundStyle(.secondary) }; Slider(value: $grams, in: 10...400, step: 5); HStack { ForEach([50.0,100,150], id: \.self) { p in Button("\(Int(p))g") { grams = p }.buttonStyle(.bordered) } }; Text("\(Int(kcalPer100g * grams / 100)) kcal · \(Int(proteinPer100g * grams / 100)) g Protein").foregroundStyle(.secondary); Button(actionTitle) { onSubmit(grams); dismiss() }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity) }.padding() }
}

private struct EntryEditContext: Identifiable { let id = UUID(); let meal: String; let entry: MealEntry }

struct IngredientAnalysisReviewSheet: View {
    @ObservedObject var vm: DiaryViewModel
    let analysis: AnalyzeIngredientsResponse
    @Binding var selectedMeal: String
    @State private var selections: [String: Bool] = [:]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section { HStack { Text("Gesamt"); Spacer(); Text("\(Int(analysis.totals.kcal ?? 0)) kcal · \(Int(analysis.totals.protein ?? 0)) g") }; ConfidenceBadge(confidence: analysis.confidence) }
                Section("Erkannte Zutaten") {
                    ForEach(analysis.ingredients) { ingredient in
                        Toggle(isOn: Binding(get: { selections[ingredient.id.uuidString, default: true] }, set: { selections[ingredient.id.uuidString] = $0 })) { AIIngredientRow(ingredient: ingredient) }
                    }
                }
            }
            .navigationTitle("Erkannte Zutaten")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Als Gruppe hinzufügen") { let selected = analysis.ingredients.filter { selections[$0.id.uuidString, default: true] }; vm.addAnalyzedIngredientsToMeal(meal: selectedMeal, selected: selected, confidence: analysis.confidence, notes: analysis.notes); dismiss() } } }
        }
    }
}

struct AIIngredientGroupCard: View { let entries: [MealEntry]; let onDeleteGroup: () -> Void; let onEditEntry: (MealEntry) -> Void
    var body: some View { VStack(alignment: .leading, spacing: 6) { HStack { Label(entries.first?.groupTitle ?? "AI Zutatenliste", systemImage: "sparkles"); Spacer(); ConfidenceBadge(confidence: entries.first?.confidence ?? "medium") }; Text("\(entries.count) Zutaten · ca. \(Int(entries.reduce(0){$0+$1.kcal})) kcal · \(Int(entries.reduce(0){$0+$1.protein})) g Protein").font(.caption).foregroundStyle(.secondary); ForEach(entries) { entry in FoodEntryRow(entry: entry).onTapGesture { onEditEntry(entry) } } }.padding(10).background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground))).contextMenu { Button("Gruppe löschen", role: .destructive, action: onDeleteGroup) } }
}
struct AIIngredientRow: View { let ingredient: AnalyzedIngredient; var body: some View { VStack(alignment: .leading) { Text(ingredient.name); Text("\(Int(ingredient.amount ?? 100)) \(ingredient.unit ?? "g") · \(Int(ingredient.estimatedKcal ?? 0)) kcal · \(Int(ingredient.estimatedProtein ?? 0)) g Protein").font(.caption).foregroundStyle(.secondary) } } }
struct ConfidenceBadge: View { let confidence: String; var color: Color { confidence == "high" ? .green : (confidence == "medium" ? .orange : .gray) }; var text: String { confidence == "high" ? "hoch" : (confidence == "medium" ? "mittel" : "niedrig") }; var body: some View { Text(text).font(.caption2.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(color.opacity(0.18))).foregroundStyle(color) } }
