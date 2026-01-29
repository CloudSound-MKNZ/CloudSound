<script lang="ts">
	import { onMount } from 'svelte';
	import { getStations, getConcerts, triggerEventsPoll, type Station, type Concert } from '$lib/api/client';

	let stations: Station[] = [];
	let concerts: Concert[] = [];
	let loadingStations = true;
	let loadingConcerts = true;
	let stationsError: string | null = null;
	let concertsError: string | null = null;
	
	// Sync state
	let syncing = false;
	let syncMessage: string | null = null;
	let syncError: string | null = null;

	onMount(async () => {
		// Fetch stations
		try {
			stations = await getStations();
			stations = stations.slice(0, 3); // Show first 3
		} catch (e) {
			stationsError = e instanceof Error ? e.message : 'Failed to load';
		}
		loadingStations = false;

		// Fetch concerts
		try {
			concerts = await getConcerts();
			concerts = concerts
				.filter((c) => new Date(c.date) > new Date())
				.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())
				.slice(0, 3);
		} catch (e) {
			concertsError = e instanceof Error ? e.message : 'Failed to load';
		}
		loadingConcerts = false;
	});

	function formatDate(dateString: string): string {
		return new Date(dateString).toLocaleDateString('en-US', {
			month: 'short',
			day: 'numeric',
			year: 'numeric'
		});
	}
	
	async function syncEvents() {
		if (syncing) return;
		
		syncing = true;
		syncMessage = null;
		syncError = null;
		
		try {
			const result = await triggerEventsPoll();
			const created = result.created || 0;
			const updated = result.updated || 0;
			const skipped = result.skipped || 0;
			if (created > 0 || updated > 0) {
				syncMessage = `Synced ${result.events_fetched} events: ${created} created, ${updated} updated, ${skipped} skipped`;
			} else if (result.events_fetched > 0) {
				syncMessage = `Fetched ${result.events_fetched} events (${skipped} skipped - check validation)`;
			} else {
				syncMessage = `No events found to sync`;
			}
			
			// Refresh concerts after sync
			setTimeout(async () => {
				try {
					concerts = await getConcerts();
					concerts = concerts
						.filter((c) => new Date(c.date) > new Date())
						.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())
						.slice(0, 3);
				} catch (e) {
					// Ignore refresh error
				}
			}, 2000);
			
			// Clear message after 5 seconds
			setTimeout(() => {
				syncMessage = null;
			}, 5000);
		} catch (e) {
			syncError = e instanceof Error ? e.message : 'Failed to sync events';
			setTimeout(() => {
				syncError = null;
			}, 5000);
		} finally {
			syncing = false;
		}
	}
</script>

<svelte:head>
	<title>CloudSound - Local Music Radio Platform</title>
</svelte:head>

<div class="home">
	<!-- Hero Section -->
	<section class="hero">
		<div class="hero-content">
			<h1>Welcome to CloudSound</h1>
			<p class="hero-subtitle">Your local music club's radio platform</p>
			<p class="hero-description">
				Discover music from upcoming and past performers, listen to curated radio stations, and stay
				updated with the concert schedule.
			</p>
			<div class="hero-actions">
				<a href="/radio" class="btn btn-primary">🎵 Listen Now</a>
				<a href="/concerts" class="btn btn-secondary">📅 View Concerts</a>
			</div>
		</div>
	</section>

	<!-- Featured Stations -->
	<section class="section">
		<div class="section-header">
			<h2>📻 Radio Stations</h2>
			<a href="/radio" class="view-all">View all →</a>
		</div>

		{#if loadingStations}
			<div class="loading">Loading stations...</div>
		{:else if stationsError}
			<div class="error">{stationsError}</div>
		{:else if stations.length === 0}
			<div class="empty">No stations available</div>
		{:else}
			<div class="cards-grid">
				{#each stations as station (station.id)}
					<a href="/radio/{station.id}" class="card station-card">
						<span class="card-badge">{station.type}</span>
						<h3>{station.name}</h3>
						{#if station.genre}
							<span class="genre-tag">{station.genre}</span>
						{/if}
						{#if station.description}
							<p>{station.description}</p>
						{/if}
					</a>
				{/each}
			</div>
		{/if}
	</section>

	<!-- Upcoming Concerts -->
	<section class="section">
		<div class="section-header">
			<h2>🎤 Upcoming Concerts</h2>
			<a href="/concerts" class="view-all">View all →</a>
		</div>

		{#if loadingConcerts}
			<div class="loading">Loading concerts...</div>
		{:else if concertsError}
			<div class="error">{concertsError}</div>
		{:else if concerts.length === 0}
			<div class="empty">No upcoming concerts scheduled</div>
		{:else}
			<div class="cards-grid">
				{#each concerts as concert (concert.id)}
					<div class="card concert-card">
						<span class="date-badge">{formatDate(concert.date)}</span>
						{#if concert.title}
							<h3>{concert.title}</h3>
						{/if}
						<p class="location">📍 {concert.location}</p>
						{#if concert.description}
							<p class="description">{concert.description}</p>
						{/if}
					</div>
				{/each}
			</div>
		{/if}
	</section>

	<!-- Quick Links -->
	<section class="section quick-links">
		<h2>Quick Links</h2>
		<div class="links-grid">
			<a href="/radio" class="quick-link">
				<span class="link-icon">📻</span>
				<span class="link-label">Browse Radio Stations</span>
			</a>
			<a href="/concerts" class="quick-link">
				<span class="link-icon">🎤</span>
				<span class="link-label">Concert Schedule</span>
			</a>
			<a href="/search" class="quick-link">
				<span class="link-icon">🔍</span>
				<span class="link-label">Search Music</span>
			</a>
			<button 
				class="quick-link sync-button" 
				on:click={syncEvents}
				disabled={syncing}
			>
				<span class="link-icon">{syncing ? '⏳' : '🔄'}</span>
				<span class="link-label">{syncing ? 'Syncing...' : 'Sync Events'}</span>
			</button>
		</div>
		
		{#if syncMessage}
			<div class="sync-toast success">
				✅ {syncMessage}
			</div>
		{/if}
		
		{#if syncError}
			<div class="sync-toast error">
				❌ {syncError}
			</div>
		{/if}
	</section>
</div>

<style>
	.home {
		width: 100%;
	}

	/* Hero */
	.hero {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		border-radius: 16px;
		padding: 3rem 2rem;
		color: white;
		text-align: center;
		margin-bottom: 3rem;
	}

	.hero-content {
		max-width: 600px;
		margin: 0 auto;
	}

	.hero h1 {
		font-size: 2.5rem;
		margin-bottom: 0.5rem;
	}

	.hero-subtitle {
		font-size: 1.25rem;
		opacity: 0.9;
		margin-bottom: 1rem;
	}

	.hero-description {
		opacity: 0.85;
		line-height: 1.6;
		margin-bottom: 2rem;
	}

	.hero-actions {
		display: flex;
		gap: 1rem;
		justify-content: center;
		flex-wrap: wrap;
	}

	.btn {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1.5rem;
		border-radius: 8px;
		text-decoration: none;
		font-weight: 500;
		transition:
			transform 0.2s,
			box-shadow 0.2s;
	}

	.btn:hover {
		transform: translateY(-2px);
	}

	.btn-primary {
		background: white;
		color: #667eea;
	}

	.btn-secondary {
		background: rgba(255, 255, 255, 0.2);
		color: white;
		border: 1px solid rgba(255, 255, 255, 0.3);
	}

	/* Sections */
	.section {
		margin-bottom: 3rem;
	}

	.section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1.5rem;
	}

	.section-header h2 {
		font-size: 1.5rem;
		color: #1a202c;
	}

	.view-all {
		color: #667eea;
		text-decoration: none;
		font-weight: 500;
	}

	.view-all:hover {
		text-decoration: underline;
	}

	/* Cards Grid */
	.cards-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
		gap: 1.5rem;
	}

	.card {
		background: white;
		border: 1px solid #e2e8f0;
		border-radius: 12px;
		padding: 1.5rem;
		transition:
			transform 0.2s,
			box-shadow 0.2s;
	}

	.card:hover {
		transform: translateY(-2px);
		box-shadow: 0 8px 25px rgba(0, 0, 0, 0.08);
	}

	.station-card {
		display: block;
		text-decoration: none;
		color: inherit;
	}

	.card-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		background: #edf2f7;
		border-radius: 20px;
		font-size: 0.8rem;
		color: #4a5568;
		margin-bottom: 0.75rem;
		text-transform: capitalize;
	}

	.card h3 {
		margin: 0 0 0.5rem 0;
		font-size: 1.1rem;
		color: #1a202c;
	}

	.genre-tag {
		display: inline-block;
		padding: 0.2rem 0.5rem;
		background: #e9d8fd;
		color: #553c9a;
		border-radius: 4px;
		font-size: 0.75rem;
		margin-bottom: 0.5rem;
	}

	.card p {
		color: #718096;
		font-size: 0.9rem;
		margin: 0;
	}

	.date-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		background: #fed7d7;
		color: #c53030;
		border-radius: 20px;
		font-size: 0.8rem;
		font-weight: 500;
		margin-bottom: 0.75rem;
	}

	.location {
		color: #4a5568;
		margin-bottom: 0.5rem;
	}

	.description {
		color: #718096;
	}

	/* Loading/Error/Empty */
	.loading,
	.error,
	.empty {
		text-align: center;
		padding: 2rem;
		color: #718096;
		background: #f7fafc;
		border-radius: 8px;
	}

	.error {
		color: #c53030;
		background: #fff5f5;
	}

	/* Quick Links */
	.quick-links {
		background: white;
		border-radius: 12px;
		padding: 2rem;
		border: 1px solid #e2e8f0;
	}

	.quick-links h2 {
		text-align: center;
		margin-bottom: 1.5rem;
	}

	.links-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 1rem;
	}

	.quick-link {
		display: flex;
		align-items: center;
		gap: 1rem;
		padding: 1rem 1.5rem;
		background: #f7fafc;
		border-radius: 8px;
		text-decoration: none;
		color: #1a202c;
		transition: background 0.2s;
	}

	.quick-link:hover {
		background: #edf2f7;
	}

	.link-icon {
		font-size: 1.5rem;
	}

	.link-label {
		font-weight: 500;
	}

	/* Sync Button */
	.sync-button {
		border: none;
		cursor: pointer;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
	}

	.sync-button:hover:not(:disabled) {
		background: linear-gradient(135deg, #5a67d8 0%, #6b46c1 100%);
		transform: translateY(-1px);
	}

	.sync-button:disabled {
		opacity: 0.7;
		cursor: not-allowed;
	}

	.sync-button .link-icon {
		transition: transform 0.3s;
	}

	.sync-button:not(:disabled):hover .link-icon {
		transform: rotate(180deg);
	}

	/* Sync Toast */
	.sync-toast {
		margin-top: 1rem;
		padding: 0.75rem 1rem;
		border-radius: 8px;
		text-align: center;
		animation: slideIn 0.3s ease-out;
	}

	.sync-toast.success {
		background: #c6f6d5;
		color: #22543d;
	}

	.sync-toast.error {
		background: #fed7d7;
		color: #c53030;
	}

	@keyframes slideIn {
		from {
			opacity: 0;
			transform: translateY(-10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	@media (max-width: 600px) {
		.hero {
			padding: 2rem 1rem;
		}

		.hero h1 {
			font-size: 1.75rem;
		}

		.hero-actions {
			flex-direction: column;
		}

		.btn {
			width: 100%;
			justify-content: center;
		}
	}
</style>
