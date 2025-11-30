<script lang="ts">
	import RadioStationBrowser from '$lib/components/RadioStationBrowser.svelte';
</script>

<svelte:head>
	<title>CloudSound Radio</title>
</svelte:head>

<div class="container">
	<h1>CloudSound Radio</h1>
	<RadioStationBrowser />
</div>

<style>
	.container {
		max-width: 800px;
		margin: 0 auto;
		padding: 2rem;
	}

	h1 {
		margin-bottom: 2rem;
	}
</style>

