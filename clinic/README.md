# the clinician dashboard moved

It lives in the **web** repository now:

    jeni-health-web/app/care          the route
    jeni-health-web/components/care   the screens
    jeni-health-web/lib/care          the RPC client, types, attention model
    jeni-health-web/scripts/demo      the demo clinic + its Supabase stack

## why

This directory held the S4/S5 clinician alpha, built here because at
the time there was no web product to hold it — `10_S4_CLINIC_LOOP §11`
chose "a static web app in `clinic/`" as the smallest production-capable
surface that fit the stack. jeni.health exists now, so the boundary is
the honest one:

    plankAI           the patient experience (iOS)
    jeni-health-web   jeni.health + the clinician experience

One canonical record system still spans both — the Supabase schema in
`supabase/migrations/` is owned HERE, because it defines every patient
table the app writes and the `care_*` RPCs are definer functions layered
over those same rows. The web repo's demo stack reads that chain rather
than forking it.

## what is still here

The iOS half of the demo:

    Scripts/demo/run.sh          drives the phone (and calls the web repo
                                 to reset + seed the clinic)
    Scripts/demo/capture_ios.sh  the iOS frames
    PlankApp/App/ClinicDemoSeeder.swift

See `docs/demo/00_DEMO.md`.
