import { generateSecretKey, getPublicKey, finalizeEvent } from 'nostr-tools/pure';
import { SimplePool } from 'nostr-tools/pool';
import { npubEncode, decode } from 'nostr-tools/nip19';

function bytesToHex(bytes: Uint8Array): string {
	return Array.from(bytes)
		.map((b) => b.toString(16).padStart(2, '0'))
		.join('');
}

function hexToBytes(hex: string): Uint8Array {
	const bytes = new Uint8Array(hex.length / 2);
	for (let i = 0; i < hex.length; i += 2) {
		bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
	}
	return bytes;
}

const RELAYS = [
	'wss://relay.damus.io',
	'wss://nos.lol',
	'wss://relay.nostr.band'
];

const EVENT_KIND = 30078;
const D_TAG = 'auxfm:nowplaying';
const SK_KEY = 'auxfm:nostr:sk';
const FOLLOWS_KEY = 'auxfm:nostr:follows';

let pool: SimplePool | null = null;
let secretKey: Uint8Array | null = null;

function getPool(): SimplePool {
	if (!pool) {
		pool = new SimplePool();
	}
	return pool;
}

function getOrCreateSecretKey(): Uint8Array {
	if (secretKey) return secretKey;

	const stored = localStorage.getItem(SK_KEY);
	if (stored) {
		secretKey = hexToBytes(stored);
	} else {
		secretKey = generateSecretKey();
		localStorage.setItem(SK_KEY, bytesToHex(secretKey));
	}
	return secretKey;
}

export function getPublicKeyHex(): string {
	return getPublicKey(getOrCreateSecretKey());
}

export function getNpub(): string {
	return npubEncode(getPublicKeyHex());
}

export function npubToHex(npub: string): string | null {
	try {
		const { type, data } = decode(npub);
		if (type === 'npub') return data as string;
		return null;
	} catch {
		return null;
	}
}

export function getShareLink(): string {
	return `${window.location.origin}/#follow:${getNpub()}`;
}

export async function publishNowPlaying(stationId: string, stationName: string): Promise<void> {
	const sk = getOrCreateSecretKey();

	const event = finalizeEvent(
		{
			kind: EVENT_KIND,
			created_at: Math.floor(Date.now() / 1000),
			tags: [['d', D_TAG]],
			content: JSON.stringify({ stationId, stationName })
		},
		sk
	);

	const p = getPool();
	await Promise.allSettled(p.publish(RELAYS, event));
}

export function subscribeToUser(
	pubkeyHex: string,
	onUpdate: (stationId: string, stationName: string) => void
): { close: () => void } {
	const p = getPool();

	const sub = p.subscribeMany(
		RELAYS,
		{
			kinds: [EVENT_KIND],
			authors: [pubkeyHex],
			'#d': [D_TAG]
		},
		{
			onevent(event) {
				try {
					const data = JSON.parse(event.content);
					if (data.stationId && data.stationName) {
						onUpdate(data.stationId, data.stationName);
					}
				} catch {
					// ignore malformed events
				}
			}
		}
	);

	return { close: () => sub.close() };
}

export type FollowedUser = {
	npub: string;
	hex: string;
	name: string;
};

export function getFollowedUsers(): FollowedUser[] {
	try {
		const stored = localStorage.getItem(FOLLOWS_KEY);
		return stored ? JSON.parse(stored) : [];
	} catch {
		return [];
	}
}

export function saveFollowedUsers(users: FollowedUser[]): void {
	localStorage.setItem(FOLLOWS_KEY, JSON.stringify(users));
}

export function addFollowedUser(npub: string, name: string): boolean {
	const hex = npubToHex(npub);
	if (!hex) return false;

	// don't follow yourself
	if (hex === getPublicKeyHex()) return false;

	const follows = getFollowedUsers();
	if (follows.some((f) => f.hex === hex)) return false;

	follows.push({ npub, hex, name });
	saveFollowedUsers(follows);
	return true;
}

export function removeFollowedUser(hex: string): void {
	const follows = getFollowedUsers().filter((f) => f.hex !== hex);
	saveFollowedUsers(follows);
}
