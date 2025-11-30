<script lang="ts">
	import ConcertSchedule from '$lib/components/ConcertSchedule.svelte';
</script>

<svelte:head>
	<title>Concert Schedule - CloudSound</title>
</svelte:head>

<div class="container">
	<h1>Concert Schedule</h1>
	<ConcertSchedule />
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
</style>

