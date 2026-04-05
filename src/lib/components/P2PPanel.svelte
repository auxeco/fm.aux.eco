<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import {
		showP2P,
		friends,
		p2pActive,
		tuningSource,
		initP2P,
		subscribeToFriend,
		unsubscribeFromFriend,
		tuneToFriend,
		teardownP2P,
		type FriendStatus
	} from '$lib/p2p-store';
	import {
		getNpub,
		getShareLink,
		addFollowedUser,
		removeFollowedUser,
		npubToHex,
		getPublicKeyHex
	} from '$lib/nostr';
	import Overlay from './Overlay.svelte';

	let shareLink = $state('');
	let npub = $state('');
	let followInput = $state('');
	let nameInput = $state('');
	let showCopied = $state(false);
	let error = $state('');

	onMount(() => {
		npub = getNpub();
		shareLink = getShareLink();

		if (!$p2pActive) {
			initP2P();
		}

		// check URL for follow link
		const hash = window.location.hash.slice(1);
		if (hash.startsWith('follow:')) {
			const incomingNpub = hash.replace('follow:', '');
			followInput = incomingNpub;
			window.location.hash = '';
		}
	});

	onDestroy(() => {
		// keep subscriptions alive, don't teardown
	});

	function copyLink() {
		navigator.clipboard.writeText(shareLink);
		showCopied = true;
		setTimeout(() => (showCopied = false), 1500);
	}

	function handleFollow() {
		error = '';

		if (!followInput.trim()) {
			error = 'Paste a link or npub';
			return;
		}

		// extract npub from link or raw npub
		let targetNpub = followInput.trim();
		if (targetNpub.includes('#follow:')) {
			targetNpub = targetNpub.split('#follow:')[1];
		}

		if (!targetNpub.startsWith('npub1')) {
			error = 'Invalid link or npub';
			return;
		}

		const hex = npubToHex(targetNpub);
		if (!hex) {
			error = 'Invalid npub';
			return;
		}

		if (hex === getPublicKeyHex()) {
			error = "That's you";
			return;
		}

		const name = nameInput.trim() || targetNpub.slice(0, 12) + '...';
		const added = addFollowedUser(targetNpub, name);
		if (!added) {
			error = 'Already following';
			return;
		}

		const user = { npub: targetNpub, hex, name };
		friends.update((list) => [...list, user]);
		subscribeToFriend(user);

		followInput = '';
		nameInput = '';
	}

	function handleUnfollow(friend: FriendStatus) {
		removeFollowedUser(friend.hex);
		unsubscribeFromFriend(friend.hex);
		friends.update((list) => list.filter((f) => f.hex !== friend.hex));
	}

	function handleTune(friend: FriendStatus) {
		tuneToFriend(friend);
	}
</script>

{#if showCopied}
	<Overlay text="link copied to clipboard" handleOverlayClick={() => (showCopied = false)} />
{/if}

<div class="px-[var(--space-m)] py-[10px]">
	<!-- Your identity -->
	<div class="mb-4 border-b border-[var(--decorative-base)] pb-4">
		<p class="mb-2 text-[0.7rem] uppercase tracking-widest opacity-50">Your link</p>
		<div class="flex items-center gap-2">
			<code
				class="flex-1 overflow-hidden text-ellipsis whitespace-nowrap text-[0.75rem] opacity-70"
			>
				{npub.slice(0, 20)}...{npub.slice(-8)}
			</code>
			<button
				class="border border-[var(--decorative-base)] px-3 py-1 text-[0.75rem] uppercase text-[var(--text-base)] hover:text-[var(--essential-primary)]"
				onclick={copyLink}
			>
				Copy
			</button>
		</div>
	</div>

	<!-- Follow someone -->
	<div class="mb-4 border-b border-[var(--decorative-base)] pb-4">
		<p class="mb-2 text-[0.7rem] uppercase tracking-widest opacity-50">Follow someone</p>
		<input
			type="text"
			bind:value={nameInput}
			placeholder="Name (optional)"
			class="mb-2 w-full border border-[var(--decorative-base)] bg-[var(--background-base)] px-3 py-2 text-[0.8rem] text-[var(--text-base)]"
		/>
		<div class="flex gap-2">
			<input
				type="text"
				bind:value={followInput}
				placeholder="Paste link or npub..."
				class="flex-1 border border-[var(--decorative-base)] bg-[var(--background-base)] px-3 py-2 text-[0.8rem] text-[var(--text-base)]"
				onkeydown={(e: KeyboardEvent) => e.key === 'Enter' && handleFollow()}
			/>
			<button
				class="border border-[var(--decorative-base)] px-3 py-1 text-[0.8rem] uppercase text-[var(--text-base)] hover:text-[var(--essential-primary)]"
				onclick={handleFollow}
			>
				Follow
			</button>
		</div>
		{#if error}
			<p class="mt-1 text-[0.75rem] text-[var(--essential-primary)]">{error}</p>
		{/if}
	</div>

	<!-- Friends list -->
	<div>
		<p class="mb-2 text-[0.7rem] uppercase tracking-widest opacity-50">
			Following ({$friends.length})
		</p>
		{#if $friends.length === 0}
			<p class="text-[0.8rem] opacity-50">
				Share your link with friends and paste theirs here to follow them.
			</p>
		{:else}
			<ul class="m-0 list-none p-0">
				{#each $friends as friend}
					<li class="flex items-center gap-2 py-2">
						<div class="flex-1 overflow-hidden">
							<span class="text-[0.9rem] text-[var(--text-base)]">
								{friend.name || friend.npub.slice(0, 12) + '...'}
							</span>
							{#if friend.stationName}
								<button
									class="ml-2 text-[0.75rem] text-[var(--essential-primary)] hover:underline"
									onclick={() => handleTune(friend)}
								>
									{friend.stationName}
								</button>
							{:else}
								<span class="ml-2 text-[0.7rem] opacity-30">offline</span>
							{/if}
						</div>
						<button
							class="text-[0.7rem] opacity-30 hover:opacity-100"
							onclick={() => handleUnfollow(friend)}
						>
							unfollow
						</button>
					</li>
				{/each}
			</ul>
		{/if}
	</div>
</div>
