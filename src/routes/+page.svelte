<script lang="ts">
	import { onMount } from 'svelte';
	import { currentTheme } from '$lib/store';
	import { showP2P } from '$lib/p2p-store';
	import Footer from '$lib/components/Footer.svelte';
	import Header from '$lib/components/Header.svelte';
	import NowPlaying from '$lib/components/NowPlaying.svelte';
	import StationList from '$lib/components/StationList.svelte';
	import P2PPanel from '$lib/components/P2PPanel.svelte';

	onMount(() => {
		const hash = window.location.hash.slice(1);
		if (hash.startsWith('follow:')) {
			showP2P.set(true);
		}
	});
</script>

<div class="base {$currentTheme} mx-auto flex h-screen flex-col">
	<div class="flex-none bg-[var(--background-base)]">
		<Header />
		<NowPlaying />
	</div>
	<main class="flex-1 overflow-y-auto bg-[var(--background-base)]">
		{#if $showP2P}
			<P2PPanel />
		{:else}
			<StationList />
		{/if}
	</main>
	<div class="flex-none">
		<Footer />
	</div>
</div>
