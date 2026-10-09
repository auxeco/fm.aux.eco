import '../models/station.dart';

/// A titled group of extra stations in Settings.
class StationGroup {
  const StationGroup(this.title, this.stations);
  final String title;
  final List<Station> stations;
}

/// Extra stations users can add to their list in Settings, by group. Every
/// URL is checked by tool/check_stations.dart in CI (Station streams
/// workflow).
const List<StationGroup> stationCatalog = [
  StationGroup('MORE STATIONS', moreStations),
  StationGroup('NTS INFINITE MIXTAPES', ntsMixtapes),
];

const List<Station> moreStations = [
  // Independent and community radio, like the AUX FM selection.
  Station(
    id: 'cashmere',
    name: 'Cashmere Radio',
    url: 'https://cashmereradio.out.airtime.pro/cashmereradio_b',
    description: 'Not-for-profit experimental community radio from Berlin.',
  ),
  Station(
    id: 'kiosk',
    name: 'Kiosk Radio',
    url: 'https://kioskradiobxl.out.airtime.pro/kioskradiobxl_a',
    description: 'Community radio broadcasting from a kiosk in Brussels.',
  ),
  Station(
    id: 'radio80k',
    name: 'Radio 80000',
    url: 'https://radio80k.out.airtime.pro/radio80k_a',
    description: 'Independent community radio from Munich.',
  ),
  Station(
    id: 'lyl',
    name: 'LYL Radio',
    url: 'https://icecast.lyl.live/live',
    description:
        'Independent radio with studios in Lyon, Paris, Brussels and '
        'Marseille.',
  ),
  Station(
    id: 'noods',
    name: 'Noods Radio',
    url: 'https://noods-radio.radiocult.fm/stream',
    description: 'Independent community radio from Bristol.',
  ),
  Station(
    id: 'raheem',
    name: 'Radio Raheem',
    url: 'https://radioraheem.out.airtime.pro/radioraheem_a',
    description: 'Independent radio from Milan.',
  ),
  Station(
    id: 'operator',
    name: 'Operator Radio',
    url: 'https://origin.streamnerd.nl/operator/operator/icecast.audio',
    description: 'Independent radio from Rotterdam.',
  ),
  Station(
    id: 'foundation',
    name: 'Foundation FM',
    url: 'https://streamer.radio.co/s0628bdd53/listen',
    description: 'Independent online radio from London.',
  ),
  Station(
    id: 'netil',
    name: 'Netil Radio',
    url: 'https://netilradio.out.airtime.pro/netilradio_a',
    description: 'Community radio from Hackney, London.',
  ),
  Station(
    id: 'soho',
    name: 'Soho Radio',
    url: 'https://sohoradiomusic.doughunt.co.uk:8010/128mp3',
    description: 'Independent radio from Soho, London.',
  ),
  Station(
    id: 'kapital',
    name: 'Radio Kapitał',
    url: 'https://radiokapitalpl.out.airtime.pro/radiokapitalpl_a',
    description: 'Independent community radio from Warsaw.',
  ),
  Station(
    id: 'lahmacun',
    name: 'Lahmacun Radio',
    url: 'https://streaming.lahmacun.hu/listen/lahmacun_radio/radio.mp3',
    description: 'Community radio from Budapest.',
  ),
  Station(
    id: 'relativa',
    name: 'Radio Relativa',
    url: 'https://streamer.radio.co/sd6131729c/listen',
    description: 'Independent radio from Madrid.',
  ),
  Station(
    id: 'oroko',
    name: 'Oroko Radio',
    url: 'https://oroko-radio.radiocult.fm/stream',
    description: 'Independent radio from Accra, Ghana.',
  ),
  Station(
    id: 'alhara',
    name: 'Radio Alhara',
    url: 'https://n10.radiojar.com/78cxy6wkxtzuv',
    description: 'Community radio started in Bethlehem, Palestine.',
  ),
  Station(
    id: 'rinse-france',
    name: 'Rinse France',
    url: 'https://radio10.pro-fhi.net/radio/9041/stream',
    description: 'The Paris outpost of Rinse FM.',
  ),
  Station(
    id: 'mellotron',
    name: 'Le Mellotron',
    url: 'https://listen.radioking.com/radio/477719/stream/534044',
    description: 'Music webradio from Paris.',
  ),
  Station(
    id: 'campus-paris',
    name: 'Radio Campus Paris',
    url: 'https://www.radiocampusparis.org/stream/',
    description: 'Student and associative radio from Paris.',
  ),
  Station(
    id: 'dublab-de',
    name: 'dublab DE',
    url: 'https://dublabde.out.airtime.pro/dublabde_a',
    description: 'The German branch of the dublab collective.',
  ),
  Station(
    id: 'montez',
    name: 'Montez Press Radio',
    url: 'https://stream.montezpress.com/icecast/music',
    description: 'Experimental art and music radio from New York.',
  ),
  Station(
    id: 'datafruits',
    name: 'Datafruits',
    url: 'https://streampusher-relay.club/datafruits.mp3',
    description: 'Community-run internet radio.',
  ),
  Station(
    id: 'intergalactic',
    name: 'Intergalactic FM',
    url: 'https://radio.intergalactic.fm/1',
    description: 'Electronic music from The Hague.',
  ),
  Station(
    id: 'techno-underground',
    name: 'Techno Underground',
    url: 'https://fluxfm.streamabc.net/flx-technounderground-mp3-128-7228171',
    description: 'Non-stop techno from FluxFM, Berlin.',
  ),

  // Curated music radio and freeform stations.
  Station(
    id: 'fip',
    name: 'FIP',
    url: 'https://icecast.radiofrance.fr/fip-midfi.mp3?id=radiofrance',
    description: 'Eclectic, ad-free music radio from Radio France, Paris.',
  ),
  Station(
    id: 'fip-groove',
    name: 'FIP Groove',
    url: 'https://icecast.radiofrance.fr/fipgroove-midfi.mp3?id=radiofrance',
    description: "FIP's soul, funk and hip hop channel.",
  ),
  Station(
    id: 'fip-jazz',
    name: 'FIP Jazz',
    url: 'https://icecast.radiofrance.fr/fipjazz-midfi.mp3?id=radiofrance',
    description: "FIP's jazz channel.",
  ),
  Station(
    id: 'fip-electro',
    name: 'FIP Electro',
    url: 'https://icecast.radiofrance.fr/fipelectro-midfi.mp3?id=radiofrance',
    description: "FIP's electronic music channel.",
  ),
  Station(
    id: 'fip-monde',
    name: 'FIP Monde',
    url: 'https://icecast.radiofrance.fr/fipworld-midfi.mp3?id=radiofrance',
    description: "FIP's world music channel.",
  ),
  Station(
    id: 'nova',
    name: 'Radio Nova',
    url: 'https://novazz.ice.infomaniak.ch/novazz-128.mp3',
    description: 'Independent Paris station, open to every genre since 1981.',
  ),
  Station(
    id: 'meuh',
    name: 'Radio Meuh',
    url: 'https://radiomeuh.ice.infomaniak.ch/radiomeuh-128.mp3',
    description: 'Eclectic music radio from the French Alps.',
  ),
  Station(
    id: 'wfmu',
    name: 'WFMU',
    url: 'https://stream0.wfmu.org/freeform-128k.mp3',
    description: 'Freeform, listener-supported radio from Jersey City.',
  ),
  Station(
    id: 'kalx',
    name: 'KALX',
    url: 'https://stream.kalx.berkeley.edu:8443/kalx-128.mp3',
    description: 'Student-run college radio from UC Berkeley.',
  ),
  Station(
    id: 'kcrw-e24',
    name: 'KCRW Eclectic24',
    url: 'https://streams.kcrw.com/e24_mp3',
    description: 'Round-the-clock music stream from KCRW, Santa Monica.',
  ),
  Station(
    id: 'fm4',
    name: 'FM4',
    url: 'https://orf-live.ors-shoutcast.at/fm4-q2a',
    description: "Alternative station of Austria's public broadcaster ORF.",
  ),
  Station(
    id: 'couleur3',
    name: 'Couleur 3',
    url: 'https://stream.srg-ssr.ch/m/couleur3/mp3_128',
    description: 'Alternative music station of Swiss public radio RTS.',
  ),
  Station(
    id: 'radio-paradise',
    name: 'Radio Paradise',
    url: 'https://stream.radioparadise.com/mp3-192',
    description: 'Listener-supported, human-curated eclectic mix.',
  ),
  Station(
    id: 'soma-groove-salad',
    name: 'SomaFM Groove Salad',
    url: 'https://ice2.somafm.com/groovesalad-128-mp3',
    description: 'Ambient and downtempo from listener-supported SomaFM.',
  ),
  Station(
    id: 'soma-drone-zone',
    name: 'SomaFM Drone Zone',
    url: 'https://ice2.somafm.com/dronezone-128-mp3',
    description: 'Atmospheric ambient textures from SomaFM.',
  ),
];

/// NTS's themed 24/7 streams, with NTS's own descriptions.
const List<Station> ntsMixtapes = [
  Station(
    id: 'nts-poolside',
    name: 'NTS Poolside',
    url: 'https://stream-mixtape-geo.ntslive.net/mixtape4',
    description: 'Balearic, boogie, and sophisti-pop for poolsides, beaches and car stereos.',
  ),
  Station(
    id: 'nts-slow-focus',
    name: 'NTS Slow Focus',
    url: 'https://stream-mixtape-geo.ntslive.net/mixtape',
    description: 'Meditative, relaxing and beatless: ambient, drone and ragas.',
  ),
  Station(
    id: 'nts-low-key',
    name: 'NTS Low Key',
    url: 'https://stream-mixtape-geo.ntslive.net/mixtape2',
    description: "Keeping it simple with lo-fi hip-hop and smooth R'n'B.",
  ),
  Station(
    id: 'nts-memory-lane',
    name: 'NTS Memory Lane',
    url: 'https://stream-mixtape-geo.ntslive.net/mixtape6',
    description: 'Turn on, tune in, drop out.',
  ),
  Station(
    id: 'nts-4-to-the-floor',
    name: 'NTS 4 To The Floor',
    url: 'https://stream-mixtape-geo.ntslive.net/mixtape5',
    description: 'House and techno from past to present.',
  ),
  Station(
    id: 'nts-island-time',
    name: 'NTS Island Time',
    url: 'https://stream-mixtape-geo.ntslive.net/mixtape21',
    description: 'Easy skanking - reggae, dub, and plenty more.',
  ),
  Station(
    id: 'nts-the-tube',
    name: 'NTS The Tube',
    url: 'https://stream-mixtape-geo.ntslive.net/mixtape26',
    description: 'Oddball post-punk, industrial provocation, and minimal wave.',
  ),
  Station(
    id: 'nts-sheet-music',
    name: 'NTS Sheet Music',
    url: 'https://stream-mixtape-geo.ntslive.net/mixtape35',
    description: 'The best of classical and contemporary composition.',
  ),
  Station(
    id: 'nts-feelings',
    name: 'NTS Feelings',
    url: 'https://stream-mixtape-geo.ntslive.net/mixtape27',
    description: 'Sweet soul, gospel, boogie, and beyond.',
  ),
  Station(
    id: 'nts-expansions',
    name: 'NTS Expansions',
    url: 'https://stream-mixtape-geo.ntslive.net/mixtape3',
    description: 'Jazz and its many mind-expanding variations.',
  ),
  Station(
    id: 'nts-rap-house',
    name: 'NTS Rap House',
    url: 'https://stream-mixtape-geo.ntslive.net/mixtape22',
    description: '808s and champagne.',
  ),
  Station(
    id: 'nts-labyrinth',
    name: 'NTS Labyrinth',
    url: 'https://stream-mixtape-geo.ntslive.net/mixtape31',
    description: 'Enter the void.',
  ),
  Station(
    id: 'nts-sweat',
    name: 'NTS Sweat',
    url: 'https://stream-mixtape-geo.ntslive.net/mixtape24',
    description: 'A new wave of international party music.',
  ),
  Station(
    id: 'nts-otaku',
    name: 'NTS Otaku',
    url: 'https://stream-mixtape-geo.ntslive.net/mixtape36',
    description: 'Video game and anime soundtracks, for fanboys and fangirls.',
  ),
  Station(
    id: 'nts-the-pit',
    name: 'NTS The Pit',
    url: 'https://stream-mixtape-geo.ntslive.net/mixtape34',
    description: 'Behold the songs of the ancient metal bards.',
  ),
  Station(
    id: 'nts-field-recordings',
    name: 'NTS Field Recordings',
    url: 'https://stream-mixtape-geo.ntslive.net/mixtape23',
    description: 'Natural ambience from NTS listeners around the world.',
  ),
];
