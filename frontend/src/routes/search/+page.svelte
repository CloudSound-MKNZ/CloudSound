<script lang="ts">
	import SearchBar from '$lib/components/SearchBar.svelte';
	import SearchResults from '$lib/components/SearchResults.svelte';
	import { search, type Artist, type Track } from '$lib/api/client';
	import { onMount } from 'svelte';

	let searchQuery: string = '';
	let artists: Artist[] = [];
	let tracks: Track[] = [];
	let loading: boolean = false;
	let error: string | null = null;

	// Get query from URL params if present
	onMount(() => {
		const urlParams = new URLSearchParams(window.location.search);
		const q = urlParams.get('q');
		if (q) {
			searchQuery = q;
			performSearch(q);
		}
	});

	async function performSearch(query: string) {
		if (!query.trim()) {
			artists = [];
			tracks = [];
			return;
		}

		loading = true;
		error = null;
		searchQuery = query;

		// Update URL without page reload
		const url = new URL(window.location.href);
		url.searchParams.set('q', query);
		window.history.pushState({}, '', url);

		try {
			const results = await search(query);
			artists = results.artists;
			tracks = results.tracks;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to search';
			artists = [];
			tracks = [];
		} finally {
			loading = false;
		}
	}

	function handleSearch(event: CustomEvent<string>) {
		performSearch(event.detail);
	}

	function handleInput(event: CustomEvent<string>) {
		// Optional: Could implement debounced search here
	}

	function handleClear() {
		searchQuery = '';
		artists = [];
		tracks = [];
		error = null;

		// Clear URL param
		const url = new URL(window.location.href);
		url.searchParams.delete('q');
		window.history.pushState({}, '', url);
	}
</script>

<svelte:head>
	<title>Search - CloudSound</title>
</svelte:head>

<div class="container">
	<h1>Search Music</h1>
	<SearchBar bind:value={searchQuery} on:search={handleSearch} on:input={handleInput} on:clear={handleClear} />

	{#if error}
		<div class="error-message">
			<p>Error: {error}</p>
		</div>
	{/if}

	<SearchResults {artists} {tracks} query={searchQuery} {loading} />
</div>

<style>
	.container {
		max-width: 1000px;
		margin: 0 auto;
		padding: 2rem;
	}

	h1 {
		margin-bottom: 2rem;
	}

	.error-message {
		padding: 1rem;
		margin-bottom: 1rem;
		background-color: #ffe6e6;
		border: 1px solid #ff9999;
		border-radius: 4px;
		color: #cc0000;
	}
</style>

