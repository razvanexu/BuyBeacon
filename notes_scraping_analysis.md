# Analiză scraping backend — notițe (2026-08-11)

## Context
Branch curent: `refactoring/SOLID_cleaning`. Comparat cu `main` (tip `7e847b4`).

## Ce s-a verificat
1. De ce pare `SeleniumHtmlFetcher` nefolosit.
2. Dacă feature-ul de scraping e abandonat.
3. Diferențe reale între `main` și branch-ul curent, pe backend.

## Concluzii

### 1. `SeleniumHtmlFetcher` — activ, nu e cod mort
- `scraper/common/SeleniumHtmlFetcher.java` e `@Component @Primary @Profile("!test")` → candidat implicit pentru orice `HtmlFetcher` injectat fără `@Qualifier`.
- Folosit în 2 locuri:
  - `service/WebSearchServiceImp.java:34` — explicit prin `@Qualifier("seleniumHtmlFetcher")`.
  - `scraper/retailers/CarrefourScraper.java:29` — injectare fără qualifier, primește tot `SeleniumHtmlFetcher` (pentru că `JSoupHtmlFetcher` are `@Component`/`@Primary` comentate).
- Motivul pentru care un IDE/analiză statică îl arată "fără utilizări": legătura se face doar prin Spring DI (scanare + qualifier ca string), nu prin `new SeleniumHtmlFetcher()` sau import direct.

### 2. Există DOUĂ căi de scraping, complet separate
**A. Web-search scraping (Selenium → Google search) — ACTIV, cale principală**
- Flow real folosit de aplicație:
  `frontend api_service.dart:32 (POST /api/shops/find)` → `ShopFinderController` → `ShopFinderServiceImp` → `WebSearchServiceImp` (Selenium, caută "produs + store near me" pe Google) → `GooglePlacesClient` (geocodare).
- Rulează la fiecare actualizare a listei de cumpărături. E coloana vertebrală a descoperirii de magazine.

**B. Scraping per-retailer (`CarrefourScraper`) — construit dar NECONECTAT**
- `ScraperController` (`GET /api/scrape/products`) → `ScraperOrchestrator` → `CarrefourScraper` (scrapuiește carrefour.ro pentru produse + preț + url).
- Frontend-ul NU apelează niciodată `/api/scrape` (verificat: zero referințe în `frontend/lib`).
- `ShopFinderServiceImp` (fluxul A) nu apelează deloc `ScraperOrchestrator`. Cele două căi nu comunică între ele.
- Are teste (`CarrefourScraperTest`), cod curat, dar orfan funcțional.

### 3. Nu e o regresie a refactorului SOLID — era așa de la început
- `git diff main refactoring/SOLID_cleaning` pe `scraper/`, `service/`, `controller/` → **o singură diferență**: `Product.java` are `.trim()` pe `name` pe branch-ul curent (fix minor, restul identic).
- Istoric: `CarrefourScraper` a apărut devreme (`aed5662 refactored the scaper to decouple it...`, `7f11239 more refactoring (cleaning up and organizing by folders)`), deja pe `main`.
- Diagramele găsite în `Diagrams/backend_flowchart_new_approach.mmd` arată un plan de arhitectură viitoare unde scraping-ul per-retailer devine **fallback de ultimă instanță** într-un lanț: API-uri retailer → API agregator → Google Places → web scraping. Arhitectura curentă (`backend_flowchart.mmd`) corespunde cu ce rulează azi (Selenium ca pas central, fără fallback-uri).
- Concluzie: `CarrefourScraper`/`ScraperController` = piesă neterminată, pregătită pentru o iterație viitoare, lăsată intenționat neconectată — nu ceva stricat sau pierdut în refactor.

### 4. Diferențe reale main vs. branch curent (tot repo-ul)
- **Backend Java**: doar `.trim()` în `Product.java` + reindentare whitespace în `BackendApplication.java`. Nimic altceva.
- **Backend — fișiere de proiect noi** (nu erau versionate pe `main`): `.gitignore`, `.gitattributes`, `.mvn/`, `mvnw`, `mvnw.cmd`.
- **Frontend**: aici e toată munca refactorului SOLID — `ShoppingOrchestrator`, `GeofenceService`, `NotificationDecisionService`, `ProductRepository`, simplificare `ProductProvider`, UI mai "prost" (fără logică de business), teste noi/actualizate.
- **Zgomot generat**: `android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/`, `pubspec.lock` — probabil regenerate de `flutter create`/IDE, nu erau commise pe `main`.
- **Documentație de sesiune** (alt asistent AI): `GEMINI.md`, `Diagrams/*.mmd`, `Log_buffer.txt`, `gemini_discussion.txt`.

## De discutat / posibile îmbunătățiri
- [x] Decizie: **integrat** `CarrefourScraper` ca fallback/enrichment în `ShopFinderServiceImp` (nu șters, nu înlocuit fluxul principal). Vezi secțiunea 5.
- [ ] `JSoupHtmlFetcher` e complet dezactivat (`@Component`/`@Primary` comentate) — candidat de curățat dacă nu mai e nevoie de el.
- [ ] Verificat dacă merită curățenie în fișierele generate necomise (`android/`, `ios/` etc.) — clarificat dacă trebuie versionate sau adăugate în `.gitignore`.

## 5. Îmbunătățiri implementate (2026-08-11)

**A. Robustețe `SeleniumHtmlFetcher`**
- Eliminat `Thread.sleep(2000)` fix, înlocuit cu `WebDriverWait` condiționat pe `document.readyState == 'complete'` (timeout 5s, cu fallback la conținutul curent dacă expiră).
- Adăugat `pageLoadTimeout` (15s) pe driver, ca să nu rămână agățat la infinit.
- `WebDriverException` (unchecked, din Selenium) e acum prinsă și transformată în `IOException`, astfel încât handling-ul existent din `WebSearchServiceImp` (catch IOException → listă goală) funcționează și pentru crash-uri de Chrome/Selenium, nu doar pentru erori de rețea.

**B. Performanță — concurență mărginită**
- Bean nou `ScrapingConfig.scrapingExecutor()` — `ExecutorService` cu pool fix de 3 thread-uri, folosit pentru operațiile I/O-bound din `ShopFinderServiceImp` (căutare web per produs + geocodare per magazin), acum paralelizate via `CompletableFuture` în loc de secvențial. Limitat la 3 concurente intenționat (fiecare căutare web deschide un Chrome headless — nemărginit ar epuiza resursele local și ar arăta ca trafic abuziv către Google).

**C. `CarrefourScraper` conectat ca sursă de enrichment**
- `ScraperOrchestrator.tryScrapeProducts(query, retailerName)` — variantă sigură a `scrapeProducts`, prinde `IOException`/`IllegalArgumentException`, loghează și returnează listă goală în loc să propage eroare. Metoda originală `scrapeProducts` (folosită de `ScraperController`) e neatinsă.
- `ShopFinderServiceImp` verifică acum, pe lângă căutarea web generică, și dacă retailerii cunoscuți (`ENRICHMENT_RETAILERS = ["Carrefour"]`) chiar au produsul via `CarrefourScraper`; dacă da, adaugă numele retailerului ca magazin candidat garantat corect (nu doar ghicit din Google), care apoi se geocodează normal. E aditiv, nu înlocuiește rezultatele web-search.

**Teste**: `ShopFinderServiceTest` actualizat (mock nou pentru `ScraperOrchestrator`, executor single-thread real pentru determinism) + test nou `findShops_shouldAddRetailerAsCandidateShop_whenScraperConfirmsProductAvailability`. Toate cele 29 de teste backend trec (`mvn test` → BUILD SUCCESS).

**Fișiere atinse**: `SeleniumHtmlFetcher.java`, `ScrapingConfig.java` (nou), `ScraperOrchestrator.java`, `ShopFinderServiceImp.java`, `ShopFinderServiceTest.java`.