<script lang="ts">
	import { goto } from '$app/navigation';
</script>

<svelte:head>
	<title>CloudSound</title>
</svelte:head>

<div class="container">
	<h1>Welcome to CloudSound</h1>
	<p><a href="/radio">View Radio Stations →</a></p>
</div>

<style>
	.container {
		max-width: 800px;
		margin: 0 auto;
		padding: 2rem;
		text-align: center;
	}

	h1 {
		margin-bottom: 2rem;
	}

	a {
		color: #0066cc;
		text-decoration: none;
		font-size: 1.2em;
	}

	a:hover {
		text-decoration: underline;
	}
</style>
