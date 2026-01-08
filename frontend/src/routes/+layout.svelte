<script lang="ts">
	import favicon from '$lib/assets/favicon.svg';
	import { page } from '$app/stores';

	let { children } = $props();

	// Navigation items
	const navItems = [
		{ href: '/', label: 'Home', icon: '🏠' },
		{ href: '/radio', label: 'Radio', icon: '📻' },
		{ href: '/concerts', label: 'Concerts', icon: '🎤' },
		{ href: '/search', label: 'Search', icon: '🔍' },
		{ href: '/admin', label: 'Admin', icon: '⚙️' }
	];
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
	<link rel="preconnect" href="https://fonts.googleapis.com" />
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
	<link
		href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap"
		rel="stylesheet"
	/>
</svelte:head>

<div class="app">
	<header class="header">
		<div class="header-content">
			<a href="/" class="logo">
				<span class="logo-icon">🎵</span>
				<span class="logo-text">CloudSound</span>
			</a>

			<nav class="nav">
				{#each navItems as item}
					<a
						href={item.href}
						class="nav-link"
						class:active={$page.url.pathname === item.href ||
							(item.href !== '/' && $page.url.pathname.startsWith(item.href))}
					>
						<span class="nav-icon">{item.icon}</span>
						<span class="nav-label">{item.label}</span>
					</a>
				{/each}
			</nav>
		</div>
	</header>

	<main class="main">
		{@render children()}
	</main>

	<footer class="footer">
		<div class="footer-content">
			<p>CloudSound Radio Platform • Local Music Club</p>
			<p class="footer-links">
				<a href="/radio">Radio</a>
				<span class="separator">•</span>
				<a href="/concerts">Concerts</a>
				<span class="separator">•</span>
				<a href="/search">Search</a>
			</p>
		</div>
	</footer>
</div>

<style>
	:global(*) {
		margin: 0;
		padding: 0;
		box-sizing: border-box;
	}

	:global(body) {
		font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
		background: #f7fafc;
		color: #1a202c;
		line-height: 1.6;
	}

	.app {
		min-height: 100vh;
		display: flex;
		flex-direction: column;
	}

	.header {
		background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
		color: white;
		padding: 0 1rem;
		position: sticky;
		top: 0;
		z-index: 100;
		box-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
	}

	.header-content {
		max-width: 1200px;
		margin: 0 auto;
		display: flex;
		align-items: center;
		justify-content: space-between;
		height: 64px;
	}

	.logo {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		text-decoration: none;
		color: white;
	}

	.logo-icon {
		font-size: 1.5rem;
	}

	.logo-text {
		font-size: 1.25rem;
		font-weight: 700;
		letter-spacing: -0.02em;
	}

	.nav {
		display: flex;
		gap: 0.5rem;
	}

	.nav-link {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		padding: 0.5rem 1rem;
		text-decoration: none;
		color: rgba(255, 255, 255, 0.8);
		border-radius: 8px;
		transition:
			background 0.2s,
			color 0.2s;
		font-size: 0.9rem;
	}

	.nav-link:hover {
		background: rgba(255, 255, 255, 0.1);
		color: white;
	}

	.nav-link.active {
		background: rgba(255, 255, 255, 0.15);
		color: white;
	}

	.nav-icon {
		font-size: 1rem;
	}

	.main {
		flex: 1;
		padding: 2rem 1rem;
		max-width: 1200px;
		margin: 0 auto;
		width: 100%;
	}

	.footer {
		background: #1a202c;
		color: #a0aec0;
		padding: 2rem 1rem;
		margin-top: auto;
	}

	.footer-content {
		max-width: 1200px;
		margin: 0 auto;
		text-align: center;
	}

	.footer p {
		margin-bottom: 0.5rem;
	}

	.footer-links a {
		color: #a0aec0;
		text-decoration: none;
	}

	.footer-links a:hover {
		color: white;
	}

	.separator {
		margin: 0 0.5rem;
	}

	@media (max-width: 600px) {
		.header-content {
			flex-direction: column;
			height: auto;
			padding: 1rem 0;
			gap: 1rem;
		}

		.nav {
			width: 100%;
			justify-content: center;
		}

		.nav-label {
			display: none;
		}

		.nav-link {
			padding: 0.5rem 0.75rem;
		}

		.nav-icon {
			font-size: 1.2rem;
		}
	}
</style>
