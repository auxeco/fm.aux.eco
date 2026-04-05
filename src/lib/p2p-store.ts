import { writable } from 'svelte/store';
import {
	getFollowedUsers,
	subscribeToUser,
	publishNowPlaying,
	type FollowedUser
} from './nostr';
import type { Station } from './stationlist';
import { stations } from './stationlist';
import { currentStation, isPlaying } from './store';

export type FriendStatus = FollowedUser & {
	stationId?: string;
	stationName?: string;
	lastSeen?: number;
};

export const showP2P = writable(false);
export const friends = writable<FriendStatus[]>([]);
export const p2pActive = writable(false);
export const tuningSource = writable<string | null>(null);

const subscriptions: Map<string, { close: () => void }> = new Map();

export function initP2P(): void {
	const follows = getFollowedUsers();
	friends.set(follows.map((f) => ({ ...f })));

	for (const user of follows) {
		subscribeToFriend(user);
	}

	p2pActive.set(true);
}

export function subscribeToFriend(user: FollowedUser): void {
	if (subscriptions.has(user.hex)) return;

	const sub = subscribeToUser(user.hex, (stationId, stationName) => {
		friends.update((list) =>
			list.map((f) =>
				f.hex === user.hex
					? { ...f, stationId, stationName, lastSeen: Date.now() }
					: f
			)
		);
	});

	subscriptions.set(user.hex, sub);
}

export function unsubscribeFromFriend(hex: string): void {
	const sub = subscriptions.get(hex);
	if (sub) {
		sub.close();
		subscriptions.delete(hex);
	}
}

export function tuneToFriend(friendStatus: FriendStatus): void {
	if (!friendStatus.stationId) return;

	const station = stations.find((s) => s.id === friendStatus.stationId);
	if (station) {
		tuningSource.set(friendStatus.name || friendStatus.npub.slice(0, 12));
		currentStation.set(station);
	}
}

export function broadcastStation(station: Station): void {
	let active = false;
	p2pActive.subscribe((v) => (active = v))();
	if (!active) return;

	let playing = false;
	isPlaying.subscribe((v) => (playing = v))();
	if (!playing) return;

	publishNowPlaying(station.id, station.name);
}

export function teardownP2P(): void {
	for (const [hex, sub] of subscriptions) {
		sub.close();
		subscriptions.delete(hex);
	}
	p2pActive.set(false);
}
