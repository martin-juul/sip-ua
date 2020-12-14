# SIP User Agent

Når man skal facilitere et VOIP __(Voice Over IP)__ opkald forgår det typisk via SIP __(Session Initiation Protocol)__
som er en signaleringsprotokol, også kendt som application-layer control. SIP bruger flere transport protokoller som TCP, UDP, SCTCP, RSVP m.fl.

En SIP User Agent har til opgave at oprette, modificere og afslutte sessioner. Disse sessioner inkluderer IP Telefoni,
multimedie distribution og multimedie konferencer.

En user agent vil typisk forbinde til en dedikeret server, der kan håndtere transcoding af mediet.
Men da standarden også tillader to klienter at snakke sammen, dvs. at de både agere klient og server,
vil løsningen fokusere på dette scenarie for at simplificere projektet.

Teoretisk tillader dette også langt højere kvalitet, da en typisk telefonsamtale har 64 kbit til rådighed _(PCMA/G.711)_.

Når de to klienter vil oprette forbindelse mellem hinanden, kommunikere de hvilke funktionaliteter de understøtter (voice, video).
Samt codecs og bitrates.

For at starte et opkald vil den ene sende en __Invite__ besked til den anden, med disse informationer.
Når den modsatte part acceptere, skal klienterne blive enige om hvordan de kommunikere.

Dette foregår via princippet at højeste fællesnævner bestemmer.

Denne klient er web browser kompatibel og signalere SIP over WebSocket protokollen.
