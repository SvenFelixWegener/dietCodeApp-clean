import SwiftUI

struct DiaryView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var vm = DiaryViewModel()
    let token: String
    @State private var selectedDate = ISO8601DateFormatter().string(from: Date()).prefix(10).description

    var body: some View {
        NavigationStack {
            Form {
                Section("Tag") {
                    TextField("Datum (YYYY-MM-DD)", text: $selectedDate)
                    Button("Laden") {
                        Task {
                            await vm.load(container: container, token: token, date: selectedDate)
                        }
                    }
                }

                if let day = vm.day {
                    Section("Mahlzeit") {
                        Picker("Typ", selection: $vm.selectedMeal) {
                            ForEach(mealTypes, id: \.self) { Text($0) }
                        }

                        ForEach(day.meals[vm.selectedMeal] ?? []) { entry in
                            VStack(alignment: .leading) {
                                Text(entry.food)
                                Text("\(Int(entry.grams)) g · \(Int(entry.kcal)) kcal · \(Int(entry.protein)) g Protein")
                                    .font(.caption)
                            }
                        }
                    }

                    Section("Produkt hinzufügen") {
                        TextField("Suche", text: $vm.searchTerm)

                        Button("Suchen") {
                            Task {
                                await vm.searchProducts(container: container, token: token)
                            }
                        }

                        ForEach(vm.searchResults) { product in
                            Button("\(product.productName) – \(Int(product.kcalPer100g)) kcal") {
                                vm.addProduct(product)
                            }
                        }
                    }

                    Section {
                        Button("Speichern") {
                            Task {
                                await vm.save(container: container, token: token)
                            }
                        }
                        .disabled(vm.isSaving)
                    }
                }
            }
            .navigationTitle("Tagebuch")
            .task {
                await vm.load(container: container, token: token, date: selectedDate)
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
            .overlay {
                if vm.isLoading || vm.isSaving {
                    ProgressView()
                }
            }
        }
    }
}
