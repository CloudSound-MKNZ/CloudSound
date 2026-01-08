<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { auth, isAdmin, currentUser } from '$lib/stores/auth';
	import { getConcerts, concertsApi, type Concert } from '$lib/api/client';
	import ConcertForm from '$lib/components/ConcertForm.svelte';

	let concerts: Concert[] = [];
	let loading = true;
	let error: string | null = null;

	// Modal state
	let showForm = false;
	let editingConcert: Concert | null = null;
	let formLoading = false;
	let formError: string | null = null;

	// Delete confirmation
	let deletingId: string | null = null;

	onMount(async () => {
		// Check if admin
		if (!$isAdmin) {
			goto('/admin');
			return;
		}

		await loadConcerts();
	});

	async function loadConcerts() {
		loading = true;
		error = null;
		try {
			concerts = await getConcerts();
			concerts.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load concerts';
		}
		loading = false;
	}

	function openCreateForm() {
		editingConcert = null;
		formError = null;
		showForm = true;
	}

	function openEditForm(concert: Concert) {
		editingConcert = concert;
		formError = null;
		showForm = true;
	}

	function closeForm() {
		showForm = false;
		editingConcert = null;
		formError = null;
	}

	async function handleFormSubmit(
		event: CustomEvent<{
			date: string;
			location: string;
			description: string;
			expected_version?: number;
		}>
	) {
		formLoading = true;
		formError = null;

		try {
			if (editingConcert) {
				// Update
				const response = await concertsApi.updateConcert(editingConcert.id, event.detail);
				if (response.error) {
					formError = response.error;
				} else {
					await loadConcerts();
					closeForm();
				}
			} else {
				// Create
				const response = await concertsApi.createConcert(event.detail);
				if (response.error) {
					formError = response.error;
				} else {
					await loadConcerts();
					closeForm();
				}
			}
		} catch (e) {
			formError = e instanceof Error ? e.message : 'Operation failed';
		}

		formLoading = false;
	}

	async function handleDelete(concertId: string) {
		if (deletingId === concertId) {
			// Confirm delete
			try {
				const response = await concertsApi.deleteConcert(concertId);
				if (response.error) {
					alert('Failed to delete: ' + response.error);
				} else {
					await loadConcerts();
				}
			} catch (e) {
				alert('Failed to delete concert');
			}
			deletingId = null;
		} else {
			// First click - show confirmation
			deletingId = concertId;
			// Reset after 3 seconds
			setTimeout(() => {
				deletingId = null;
			}, 3000);
		}
	}

	function formatDate(dateString: string): string {
		return new Date(dateString).toLocaleDateString('en-US', {
			weekday: 'short',
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function isUpcoming(dateString: string): boolean {
		return new Date(dateString) > new Date();
	}

	function handleLogout() {
		auth.logout();
		goto('/admin');
	}
</script>

<svelte:head>
	<title>Manage Concerts - CloudSound Admin</title>
</svelte:head>

<div class="admin-container">
	<header class="admin-header">
		<div class="header-left">
			<h1>🎤 Concert Management</h1>
			<p>Manage concert schedule for CloudSound</p>
		</div>
		<div class="header-right">
			<span class="user-info">
				👤 {$currentUser?.email || 'Admin'}
			</span>
			<button class="logout-btn" onclick={handleLogout}>
				🚪 Logout
			</button>
		</div>
	</header>

	<div class="toolbar">
		<button class="btn-primary" onclick={openCreateForm}>
			➕ Add Concert
		</button>
		<button class="btn-secondary" onclick={loadConcerts} disabled={loading}>
			🔄 Refresh
		</button>
	</div>

	{#if loading}
		<div class="loading">
			<div class="spinner"></div>
			<p>Loading concerts...</p>
		</div>
	{:else if error}
		<div class="error">
			<p>⚠️ {error}</p>
			<button onclick={loadConcerts}>Try Again</button>
		</div>
	{:else if concerts.length === 0}
		<div class="empty">
			<div class="empty-icon">🎤</div>
			<h3>No Concerts Yet</h3>
			<p>Click "Add Concert" to create your first concert</p>
		</div>
	{:else}
		<div class="concerts-table">
			<table>
				<thead>
					<tr>
						<th>Date</th>
						<th>Location</th>
						<th>Description</th>
						<th>Status</th>
						<th>Actions</th>
					</tr>
				</thead>
				<tbody>
					{#each concerts as concert (concert.id)}
						<tr class:past={!isUpcoming(concert.date)}>
							<td class="date-cell">
								<span class="date">{formatDate(concert.date)}</span>
							</td>
							<td class="location-cell">
								<strong>{concert.location}</strong>
							</td>
							<td class="description-cell">
								{concert.description || '-'}
							</td>
							<td class="status-cell">
								{#if isUpcoming(concert.date)}
									<span class="status upcoming">Upcoming</span>
								{:else}
									<span class="status past">Past</span>
								{/if}
							</td>
							<td class="actions-cell">
								<button class="action-btn edit" onclick={() => openEditForm(concert)} title="Edit">
									✏️
								</button>
								<button
									class="action-btn delete"
									class:confirm={deletingId === concert.id}
									onclick={() => handleDelete(concert.id)}
									title={deletingId === concert.id ? 'Click again to confirm' : 'Delete'}
								>
									{deletingId === concert.id ? '⚠️' : '🗑️'}
								</button>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
</div>

{#if showForm}
	<div class="modal-overlay" onclick={closeForm}>
		<div class="modal-content" onclick={(e) => e.stopPropagation()}>
			{#if formError}
				<div class="form-error">
					⚠️ {formError}
				</div>
			{/if}
			<ConcertForm
				concert={editingConcert}
				loading={formLoading}
				on:submit={handleFormSubmit}
				on:cancel={closeForm}
			/>
		</div>
	</div>
{/if}

<style>
	.admin-container {
		max-width: 1200px;
		margin: 0 auto;
	}

	.admin-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 2rem;
		flex-wrap: wrap;
		gap: 1rem;
	}

	.header-left h1 {
		margin: 0 0 0.5rem 0;
		font-size: 1.75rem;
		color: #1a202c;
	}

	.header-left p {
		margin: 0;
		color: #718096;
	}

	.header-right {
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.user-info {
		color: #4a5568;
		font-size: 0.9rem;
	}

	.logout-btn {
		padding: 0.5rem 1rem;
		background: #e2e8f0;
		border: none;
		border-radius: 6px;
		color: #4a5568;
		cursor: pointer;
		font-size: 0.9rem;
		transition: background 0.2s;
	}

	.logout-btn:hover {
		background: #cbd5e0;
	}

	.toolbar {
		display: flex;
		gap: 1rem;
		margin-bottom: 1.5rem;
	}

	.btn-primary,
	.btn-secondary {
		padding: 0.75rem 1.5rem;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-primary {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		border: none;
	}

	.btn-primary:hover {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
	}

	.btn-secondary {
		background: white;
		color: #4a5568;
		border: 2px solid #e2e8f0;
	}

	.btn-secondary:hover:not(:disabled) {
		background: #f7fafc;
	}

	.btn-secondary:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.loading {
		text-align: center;
		padding: 4rem;
		color: #718096;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #e2e8f0;
		border-top-color: #667eea;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin: 0 auto 1rem;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.error {
		text-align: center;
		padding: 2rem;
		background: #fff5f5;
		border: 1px solid #feb2b2;
		border-radius: 12px;
		color: #c53030;
	}

	.error button {
		margin-top: 1rem;
		padding: 0.5rem 1rem;
		background: #c53030;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
	}

	.empty {
		text-align: center;
		padding: 4rem;
		background: #f7fafc;
		border-radius: 12px;
	}

	.empty-icon {
		font-size: 4rem;
		margin-bottom: 1rem;
	}

	.empty h3 {
		margin: 0 0 0.5rem 0;
		color: #2d3748;
	}

	.empty p {
		color: #718096;
	}

	.concerts-table {
		background: white;
		border-radius: 12px;
		overflow: hidden;
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
	}

	table {
		width: 100%;
		border-collapse: collapse;
	}

	thead {
		background: #f7fafc;
	}

	th {
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #4a5568;
		border-bottom: 2px solid #e2e8f0;
	}

	td {
		padding: 1rem;
		border-bottom: 1px solid #e2e8f0;
		vertical-align: top;
	}

	tr:last-child td {
		border-bottom: none;
	}

	tr.past {
		opacity: 0.6;
		background: #f7fafc;
	}

	.date-cell {
		white-space: nowrap;
	}

	.description-cell {
		max-width: 300px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		color: #718096;
	}

	.status {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 20px;
		font-size: 0.8rem;
		font-weight: 500;
	}

	.status.upcoming {
		background: #c6f6d5;
		color: #276749;
	}

	.status.past {
		background: #e2e8f0;
		color: #4a5568;
	}

	.actions-cell {
		white-space: nowrap;
	}

	.action-btn {
		padding: 0.5rem;
		background: none;
		border: none;
		cursor: pointer;
		font-size: 1.1rem;
		border-radius: 6px;
		transition: background 0.2s;
	}

	.action-btn:hover {
		background: #edf2f7;
	}

	.action-btn.delete:hover {
		background: #fed7d7;
	}

	.action-btn.confirm {
		background: #fed7d7;
		animation: pulse 0.5s ease-in-out infinite;
	}

	@keyframes pulse {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.6;
		}
	}

	.modal-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
		padding: 1rem;
	}

	.modal-content {
		width: 100%;
		max-width: 500px;
		max-height: 90vh;
		overflow-y: auto;
	}

	.form-error {
		background: #fed7d7;
		color: #c53030;
		padding: 1rem;
		border-radius: 8px;
		margin-bottom: 1rem;
	}

	@media (max-width: 768px) {
		.concerts-table {
			overflow-x: auto;
		}

		table {
			min-width: 600px;
		}

		.admin-header {
			flex-direction: column;
		}

		.header-right {
			width: 100%;
			justify-content: space-between;
		}
	}
</style>

