[TOC]: #

# SIP User Agent

- [SIP](#sip)
- [Opsætning](#opsætning)
  - [UserAgent](#useragent)
  - [UserAgentDelegate](#useragentdelegate)
  - [UserAgentDelegate - Eksempel](#useragentdelegate---eksempel)
- [Session](#session)
- [Flows](#flows)
  - [Indregistrering](#indregistrering)
  - [Voice opkald](#voice-opkald)
  - [Viderestilling](#viderestilling)


Når man skal facilitere et VOIP __(Voice Over IP)__ opkald forgår det
typisk via SIP __(Session Initiation Protocol)__ som er en
signaleringsprotokol, også kendt som application-layer control. SIP
bruger flere transport protokoller som TCP, UDP, SCTCP, RSVP m.fl.

En SIP User Agent har til opgave at oprette, modificere og afslutte
sessioner. Disse sessioner inkluderer IP Telefoni, multimedie
distribution og multimedie konferencer.

En user agent vil typisk forbinde til en dedikeret server, der kan
håndtere transcoding af mediet. Men da standarden også tillader to
klienter at snakke sammen, dvs. at de både agere klient og server, vil
løsningen fokusere på dette scenarie for at simplificere projektet.

Teoretisk tillader dette også langt højere kvalitet, da en typisk
telefonsamtale har 64 kbit til rådighed _(PCMA/G.711)_.

Når de to klienter vil oprette forbindelse mellem hinanden, kommunikere
de hvilke funktionaliteter de understøtter (voice, video). Samt codecs
og bitrates.

For at starte et opkald vil den ene sende en __Invite__ besked til den
anden, med disse informationer. Når den modsatte part acceptere, skal
klienterne blive enige om hvordan de kommunikere.

Dette foregår via princippet at højeste fællesnævner bestemmer.

## SIP

SIP er en plain text protokol. I eksemplet herunder, er vist en
__REGISTER__ pakke. Her er også implementeret authorization og
kommunikationen er over WebSocket med TLS.

```http request
REGISTER sip:remotehost SIP/2.0
Via: SIP/2.0/WSS 3af6pj3a8fk4.invalid;branch=z9hG4bK4997110
Max-Forwards: 69
To: <sip:bob@192.168.20.20>
From: <sip:alice@192.168.20.19>;tag=itp46o81e5
Call-ID: Alice
CSeq: 2 REGISTER
Authorization: Digest algorithm=MD5, username="", realm="", nonce="", uri="sip:hostname", response="", opaque="", qop=auth, cnonce="", nc=00000001
Contact: <sip:alice@192.168.20.19;transport=ws>;+sip.ice;reg-id=1;+sip.instance="<urn:uuid:5d60af5f-d4dd-4336-876c-a8dc92415a74>";expires=600
Expires: 600
Allow: INVITE,ACK,CANCEL,BYE,UPDATE,MESSAGE,OPTIONS,REFER,INFO,NOTIFY
Supported: path,gruu,outbound
User-Agent: sip-ua
Content-Length: 0
```

Meget af den viden man har fra HTTP 1.1 kan man genbruge i SIP land.
__Allow__ kan f.eks. sammenlignes med med CORS headeren
__Access-Control-Allow-Methods__.

Det specielle ved SIP er at alle beskeder indeholder en __CSeq__ header
med en metode og et sekvens id angivet i `integer`. Protokollen tillader
nemlig _Out of Order_ pakker. En user agent og tilsvarende server,
__SKAL__ understøtte dette, da man ellers har en ødelagt implementation.
Vigtigst er at man inkrementere id´et med n+1. Man starter typisk fra
__1__, men dette er ikke så vigtigt.

## Opsætning

En bruger af dette user agent bibliotek vil blive eksponeret overfor en
`UserAgent` klasse, der under alle omstændigheder skal anvendes som
`Singleton`. Grunden til dette er, at det for det første ikke giver
mening at have flere _"telefoner"_ i et browser vindue. Men også fordi i
tilfælde af flere opkald, vil det blive alt for uoverskueligt at
programmere routingen af opkald.

I disse tilfælde skal man bruge en PBX server, hvor man konfigurere
routing tabeller. Men dette er ude af scopet for dette projekt. Dog vil
jeg henvise til [Asterisk](https://www.asterisk.org/) skulle det blive
aktuelt.

### UserAgent

```mermaid
%%{init: {'theme':'base', "securityLevel": "loose"}}%%

classDiagram
    UserAgent <-- UserAgentOptions
    class UserAgent{
        -Array~Session~ sessions
        -boolean connected
        -boolean isMuted
        -boolean isHeld
        -boolean inCall
        -MediaStream localMediaStream
        -MediaStream remoteMediaStream
        
        +constructor(options: UserAgentOptions)

        +connect()
        +disconnect()
        +isConnected()
        +answer()
        +hangup()
        +hold()
        +unhold()
        +isHeld()
        +mute()
        +unMute()
        +isMuted()
        +sendDTMF(tone: string)
        +message(message: string, destination: string)
        
        +localMediaStream()
        +remoteMediaStream()
    }
    class UserAgentOptions{
        <<Interface>>
        url: string
        username: string
        password: string
        delegate: UserAgentDelegate
    }
    UserAgentOptions <-- UserAgentDelegate
    class UserAgentDelegate{
        <<Interface>>
    }
    UserAgent <-- Session
    class Session{
        <<Abstract>>
        -Array~Message~ messages
    }
    Session <-- Message
    class Message{
        <<Abstract>>
        -number sequence
    }
```

En factory funktion ville her være fordelagtigt til instantiering af
`UserAgent`. Denne kan så bindes til en dependency container.

#### UserAgentDelegate

Et interface til at binde callbacks til UserAgent events. Disse
callbacks er metoderne til at, binde ens brugerflade til klienten - og
derved kan gøre brugerfladen _reaktionær_.

#### UserAgentDelegate - Eksempel

```typescript
interface Identity {
  // Call ID header or parsed from 'From'|'To'
  // depending on if our side is receiver or sender.
  friendlyName(): string;
  // raw header
  raw(): string;
}

interface Invite {
  sender: Identity;
  withoutSdp: boolean;
}

interface UserAgentDelegate {
  onMessage(message: string, sender: Identity): void;
  // return true to accept or false to decline
  onInvite(invite: Invite): Promise<boolean>;
  // called when someone refers a call to us.
  onRefer(referer: Identity, referral: Identity): Promise<boolean>;
  // Called when user is registered to received calls.
  onRegistered(): void;
  // Called when user is no longer registered to received calls.
  onUnregistered(): void;
  // Called when user is connected to server.
  onServerConnect();
  // Called when user is no longer connected.
  // @param error - An Error if server caused the disconnect. Otherwise undefined.
  onServerDisconnect(error?: Error): void;
}

const delegate: UserAgentDelegate = {
  onMessage(message: string, sender: Identity) {
    console.log(`Received message from: ${sender.friendlyName()}`, message)
  },
  onInvite(invite: Invite) {
    return new Promise<boolean>(resolve => {
      console.log(`Received invite from ${invite.sender.friendlyName()}`);
      resolve(true); // accept
    })
  },
  onRefer(referer: Identity, referral: Identity) {
    return new Promise<boolean>(resolve => {
      console.log(`Received refer from ${referer.friendlyName()} to ${referral.friendlyName()}`);
      resolve(true); // accept
    })
  },
  onRegistered() {
    console.log('registered');
  },
  onUnregistered() {
    console.log('unregistered');
  },
  onServerConnect() {
    console.log('connected');
  },
  onServerDisconnect(error?:Error) {
    if (error) {
      console.error(error);
    }
    console.log('disconnected');
  }
}
```

## Session

En UserAgent kan have flere opkald igang. Derfor er sessions gemt på
`UserAgent` som et array.

I tilfælde af flere opkald, vil det aktive opkald være dét som brugeren
er forbundet til. De andre vil være på `Hold`.

```mermaid
%%{init: {'theme':'base', "securityLevel": "loose"}}%%

classDiagram
    class Identity{
        -String uri
        
        +friendlyName()
        +raw()
    }
    Session o-- Identity
    class Session {
        <<Abstract>>
        +Array~String~ data
        -String contact
        +remoteIdentity() Identity
        +localIdentity() Identity
    }
```

## Flows

### Indregistrering

Biblioteket bruger en pinkode som kodeord, når _Alice_ vil snakke med
_Bob_, uden en server i mellem. Aftaler hun at bruge koden __1234__ som
`password`.

En SIP `REGISTER` __SKAL__ altid først sendes uden password. Når den
bliver afvist med status __401__, så aftaler klienterne en `nonce` - som
bliver inkluderet i næste `REGISTER` forsøg. Inklusiv kodeordet.

`nonce` bliver genereret af _Bob_ og sendt til _Alice_. Dette er en
`Password-Challenge` Når _Alice_ så indregistrere igen, så ved _Bob_ at,
det er samme _Alice_ han snakker med - da kun hun vil kende til den
værdi.

Den underlæggende implementation er håndteret af biblioteket. Som bruger
vil dette være gemt under abstraktionen, men det vil dog være en fordel
at have en forståelse af hvordan dette fungerer. Specielt i debug
tilfælde.

```mermaid
%%{init: {'theme':'base', "securityLevel": "loose"}}%%

 sequenceDiagram
    Note over Alice,Bob: without Authorization header
    Alice->>Bob: REGISTER
    Bob-->>Alice: 401
    Note over Alice,Bob: with Authorization header
    Alice->>Bob: REGISTER
    Bob-->>Alice: 200
```

### Voice opkald

```mermaid
%%{init: {'theme':'base', "securityLevel": "loose"}}%%

sequenceDiagram
    participant A as Alice
    participant B as Bob
    A->>+B: INVITE
    Note left of A: CSeq: 2 Invite<br/>Username: 'Alice'<br/>Nonce Value: '***'<br/>Authentication URI: 'sip:user@192.168.10.20'
    B-->>-A: 100 Trying
    Note right of B: CSeq: 2 Invite
    B-->>A: 183 Session Progress
    Note right of B: Authenticate against the Nonce challenge.<br/>Allocate UDP port for RTP traffic
    Note right of B: CSeq 2: Invite<br/>c: IN IP4 192.168.10.20<br/>a: rtpmap:0 PCMU/8000<br/>a: rtpmap:101 telephone-event/8000<br/>a: fmtp: 101 0-11<br/>a: ptime:20<br/>a: setup:active<br/>a: sendrecv
    Note left of A: Ringing
    B-->>A: 200 OK
    Note left of A: Answer
    A->>B: ACK
```

### Viderestilling

Når man viderestiller et opkald, er der 2 måder at gøre det på.

### Blind

Ved en blind omstilling, tjekker man ikke om modparten rent faktisk er klar til at modtage opkaldet.
Derimod så sender man bare opkaldet videre, og så bliver der lagt på.

### Attended

Ved en Attended omstilling, ringer man modparten op og venter på svar. Her kan man snakke sammen,
og forklare hvorfor man omstiller - uden at personen der skal omstilles kan gøre med. Derved slipper en eventuel kunde for,
at beskrive sit problem igen.

```mermaid
%%{init: {'theme':'base', "securityLevel": "loose"}}%%

graph TD
    Transfer --> Type{Type}
    Type     --> Blind
    Type     --> Attended
    Blind    --> Refer
    Refer    --> |"Alice hangs up"|Hangup
    Attended --> |"sip:bob@192.168.20.20"|Invite
    Invite   --> |"Bob answers"|Answer
    Answer   --> Refer
```
