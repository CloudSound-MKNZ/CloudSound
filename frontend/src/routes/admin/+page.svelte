<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { auth, isAdmin } from '$lib/stores/auth';
	import AdminLogin from '$lib/components/AdminLogin.svelte';

	onMount(() => {
		// If already logged in as admin, redirect to concerts
		if ($isAdmin) {
			goto('/admin/concerts');
		}
	});

	$: if ($isAdmin) {
		goto('/admin/concerts');
	}
</script>

<svelte:head>
	<title>Admin Login - CloudSound</title>
</svelte:head>

<AdminLogin />

