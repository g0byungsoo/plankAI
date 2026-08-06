// Jeni Care site behavior. No framework, no external requests except
// the one pilot-request POST. Reduced-motion respected throughout.
(function () {
  "use strict";
  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var loadedAt = Date.now();

  var y = document.getElementById("year");
  if (y) y.textContent = String(new Date().getFullYear());

  // Scroll reveal (and the horizon fill / notes), IntersectionObserver.
  if ("IntersectionObserver" in window && !reduce) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); }
      });
    }, { threshold: 0.16 });
    document.querySelectorAll(".reveal").forEach(function (el) { io.observe(el); });

    var track = document.getElementById("hzTrack");
    if (track) {
      var hzIo = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          if (!e.isIntersecting) return;
          track.classList.add("lit");
          var notes = document.querySelectorAll(".hz-note");
          notes.forEach(function (n, i) { setTimeout(function () { n.classList.add("in"); }, 500 + i * 160); });
          hzIo.disconnect();
        });
      }, { threshold: 0.4 });
      hzIo.observe(track);
    }
  } else {
    document.querySelectorAll(".reveal, .hz-note").forEach(function (el) { el.classList.add("in"); });
    var t = document.getElementById("hzTrack"); if (t) t.classList.add("lit");
  }

  // Pilot request form.
  var form = document.getElementById("pilotForm");
  if (!form) return;
  var msg = document.getElementById("formMsg");
  var submit = document.getElementById("pilotSubmit");

  function show(kind, text) {
    msg.className = "form-msg " + kind;
    msg.textContent = text;
    msg.style.display = "block";
  }

  form.addEventListener("submit", function (ev) {
    ev.preventDefault();
    var cfg = window.JENI_CARE || {};
    if (!cfg.supabaseUrl || !cfg.supabaseAnonKey) {
      show("err", "the request form isn't configured yet — email us instead.");
      return;
    }
    var fd = new FormData(form);
    var body = {
      p_name: (fd.get("name") || "").trim(),
      p_email: (fd.get("email") || "").trim(),
      p_clinic: (fd.get("clinic") || "").trim(),
      p_role: (fd.get("role") || "").trim() || null,
      p_glp1_volume: fd.get("glp1_volume") || null,
      p_workflow: (fd.get("workflow") || "").trim() || null,
      p_pain: (fd.get("pain") || "").trim() || null,
      p_contact_pref: "email",
      p_website: fd.get("website") || "",
      p_elapsed_ms: Date.now() - loadedAt,
    };
    if (!body.p_name || !body.p_email || !body.p_clinic) {
      show("err", "please add your name, work email, and clinic.");
      return;
    }
    submit.disabled = true;
    submit.textContent = "sending…";
    fetch(cfg.supabaseUrl.replace(/\/$/, "") + "/rest/v1/rpc/care_submit_pilot_request", {
      method: "POST",
      headers: {
        apikey: cfg.supabaseAnonKey,
        Authorization: "Bearer " + cfg.supabaseAnonKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    })
      .then(function (r) { return r.json().then(function (j) { return { ok: r.ok, j: j }; }); })
      .then(function (res) {
        if (res.ok) {
          form.reset();
          show("ok", "thank you — we've got it. we'll reply to set up a conversation. this doesn't create a clinical relationship.");
        } else {
          show("err", (res.j && res.j.message) || "something went wrong — please email us instead.");
          submit.disabled = false;
          submit.textContent = "Request a pilot";
        }
      })
      .catch(function () {
        show("err", "we couldn't reach the server — please email us instead.");
        submit.disabled = false;
        submit.textContent = "Request a pilot";
      });
  });
})();
