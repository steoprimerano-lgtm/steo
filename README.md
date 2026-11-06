# Centralina Luci – app per iPad

App personale per comandare le luci (PAR, teste mobili, fumo) dall'iPad.
L'app manda il segnale Art‑Net **direttamente dall'iPad** al nodo DMX, quindi non servono né il Raspberry né il portatile.

Questo repository contiene:
- `web/index.html`: l'app (interfaccia, giochi, preset, libreria fari)
- `App/`: il "guscio" per iPad che manda l'Art‑Net al nodo
- `.github/workflows/build-ipa.yml`: GitHub compila da solo il file `.ipa` a ogni modifica
- `centralina/`: la versione per Raspberry o portatile (facoltativa)

**Ultima versione dell'app:** [CentralinaLuci.ipa](https://github.com/steoprimerano-lgtm/steo/releases/latest/download/CentralinaLuci.ipa)

---

## 1. Installa SideStore sull'iPad (solo la prima volta)

SideStore installa sull'iPad app che non vengono dall'App Store, firmandole con il tuo Apple ID gratuito.
La prima installazione va fatta una volta sola con un computer (va bene il portatile Windows). Dopo, l'iPad fa tutto da solo.

Ti serve: l'iPad con un **codice di sblocco** impostato, il portatile Windows (64 bit), un cavo USB, e iPad e portatile sullo stesso Wi‑Fi.

1. **Sull'iPad:** installa dall'App Store **LocalDevVPN**, aprila e tocca **Connect**, poi **Consenti** e il codice di sblocco. Serve a SideStore per installare e rinnovare le app senza computer.
2. **Sul portatile:** installa **iTunes** dal sito Apple (versione 64 bit) e il programma **iloader**, scaricando `iloader-windows-x64.msi` da github.com/nab138/iloader/releases. Se Windows mostra l'avviso SmartScreen, tocca "Ulteriori informazioni → Esegui comunque".
3. Collega l'iPad al portatile con il cavo e apri iloader. Accedi con il tuo **Apple ID**, sull'iPad tocca **Autorizza** e inserisci il codice che compare. Quando il nome dell'iPad diventa blu, clicca **SideStore (Stable)** e aspetta "SideStore Installed!".
4. **Sull'iPad:** attiva la **Modalità sviluppatore** quando te la chiede (Impostazioni → Privacy e sicurezza → Modalità sviluppatore, poi riavvio e "Attiva").
5. Apri **SideStore** e consenti l'accesso alla rete locale e le notifiche.

Guida ufficiale con le immagini: **docs.sidestore.io**.

## 2. Installa l'app Luci

1. Sull'iPad apri in Safari il link **[CentralinaLuci.ipa](https://github.com/steoprimerano-lgtm/steo/releases/latest/download/CentralinaLuci.ipa)** e scaricalo. Va nella cartella Download dell'app File.
2. Apri **SideStore → My Apps → +** e scegli `CentralinaLuci.ipa` dai Download.
3. Attendi l'installazione: sulla Home compare l'icona **Luci**.
4. Alla prima apertura l'iPad chiede di **trovare dispositivi sulla rete locale**: rispondi **Consenti**. Senza questo permesso le luci non ricevono il segnale.

### Da sapere sull'Apple ID gratuito
- Le app installate con SideStore **scadono dopo 7 giorni**. Lascia LocalDevVPN connessa, così SideStore le rinnova da solo. In alternativa, una volta a settimana apri SideStore e in **My Apps** tocca il contatore dei giorni (o **Refresh All**).
- **Prima di un concerto, controlla in SideStore quanti giorni restano.** Se l'app scade non si apre più finché non la rinnovi, e per rinnovarla serve internet.
- Con un Apple ID gratuito puoi avere al massimo 3 app installate con SideStore, SideStore compreso.

## 3. Collega iPad e nodo Art‑Net

iPad e nodo devono essere sulla **stessa rete**: il nodo collegato con il cavo al router della centralina, l'iPad al Wi‑Fi dello stesso router.
Gli indirizzi devono essere della stessa "famiglia". Il modo più semplice:

- Nel router (pagina di configurazione, di solito `192.168.0.1` o `192.168.1.1`) imposta la rete locale (LAN) su **IP 2.0.0.1**, **subnet mask 255.0.0.0**, con DHCP attivo. Così l'iPad riceve da solo un indirizzo 2.x.x.x.
- In alternativa lascia il router com'è e cambia l'IP del nodo dalla sua configurazione, mettendone uno della rete del router (es. `192.168.1.50`).

Poi nell'app vai in **Setup → Rete Art‑Net** e scrivi **l'IP esatto del nodo**. Sull'iPad l'indirizzo "2.255.255.255" non funziona.

## 4. Durante lo spettacolo
- **Tieni l'app aperta e in primo piano.** Se esci dall'app o blocchi l'iPad, il segnale si ferma e la maggior parte dei nodi tiene l'ultima scena.
- **Lo schermo resta sempre acceso:** l'app ne impedisce lo spegnimento automatico.
- Per non uscire dall'app per sbaglio, puoi usare **Accesso Guidato** (Impostazioni → Accessibilità).

## Aggiornare l'app
Ogni volta che l'app viene modificata in questo repository, GitHub prepara da solo la nuova versione (scheda *Actions*, circa 5 minuti).
Riscarica il link `CentralinaLuci.ipa` e installalo di nuovo da SideStore: fari, preset e impostazioni restano.
