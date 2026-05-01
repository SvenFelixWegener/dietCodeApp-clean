# DietCode iOS App (SwiftUI)

Native iOS-App als eigenständiger Unterordner für DietCode. Die App nutzt **dieselben bestehenden Backend-Endpunkte** (`/api/auth/login`, `/api/day`, `/api/products/search`) und führt **keine neue Datenhaltung** ein.

## Kurzbeschreibung

- Native SwiftUI-App für iPhone mit NavigationStack + Form-basierten, iOS-typischen Flows.
- Fachlich identischer Kern-Workflow als vertikaler Slice:
  1. Login
  2. Tagesdaten laden
  3. Ziele bearbeiten
  4. Produkt suchen
  5. Mahlzeit-Eintrag hinzufügen
  6. Tagesdaten speichern
- Fehlerzustände für Netzwerk/API werden per Alert angezeigt, Lade-/Speicherzustände per ProgressView.

## Projektstruktur

```text
ios-app/
  App/
    DietCodeiOSApp.swift
    AppContainer.swift
  Views/
    RootView.swift
    LoginView.swift
    DiaryView.swift
  ViewModels/
    AppViewModel.swift
    DiaryViewModel.swift
  Models/
    Domain.swift
  Services/
    AuthService.swift
    DayService.swift
    ProductService.swift
  Networking/
    APIClient.swift
  Utilities/
    AppConfig.swift
  Resources/
  README.md
```

## Setup

1. In Xcode neues iOS-App-Target anlegen (SwiftUI / iOS 16+ empfohlen).
2. Die Dateien aus `ios-app/` ins Target übernehmen.
3. Runtime-Konfiguration setzen:
   - Environment Variable `DIETCODE_API_BASE_URL` (z. B. `https://<dein-deployment>` oder lokal `http://localhost:3000`).
4. Sicherstellen, dass bestehende API erreichbar ist und CORS/ATS entsprechend konfiguriert sind.

## Benötigte Konfigurationswerte

- `DIETCODE_API_BASE_URL`: Basis-URL des bestehenden DietCode-Backends.

## Verwendete API-Endpunkte

- `POST /api/auth/login`
  - Request: `{ username, password }`
  - Response: `{ ok, token, userHash, expiresAt }`
- `GET /api/day?date=YYYY-MM-DD`
  - Response: `{ date, meals, goals }`
- `PUT /api/day?date=YYYY-MM-DD`
  - Request: `{ date, meals, goals }`
- `POST /api/products/search`
  - Request: `{ food, brand }`
  - Response: `{ products, source }`

## Fachliche Gleichheit / bekannte Differenzen

- Datenmodelle, Felder und Endpunkte sind gleich zum Webprojekt.
- UI ist nativ iOS und nicht 1:1 vom Webformular kopiert.
- Der initiale Scope implementiert einen vollständigen vertikalen Slice; weitere Spezialflows (z. B. Barcode-Bildanalyse, Rezept-Parsing) können auf derselben Service-Schicht ergänzt werden.

## Hinweise zur späteren Auslagerung in eigenes Repository

- Ordner ist bewusst eigenständig (App/Views/ViewModels/Services/Networking/Utilities).
- Nur API-Verträge koppeln iOS und Web.
- Für Extraction:
  - `ios-app/` in neues Repo verschieben,
  - CI + Signing + Fastlane ergänzen,
  - gemeinsame API-Vertragsdoku zentral halten.
