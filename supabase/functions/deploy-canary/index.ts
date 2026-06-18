// TEMPORARY deploy-canary function — used to verify the Supabase GitHub
// integration actually deploys edge functions to the live project on push to
// main. Safe to delete after verification. verify_jwt is disabled so an
// unauthenticated curl returns a recognizable marker.
Deno.serve(() => {
  return new Response(
    JSON.stringify({ canary: 'ok', deployed_at: '2026-06-17' }),
    { headers: { 'Content-Type': 'application/json' }, status: 200 },
  );
});
