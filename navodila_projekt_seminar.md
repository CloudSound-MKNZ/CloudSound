# Navodila za projekt in seminar

**Računalniške storitve v oblaku (2025/2026)**

## 1. Uvod

Cilj vaj pri predmetu Računalniške storitve v oblaku (RSO) je uspešna realizacija izbranega projekta spletne in/ali mobilne aplikacije, pri čemer je potrebno vključiti koncepte, obravnavane na predavanjih. Projekt se razvija v skupinah z dvema ali tremi študenti (če želite, lahko delati tudi sami), končan in uspešno zagovorjen projekt pa je pogoj za pristop k izpitu. Vaje lahko opravite tudi s seminarjem.

## 2. Potek razvoja in mejniki

Razvoj projekta poteka v tedenskem tempu in sledi predavanjem – predlagamo sprotno delo. Med semestrom bodo pomembnejši mejniki, za katere bodo dodatna navodila in obrazci za oddajo objavljena na spletni učilnici:

1. **Razdelitev v skupine** (rok: 19. 10. 2025): Prijava skupine na spletni učilnici.

2. **Prijava teme projekta ali seminarja** (rok: 26. 10. 2025): Oddaja prijave na spletni učilnici, prijava teme vključuje podroben opis izbrane teme, seznam članov ekipe, arhitekturno zasnovo rešitve, izbrano ogrodje ter povezavo do ustvarjene organizacije na GitHub oz. GitLab.

3. **Neobvezna vmesna predstavitev** (8.-14. 12. 2025): Kratek javni »pitch« projekta ali seminarja na vajah, predstavitev arhitekturne zasnove in že razvitih delov.
   - [do 10 % ocene vaj]

4. **Oddaja projekta ali seminarja** (rok: 11. 1. 2026): Oddaja kode in poročila na spletni učilnici.
   - [do 10 % ocene vaj]

5. **Zagovor projekta ali seminarja** (5.-18. 1. 2026): Pregled bistvenih funkcionalnosti razvite aplikacije in vključenih konceptov iz seznama zahtev.
   - [do 80 % ocene vaj]

## 3. Priprava na delo in razvojno okolje

Zahteva za uspešno opravljene vaje je, da vaš projekt sproti objavljate na GitHub (oziroma primerljivo platformo, na primer GitLab). Ustvarite si organizacijo v kateri boste ustvarili repozitorije za vašo aplikacijo. Repozitoriji naj bodo javni.

Na predavanjih bo uporabljeno mikrostoritveno ogrodje KumuluzEE, ki nudi močno podporo za koncepte, obravnavane pri predmetu. Pri izdelavi projektov lahko uporabite katerikoli programski jezik in ogrodje, prav tako lahko različne mikrostoritve razvijate v različnih ogrodjih in programskih jezikih. Na spletni učilnici bo na voljo vzorčni skeletni primer za Javo in KumuluzEE.

Kot študenti Univerze v Ljubljani imate dostop do študentske licence za produkte in razvojna okolja JetBrains. Študentski račun lahko ustvarite na tem naslovu. Razmeroma popularno razvojno okolje je Visual Studio Code. Na GitHub Education si dodatno lahko aktivirate študentski paket, v katerem se nahaja nekaj uporabnih orodij.

Pri razvoju svojih aplikacij boste lahko poskrbeli tudi za njihovo namestitev v oblak. V ta namen si ustvarite račun pri poljubnem ponudniku oblačnih storitev. Priporočamo, da izberete ponudnika, ki že ponuja prednameščeno okolje Kubernetes, saj vam bo to olajšalo delo. Nekaj možnosti:

- **Azure (Azure for Education)**: $100 kreditov. Za registracijo pojdite na Azure for Students in sledite postopku.
- **Google Cloud Platform**: Študenti lahko izkoristite brezplačen kredit.
- **AWS (Amazon Web Services)**: AWS ponuja brezplačen nivo storitev za nove uporabnike.
- **DigitalOcean**: Ponuja enostavne oblačne storitve z opcijo upravljanja Kubernetes okolij.
- **IBM Cloud**: Omogoča uporabo brezplačnih storitev ter upravljanje Kubernetes klustrov.
- **Oracle Cloud Infrastructure**: Oracle ponuja brezplačni nivo storitev, ki vključuje dve vedno brezplačni virtualni računalniški instanci, baze podatkov, shranjevanje in več. Študenti lahko prav tako pridobijo dodatne kredite ob registraciji za izobraževalne namene.

Priporočamo, da za učinkovito organizacijo skupinskega dela ter sledenje nalogam in napredku projekta ustvarite GitHub projekt ali uporabite orodja, kot sta JIRA ali Asana.

## 4. Seznam zahtev in ocenjevalni list

Tabela 1 prikazuje seznam projektnih zahtev, ki vključujejo obvezne zahteve (poleg oddaje projekta) in izbirne zahteve. Za uspešno zaključene vaje je potrebno opraviti/vključiti vse obvezne zahteve in zbrati skupno najmanj 50 % točk (50 točk). Zahteve se preverjajo med zagovorom projekta in se ocenjujejo glede na obseg in kakovost implementacije.

Minimalne zahteve so določene za vsakega člana skupine in se smiselno prilagodijo glede na število članov v skupini, kjer je to mogoče (npr. če je minimalna zahteva razvoj dveh mikrostoritev, je za tričlansko skupino minimalna zahteva šest mikrostoritev).

### Tabela 1: Seznam zahtev

| Postavka | Opis in minimalne zahteve | Obvezno | Točke |
|----------|---------------------------|---------|-------|
| **Repozitorij** | Ustvarite repozitorij za projekt z uporabo Git.<br><br>Minimalne zahteve:<br>• Nastavite Git repozitorij na platformah, kot so GitHub, GitLab ali Bitbucket.<br>• Vključite datoteko README z informacijami o projektu (kratek opis, navodila za namestitev itd.).<br>• Uvedite strategijo razvejitve (npr. main, dev). | ✓ | 1 |
| **Mikrostoritve in »cloud-native« aplikacija** | Nastavite razvojno okolje in definirajte strukturo projekta, zasnujte in implementirajte aplikacijo z uporabo arhitekture mikrostoritev, jih namestite na Kubernetes gručo ter nastavite bazo podatkov za trajno shranjevanje podatkov.<br><br>Minimalne zahteve:<br>• Uporabite IDE (npr. Visual Studio Code, IntelliJ IDEA).<br>• Nastavite osnovno strukturo projekta v skladu z najboljšimi praksami (npr. direktoriji za izvorno kodo, teste in konfiguracijske datoteke).<br>• Inicializirajte razvojno okolje z vsemi potrebnimi datotekami.<br>• Dokumentirajte navodila za nastavitev za druge razvijalce.<br>• Razdelite aplikacijo na vsaj dve mikrostoritve, kjer je vsaka odgovorna za določeno funkcionalnost.<br>• Zagotovite, da mikrostoritve komunicirajo prek HTTP ali sporočilnega protokola.<br>• Napišite Kubernetes manifeste (YAML datoteke) za namestitev mikrostoritev.<br>• Uporabite funkcionalnosti Kubernetes, kot so storitve, namestitve in podi za orkestracijo.<br>• Upoštevajte »cloud-native« koncepte.<br>• Uporabite relacijsko (npr. PostgreSQL, MySQL) ali NoSQL (npr. MongoDB) bazo podatkov.<br>• Zagotovite, da je baza podatkov dostopna iz mikrostoritev in mikrostoritve vanjo shranjujejo ali iz nje berejo podatke.<br>• V podatkovno bazo dodajte nekaj tabel in podatkov. | ✓ | 6 |
| **Dokumentacija** | Ustvarite tehnično dokumentacijo za projekt.<br><br>Minimalne zahteve:<br>• Vključite vse relevantne informacije o aplikaciji glede na primere dobrih praks.<br>• Uporabite Markdown ali druga orodja za dokumentacijo za jasno organizacijo vsebine. | ✓ | 2 |
| **Dokumentacija API** | Ustvarite dokumentacijo za API.<br><br>Minimalne zahteve:<br>• Uporabite orodja, kot sta Swagger/OpenAPI ali Postman, za dokumentiranje končnih točk API.<br>• Vključite podrobnosti o formatih zahtev/odgovorov, primerih tovorov in sporočilih o napakah za vsako mikrostoritev. | | 3 |
| **Cevovod CI/CD** | Uvedite CI/CD (nenehno integracijo in nenehno dobavo).<br><br>Minimalne zahteve:<br>• Uporabite CI/CD orodje (npr. GitHub Actions, GitLab CI, Jenkins) za avtomatizacijo gradnje in testiranja.<br>• Zagotovite, da se koda samodejno testira in namesti na Kubernetes gručo ob spremembah v glavni veji. | | 5 |
| **Helm charts** | Uporabi Helm Charts za upravljanje Kubernetes namestitev.<br><br>Minimalne zahteve:<br>• Ustvarite Helm Charts za mikrostoritve.<br>• Parametrizirajte konfiguracije za različna okolja (razvoj, produkcija).<br>• Namestite in posodobite aplikacije v Kubernetes okolju s Helm Charts. | | 4 |
| **Namestitev v oblak** | Namestite aplikacijo v oblačnem okolju.<br><br>Minimalne zahteve:<br>• Uporabite oblačne platforme, kot so AWS, Azure ali Google Cloud.<br>• Zagotovite, da je Kubernetes gruča in aplikacija javno dostopna. | ✓ | 5 |
| **»Serverless« funkcija** | Razvijte in namestite »serverless« funkcijo za del aplikacije.<br><br>Minimalne zahteve:<br>• Uporabite npr. AWS Lambda, Azure Functions ali Google Cloud Functions.<br>• Implementirajte funkcijo, ki se proži na podlagi dogodkov (npr. HTTP zahtevek).<br>• Opazujte delovanje funkcije in prilagajajte zmogljivost na podlagi obremenitev. | | 5 |
| **Zunanji API** | V aplikacijo integrirajte vsaj en zunanji API.<br><br>Minimalne zahteve:<br>• Uporabite zunanji API znotraj ene izmed mikrostoritev.<br>• Ustrezno izvedite potrditev verodostojnosti (ang. authentication). | | 3 |
| **Večnajemništvo (ang. multitenancy)** | Implementirajte večnajemniško arhitekturo.<br><br>Minimalne zahteve:<br>• Načrtujete in implementirajte večnajemništvo na nivoju mikrostoritev, Kubernetes in podatkovne baze.<br>• Prikažite delovanje z več najemniki. | | 5 |
| **Preverjanje zdravja** | Implementirajte preverjanja zdravja za mikrostoritve.<br><br>Minimalne zahteve:<br>• Ustvarite končne točke za preverjanje zdravja, ki vrnejo stanje vsake mikrostoritve.<br>• Zagotovite, da lahko Kubernetes spremlja te končne točke za zdravje storitve. | | 4 |
| **GraphQL in gRPC** | Uporabite GraphQL in gRPC za komunikacijo med storitvami.<br><br>Minimalne zahteve:<br>• Implementirajte GraphQL za poizvedovanje po podatkih v eni mikrostoritvi.<br>• Uporabite gRPC za komunikacijo med dvema storitvama.<br>• Prikažite uporabo obeh tehnologij v aplikaciji. | | 4 |
| **Sporočilni sistemi** | Implementirajte sporočilni sistem za komunikacijo med storitvami.<br><br>Minimalne zahteve:<br>• Uporabite sporočilnega posrednika (npr. RabbitMQ, Kafka, NATS Jetstream) za asinhrono komunikacijo med mikrostoritvami.<br>• Zagotovite, da vsaj dve mikrostoritvi komunicirata prek sporočilnega sistema. | | 5 |
| **»Event sourcing« in CQRS** | Implementirajte vzorce »Event Sourcing« in CQRS.<br><br>Minimalne zahteve:<br>• Implementirajte »Event Sourcing« za sledenje sprememb podatkov.<br>• Uporabite CQRS za ločene modele branja in pisanja.<br>• Demonstrirajte, kako se lahko ponovno predvajajo dogodki za obnovo stanja. | | 5 |
| **Centralizirano beleženje dnevnikov** | Implementirajte centraliziran sistem za beleženje in analizo dnevnikov.<br><br>Minimalne zahteve:<br>• Uporabite orodja, kot so ELK Stack ali Fluentd za zbiranje dnevnikov.<br>• Centralizirajte dnevnike vseh storitev.<br>• Nastavite opozorila na podlagi zaznanih vzorcev v dnevnikih. | | 5 |
| **Zbiranje metrik** | Implementirajte sistem za zbiranje metrik delovanja aplikacije.<br><br>Minimalne zahteve:<br>• Uporabite Prometheus, Grafana ali podobno orodje za zbiranje in vizualizacijo metrik.<br>• Spremljajte ključne metrike aplikacije, kot so odzivnost in obremenitev.<br>• Prikažite uporabo zbranih metrik za optimizacijo delovanja aplikacije. | | 5 |
| **Izolacija in toleranca napak** | Zagotovite izolacijo mikrostoritev in odpornost na napake.<br><br>Minimalne zahteve:<br>• Implementirajte mehanizme za toleranco napak, kot so Circuit Breaker in Retry.<br>• Prikažite, kako sistem ohranja delovanje tudi ob napakah ene storitve.<br>• Pojasnite, kako izolacija storitev zmanjšuje vpliv napak na celoten sistem. | | 5 |
| **Upravljanje s konfiguracijo** | Implementirajte koncepte za upravljanja konfiguracije.<br><br>Minimalne zahteve:<br>• Identificirajte vso konfiguracijo vaše aplikacije.<br>• Ločite implementacijo in konfiguracijo – konfiguracijo naj bo mogoče spreminjati brez ponovnega prevajanja in nameščanja mikrostoritve.<br>• Predvidite in uvedite eno uporabo različnih virov konfiguracije, npr. konfiguracijske datoteke, okoljske spremenljivke, konfiguracijski strežnik ... | | 4 |
| **Grafični vmesnik** | Razvijte grafični uporabniški vmesnik (GUI) za aplikacijo.<br><br>Minimalne zahteve:<br>• Uporabite ogrodje (npr. React, Angular, Vue.js) za izdelavo GUI ali razvijte mobilno aplikacijo.<br>• Implementirajte vsaj 2 podstrani.<br>• Zagotovite, da sprednji del komunicira z mikrostoritvami prek REST API-jev. | ✓ | 4 |
| **Vmesna predstavitev** | | | 10 |
| **Oddaja projekta** | | ✓ | 10 |
| **SKUPAJ** | | | **100** |

Poleg zahtev iz Tabele 1 lahko v svojo rešitev vključite tudi koncepte iz zahtev za dodatne točke (Tabela 2) in si tako zvišate oceno vaj. Te točke se ne štejejo v kvoto za opravljene vaje, najvišja možna končna ocena pri vajah pa ostaja 100 točk (100 %).

### Tabela 2: Seznam zahtev za dodatne točke

| Postavka | Opis in minimalne zahteve | Obvezno | Točke |
|----------|---------------------------|---------|-------|
| **Terraform** | Uporabite Terraform za avtomatizacijo namestitve infrastrukture v oblak.<br><br>Minimalne zahteve:<br>• Ustvarite Terraform konfiguracijske datoteke za definiranje potrebnih virov (npr. virtualni stroji, omrežja, baze podatkov).<br>• Uporabite module za ponovno uporabo konfiguracij.<br>• Implementirajte Terraform »plan« in »apply« za izpeljavo sprememb infrastrukture. | | 3 |
| **API Gateway** | Implementirajte API Gateway za centralizirano upravljanje dostopa do mikrostoritev.<br><br>Minimalne zahteve:<br>• Uporabite API Gateway (npr. Kong, AWS API Gateway, Istio) za usmerjanje API klicev.<br>• Ustrezno nastavite potrditev pristnosti (ang. authentication) in avtorizacijo (ang. authorization) preko API Gateway.<br>• Implementirajte enotno točko dostopa za različne API-je.<br>• Prikažite delovanje API Gatewa z večimi mikrostoritvami. | | 4 |
| **Ingress Controller** | Ustvari Ingress Controller za upravljanje dostopa do storitev v Kubernetes.<br><br>Minimalne zahteve:<br>• Namestite Ingress Controller (npr. NGINX, Traefik) v svoje Kubernetes okolje.<br>• Nastavite Ingress pravila za usmerjanje prometa do ustreznih storitev.<br>• Implementirajte TLS/SSL za varno komunikacijo.<br>• Preverite delovanje Ingress Controllerja z dostopom do storitev preko URL-jev. | | 4 |
| **IAM, OAuth2, OIDC** | Uporabite upravljanje identitete in dostopa (IAM) sistem za upravljanje identitet in dostopa.<br><br>Minimalne zahteve:<br>• Implementirajte IAM rešitev (npr. AWS IAM, Azure AD, Keycloak) za upravljanje uporabniških dostopov.<br>• Uporabite OAuth2 za avtorizacijo dostopa do API-jev.<br>• Implementirajte OpenID Connect (OIDC) za avtorizacijo in pridobivanje informacij o uporabnikih.<br>• Preverite delovanje s prijavo uporabnika in dodelitvijo pravic dostopa do aplikacije. | | 4 |
| **SKUPAJ** | | | **15** |

## Opombe

Ker je glavna tema tega predmeta razvoj spletnih aplikacij, optimiziranih za izvajanje v oblaku, si prizadevajte zasnovati svoje aplikacije tako, da kar najbolje odražajo realne zahteve modernih aplikacij. Pri zasnovi takšnih aplikacij se lahko pojavijo težave, katerih rešitve pa ne spadajo v okviru samega predmeta. Da bi vaše aplikacije bile zanimive, hkrati pa ne bi porabili preveč časa za implementacijo domensko-specifičnih težav, lahko nekatere funkcionalnosti v vaših mikrostoritvah nadomestite z t. i. "mock" implementacijo. Na primer, če bi bilo smiselno vključiti mikrostoritev za analizo zgodovinskih lokacijskih podatkov, jasno določite vmesnike spletnih storitev za to mikrostoritev in jo povežite z ostalimi mikrostoritvami v aplikaciji. Implementacijo analize pa lahko poenostavite do te mere, da bo še vedno očiten smisel in namen te mikrostoritve.

