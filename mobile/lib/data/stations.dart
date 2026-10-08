import '../models/station.dart';

/// Curated station list. Keep in sync with `src/lib/stationlist.ts`.
const List<Station> stations = [
  Station(
    id: 'NTS',
    name: 'NTS 1',
    hashtag: 'nts1',
    url: 'https://stream-relay-geo.ntslive.net/stream',
    description: 'NTS provides curious minds with a home for music discovery. Built by music lovers, for music lovers.',
  ),
  Station(
    id: 'NTS2',
    name: 'NTS 2',
    hashtag: 'nts2',
    url: 'https://stream-relay-geo.ntslive.net/stream2',
    description: 'NTS provides curious minds with a home for music discovery. Built by music lovers, for music lovers.',
  ),
  Station(
    id: 'gds.fm',
    name: 'GDS.fm',
    hashtag: 'gds',
    url: 'https://gdsfm.out.airtime.pro/gdsfm_a',
    link: 'https://gds.fm/',
    description: 'Zürichs Radio gegen den Strom.',
  ),
  Station(
    id: 'wefunkradio',
    name: 'WEFUNK',
    hashtag: 'wefunk',
    url: 'http://s-09.wefunkradio.com:81/wefunk64.mp3',
    link: 'http://www.wefunkradio.com/',
    description: 'WEFUNK is a Hip Hop, Funk & Soul mix show broadcasting from Montreal. Tune in and enjoy underground hip hop, classic funk and rare grooves.',
  ),
  Station(
    id: 'dublab',
    name: 'dublab',
    hashtag: 'dublab',
    url: 'https://dublab.out.airtime.pro/dublab_a',
    link: 'https://www.dublab.com/',
    description: 'dublab is a platform for discovery and the cultivation of next-wave music, arts and culture.',
  ),
  Station(
    id: 'kexp',
    name: 'KEXP',
    hashtag: 'kexp',
    url: 'https://kexp-mp3-128.streamguys1.com/kexp128.mp3',
    link: 'https://www.kexp.org/donate/',
    description: 'KEXP is a nonprofit arts organization serving music lovers through in-person, broadcast and online programming.',
  ),
  Station(
    id: 'worldwidefm',
    name: 'Worldwide FM',
    hashtag: 'worldwide',
    url: 'https://worldwidefm.out.airtime.pro/worldwidefm_b',
    link: 'https://worldwidefm.net/',
    description: 'An award winning radio station with a global audience.',
  ),
  Station(
    id: 'seoulcommunityradio',
    name: 'Seoul Community Radio',
    hashtag: 'scr',
    url: 'http://188.166.198.223/radio/8000/radio.mp3',
    link: 'https://www.seoulcommunityradio.com/',
    description:
        'SCR Live shows are broadcasted regularly Wed-Sun from 7PM KST.',
  ),
  Station(
    id: 'rinse',
    name: 'Rinse FM',
    hashtag: 'rinse',
    url: 'https://streamer-uk.rinse.fm:8443/stream',
    link: 'https://www.rinse.fm/',
    description: 'Rinse is at the centre of a vast musical community. As genres, artists and scenes evolve and fragment, so Rinse remains locked to the pulse of the underground.',
  ),
  Station(
    id: 'rw',
    name: 'Refuge Worldwide',
    hashtag: 'rw',
    url: 'https://streaming.radio.co/s3699c5e49/listen',
    description: 'Refuge Worldwide is a community radio station and fundraising platform based in Berlin.',
  ),
  Station(
    id: 'byte',
    name: 'Byte FM',
    hashtag: 'bytefm',
    url: 'https://uplink.byte.fm/bytefm-main/mp3-128/?ar-distributor=ffa0',
    description: 'ByteFM ist moderiertes Musik- und Kultur-Radio aus Hamburg',
  ),
  Station(
    id: 'rbv',
    name: 'Radio Buena Vida',
    hashtag: 'rbv',
    url: 'https://s4.radio.co/s69b281ac0/listen',
    link: 'https://buenavida.co.uk/get-involved/',
    description:
        'Radio Buena Vida first went on air in October 2020, live from Glasgow',
  ),
];
