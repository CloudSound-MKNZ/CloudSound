<script lang="ts">
	import { page } from '$app/stores';
	import { getStation, getStationTracks, getStreamUrl, type Station, type Track } from '$lib/api/client';
	import { onMount } from 'svelte';
	import AudioPlayer from '$lib/components/AudioPlayer.svelte';

	let station: Station | null = null;
	let tracks: Track[] = [];
	let loading = true;
	let error: string | null = null;

	$: stationId = $page.params.id;

	onMount(async () => {
		if (!stationId) return;

		try {
			station = await getStation(stationId);
			tracks = await getStationTracks(stationId);
			loading = false;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load station';
			loading = false;
		}
	});
</script>

<svelte:head>
	<title>{station?.name || 'Radio Station'} - CloudSound</title>
</svelte:head>

<div class="container">
	{#if loading}
		<p>Loading...</p>
	{:else if error}
		<p class="error">Error: {error}</p>
	{:else if station}
		<h1>{station.name}</h1>
		<p class="type">Type: {station.type}</p>
		{#if station.genre}
			<p class="genre">Genre: {station.genre}</p>
		{/if}
		{#if station.description}
			<p class="description">{station.description}</p>
		{/if}

		<AudioPlayer stationId={station.id} />

		<h2>Tracks ({tracks.length})</h2>
		{#if tracks.length === 0}
			<p>No tracks available for this station.</p>
		{:else}
			<ul class="tracks">
				{#each tracks as track (track.id)}
					<li>
						<strong>{track.title}</strong>
						{#if track.artist_name}
							<span class="artist"> - {track.artist_name}</span>
						{/if}
						<span class="duration">({Math.floor(track.duration_seconds / 60)}:{(track.duration_seconds % 60).toString().padStart(2, '0')})</span>
					</li>
				{/each}
			</ul>
		{/if}

		<p><a href="/radio">← Back to stations</a></p>
	{/if}
</div>

<style>
	.container {
		max-width: 800px;
		margin: 0 auto;
		padding: 2rem;
	}

	h1 {
		margin-bottom: 1rem;
	}

	.type,
	.genre {
		color: #666;
		margin: 0.5rem 0;
	}

	.description {
		margin: 1rem 0;
		color: #555;
	}

	.tracks {
		list-style: none;
		padding: 0;
		margin: 1rem 0;
	}

	.tracks li {
		padding: 0.5rem;
		margin-bottom: 0.5rem;
		border: 1px solid #ddd;
		border-radius: 4px;
	}

	.artist {
		color: #666;
	}

	.duration {
		color: #888;
		font-size: 0.9em;
		margin-left: 0.5rem;
	}

	.error {
		color: red;
	}

	a {
		color: #0066cc;
		text-decoration: none;
	}

	a:hover {
		text-decoration: underline;
	}
</style>

